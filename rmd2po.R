# https://github.com/SciViews/rmdpo

# Create .po files from R Markdown or Quarto documents an build translated
# versions of these documents. Internally uses Python's mdpo.
#
# Note: there is also po4a that does the job. It is a Perl program that works
# on Linux and macOS (installation through Homebrew or Macports), but I have
# found nothing for Windows. Here is what I did with it on macOS:
#
# Create, or update a .pot file for one R Markdown document
#po4a-updatepo -f text -m <doc>.Rmd -p fr/po/<doc>.pot -p fr/po/<doc>-fr.po -M utf8 -o markdown -o neverwrap -o nobullets --wrap-po newlines --msgid-bugs-address <mail>@sciviews.org --copyright-holder "SciViews" --package-name "<doc>" --package-version "1.0.0"
#
# Translate an R Markdown document using an -fr.po file (with a minimal threshold of translated text set to 80%)
#po4a-translate -f text -m <doc>.Rmd -p fr/po/<doc>-fr.po -M utf8 -l fr/<doc>.Rmd -L utf8 -o markdown -o neverwrap -o nobullets --wrap-po newlines --keep 80
#
# Use a reworked (and correctly aligned!) translated .Rmd file to update the -fr.po file
#po4a-gettextize -f text -m <doc>.Rmd -l fr/<doc>.Rmd -p fr/po/<doc>.pot -p fr/po/<doc>-fr.po -M utf8 -L utf8 -o markdown -o neverwrap -o nobullets --msgid-bugs-address <mail>@sciviews.org --copyright-holder "SciViews" --package-name "<doc>" --package-version "1.0.0"

# This is a version using the mdpo Python library

.check_mdpo <- function(pgm = "md2po", min.version = "2.0.0",
  mdpodir = getOption("mdpodir")) {

  if (!is.null(mdpodir) && nchar(mdpodir))
    pgm <- file.path(path.expand(mdpodir), pgm)

  pgm_version <- tryCatch(system2(pgm, args = "--version",
    stdout = TRUE, stderr = TRUE), error = function(e) 
      stopf("%s not found. Install mdpo Python library and make it available.", 
            pgm, call = NULL))
  # Returned string is like "md2po 2.0.0", but we need "2.0.0" only
  pgm_version <- sub("^[^ ]+ +", "", pgm_version)
  if (package_version(pgm_version) < min.version)
    stopf( "%s version %s or higher is required, but %s is found.",
      pgm, min.version, pgm_version)
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
  rmddata <- sub("^( *)```\\{([a-zA-Z]+[ ,][^}]+)\\}$",
    "\\1```{chunk_with_args}\n\\1#===== \\2", rmddata)
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
  endflag <- (1:length(data))[grep("=====END=====", data)]
  if (!length(endflag))
    return(data) # Nothing to do, no end flag found
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
  # TODO... how ??? This is wrong: rmddata <- sub("^([^=].*) (=====.*=====)$", "\\1\n\\2", rmddata)
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

  # This is not needed any more with the wrapping of list items within =====
  # Kept here commented for reference
  ## Indent code correctly in indented code chunks
  ## po2md indents tags and sometimes first line, but not the remaining lines
  ## This produces incorrect results => indent all lines now inside the chunk
  #inchunks <- grepl("^ +```", rmddata)
  #if (any(inchunks)) {
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
  #}
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
# @@ eliminado: 
# @param keep.tmpfile If `TRUE`, keep the modified .tmp file that is created
# from the original .Rmd/.qmd to allow better handling of YAML header and R
# chunks. `FALSE` by default, change it only for debugging purposes
rmd2po <- function(rmdfile, lang = "fr", podir = "po",
  mdpodir = getOption("mdpodir"), min.version = "2.0.0",
  verbose = FALSE, cmd_options = character(0)) {

  # Check external program availability and version
  md2po <- .check_mdpo("md2po", min.version = min.version, mdpodir = mdpodir)

  if (!file.exists(rmdfile))
    stopf("The file '%s' is not found.", rmdfile)
  
  # los encabezados PO.
  metadata <- paste(
    "Project-Id-Version: 0.0.1",
    "Report-Msgid-Bugs-To: ",
    #    "POT-Creation-Date: 2024-10-04 11:40-0300",
    #    "PO-Revision-Date: 2025-02-06 15:35-0300",
    #    "Last-Translator: Nombre Apellido <direccion@ejemplo.com>",
    "Language-Team: es",
    "Language: es",
    "MIME-Version: 1.0",
    "Content-Type: text/plain; charset=UTF-8",
    "Content-Transfer-Encoding: 8bit",
    #    "X-Generator: Translate Toolkit 3.13.3",
    sep = "; ")

  rmddir <- dirname(rmdfile)
  rmdfilename <- basename(rmdfile)
  odir <- setwd(rmddir)     # see NOTE above
  tmpfile <- file.path(lang, paste0(basename(rmdfile), ".tmp"))
  
  tryCatch(
    finally = {
      setwd(odir) 
      unlink(tmpfile)
    },  { 
      if (isTRUE(verbose)) 
        messagef("Procesando %s", rmdfilename)
      
      # Make sure required subdirectories exist
      dir.create(lang, showWarnings = FALSE)
      dir.create(file.path(lang, podir), showWarnings = FALSE)
    
      # Create temporary file with modified Rmd/qmd file so that it is correctly
      # processed with md2po
      .create_temp_rmd(rmdfile, tmpfile)
    
      # Create the .po file, using md2po on the temporary rmd file
      pofile <- file.path(lang, podir, paste0(rmdfilename, "-", lang, ".po"))
    
      if (length(cmd_options)) 
        messagef("Opciones extra: %s", paste(cmd_options, collapse = " "))
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
        { exit_code <- system2(
            command = md2po, 
            args = c(
              "--quiet", "--save", "--merge-pofiles", "--remove-not-found", 
              "--metadata", shQuote(sprintf("Language: %s", lang)),
              "--metadata", shQuote(metadata),
              "--po-filepath", shQuote(pofile), 
              cmd_options),        
            stdin = tmpfile,
            stdout = cmd_output_tmp, 
            stderr = cmd_output_tmp)
          cmd_output <- readLines(cmd_output_tmp)
          if (exit_code) 
            messagef("Aviso: md2po terminó con estado de salida no cero: %d", exit_code)
        }
      )
    }
  )
  
  if (isTRUE(verbose) && any(nzchar(cmd_output))) {
    if(any(grepl("OSError:", cmd_output))) {
      cmd_output <- sub(".*OSError:", "OSError:", cmd_output)
      messagef("%s", cmd_output)
    } else messagef("salida de md2po: %s", cmd_output)
  }

  # Cut any unnecessary parts in the .po file
  writeLines(.cut_after_end(readLines(pofile)), pofile)

  file.path(rmddir, pofile)
}

# NOTE: po2md does not process quoted paths correctly. It is thus better to
# temporarily switch to the directory where the rdmfile is located and to
# always escape spaces with backslashes if they exist in the vignette name
# It also waits for the name of the md file to process on stdin, even if it
# is provided as first argument (both using system() and system2()). So, we
# provide it through input = 
po2rmd <- function(rmdfile, lang = "fr", podir = "po",
  mdpodir = getOption("mdpodir"), min.version = "2.0.0",
  verbose = FALSE) {

  po2md <- .check_mdpo("po2md", min.version = min.version, mdpodir = mdpodir)

  if (!file.exists(rmdfile))
    stopf("The file '%s' is not found.", rmdfile)
  else if (!dir.exists(rmddir <- dirname(rmdfile)))
    stopf("The directory '%s' is not found.", rmddir)

  rmdfilename <- basename(rmdfile)
  
  odir <- setwd(rmddir)  # read NOTE above.
  if (normalizePath(getwd()) != normalizePath(odir) && verbose) 
    messagef("cambiando temporalmente a %s", rmddir)
  tmpfile <- file.path(lang, paste0(basename(rmdfile), ".tmp"))
  tryCatch(
    finally = {
      unlink(tmpfile)
      setwd(odir) }, 
    { 
      if (isTRUE(verbose))
        messagef("Procesando %s", rmdfilename)

      # Make sure required subdirectories exist
      # Create temporary file, if needed, with modified Rmd/qmd file so that it is
      # correctly processed with po2md
      dir.create(lang, showWarnings = FALSE)
      .create_temp_rmd(rmdfile, tmpfile)
    
      # Create translated .Rmd/.qmd file using the temporary .Rmd/.qmd and .po file
      rmd2file <- file.path(lang, rmdfilename)
      pofile <- file.path(lang, podir, paste0(rmdfilename, "-", lang, ".po"))
      if (!file.exists(pofile))
        stopf("The .po file '%s' is not found.", pofile)
 
      cmd_output_tmp <- tempfile()
      # la entrada se puede especificar como nombre de archivo o como stdin.
      # pero leer NOTA ut supra
      tryCatch(
        finally = unlink(cmd_output_tmp),
        { exit_code <- system2(
            command = po2md, 
            args = c(
              "--po-files", shQuote(pofile),
              "--save", shQuote(rmd2file), 
              "--wrapwidth", "0",  # Necesario para que .postprocess.. funcione
              "--quiet"  
              # c("--no-obsolete", "--no-fuzzy", "--no-empty-msgstr"),    # desactivado por ahora
              ),    
            stdin = tmpfile,
            stdout = cmd_output_tmp, 
            stderr = cmd_output_tmp
          )
          cmd_output <- readLines(cmd_output_tmp)
        } 
      )
      if (exit_code) 
        messagef("Aviso: md2po terminó con estado de salida no cero: %d", exit_code)

      # Rework the translated .Rmd/.qmd file to restore YAML header, R chunks and
      # list items
      .postprocess_translated_rmd(rmd2file)
      
      file.path(rmddir, rmd2file)
    }
  )
}
