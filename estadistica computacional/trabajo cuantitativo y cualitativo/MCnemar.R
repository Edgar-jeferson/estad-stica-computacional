
library(shiny)
library(readxl)
library(janitor)
library(dplyr)
library(ggplot2)
library(vcd)

ui <- fluidPage(
  titlePanel("Prueba de McNemar para datos emparejados"),
  sidebarLayout(
    sidebarPanel(
      fileInput("archivo", "Sube un archivo (.csv o .xlsx)", accept = c(".csv", ".xlsx")),
      uiOutput("var1_ui"),
      uiOutput("var2_ui"),
      actionButton("analizar", "Realizar prueba de McNemar")
    ),
    mainPanel(
      h4("Tabla de contingencia 2x2"),
      tableOutput("tabla_mcnemar"),
      
      h4("Estadísticos descriptivos"),
      verbatimTextOutput("frecuencias"),
      
      h4("Resultado de la prueba de McNemar"),
      verbatimTextOutput("resultado"),
      
      h4("Interpretación"),
      verbatimTextOutput("interpretacion"),
      
      h4("Gráficos de barras y mosaico"),
      plotOutput("grafico_barras"),
      plotOutput("grafico_mosaico")
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
    selectInput("var1", "Variable antes:", choices = names(datos()))
  })
  
  output$var2_ui <- renderUI({
    req(datos())
    selectInput("var2", "Variable después:", choices = names(datos()))
  })
  
  datos_filtrados <- reactive({
    req(input$var1, input$var2)
    datos() %>%
      select(all_of(c(input$var1, input$var2))) %>%
      filter(complete.cases(.))
  })
  
  tabla_mcnemar <- reactive({
    table(datos_filtrados()[[1]], datos_filtrados()[[2]])
  })
  
  resultado <- eventReactive(input$analizar, {
    req(tabla_mcnemar())
    mcnemar.test(tabla_mcnemar(), correct = TRUE)
  })
  
  output$tabla_mcnemar <- renderTable({
    req(tabla_mcnemar())
    as.data.frame.matrix(tabla_mcnemar())
  }, rownames = TRUE)
  
  output$frecuencias <- renderPrint({
    df <- datos_filtrados()
    cat("Frecuencias de", input$var1, ":\n")
    print(table(df[[1]]))
    cat("\nFrecuencias de", input$var2, ":\n")
    print(table(df[[2]]))
  })
  
  output$resultado <- renderPrint({
    req(resultado())
    print(resultado())
  })
  
  output$interpretacion <- renderPrint({
    req(resultado())
    p <- resultado()$p.value
    if (p < 0.05) {
      cat("El valor p es", round(p, 4), 
          "\nComo p < 0.05, se rechaza la hipótesis nula.\nHubo un cambio significativo entre las condiciones comparadas.")
    } else {
      cat("El valor p es", round(p, 4), 
          "\nComo p ≥ 0.05, no se rechaza la hipótesis nula.\nNo hubo un cambio significativo entre las condiciones.")
    }
  })
  
  output$grafico_barras <- renderPlot({
    df <- datos_filtrados()
    ggplot(df, aes_string(x = input$var1, fill = input$var2)) +
      geom_bar(position = "dodge") +
      theme_minimal() +
      labs(x = input$var1, y = "Frecuencia", fill = input$var2)
  })
  
  output$grafico_mosaico <- renderPlot({
    mosaic(tabla_mcnemar(), shade = TRUE, legend = TRUE)
  })
}

shinyApp(ui, server)
