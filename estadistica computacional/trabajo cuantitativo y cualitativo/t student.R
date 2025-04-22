library(shiny)
library(readxl)
library(janitor)
library(dplyr)
library(ggplot2)

ui <- fluidPage(
  titlePanel("Prueba t de Student para muestras independientes"),
  sidebarLayout(
    sidebarPanel(
      fileInput("archivo", "Sube un archivo (.csv o .xlsx)", accept = c(".csv", ".xlsx")),
      uiOutput("var_num_ui"),
      uiOutput("var_cat_ui"),
      actionButton("analizar", "Realizar prueba t")
    ),
    mainPanel(
      h4("Estadísticos descriptivos por grupo"),
      tableOutput("tabla_desc"),
      
      h4("Resultado de la prueba t"),
      verbatimTextOutput("resultado"),
      
      h4("Interpretación"),
      verbatimTextOutput("interpretacion"),
      
      h4("Gráficos"),
      plotOutput("boxplot"),
      plotOutput("media_error")
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
  
  output$var_num_ui <- renderUI({
    req(datos())
    selectInput("var_num", "Variable numérica:", choices = names(datos()))
  })
  
  output$var_cat_ui <- renderUI({
    req(datos())
    selectInput("var_cat", "Variable de grupo (2 categorías):", choices = names(datos()))
  })
  
  datos_filtrados <- reactive({
    req(input$var_num, input$var_cat)
    datos() %>%
      select(all_of(c(input$var_num, input$var_cat))) %>%
      filter(complete.cases(.))
  })
  
  output$tabla_desc <- renderTable({
    req(datos_filtrados())
    datos_filtrados() %>%
      group_by(!!sym(input$var_cat)) %>%
      summarise(
        Media = mean(!!sym(input$var_num)),
        Desviación = sd(!!sym(input$var_num)),
        n = n()
      )
  })
  
  resultado_t <- eventReactive(input$analizar, {
    req(datos_filtrados())
    t.test(
      formula = as.formula(paste(input$var_num, "~", input$var_cat)),
      data = datos_filtrados()
    )
  })
  
  output$resultado <- renderPrint({
    req(resultado_t())
    print(resultado_t())
  })
  
  output$interpretacion <- renderPrint({
    req(resultado_t())
    p <- resultado_t()$p.value
    if (p < 0.05) {
      cat("El valor p es", round(p, 4),
          "\nComo p < 0.05, se rechaza la hipótesis nula.\nExiste una diferencia significativa entre los grupos.")
    } else {
      cat("El valor p es", round(p, 4),
          "\nComo p ≥ 0.05, no se rechaza la hipótesis nula.\nNo existe una diferencia significativa entre los grupos.")
    }
  })
  
  output$boxplot <- renderPlot({
    req(datos_filtrados())
    ggplot(datos_filtrados(), aes_string(x = input$var_cat, y = input$var_num, fill = input$var_cat)) +
      geom_boxplot() +
      theme_minimal() +
      labs(x = input$var_cat, y = input$var_num, title = "Boxplot por grupo")
  })
  
  output$media_error <- renderPlot({
    req(datos_filtrados())
    datos_resumen <- datos_filtrados() %>%
      group_by(!!sym(input$var_cat)) %>%
      summarise(
        Media = mean(!!sym(input$var_num)),
        SE = sd(!!sym(input$var_num)) / sqrt(n())
      )
    
    ggplot(datos_resumen, aes_string(x = input$var_cat, y = "Media", fill = input$var_cat)) +
      geom_col(position = "dodge") +
      geom_errorbar(aes(ymin = Media - SE, ymax = Media + SE), width = 0.2) +
      theme_minimal() +
      labs(x = input$var_cat, y = "Media", title = "Media con error estándar")
  })
  
}

shinyApp(ui, server)
