# ==== rutinas para traducción ====
# hacks para que md2po funcione con rmd's
# https://github.com/SciViews/rmdpo

# Funciones varias para la traducción de viñetas

# requiere:

#   rmd2po.R (con modificaciones para que funcione con ttk 3.13)
#   reticulate (si md2po se instala en un entorno conda o venv)
#
# Workflow:
#    Por ahora no trabajamos con .POT pero convendría para mantener
#    las viñetas.
#   
#    0) generar_po_desde_rmd_en_ingles()
#      -  los .PO se generan (si no existen) con esta rutina.
#    1) traducir los archivos .PO con su herramienta preferida (o leer  y
#           usar .combinar_plain_txt_en_po)
#    2) convertir_po_a_rmd() 
#    3) traducir_titulos_rmd()
#    4) generar_viñetas_html()
#

# # TODO: en windows requiere msgcat, por ejemplo el que viene con git.
# if (.Platform$OS.type == "windows") Sys.setenv("PATH" = paste0(
#   sep = .Platform$file.sep, Sys.getenv("PATH"), 
#   "c:\\apps\\git\\mingw64\\bin",
#   "c:\\apps\\git\\bin"))


## ---- funciones auxiliares ----

# dada la posición de espacios en una cadena, devuelve las
# posicones en que hay que saltar la línea para limitarla
# a wd caracteres (wd - 2 ya que considera comillas) 
# siempre sobre espacios en blanco, salvo palabras > wd largas .
wrap_msg <- function(m, wd = 80, p = 0) {
  if (length(x <- which(m > p & m < wd - 2 + p)))
    c(p, wrap_msg(m, wd, m[x[length(x)]]))
  else if (any(m > p))
    c(p, wrap_msg(m, wd, wd - 2 + p))
  else if (m[length(m)] == p + 1)
    integer()
  else p
}
#debug(wrap_msg)
# Función auxiliar para sustitución con regmatches<-
regex_sub <- function(x, pattern, ...) {
  matches <- regexec(pattern, x)
  drop_first <- function(x) {
    if(!anyNA(x) && all(x > 0)) {
      ml <- attr(x, 'match.length')
      if(is.matrix(x)) x <- x[-1,] else x <- x[-1]
      attr(x, 'match.length') <- if(is.matrix(ml)) ml[-1,] else ml[-1]
    }
    x
  }
  regmatches(x, lapply(matches, drop_first)) <- Map(f = c, ...)
  x
}

# Obtiene los nro de lineas o el valor de las líneas de una entrada de un PO
get_po_msgs <- function(lines_po, type = c("msgid", "msgstr"), ret = c("position", "value")) {
  type <- match.arg(type)
  ret <- match.arg(ret)
  EOF <- length(lines_po) + 1
  msgid_pos <- c(grep(paste0("^\\s*", type, "\\s+\""), lines_po), EOF)
  str_pos <- grep("\\s*\"", lines_po)
  no_str_pos <- c(grep("^\\s*[^\"#]", lines_po), EOF) 
  .mapply(
    list(head(msgid_pos, -1), tail(msgid_pos, -1)),
    FUN = \(d, h) {
      l <- str_pos[str_pos >= d & str_pos < min(h, no_str_pos[no_str_pos > d])]
      if (ret == "position") l else 
        paste0(collapse = "", sub(
          "^\\s*(msg(id(_plural)?|str( *\\[ *\\d+ *\\])?))?\\s*\"(([^\"]|([\\]\"))*)\"\\s*(#.*)?$",
          "\\5", lines_po[l])) },
    MoreArgs = NULL)
}

# Script para cargar los archivos .txt generados en los po originales
# los txt se generan ocn el script siguiente :
# find *.po -exec sh -c "msggrep --no-wrap -Ke '' {} | sed -nE '/^$|(msgid)/p' | sed -E 's/^msgid \\\"(.*)\\\"/\\1/' > {}.txt" \;
# al estar línea por línea soin más faciles de traducir masivamente 
# (aunque puede tener algún prolema con los escapees tipo \n)
# por ejemplo cargando en GITHUB y luego pedirle a google que
# traduzca el link RAW
# Otra forma:
# # REQUIERE: (mingw) (usa echo -n. Yo usé el de GIT)
# # CUIDADO: Elimina toda la traducción del PO.
# esto es para poner topes en el largo de línea
# cmd <- paste("msgcat", "--no-wrap", "-o", shQuote(po_files[i]), shQuote(po_files[i]))
# rslt <- system(cmd)
# if (attr(rslt, "status") %||% 0 != 0)
#   stop(attr(rslt, "errmsg") %||% "status <> 0")
#  OTRA Forma:
# hecho en R.
#
## Si le quiero agregar backup...
# if (!file.copy(po_files[i], paste0(po_files[i], ".bak"), overwrite = F))
#   stop(
#     "No se pudo crear copia de seguridad (",
#     paste0(po_files[i], ".bak"), "). ",
#     "(Quizá deba borrar los archivos .bak existentes)"
#   )
#
# Sin wrapping (luego requiere gettext tools):  
#   lines_po[msgstr_pos] <- paste0("msgstr \"", lines_txt, "\"")
#        msgstr_pos <- grep("^\\s+msgstr \"\"", lines_po)[-1]

# msgid o str : "^\\s*(msg(id|id_plural|str)(\\[\\d*\\])?)?\\s*\"(([^\"]|\\\\.)*)\".*", 

extrae_msgid_de_po <- function(files.po, files.txt) {
  for (i in seq_along(files.po)) {
    lines <- grep(
      pattern = "^\\s*(\"|msgid)", value= TRUE, readLines(files.po[i]))
    msgids <- grep("^\\s*msgid(_plural)?", lines)
    grps <- cut(seq_along(lines), c(msgids, Inf), labels = FALSE, right = FALSE)
    text <- vapply(seq_along(msgids), "", FUN = function(j) paste0(sub(
      "^\\s*(msgid(_plural)?)?\\s*\"(([^\"]|\\\\.)*)\".*", "\\3", 
      lines[grps == j]), collapse = ""))
    writeLines(text[grep("^\\s*msgid", lines[msgids])], files.txt[i])
  }
}

# toma los archivos txt linea por linea y los incorpora a las
# entradas "msgstr" del PO, partiendo lineas largas si es necesario
#debugonce(combinar_plain_txt_en_po)
combinar_plain_txt_en_po <- function(po_txt_files, po_files) {
  browser()
  for (i in seq_along(po_files)) {
    message(sprintf(
      "Combinando %s en %s", basename(po_txt_files[i]), basename(po_files[i])))
    tryCatch(
      {
        lines_po <- readLines(po_files[i])
        lines_txt <- readLines(po_txt_files[i]) |>
          # escapa las comillas
          gsub(pattern = "(?<!\\\\)\"", replacement = "\\\\\"", perl = TRUE) |>
          # Si la primera linea está vacía la suprime
          (\(l) subset(l, nzchar(l[1]) | seq_along(l) > 1))()

        # msgstr_pos es la posición de los msgstr en el po
        # other_pos es la posición de todo el resto
        
        # la primera línea de msgstr es el encabezado del PO. No se incluye.
        msgstr_pos <- get_po_msgs(lines_po, "msgstr", "position")[-1]
        other_pos <- .mapply(seq, MoreArgs = NULL, list(
          c(0, vapply(msgstr_pos, max, 0L) + 1L),
          c(vapply(msgstr_pos, min, 0L) - 1L, length(lines_po) + 1L)))

        # los .po y los archivos planos deben tener el mismo nro de elementos
        n <- length(msgstr_pos)
        if (n != length(lines_txt)) {
          stop(errorCondition(
            sprintf(
              "el archivo %s tiene %d líneas, mientras que %s tiene %d líneas",
              po_files[i], n, po_txt_files[i], length(lines_txt)),
            call = sys.call(),
            class = "length.mismatch"
          ))
        }
        
        # saltos de línea en lineas largas wd <- 80
        msgstr <- lapply(lines_txt, FUN = \(x) {
          m <- gregexpr("\\s(?=\\S)|$", x, perl = T)[[1]]
          if (nchar(x) <= 80 - nchar("msgstr") - 2) {
            paste0("msgstr ","\"", x, "\"")  
          } else {
            cuts <- wrap_msg(m, wd = 80)
            c("msgstr \"\"", paste0(
              '"', substring(x, cuts[-length(cuts)] + 1, cuts[-1]), '"'))
          }
        })

        other <- lapply(other_pos, \(s) lines_po[s])
        
        # intercalar n elementos con m=n+1 elementos.
        # 1, m+1, 2, m+2, 3, m+3 ... 
        ord <- seq(0, (n+1) * (2*n), n+1) %% (2*n+1) + 1
        lines_po <- c(other, msgstr)[ord]
        #browser()
        writeLines(unlist(lines_po), po_files[i])
      },
      length.mismatch = function(e) {
        tryCatch(
          {
            plain_english <- get_po_msgs(lines_po, "msgid", "value")
            writeLines(plain_english, paste0(po_files[i], ".msgid.txt"))
            stop(errorCondition(
              sprintf(
                "El texto de los msgid (en inglés) extraídos de %s se guardó en %s", 
                po_files[i], paste0(po_files[i],".msgid.txt")),
              call = conditionCall(e)))
          },
          error = function(f) stop(errorCondition(
            paste0(conditionMessage(e), "\n", conditionMessage(f)),
            call = conditionCall(f)))
        )
      },
      # Para personalizar error
      error = function(e) stop(errorCondition(
        sprintf("%s", conditionMessage(e)),
        call = conditionCall(e)))
    )
  }
}

# Actualiza la metadata en PO (fecha de revisión, Last translator...)
actualizar_po_metadata <- function(name, email) {
  pwd <- getwd()
  on.exit(setwd(pwd))
  setwd("es/po")
  po_files  <- dir(pattern=".po$")
  lapply(po_files, \(i) {
    lines <- readLines(i)
    lines |> 
      regex_sub("\"Project-Id-Version: (.*)\\\\n\"", "0.0.1") |>
      regex_sub("\"PO-Revision-Date: (.*)\\\\n\"", format(Sys.time(), format = "%Y-%m-%d %H:%M%z")) |>
      regex_sub("\"Last-Translator: (.*)\\\\n\"",  sprintf("%s <%s>", name, email)) |>
      regex_sub("\"Language-Team: (.*)\\\\n\"", "es")  |> 
      append("\"Language: es\\n\"", after = grep("\"Language-Team: (.*)\\\\n\"", lines)) |>
      writeLines(i)
  })
  invisible()
}


# Aquí: Script provisorio para traducir los títulos
traducir_titulos_rmd <- function() {
  pwd <- getwd()
  on.exit(setwd(pwd))
  setwd("es")
  
  titles_en <-
    c(`datatable-benchmarking.Rmd` = "Benchmarking data.table", 
      `datatable-faq.Rmd` = "Frequently Asked Questions about data.table", 
      `datatable-importing.Rmd` = "Importing data.table", 
      `datatable-intro.Rmd` = "Introduction to data.table", 
      `datatable-keys-fast-subset.Rmd` = "Keys and fast binary search based subset", 
      `datatable-programming.Rmd` = "Programming on data.table", 
      `datatable-reference-semantics.Rmd` = "Reference semantics", 
      `datatable-reshape.Rmd` = "Efficient reshaping using data.tables", 
      `datatable-sd-usage.Rmd` = "Using .SD for Data Analysis", 
      `datatable-secondary-indices-and-auto-indexing.Rmd` = "Secondary indices and auto indexing"
    )
  titles_es <- 
    c(`datatable-benchmarking.Rmd` = "Benchmarking con data.table", 
      `datatable-faq.Rmd` = "Preguntas frecuentes sobre data.table", 
      `datatable-importing.Rmd` = "Importar data.table", 
      `datatable-intro.Rmd` = "Introducción a data.table", 
      `datatable-keys-fast-subset.Rmd` = "Claves y filtrado rápido con búsqueda binaria", 
      `datatable-programming.Rmd` = "Programación en data.table", 
      `datatable-reference-semantics.Rmd` = "Semántica de referencia", 
      `datatable-reshape.Rmd` = "Remodelado eficiente con data.table", 
      `datatable-sd-usage.Rmd` = "Uso de .SD para Análisis de datos", 
      `datatable-secondary-indices-and-auto-indexing.Rmd` = "Índices secundarios y auto indexación"
    )
  title_missing <- 
    c("joins and rolling joins", "data.table internals")
  
  rmd_files  <- dir(pattern=".Rmd$")
  lapply(rmd_files, \(i) {
    if (i %in% names(titles_es)) {
      lines <- readLines(i) |>
        regex_sub("title: \"(.*)\"", titles_es[i]) 
      writeLines(lines, i)
    } else {warning(sprintf("título para %s no en titles_es", i))}
  })
}


# usa SELENIUM para traducir con google desde github
extraer_traducciones_con_selenium <- function(files, files_es, wait = .8) {
  while(TRUE) {
    try({
      selenium_driver <- RSelenium::rsDriver(
        browser = "chrome", check  = FALSE, extraCapabilities = list(
          chromeOptions = list(prefs = list(
            "profile.default_content_settings.popups" = 0L))))
      break
    })
    try({
      selenium_driver <- try(RSelenium::rsDriver())
      break
    })
    stop("No fue posible iniciar Selenium")
  }

  # Estos links vinculan a las traducciones de google
  google_urls <- paste0(
    "https://raw-githubusercontent-com.translate.goog/cienciadedatos/",
    "traduccion-vignettes-datatable/refs/heads/main/vignettes/",
    URLencode(files), "?_x_tr_sl=en&_x_tr_tl=es&_x_tr_hl=es&_x_tr_pto=wapp")

  tryCatch(
    error = \(e) message(e),
    finally = selenium_driver$server$stop,
    for (i in seq(files)) {
      selenium_driver$client$navigate(google_urls[i])
      selenium_driver$server$process$wait(1000 * wait)
      
      element <- selenium_driver$client$findElement(using="xpath", "/html/body/pre")
      if (!length(element))
        stop("Problema al analizar el documento con chromote ",
             "(no fue posible interpretar html de la traducción, pruebe mayor wait )")
      
      lines <- element$getElementText()[[1]] |> 
        strsplit("\n", fixed = TRUE) |> _[[1]]
      
      writeLines(lines, files_es[i])
      message("ok ", files_es[i]) 
    }
  ) 
  invisible()
}

# client$view() # para verlo en chrome
extraer_traducciones_con_chromote <- function(files, files_es, wait = .8) {
  client <- chromote::ChromoteSession$new()

  # Estos links vinculan a las traducciones de google
  google_urls <- paste0(
    "https://raw-githubusercontent-com.translate.goog/cienciadedatos/",
    "traduccion-vignettes-datatable/refs/heads/main/vignettes/",
    URLencode(files), "?_x_tr_sl=en&_x_tr_tl=es&_x_tr_hl=es&_x_tr_pto=wapp")
  
  tryCatch(
    for (i in seq(files)) {
      DOM <- client$DOM
      client$Page$navigate(google_urls[i])
      Sys.sleep(wait)
      doc.nodeId <- DOM$getDocument()[[1]]$nodeId
      sel.nodeId <- DOM$querySelector(
        nodeId = doc.nodeId, selector = "html > body > pre")[[1]]
      if (sel.nodeId == 0) {
        #browser()
        client$view()
        stop("Problema al analizar el documento con chromote ",
             "(no fue posible interpretar html de la traducción, pruebe mayor wait)")
      }
      lines <- DOM$getOuterHTML(sel.nodeId)[[1]] |>
        xml2::as_xml_document() |> xml2::xml_text() |>
        strsplit("\n", fixed = TRUE) |> _[[1]]
      writeLines(lines, files_es[i])
      message("ok ", files_es[i]) 
    },
    error = \(e) stop(e),
    finally = client$close()
  ) 
  invisible()
}



# ==== Inicio ====

## ---- paso (0) setup ----

message("Inicio ...")

if (basename(getwd()) == "vignettes" && !"./vignettes" %in% list.dirs()) 
  setwd("..")

basedir <- getwd()

if (!file.exists("rmd2po.R")) stop(
  "No se encuentra rmd2po.R (chequee que su directorio actual sea ",
  "traduccion-vignettes-datatable, la ubicación de rutinas.R y rmd2po.R")

source("rmd2po.R")


message("Cargar Python...")
library(reticulate)
py_available(TRUE)  # check for Python

tryCatch(
  {
    message("chequear que exista `mdpo`...")
    .check_mdpo() 
  }, error = function(e) {
    warning(conditionMessage(e))
    message("Instalar mdpo (si no está instalado)...")
    if(as.numeric_version(py_version()) > "3.11" 
       && .Platform$OS.type == "windows") warning(
         "-- AVISO: En windows, mdpo sólo está disponible hasta 3.11, ",
         "luego requiere compilación (visual studio toolchain)")
    py_install("mdpo", pip = TRUE)
  }
)

if (basename(getwd()) == "vignettes") {
  setwd("..")
  basedir <- getwd()
}

message("Cambiando a directorio «./vignettes»")
setwd(file.path(basedir, "vignettes"))


# Acá empieza el script.
# ~~~~~~~~~~~~~~~~~~~~~~

## ---- paso (1) generar PO's en inglés ----

## ---- paso (2) generar po desde rmd en ingles ----
message("Paso (2) generar_po_desde_rmd_en_ingles")
{
  rmd_files <- dir(,".Rmd$")
  if (!length(rmd_files)) stop("No se encontraron archivos para traducir")
  for (f in rmd_files) {
    rmd2po(f, lang = "es", verbose = TRUE)
  }  
}

## ---- paso (3) extrae texto de archivos PO ----
message("Paso (3) extrae texto de archivos PO")
{
  # extrae directo del PO para evitar msgcat, msggrep y programas
  # similares de gettext
  message("Extraer mensajes originales (inglés) de archivos PO y generar .txt ...")
  dir.create(file.path("es", "google-translations"), showWarnings = FALSE)
  files.po <- dir(file.path("es", "po"), "[.]po$", full.names = TRUE) 
  files.txt <- file.path(
    "es", "google-translations", basename(sub(paste0("-", "es", "[.]po$"), "-en.txt", files.po)))
  extrae_msgid_de_po(files.po, files.txt)
}

## ---- paso (4) subir estos txt al repo ----
# Hacer un commit en este punto o subir a github.
# para que google pueda traducirlo (método gratuito:;)

#      usethis::create_github_token()
#      githubr::get_git_auth()
#      usethis::gh_token_help()
#      gitcreds::gitcreds_cache_envvar()

message("Paso (4) subir estos txt al repo")

{
  GITHUB_PAT_prev <- Sys.getenv("GITHUB_PAT", unset = NA)
  PAT <- Sys.getenv("GITHUB_PAT_GITHUB_COM", unset = Sys.getenv("GITHUB_PAT"))
  Sys.setenv(GITHUB_PAT = PAT)  
  git_version <- try(silent = T, system2(
    "git", "--version", stdout = TRUE, stderr = nullfile()))
  
  pat_alert <- "Es posible que se le solicite nombre de usuario y PAT de github si no tiene uno configurado"
  
  askpass <- function (prompt) {
    if (grepl("Please enter username for", prompt)) {
      prompt <- sprintf(
        "Ingrese el nombre de usuario de %s", 
        get0("url", parent.frame(), ifnotfound = "repo remoto"))
      resp <- askpass::askpass(prompt)
    } else if (grepl("Please enter a PAT or password", prompt)) {
      prompt <- sprintf(
        "Ingrese su PAT (personal access token) de %s \n", 
        get0("url", parent.frame(), ifnotfound = "repo remoto"))
      resp <- askpass::askpass(prompt)
      if (!is.null(resp)) Sys.setenv("GITHUB_PAT" = PAT <<- resp)
    }
    resp
  }
  
  tryCatch(
    finally = {
      if(is.na(GITHUB_PAT_prev)) Sys.unsetenv("GITHUB_PAT") 
      else Sys.setenv("GITHUB_PAT" = GITHUB_PAT_prev) }, 
    error = \(e) stop(conditionMessage(e)),
    {
      gert::git_add(file.path("vignettes", files.txt))
      if (NROW(gert::git_status(staged = TRUE, file.path("vignettes", files.txt)))) {
        message("Actualizando (commit) repo local")
        gert::git_commit("Actualizar txt para traducir")
      } else {
        message("Sin modificaciones en repo local")
      }
      attempt <- 0
      while((attempt <- attempt + 1L) <= 3) {
        if (inherits(git_version, "try-error") && !nzchar(PAT) || attempt > 1L) 
          cat("Probablemente deba generar un Personal Access Token de Github\n")
        tryCatch(
          {
            switch(
              menu(title= "Elija una opción", c(
                sprintf("Intentar `git pull` directamente. %s", pat_alert),  
                "Generar y/o copiar un token PAT via github",
                "Continuar sin actualizar el repo")), 
              {
                NULL
              },{
                utils::browseURL(sprintf(
                  "https://github.com/settings/tokens/new?scopes=%s&description=%s",
                  paste0( c("repo", "user", "gist", "workflow"), collapse = ","),
                  URLencode("traducción vignettes data table")))
                readline("Copie el Personal Access Token (PAT) generado en github y presione [Enter]")
                PAT_generated <- scan("clipboard", "", 1)
                if (grepl("^gh[pousr]_[a-zA-Z0-9]{36}$", PAT_generated))
                  Sys.setenv("GITHUB_PAT" = PAT <- PAT_generated)
                else
                  stop("Error: no se pudo identificar el token PAT")
              },{     
                message("Debe actualizar manualmente el repo subiendo los .txt a ../google-translations")
                break;  # no push
              })
            message("Intentando `git push`...")
            gert::git_push(password = askpass)
            break;
          },
          error = \(e) message(e)
        )
        if (attempt < 3) message(sprintf("Nuevo intento (%d)...", attempt + 1L))
        else message("Demasiados intentos fallidos, se continúa sin actualizar repo")
      }
    }
  )
}


# writeLines(sprintf("[%s](%s)", files, google_urls), "../google_translate_urls.md")

## ---- paso (5) scrapping de traducciones ----
# Todo esto se evitaría con una buena api de traducción gratuita.
# pero NO EXISTE!
message("paso (5) scrapping de traducciones")

{
  files.txt.es <- sub("-en[.]txt$", paste0("-", "es", ".txt"), files.txt)

  while(TRUE) {
    try({ 
      message("Probar con chromote (requiere google chrome)")
      extraer_traducciones_con_chromote(files.txt, files.txt.es, wait = 0.75)
      break 
    })
    try({ 
      message("Probar con selenium (requiere java)")
      extraer_traducciones_con_selenium(files.txt, files.txt.es, wait = 0.75)
      break 
    })
    stop("no fue posible extraer traducciones. ")
  }

  # verificar que hayan sido creados los txt traducidos
  stopifnot(all(file.exists(files.txt.es)))
}

#TODO: No es necesario actualizar los -es.txt en el repo aunque 
# pueden quedar como backup


## ---- paso (6) combinar traducción en el PO ----
{
  # función hace el trabajo de msgcat, etc.
  # analizar si potools tiene algo similar...
  combinar_plain_txt_en_po(files.txt.es, files.po)    
  
  #undebug(wrap_msg)
  # TODO
  # combinar texto plano en PO.
  stop("DONE")
  
  # Actualiza metadata ej: name = "Ricardo Villalba", mail = "rikivillalba@gmail.com"
  actualizar_po_metadata(name = "Nombre Apellido", email = "direccion@ejemplo.com") 
  
  # correr path donde se encuentra po2md y md2po si no se corrió antes i.e. cargar_entorno_conda(condaenv = "main")
}

convertir_po_a_rmd()
# 
# # copia a "es" los otros archivos que son necesarios para ejecutar las viñeytas
# #TODO: (esto cambió, hay que cambiar las rutas)
# vignette_files <- setdiff(
#   list.files(recursive = FALSE), c(
#     "es", list.files( recursive = FALSE, pattern = "[.]Rmd$")))
# file.copy(vignette_files, "es", recursive = T)
# 
# # generar las viñetas html
# setwd("es")
# rmd_files  <- dir(pattern=".Rmd$")
# lapply(rmd_files, \(f)  knitr::knit2html(f))
# 
# # borrar markdown generados
# file.remove(dir(pattern = "[.]md$"))
# 
