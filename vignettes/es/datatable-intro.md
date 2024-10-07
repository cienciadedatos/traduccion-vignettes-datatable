---
title: "Introduction to data.table"
date: "2024-10-07"
output:
  markdown::html_format
vignette: >
  %\VignetteIndexEntry{Introduction to data.table}
  %\VignetteEngine{knitr::knitr}
  \usepackage[utf8]{inputenc}
---



Esta viñeta presenta la sintaxis de `data.table`, su forma general, cómo crear *subconjuntos* de filas, *seleccionar y calcular* columnas y realizar agregaciones *por grupo*. Es útil estar familiarizado con la estructura de datos `data.frame` de R básico, pero no es esencial para seguir esta viñeta.

***

## Análisis de datos utilizando `data.table`

Las operaciones de manipulación de datos como *subconjunto*, *grupo*, *actualización*, *unión*, etc. están todas relacionadas de manera inherente. Mantener juntas estas *operaciones relacionadas* permite:

* Sintaxis *concisa* y *consistente* independientemente del conjunto de operaciones que desee realizar para lograr su objetivo final.

* realizar análisis *de manera fluida* sin la carga cognitiva de tener que asignar cada operación a una función particular de un conjunto potencialmente enorme de funciones disponibles antes de realizar el análisis.

* optimizar *automáticamente* las operaciones internamente y de manera muy efectiva al conocer con precisión los datos necesarios para cada operación, lo que genera un código muy rápido y con uso eficiente de la memoria.

En resumen, si está interesado en reducir enormemente el tiempo de *programación* y *computación*, este paquete es para usted. La filosofía a la que se adhiere `data.table` lo hace posible. Nuestro objetivo es ilustrarlo a través de esta serie de viñetas.

## Datos {#data}

En esta viñeta, utilizaremos los datos de [NYC-flights14](https://raw.githubusercontent.com/Rdatatable/data.table/master/vignettes/flights14.csv) obtenidos del paquete [flights](https://github.com/arunsrinivasan/flights) (disponible solo en GitHub). Contiene datos de vuelos puntuales de la Oficina de Estadísticas de Transporte para todos los vuelos que partieron de los aeropuertos de la ciudad de Nueva York en 2014 (inspirados en [nycflights13](https://github.com/tidyverse/nycflights13)). Los datos están disponibles solo para enero-octubre de 2014.

Podemos usar el lector de archivos rápido y amigable `fread` de `data.table` para cargar `flights` directamente de la siguiente manera:




``` r
input <- if (file.exists("flights14.csv")) {
   "flights14.csv"
} else {
  "https://raw.githubusercontent.com/Rdatatable/data.table/master/vignettes/flights14.csv"
}
flights <- fread(input)
flights
#          year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#         <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
#      1:  2014     1     1        14        13      AA    JFK    LAX      359     2475     9
#      2:  2014     1     1        -3        13      AA    JFK    LAX      363     2475    11
#      3:  2014     1     1         2         9      AA    JFK    LAX      351     2475    19
#      4:  2014     1     1        -8       -26      AA    LGA    PBI      157     1035     7
#      5:  2014     1     1         2         1      AA    JFK    LAX      350     2475    13
#     ---                                                                                    
# 253312:  2014    10    31         1       -30      UA    LGA    IAH      201     1416    14
# 253313:  2014    10    31        -5       -14      UA    EWR    IAH      189     1400     8
# 253314:  2014    10    31        -8        16      MQ    LGA    RDU       83      431    11
# 253315:  2014    10    31        -4        15      MQ    LGA    DTW       75      502    11
# 253316:  2014    10    31        -5         1      MQ    LGA    SDF      110      659     8
dim(flights)
# [1] 253316     11
```

Nota: `fread` acepta URL `http` y `https` directamente, así como comandos del sistema operativo como `sed` y `awk`. Consulta `?fread` para ver ejemplos.

## Introducción

En esta viñeta, vamos a

1. Comience con lo básico: qué es una `data.table`, su forma general, cómo crear *subconjuntos* de filas, cómo *seleccionar y calcular* columnas;

2. Luego veremos cómo realizar agregaciones de datos por grupo

## 1. Conceptos básicos {#basics-1}

### a) ¿Qué es `data.table`? {#what-is-datatable-1a}

`data.table` es un paquete R que proporciona **una versión mejorada** de un `data.frame`, la estructura de datos estándar para almacenar datos en `base` R. En la sección [Data](#data) anterior, vimos cómo crear un `data.table` usando `fread()`, pero también podemos crear uno usando la función `data.table()`. Aquí hay un ejemplo:


``` r
DT = data.table(
  ID = c("b","b","b","a","a","c"),
  a = 1:6,
  b = 7:12,
  c = 13:18
)
DT
#        ID     a     b     c
#    <char> <int> <int> <int>
# 1:      b     1     7    13
# 2:      b     2     8    14
# 3:      b     3     9    15
# 4:      a     4    10    16
# 5:      a     5    11    17
# 6:      c     6    12    18
class(DT$ID)
# [1] "character"
```

También puede convertir objetos existentes en una tabla `data.table` utilizando `setDT()` (para estructuras `data.frame` y `list`) o `as.data.table()` (para otras estructuras). Para obtener más detalles sobre la diferencia (que va más allá del alcance de esta viñeta), consulte `?setDT` y `?as.data.table`.

#### Tenga en cuenta que:

* Los números de fila se imprimen con un `:` para separar visualmente el número de fila de la primera columna.

* Cuando el número de filas a imprimir excede la opción global `datatable.print.nrows` (predeterminado = 100), imprime automáticamente solo las primeras 5 y las últimas 5 filas (como se puede ver en la sección [Data](#data)). Para un `data.frame` grande, es posible que se haya encontrado esperando mientras se imprimen y paginan tablas más grandes, a veces aparentemente sin fin. Esta restricción ayuda con eso, y puede consultar el número predeterminado de la siguiente manera:

    ```{.r}
    getOption("datatable.print.nrows")
    ```

* `data.table` nunca establece ni utiliza *nombres de fila*. Veremos por qué en la viñeta *"Subconjunto basado en claves y búsqueda binaria rápida"*.

### b) Forma general: ¿de qué manera se *mejora* una tabla `data.table`? {#enhanced-1b}

A diferencia de un `data.frame`, puedes hacer *mucho más* que simplemente crear subconjuntos de filas y seleccionar columnas dentro del marco de un `data.table`, es decir, dentro de `[...]` (NB: también podríamos referirnos a escribir cosas dentro de `DT[...]` como "consultar `DT`", como una analogía o en relación con SQL). Para entenderlo, primero tendremos que mirar la *forma general* de la sintaxis de `data.table`, como se muestra a continuación:


``` r
DT[i, j, by]

##   R:                 i                 j        by
## SQL:  where | order by   select | update  group by
```

Los usuarios con conocimientos de SQL quizás se sientan inmediatamente identificados con esta sintaxis.

#### La forma de leerlo (en voz alta) es:

Tome `DT`, subconjunto/reordene filas usando `i`, luego calcule `j`, agrupado por `by`.

Comencemos mirando primero `i` y `j`: subconjuntando filas y operando en columnas.

### c) Subconjunto de filas en `i` {#subset-i-1c}

#### -- Obtenga todos los vuelos con "JFK" como aeropuerto de origen en el mes de junio.


``` r
ans <- flights[origin == "JFK" & month == 6L]
head(ans)
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
# 1:  2014     6     1        -9        -5      AA    JFK    LAX      324     2475     8
# 2:  2014     6     1       -10       -13      AA    JFK    LAX      329     2475    12
# 3:  2014     6     1        18        -1      AA    JFK    LAX      326     2475     7
# 4:  2014     6     1        -6       -16      AA    JFK    LAX      320     2475    10
# 5:  2014     6     1        -4       -45      AA    JFK    LAX      326     2475    18
# 6:  2014     6     1        -6       -23      AA    JFK    LAX      329     2475    14
```

* Dentro del marco de una `data.table`, se puede hacer referencia a las columnas *como si fueran variables*, de forma muy similar a SQL o Stata. Por lo tanto, simplemente nos referimos a `origin` y `month` como si fueran variables. No necesitamos agregar el prefijo `flights$` cada vez. Sin embargo, usar `flights$origin` y `flights$month` funcionaría perfectamente.

* Se calculan los *índices de fila* que satisfacen la condición `origin == "JFK" & month == 6L` y, dado que no hay nada más que hacer, todas las columnas de `flights` en las filas correspondientes a esos *índices de fila* simplemente se devuelven como una `data.table`.

* No es necesario incluir una coma después de la condición en `i`. Pero `flights[origin == "JFK" & month == 6L, ]` funcionaría perfectamente. Sin embargo, en un `data.frame`, la coma es necesaria.

#### -- Obtener las dos primeras filas de `vuelos`. {#subset-rows-integer}


``` r
ans <- flights[1:2]
ans
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
# 1:  2014     1     1        14        13      AA    JFK    LAX      359     2475     9
# 2:  2014     1     1        -3        13      AA    JFK    LAX      363     2475    11
```

* En este caso, no hay ninguna condición. Los índices de fila ya se proporcionan en `i`. Por lo tanto, devolvemos una `data.table` con todas las columnas de `flights` en las filas para esos *índices de fila*.

#### -- Ordena `vuelos` primero por la columna `origen` en orden *ascendente*, y luego por `destino` en orden *descendente*:

Podemos utilizar la función R `order()` para lograr esto.


``` r
ans <- flights[order(origin, -dest)]
head(ans)
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
# 1:  2014     1     5         6        49      EV    EWR    XNA      195     1131     8
# 2:  2014     1     6         7        13      EV    EWR    XNA      190     1131     8
# 3:  2014     1     7        -6       -13      EV    EWR    XNA      179     1131     8
# 4:  2014     1     8        -7       -12      EV    EWR    XNA      184     1131     8
# 5:  2014     1     9        16         7      EV    EWR    XNA      181     1131     8
# 6:  2014     1    13        66        66      EV    EWR    XNA      188     1131     9
```

#### `order()` está optimizado internamente

* Podemos usar "-" en columnas de `caracteres` dentro del marco de una `tabla de datos` para ordenar en orden decreciente.

* Además, `order(...)` dentro del marco de una `data.table` utiliza el ordenamiento rápido interno de `data.table` `forder()`. Esta clasificación proporcionó una mejora tan convincente con respecto a `base::order` de R que el proyecto R adoptó el algoritmo `data.table` como su clasificación predeterminada en 2016 para R 3.3.0 (para referencia, consulte `?sort` y [R Release NEWS](https://cran.r-project.org/doc/manuals/r-release/NEWS.pdf)).

Discutiremos el orden rápido de `data.table` con más detalle en la viñeta *Aspectos internos de `data.table`*.

### d) Seleccione la(s) columna(s) en `j` {#select-j-1d}

#### -- Selecciona la columna `arr_delay`, pero devuélvela como un *vector*.


``` r
ans <- flights[, arr_delay]
head(ans)
# [1]  13  13   9 -26   1   0
```

* Dado que se puede hacer referencia a las columnas como si fueran variables dentro del marco de una `data.table`, hacemos referencia directamente a la *variable* que queremos subconjunto. Como queremos *todas las filas*, simplemente omitimos `i`.

* Devuelve *todas* las filas de la columna `arr_delay`.

#### -- Seleccione la columna `arr_delay`, pero devuélvala como `data.table` en su lugar.


``` r
ans <- flights[, list(arr_delay)]
head(ans)
#    arr_delay
#        <int>
# 1:        13
# 2:        13
# 3:         9
# 4:       -26
# 5:         1
# 6:         0
```

* Envolvemos las *variables* (nombres de columnas) dentro de `list()`, lo que garantiza que se devuelva una `data.table`. En el caso de un solo nombre de columna, no envolver con `list()` devuelve un vector en su lugar, como se ve en el [ejemplo anterior](#select-j-1d).

* `data.table` también permite encapsular columnas con `.()` en lugar de `list()`. Es un *alias* de `list()`; ambos significan lo mismo. Siéntete libre de usar el que prefieras; hemos notado que la mayoría de los usuarios parecen preferir `.()` por concisión, por lo que continuaremos usando `.()` de aquí en adelante.

Una tabla `data.table` (y también un `data.frame`) es internamente una `lista` también, con la condición de que cada elemento tenga la misma longitud y la `lista` tenga un atributo `class`. Permitir que `j` devuelva una `lista` permite convertir y devolver `data.table` de manera muy eficiente.

#### Consejo: {#tip-1}

Mientras `j-expression` devuelva una `lista`, cada elemento de la lista se convertirá en una columna en la `data.table` resultante. Esto hace que `j` sea bastante potente, como veremos en breve. ¡También es muy importante comprender esto para cuando desee realizar consultas más complicadas!

#### -- Seleccione las columnas `arr_delay` y `dep_delay`.


``` r
ans <- flights[, .(arr_delay, dep_delay)]
head(ans)
#    arr_delay dep_delay
#        <int>     <int>
# 1:        13        14
# 2:        13        -3
# 3:         9         2
# 4:       -26        -8
# 5:         1         2
# 6:         0         4

## alternatively
# ans <- flights[, list(arr_delay, dep_delay)]
```

* Envuelve ambas columnas dentro de `.()` o `list()`. Eso es todo.

#### -- Seleccione las columnas `arr_delay` y `dep_delay` *y* cámbieles el nombre a `delay_arr` y `delay_dep`.

Dado que `.()` es solo un alias de `list()`, podemos nombrar las columnas como lo haríamos al crear una `lista`.


``` r
ans <- flights[, .(delay_arr = arr_delay, delay_dep = dep_delay)]
head(ans)
#    delay_arr delay_dep
#        <int>     <int>
# 1:        13        14
# 2:        13        -3
# 3:         9         2
# 4:       -26        -8
# 5:         1         2
# 6:         0         4
```

### e) Calcular o *hacer* en `j`

#### --¿Cuántos viajes han tenido un retraso total < 0?


``` r
ans <- flights[, sum( (arr_delay + dep_delay) < 0 )]
ans
# [1] 141814
```

#### ¿Que está pasando aquí?

* La función `j` de `data.table` puede manejar más que simplemente *seleccionar columnas* - puede manejar *expresiones*, es decir, *hacer cálculos sobre columnas*. Esto no debería sorprender, ya que se puede hacer referencia a las columnas como si fueran variables. Entonces deberíamos poder *hacer cálculos* llamando a funciones sobre esas variables. Y eso es precisamente lo que sucede aquí.

### f) Subconjunto en `i` *y* hacer en `j`

#### -- Calcular el retraso medio de llegada y salida para todos los vuelos con aeropuerto de origen "JFK" en el mes de junio.


``` r
ans <- flights[origin == "JFK" & month == 6L,
               .(m_arr = mean(arr_delay), m_dep = mean(dep_delay))]
ans
#       m_arr    m_dep
#       <num>    <num>
# 1: 5.839349 9.807884
```

* Primero creamos un subconjunto en `i` para encontrar los *índices de fila* coincidentes donde `origin` aeropuerto es igual a `"JFK"`, y `month` es igual a `6L`. *Todavía* no creamos un subconjunto de la `data.table` _completa_ correspondiente a esas filas.

* Ahora, observamos `j` y descubrimos que utiliza solo *dos columnas*. Y lo que tenemos que hacer es calcular su `media()`. Por lo tanto, creamos un subconjunto de las columnas que corresponden a las filas coincidentes y calculamos su `media()`.

Debido a que los tres componentes principales de la consulta (`i`, `j` y `by`) están *juntos* dentro de `[...]`, `data.table` puede ver los tres y optimizar la consulta en conjunto *antes de la evaluación*, en lugar de optimizar cada uno por separado. Por lo tanto, podemos evitar todo el subconjunto (es decir, crear subconjuntos de las columnas _además de_ `arr_delay` y `dep_delay`), tanto por velocidad como por eficiencia de memoria.

#### --¿Cuántos viajes se han realizado en el año 2014 desde el aeropuerto “JFK” en el mes de junio?


``` r
ans <- flights[origin == "JFK" & month == 6L, length(dest)]
ans
# [1] 8422
```

La función length() requiere un argumento de entrada. Solo necesitamos calcular la cantidad de filas en el subconjunto. Podríamos haber usado cualquier otra columna como argumento de entrada para length(). Este enfoque recuerda a SELECT COUNT(dest) FROM flights WHERE origin = 'JFK' AND month = 6 en SQL.

Este tipo de operación ocurre con bastante frecuencia, especialmente durante la agrupación (como veremos en la siguiente sección), hasta el punto donde `data.table` proporciona un *símbolo especial* `.N` para ello.

### g) Manejar elementos inexistentes en `i`

#### --¿Qué sucede cuando se consultan elementos no existentes?

Al consultar una `data.table` en busca de elementos que no existen, el comportamiento difiere según el método utilizado.

```r
setkeyv(flights, "origin")
```

* **Subconjunto basado en clave: `dt["d"]`**

Esto realiza una unión a la derecha en la columna de clave `x`, lo que da como resultado una fila con `d` y `NA` para las columnas que no se encuentran. Al utilizar `setkeyv`, la tabla se ordena por las claves especificadas y se crea un índice interno, lo que permite la búsqueda binaria para una subdivisión eficiente.

  ```r
  flights["XYZ"]
  # Returns:
  #    origin year month day dep_time sched_dep_time dep_delay arr_time sched_arr_time arr_delay carrier flight tailnum ...
  # 1:    XYZ   NA    NA  NA       NA             NA        NA       NA             NA        NA      NA     NA      NA ...
  ```

* **Subconjunto lógico: `dt[x == "d"]`**

Esto realiza una operación de subconjunto estándar que no encuentra ninguna fila coincidente y, por lo tanto, devuelve una `data.table` vacía.

  ```r
    flights[origin == "XYZ"]
  # Returns:
  # Empty data.table (0 rows and 19 cols): year,month,day,dep_time,sched_dep_time,dep_delay,arr_time,sched_arr_time,arr_delay,...
  ```

* **Coincidencia exacta usando `nomatch=NULL`**

Para coincidencias exactas sin `NA` para elementos inexistentes, utilice `nomatch=NULL`:

  ```r
  flights["XYZ", nomatch=NULL]
  # Returns:
  # Empty data.table (0 rows and 19 cols): year,month,day,dep_time,sched_dep_time,dep_delay,arr_time,sched_arr_time,arr_delay,...
  ```

Comprender estos comportamientos puede ayudar a evitar confusiones al tratar con elementos inexistentes en sus datos.

#### Símbolo especial `.N`: {#special-N}

`.N` es una variable incorporada especial que contiene la cantidad de observaciones _en el grupo actual_. Es particularmente útil cuando se combina con `by` como veremos en la siguiente sección. En ausencia de operaciones de agrupamiento por, simplemente devuelve la cantidad de filas en el subconjunto.

Ahora que lo sabemos, podemos realizar la misma tarea utilizando `.N` de la siguiente manera:


``` r
ans <- flights[origin == "JFK" & month == 6L, .N]
ans
# [1] 8422
```

* Una vez más, subconjunto en `i` para obtener los *índices de fila* donde el aeropuerto `origen` es igual a *"JFK"*, y el mes es igual a *6*.

* Vemos que `j` utiliza solo `.N` y ninguna otra columna. Por lo tanto, no se materializa el subconjunto completo. Simplemente devolvemos la cantidad de filas en el subconjunto (que es solo la longitud de los índices de fila).

* Tenga en cuenta que no hemos incluido `.N` en `list()` o `.()`. Por lo tanto, se devuelve un vector.

Podríamos haber realizado la misma operación haciendo `nrow(flights[origin == "JFK" & month == 6L])`. Sin embargo, tendríamos que crear primero un subconjunto de toda la `data.table` correspondiente a los *índices de fila* en `i` *y luego* devolver las filas usando `nrow()`, lo cual es innecesario e ineficiente. Trataremos este y otros aspectos de optimización en detalle en la viñeta de *diseño de `data.table`*.

### h) ¡Genial! Pero, ¿cómo puedo hacer referencia a las columnas por nombres en `j` (como en un `data.frame`)? {#refer_j}

Si escribe los nombres de las columnas explícitamente, no hay diferencia en comparación con un `data.frame` (desde v1.9.8).

#### -- Seleccione las columnas `arr_delay` y `dep_delay` mediante el método `data.frame`.


``` r
ans <- flights[, c("arr_delay", "dep_delay")]
head(ans)
#    arr_delay dep_delay
#        <int>     <int>
# 1:        13        14
# 2:        13        -3
# 3:         9         2
# 4:       -26        -8
# 5:         1         2
# 6:         0         4
```

Si ha almacenado las columnas deseadas en un vector de caracteres, hay dos opciones: utilizar el prefijo `..` o utilizar el argumento `with`.

#### -- Seleccionar columnas nombradas en una variable usando el prefijo `..`


``` r
select_cols = c("arr_delay", "dep_delay")
flights[ , ..select_cols]
#         arr_delay dep_delay
#             <int>     <int>
#      1:        13        14
#      2:        13        -3
#      3:         9         2
#      4:       -26        -8
#      5:         1         2
#     ---                    
# 253312:       -30         1
# 253313:       -14        -5
# 253314:        16        -8
# 253315:        15        -4
# 253316:         1        -5
```

Para aquellos familiarizados con la terminal Unix, el prefijo `..` debería recordar al comando "up-one-level", que es análogo a lo que sucede aquí: `..` indica a `data.table` que busque la variable `select_cols` "up-one-level", es decir, dentro del entorno global en este caso.

#### -- Seleccionar columnas nombradas en una variable usando `with = FALSE`


``` r
flights[ , select_cols, with = FALSE]
#         arr_delay dep_delay
#             <int>     <int>
#      1:        13        14
#      2:        13        -3
#      3:         9         2
#      4:       -26        -8
#      5:         1         2
#     ---                    
# 253312:       -30         1
# 253313:       -14        -5
# 253314:        16        -8
# 253315:        15        -4
# 253316:         1        -5
```

El argumento se llama `with` en honor a la función R `with()` debido a que tiene una funcionalidad similar. Supongamos que tiene un `data.frame` `DF` y desea crear un subconjunto de todas las filas donde `x > 1`. En `base` R puede hacer lo siguiente:


``` r
DF = data.frame(x = c(1,1,1,2,2,3,3,3), y = 1:8)

## (1) normal way
DF[DF$x > 1, ] # data.frame needs that ',' as well
#   x y
# 4 2 4
# 5 2 5
# 6 3 6
# 7 3 7
# 8 3 8

## (2) using with
DF[with(DF, x > 1), ]
#   x y
# 4 2 4
# 5 2 5
# 6 3 6
# 7 3 7
# 8 3 8
```

* El uso de `with()` en (2) permite usar la columna `x` de `DF` como si fuera una variable.

    Hence, the argument name `with` in `data.table`. Setting `with = FALSE` disables the ability to refer to columns as if they are variables, thereby restoring the "`data.frame` mode".

* También podemos *deseleccionar* columnas usando `-` o `!`. Por ejemplo:

    
    ``` r
    ## not run
    
    # returns all columns except arr_delay and dep_delay
    ans <- flights[, !c("arr_delay", "dep_delay")]
    # or
    ans <- flights[, -c("arr_delay", "dep_delay")]
    ```

* Desde `v1.9.5+`, también podemos seleccionar especificando los nombres de las columnas de inicio y fin, por ejemplo, `año:día` para seleccionar las primeras tres columnas.

    
    ``` r
    ## not run
    
    # returns year,month and day
    ans <- flights[, year:day]
    # returns day, month and year
    ans <- flights[, day:year]
    # returns all columns except year, month and day
    ans <- flights[, -(year:day)]
    ans <- flights[, !(year:day)]
    ```

    This is particularly handy while working interactively.

`with = TRUE` es el valor predeterminado en `data.table` porque podemos hacer mucho más al permitir que `j` maneje expresiones, especialmente cuando se combina con `by`, como veremos en un momento.

## 2. Agregaciones

Ya hemos visto `i` y `j` de la forma general de `data.table` en la sección anterior. En esta sección, veremos cómo se pueden combinar con `by` para realizar operaciones *por grupo*. Veamos algunos ejemplos.

### a) Agrupación mediante `by`

#### --¿Cómo podemos obtener el número de viajes correspondientes a cada aeropuerto de origen?


``` r
ans <- flights[, .(.N), by = .(origin)]
ans
#    origin     N
#    <char> <int>
# 1:    JFK 81483
# 2:    LGA 84433
# 3:    EWR 87400

## or equivalently using a character vector in 'by'
# ans <- flights[, .(.N), by = "origin"]
```

* Sabemos que `.N` [es una variable especial](#special-N) que contiene la cantidad de filas en el grupo actual. Al agrupar por `origen` se obtiene la cantidad de filas, `.N`, para cada grupo.

* Al ejecutar `head(flights)`, puede ver que los aeropuertos de origen aparecen en el orden *"JFK"*, *"LGA"* y *"EWR"*. El orden original de agrupación de las variables se conserva en el resultado. ¡Es importante tener esto en cuenta!_

* Dado que no proporcionamos un nombre para la columna devuelta en `j`, se la denominó `N` automáticamente al reconocer el símbolo especial `.N`.

* `by` también acepta un vector de caracteres de nombres de columnas. Esto es particularmente útil para la codificación programática, por ejemplo, para diseñar una función con las columnas de agrupación (en forma de un vector de `carácter`) como argumento de función.

* Cuando solo hay una columna o expresión a la que hacer referencia en `j` y `by`, podemos omitir la notación `.()`. Esto es puramente por conveniencia. En su lugar, podríamos hacer lo siguiente:

    
    ``` r
    ans <- flights[, .N, by = origin]
    ans
    #    origin     N
    #    <char> <int>
    # 1:    JFK 81483
    # 2:    LGA 84433
    # 3:    EWR 87400
    ```

    We'll use this convenient form wherever applicable hereafter.

#### -- ¿Cómo podemos calcular el número de viajes para cada aeropuerto de origen para el código de aerolínea `"AA"`? {#origin-.N}

El código único de aerolínea `"AA"` corresponde a *American Airlines Inc.*


``` r
ans <- flights[carrier == "AA", .N, by = origin]
ans
#    origin     N
#    <char> <int>
# 1:    JFK 11923
# 2:    LGA 11730
# 3:    EWR  2649
```

* Primero obtenemos los índices de fila para la expresión `carrier == "AA"` de `i`.

* Al utilizar esos *índices de fila*, obtenemos la cantidad de filas agrupadas por `origen`. Una vez más, aquí no se materializan columnas, ya que la `j-expression` no requiere que se creen subconjuntos de ninguna columna y, por lo tanto, es rápida y eficiente en el uso de la memoria.

#### -- ¿Cómo podemos obtener el número total de viajes para cada par `origen, destino` para el código de transportista `"AA"`? {#origin-dest-.N}


``` r
ans <- flights[carrier == "AA", .N, by = .(origin, dest)]
head(ans)
#    origin   dest     N
#    <char> <char> <int>
# 1:    JFK    LAX  3387
# 2:    LGA    PBI   245
# 3:    EWR    LAX    62
# 4:    JFK    MIA  1876
# 5:    JFK    SEA   298
# 6:    EWR    MIA   848

## or equivalently using a character vector in 'by'
# ans <- flights[carrier == "AA", .N, by = c("origin", "dest")]
```

* `by` acepta múltiples columnas. Simplemente proporcionamos todas las columnas por las que se agrupará. Observe el uso de `.()` nuevamente en `by`; nuevamente, esto es solo una forma abreviada de `list()`, y `list()` también se puede usar aquí. Nuevamente, nos quedaremos con `.()` en esta viñeta.

#### -- ¿Cómo podemos obtener el retraso promedio de llegada y salida para cada par `orig,dest` para cada mes para el código de operador `"AA"`? {#origin-dest-month}


``` r
ans <- flights[carrier == "AA",
        .(mean(arr_delay), mean(dep_delay)),
        by = .(origin, dest, month)]
ans
#      origin   dest month         V1         V2
#      <char> <char> <int>      <num>      <num>
#   1:    JFK    LAX     1   6.590361 14.2289157
#   2:    LGA    PBI     1  -7.758621  0.3103448
#   3:    EWR    LAX     1   1.366667  7.5000000
#   4:    JFK    MIA     1  15.720670 18.7430168
#   5:    JFK    SEA     1  14.357143 30.7500000
#  ---                                          
# 196:    LGA    MIA    10  -6.251799 -1.4208633
# 197:    JFK    MIA    10  -1.880184  6.6774194
# 198:    EWR    PHX    10  -3.032258 -4.2903226
# 199:    JFK    MCO    10 -10.048387 -1.6129032
# 200:    JFK    DCA    10  16.483871 15.5161290
```

* Dado que no proporcionamos nombres de columnas para las expresiones en `j`, se generaron automáticamente como `V1` y `V2`.

* Una vez más, tenga en cuenta que el orden de entrada de las columnas de agrupación se conserva en el resultado.

¿Y ahora qué pasa si queremos ordenar el resultado por las columnas de agrupación «origen», «destino» y «mes»?

### b) Ordenado `por`: `keyby`

El hecho de que `data.table` conserve el orden original de los grupos es intencional y está diseñado de esa manera. Hay casos en los que es esencial conservar el orden original, pero en ocasiones nos gustaría ordenar automáticamente por variables en nuestra agrupación.

#### --Entonces, ¿cómo podemos ordenar directamente por todas las variables de agrupación?


``` r
ans <- flights[carrier == "AA",
        .(mean(arr_delay), mean(dep_delay)),
        keyby = .(origin, dest, month)]
ans
# Key: <origin, dest, month>
#      origin   dest month         V1         V2
#      <char> <char> <int>      <num>      <num>
#   1:    EWR    DFW     1   6.427673 10.0125786
#   2:    EWR    DFW     2  10.536765 11.3455882
#   3:    EWR    DFW     3  12.865031  8.0797546
#   4:    EWR    DFW     4  17.792683 12.9207317
#   5:    EWR    DFW     5  18.487805 18.6829268
#  ---                                          
# 196:    LGA    PBI     1  -7.758621  0.3103448
# 197:    LGA    PBI     2  -7.865385  2.4038462
# 198:    LGA    PBI     3  -5.754098  3.0327869
# 199:    LGA    PBI     4 -13.966667 -4.7333333
# 200:    LGA    PBI     5 -10.357143 -6.8571429
```

* Todo lo que hicimos fue cambiar `by` por `keyby`. Esto ordena automáticamente el resultado por las variables de agrupación en orden creciente. De hecho, debido a que la implementación interna de `by` requiere primero una clasificación antes de recuperar el orden de la tabla original, `keyby` es típicamente más rápido que `by` porque no requiere este segundo paso.

**Claves:** En realidad, `keyby` hace un poco más que *simplemente ordenar*. También *establece una clave* después de ordenar, estableciendo un `atributo` llamado `sorted`.

Aprenderemos más sobre `claves` en la viñeta *Subconjunto basado en claves y búsqueda binaria rápida*; por ahora, todo lo que tiene que saber es que puede usar `keyby` para ordenar automáticamente el resultado por las columnas especificadas en `by`.

### c) Encadenamiento

Reconsideremos la tarea de [obtener el número total de viajes para cada par `origen, destino` para el transportista *"AA"*](#origin-dest-.N).


``` r
ans <- flights[carrier == "AA", .N, by = .(origin, dest)]
```

#### -- ¿Cómo podemos ordenar `ans` utilizando las columnas `origin` en orden ascendente y `dest` en orden descendente?

Podemos almacenar el resultado intermedio en una variable y luego usar `order(origin, -dest)` en esa variable. Parece bastante sencillo.


``` r
ans <- ans[order(origin, -dest)]
head(ans)
#    origin   dest     N
#    <char> <char> <int>
# 1:    EWR    PHX   121
# 2:    EWR    MIA   848
# 3:    EWR    LAX    62
# 4:    EWR    DFW  1618
# 5:    JFK    STT   229
# 6:    JFK    SJU   690
```

* Recordemos que podemos usar `-` en una columna `character` en `order()` dentro del marco de un `data.table`. Esto es posible gracias a la optimización de consultas internas de `data.table`.

* Recuerde también que `order(...)` con el marco de una `data.table` se *optimiza automáticamente* para usar el orden de base rápido interno de `data.table` `forder()` para mayor velocidad. 

Pero esto requiere tener que asignar el resultado intermedio y luego sobrescribirlo. Podemos hacer algo mejor y evitar por completo esta asignación intermedia a una variable temporal *encadenando* expresiones.


``` r
ans <- flights[carrier == "AA", .N, by = .(origin, dest)][order(origin, -dest)]
head(ans, 10)
#     origin   dest     N
#     <char> <char> <int>
#  1:    EWR    PHX   121
#  2:    EWR    MIA   848
#  3:    EWR    LAX    62
#  4:    EWR    DFW  1618
#  5:    JFK    STT   229
#  6:    JFK    SJU   690
#  7:    JFK    SFO  1312
#  8:    JFK    SEA   298
#  9:    JFK    SAN   299
# 10:    JFK    ORD   432
```

* Podemos unir expresiones una tras otra, *formando una cadena* de operaciones, es decir, `DT[ ... ][ ... ][ ... ]`.

* O también puedes encadenarlos verticalmente:

    
    ``` r
    DT[ ...
       ][ ...
         ][ ...
           ]
    ```

### d) Expresiones en `by`

#### -- ¿Puede `by` también aceptar *expresiones* o sólo toma columnas?

Sí, lo hace. Por ejemplo, si queremos saber cuántos vuelos empezaron con retraso pero llegaron antes (o a tiempo), empezaron y llegaron con retraso, etc.


``` r
ans <- flights[, .N, .(dep_delay>0, arr_delay>0)]
ans
#    dep_delay arr_delay      N
#       <lgcl>    <lgcl>  <int>
# 1:      TRUE      TRUE  72836
# 2:     FALSE      TRUE  34583
# 3:     FALSE     FALSE 119304
# 4:      TRUE     FALSE  26593
```

* La última fila corresponde a `dep_delay > 0 = TRUE` y `arr_delay > 0 = FALSE`. Podemos ver que 26593 los vuelos partieron tarde pero llegaron temprano (o a tiempo).

* Tenga en cuenta que no proporcionamos ningún nombre a `by-expression`. Por lo tanto, los nombres se han asignado automáticamente en el resultado. Al igual que con `j`, puede nombrar estas expresiones como lo haría para los elementos de cualquier `lista`, como por ejemplo `DT[, .N, .(dep_delayed = dep_delay>0, arr_delayed = arr_delay>0)]`.

* Puede proporcionar otras columnas junto con expresiones, por ejemplo: `DT[, .N, by = .(a, b>0)]`.

### e) Varias columnas en `j` - `.SD`

#### -- ¿Tenemos que calcular `mean()` para cada columna individualmente?

Por supuesto, no es práctico tener que escribir `mean(myCol)` para cada columna una por una. ¿Qué sucedería si tuviera 100 columnas para calcular el promedio de `mean()`?

¿Cómo podemos hacer esto de manera eficiente y concisa? Para lograrlo, repasemos [este consejo](#tip-1): *"Siempre que la expresión `j` devuelva una `lista`, cada elemento de la `lista` se convertirá en una columna en la `tabla de datos` resultante"*. Si podemos hacer referencia al *subconjunto de datos de cada grupo* como una variable *mientras agrupamos*, podemos recorrer todas las columnas de esa variable utilizando la función base `lapply()`, que ya nos resulta familiar o que pronto nos resultará familiar. No hay que aprender nuevos nombres específicos de `data.table`.

#### Símbolo especial `.SD`: {#special-SD}

`data.table` proporciona un símbolo *especial* llamado `.SD`. Significa **S**subset of **D**ata. Es en sí mismo una `data.table` que contiene los datos para *el grupo actual* definido usando `by`.

Recuerde que una `data.table` es internamente también una `lista` con todas sus columnas de igual longitud.

Utilicemos la [`data.table` `DT` de antes](#what-is-datatable-1a) para tener una idea de cómo se ve `.SD`.


``` r
DT
#        ID     a     b     c
#    <char> <int> <int> <int>
# 1:      b     1     7    13
# 2:      b     2     8    14
# 3:      b     3     9    15
# 4:      a     4    10    16
# 5:      a     5    11    17
# 6:      c     6    12    18

DT[, print(.SD), by = ID]
#        a     b     c
#    <int> <int> <int>
# 1:     1     7    13
# 2:     2     8    14
# 3:     3     9    15
#        a     b     c
#    <int> <int> <int>
# 1:     4    10    16
# 2:     5    11    17
#        a     b     c
#    <int> <int> <int>
# 1:     6    12    18
# Empty data.table (0 rows and 1 cols): ID
```

* `.SD` contiene todas las columnas *excepto las columnas de agrupación* de forma predeterminada.

* También se genera conservando el orden original: datos correspondientes a `ID = "b"`, luego `ID = "a"`, y luego `ID = "c"`.

Para calcular en (múltiples) columnas, podemos simplemente usar la función base R `lapply()`.


``` r
DT[, lapply(.SD, mean), by = ID]
#        ID     a     b     c
#    <char> <num> <num> <num>
# 1:      b   2.0   8.0  14.0
# 2:      a   4.5  10.5  16.5
# 3:      c   6.0  12.0  18.0
```

* `.SD` contiene las filas correspondientes a las columnas `a`, `b` y `c` de ese grupo. Calculamos la `media()` de cada una de estas columnas utilizando la función base `lapply()`, que ya conocemos.

* Cada grupo devuelve una lista de tres elementos que contienen el valor medio que se convertirán en las columnas de la tabla `data.table` resultante.

* Dado que `lapply()` devuelve una `lista`, no es necesario envolverla con un `.()` adicional (si es necesario, consulte [este consejo](#tip-1)).

Ya casi estamos listos. Queda un pequeño detalle por resolver. En nuestra tabla de datos `flights`, solo queríamos calcular la `mean()` de las dos columnas `arr_delay` y `dep_delay`. Pero `.SD` contendría todas las columnas excepto las variables de agrupamiento de forma predeterminada.

#### -- ¿Cómo podemos especificar sólo las columnas en las que nos gustaría calcular la `media()`?

#### .SDcols

Utilizando el argumento `.SDcols`. Acepta nombres de columnas o índices de columnas. Por ejemplo, `.SDcols = c("arr_delay", "dep_delay")` garantiza que `.SD` contenga solo estas dos columnas para cada grupo.

De manera similar a [parte g)](#refer_j), también puede especificar las columnas que desea eliminar en lugar de las columnas que desea conservar utilizando `-` o `!`. Además, puede seleccionar columnas consecutivas como `colA:colB` y deseleccionarlas como `!(colA:colB)` o `-(colA:colB)`.

Ahora intentemos usar `.SD` junto con `.SDcols` para obtener la `media()` de las columnas `arr_delay` y `dep_delay` agrupadas por `origen`, `dest` y `mes`.


``` r
flights[carrier == "AA",                       ## Only on trips with carrier "AA"
        lapply(.SD, mean),                     ## compute the mean
        by = .(origin, dest, month),           ## for every 'origin,dest,month'
        .SDcols = c("arr_delay", "dep_delay")] ## for just those specified in .SDcols
#      origin   dest month  arr_delay  dep_delay
#      <char> <char> <int>      <num>      <num>
#   1:    JFK    LAX     1   6.590361 14.2289157
#   2:    LGA    PBI     1  -7.758621  0.3103448
#   3:    EWR    LAX     1   1.366667  7.5000000
#   4:    JFK    MIA     1  15.720670 18.7430168
#   5:    JFK    SEA     1  14.357143 30.7500000
#  ---                                          
# 196:    LGA    MIA    10  -6.251799 -1.4208633
# 197:    JFK    MIA    10  -1.880184  6.6774194
# 198:    EWR    PHX    10  -3.032258 -4.2903226
# 199:    JFK    MCO    10 -10.048387 -1.6129032
# 200:    JFK    DCA    10  16.483871 15.5161290
```

### f) Subconjunto `.SD` para cada grupo:

#### -- ¿Cómo podemos devolver las dos primeras filas de cada "mes"?


``` r
ans <- flights[, head(.SD, 2), by = month]
head(ans)
#    month  year   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
# 1:     1  2014     1        14        13      AA    JFK    LAX      359     2475     9
# 2:     1  2014     1        -3        13      AA    JFK    LAX      363     2475    11
# 3:     2  2014     1        -1         1      AA    JFK    LAX      358     2475     8
# 4:     2  2014     1        -5         3      AA    JFK    LAX      358     2475    11
# 5:     3  2014     1       -11        36      AA    JFK    LAX      375     2475     8
# 6:     3  2014     1        -3        14      AA    JFK    LAX      368     2475    11
```

* `.SD` es una `data.table` que contiene todas las filas de *ese grupo*. Simplemente creamos un subconjunto de las dos primeras filas como ya hemos visto [aquí](#subset-rows-integer).

* Para cada grupo, `head(.SD, 2)` devuelve las primeras dos filas como una `data.table`, que también es una `lista`, por lo que no tenemos que envolverla con `.()`.

### g) ¿Por qué mantener `j` tan flexible?

Para que tengamos una sintaxis consistente y sigamos usando funciones base ya existentes (y conocidas) en lugar de aprender nuevas funciones, para ilustrarlo, usemos la tabla `data.table` `DT` que creamos al principio en la sección [¿Qué es una tabla data.table?](#what-is-datatable-1a).

#### -- ¿Cómo podemos concatenar las columnas `a` y `b` para cada grupo en `ID`?


``` r
DT[, .(val = c(a,b)), by = ID]
#         ID   val
#     <char> <int>
#  1:      b     1
#  2:      b     2
#  3:      b     3
#  4:      b     7
#  5:      b     8
#  6:      b     9
#  7:      a     4
#  8:      a     5
#  9:      a    10
# 10:      a    11
# 11:      c     6
# 12:      c    12
```

* Eso es todo. No se requiere ninguna sintaxis especial. Todo lo que necesitamos saber es la función base `c()` que concatena vectores y [el consejo de antes](#tip-1).

#### -- ¿Qué pasa si queremos tener todos los valores de las columnas `a` y `b` concatenados, pero devueltos como una columna de lista?


``` r
DT[, .(val = list(c(a,b))), by = ID]
#        ID         val
#    <char>      <list>
# 1:      b 1,2,3,7,8,9
# 2:      a  4, 5,10,11
# 3:      c        6,12
```

* Aquí, primero concatenamos los valores con `c(a,b)` para cada grupo y los envolvemos con `list()`. Por lo tanto, para cada grupo, devolvemos una lista de todos los valores concatenados.

* Tenga en cuenta que esas comas son solo para visualización. Una columna de lista puede contener cualquier objeto en cada celda y, en este ejemplo, cada celda es en sí misma un vector y algunas celdas contienen vectores más largos que otras.

Una vez que comiences a internalizar el uso de `j`, te darás cuenta de lo poderosa que puede ser la sintaxis. Una forma muy útil de entenderla es jugando con ella, con la ayuda de `print()`.

Por ejemplo:


``` r
## look at the difference between
DT[, print(c(a,b)), by = ID] # (1)
# [1] 1 2 3 7 8 9
# [1]  4  5 10 11
# [1]  6 12
# Empty data.table (0 rows and 1 cols): ID

## and
DT[, print(list(c(a,b))), by = ID] # (2)
# [[1]]
# [1] 1 2 3 7 8 9
# 
# [[1]]
# [1]  4  5 10 11
# 
# [[1]]
# [1]  6 12
# Empty data.table (0 rows and 1 cols): ID
```

En (1), para cada grupo, se devuelve un vector, con longitud = 6,4,2 aquí. Sin embargo, (2) devuelve una lista de longitud 1 para cada grupo, con su primer elemento que contiene vectores de longitud 6,4,2. Por lo tanto, (1) da como resultado una longitud de ` 6+4+2 = 12`, mientras que (2) devuelve `1+1+1=3`.

## Resumen

La forma general de la sintaxis de `data.table` es:


``` r
DT[i, j, by]
```

Hemos visto hasta ahora que,

#### Usando `i`:

* Podemos crear subconjuntos de filas de manera similar a un `data.frame`, excepto que no es necesario usar `DT$` repetidamente, ya que las columnas dentro del marco de un `data.table` se ven como si fueran *variables*.

* También podemos ordenar una `data.table` usando `order()`, que internamente usa el orden rápido de data.table para un mejor rendimiento.

Podemos hacer mucho más en `i` introduciendo claves en `data.table`, lo que permite crear subconjuntos y uniones con una velocidad increíble. Veremos esto en la viñeta *"Claves y subconjuntos basados en búsqueda binaria rápida"* y *"Uniones y uniones continuas"*.

#### Usando `j`:

1. Seleccione columnas con el método `data.table`: `DT[, .(colA, colB)]`.

2. Seleccione columnas con el método `data.frame`: `DT[, c("colA", "colB")]`.

3. Calcular en las columnas: `DT[, .(sum(colA), mean(colB))]`.

4. Proporcione nombres si es necesario: `DT[, .(sA = suma(colA), mB = media(colB))]`.

5. Combine con `i`: `DT[colA > valor, suma(colB)]`.

#### Usando `por`:

* Al usar `by`, podemos agrupar por columnas especificando una *lista de columnas* o un *vector de caracteres de nombres de columnas* o incluso *expresiones*. La flexibilidad de `j`, combinada con `by` e `i`, crea una sintaxis muy poderosa.

* `by` puede manejar múltiples columnas y también *expresiones*.

* Podemos agrupar columnas mediante clave para ordenar automáticamente el resultado agrupado.

* Podemos usar `.SD` y `.SDcols` en `j` para operar en múltiples columnas usando funciones base que ya conocemos. A continuación se muestran algunos ejemplos:

    1. `DT[, lapply(.SD, fun), by = ..., .SDcols = ...]` - aplica `fun` a todas las columnas especificadas en `.SDcols` mientras agrupa por las columnas especificadas en `by`.

    2. `DT[, head(.SD, 2), by = ...]` - devuelve las dos primeras filas de cada grupo.

    3. `DT[col > val, head(.SD, 1), by = ...]` - combina `i` junto con `j` y `by`.

#### Y recuerda el consejo:

Siempre que `j` devuelva una `lista`, cada elemento de la lista se convertirá en una columna en la `data.table` resultante.

Veremos cómo *agregar/actualizar/eliminar* columnas *por referencia* y cómo combinarlas con `i` y `by` en la próxima viñeta.

***



