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


# ---- funciones auxiliares ----

if (!exists("%||%")) `%||%` <- function(x, y) {if (is.null(x)) y else x}

condf.generator <- function(fname = c("warning", "stop")) {
  fname <- match.arg(fname)
  sig.fn <- match.fun(fname)
  cnd.fn <- switch(fname, warning = warningCondition, stop = errorCondition, 
                   stop(gettext("debe ser o bien warning o bien stop")))
  function(fmt, ..., class = NULL, call = sys.call(-1), domain = NULL) {
    nmd <- nzchar(...names() %||% character(...length()))
    msg <- do.call(sprintf, quote = TRUE, c(list(fmt = fmt), list(...)[!nmd]))
    cnd <- do.call(cnd.fn, quote = TRUE, c(
      list(message = msg, call = call, class = class), list(...)[nmd]))
    sig.fn(cnd, domain, call. = FALSE)
  }
} 

messagef <- function(fmt, ..., call = sys.call(-1)) {
  message(simpleMessage(paste0(sprintf(fmt, ...), "\n"), call = call))
}

stopf <- condf.generator("stop")
warningf <- condf.generator("warning")

catfln <- function(fmt, ..., domain = NULL, trim = TRUE) {
  cat(gettextf(fmt, ..., domain = domain, trim = trim), "\n")
}

# dada la posición de espacios en una cadena, devuelve las
# posicones en que hay que saltar la línea para limitarla
# a wd caracteres (wd - 2 ya que considera comillas) 
# siempre sobre espacios en blanco.
# por defectolas palabras > wd largas se quiebran en un punto arbitrario.
wrap_msg <- function(m, wd = 80, wrap.long.words = TRUE) {
  f <- \(m, p = 0) 
    if (any(x <- m > p & m < wd - 2 + p))
      c(p, f(m, m[rev(which(x))][1]))
    else if (any(m > p))
      c(p, f(m, if (wrap.long.words) wd - 2 + p else m[which(m > p)[1]])) 
    else if (m[length(m)] == p + 1)
      integer()
    else p
  f(m)  
}

#debug(wrap_msg)
# Función auxiliar para sustitución con regmatches<-
regex_sub <- function(x, pattern, ...) {
  matches <- regexec(pattern, x)
  drop_first <- function(x) 
    if(!anyNA(x) && all(x > 0)) {
      ml <- attr(x, 'match.length')
      if(is.matrix(x)) x <- x[-1,] else x <- x[-1]
      attr(x, 'match.length') <- if(is.matrix(ml)) ml[-1,] else ml[-1]
      x 
    } else x
  regmatches(x, lapply(matches, drop_first)) <- Map(f = c, ...)
  x
}

# En .PO, una <entrada> consiste en la secuencia 
# msgid{"texto"}+msgstr{"texto"}+   con cualquier número de espacios o saltos 
# de línea entre medio. o bien una secuencia 
# msgid "texto" msgid_plural "texto" { msgstr[n] "texto"}+ donde n = 0..N
# Entradas válidas son:
#   msgid "texto"
#   msgstr "texto"
#
#   msgid"texto"msgstr"texto"
#
#   msgid 
#   "texto" msgstr "texto\n""texto\n"  # comment
#
#   msgid "" 
#   "texto" msgid_plural "texto\""
#    msgstr[0] "" msgstr[01] "akgo"
#  msgstr [ 2  ]"other" 
#
# No válidas:
#
# # msgstr or msgid_plural or string expected (but comment found): 
# msgid "texto" # comment
# msgstr "text"
#
# # msgstr or msgid_plural or string expected (but msgid found): 
# msgid "" msgid ""
#
# # en of line while in string
# msgid "texto
#   más texto" 
#
# # invalid msgstr index 2 (expected 1):
# msgid "" msgid_plural "" msgstr[0] "" msgstr[2] "" 
#
#
# etc.
# no se permiten comentarios entre líneas de una misma entrada (pero la última
# línea de la entrada puede tener comentarios en la misma línea)
# https://www.gnu.org/software/gettext/manual/html_node/PO-Files.html
# 
# TODO: Esta función asume el formato de salida de msgtext por lo que es PROVISORIA
get_po_msgs <- function(lines_po, type = c("msgid", "msgstr")) {
  type <- match.arg(type)
  EOF <- length(lines_po) + 1
  # msgid_pos: posisción de msgid o msgstr
  # no_str_pos: comandos y EOF. todo excepto #s, o cadenas (incl. msgid_pos)
  # str_pos: cadenas sin comandos ni #s
  msgid_pos <- c(grep(paste0("^\\s*", type, "\\s+\""), lines_po), EOF)
  no_str_pos <- c(grep("^\\s*[^\"#]", lines_po), EOF) 
  str_pos <- grep("\\s*[\"]", lines_po)
  pos <- Map(
       head(msgid_pos, -1L), tail(msgid_pos, -1L),
    f = \(d, h) union(
      d, str_pos[str_pos >= d & str_pos < min(h, no_str_pos[no_str_pos > d])]))
  structure(
    vapply(pos, "", FUN = \(l) (
      paste0(collapse = "", sub(
        "^\\s*(msg(id(_plural)?|str( *\\[ *\\d+ *\\])?))?\\s*\"(([^\"]|([\\]\"))*)\"\\s*(#.*)?$",
        "\\5", lines_po[l])))),
    pos = pos)
}


#    bad_ctrlseq = '"([^\\"]|[\\].)*([\\]$|")', # captura lo q no captura string
#    eol_string = '"([^\\"]|[\\].)*$', 

# versión más ajustada a la sintaxis real
# https://www.gnu.org/software/gettext/manual/html_node/PO-Files.html
# "Each of untranslated-string and translated-string respects the C syntax for 
# a character string, including the surrounding quotes and embedded backslashed 
# escape sequences, except that universal character escape sequences 
# (\u and \U) are not allowed."
# ejemplo:
# sample(dir("R\\traduccion-vignettes-datatable\\vignettes\\es\\po", full=T, "\\.po$"), 1) |>
#   (\(x) {cat(x);x})() |>
#   readLines() |> parse_PO()  |> jsonlite::toJSON(pretty = T, auto_unbox = T) |> clipr::write_clip()
# readLines("a.po") |> parse_PO()  |> jsonlite::toJSON(pretty = T, auto_unbox = T) |> clipr::write_clip()
# strings:
# hasta donde puedo ver las secuencias \xhh.. toman sólo los dos últimos 
# dígitos y sólo son válidos hasta 7f, pero igual se parsean. Quizás 
# depende de charset. no puedo usar str2lang directamente. Además,
# se acepta \x00 con el efecto de terminar la cadena (R no acepta).
parse_PO <- function(lines_po, literal.strings = FALSE) {
  # tokenizer
  re_str <- '([^\\"]|[\\][\\"abfnrtv"]|[\\][0-7]{1,3}|[\\]x[[:xdigit:]]+)*'
  re_kw <- paste0(c(letters, LETTERS, "_"), collapse = "")
  re_classes <- c(
    msgid = "msgid", msgid_plural = "msgid_plural", msgstr = "msgstr",
    index.open = "[[]", index.close = "[]]", index = "\\d+",
    comment = "#.*", 
    keyword = paste0("[", re_kw, "]", "[0-9", re_kw, "]*"),
    string = paste0('"', re_str, '"'),
    bad_ctrlseq = paste0('"', re_str, '\\\\'), 
    eol_string =  paste0('"', re_str, '$'), 
    space = "\\s+", unknown = ".")        
  classes <- c(names(re_classes), "EOF")  # el orden es importante!
  id_classes <- setNames(seq_along(classes), classes)

  # generar tokens  
  all_matches <- gregexpr(paste0(re_classes, collapse = "|"), lines_po) 
  no_empty <- which(vapply(all_matches, `[`, 0L, 1L) > 0L)
  matches <- all_matches[no_empty] 
  token_value <- unlist(regmatches(lines_po[no_empty], matches))
  token_class_id <- paste0("^", re_classes, "$") |> 
    vapply(grepl, logical(length(token_value)), token_value, USE.NAMES = FALSE) |> 
    structure(dim = c(length(token_value), length(re_classes))) |>
    apply(1, match, x = TRUE, nomatch = 0) |>
    c(as.integer(id_classes["EOF"]))
  token_row <- rep(no_empty, lengths(matches))
  token_col <- unlist(matches) 
  token_length <- unlist(lapply(matches, attr, "match.length"))

  # check léxico
  if (p <- match(id_classes["bad_ctrlseq"], token_class_id, 0L)) stopf(
    "secuencia de control errónea, fila %s, col %s...", 
    token_row[p], token_col[p] + token_length[p] - 1L)
  if (p <- match(id_classes["eol_string"], token_class_id, 0L)) stopf(
    "fin de línea dentro de la cadena, fila %s, col %s...",
    token_row[p], token_col[p])
  if (p <- match(id_classes["keyword"], token_class_id, 0L)) stopf(
    "palabra clave desconocida '%s' fila %s, col %s...", 
    token_value[p], token_row[p], token_col[p])
  if (p <- match(id_classes["unknown"], token_class_id, 0L)) stopf(
    "error de sintaxis '%s', fila %s, col %s...", 
    token_value[p], token_row[p], token_col[p])
  
  # opciones - parsear cadenas de caracteres
  if (!literal.strings) 
    token_value[token_class_id == id_classes["string"]] <- 
      token_value[token_class_id == id_classes["string"]] |> 
        sub(pattern = "\\\\x[[:xdigit:]]*([[:xdigit:]]{2})", replacement = "\\\\x\\1") |>
        sub(pattern = "\\\\x0+($|[^[:xdigit:]]).*", replacement = "") |>
        sub(pattern = "\\\\(000|00?($|[^0-7])).*", replacement = "") |> 
        vapply(str2lang, "")

  # auxiliar mini parser 
  `c<-` <- \(tmp, value) {
    c(tmp, value)  # concatenar in situ (sin 'value')
  }
  stop_position <- function() {
    if (i == length(token_class_id[i])) gettext("<fin de archivo>") 
    else gettextf("fila %d, col %d", token_row[i], token_col[i])
  }
  new_entry <- function() {
    c(entries) <<- list(entry) 
    entry <<- list()
    switch(
      classes[token_class_id[i]], 
      msgid = "msgid", 
      comment = consume("comment"),
      EOF = "end",
      stopf(
        "se esperaba <msgid> o <comment> en %s", stop_position()))
  }
  switch_class <- function(..., default) {
    switch(
      classes[token_class_id[i]], 
      ...,
      if (!missing(default)) default
      else if (...length() == 1L)
        switch(
          ...names(),
          index.open = stopf("se esperaba '[' en %s", stop_position()),
          index.close = stopf("se esperaba ']' en %s", stop_position()),
          stopf("se esperaba <%s> en %s", ...names(), stop_position()))
      else {
        cls <- paste0(...names(), collapse = " | ")
        stopf("se esperaba <%s> en %s", cls, stop_position())
      }
    )
  }
  consume <- function(class = c(
    "msgid", "msgstr", "msgid_plural", "msgstr_with_index", "comment")) { 
    class <- match.arg(class)
    if (class == "msgstr_with_index")
      c(entry$msgstr[[id + 1L]]$value) <<- token_value[i]
    else if (class == "comment") 
      c(entry[[class]]) <<- substr(token_value[i], 2L, nchar(token_value[i]))
    else 
      c(entry[[class]]) <<- token_value[i]
    switch(
      class, msgid = "msgid.string", msgstr = "msgstr.string", 
      msgid_plural = "msgid_plural.string", 
      msgstr_with_index = "msgstr_with_index.string", 
      comments = "ready", 
      stop()) 
  }
  set_index <- function(value = id + 1L) {
    id <<- value
    if (value == 0) entry$msgstr <<- list()
    "msgstr_with_index"
  }
  check_index <- function() {
    if (as.integer(token_value[i]) != id) 
      stopf("índice erróneo en fila %d, col %d: ", token_row[i], token_col[i]) 
    entry$msgstr[[id + 1L]] <<- list(id = id)
    "msgstr_with_index.index" 
  }
  
  # inicio mini parser
  entries <- entry <- list()
  state <- "ready"
  id <- NULL
  for (i in seq_along(token_class_id)[token_class_id != id_classes["space"]]) {
    state <- switch(
      state,
      ready = switch_class(
        msgid = "msgid", 
        comment = consume("comment"),
        default = new_entry()),
      msgid = switch_class(
        string = consume("msgid")),
      msgid.string = switch_class(
        string = consume("msgid"),
        msgid_plural = "msgid_plural", 
        msgstr = "msgstr"),
      msgstr = switch_class(
        string = consume("msgstr")),
      msgstr.string = switch_class(
        string = consume("msgstr"),
        default = new_entry()),
      msgid_plural = switch_class(
        string = consume("msgid_plural")),
      msgid_plural.string = switch_class(
        string = consume("msgid_plural.string"),
        msgstr = set_index(0L)),
      msgstr_with_index = switch_class(
        index.open = "msgstr_with_index.open") ,
      msgstr_with_index.open = switch_class(
        index = check_index()),
      msgstr_with_index.index = switch_class(
        index.close = "msgstr_with_index.close"),
      msgstr_with_index.close = switch_class(
        string = consume("msgstr_with_index")),
      msgstr_with_index.string = switch_class(
        string = consume("msgstr_with_index"),
        msgstr = set_index(),
        default = new_entry()),
      stop("bad state")
    )
  }
  entries
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
#DEBUG: files.po = "es/po/datatable-benchmarking.Rmd-es.po"
#DEBUG: files.txt = "es/google-translations/datatable-benchmarking.Rmd-en.txt"
extrae_msgid_de_po <- function(files.po, files.txt) {
  for (i in seq_along(files.po)) {
    all_lines <- readLines(files.po[i])
    lines <- all_lines[grep("^\\s*(msg|\")", all_lines)]
    msgs <- grep("^\\s*(msg(id|id_plural|str(\\s*\\[\\d*\\])?))", lines)
    grps <- cut(seq_along(lines), c(msgs, Inf), labels = FALSE, right = FALSE)
    msgids <- grep("^\\s*(msgid(_plural)?)", lines[msgs])
    text <- vapply(seq_along(msgids), "", FUN = function(j) paste0(sub(
      "^\\s*(msgid(_plural)?)?\\s*\"(([^\"]|\\\\.)*)\".*", "\\3", 
      lines[grps == msgids[j]]), collapse = ""))
    # generalmente el primer msgid es vacío
    if (nzchar(text[1])) stopf("El primer msgid del PO debería ser vacío (msgstr es la descripción)")
    writeLines(text[-1], files.txt[i])
  }
}

# toma los archivos txt linea por linea y los incorpora a las
# entradas "msgstr" del PO, partiendo lineas largas si es necesario
#debugonce(combinar_plain_txt_en_po)
combinar_plain_txt_en_po <- function(po_txt_files, po_files, overwrite = FALSE) {
  for (i in seq_along(po_files)) {
    messagef("Combinando %s en %s", 
      basename(po_txt_files[i]), basename(po_files[i]))
    tryCatch(
      {
        # Si la primera linea en txt está vacía la suprime
        lines_po <- readLines(po_files[i])
        lines_txt <- readLines(po_txt_files[i]) |>
          gsub(pattern = "(?<!\\\\)\"", replacement = "\\\\\"", perl = TRUE) |>
          (\(l) subset(l, nzchar(l[1]) | seq_along(l) > 1))()

        # msgstr_pos es la posición de los msgstr en el po
        # other_pos es la posición de todo el resto
        # la primera línea de msgstr es el encabezado del PO. No se incluye.
        msgs <- get_po_msgs(lines_po, "msgstr")[-1]
        msgstr_pos <- attr(msgs, "pos")
        other_pos <- Map(
          f = seq, 
          c(0, vapply(msgstr_pos, tail, 0L, 1L) + 1L),
          c(vapply(msgstr_pos, head, 0L, 1L) - 1L, length(lines_po) + 1L))

        # los .po y los archivos txt planos deben tener el mismo nro de elementos
        if ((n <- length(msgstr_pos)) != (m <- length(lines_txt))) {
          stopf(
            "el archivo %s tiene %d líneas, mientras que %s tiene %d líneas",
            po_files[i], n, po_txt_files[i], m,
            class = "length.mismatch"
          )
        }
        
        #TODO: esta parte formatea lines_txt aunque overwrite=FALSe (innecesario)
        # saltos de línea en lineas largas wd <- 80
        msgstr <- lapply(lines_txt, FUN = \(x) ({
          m <- gregexpr("\\s(?=\\S)|$", x, perl = T)[[1]]
          if (nchar(x) <= 80 - nchar("msgstr") - 2) {
            paste0("msgstr ","\"", x, "\"")  
          } else {
            cuts <- wrap_msg(m, wd = 80)
            c("msgstr \"\"", paste0(
              '"', substring(x, cuts[-length(cuts)] + 1, cuts[-1]), '"'))
          }
        }))
        
        if (overwrite) {
          if ((n <- length(which(lines_txt[nzchar(msgs)] != msgs[nzchar(msgs)]))) > 0)
            warningf("AVISO: %d mensajes ya traducidos se reemplazan por nueva versión de google", n)
        } else {
          msgstr[nzchar(msgs)] <- lapply(msgstr_pos[nzchar(msgs)], \(l) lines_po[l])
        }
        
        other <- lapply(other_pos, \(s) lines_po[s[s <= length(lines_po)]])
        
        lines_po <- vector("list", length(msgstr) + length(other))
        lines_po[seq(2, length(msgstr), by = 2)] <- msgstr
        lines_po[seq(1, length(other), by = 2)] <- other
        writeLines(unlist(lines_po), po_files[i])
      },
      length.mismatch = (function(e) {
        tryCatch(
          {
            plain_english <- get_po_msgs(lines_po, "msgid", "value")
            writeLines(plain_english, paste0(po_files[i], ".msgid.txt"))
            stopf(
              "El texto de los msgid (en inglés) extraídos de %s se guardó en %s", 
              po_files[i], paste0(po_files[i],".msgid.txt"), call = conditionCall(e))
          },
          error = function(f) stopf("%s\n%s", conditionMessage(e), conditionMessage(f),
            call = conditionCall(f))
        )
      }),
      # Para personalizar error
      error = function(e) stopf("%s", conditionMessage(e), call = conditionCall(e))
    )
  }
}

#TODO: solo devuelve el Last-translator!!
#Falta todo lo demás (debería usar get_po_msg para msgid=="")
obtener_po_metadata <- function(po_files) {
  result <- vapply(po_files, character(2), FUN = \(i) {
    lines <- readLines(i)
    matches <- regexec("\"Last-Translator: ([^<]*)<([^>]*)>\\\\n\"", lines)
    c(name = regmatches(lines, matches) |> Filter(f=length) |> append("") |> _[[1]][2] |> trimws(), 
      email = regmatches(lines, matches) |> Filter(f=length) |> append("") |> _[[1]][3] |> trimws()) 
  })
  fmt <- sprintf("%s <%s>", result[1,], result[2, ])
  if (all(fmt == fmt[1])) result[,1] else result
}

# Actualiza la metadata en PO (fecha de revisión, Last translator...)
actualizar_po_metadata <- function(po_files, name, email, lang_code) {
  lapply(po_files, \(i) {
    lines <- readLines(i)
    lines |> 
      regex_sub("\"Project-Id-Version: (.*)\\\\n\"", "0.0.1") |>
      regex_sub("\"PO-Revision-Date: (.*)\\\\n\"", format(Sys.time(), format = "%Y-%m-%d %H:%M%z")) |>
      regex_sub("\"Last-Translator: (.*)\\\\n\"",  sprintf("%s <%s>", name, email)) |>
      regex_sub("\"Language-Team: (.*)\\\\n\"", lang_code)  |> 
      append(
        sprintf("\"Language: %s\\n\"", lang_code), 
        after = grep("\"Language-Team: (.*)\\\\n\"", lines)) |>
      writeLines(i)
  })
  invisible()
}


# TODO: Script provisorio para traducir los títulos
traducir_titulos_rmd <- function(lang_code="es") {
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
      `datatable-secondary-indices-and-auto-indexing.Rmd` = "Secondary indices and auto indexing",
      `datatable-joins.Rmd` = "Joins in data.table"
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
      `datatable-secondary-indices-and-auto-indexing.Rmd` = "Índices secundarios y auto indexación",
      `datatable-joins.Rmd` = "Uniones «join» en data.table"
    )
  title_missing <- 
    c("joins and rolling joins", "data.table internals")
  
  rmd_files  <- dir(lang_code, pattern=".Rmd$", full.names = TRUE)
  lapply(rmd_files, \(f, i = basename(f)) {
    if (i %in% names(titles_es)) {
      lines <- readLines(f) 
      if ((length(n <- grep("title: \"(.*)\"", lines))) == 1) {
        prev <- sub(".*title: \"(.*)\".*", "\\1", lines[n])
        if (prev == titles_es[i])
          messagef("Título no se cambia: %s", prev)
        else {
          writeLines(
            regex_sub(lines, "title: \"(.*)\"", titles_es[i]), f)
          messagef("Título cambiado de %s a %s", prev, titles_es[i])
        }
      } else warningf("no se puede individualizar \"title:\" (%d coincidencias)", length(n))
    } else warningf("título para %s no en titles_es (lista de traducidos)", i)
  })
  invisible()
}

# usa SELENIUM para traducir con google desde github
extraer_traducciones_con_selenium <- function(
    files, files_es, wait = .8, lang_code, branch_name) {
  errors <- list()
  for (i in 1:3) {
    result <- switch(
      i, { 
        try(selenium_driver <- RSelenium::rsDriver(
          browser = "chrome", check  = FALSE, extraCapabilities = list(
            chromeOptions = list(prefs = list(
              "profile.default_content_settings.popups" = 0L))))) 
      }, { 
        try(selenium_driver <- RSelenium::rsDriver()) 
      }, { 
        stopf(
          "No fue posible iniciar Selenium: %s.", paste(vapply(errors, conditionMessage), sep = "\n"),
          class = "web.driver.error", call = sys.call()) 
      }
    )
    if (!inherits(result, "try-error")) break 
    else errors <- c(errors, list(attr(result, "condition")))
  }

  # Estos links vinculan a las traducciones de google
  google_urls <- sprintf(
    "https://raw.githubusercontent.com.translate.goog/cienciadedatos/",
    "traduccion-vignettes-datatable/refs/heads/%s/vignettes/%s?%s",
    branch_name,
    URLencode(files), 
    sprintf("_x_tr_sl=%s&_x_tr_tl=%s", "en", lang_code))
  
  raw_urls <- sprintf(
    "https://raw.githubusercontent.com/cienciadedatos/",
    "traduccion-vignettes-datatable/refs/heads/%s/vignettes/",
    branch_name,
    URLencode(files))
  
  tryCatch(
    error = \(e) message(e),
    finally = selenium_driver$server$stop,
    for (i in seq(files)) {
      message(google_urls[i])
      selenium_driver$client$navigate(google_urls[i])
      messagef("Esperar %f seg.", wait)
      selenium_driver$server$process$wait(1000 * wait)
      
      element <- selenium_driver$client$findElement(using="xpath", "/html/body/pre")
      if (!length(element))
        stopf("Problema al analizar el documento con chromote, no fue posible interpretar html de la traducción, pruebe mayor wait.")
      
      lines <- element$getElementText()[[1]] |> 
        strsplit("\n", fixed = TRUE) |> _[[1]]
      writeLines(lines, files_es[i])
      messagef("%s OK.", files_es[i])
    }
  ) 
  invisible()
}

# client$view() # para verlo en chrome
extraer_traducciones_con_chromote <- function(
    files, files_es, wait = .8, lang_code, branch_name) {
  options("chromote.launch.echo_cmd" = TRUE)
  tryCatch(
    client <- chromote::ChromoteSession$new(),
    error = \(e) stopf(
      "No fue posible iniciar ChromoteSession (google devtools protocol): %s",
      conditionMessage(e), 
      class = "web.driver.error",
      call = sys.call())
  )
  # Estos links vinculan a las traducciones de google
  google_urls <- sprintf(
    "https://raw.githubusercontent.com.translate.goog/cienciadedatos/",
    "traduccion-vignettes-datatable/refs/heads/%s/vignettes/%s?%s",
    branch_name,
    URLencode(files), 
    sprintf("_x_tr_sl=%s&_x_tr_tl=%s", "en", lang_code))

  raw_urls <- sprintf(
    "https://raw.githubusercontent.com/cienciadedatos/",
    "traduccion-vignettes-datatable/refs/heads/%s/vignettes/",
    branch_name,
    URLencode(files))

  # por las dudas, quizá en background no traduce
  # client$view()
  
  DOM <- client$DOM

  tryCatch(
    for (i in seq(files)) {
      message(google_urls[i])
      client$Page$navigate(google_urls[i])
      messagef("Esperar %0.1f seg.", wait)
      attempt <- 0
      while (TRUE) {
        Sys.sleep(wait)
        doc.nodeId <- DOM$getDocument()[[1]]$nodeId
        sel.nodeId <- DOM$querySelector(
          nodeId = doc.nodeId, selector = "html > body > pre")[[1]]
        if (sel.nodeId == 0) {
          client$view()
          stopf(
            "Problema al analizar el documento con chromote: no fue posible interpretar html de la traducción, pruebe mayor wait.")
        }
        lines <- DOM$getOuterHTML(sel.nodeId)[[1]] |>
          xml2::as_xml_document() |> xml2::xml_text() |>
          strsplit("\n", fixed = TRUE) |> _[[1]]
        lines_orig <- readLines(url(raw_urls[i]))
        if (length(lines_orig) != length(lines)) 
          stopf("Número de líneas original y traducido difieren")
        else if (all(lines_orig == lines)) {
          if (attempt < 3) {
            messagef("Los mensajes no parecen haberse traducido (%d mensajes). Esperar un poco más", length(lines))
            attempt <- attempt + 1
            next
          }
        } else {
          break
        }
        warningf("No se encontraron diferencias entre original y traducido después de %d intentos", attempt)
        break
      }
      writeLines(lines, files_es[i])
      message("ok ", files_es[i]) 
    },
    finally = client$close()
  ) 
  invisible()
}

setup <- function() {
  if (basename(getwd()) == "vignettes" && !"./vignettes" %in% list.dirs()) 
    setwd("..")
  if (!file.exists("rmd2po.R")) {
    stopf("No se encuentra rmd2po.R. Chequee que su directorio actual sea traduccion-vignettes-datatable, la ubicación de rutinas.R y rmd2po.R.")
  } else source("rmd2po.R")
  
  message("Cargar Python...")
  library(reticulate)
  py_available(TRUE)  # check for Python
  message(py_exe())
  
  # verificar md2po
  # sitio del proyecto: https://pypi.org/project/mdpo/
  message("chequear que exista `mdpo`...")
  tryCatch(
    .check_mdpo(),
    error = (function(e) {
      warningf("%s: Instalar mdpo (si no está instalado)...", conditionMessage(e))
      if(as.numeric_version(py_version()) > "3.11" && .Platform$OS.type == "windows") 
        warningf(
          "AVISO: En windows, mdpo sólo está disponible hasta 3.11, luego requiere compilación (visual studio toolchain)")
      py_install("mdpo", pip = TRUE)
    })
  )
  
  if (basename(getwd()) == "vignettes") {
    setwd("..")
  }
}
# Auxiliar

cambiar_rutas_en_Rmd <- function(lang, debug = FALSE) {
  # el "./" es necesario par comparar
  rmd_files <- dir(file.path(".", lang), pattern = ".Rmd$", full.names = TRUE)
  rg_other_files <- basename(setdiff(
    dir(".", recursive = TRUE, full.names = TRUE),
    c(dir(".", ".Rmd$", full.names = TRUE), 
      dir(file.path(".", lang), recursive = TRUE, full.names = TRUE)))) |> 
    gsub(pattern = "([].\\*?[])", replacement = "\\\\\\1") |>
    sub(pattern = "(.*)", replacement = "^\\1$")
  
  paths <- lapply(setNames(nm=rmd_files),  \(f) {
    message(f)
    lines <- readLines(f)
    cb_start <- grep("^```\\{?\\s*[rR]", lines)  
    cb_end <- grep("^```\\s*(#|$)", lines)
    cb_end <- vapply(cb_start, \(i) cb_end[cb_end > i][1], 1L )
    if (anyNA(cb_end)) stop("error al parsear codeblocks" )

    cblks <- 
      Map(cb_start, cb_end, f = \(i, j) seq.int(from = i + 1L, length = j - i - 1L)) |> 
      Map(f = \(i) lines[i]) |> 
      Map(f = \(i) tryCatch(parse(text = i), error = as.null)) 
    
    valid <- which(!vapply(cblks, is.null, FALSE))
    
    pdata <- cblks[valid] |>  
      Map(f = getParseData) |> 
      Map(f = \(d) d[d$terminal == TRUE & d$token == "STR_CONST",]) |> 
      Map(cb_start[valid], f = \(d, s) d |> transform(
        row = line1 + s - 0L, 
        str = as.character(parse(text = text)))) |> 
      do.call(what = rbind)
    
    rg_other_files |> 
      Map(f = grepl, x = list(as.character(parse(text = pdata$text)))) |> 
      Map(f = subset, x = list(pdata)) |>
      Filter(f = nrow) |> 
      do.call(what = rbind)
    
  }) |> Filter(f = NROW)
  if (debug) { print(paths) } 
  
  for (i in seq_along(paths)) {
    lines <- readLines(names(paths)[i])
    matches <- Map(
      f = structure,
      paths[[i]]$col1, 
      index.type = "chars", 
      match.length = with(paths[[i]], col2 - col1 + 1L), 
      useBytes = TRUE)
    if (debug) { cat("====matches\n");    print(matches) }
    if (debug) { cat("====lines\n");    print(lines[paths[[i]]$row]) }
    # asume line1 = line2 
    for (j in seq_along(matches)) {
      # normalmente la traducción se encuentra en una subcarpeta de las viñetas
      rpl <- file.path("..", paths[[i]]$str[j])
      regmatches(lines[paths[[i]]$row[j]], matches[j]) <- list(deparse1(rpl))
    }
    if (debug) { cat("====lines modif\n"); print(lines[paths[[i]]$row]) }
    
    writeLines(lines, names(paths)[i])
  }
  invisible()
}

update_PO <- function(lang_code = "es") {
  basedir <- getwd()
  on.exit({
    setwd(basedir)
  })
  message("Cambiando a directorio «./vignettes»")
  setwd(file.path(basedir, "vignettes"))

  message("identificar viñetas...")
  rmd_files <- dir(,".Rmd$")
  if (!length(rmd_files)) {
    stopf("No se encontraron archivos para traducir")
  } else {
    for (i in rmd_files) catfln("* %s", i)
  }
  
  message("generar/actualizar PO a partir de viñetas en inglés...")
  for (f in rmd_files) 
    rmd2po(f, lang = lang_code, verbose = TRUE)
  message("Listo")
}

# ---- Inicio ----
start_translation <- function(lang_code = "es") {
  
  ## ---- paso (0) setup ----

  messagef("Inicio ...")
  
  basedir <- getwd()
  on.exit({
    setwd(basedir)
    message("Gracias por usar este script (q() para salir de R)")
  })
  
  message("Cambiando a directorio «./vignettes»")
  setwd(file.path(basedir, "vignettes"))

  # Acá empieza el script.
  # ~~~~~~~~~~~~~~~~~~~~~~
  
  ## ---- paso (1) generar/actualizar PO a partir de viñetas en inglés ----
  messagef("Paso (%d): ", 1L, gettext("identificar viñetas..."))
  rmd_files <- dir(,".Rmd$")
  if (!length(rmd_files)) {
    stopf("No se encontraron archivos para traducir")
  } else {
    for (i in rmd_files) catfln("* %s", i)
  }
  
  
  ## ---- paso (2) generar po desde rmd en ingles ----
  messagef("Paso (%d): %s", 2L, gettext("generar/actualizar PO a partir de viñetas en inglés..."))
  
  {
    for (f in rmd_files) 
      rmd2po(f, lang = lang_code, verbose = TRUE)
  }
  
  ## ---- paso (3) extrae texto de archivos PO ----
  messagef("Paso (%d): %s", 3L, gettext("extrae texto de archivos PO..."))
  
  if (get0("DEBUG", ifnotfound = FALSE)) readline("presione [Enter]")
  {
    # extrae directo del PO para evitar msgcat, msggrep y programas
    # similares de gettext
    message("Extraer mensajes originales (inglés) de archivos PO y generar .txt ...")
    dir.create(file.path(lang_code, "google-translations"), showWarnings = FALSE)
    files.po <- dir(file.path(lang_code, "po"), "[.]po$", full.names = TRUE) 
    files.txt <- file.path(
      lang_code, "google-translations", basename(sub(paste0("-", lang_code, "[.]po$"), "-en.txt", files.po)))
    extrae_msgid_de_po(files.po, files.txt)
  }
  
  ## ---- paso (4) subir estos txt al repo ----
  # Hacer un commit en este punto o subir a github.
  # para que google pueda traducirlo (método gratuito:;)
  
  #      usethis::create_github_token()
  #      githubr::get_git_auth()
  #      usethis::gh_token_help()
  #      gitcreds::gitcreds_cache_envvar()
  
  messagef("Paso (%d): %s", 4L, gettext("subir estos txt al repo..."))
  cat("=====\n")
  catfln("El resto del proceso es subir a repo los archivos txt y scrapear ese archivo traducido por google.")
#  catfln("algunas librerías usan llamadas web a google directamente, o scrapean las claves de la API.")
  catfln("Aunque no es lo más elegante, este método puede ser un poco más portable.")
#  catfln("Google podría cambiar detalles de la API sin demasiada explicación ¯\\_:)_/¯.")
  cat("=====\n")
  {
    GITHUB_PAT_prev <- Sys.getenv("GITHUB_PAT", unset = NA)
    PAT <- Sys.getenv("GITHUB_PAT_GITHUB_COM", unset = Sys.getenv("GITHUB_PAT"))
    Sys.setenv(GITHUB_PAT = PAT)  
    
    git_version <- try(silent = T, system2(
      "git", "--version", stdout = TRUE, stderr = nullfile()))
    
    # función personalizada de askpass. Guarda la contraseña provista 
    # en la variable PAT como side-effect.
    custom_askpass <- (function (prompt) {
      if (grepl("Please enter username for", prompt)) {
        prompt <- gettextf(
          "Ingrese el nombre de usuario de %s", 
          get0("url", parent.frame(), ifnotfound = gettext("repo remoto")))
        resp <- askpass::askpass(prompt)
      } else if (grepl("Please enter a PAT or password", prompt)) {
        prompt <- gettextf(
          "Ingrese su PAT (personal access token) de %s \n", 
          get0("url", parent.frame(), ifnotfound = gettext("repo remoto")))
        resp <- askpass::askpass(prompt)
        if (!is.null(resp)) {
          PAT <<- resp      # non local
          Sys.setenv(GITHUB_PAT = PAT)
        }
      }
      resp
    })
    
    tryCatch(
      finally = {
        if(is.na(GITHUB_PAT_prev)) Sys.unsetenv("GITHUB_PAT") 
        else Sys.setenv("GITHUB_PAT" = GITHUB_PAT_prev) }, 
      error = \(e) stopf("%s", conditionMessage(e)),
      {
        current_branch <- gert::git_branch()
        conf <- gert::git_config()
        user.name <- conf[match("user.name", conf$name, NA), "value"]
        user.name <- if (is.na(user.name)) "anonymous" else make.names(user.name)
        branch_name <- get0("branch_name") %||% sprintf(
          "transl_%s_%s", user.name, format(Sys.time(), "%Y%m%dT%H%m%z")
        )
        gert::git_branch_create(branch_name)
        gert::git_branch_set_upstream(branch_name)
        gert::git_add(file.path("vignettes", files.txt))
        if (NROW(gert::git_status(staged = TRUE, file.path("vignettes", files.txt)))) {
          messagef("Actualizando (commit) repo local, rama %s", gert::git_branch())
          gert::git_commit(gettext("Actualizar txt para traducir"))
        } else {
          message("Sin modificaciones en repo local")
        }
        
        attempt <- 0
        catfln("Debe actualizar el repo subiendo los .txt en inglés a ../google-translations")
        catfln("Luego se intentará traducir los txt desde la web, usando google")
        catfln("El script puede actualizar el repo por usted")
        catfln("Si no actualiza el repo, la traducción se hará con los mensajes del repo, que pueden estar obsoletos")
        
        while((attempt <- attempt + 1L) <= 3) {
          if (inherits(git_version, "try-error") && !nzchar(PAT) || attempt > 1L) {
            catfln("NOTA: Probablemente deba generar un Personal Access Token de Github")
          }
          switch(
            menu(title = gettext("Elija una opción"), c(
              gettext("Intentar `git pull` desde R. Es posible que se le solicite nombre de usuario y PAT de github si no tiene uno configurado"),
              gettext("Generar y/o copiar un token PAT via github (elija esta opción si no funcionó la opción 1)"),
              gettext("Continuar sin actualizar el repo (o bien actualice manualmente y luego seleccione opción 3 para continuar)"))),
            {
              # Caso 1: no hace nada e intenta git push normalmente
            },{
              # Caso 2: va a github para generar una clave token. La copia y la actualiza.
              utils::browseURL(sprintf(
                "https://github.com/settings/tokens/new?scopes=%s&description=%s",
                paste0( c("repo", "user", "gist", "workflow"), collapse = ","),
                URLencode("traducción vignettes data table")))
              readline("Copie el Personal Access Token (PAT) generado en github y presione [Enter]")
              PAT_generated <- scan("clipboard", "", 1)
              if (grepl("^gh[pousr]_[a-zA-Z0-9]{36}$", PAT_generated)) {
                PAT <- PAT_generated
                Sys.setenv("GITHUB_PAT" = PAT)
              } else
                stopf("Error: no se pudo identificar el token PAT")
            },{     
              # caso 3: sale del loop de intentos. continuar sin actualizar.
              break;  
            }
          )
          
          # intento de git push
          message("Intentando `git push`...")
          tryCatch(
            gert::git_push(password = custom_askpass),
            error = (\(e) {
              message(e)
              if (attempt < 3) {
                messagef("Nuevo intento (%d)...", attempt + 1L)
                next
              } else {
                catfln("Demasiados intentos fallidos")
                catfln("Debe actualizar manualmente el repo subiendo los .txt en inglés a ../google-translations")
                catfln("Si no actualiza el repo, la traducción se hará con los mensajes del repo, que pueden estar obsoletos")
                stopf("Demasiados intentos fallidos")
              }
            })
          )
          message("Actualización exitosa")
          break
        }
      
        # vuelve a main
        gert::git_branch_checkout(current_branch)
        gert::git_branch_delete(branch_name)
        # branch_name se preserva para el próximo paso.
      }
    )
  }
  
  
  # writeLines(sprintf("[%s](%s)", files, google_urls), "../google_translate_urls.md")
  
  ## ---- paso (5) scraping de traducciones ----
  # Todo esto se evitaría con una buena api de traducción gratuita.
  # pero NO EXISTE!
  messagef("Paso (%d): %s", 5L, gettext("scraping de traducciones..."))
  catfln("Este paso utiliza web scraping para traducir el texto extraído (peor es nada)")
  {
    files.txt.es <- sub("-en[.]txt$", paste0("-", lang_code, ".txt"), files.txt)
    for (i in 1:3) {
      switch (i,
        message("Probar con chromote (requiere google chrome)"),
        message("Probar con selenium (requiere java)"),
        stopf("no fue posible extraer traducciones."))
      result <- switch (i,
        tryCatch(
          extraer_traducciones_con_chromote(
            files.txt, files.txt.es, wait = 1.5, lang_code = lang_code, branch_name = branch_name),
          web.driver.error = \(e) (e)),
        tryCatch(
          extraer_traducciones_con_selenium(
            files.txt, files.txt.es, wait = 1.5, , lang_code = lang_code, branch_name = branch_name),
          web.driver.error = \(e) (e)))
      if (!inherits(result, "web.driver.error")) break
    }
  
    # verificar que hayan sido creados los txt traducidos
    stopifnot(all(file.exists(files.txt.es)))
  }
  
  #TODO: No es necesario actualizar los -es.txt en el repo aunque 
  # pueden quedar como backup
  
  
  ## ---- paso (6) combinar traducción en el PO ----
  messagef("Paso (%d): %s", 6L, gettext("combinar traducciones en PO..."))
  cat("====\n")
  catfln("NOTA: En este paso es que también puede modificar algo en los txt antes de continuar. Luego sólo se puede actualizar los .PO.")
  catfln("Las traducciones existentes no se modifican")
  if (interactive() && menu(c("Continuar", "Salir")) == 2) return(1)
  
  {
    # función hace el trabajo de msgcat, etc.
    # analizar si potools tiene algo similar...
    combinar_plain_txt_en_po(files.txt.es, files.po, overwrite = FALSE)    
    
    # Actualiza metadata ej: name = "Ricardo Villalba", mail = "rikivillalba@gmail.com"
    # TODO: arreglar la función. por ahora no hace nada
    md <- try(obtener_po_metadata(files.po))
    #if (!inherits(md, "try-error")) 
      
    # actualizar_po_metadata( lang_code = "es",
    #   name = "Ricardo Villalba", 
    #   email = "rikivillalba@gmail.com") 
  }
  
  ## ---- paso (7) generar .Rmd traducidos ----
  messagef("Paso (%d): %s", 7L, gettext("generar .Rmd traducidos..."))
  for (f in rmd_files) {
    rmd <- po2rmd(f, lang = lang_code, verbose = T)
  }
  
  ## ---- paso (8) cambiar rutas en código R de subcarpeta del idioma ----
  messagef("Paso (%d): %s", 7L, gettext("cambiar rutas en código R de subcarpeta del idioma..."))
  cambiar_rutas_en_Rmd(lang = lang_code)
  message("paso (9) cambiar títulos")
  #TODO: este paso está HARCODEADO. rmd2po no tiene en cuenta los títulos
  # habríoa que generar un PO con los títulos y usar ese.
  traducir_titulos_rmd()

  ## ---- paso (10) subir a repo. ----
  message("paso (10) subir a repo.")
  {
    switch(
      menu(
        title = gettextf(
          "¿Desea actualizar el repo con estas traducciones (se incluyen en la carpeta '%s')?", 
          lang_code), 
        c(gettext("Intentar `git pull` desde R"),
          gettext("Continuar sin actualizar el repo"))),
      {
        message("Intentando `git push`...")
        tryCatch(
          gert::git_push(password = custom_askpass),
          error = (\(e) {
            stopf("No se pudo actualizar repo")
          })
        )
        message("Actualización exitosa")
      },{
        # Caso 2: no hace nada
      }
    )
  }
}

local({
  startmsg <- gettext("Script para tradución automática de viñetas .Rmd")
  cat(startmsg, "\n")
  catfln(strrep("=", nchar(startmsg)))
  catfln("Utiliza partes del proyecto rmdpo - https://github.com/SciViews/rmdpo")
  setup()
  catfln("Sesión interactiva, puede haber algunas preguntas")
  cat("*** Ejecute `start_translation()` para iniciar traducción automática\n")
  cat("*** Ejecute `update_PO()` para solamente actualizar el catálogo .PO con los cambios en los .Rmd en inglés más recientes\n")
  cat("*** Ejecute `q()` para salir de R\n")
})
