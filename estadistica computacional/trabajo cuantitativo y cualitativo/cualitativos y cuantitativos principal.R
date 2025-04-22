library(shiny)
library(readxl)
library(janitor)
library(dplyr)
library(ggplot2)
library(shinyjs)

ui <- fluidPage(
  useShinyjs(),  # Inicializa shinyjs
  titlePanel("Análisis Estadístico: t-Student, Chi-cuadrado, McNemar, ANOVA, Wilcoxon y Correlación"),
  
  # Agregar estilo general a la página
  tags$style(HTML("
    body {
      background-color: #f7f7f7;
      font-family: 'Arial', sans-serif;
    }
    .well {
      background-color: #ffffff;
      border-radius: 8px;
      padding: 20px;
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    }
    .btn {
      background-color: #2c3e50;
      color: white;
      border-radius: 5px;
    }
    .btn:hover {
      background-color: #34495e;
    }
    .container-fluid {
      padding-top: 30px;
    }
  ")),
  
  sidebarLayout(
    sidebarPanel(
      width = 3,
      fileInput("archivo", "Sube un archivo (.csv o .xlsx)", accept = c(".csv", ".xlsx")),
      radioButtons("prueba", "Selecciona la prueba estadística:",
                   choices = c("t-Student", "Chi-cuadrado", "McNemar", "ANOVA", "Wilcoxon", "Correlación"),
                   selected = "t-Student"),
      conditionalPanel(
        condition = "input.prueba == 't-Student'",
        selectInput("var1_t", "Variable 1:", choices = NULL),
        selectInput("var2_t", "Variable 2:", choices = NULL),
        actionButton("analizar_t", "Realizar prueba t-Student", class = "btn")
      ),
      conditionalPanel(
        condition = "input.prueba == 'Chi-cuadrado'",
        selectInput("var_chi", "Variable de conteo:", choices = NULL),
        actionButton("analizar_chi", "Realizar prueba Chi-cuadrado", class = "btn")
      ),
      conditionalPanel(
        condition = "input.prueba == 'McNemar'",
        selectInput("var1_mcnemar", "Variable 1:", choices = NULL),
        selectInput("var2_mcnemar", "Variable 2:", choices = NULL),
        actionButton("analizar_mcnemar", "Realizar prueba McNemar", class = "btn")
      ),
      conditionalPanel(
        condition = "input.prueba == 'ANOVA'",
        uiOutput("var_num_ui"),
        uiOutput("var_grupo_ui"),
        actionButton("analizar_anova", "Realizar prueba ANOVA", class = "btn")
      ),
      conditionalPanel(
        condition = "input.prueba == 'Wilcoxon'",
        radioButtons("tipo_wilcoxon", "Tipo de prueba:", choices = c("Pareada", "Independiente")),
        uiOutput("var1_wilcoxon_ui"),
        uiOutput("var2_wilcoxon_ui"),
        actionButton("analizar_wilcoxon", "Realizar prueba de Wilcoxon", class = "btn")
      ),
      conditionalPanel(
        condition = "input.prueba == 'Correlación'",
        selectInput("metodo_cor", "Tipo de correlación:", choices = c("pearson", "spearman")),
        uiOutput("var1_cor_ui"),
        uiOutput("var2_cor_ui"),
        actionButton("analizar_cor", "Calcular correlación", class = "btn")
      )
    ),
    
    mainPanel(
      width = 9,
      fluidRow(
        column(12, 
               h4("Resultado"),
               verbatimTextOutput("resultado"),
               br(),
               h4("Interpretación"),
               verbatimTextOutput("interpretacion"),
               br(),
               h4("Gráfico"),
               plotOutput("grafico")
        )
      )
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
  
  observe({
    req(datos())
    updateSelectInput(session, "var1_t", choices = names(datos()))
    updateSelectInput(session, "var2_t", choices = names(datos()))
    updateSelectInput(session, "var_chi", choices = names(datos()))
    updateSelectInput(session, "var1_mcnemar", choices = names(datos()))
    updateSelectInput(session, "var2_mcnemar", choices = names(datos()))
    updateSelectInput(session, "var_num", choices = names(datos()))
    updateSelectInput(session, "var_grupo", choices = names(datos()))
    updateSelectInput(session, "var1_wilcoxon", choices = names(datos()))
    updateSelectInput(session, "var2_wilcoxon", choices = names(datos()))
    updateSelectInput(session, "var1_cor", choices = names(datos()))
    updateSelectInput(session, "var2_cor", choices = names(datos()))
  })
  
  # t-Student
  resultado_t <- eventReactive(input$analizar_t, {
    req(datos())
    t.test(datos()[[input$var1_t]], datos()[[input$var2_t]])
  })
  
  # Chi-cuadrado
  resultado_chi <- eventReactive(input$analizar_chi, {
    req(datos())
    tabla <- table(datos()[[input$var_chi]])
    chisq.test(tabla)
  })
  
  # McNemar
  resultado_mcnemar <- eventReactive(input$analizar_mcnemar, {
    req(datos())
    mcnemar.test(table(datos()[[input$var1_mcnemar]], datos()[[input$var2_mcnemar]]))
  })
  
  # ANOVA
  output$var_num_ui <- renderUI({
    req(datos())
    selectInput("var_num", "Variable numérica:", choices = names(datos()))
  })
  
  output$var_grupo_ui <- renderUI({
    req(datos())
    selectInput("var_grupo", "Variable de grupo (3 o más categorías):", choices = names(datos()))
  })
  
  resultado_anova <- eventReactive(input$analizar_anova, {
    req(datos())
    aov(formula = as.formula(paste(input$var_num, "~", input$var_grupo)), data = datos())
  })
  
  # Wilcoxon
  output$var1_wilcoxon_ui <- renderUI({
    req(datos())
    if (input$tipo_wilcoxon == "Pareada") {
      selectInput("var1_wilcoxon", "Variable antes:", choices = names(datos()))
    } else {
      selectInput("var1_wilcoxon", "Variable numérica:", choices = names(datos()))
    }
  })
  
  output$var2_wilcoxon_ui <- renderUI({
    req(datos())
    if (input$tipo_wilcoxon == "Pareada") {
      selectInput("var2_wilcoxon", "Variable después:", choices = names(datos()))
    } else {
      selectInput("var2_wilcoxon", "Variable de grupo (2 grupos):", choices = names(datos()))
    }
  })
  
  resultado_wilcoxon <- eventReactive(input$analizar_wilcoxon, {
    req(datos())
    if (input$tipo_wilcoxon == "Pareada") {
      wilcox.test(
        x = datos()[[input$var1_wilcoxon]],
        y = datos()[[input$var2_wilcoxon]],
        paired = TRUE
      )
    } else {
      wilcox.test(
        formula = as.formula(paste(input$var1_wilcoxon, "~", input$var2_wilcoxon)),
        data = datos()
      )
    }
  })
  
  # Correlación
  output$var1_cor_ui <- renderUI({
    req(datos())
    selectInput("var1_cor", "Variable 1:", choices = names(datos()))
  })
  
  output$var2_cor_ui <- renderUI({
    req(datos())
    selectInput("var2_cor", "Variable 2:", choices = names(datos()))
  })
  
  resultado_cor <- eventReactive(input$analizar_cor, {
    req(datos())
    cor.test(datos()[[input$var1_cor]], datos()[[input$var2_cor]], method = input$metodo_cor)
  })
  
  # Output según la prueba seleccionada
  output$resultado <- renderPrint({
    if (input$prueba == "t-Student") {
      req(resultado_t())
      resultado_t()
    } else if (input$prueba == "Chi-cuadrado") {
      req(resultado_chi())
      resultado_chi()
    } else if (input$prueba == "McNemar") {
      req(resultado_mcnemar())
      resultado_mcnemar()
    } else if (input$prueba == "ANOVA") {
      req(resultado_anova())
      summary(resultado_anova())
    } else if (input$prueba == "Wilcoxon") {
      req(resultado_wilcoxon())
      resultado_wilcoxon()
    } else if (input$prueba == "Correlación") {
      req(resultado_cor())
      resultado_cor()
    }
  })
  
  output$interpretacion <- renderPrint({
    if (input$prueba == "t-Student") {
      req(resultado_t())
      p <- resultado_t()$p.value
      if (p < 0.05) {
        cat("El valor p es", round(p, 4), "\nSe rechaza la hipótesis nula. Hay una diferencia significativa.")
      } else {
        cat("El valor p es", round(p, 4), "\nNo se rechaza la hipótesis nula. No hay diferencia significativa.")
      }
    } else if (input$prueba == "Chi-cuadrado") {
      req(resultado_chi())
      p <- resultado_chi()$p.value
      if (p < 0.05) {
        cat("El valor p es", round(p, 4), "\nSe rechaza la hipótesis nula. Hay una asociación significativa.")
      } else {
        cat("El valor p es", round(p, 4), "\nNo se rechaza la hipótesis nula. No hay asociación significativa.")
      }
    } else if (input$prueba == "McNemar") {
      req(resultado_mcnemar())
      p <- resultado_mcnemar()$p.value
      if (p < 0.05) {
        cat("El valor p es", round(p, 4), "\nSe rechaza la hipótesis nula. Los dos grupos difieren significativamente.")
      } else {
        cat("El valor p es", round(p, 4), "\nNo se rechaza la hipótesis nula. No hay diferencia significativa.")
      }
    } else if (input$prueba == "ANOVA") {
      req(resultado_anova())
      p <- summary(resultado_anova())[[1]]["Pr(>F)"]
      if (p < 0.05) {
        cat("El valor p es", round(p, 4), "\nSe rechaza la hipótesis nula. Hay diferencias significativas entre los grupos.")
      } else {
        cat("El valor p es", round(p, 4), "\nNo se rechaza la hipótesis nula. No hay diferencias significativas.")
      }
    } else if (input$prueba == "Wilcoxon") {
      req(resultado_wilcoxon())
      p <- resultado_wilcoxon()$p.value
      if (p < 0.05) {
        cat("El valor p es", round(p, 4), "\nSe rechaza la hipótesis nula. Hay una diferencia significativa.")
      } else {
        cat("El valor p es", round(p, 4), "\nNo se rechaza la hipótesis nula. No hay diferencia significativa.")
      }
    } else if (input$prueba == "Correlación") {
      req(resultado_cor())
      p <- resultado_cor()$p.value
      if (p < 0.05) {
        cat("El valor p es", round(p, 4), "\nSe rechaza la hipótesis nula. Hay una correlación significativa.")
      } else {
        cat("El valor p es", round(p, 4), "\nNo se rechaza la hipótesis nula. No hay correlación significativa.")
      }
    }
  })
  
  output$grafico <- renderPlot({
    req(datos())
    if (input$prueba == "t-Student") {
      ggplot(datos(), aes(x = .data[[input$var1_t]], y = .data[[input$var2_t]])) +
        geom_point() +
        stat_smooth(method = "lm", se = FALSE, color = "blue") +
        theme_minimal()
    } else if (input$prueba == "Chi-cuadrado") {
      ggplot(datos(), aes(x = .data[[input$var_chi]])) +
        geom_bar(fill = "skyblue") +
        theme_minimal()
    } else if (input$prueba == "McNemar") {
      ggplot(datos(), aes(x = .data[[input$var1_mcnemar]])) +
        geom_bar(fill = "lightgreen") +
        theme_minimal()
    } else if (input$prueba == "ANOVA") {
      ggplot(datos(), aes(x = .data[[input$var_grupo]], y = .data[[input$var_num]])) +
        geom_boxplot() +
        theme_minimal()
    } else if (input$prueba == "Wilcoxon") {
      ggplot(datos(), aes(x = .data[[input$var1_wilcoxon]], y = .data[[input$var2_wilcoxon]])) +
        geom_point() +
        stat_smooth(method = "lm", se = FALSE, color = "red") +
        theme_minimal()
    } else if (input$prueba == "Correlación") {
      ggplot(datos(), aes(x = .data[[input$var1_cor]], y = .data[[input$var2_cor]])) +
        geom_point() +
        stat_smooth(method = "lm", se = FALSE, color = "orange") +
        theme_minimal()
    }
  })
}

shinyApp(ui = ui, server = server)
