library(shiny)
library(readxl)
library(janitor)
library(dplyr)
library(ggplot2)

ui <- fluidPage(
  titlePanel("Correlación de Pearson y Spearman"),
  sidebarLayout(
    sidebarPanel(
      fileInput("archivo", "Sube un archivo (.csv o .xlsx)", accept = c(".csv", ".xlsx")),
      selectInput("metodo", "Tipo de correlación:", choices = c("pearson", "spearman")),
      uiOutput("var1_ui"),
      uiOutput("var2_ui"),
      actionButton("analizar", "Calcular correlación")
    ),
    mainPanel(
      h4("Estadísticos descriptivos"),
      tableOutput("tabla_desc"),
      
      h4("Resultado de la correlación"),
      verbatimTextOutput("resultado"),
      
      h4("Interpretación"),
      verbatimTextOutput("interpretacion"),
      
      h4("Gráfico de dispersión"),
      plotOutput("grafico_dispersion")
    )
  )
)

server <- function(input, output, session) {
  
  datos <- reactive({
    req(input$archivo)
    ext <- tools::file_ext(input$archivo$name)
    if (ext == "csv") {
      read.csv(input$archivo$datapath) %>% clean_names()
    } else if (ext == "xlsx") {
      read_excel(input$archivo$datapath) %>% clean_names()
    } else {
      showNotification("Formato no compatible. Usa .csv o .xlsx", type = "error")
      return(NULL)
    }
  })
  
  output$var1_ui <- renderUI({
    req(datos())
    selectInput("var1", "Variable 1:", choices = names(datos()))
  })
  
  output$var2_ui <- renderUI({
    req(datos())
    selectInput("var2", "Variable 2:", choices = names(datos()))
  })
  
  datos_filtrados <- reactive({
    req(input$var1, input$var2)
    datos() %>%
      select(all_of(c(input$var1, input$var2))) %>%
      filter(complete.cases(.))
  })
  
  output$tabla_desc <- renderTable({
    req(datos_filtrados())
    df <- datos_filtrados()
    data.frame(
      Variable = c(input$var1, input$var2),
      Media = c(mean(df[[input$var1]]), mean(df[[input$var2]])),
      Mediana = c(median(df[[input$var1]]), median(df[[input$var2]])),
      Desviación = c(sd(df[[input$var1]]), sd(df[[input$var2]]))
    )
  })
  
  resultado_cor <- eventReactive(input$analizar, {
    req(datos_filtrados())
    cor.test(datos_filtrados()[[input$var1]], datos_filtrados()[[input$var2]], method = input$metodo)
  })
  
  output$resultado <- renderPrint({
    req(resultado_cor())
    resultado_cor()
  })
  
  output$interpretacion <- renderPrint({
    req(resultado_cor())
    r <- resultado_cor()$estimate
    p <- resultado_cor()$p.value
    
    cat("Coeficiente de correlación (r):", round(r, 4), "\n")
    cat("Valor p:", round(p, 4), "\n")
    
    if (p < 0.05) {
      cat("Existe una correlación significativa entre las variables.")
    } else {
      cat("No se encontró una correlación significativa entre las variables.")
    }
    
    if (abs(r) >= 0.7) {
      fuerza <- "fuerte"
    } else if (abs(r) >= 0.4) {
      fuerza <- "moderada"
    } else {
      fuerza <- "débil"
    }
    
    cat("\nLa relación es", fuerza, "y de tipo", ifelse(r > 0, "positiva.", "negativa."))
  })
  
  output$grafico_dispersion <- renderPlot({
    req(datos_filtrados())
    ggplot(datos_filtrados(), aes_string(x = input$var1, y = input$var2)) +
      geom_point(color = "#2C3E50") +
      geom_smooth(method = "lm", se = FALSE, color = "#E74C3C") +
      theme_minimal()
  })
  
}

shinyApp(ui, server)

