# Funciones varias para la traducción de viñetas

# requiere:
#   translateToolkit 
#     po2md, md2po
#           modificado: hacks para que md2po funcione con rmd's
#     - yo usé la versión de translateToolkit 3.13)# 

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

combinar_plain_txt_en_po <- function() {
  
  # Script para cargar los archivos .txt generados en los po originales
  # los txt se generan ocn el script siguiente :
  # find *.po -exec sh -c "msggrep --no-wrap -Ke '' {} | sed -nE '/^$|(msgid)/p' | sed -E 's/^msgid \\\"(.*)\\\"/\\1/' > {}.txt" \;
  # al estar línea por línea soin más faciles de traducir masivamente 
  # (aunque puede tener algún prolema con los escapees tipo \n)
  # por ejemplo cargando en GITHUB y luego pedirle a google que
  # traduzca el link RAW
  
  pwd <- getwd()
  on.exit(setwd(pwd))
  setwd("es/po")
  
  po_files  <- dir(pattern="-es[.]po$")
  po_txt_files <- sub("-es[.]po$", "-es.txt$", po_files)
  stopifnot(all(file.exists(po_txt_files)))
  
  for (f in split(data.frame(po_files, po_txt_files), po_files)) {
    message(f$po_files)
    
    # REQUIERE: (mingw) (usa echo -n. Yo usé el de GIT)
    # CUIDADO: Elimina toda la traducción del PO.
    stopifnot(
      file.copy(f$po_files, paste0(f$po_files,".bak"), overwrite = F))
    
    tryCatch(
      {
        # Modificar el .PO para que las traducciones estén en 1 sola línea
        # (compatible con windows mingw)
        system2("sh", c("-c", shQuote(paste0(
          "msgfilter", "--keep-header", "--no-wrap", 
          "-i", shQuote(f$po_files), "-o", shQuote(f$po_files), "cat"))))
        
        lines_po <- readLines(f$po_files)
        lines_txt <- readLines(f$po_txt_files)
        # Esta línea escapa las comillas " que pudieran haberse introducido
        lines_txt <- gsub("(?<!\\\\)\"", "\\\\\"", lines_txt, perl = T)
        # Si la primera linea está vacía la suprime
        lines_txt <- if(!nzchar(lines_txt[1])) lines_txt[-1] else lines_txt
        # la primera línea de msgstr es el encabezado del PO
        msgstr_pos <- grep("msgstr \"\"", lines_po)[-1]
        # los .po y los archivos planos deben tener el mismo nro de elementos
        if(length(msgstr_pos) != length(lines_txt)) 
          stop(sprintf("po: %d líneas vs txt: %d líneas", 
                       length(msgstr_pos), length(lines_txt)))
        
        lines_po[msgstr_pos] <- paste0("msgstr \"", lines_txt, "\"")
        writeLines(lines_po, paste0(f$po_files, ""))
        file.remove( paste0(f$po_files,".bak"))
      },
      error = \(e){
        message(as.character(e))
        message(sprintf(".PO original guardado como %s", paste0(f$po_files,".bak")))
      }
    )
  }  
}

# Actualiza la metadata en PO (fecha de revisión, Last translator...)
.actualizar_po_metadata <- function() {
  last_translator <- list(name = "Ricardo Villalba", mail = "rikivillalba@gmail.com")
  pwd <- getwd()
  on.exit(setwd(pwd))
  setwd("es/po")
  po_files  <- dir(pattern=".po$")
  lapply(po_files, \(i) {
    lines <- readLines(i) |>
      regex_sub("\"Project-Id-Version: (.*)\\\\n\"", "0.0.1") |>
      regex_sub("\"PO-Revision-Date: (.*)\\\\n\"", format(Sys.time(), format = "%Y-%m-%d %H:%M%z")) |>
      regex_sub("\"Last-Translator: (.*)\\\\n\"", with(last_translator, sprintf("%s <%s>", name, mail))) |>
      regex_sub("\"Language-Team: (.*)\\\\n\"", "es")  |> 
      append("\"Language: es\\n\"", after = grep("\"Language-Team: (.*)\\\\n\"", lines))
    writeLines(lines, i)
  })
}

# Usa las rutinas de rmd2po para generar archivos ".po" y traducir las viñetas
generar_po_desde_rmd_en_ingles <- function() {
  rmd_files <- dir(,".Rmd$")
  for (f in rmd_files) {
    rmd2po(f, lang = "es")
  }  
}



# Una vez traducidos los po, generar los rmd
# po2rmd utiliza "po2md" (librerías escritas en python)
# po2rmd hace algunas transformaciones sobre el .Rmd original para 
convertir_po_a_rmd <- function() {
  rmd_files <- dir("es", ".Rmd$")
  for (f in rmd_files) {
    po2rmd(f, lang = "es", verbose = TRUE)
  }  
}

# generar las viñetas html
generar_viñetas_html <- function() {
  rmd_files  <- dir("es", pattern=".Rmd$")
  lapply(rmd_files, \(i) {
    # Corre en su propio subproceso.
    # NOTA no pasar knitr directamente en lapply (porque topenv() es "base" 
    # en lugar de .Globalenv y cedta() no lo detecta)
    callr::r(\(f) knitr::knit2html(file.path("es", f)), list(i))
  })
  # borrar markdown generados
  file.remove(dir("es", pattern = "[.]md$"))
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

extrae_texto_de_msgid <- function() {
  message("Extraer msgid de archivos...")
  for (i in dir("es/po", ".po$")) {
    lines <- grep(readLines(file.path("es/po", i)), pattern = "^\\s*(\"|msg)", value= TRUE)
    msgs <- grep("^\\s*msg", lines)
    grps <- cut(seq_along(lines), c(msgs, Inf), labels = FALSE, right = FALSE)
    text <- vapply(seq_along(msgs), "", FUN = function(j) paste0(gsub(
      "\\s*(msg(id|id_plural|str)(\\[\\d*\\])?)?\\s*\"(([^\"]|\\\\.)*)\".*", 
      "\\4", lines[grps == j]), collapse = ""))
    writeLines(text[grep("^\\s*msgid", lines[msgs])], 
               file.path("es/po", sub("es\\.po$", "en.txt", i, ".txt")))
  }
  message("Listo")
}



cargar_entorno_conda <- function(condaenv) {
  # entorno conda donde se instaló "translate toolkit"
  # (esto funciona para mi caso en windows. Yo lo instalé en "main")
  #TODO: usar el que corresponde. O Iniciar R desde un entorno donde 
  # md2po esté idsponible.
  tryCatch(
    system2("md2po", "--version", stderr = TRUE),
    error = \(e) {
      message("cargar ruta de conda. env: \"", condaenv, "\"")
      md2po_path <- file.path(
        dirname(dirname(reticulate::conda_binary())), "envs", condaenv,"Scripts")
      Sys.setenv(
        PATH = paste(md2po_path, Sys.getenv("PATH"), sep = .Platform$path.sep))
    }
  )
}

#para "normalizar" el archivo: 
# find *.po -exec msgcat -o {} {} \\;"




traducciones_google_english <- function(url, files) {
  sapply(gsub("-es\\.", "-en\\.", files), \(file) {
    httr::build_url(within.list(httr::parse_url(
      paste0(url, file)), 
      query <- list(`_x_tr_sl`="en", `_x_tr_tl`="es", `_x_tr_hl`="es", `_x_tr_pto`="wapp")
    ))})
}

# usa SELENIUM para traducir con google desde github
extraer_traducciones_con_selenium <- function(google_urls) {
  tryCatch(
    {
      selenium_driver <- RSelenium::rsDriver(
        browser = "chrome",
        check  = FALSE, 
        extraCapabilities = list(
          chromeOptions = list(
            prefs = list(
              "profile.default_content_settings.popups" = 0L))))
      
      for (link_id in names(google_urls)) {
        selenium_driver$client$navigate(google_urls[link_id])
        selenium_driver$server$process$wait(1000)
        
        element <- selenium_driver$client$findElement(using="xpath", "/html/body/pre")
        lines <- element$getElementText()[[1]] |> strsplit("\n", fixed = TRUE) |> _[[1]]
        writeLines(lines, file.path("es/po", sub("en\\.txt$", "es.txt", link_id)))
        message(paste(link_id, "ok."))
        #    sub("^.*/([^/]+en\\.txt)\\?.*$", "\\1", link)
      }
    },
    error = \(e) message(e),
    finally = {
      (get0("selenium_driver")$server$stop 
       %||% \() warning("no hay server para detener"))()
    }
  )  
}

#==== Inicio ====

if (FALSE) {
  
  
  # inicia en la carpeta "vignettes"
  # TODO: MODIFICAR CON LA RUTA DONDE CADA UNO GUARDA LAS VIGNETTES
  # O CLONA EL GIT
  # TODO: alguna automatización de CI/CD de github para que lo haga automático? 
  setwd("~/R/traduccion-vignettes-datatable/vignettes")
  
  # hacks para que md2po funcione con rmd's
  # https://github.com/SciViews/rmdpo
  # (modificado para q funcione con translateToolkit 3.13)
  
  cargar_entorno_conda(condaenv = "main")
  
  # version de rm2po
  system2("md2po", "--version", stderr = TRUE)
  
  source("../rmd2po.R")
  
  generar_po_desde_rmd_en_ingles()
  
  extrae_texto_de_msgid()
  
  files <- c("datatable-benchmarking.Rmd-en.txt", "datatable-faq.Rmd-en.txt", 
            "datatable-importing.Rmd-en.txt", "datatable-intro.Rmd-en.txt", 
            "datatable-keys-fast-subset.Rmd-en.txt", "datatable-programming.Rmd-en.txt", 
            "datatable-reference-semantics.Rmd-en.txt", "datatable-reshape.Rmd-en.txt", 
            "datatable-sd-usage.Rmd-en.txt", "datatable-secondary-indices-and-auto-indexing.Rmd-en.txt")
  
  google_urls <- traducciones_google_english(
    url = "https://raw-githubusercontent-com.translate.goog/cienciadedatos/traduccion-vignettes-datatable/refs/heads/main/vignettes/es/po/",
    files = files)
  
  writeLines(sprintf("[%s](%s)", files, google_urls), "../google_translate_urls.md")
  
  extraer_traducciones_con_selenium(google_urls = google_urls)
  
  
  
  #Hacer un commit en este punto.
  #system2("git", "add .",  stderr = TRUE)
  #   system2("git", "commit -m \"texto extraido de msgid\"",  stderr = TRUE)
  
  # extraer traducciones con SELENIUM
  
  

}