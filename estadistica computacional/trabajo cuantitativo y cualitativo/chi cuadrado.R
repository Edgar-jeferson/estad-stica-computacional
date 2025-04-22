library(shiny)
library(readxl)
library(ggplot2)
library(janitor)
library(dplyr)

ui <- fluidPage(
  titlePanel("Prueba Chi-cuadrado con análisis e interpretación"),
  sidebarLayout(
    sidebarPanel(
      fileInput("archivo", "Sube un archivo (.csv o .xlsx)", accept = c(".csv", ".xlsx")),
      uiOutput("var1_ui"),
      uiOutput("var2_ui"),
      actionButton("analizar", "Realizar Chi-cuadrado")
    ),
    mainPanel(
      h4("Tabla de Contingencia"),
      tableOutput("tabla_contingencia"),
      
      h4("Estadísticos Descriptivos"),
      verbatimTextOutput("descriptivos"),
      
      h4("Resultado de Chi-cuadrado"),
      verbatimTextOutput("resultado_chi"),
      
      h4("Interpretación"),
      verbatimTextOutput("interpretacion"),
      
      h4("Gráfico de barras"),
      plotOutput("grafico")
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
    selectInput("var1", "Variable 1 (categórica):", choices = names(datos()))
  })
  
  output$var2_ui <- renderUI({
    req(datos())
    selectInput("var2", "Variable 2 (categórica):", choices = names(datos()))
  })
  
  tabla_contingencia <- reactive({
    req(input$var1, input$var2)
    table(datos()[[input$var1]], datos()[[input$var2]])
  })
  
  resultado <- eventReactive(input$analizar, {
    chisq.test(tabla_contingencia())
  })
  
  output$tabla_contingencia <- renderTable({
    req(tabla_contingencia())
    as.data.frame.matrix(tabla_contingencia())
  }, rownames = TRUE)
  
  output$descriptivos <- renderPrint({
    req(datos(), input$var1, input$var2)
    cat("Frecuencias de", input$var1, ":\n")
    print(table(datos()[[input$var1]]))
    cat("\nFrecuencias de", input$var2, ":\n")
    print(table(datos()[[input$var2]]))
    
    moda_var1 <- names(which.max(table(datos()[[input$var1]])))
    moda_var2 <- names(which.max(table(datos()[[input$var2]])))
    
    cat("\nModa de", input$var1, ":", moda_var1)
    cat("\nModa de", input$var2, ":", moda_var2)
  })
  
  output$resultado_chi <- renderPrint({
    req(resultado())
    print(resultado())
  })
  
  output$interpretacion <- renderPrint({
    req(resultado())
    p <- resultado()$p.value
    if (p < 0.05) {
      cat("El valor p es", round(p, 4), 
          "\nComo p < 0.05, se rechaza la hipótesis nula.\nExiste una asociación significativa entre las variables.")
    } else {
      cat("El valor p es", round(p, 4), 
          "\nComo p ≥ 0.05, no se rechaza la hipótesis nula.\nNo hay evidencia suficiente para afirmar una asociación entre las variables.")
    }
  })
  
  output$grafico <- renderPlot({
    req(datos(), input$var1, input$var2)
    ggplot(datos(), aes_string(x = input$var1, fill = input$var2)) +
      geom_bar(position = "dodge") +
      theme_minimal() +
      labs(x = input$var1, y = "Frecuencia", fill = input$var2)
  })
}

shinyApp(ui, server)