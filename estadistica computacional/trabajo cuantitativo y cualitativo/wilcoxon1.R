
library(shiny)
library(readxl)
library(janitor)
library(dplyr)
library(ggplot2)

ui <- fluidPage(
  titlePanel("Prueba de Wilcoxon"),
  sidebarLayout(
    sidebarPanel(
      fileInput("archivo", "Sube un archivo (.csv o .xlsx)", accept = c(".csv", ".xlsx")),
      radioButtons("tipo", "Tipo de prueba:", choices = c("Pareada", "Independiente")),
      uiOutput("var1_ui"),
      uiOutput("var2_ui"),
      actionButton("analizar", "Realizar prueba de Wilcoxon")
    ),
    mainPanel(
      h4("Estadísticos descriptivos"),
      tableOutput("tabla_desc"),
      
      h4("Resultado de la prueba de Wilcoxon"),
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
  
  output$var1_ui <- renderUI({
    req(datos())
    if (input$tipo == "Pareada") {
      selectInput("var1", "Variable antes:", choices = names(datos()))
    } else {
      selectInput("var1", "Variable numérica:", choices = names(datos()))
    }
  })
  
  output$var2_ui <- renderUI({
    req(datos())
    if (input$tipo == "Pareada") {
      selectInput("var2", "Variable después:", choices = names(datos()))
    } else {
      selectInput("var2", "Variable de grupo (2 grupos):", choices = names(datos()))
    }
  })
  
  datos_filtrados <- reactive({
    req(input$var1, input$var2)
    datos() %>%
      select(all_of(c(input$var1, input$var2))) %>%
      filter(complete.cases(.))
  })
  
  output$tabla_desc <- renderTable({
    req(datos_filtrados())
    if (input$tipo == "Pareada") {
      data.frame(
        Variable = c(input$var1, input$var2),
        Media = c(mean(datos_filtrados()[[input$var1]]), mean(datos_filtrados()[[input$var2]])),
        Mediana = c(median(datos_filtrados()[[input$var1]]), median(datos_filtrados()[[input$var2]])),
        Desviación = c(sd(datos_filtrados()[[input$var1]]), sd(datos_filtrados()[[input$var2]]))
      )
    } else {
      datos_filtrados() %>%
        group_by(!!sym(input$var2)) %>%
        summarise(
          Media = mean(!!sym(input$var1)),
          Mediana = median(!!sym(input$var1)),
          Desviación = sd(!!sym(input$var1)),
          n = n()
        )
    }
  })
  
  resultado_wilcoxon <- eventReactive(input$analizar, {
    req(datos_filtrados())
    if (input$tipo == "Pareada") {
      wilcox.test(
        x = datos_filtrados()[[input$var1]],
        y = datos_filtrados()[[input$var2]],
        paired = TRUE
      )
    } else {
      wilcox.test(
        formula = as.formula(paste(input$var1, "~", input$var2)),
        data = datos_filtrados()
      )
    }
  })
  
  output$resultado <- renderPrint({
    req(resultado_wilcoxon())
    resultado_wilcoxon()
  })
  
  output$interpretacion <- renderPrint({
    req(resultado_wilcoxon())
    p <- resultado_wilcoxon()$p.value
    if (p < 0.05) {
      cat("El valor p es", round(p, 4),
          "\nComo p < 0.05, se rechaza la hipótesis nula.\nHay diferencias significativas entre los grupos o momentos.")
    } else {
      cat("El valor p es", round(p, 4),
          "\nComo p ≥ 0.05, no se rechaza la hipótesis nula.\nNo hay diferencias significativas entre los grupos o momentos.")
    }
  })
  
  output$boxplot <- renderPlot({
    req(datos_filtrados())
    if (input$tipo == "Pareada") {
      df_long <- datos_filtrados() %>%
        tidyr::pivot_longer(cols = everything(), names_to = "momento", values_to = "valor")
      ggplot(df_long, aes(x = momento, y = valor, fill = momento)) +
        geom_boxplot() +
        theme_minimal()
    } else {
      ggplot(datos_filtrados(), aes_string(x = input$var2, y = input$var1, fill = input$var2)) +
        geom_boxplot() +
        theme_minimal()
    }
  })
  
  output$media_error <- renderPlot({
    req(datos_filtrados())
    if (input$tipo == "Pareada") {
      df_long <- datos_filtrados() %>%
        tidyr::pivot_longer(cols = everything(), names_to = "momento", values_to = "valor") %>%
        group_by(momento) %>%
        summarise(
          Media = mean(valor),
          SE = sd(valor) / sqrt(n())
        )
      ggplot(df_long, aes(x = momento, y = Media, fill = momento)) +
        geom_col() +
        geom_errorbar(aes(ymin = Media - SE, ymax = Media + SE), width = 0.2) +
        theme_minimal()
    } else {
      resumen <- datos_filtrados() %>%
        group_by(!!sym(input$var2)) %>%
        summarise(
          Media = mean(!!sym(input$var1)),
          SE = sd(!!sym(input$var1)) / sqrt(n())
        )
      ggplot(resumen, aes_string(x = input$var2, y = "Media", fill = input$var2)) +
        geom_col() +
        geom_errorbar(aes(ymin = Media - SE, ymax = Media + SE), width = 0.2) +
        theme_minimal()
    }
  })
  
}

shinyApp(ui, server)