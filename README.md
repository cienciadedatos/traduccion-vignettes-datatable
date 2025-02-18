## Traducción de viñetas de data.table

El repo incluye:
* Copia de las viñetas originales de data.table *actualizadas al 2025-02-18*
* Viñetas traducidas al español con *google translator*
  * Se hizo una revisión manual de todas las viñetas y las pasé a conjugación 2da pers. (tú) cuando estaban en 3ra (Usted) (#2)
* Colección de scripts para generar traducciones "iniciales" automáticamente. Utiliza parte del proyecto rmd2po
  * para ejecutar, navegar hasta el directorio del repo (con setwd o desde rstudio) y cargar el código (`source("rutinas.R")`) y luego ejecutar `start_translation()`.
  * El script trabaja con rmd2po que a su vez instala y usa md2po para lo que requiere python. Los resultados se cargan como un commit en el repo (opcional)
  * script en estado alpha o beta
 
