## Traducción de viñetas de data.table

El repo incluye:
* Copia de las viñetas originales de data.table *actualizadas al 2025-02-18*
* Viñetas traducidas al español con *google translator* y revisadas en general (por ej. usando «tú» en vez de «usted» (#2) y la traducción de algunos términos
* Colección de scripts para generar traducciones "iniciales" automáticamente. Utiliza parte del proyecto [rmd2po](https://github.com/SciViews/rmdpo)
  * para ejecutar, navegar hasta el directorio del repo (con setwd o desde rstudio) y cargar el código (`source("rutinas.R")`) y luego ejecutar `start_translation()`.
  * El script trabaja con rmd2po que a su vez instala y usa md2po para lo que requiere python. Los resultados se pueden cargar como un push en este repo (opcional) usando [gert](https://github.com/r-lib/gert)
  * script en estado alpha o beta
* para generar los html a partir de los Rmd: `lapply(dir(,"Rmd$"),\(i) knitr::knit2html(i))`
---
### >> Los archivos para traducir (que hay que revisar) están en [vignettes/es](https://github.com/cienciadedatos/traduccion-vignettes-datatable/tree/main/vignettes/es) se pueden editar ahí mismo.<<
---
En este [issue](https://github.com/cienciadedatos/traduccion-vignettes-datatable/issues/1) hacemos el seguimiento del estado de traducción.
