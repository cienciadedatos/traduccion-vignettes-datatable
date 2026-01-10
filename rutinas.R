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

# ---- rmd2po ----


# https://github.com/SciViews/rmdpo

# Create .po files from R Markdown or Quarto documents an build translated
# versions of these documents. Internally uses Python's mdpo.
#
# Note: there is also po4a that does the job. It is a Perl program that works
# on Linux and macOS (installation through Homebrew or Macports), but I have
# found nothing for Windows. Here is what I did with it on macOS:
#
# Create, or update a .pot file for one R Markdown document
# po4a-updatepo -f text -m <doc>.Rmd -p fr/po/<doc>.pot -p fr/po/<doc>-fr.po 
# -M utf8 -o markdown -o neverwrap -o nobullets --wrap-po newlines 
# --msgid-bugs-address <mail>@sciviews.org --copyright-holder "SciViews" 
# --package-name "<doc>" --package-version "1.0.0"
#
# Translate an R Markdown document using an -fr.po file (with a minimal 
# threshold of translated text set to 80%)
# po4a-translate -f text -m <doc>.Rmd -p fr/po/<doc>-fr.po -M utf8 -l # 
# fr/<doc>.Rmd -L utf8 -o markdown -o neverwrap -o nobullets --wrap-po newlines 
# --keep 80
#
# Use a reworked (and correctly aligned!) translated .Rmd file to update the 
# -fr.po file
# po4a-gettextize -f text -m <doc>.Rmd -l fr/<doc>.Rmd -p fr/po/<doc>.pot 
# -p fr/po/<doc>-fr.po -M utf8 -L utf8 -o markdown -o neverwrap -o nobullets 
# --msgid-bugs-address <mail>@sciviews.org --copyright-holder "SciViews" 
# --package-name "<doc>" --package-version "1.0.0"

# This is a version using the mdpo Python library

.check_mdpo <- function(
    pgm = "md2po", min.version = "2.0.0", mdpodir = getOption("mdpodir")
  ) {
  if (!is.null(mdpodir) && nchar(mdpodir)) {
    pgm <- file.path(path.expand(mdpodir), pgm)
  }

  pgm_version <- tryCatch(system2(pgm,
    args = "--version",
    stdout = TRUE, stderr = TRUE
  ), error = function(e) {
    stop(gettext(
      "%s not found. Install mdpo Python library and make it available.",
      pgm,
      call = NULL
    ))
  })
  # Returned string is like "md2po 2.0.0", but we need "2.0.0" only
  pgm_version <- sub("^[^ ]+ +", "", pgm_version)
  if (package_version(pgm_version) < min.version) {
    stop(
      "%s version %s or higher is required, but %s is found.",
      pgm, min.version, pgm_version
    )
  }
  pgm
}

# md2po is not aware of the Rmd peculiarities. It does not processes correctly
# 1) The YAML header
# 2) chunks with options like {r, echo=FALSE}
# 3) List items with empty lines between items (list items are transformed
#    into plain paragraphs to avoid this). For unknown reasons, po2md
#    eliminates equations tags ($...$) in such lists => escape them by
#    replacing $ by $$$ in list items
# 4) Indentation using tabulations, to be replaced by four spaces
# 5) md2po adds footnotes a second time at the en of the .po file with a
#    traduction that is identical to the original strings. To avoid this, we
#    flag the end of the file and will delete anything past this flag in the
#    .po file as a workaround
# 6) Display equations (equations on its own line) is not correctly handled
#    by po2md and the $...$ tags disappear. So, we escape them by `$$$...$$$`
# So, we change these to something that can be easily reversed on the
# translated version to restore these Rmd/qmd features
# This is done in a temporary file
# Note: we assume that current directory is the one where we should place
# the temporary file in the "lang" subdirectory
.create_temp_rmd <- function(rmdfile, tmpfile) {
  rmddata <- readLines(rmdfile)

  # 1) YAML header
  rmddata <- sub("^---$", "~~~", rmddata)
  # 2) R chunks with options
  rmddata <- sub(
    "^( *)```\\{([a-zA-Z]+[ ,][^}]+)\\}$",
    "\\1```{chunk_with_args}\n\\1#===== \\2", rmddata
  )
  # 3) List items
  rmddata <- sub("^( *[-+*] +.+)$", "=====\\1=====", rmddata)
  rmddata <- sub("^( *[0-9]+[.)] +.+)$", "=====\\1=====", rmddata)
  # Because mdpo squeezes multiple spaces into one, we replace them with _
  # ahead of lists (down to three indentation levels)
  rmddata <- sub("^=====(    )", "=====_", rmddata)
  rmddata <- sub("^=====_(    )", "=====__", rmddata)
  rmddata <- sub("^=====__(    )", "=====___", rmddata)
  # Escape $...$ that po2md eliminates sometines by $$$...$$$,
  # but only in escaped list items
  is_escaped_list <- grepl("^=====.*=====$", rmddata)
  rmddata[is_escaped_list] <- gsub("\\$", "$$$", rmddata[is_escaped_list])
  # 4) Indentation with tabulations (up to three levels)
  rmddata <- gsub("^\t\t\t", "            ", rmddata)
  rmddata <- gsub("^\t\t", "        ", rmddata)
  rmddata <- gsub("^\t", "    ", rmddata)
  # 5) Flag the end of the file
  rmddata <- c(rmddata, "\n\n=====END=====")
  # 6) Escape equations tags in display equations
  rmddata <- sub("^( *)\\$(.+)\\$ *$", "\\1`$$$\\2$$$`", rmddata)

  writeLines(rmddata, tmpfile)
  invisible(tmpfile)
}

.cut_after_end <- function(data) {
  # Cut the .po/.Rmd/.qmd file at the "=====END=====" flag
  # (workaround for a bug in md2po and po2md that inject a second time the
  # footnotes at the end of the .po file)
  endflag <- seq_along(data)[grep("=====END=====", data)]
  if (!length(endflag)) {
    return(data)
  } # Nothing to do, no end flag found
  # We must cut the file two lines above the first occurrence of that tag
  # (for .po file, there is one entry before it)
  data <- data[1:(endflag[1] - 2)]
  data
}

.postprocess_translated_rmd <- function(rmdfile) {
  # We have to rework a little bit the produced .Rmd/.qmd file to make sure
  # the YAML header, the R chunks headers and list items are correct
  rmddata <- readLines(rmdfile)

  # 1) Restore YAML header
  rmddata <- sub("~~~", "---", rmddata, fixed = TRUE)
  # 2) Restore chunks with options
  rmddata <- sub("^( *)#===== (.+)$", "\\1```{\\2}", rmddata)
  rmddata <- rmddata[!grepl("```{chunk_with_args}", rmddata, fixed = TRUE)]
  # 3) Restore list items
  #    a) if an empty line was missing between previous block and first list
  #       item, we have to add one now
  # TODO... how ??? This is wrong: rmddata <- sub("^([^=].*) (=====.*=====)$", 
  # "\\1\n\\2", rmddata)
  #    b) restore proper equation tags $...$ instead of $$$...$$$
  is_escaped_list <- grepl("=====.*=====$", rmddata)
  rmddata[is_escaped_list] <- gsub("\\$\\$\\$", "$", rmddata[is_escaped_list])
  #    c) restore proper spaces before indented list items)
  rmddata <- sub("^=====___", "=====           ", rmddata)
  rmddata <- sub("^=====__", "=====        ", rmddata)
  rmddata <- sub("^=====_", "=====    ", rmddata)
  #    d) restore list items
  rmddata <- sub("^=====( *[-+*] *.+)=====$", "\\1", rmddata)
  rmddata <- sub("^=====( *[0-9]+[.)] *.+)=====$", "\\1", rmddata)
  rmddata <- gsub("===== =====", "\n", rmddata, fixed = TRUE)
  # 4) Tabs replaced by four spaces at the beginning of lines -> keep them
  # 5) Remove the "=====END=====" flag and what is after it
  rmddata <- .cut_after_end(rmddata)
  # 6) Remove escape codes for display equations
  rmddata <- sub("^( *)`\\$\\$\\$(.+)\\$\\$\\$`$", "\\1$\\2$", rmddata)

  # This is not needed any more with the wrapping of list items within
  # Kept here commented for reference
  ## Indent code correctly in indented code chunks
  ## po2md indents tags and sometimes first line, but not the remaining lines
  ## This produces incorrect results => indent all lines now inside the chunk
  # inchunks <- grepl("^ +```", rmddata)
  # if (any(inchunks)) {
  #  # Verification: should be an even number
  #  if ((sum(inchunks) %% 2) != 0)
  #    stop("Incorrect number of indented code chunks markers in ", rmdfile)
  #  inchunklines <- (1:length(rmddata))[inchunks]
  #  # Odd lines are start markers, even lines are end markers
  #  starts <- inchunklines[c(TRUE, FALSE)]
  #  ends <- inchunklines[c(FALSE, TRUE)]
  #  # Process each chunk in turn
  #  for (i in seq_along(starts)) {
  #    chunk_range <- starts[i]:ends[i]
  #    chunk_header <- rmddata[starts[i]]
  #    # Number of space to use for indentation (seems to be always 3, but we
  #    # prefer to get it from the start header)
  #    spaces <- sub("^( +)`.*$", "\\1", chunk_header)
  #    # If we have a complex chunk header we also have to indent first line,
  #    # otherwise, not
  #    indent_first_line <- 3 # First code line is already correctly indented
  #    is_complex <- grepl("^( *)```\\{([a-zA-Z]+[ ,][^}]+)\\}$", chunk_header)
  #    if (is_complex) indent_first_line <- 2 # but not in this case
  #    # Are there remaining lines to indent?
  #    if (length(chunk_range) - indent_first_line > 0) {
  #      # Indent all remaining lines
  #      indent_range <- chunk_range[indent_first_line:(length(chunk_range) - 1)]
  #      rmddata[indent_range] <- paste0(spaces, rmddata[indent_range])
  #    }
  #  }
  # }
  #
  writeLines(rmddata, rmdfile)

  invisible(rmdfile)
}

#' Create a poEdit file from an R Markdown or Quarto document, or translate such a document using the .po file
#'
#' @param rmdfile The path to the R Markdown or Quarto document to translate
#' @param lang The language to translate to, like `"fr"` for French, `"es"` for
#'   Spanish, ... Also the subdirectory to the directory where the original file
#'   is located where to place the translated .Rmd or .qmd file.
#' @param podir The subdirectory of `lang` where to place the .po file (by
#'   default, it is `"po"`)
#' @param mdpodir The directory that contains md2po and po2md programs (`NULL`,
#'   by default, if these programs are accessible directly from the command
#'   line within the R process)
#' @param min.version The minimum version of md2po and po2md required (string
#'   like "2.0.0")
#' @param verbose If `TRUE`, print more info about md2po or po2md and the
#'   command that is executed
#'
#' @details This function internally uses md2po and po2md CLI programs that are
#' from the mdpo Python library. You have to install these before use and make
#' sure that md2po and po2md are accessible on the command line from within R,
#' or provide the absolute path where they are located in the `"mdpodir"` option
#' using something like `options(mdpodir = "/usr/bin")`.
#' md2po is not dealing well with YAML headers, chunk headers and list items in
#' the .Rmd/.qmd files. A special code '=====' is introduced in the strings to
#' "escape" them from a wrong processing by md2po. This code is removed in the
#' final translated .Rmd/.qmd file.
#' You should leave these "=====" codes in the translated string too in the .po
#' file.
#'
#' **A few advise when you translate the strings in poEdit:**
#' - Use a correct syntax in your .Rmd/.qmd file. Indent by **four** spaces when
#' required (do **not** use two spaces to indent items inside lists, for
#' instance). Do not wrap paragraphs and place one empty line between each
#' block. That way, you will get an exact correspondence of line numbers between
#' the original and translated .Rmd/.qmd files. Bring correction in the layout of
#' the original file, if needed.
#' - The string "#=====" tags a complex chunk header. You should not change it,
#' except, may be the content of `fig.cap="..."` that could be translated.
#' - For chunks, it is easier to start from an identical copy using
#' Ctrl-B/Cmd-B. Most of the time, nothing or very little parts must be changed
#' (mostly comments, but also see next point here under). Take care of quotes ',
#' and " that could be changed, depending on the language used (e.g., French).
#' The French quotes are, of course, inappropriate in R code. If the change is
#' automatic in poEdit, Ctrl-Z/Cmd-Z undoes the change.
#' - Where the .Rmd/.qmd refers to a document in the same directory or in a
#' subdirectory, remember that the translated vignette is located in a "<lang>"
#' subdirectory. It means that the relative path must be prepended with "../" to
#' reflect its new location. For instance, for a dataset "flights14.csv",
#' `fread('fligth14.csv')` must be changed into `fread('../flights14.csv')` in
#' the translated version. Also for a figure "fig1.png" in, say the "plots"
#' subdirectory, `![](plots/fig1.png)` must be changed into
#' `![](../plots/fig1.png)`. Finally, documents referred in the YAML header must
#' also be changed accordingly. For a "style.css" file in the "css"
#' subdirectory, change `css: [default, css/toc.css]` into
#' `css: [default, ../css/toc.css]` in the YAML header of the translated .Rmd
#' file. This way, there is no need to duplicate files. Failure to do so will
#' result in an error during compilation of the .Rmd file. So, go back to
#' poEdit, correct the concerned item, and relaunch `po2rmd()` until compilation
#' runs flawlessly.
#' - List items are surrounded by "=====" markers. This is to avoid po2md to
#' reinterpret them in a different way, and it is also to draw your attention on
#' pieces of text that may not be complete sentences. Keep the exact same tags
#' in the translated version. If list items are not separated by an empty line,
#' they are concatenated into a single string in poEdit, something like:
#' "=====1. First item===== =====2. Second item===== =====3. Third item====="
#' This is normal. Just keep the same tags and correct list items will be placed
#' in the final translated .Rmd/.qmd file by `rmd2po()`.
#'
#' @return The path to the .po file (for `rmd2po()`) or to the translated
#'   Rmd/qmd file (for `po2rmd()`) is returned. The .po file or the translated
#'   Rmd/qmd file is created or updated on each call of the respective function.
#' @export
#'
#' @examples
#' # TODO: and example using a short vignette
# NOTE: md2po does not process quoted paths correctly. It is thus better to
# temporarily switch to the directory where the rdmfile is located and to
# always escape spaces with backslashes if they exist in the vignette name
# It also waits for the name of the md file to process on stdin, even if it
# is provided as first argument (both using system() and system2()). So, we
# provide it through input =
# @@ EN WINDOWS hay algún problema para leer UTF8 de stdin, así que pruebo
# pasando el nombre de archivo.
# @@ eliminado:
# @param keep.tmpfile If `TRUE`, keep the modified .tmp file that is created
# from the original .Rmd/.qmd to allow better handling of YAML header and R
# chunks. `FALSE` by default, change it only for debugging purposes
rmd2po <- function(rmdfile, lang = "fr", podir = "po",
                   mdpodir = getOption("mdpodir"), min.version = "2.0.0",
                   verbose = FALSE, cmd_options = character(0)) {
  # chequear cmd_options
  check_options(cmd_options)
  # Check external program availability and version
  md2po <- .check_mdpo("md2po", min.version = min.version, mdpodir = mdpodir)

  if (!file.exists(rmdfile)) {
    stop(gettext("The file '%s' is not found.", rmdfile))
  }


  rmddir <- dirname(rmdfile)
  rmdfilename <- basename(rmdfile)
  odir <- setwd(rmddir) # see NOTE above
  tmpfile <- file.path(lang, paste0(basename(rmdfile), ".tmp"))
  exit_code <- 0
  tryCatch(
    finally = {
      setwd(odir)
      unlink(tmpfile)
    }, {
      if (isTRUE(verbose)) {
        message("Procesando ", rmdfilename)
      }
      # Make sure required subdirectories exist
      dir.create(lang, showWarnings = FALSE)
      dir.create(file.path(lang, podir), showWarnings = FALSE)

      # Create temporary file with modified Rmd/qmd file so that it is correctly
      # processed with md2po
      .create_temp_rmd(rmdfile, tmpfile)

      # Create the .po file, using md2po on the temporary rmd file
      pofile <- file.path(lang, podir, paste0(rmdfilename, "-", lang, ".po"))

      if (length(cmd_options)) {
        message("Opciones extra: ", paste(cmd_options, collapse = " "))
      }
      cmd_output_tmp <- tempfile()

      # Usando https://pypi.org/project/mdpo/
      # @@ agregué:
      #  --metadata
      # @@ quité
      #  --include-codeblocks
      # la entrada se puede especificar como nombre de archivo o como stdin.
      # pero leer NOTA ut supra
      tryCatch(
        finally = unlink(cmd_output_tmp),
        {
          exit_code <- system2(
            command = md2po,
            args = c(
              "--quiet", "--save",
              "--merge-pofiles", # Mantiene traducciones existentes
              "--remove-not-found",
              "--metadata", shQuote(sprintf("Language: %s", lang)),
              "--metadata", shQuote(
                sprintf("PO-Revision-Date: %s", format(Sys.time(), "%Y-%m-%d %H:%M%z"))
              ),
              cmd_options, # do not put last
              "--po-filepath", shQuote(pofile),
              shQuote(tmpfile)
            ),
            #            stdin = tmpfile,
            stdout = cmd_output_tmp,
            stderr = cmd_output_tmp
          )
          cmd_output <- readLines(cmd_output_tmp)
          if (exit_code) {
            message("Aviso: md2po terminó con estado de salida no cero: ", exit_code)
          }
        }
      )
    }
  )
  msg_ver <- R"--{
Nota: en Windows, la instalación de mdpo requiere compilación (MSVC) para 
python>3.8\. Específicamente el componente md4c sólo tiene binarios (whl) hasta
python 3.8., En caso de errores, reiniciar arrancando previamente un entorno 
virtual con esa versión de python (por ejemplo use_virtualenv())}--"
  
  if (exit_code) message(msg_ver)
  if (isTRUE(verbose) && any(nzchar(cmd_output))) {
    if (any(grepl("OSError:", cmd_output))) {
      cmd_output <- sub(".*OSError:", "OSError:", cmd_output)
      message(cmd_output)
    } else {
      message("salida de md2po: ", cmd_output)
    }
  }

  # Cut any unnecessary parts in the .po file
  writeLines(.cut_after_end(readLines(pofile)), pofile)

  file.path(rmddir, pofile)
}

check_options <- function(cmd_options) {
  # chequear cmd_options
  re_opt <- "^[\\1].*[\\2]$|^([^[:blank:]\\1]|\\\\\\\\\\1)*$"
  cmd_isswitch <- grepl("^--?\\S+$", cmd_options)
  for (i in seq_along(cmd_options)) {
    if (!cmd_isswitch[i] && c(TRUE, !cmd_isswitch)[i]) {
      stop("bad cmd_options (two consecutive values with no option")
    } else if (!grepl(sub("(.)(.)", re_opt, shQuote("")), cmd_options[i])) {
      stop("bad cmd_options (no shQuote'd or extra space)")
    }
  }
}

# NOTE: po2md does not process quoted paths correctly. It is thus better to
# temporarily switch to the directory where the rdmfile is located and to
# always escape spaces with backslashes if they exist in the vignette name
# It also waits for the name of the md file to process on stdin, even if it
# is provided as first argument (both using system() and system2()). So, we
# provide it through input =
# @@ EN WINDOWS hay algún problema para leer UTF8 de stdin, así que pruebo
# pasando el nombre del archivo
po2rmd <- function(rmdfile, lang = "fr", podir = "po",
                   mdpodir = getOption("mdpodir"), min.version = "2.0.0",
                   verbose = FALSE, cmd_options = character(0)) {
  check_options(cmd_options)
  po2md <- .check_mdpo("po2md", min.version = min.version, mdpodir = mdpodir)
  if (!file.exists(rmdfile)) {
    stop("The file '%s' is not found. ", rmdfile)
  } else if (!dir.exists(rmddir <- dirname(rmdfile))) {
    stop("The directory is not found. ", rmddir)
  }

  rmdfilename <- basename(rmdfile)
  odir <- setwd(rmddir) # read NOTE above.
  if (normalizePath(getwd()) != normalizePath(odir) && verbose) {
    message("cambiando a: ", rmddir)
  }
  tmpfile <- file.path(lang, paste0(basename(rmdfile), ".tmp"))
  tryCatch(
    finally = {
      unlink(tmpfile)
      setwd(odir)
    }, {
      if (isTRUE(verbose)) {
        message("Procesando ", rmdfilename)
      }

      # Make sure required subdirectories exist
      # Create temporary file, if needed, with modified Rmd/qmd file so that it is
      # correctly processed with po2md
      dir.create(lang, showWarnings = FALSE)
      .create_temp_rmd(rmdfile, tmpfile)

      # Create translated .Rmd/.qmd file using the temporary .Rmd/.qmd and .po file
      rmd2file <- file.path(lang, rmdfilename)
      pofile <- file.path(lang, podir, paste0(rmdfilename, "-", lang, ".po"))
      if (!file.exists(pofile)) {
        stop(gettext("The .po file '%s' is not found.", pofile))
      }

      cmd_output_tmp <- tempfile()
      # la entrada se puede especificar como nombre de archivo o como stdin.
      # pero leer NOTA ut supra
      tryCatch(
        finally = unlink(cmd_output_tmp),
        {
          exit_code <- system2(
            command = po2md,
            args = c(
              "--po-files", shQuote(pofile),
              "--save", shQuote(rmd2file),
              "--wrapwidth", "0", # Necesario para que .postprocess.. funcione
              cmd_options, # que no sea el último
              "--quiet",
              # c("--no-obsolete", "--no-fuzzy", "--no-empty-msgstr"),    # desactivado por ahora
              shQuote(tmpfile)
            ),
            #            stdin = tmpfile,
            stdout = cmd_output_tmp,
            stderr = cmd_output_tmp
          )
          cmd_output <- readLines(cmd_output_tmp)
        }
      )
      if (exit_code) {
        message("Aviso: md2po terminó con estado de salida no cero: ", exit_code)
      }
      # Rework the translated .Rmd/.qmd file to restore YAML header, R chunks and
      # list items
      .postprocess_translated_rmd(rmd2file)

      file.path(rmddir, rmd2file)
    }
  )
}

# ---- funciones auxiliares ----

# dada la posición de espacios en una cadena, devuelve las
# posicones en que hay que saltar la línea para limitarla
# a wd caracteres (wd - 2 ya que considera comillas)
# siempre sobre espacios en blanco.
# por defectolas palabras > wd largas se quiebran en un punto arbitrario.
wrap_msg <- function(m, wd = 80, wrap.long.words = TRUE) {
  f <- \(m, p = 0)
  if (any(x <- m > p & m < wd - 2 + p)) {
    c(p, f(m, m[rev(which(x))][1]))
  } else if (any(m > p)) {
    c(p, f(m, if (wrap.long.words) wd - 2 + p else m[which(m > p)[1]]))
  } else if (m[length(m)] == p + 1) {
    integer()
  } else {
    p
  }
  f(m)
}

# debug(wrap_msg)
# Función auxiliar para sustitución con regmatches<-
regex_sub <- function(x, pattern, ...) {
  matches <- regexec(pattern, x)
  drop_first <- function(x) {
    if (!anyNA(x) && all(x > 0)) {
      ml <- attr(x, "match.length")
      if (is.matrix(x)) x <- x[-1, ] else x <- x[-1]
      attr(x, "match.length") <- if (is.matrix(ml)) ml[-1, ] else ml[-1]
      x
    } else {
      x
    }
  }
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
get_po_msgs <- function(lines_po) {
  EOF <- length(lines_po) + 1
  # msgid_pos: posisción de msgid o msgstr
  # no_str_pos: comandos y EOF. todo excepto #s, o cadenas (incl. msgid_pos)
  # str_pos: cadenas sin comandos ni #s
  msgid_cmd <- c(grep("^\\s*msgid\\s+\"", lines_po), EOF)
  msgstr_cmd <- c(grep("^\\s*msgstr\\s+\"", lines_po), EOF)
  no_str_pos <- c(grep("^\\s*[^\"#]", lines_po), EOF)
  str_pos <- grep("\\s*[\"]", lines_po)

  pos_from_cmd <- function(cmd) {
    lapply(seq_len(length(cmd) - 1L), function(i) {
      l <- cmd[i]
      r <- min(cmd[i + 1L], no_str_pos[no_str_pos > cmd[i]])
      union(l, str_pos[str_pos >= l & str_pos < r])
    })
  }
  pttrn_cmd <- "\\s*(msg(id(_plural)?|str( *\\[ *\\d+ *\\])?))?"
  pttrn_data <- "\\s*\"(([^\"]|([\\]\"))*)\"\\s*(#.*)?"
  pattern <- paste0("$", pttrn_cmd, pttrn_data, "$")
  msg_from_pos <- function(pos) {
    paste0(sub(pattern, "\\5", lines_po[pos]), collapse = "")
  }

  msgid_pos <- pos_from_cmd(msgid_cmd)
  msgstr_pos <- pos_from_cmd(msgstr_cmd)
  msgid <- unlist(lapply(msgid_pos, msg_from_pos))
  msgstr <- unlist(lapply(msgstr_pos, msg_from_pos))

  list(
    msgid = msgid, msgstr = msgstr,
    msgid_pos = msgid_pos, msgstr_pos = msgstr_pos
  )
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
# DEBUG: files.po = "es/po/datatable-benchmarking.Rmd-es.po"
# DEBUG: files.txt = "es/google-translations/datatable-benchmarking.Rmd-en.txt"
extrae_msgid_de_po <- function(files.po, files.txt) {
  for (i in seq_along(files.po)) {
    all_lines <- readLines(files.po[i])
    lines <- all_lines[grep("^\\s*(msg|\")", all_lines)]
    msgs <- grep("^\\s*(msg(id|id_plural|str(\\s*\\[\\d*\\])?))", lines)
    grps <- cut(seq_along(lines), c(msgs, Inf), labels = FALSE, right = FALSE)
    msgids <- grep("^\\s*(msgid(_plural)?)", lines[msgs])
    text <- vapply(seq_along(msgids), "", FUN = function(j) {
      paste0(sub(
        "^\\s*(msgid(_plural)?)?\\s*\"(([^\"]|\\\\.)*)\".*", "\\3",
        lines[grps == msgids[j]]
      ), collapse = "")
    })
    # generalmente el primer msgid es vacío
    if (nzchar(text[1])) {
      stop("El primer msgid del PO debería ser vacío (msgstr es la descripción)")
    }
    writeLines(text[-1], files.txt[i])
  }
}

# toma los archivos txt linea por linea y los incorpora a las
# entradas "msgstr" del PO, partiendo lineas largas si es necesario
# debugonce(combinar_plain_txt_en_po)
combinar_plain_txt_en_po <- function(po_txt_file, po_file, overwrite = FALSE) {
  message("Combinando ", basename(po_txt_file), " en ", basename(po_file))
  tryCatch(
    {
      lines_po <- readLines(po_file)
      lines_txt <- readLines(po_txt_file) |>
        gsub(pattern = "(?<!\\\\)\"", replacement = "\\\\\"", perl = TRUE)
      lines_txt <- lines_txt[cumsum(nchar(lines_txt)) > 0]
      # msgstr_pos es la posición de los msgstr en el po
      # other_pos es la posición de todo el resto
      # la primera línea de msgstr es el encabezado del PO. No se incluye.
      po_nl <- length(lines_po)
      txt_nl <- length(lines_txt)
      #      o_from <- c(0L, vapply(po$msgstr_pos, tail, 0, 1L) + 1L)
      #      o_to <- c(vapply(po$msgstr_pos, head, 0, 1L) - 1L, po_nl + 1L)
      msgs <- get_po_msgs(lines_po)
      o_from <- c(1L, vapply(msgs$msgstr_pos, tail, 0, 1L) + 1L)
      o_to <- c(vapply(msgs$msgstr_pos, head, 0, 1L) - 1L, po_nl)


      # other_pos <- Map(
      #   f = seq,
      #   c(0L, vapply(po$msgstr_pos, tail, 0, 1L) + 1L),
      #   c(vapply(po$msgstr_pos, head, 0, 1L) - 1L, nl + 1L)
      # )

      # los .po y los archivos txt planos deben tener el mismo nro de elementos
      # browser()
      if (length(msgs$msgstr[-1]) != txt_nl) {
        msg <- "Número de entradas .po y .txt no coinciden."
        stop(msg, class = "length.mismatch")
      }

      # TODO: esta parte formatea lines_txt aunque overwrite=FALSe (innecesario)
      # saltos de línea en lineas largas wd <- 80
      msgstr_new <- list()
      msgstr_new[[1]] <- lines_po[msgs$msgstr_pos[[1]]]
      msgstr_new[2:(txt_nl + 1)] <- lapply(lines_txt, function(x) {
        m <- gregexpr("\\s(?=\\S)|$", x, perl = T)[[1]]
        if (nchar(x) <= 80 - nchar("msgstr") - 2) {
          paste0("msgstr ", "\"", x, "\"")
        } else {
          cuts <- wrap_msg(m, wd = 80)
          l <- length(cuts)
          s <- paste0('"', substr(rep(x, l - 1), cuts[-l] + 1L, cuts[-1L]), '"')
          c("msgstr \"\"", s)
        }
      })

      no_empty <- nzchar(msgs$msgstr)
      if (overwrite && any(no_empty[-1])) {
        warning("AVISO: algunos mensajes ya traducidos se reemplazan por nueva versión de google")
      } else {
        # restaurar originales
        msgstr_new[no_empty][-1] <-
          lapply(msgs$msgstr_pos[no_empty][-1], \(i) lines_po[i])
      }

      # if (overwrite) {
      #   no_empty <-
      #     which(lines_txt[nzchar(msgs$msgstr[-1L])] != msgs[nzchar(msgs)])
      #   if ((n <- length(no_empty) > 0) {
      #       msg <- gettext("AVISO: %d mensajes ya traducidos se reemplazan por nueva versión de google", n)
      #       warning(msg)
      # } else {
      #   msgstr[nzchar(msgs)] <- lapply(msgstr_pos[nzchar(msgs)], \(l) lines_po[l])
      # }
      # no_empty <-
      #   which(lines_txt[nzchar(msgs$msgstr[-1L])] != msgs[nzchar(msgs)])


      # other <- lapply(other_pos, \(s) lines_po[s[s <= length(lines_po)]])

      po <- list()
      # vector("list", length(msgstr) + length(other))
      # prev <- seq(o_from[1], length.out = o_to[1] - o_from[1] + 1)
      # po[[1L]] <- lines_po[prev]
      # po[[2L]] <- lines_po[msgs$mgstr_pos[[1L]]]
      for (i in seq_len(txt_nl + 1)) {
        prev <- seq(o_from[i], length.out = o_to[i] - o_from[i] + 1)
        po[[2L * (i - 1L) + 1]] <- lines_po[prev]
        po[[2L * (i - 1L) + 2]] <- msgstr_new[[i]]
      }
      # comments al final?
      trail <- seq(o_from[i + 1], length.out = po_nl - o_from[i + 1] + 1)
      po[[2L * i + 1L]] <- lines_po[trail]
      browser()

      writeLines(unlist(po, FALSE, FALSE), po_file)
    },
    error = \(e) {
      stop(e)
    }
  )
}

# Actualiza la metadata en PO (fecha de revisión, Last translator...)
actualizar_po_metadata <- function(po_files, name, email, lang_code) {
  lapply(po_files, \(i) {
    lines <- readLines(i)
    lines |>
      regex_sub("\"Project-Id-Version: (.*)\\\\n\"", "0.0.1") |>
      regex_sub("\"PO-Revision-Date: (.*)\\\\n\"", format(Sys.time(), format = "%Y-%m-%d %H:%M%z")) |>
      regex_sub("\"Last-Translator: (.*)\\\\n\"", sprintf("%s <%s>", name, email)) |>
      regex_sub("\"Language-Team: (.*)\\\\n\"", lang_code) |>
      append(
        sprintf("\"Language: %s\\n\"", lang_code),
        after = grep("\"Language-Team: (.*)\\\\n\"", lines)
      ) |>
      writeLines(i)
  })
  invisible()
}


# TODO: Script provisorio para traducir los títulos
traducir_titulos_rmd <- function(lang_code = "es") {
  # títulos en inglés
  #   datatable-benchmarking.Rmd: "Benchmarking data.table",
  #   datatable-faq.Rmd: "Frequently Asked Questions about data.table",
  #   datatable-importing.Rmd: "Importing data.table",
  #   datatable-intro.Rmd: "Introduction to data.table",
  #   datatable-keys-fast-subset.Rmd: "Keys and fast binary search based subset",
  #   datatable-programming.Rmd: "Programming on data.table",
  #   datatable-reference-semantics.Rmd: "Reference semantics",
  #   datatable-reshape.Rmd: "Efficient reshaping using data.tables",
  #   datatable-sd-usage.Rmd: "Using .SD for Data Analysis",
  #   datatable-fread-and-fwrite.Rmd: "Fast Read and Fast Write",
  #   datatable-secondary-indices-and-auto-indexing.Rmd: "Secondary indices and auto indexing",
  #   datatable-joins.Rmd: "Joins in data.table"
  # titles missing: "joins and rolling joins", "data.table internals"

  titles_es <- c(
    `datatable-benchmarking.Rmd` = "Benchmarking con data.table",
    `datatable-faq.Rmd` = "Preguntas frecuentes sobre data.table",
    `datatable-importing.Rmd` = "Importar data.table",
    `datatable-intro.Rmd` = "Introducción a data.table",
    `datatable-keys-fast-subset.Rmd` = "Claves y filtrado rápido con búsqueda binaria",
    `datatable-programming.Rmd` = "Programación en data.table",
    `datatable-reference-semantics.Rmd` = "Semántica de referencia",
    `datatable-reshape.Rmd` = "Remodelado eficiente con data.table",
    `datatable-sd-usage.Rmd` = "Uso de .SD para Análisis de datos",
    `datatable-fread-and-fwrite.Rmd` = "Lectura y escritura rápida: fread()/fwrite()",
    `datatable-secondary-indices-and-auto-indexing.Rmd` = "Índices secundarios y auto indexación",
    `datatable-joins.Rmd` = "Uniones «join» en data.table"
  )
  rmd_files <- dir(lang_code, pattern = ".Rmd$", full.names = TRUE)
  lapply(rmd_files, function(f, i = basename(f)) {
    if (i %in% names(titles_es)) {
      lines <- readLines(f)
      if ((length(n <- grep("title: \"(.*)\"", lines))) == 1) {
        prev <- sub(".*title: \"(.*)\".*", "\\1", lines[n])
        if (prev == titles_es[i]) {
          message("Título no se cambia: ", prev)
        } else {
          writeLines(
            regex_sub(lines, "title: \"(.*)\"", titles_es[i]), f
          )
          message("Título cambiado: ", prev, "-->", titles_es[i])
        }
      } else {
        warning("no se puede individualizar \"title\"")
      }
    } else {
      warning(gettext("título para %s no en titles_es (lista de traducidos)", i))
    }
  })
  invisible()
}

# usa SELENIUM para traducir con google desde github
extraer_traducciones_con_selenium <- function(
  files, files_es, wait = .8, lang_code, branch_name
) {
  errors <- list()
  for (i in 1:3) {
    result <- switch(i, {
      try(selenium_driver <- RSelenium::rsDriver(
        browser = "chrome", check = FALSE, extraCapabilities = list(
          chromeOptions = list(prefs = list(
            "profile.default_content_settings.popups" = 0L
          ))
        )
      ))
    }, {
      try(selenium_driver <- RSelenium::rsDriver())
    }, {
      stop(
        "No fue posible iniciar Selenium: %s.", paste(vapply(errors, conditionMessage), sep = "\n"),
        class = "web.driver.error", call = sys.call()
      )
    })
    if (!inherits(result, "try-error")) {
      break
    } else {
      errors <- c(errors, list(attr(result, "condition")))
    }
  }

  # Estos links vinculan a las traducciones de google
  # original: https://raw.githubusercontent.com/cienciadedatos/
  # traduccion-vignettes-datatable/refs/heads/%s/vignettes/%s"
  google_urls <- sprintf(
    "https://raw-githubusercontent-com.translate.goog/cienciadedatos/",
    "traduccion-vignettes-datatable/refs/heads/%s/vignettes/%s?%s",
    branch_name,
    URLencode(files),
    sprintf("_x_tr_sl=%s&_x_tr_tl=%s", "en", lang_code)
  )
  tryCatch(
    error = \(e) message(e),
    finally = selenium_driver$server$stop,
    for (i in seq(files)) {
      message(google_urls[i])
      selenium_driver$client$navigate(google_urls[i])
      message(gettext("Esperar %f seg.", wait))
      selenium_driver$server$process$wait(1000 * wait)

      element <- selenium_driver$client$findElement(using = "xpath", "/html/body/pre")
      if (!length(element)) {
        stop("Problema al analizar el documento con chromote, no fue posible interpretar html de la traducción, pruebe mayor wait.")
      }

      lines <- element$getElementText()[[1]] |>
        strsplit("\n", fixed = TRUE) |>
        _[[1]]
      writeLines(lines, files_es[i])
      message(gettext("%s OK.", files_es[i]))
    }
  )
  invisible()
}

# client$view() # para verlo en chrome
extraer_traducciones_con_chromote <- function(
  files, files_es, wait = .8, lang_code, branch_name
) {
  options("chromote.launch.echo_cmd" = TRUE)
  tryCatch(
    client <- chromote::ChromoteSession$new(),
    error = \(e) stop(
      "No fue posible iniciar ChromoteSession (google devtools protocol). ",
      conditionMessage(e),
      class = "web.driver.error",
      call = sys.call()
    )
  )
  # Estos links vinculan a las traducciones de google
  google_urls <- sprintf(
    "https://%s/%s/%s/%s?%s",
    "raw-githubusercontent-com.translate.goog",
    "cienciadedatos/traduccion-vignettes-datatable",
    sprintf("refs/heads/%s", URLencode(branch_name)),
    sprintf("vignettes/%s", URLencode(files)),
    sprintf("_x_tr_sl=%s&_x_tr_tl=%s", "en", lang_code)
  )

  raw_urls <- sprintf(
    "https://%s/%s/%s/%s",
    "raw.githubusercontent.com",
    "cienciadedatos/traduccion-vignettes-datatable",
    sprintf("refs/heads/%s", URLencode(branch_name)),
    sprintf("vignettes/%s", URLencode(files))
  )

  # por las dudas, quizá en background no traduce
  DOM <- client$DOM
  tryCatch(
    finally = client$close(),
    for (i in seq(files)) {
      attempt <- 0L
      while (TRUE) {
        message(google_urls[i])
        client$Page$navigate(google_urls[i])
        message(gettext("Esperar %0.1f seg.", wait))
        Sys.sleep(wait)
        doc.nodeId <- DOM$getDocument()[[1]]$nodeId
        sel.nodeId <- DOM$querySelector(
          nodeId = doc.nodeId, selector = "html > body > pre"
        )[[1]]
        if (sel.nodeId == 0) {
          #          client$view()
          #          if (!askYesNo("Problema al analizar el documento con chromote: no fue posible interpretar html de la traducción ¿desea continuar?", prompts = "S/N/C")) {
          message("nodo principal no encontrado.")
          if (attempt >= 2) stop("Demasiados intentos fallidos.")
          message("Espera 30 seg por si se debe a bloqueo de uso servidor...")
          Sys.sleep(30)
          attempt <- attempt + 1L
          next
        }
        outerHtml <- DOM$getOuterHTML(sel.nodeId)[[1]]
        lines <- xml2::read_html(outerHtml) |>
          xml2::xml_text() |>
          strsplit("\n", fixed = TRUE) |>
          unlist(FALSE, FALSE)
        lines_orig <- tryCatch(
          readLines(url(raw_urls[i])),
          error = \(e) {
            message("Intentando de nuevo en 5s...")
            Sys.sleep(5.0)
            readLines(suppressWarnings(url(raw_urls[i])))
          }
        )
        if (length(lines_orig) != length(lines)) {
          stop("Número de líneas original y traducido difieren")
        } else if (all(lines_orig == lines)) {
          if (attempt < 3L) {
            message("Los mensajes no parecen haberse traducido. Esperar un poco más")
            attempt <- attempt + 1L
            next
          }
        } else {
          # TODO: debugging
          if (!identical(
            grep("write.translation.links", lines),
            grep("write.translation.links", lines_orig)
          ) |
            !length(grep("write.translation.links", lines))) {
            browser()
          }
          break
        }
        warning(
          "No se encontraron diferencias entre original y traducido ",
          "después de varios intentos"
        )
        break
      }
      writeLines(lines, files_es[i])
      message("ok ", files_es[i])
    }
  )
  invisible()
}


update_PO <- function(lang_code = "es") {
  setup()
  basedir <- getwd()
  on.exit({
    setwd(basedir)
  })
  message("Cambiando a directorio «./vignettes»")
  setwd(file.path(basedir, "vignettes"))

  message("identificar viñetas...")
  rmd_files <- dir(, ".Rmd$")
  if (!length(rmd_files)) {
    stop("No se encontraron archivos para traducir")
  } else {
    for (i in rmd_files) cat("*", i)
  }

  for (f in rmd_files) {
    rmd2po(f, lang = lang_code, verbose = TRUE)
  }
  message("Listo")
}

# ---- Inicio ----
start_translation <- function(lang_code = "es") {
  # En Windows necesito python 3.8esto porque la librería rmpo sólo tiene
  # paquetes pre-compilados hasta esta versión
  #  py_available(TRUE)  # check for Python
  require(reticulate)
  local({
    try(return(use_virtualenv("r-reticulate3.8")), silent = TRUE)
    try(return(use_python()))
  })
  py_config()

  if (basename(getwd()) == "vignettes" && !"./vignettes" %in% list.dirs()) {
    setwd("..")
  }
  # verificar md2po
  # sitio del proyecto: https://pypi.org/project/mdpo/
  cat("chequear que exista `mdpo`...")
  tryCatch(
    .check_mdpo(),
    error = (function(e) {
      message("%s: Instalar mdpo (si no está instalado)...", conditionMessage(e))
      # AVISO: En windows, mdpo sólo está disponible hasta 3.11,
      # luego requiere compilación (visual studio toolchain)"
      # as.numeric_version(py_version()) > "3.11"
      # && .Platform$OS.type == "windows"
      py_install("mdpo", pip = TRUE)
    })
  )

  if (basename(getwd()) == "vignettes") {
    setwd("..")
  }
  basedir <- getwd()
  on.exit(setwd(basedir))
  tryCatch(
    {
      setwd(file.path(basedir, "vignettes"))
      cat("Cambiando a directorio «./vignettes»\n")
    },
    error = \(e) {
      e$message <- paste(
        e$message,
        "¿su directorio actual es ./traduccion-vignettes-datatable?"
      )
      stop(e)
    }
  )

  # Acá empieza el script.
  # ~~~~~~~~~~~~~~~~~~~~~~

  cat("bajar últimos .Rmd del repo de data.table\n")
  rmd_url <-
    "https://api.github.com/repos/Rdatatable/data.table/contents/vignettes"
  files <- httr2::request(rmd_url) |>
    httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = TRUE)
  files <- files[grep("(?i)[.]Rmd$", files$name), ]

  files$download_url |>
    lapply(httr2::request) |>
    httr2::req_perform_parallel(paths = files$name)

  rmd_files <- dir(, ".Rmd$")
  if (!length(rmd_files)) {
    stop("No se encontraron archivos para traducir")
  } else {
    for (i in rmd_files) cat("*", i, "\n")
  }


  cat("Generar/actualizar PO a partir de viñetas en inglés...\n")
  for (f in rmd_files) {
    # generar archivos en ./vignettes/es/po/*.po
    # las traducciones existentes se mantienen.
    rmd2po(f, lang = lang_code, verbose = TRUE)
  }
  # message("generar/actualizar PO a partir de viñetas en inglés...")

  ## ---- paso (3) extrae texto de archivos PO ----
  cat("Extraer mensajes originales (inglés) de archivos PO y generar .txt\n")
  dir.create(file.path(lang_code, "google-translations"), showWarnings = FALSE)
  files.po <- dir(file.path(lang_code, "po"), "[.]po$", full.names = TRUE)
  files.txt <- file.path(
    lang_code, "google-translations",
    basename(sub(paste0("-", lang_code, "[.]po$"), "-en.txt", files.po))
  )
  extrae_msgid_de_po(files.po, files.txt)

  ## ---- paso (4) subir estos txt al repo ----
  # Hacer un commit en este punto o subir a github.
  # para que google pueda traducirlo (método gratuito:;)
  msg <- R"--{
  A continuación sube los archivos en  "./vignettes/es/google-translations/*-en.txt"
  al repo (https://github.com/cienciadedatos/traduccion-vignettes-datatable)
  Puede hacerse online o manualmente via GIT (por ejemplo):

  > git add ":(glob)./vignettes/es/google-translations/*-en.txt"
  > git commit -m "mensajes-english-20260801"
  > git push

  }--"

  branch_name <- "main"

  # writeLines(sprintf("[%s](%s)", files, google_urls), "../google_translate_urls.md")

  ## ---- paso (5) scraping de traducciones ----
  # Todo esto se evitaría con una buena api de traducción gratuita.
  # pero NO EXISTE!
  cat("Scraping de traducciones con Google:")
  files.txt.es <- sub("-en[.]txt$", paste0("-", lang_code, ".txt"), files.txt)

  local({
    funs <- list(
      chromote = extraer_traducciones_con_chromote,
      selenium = extraer_traducciones_con_selenium
    )
    for (i in seq_along(funs)) {
      cat("probando con", names(funs)[i], "\n")
      fun <- funs[[i]]
      tryCatch(
        error = \(e) {
          print(e)
        },
        return(fun(
          files = files.txt, files_es = files.txt.es,
          wait = 5, lang_code = lang_code, branch_name = branch_name
        ))
      )
    }
    stop("Fallaron todos los intentos.")
  })
  # verificar que hayan sido creados los txt traducidos
  stopifnot(all(file.exists(files.txt.es)))


  # TODO: No es necesario actualizar los -es.txt en el repo aunque
  # pueden quedar como backup


  ## ---- paso (6) combinar traducción en el PO ----
  cat("combinar traducciones en PO...\n")
  cat("Las traducciones existentes no se modifican\n")
  {
    # función hace el trabajo de msgcat, etc.
    # analizar si potools tiene algo similar...

    for (i in seq_along(files.txt.es)) {
      combinar_plain_txt_en_po(files.txt.es[i], files.po[i], overwrite = FALSE)
    }
    # TODO: después de este paso es posible correr "update_PO()" ya que rmd2po
    # altera un poco la disposición de las traducciones (no se borra nada).

    # Actualiza metadata ej: name = "Ricardo Villalba", mail = "rikivillalba@gmail.com"
  }

  ## ---- paso (7) generar .Rmd traducidos ----
  cat("Generar .Rmd traducidos...")
  for (f in rmd_files) {
    po2rmd(f, lang = lang_code, verbose = TRUE)
  }

  ## ---- here ----
  ## ---- paso (8) cambiar rutas en código R de subcarpeta del idioma ----
  cat("Pendiente: corregir rutas en código R de subcarpeta del idioma...")

  cat("Traducir títulos de Rmd")
  # TODO: este paso está HARCODEADO. rmd2po no tiene en cuenta los títulos
  # habríoa que generar un PO con los títulos y usar ese.
  traducir_titulos_rmd()

  ## ---- paso (10) subir a repo. ----
  msg <- R"--{
  Por último:
  - verifique las traducciones.
  - actualice las rutas en el código para que apunten al directorio raíz:
    p.ej  "flights14.csv"  debería ser "../flights14.csv", ya que el .Rmd
    del idioma se encuentra dentro de un subdirectorio.
  - actualizar el remo.

  > git add "."
  > git commit -m "rmd actualizados"
  > git push

  }--"

  branch_name <- "main"
}

library(reticulate)

local({
  #  rlang::global_entrace()
  cat("Script para tradución automática de viñetas .Rmd\n")
  cat("Utiliza partes del proyecto rmdpo - https://github.com/SciViews/rmdpo\n")
  cat("*** Ejecute `start_translation()` para iniciar traducción automática\n")
  cat("*** Ejecute `update_PO()` para solamente actualizar el catálogo .PO con los cambios en los .Rmd en inglés más recientes\n")
  cat("*** Ejecute `q()` para salir de R\n")
})
