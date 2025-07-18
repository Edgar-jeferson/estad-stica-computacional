library(shiny)
library(shinydashboard)

# Constantes del juego
CARAMEL_TYPES <- c('limón', 'huevo', 'pera')
DEFAULT_PEOPLE <- 10

# Funciones del juego optimizadas
can_make_chupetin <- function(inv) {
  return(inv$limon >= 2 & inv$huevo >= 2 & inv$pera >= 2)
}

# Función optimizada para calcular la mejor estrategia
get_optimal_strategy <- function(inv, objetivo_chupetines) {
  # Calcular cuántos chupetines podemos hacer directamente
  chupetines_posibles <- min(floor(inv$limon/2), floor(inv$huevo/2), floor(inv$pera/2))
  
  if(chupetines_posibles >= objetivo_chupetines) {
    return(list(accion = "hacer", cantidad = objetivo_chupetines))
  }
  
  # Si no alcanza, calcular el déficit total
  total_actual <- inv$limon + inv$huevo + inv$pera
  chupetines_faltantes <- objetivo_chupetines - chupetines_posibles
  
  # Cada chupetín requiere 6 caramelos base (2 de cada tipo)
  # Al hacerlo obtenemos 2 caramelos extra
  # Costo neto: 4 caramelos por chupetín
  caramelos_necesarios <- chupetines_faltantes * 4
  
  # Calcular déficit por tipo para llegar al mínimo balanceado
  min_por_tipo <- ceiling((total_actual + caramelos_necesarios) / 3)
  deficit <- list(
    limon = max(0, min_por_tipo - inv$limon),
    huevo = max(0, min_por_tipo - inv$huevo),
    pera = max(0, min_por_tipo - inv$pera)
  )
  
  total_deficit <- deficit$limon + deficit$huevo + deficit$pera
  intercambios_necesarios <- ceiling(total_deficit / 6)
  
  return(list(
    accion = "vender",
    cantidad = intercambios_necesarios,
    deficit = deficit,
    estrategia_compra = get_purchase_strategy(deficit)
  ))
}

# Estrategia inteligente para comprar caramelos
get_purchase_strategy <- function(deficit) {
  # Priorizar los tipos con mayor déficit
  tipos_ordenados <- names(sort(unlist(deficit), decreasing = TRUE))
  estrategia <- c()
  
  for(tipo in tipos_ordenados) {
    if(deficit[[tipo]] > 0) {
      estrategia <- c(estrategia, rep(tipo, deficit[[tipo]]))
    }
  }
  
  return(estrategia)
}

# Función optimizada para hacer chupetín con estrategia inteligente
make_chupetin_optimized <- function(inv, pasos, objetivo_chupetines, intercambios_count) {
  inv$limon <- inv$limon - 2
  inv$huevo <- inv$huevo - 2
  inv$pera <- inv$pera - 2
  
  # Incrementar contador de intercambios (hacer chupetín es un intercambio)
  intercambios_count <- intercambios_count + 1
  
  # Estrategia optimizada para caramelos extra
  chupetines_actuales <- floor(min(inv$limon/2, inv$huevo/2, inv$pera/2))
  
  if(chupetines_actuales + 1 < objetivo_chupetines) {
    # Necesitamos optimizar para futuros chupetines
    deficit <- list(
      limon = max(0, 2 - inv$limon),
      huevo = max(0, 2 - inv$huevo),
      pera = max(0, 2 - inv$pera)
    )
    
    # Priorizar los tipos con mayor déficit
    tipos_priorizados <- names(sort(unlist(deficit), decreasing = TRUE))
    extra <- c()
    
    for(tipo in tipos_priorizados) {
      if(length(extra) < 2 && deficit[[tipo]] > 0) {
        cantidad <- min(deficit[[tipo]], 2 - length(extra))
        extra <- c(extra, rep(tipo, cantidad))
      }
    }
    
    # Completar con balanceado si es necesario
    while(length(extra) < 2) {
      # Elegir el tipo con menor cantidad actual
      cantidades <- c(limon = inv$limon, huevo = inv$huevo, pera = inv$pera)
      for(tipo_extra in extra) {
        cantidades[[tipo_extra]] <- cantidades[[tipo_extra]] + 1
      }
      tipo_minimo <- names(which.min(cantidades))
      extra <- c(extra, tipo_minimo)
    }
  } else {
    # Ya tenemos suficientes, balancear inventario
    cantidades <- c(limon = inv$limon, huevo = inv$huevo, pera = inv$pera)
    tipos_ordenados <- names(sort(cantidades))
    extra <- rep(tipos_ordenados[1:2], length.out = 2)
  }
  
  # Actualizar inventario
  for(caramelo in extra) {
    inv[[caramelo]] <- inv[[caramelo]] + 1
  }
  
  paso <- paste("🍭 INTERCAMBIO: Se hizo 1 chupetín (usando 2 limón, 2 huevo, 2 pera) y se recibieron 2 caramelos extra:", 
                paste(extra, collapse = ", "))
  pasos <<- c(pasos, paso)
  
  return(list(inv = inv, chupetines = 1, intercambios = intercambios_count))
}

# Función optimizada para vender chupetín
vender_chupetin_optimized <- function(inv, pasos, objetivo_chupetines, intercambios_count) {
  # Incrementar contador de intercambios (vender chupetín es un intercambio)
  intercambios_count <- intercambios_count + 1
  
  # Calcular déficit actual para llegar al objetivo
  chupetines_posibles <- min(floor(inv$limon/2), floor(inv$huevo/2), floor(inv$pera/2))
  
  if(chupetines_posibles >= objetivo_chupetines) {
    # Ya no necesitamos vender, esto no debería ocurrir
    return(list(inv = inv, intercambios = intercambios_count))
  }
  
  # Calcular cuántos caramelos necesitamos de cada tipo
  deficit <- list(
    limon = max(0, 2 - inv$limon),
    huevo = max(0, 2 - inv$huevo),
    pera = max(0, 2 - inv$pera)
  )
  
  # Estrategia inteligente: priorizar déficits y balancear
  elegidos <- c()
  tipos_priorizados <- names(sort(unlist(deficit), decreasing = TRUE))
  
  # Primero, cubrir déficits críticos
  for(tipo in tipos_priorizados) {
    if(length(elegidos) < 6 && deficit[[tipo]] > 0) {
      cantidad <- min(deficit[[tipo]], 6 - length(elegidos))
      elegidos <- c(elegidos, rep(tipo, cantidad))
    }
  }
  
  # Luego, balancear el resto
  while(length(elegidos) < 6) {
    cantidades_proyectadas <- c(
      limon = inv$limon + sum(elegidos == "limón"),
      huevo = inv$huevo + sum(elegidos == "huevo"),
      pera = inv$pera + sum(elegidos == "pera")
    )
    tipo_minimo <- names(which.min(cantidades_proyectadas))
    elegidos <- c(elegidos, tipo_minimo)
  }
  
  # Actualizar inventario
  for(caramelo in elegidos) {
    inv[[caramelo]] <- inv[[caramelo]] + 1
  }
  
  paso <- paste("💰 INTERCAMBIO: Se cambio 1 chupetín para recibir 6 caramelos (estrategia optimizada):", 
                paste(elegidos, collapse = ", "))
  pasos <<- c(pasos, paso)
  
  return(list(inv = inv, intercambios = intercambios_count))
}

# Simulación optimizada completa
simular_juego_optimizado <- function(num_people) {
  pasos <<- c()
  
  # Reparto inicial
  people_candies <- lapply(1:num_people, function(x) sample(CARAMEL_TYPES, 2, replace = TRUE))
  all_candies <- unlist(people_candies)
  
  inventory <- list(
    limon = sum(all_candies == "limón"),
    huevo = sum(all_candies == "huevo"),
    pera = sum(all_candies == "pera")
  )
  
  chupetines <- 0
  intercambios <- 0
  objetivo <- num_people
  
  pasos <<- c(pasos, "🎯 INICIO DEL JUEGO (ESTRATEGIA OPTIMIZADA)")
  pasos <<- c(pasos, paste("👥 Número de personas:", num_people))
  pasos <<- c(pasos, paste("🎯 Objetivo: conseguir", objetivo, "chupetines"))
  pasos <<- c(pasos, "")
  pasos <<- c(pasos, "📋 REPARTO INICIAL:")
  
  for(i in 1:length(people_candies)) {
    pasos <<- c(pasos, paste("Persona", i, ":", paste(people_candies[[i]], collapse = ", ")))
  }
  
  pasos <<- c(pasos, "")
  pasos <<- c(pasos, paste("📦 Inventario inicial - Limón:", inventory$limon, 
                           "| Huevo:", inventory$huevo, "| Pera:", inventory$pera))
  
  # Análisis inicial de estrategia
  estrategia <- get_optimal_strategy(inventory, objetivo)
  pasos <<- c(pasos, "")
  pasos <<- c(pasos, "🧠 ANÁLISIS ESTRATÉGICO:")
  
  chupetines_directos <- min(floor(inventory$limon/2), floor(inventory$huevo/2), floor(inventory$pera/2))
  pasos <<- c(pasos, paste("📊 Chupetines que se pueden hacer directamente:", chupetines_directos))
  
  if(estrategia$accion == "vender") {
    pasos <<- c(pasos, paste("💡 Se necesitan", estrategia$cantidad, "intercambios para alcanzar el objetivo"))
    pasos <<- c(pasos, paste("🎯 Déficit por tipo - Limón:", estrategia$deficit$limon, 
                             "| Huevo:", estrategia$deficit$huevo, "| Pera:", estrategia$deficit$pera))
  } else {
    pasos <<- c(pasos, "✅ Se puede alcanzar el objetivo sin intercambios")
  }
  
  pasos <<- c(pasos, "")
  pasos <<- c(pasos, "🔄 EJECUCIÓN:")
  
  # Hacer chupetines iniciales
  while(can_make_chupetin(inventory)) {
    resultado <- make_chupetin_optimized(inventory, pasos, objetivo, intercambios)
    inventory <- resultado$inv
    chupetines <- chupetines + resultado$chupetines
    intercambios <- resultado$intercambios
    
    if(chupetines >= objetivo) break
  }
  
  # Intercambios optimizados si es necesario
  while(chupetines < objetivo) {
    if(chupetines == 0) {
      pasos <<- c(pasos, "⛔ No se pueden hacer más chupetines ni vender.")
      break
    }
    
    resultado_venta <- vender_chupetin_optimized(inventory, pasos, objetivo, intercambios)
    inventory <- resultado_venta$inv
    intercambios <- resultado_venta$intercambios
    chupetines <- chupetines - 1
    
    # Hacer todos los chupetines posibles después del intercambio
    while(can_make_chupetin(inventory) && chupetines < objetivo) {
      resultado <- make_chupetin_optimized(inventory, pasos, objetivo, intercambios)
      inventory <- resultado$inv
      chupetines <- chupetines + resultado$chupetines
      intercambios <- resultado$intercambios
    }
  }
  
  # Resultados finales
  pasos <<- c(pasos, "")
  pasos <<- c(pasos, "📊 RESULTADOS FINALES:")
  pasos <<- c(pasos, paste("📦 Inventario final - Limón:", inventory$limon, 
                           "| Huevo:", inventory$huevo, "| Pera:", inventory$pera))
  pasos <<- c(pasos, paste("🍭 Chupetines totales:", chupetines))
  pasos <<- c(pasos, paste("🔁 Total de intercambios realizados:", intercambios))
  pasos <<- c(pasos, paste("   - Hacer chupetines:", sum(grepl("🍭 INTERCAMBIO", pasos))))
  pasos <<- c(pasos, paste("   - Vender chupetines:", sum(grepl("💰 INTERCAMBIO", pasos))))
  pasos <<- c(pasos, "")
  
  resultado_final <- if(chupetines >= objetivo) {
    eficiencia <- if(intercambios <= (chupetines + (if(estrategia$accion == "vender") estrategia$cantidad else 0))) "ÓPTIMA" else "BUENA"
    paste("✅ ¡OBJETIVO LOGRADO! Eficiencia:", eficiencia)
  } else {
    "❌ OBJETIVO NO LOGRADO."
  }
  
  pasos <<- c(pasos, resultado_final)
  
  return(list(
    chupetines = chupetines,
    intercambios = intercambios,
    inventory = inventory,
    people_candies = people_candies,
    exito = chupetines >= objetivo,
    pasos = pasos,
    intercambios_teoricos = chupetines + (if(estrategia$accion == "vender") estrategia$cantidad else 0),
    eficiencia = if(chupetines >= objetivo) {
      if(intercambios <= (chupetines + (if(estrategia$accion == "vender") estrategia$cantidad else 0))) "ÓPTIMA" 
      else "BUENA"
    } else "FALLIDA"
  ))
}

# UI (sin el cuadro de optimizaciones implementadas)
ui <- dashboardPage(
  dashboardHeader(title = "Juego de Intercambio"),
  
  dashboardSidebar(disable = TRUE),
  
  dashboardBody(
    tags$head(
      tags$style(HTML("
        .main-header .logo { 
          font-weight: bold; 
          font-size: 18px; 
          background-color: #2c3e50 !important;
          color: #ecf0f1 !important;
        }
        .main-header .navbar {
          background-color: #2c3e50 !important;
        }
        .box-title { 
          font-weight: bold; 
          color: #2c3e50;
        }
        .content-wrapper, .right-side { 
          background-color: #ecf0f1; 
        }
        .box.box-primary {
          border-top-color: #34495e;
        }
        .box.box-primary > .box-header {
          background: #34495e;
          color: #ecf0f1;
        }
        .box.box-info {
          border-top-color: #5d6d7e;
        }
        .box.box-info > .box-header {
          background: #5d6d7e;
          color: #ecf0f1;
        }
        .box.box-success {
          border-top-color: #27ae60;
        }
        .box.box-success > .box-header {
          background: #27ae60;
          color: #ecf0f1;
        }
        .box.box-warning {
          border-top-color: #f39c12;
        }
        .box.box-warning > .box-header {
          background: #f39c12;
          color: #ecf0f1;
        }
        .efficiency-optimal { background-color: #d4edda; border: 1px solid #28a745; color: #28a745; }
        .efficiency-good { background-color: #fff3cd; border: 1px solid #ffc107; color: #856404; }
        .efficiency-failed { background-color: #f8d7da; border: 1px solid #dc3545; color: #dc3545; }
      "))
    ),
    
    fluidRow(
      box(width = 4, status = "primary", solidHeader = TRUE, title = "⚙️ Configuración del Juego",
          numericInput("num_people", "👥 Número de personas:", 
                       value = DEFAULT_PEOPLE, min = 1, max = 50, step = 1),
          
          br(),
          actionButton("simular", "EMPEZAR SIMULACION", 
                       class = "btn-primary btn-lg", style = "width: 100%;"),
          
          
      ),
      
      box(width = 8, status = "info", solidHeader = TRUE, title = "📊 Inventario de Caramelos",
          tableOutput("inventory_table")
      )
    ),
    
    fluidRow(
      box(width = 6, status = "success", solidHeader = TRUE, title = "👥 Reparto Inicial por Persona",
          tableOutput("people_table")
      ),
      
      box(width = 6, status = "warning", solidHeader = TRUE, title = "📈 Análisis de Eficiencia",
          verbatimTextOutput("efficiency_analysis")
      )
    ),
    
    fluidRow(
      box(width = 12, status = "primary", solidHeader = TRUE, title = "📝 Detalles Paso a Paso",
          verbatimTextOutput("game_details", placeholder = TRUE)
      )
    )
  )
)

# Server (con las funciones optimizadas)
server <- function(input, output, session) {
  game_result <- reactiveVal(NULL)
  
  observeEvent(input$simular, {
    resultado <- simular_juego_optimizado(input$num_people)
    game_result(resultado)
  })
  
  # Tabla de inventario
  output$inventory_table <- renderTable({
    if(is.null(game_result())) {
      return(data.frame(
        Estado = c("Inicial", "Final"),
        Limón = c("-", "-"),
        Huevo = c("-", "-"),
        Pera = c("-", "-"),
        stringsAsFactors = FALSE
      ))
    }
    
    resultado <- game_result()
    
    # Calcular inventario inicial
    inicial <- unlist(lapply(resultado$people_candies, function(x) table(factor(x, levels = CARAMEL_TYPES))))
    inicial_counts <- c(
      sum(inicial[seq(1, length(inicial), 3)]),  # limón
      sum(inicial[seq(2, length(inicial), 3)]),  # huevo  
      sum(inicial[seq(3, length(inicial), 3)])   # pera
    )
    
    data.frame(
      Estado = c("📦 Inicial", "📦 Final"),
      Limón = c(inicial_counts[1], resultado$inventory$limon),
      Huevo = c(inicial_counts[2], resultado$inventory$huevo),
      Pera = c(inicial_counts[3], resultado$inventory$pera),
      stringsAsFactors = FALSE
    )
  }, striped = TRUE, hover = TRUE, bordered = TRUE)
  
  # Tabla de personas
  output$people_table <- renderTable({
    if(is.null(game_result())) {
      return(data.frame(Persona = "Ejecuta una simulación", Caramelos = "para ver los datos"))
    }
    
    resultado <- game_result()
    
    personas_df <- data.frame(
      Persona = paste("👤", 1:length(resultado$people_candies)),
      Caramelos = sapply(resultado$people_candies, function(x) paste(x, collapse = ", ")),
      stringsAsFactors = FALSE
    )
    
    return(personas_df)
  }, striped = TRUE, hover = TRUE, bordered = TRUE)
  
  # Análisis de eficiencia
  output$efficiency_analysis <- renderText({
    if(is.null(game_result())) {
      return("Ejecuta una simulación para ver el análisis de eficiencia.")
    }
    
    resultado <- game_result()
    
    paste(
      paste("Personas participantes:", input$num_people),
      paste("Chupetines obtenidos:", resultado$chupetines),
      paste("Intercambios realizados:", resultado$intercambios),
      paste("Intercambios teóricos mínimos:", resultado$intercambios_teoricos),
      paste("Eficiencia:", resultado$eficiencia),
      "",
      paste("Objetivo logrado:", if(resultado$exito) "SÍ ✅" else "NO ❌"),
      "",
      if(resultado$exito) {
        if(resultado$eficiencia == "ÓPTIMA") {
          "🎯 ¡Perfecto! Se usó la cantidad óptima de intercambios."
        } 
      } else {
        paste("Faltan", input$num_people - resultado$chupetines, "chupetines.")
      },
      sep = "\n"
    )
  })
  
  # Detalles paso a paso
  output$game_details <- renderText({
    if(is.null(game_result())) {
      return("Ejecuta una simulación para ver los detalles paso a paso del juego optimizado.")
    }
    
    paste(game_result()$pasos, collapse = "\n")
  })
}

shinyApp(ui = ui, server = server)