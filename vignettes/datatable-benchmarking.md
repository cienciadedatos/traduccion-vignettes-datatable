---
title: "Benchmarking data.table"
date: "2024-10-04"
output:
  markdown::html_format:
    options:
      toc: true
      number_sections: true
    meta:
      css: [default, css/toc.css]
vignette: >
  %\VignetteIndexEntry{Benchmarking data.table}
  %\VignetteEngine{knitr::knitr}
  \usepackage[utf8]{inputenc}
---

<style>
h2 {
    font-size: 20px;
}
</style>

Este documento tiene como objetivo orientar sobre cómo medir el rendimiento de `data.table`. Un único lugar para documentar las mejores prácticas y las trampas que se deben evitar.

# fread: borrar cachés

Lo ideal sería que cada llamada `fread` se ejecute en una sesión nueva con los siguientes comandos antes de la ejecución de R. Esto borra el archivo de caché del sistema operativo en la RAM y la caché del disco duro.

```sh
free -g
sudo sh -c 'echo 3 >/proc/sys/vm/drop_caches'
sudo lshw -class disk
sudo hdparm -t /dev/sda
```

Al comparar `fread` con soluciones que no sean de R, tenga en cuenta que R requiere que los valores de las columnas de caracteres se agreguen a la _caché de cadenas global de R_. Esto lleva tiempo al leer datos, pero las operaciones posteriores se benefician porque las cadenas de caracteres ya se han almacenado en caché. En consecuencia, además de cronometrar tareas aisladas (como `fread` solo), es una buena idea comparar el tiempo total de una secuencia de tareas de extremo a extremo, como leer datos, manipularlos y producir el resultado final.

# subconjunto: umbral para la optimización del índice en consultas compuestas

La optimización de índice para consultas de filtros compuestos no se utilizará cuando el producto cruzado de los elementos proporcionados para filtrar exceda 1e4 elementos.

```r
DT = data.table(V1=1:10, V2=1:10, V3=1:10, V4=1:10)
setindex(DT)
v = c(1L, rep(11L, 9))
length(v)^4               # cross product of elements in filter
#[1] 10000                # <= 10000
DT[V1 %in% v & V2 %in% v & V3 %in% v & V4 %in% v, verbose=TRUE]
#Optimized subsetting with index 'V1__V2__V3__V4'
#on= matches existing index, using index
#Starting bmerge ...done in 0.000sec
#...
v = c(1L, rep(11L, 10))
length(v)^4               # cross product of elements in filter
#[1] 14641                # > 10000
DT[V1 %in% v & V2 %in% v & V3 %in% v & V4 %in% v, verbose=TRUE]
#Subsetting optimization disabled because the cross-product of RHS values exceeds 1e4, causing memory problems.
#...
```

# subconjunto: evaluación comparativa basada en índices

Para mayor comodidad, `data.table` crea automáticamente un índice en los campos que utiliza para crear subconjuntos de datos. Esto agregará algo de sobrecarga al primer subconjunto en campos específicos, pero reduce en gran medida el tiempo para consultar esas columnas en ejecuciones posteriores. Al medir la velocidad, la mejor manera es medir la creación de índices y la consulta utilizando un índice por separado. Con estos tiempos, es fácil decidir cuál es la estrategia óptima para su caso de uso. Para controlar el uso del índice, utilice las siguientes opciones:

```r
options(datatable.auto.index=TRUE)
options(datatable.use.index=TRUE)
```

- `use.index=FALSE` forzará la consulta a no usar índices incluso si existen, pero las claves existentes aún se usan para la optimización.
- `auto.index=FALSE` deshabilita la creación automática de índices al hacer un subconjunto en datos no indexados, pero si los índices se crearon antes de que se estableciera esta opción, o explícitamente al llamar a `setindex`, aún se usarán para la optimización.

Otras dos opciones controlan la optimización globalmente, incluido el uso de índices:
```r
options(datatable.optimize=2L)
options(datatable.optimize=3L)
```
`options(datatable.optimize=2L)` desactivará por completo la optimización de subconjuntos, mientras que `options(datatable.optimize=3L)` la volverá a activar. Esas opciones afectan a muchas más optimizaciones y, por lo tanto, no se deben utilizar cuando solo se necesita el control de índices. Lea más en `?datatable.optimize`.

# Operaciones _por referencia_

Al evaluar las funciones `set*`, solo tiene sentido medir la primera ejecución. Estas funciones actualizan su entrada por referencia, por lo que las ejecuciones posteriores utilizarán la `data.table` ya procesada, lo que sesgará los resultados.

Para proteger su tabla `data.table` de ser actualizada por operaciones de referencia, puede usar las funciones `copy` o `data.table:::shallow`. Tenga en cuenta que `copy` puede ser muy costoso, ya que necesita duplicar el objeto completo. Es poco probable que queramos incluir el tiempo de duplicación en el tiempo de la tarea real que estamos evaluando.

# Intentar comparar los procesos atómicos

Si su evaluación comparativa está destinada a ser publicada, será mucho más esclarecedora si la divide para medir el tiempo de los procesos atómicos. De esta manera, sus lectores pueden ver cuánto tiempo se dedicó a leer los datos de la fuente, limpiarlos, transformarlos realmente y exportar los resultados. Por supuesto, si su evaluación comparativa está destinada a presentar un _flujo de trabajo de principio a fin_, entonces tiene todo el sentido presentar el tiempo general. Sin embargo, separar el tiempo de los pasos individuales es útil para comprender qué pasos son los principales cuellos de botella de un flujo de trabajo. Hay otros casos en los que la evaluación comparativa atómica puede no ser deseable, por ejemplo, cuando se _lee un csv_, seguido de _agrupamiento_. R requiere llenar _la caché de cadenas global de R_, lo que agrega una sobrecarga adicional al importar datos de caracteres a una sesión de R. Por otro lado, la _caché de cadenas global_ puede acelerar procesos como _agrupamiento_. En tales casos, al comparar R con otros lenguajes, puede ser útil incluir el tiempo total.

# evitar la coerción de clase

A menos que esto sea lo que realmente desea medir, debe preparar objetos de entrada de la clase esperada para cada herramienta que esté evaluando.

# evitar `microbenchmark(..., veces=100)`

Repetir un punto de referencia muchas veces no suele ofrecer la imagen más clara para las herramientas de procesamiento de datos. Por supuesto, tiene todo el sentido para cálculos más atómicos, pero no es una buena representación de la forma más común en que se utilizarán realmente estas herramientas, es decir, para tareas de procesamiento de datos, que consisten en lotes de transformaciones proporcionadas secuencialmente, cada una de las cuales se ejecuta una vez. Matt dijo una vez:

> Soy muy cauteloso con los puntos de referencia medidos en cualquier valor inferior a 1 segundo. Prefiero mucho más de 10 segundos para una sola ejecución, lograda aumentando el tamaño de los datos. Un recuento de repeticiones de 500 hace sonar las alarmas. 3-5 ejecuciones deberían ser suficientes para convencer con datos más grandes. La sobrecarga de llamadas y el tiempo de recolección de basura afectan las inferencias a esta escala tan pequeña.

Esto es muy válido. Cuanto menor sea la medición de tiempo, mayor será el ruido relativo. Ruido generado por el envío de métodos, la inicialización de paquetes o clases, etc. El enfoque principal del análisis comparativo debería estar en escenarios de casos de uso reales.

# procesamiento multiproceso

Uno de los principales factores que probablemente afecten los tiempos es la cantidad de subprocesos disponibles para su sesión R. En versiones recientes de `data.table`, algunas funciones están paralelizadas. Puede controlar la cantidad de subprocesos que desea utilizar con `setDTthreads`.

```r
setDTthreads(0)    # use all available cores (default)
getDTthreads()     # check how many cores are currently used
```

# Dentro de un bucle se prefiere `set` en lugar de `:=`

A menos que esté utilizando el índice al realizar una _subasignación por referencia_, debería preferir la función `set`, que no impone la sobrecarga de la llamada al método `[.data.table`.

```r
DT = data.table(a=3:1, b=letters[1:3])
setindex(DT, a)

# for (...) {                 # imagine loop here

  DT[a==2L, b := "z"]         # sub-assign by reference, uses index
  DT[, d := "z"]              # not sub-assign by reference, not uses index and adds overhead of `[.data.table`
  set(DT, j="d", value="z")   # no `[.data.table` overhead, but no index yet, till #1196

# }
```

# Dentro de un bucle, prefiera `setDT` en lugar de `data.table()`

A partir de ahora, `data.table()` tiene una sobrecarga, por lo tanto, dentro de los bucles se prefiere utilizar `as.data.table()` o `setDT()` en una lista válida.

