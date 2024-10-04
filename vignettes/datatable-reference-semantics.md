---
title: "Reference semantics"
date: "2024-10-04"
output:
  markdown::html_format
vignette: >
  %\VignetteIndexEntry{Reference semantics}
  %\VignetteEngine{knitr::knitr}
  \usepackage[utf8]{inputenc}
---


Esta viñeta analiza la semántica de referencia de *data.table*, que permite *agregar/actualizar/eliminar* columnas de una *data.table por referencia*, y también combinarlas con `i` y `by`. Está dirigida a aquellos que ya están familiarizados con la sintaxis de *data.table*, su forma general, cómo crear subconjuntos de filas en `i`, seleccionar y calcular columnas, y realizar agregaciones por grupo. Si no está familiarizado con estos conceptos, lea primero la viñeta *"Introducción a data.table"*.

***

## Datos {#data}

Utilizaremos los mismos datos de "vuelos" que en la viñeta *"Introducción a data.table"*.




``` r
flights <- fread("flights14.csv")
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

## Introducción

En esta viñeta, vamos a

1. Primero analicemos brevemente la semántica de referencia y observemos las dos formas diferentes en las que se puede utilizar el operador `:=`

2. Luego veamos cómo podemos *agregar/actualizar/eliminar* columnas *por referencia* en `j` usando el operador `:=` y cómo combinarlo con `i` y `by`.

3. y finalmente veremos el uso de `:=` por sus *efectos secundarios* y cómo podemos evitar los efectos secundarios usando `copy()`.

## 1. Semántica de referencia

Todas las operaciones que hemos visto hasta ahora en la viñeta anterior dieron como resultado un nuevo conjunto de datos. Veremos cómo *agregar* nuevas columnas, *actualizar* o *eliminar* columnas existentes en los datos originales.

### a) Antecedentes

Antes de analizar la *semántica de referencia*, considere el *data.frame* que se muestra a continuación:


``` r
DF = data.frame(ID = c("b","b","b","a","a","c"), a = 1:6, b = 7:12, c = 13:18)
DF
#   ID a  b  c
# 1  b 1  7 13
# 2  b 2  8 14
# 3  b 3  9 15
# 4  a 4 10 16
# 5  a 5 11 17
# 6  c 6 12 18
```

Cuando lo hicimos:


``` r
DF$c <- 18:13               # (1) -- replace entire column
# or
DF$c[DF$ID == "b"] <- 15:13 # (2) -- subassign in column 'c'
```

Tanto (1) como (2) dieron como resultado una copia profunda de todo el data.frame en las versiones de `R < 3.1`. [Se copió más de una vez](https://stackoverflow.com/q/23898969/559784). Para mejorar el rendimiento evitando estas copias redundantes, *data.table* utilizó el [operador `:=` disponible pero no utilizado en R](https://stackoverflow.com/q/7033106/559784).

Se realizaron grandes mejoras de rendimiento en `R v3.1`, como resultado de lo cual solo se realiza una copia *superficial* para (1) y no una copia *profunda*. Sin embargo, para (2), todavía se realiza una copia *profunda* de toda la columna incluso en `R v3.1+`. Esto significa que cuantas más columnas se subasignan en la *misma consulta*, más copias *profundas* realiza R.

#### Copia *superficial* vs. copia *profunda*

Una copia *superficial* es simplemente una copia del vector de punteros de columna (que corresponden a las columnas en un *data.frame* o *data.table*). Los datos reales no se copian físicamente en la memoria.

Una copia *profunda*, por otro lado, copia todos los datos a otra ubicación en la memoria.

Al crear un subconjunto de una *data.table* utilizando `i` (por ejemplo, `DT[1:10]`), se realiza una copia *profunda*. Sin embargo, cuando no se proporciona `i` o es igual a `TRUE`, se realiza una copia *superficial*.

#
Con el operador `:=` de *data.table*, no se realizan copias en *ambos* (1) y (2), independientemente de la versión de R que esté utilizando. Esto se debe a que el operador `:=` actualiza las columnas de *data.table* *en el lugar* (por referencia).

### b) El operador `:=`

Se puede utilizar en `j` de dos maneras:

(a) La forma `LHS := RHS`


``` r
DT[, c("colA", "colB", ...) := list(valA, valB, ...)]

# when you have only one column to assign to you
# can drop the quotes and list(), for convenience
DT[, colA := valA]
```

(b) La forma funcional


``` r
DT[, `:=`(colA = valA, # valA is assigned to colA
          colB = valB, # valB is assigned to colB
          ...
)]
```

Tenga en cuenta que el código anterior explica cómo se puede utilizar `:=`. No son ejemplos prácticos. Comenzaremos a utilizarlos en la tabla de datos `flights` a partir de la siguiente sección.

#

* En (a), `LHS` toma un vector de caracteres de nombres de columnas y `RHS` una *lista de valores*. `RHS` solo necesita ser una `lista`, independientemente de cómo se genere (por ejemplo, utilizando `lapply()`, `list()`, `mget()`, `mapply()`, etc.). Esta forma suele ser fácil de programar y es particularmente útil cuando no se conocen de antemano las columnas a las que se deben asignar valores.

* Por otro lado, (b) es útil si quieres anotar algunos comentarios para más tarde.

* El resultado se devuelve de forma *invisible*.

* Dado que `:=` está disponible en `j`, podemos combinarlo con las operaciones `i` y `by` tal como las operaciones de agregación que vimos en la viñeta anterior.

#

En las dos formas de `:=` que se muestran arriba, tenga en cuenta que no asignamos el resultado a una variable, porque no es necesario. La entrada *data.table* se modifica por referencia. Veamos algunos ejemplos para entender lo que queremos decir con esto.

Para el resto de la viñeta, trabajaremos con la tabla de datos *flights*.

## 2. Agregar/actualizar/eliminar columnas *por referencia*

### a) Agregar columnas por referencia {#ref-j}

#### -- ¿Cómo podemos agregar las columnas *velocidad* y *demora total* de cada vuelo a la *tabla de datos* `vuelos`?


``` r
flights[, `:=`(speed = distance / (air_time/60), # speed in mph (mi/h)
               delay = arr_delay + dep_delay)]   # delay in minutes
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
#            speed delay
#            <num> <int>
#      1: 413.6490    27
#      2: 409.0909    10
#      3: 423.0769    11
#      4: 395.5414   -34
#      5: 424.2857     3
#     ---               
# 253312: 422.6866   -29
# 253313: 444.4444   -19
# 253314: 311.5663     8
# 253315: 401.6000    11
# 253316: 359.4545    -4
head(flights)
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour    speed
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>    <num>
# 1:  2014     1     1        14        13      AA    JFK    LAX      359     2475     9 413.6490
# 2:  2014     1     1        -3        13      AA    JFK    LAX      363     2475    11 409.0909
# 3:  2014     1     1         2         9      AA    JFK    LAX      351     2475    19 423.0769
# 4:  2014     1     1        -8       -26      AA    LGA    PBI      157     1035     7 395.5414
# 5:  2014     1     1         2         1      AA    JFK    LAX      350     2475    13 424.2857
# 6:  2014     1     1         4         0      AA    EWR    LAX      339     2454    18 434.3363
#    delay
#    <int>
# 1:    27
# 2:    10
# 3:    11
# 4:   -34
# 5:     3
# 6:     4

## alternatively, using the 'LHS := RHS' form
# flights[, c("speed", "delay") := list(distance/(air_time/60), arr_delay + dep_delay)]
```

#### Tenga en cuenta que

* No tuvimos que volver a asignar el resultado a `vuelos`.

* La tabla de datos `flights` ahora contiene las dos columnas recién agregadas. Esto es lo que queremos decir con *agregado por referencia*.

* Usamos la forma funcional para poder agregar comentarios al costado para explicar lo que hace el cálculo. También puedes ver la forma `LHS := RHS` (comentada).

### b) Actualizar algunas filas de columnas por referencia - *sub-asignar* por referencia {#ref-ij}

Echemos un vistazo a todas las «horas» disponibles en la tabla de datos «vuelos»:


``` r
# get all 'hours' in flights
flights[, sort(unique(hour))]
#  [1]  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
```

Vemos que hay un total de `25` valores únicos en los datos. Parece que hay tanto *0* como *24* horas. Reemplacemos *24* por *0*.

#### -- Reemplace aquellas filas donde `hora == 24` con el valor `0`


``` r
# subassign by reference
flights[hour == 24L, hour := 0L]
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
#            speed delay
#            <num> <int>
#      1: 413.6490    27
#      2: 409.0909    10
#      3: 423.0769    11
#      4: 395.5414   -34
#      5: 424.2857     3
#     ---               
# 253312: 422.6866   -29
# 253313: 444.4444   -19
# 253314: 311.5663     8
# 253315: 401.6000    11
# 253316: 359.4545    -4
```

* Podemos usar `i` junto con `:=` en `j` de la misma manera que ya hemos visto en la viñeta *"Introducción a data.table"*.

* La columna `hora` se reemplaza con `0` solo en aquellos *índices de fila* donde la condición `hora == 24L` especificada en `i` se evalúa como `VERDADERO`.

* `:=` devuelve el resultado de forma invisible. A veces puede ser necesario ver el resultado después de la asignación. Podemos lograrlo agregando un `[]` vacío al final de la consulta como se muestra a continuación:

    
    ``` r
    flights[hour == 24L, hour := 0L][]
    # Índice: <hour>
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
    #            speed delay
    #            <num> <int>
    #      1: 413.6490    27
    #      2: 409.0909    10
    #      3: 423.0769    11
    #      4: 395.5414   -34
    #      5: 424.2857     3
    #     ---               
    # 253312: 422.6866   -29
    # 253313: 444.4444   -19
    # 253314: 311.5663     8
    # 253315: 401.6000    11
    # 253316: 359.4545    -4
    ```

#
Veamos todas las “horas” para verificar.


``` r
# check again for '24'
flights[, sort(unique(hour))]
#  [1]  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23
```

#### Ejercicio: {#update-by-reference-question}

¿Cuál es la diferencia entre `vuelos[hora == 24L, hora := 0L]` y `vuelos[hora == 24L][, hora := 0L]`? Sugerencia: El último necesita una asignación (`<-`) si desea utilizar el resultado más adelante.

Si no puedes resolverlo, echa un vistazo a la sección `Nota` de `?":="`.

### c) Eliminar columna por referencia

#### -- Eliminar la columna `delay`


``` r
flights[, c("delay") := NULL]
# Índice: <hour>
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
#            speed
#            <num>
#      1: 413.6490
#      2: 409.0909
#      3: 423.0769
#      4: 395.5414
#      5: 424.2857
#     ---         
# 253312: 422.6866
# 253313: 444.4444
# 253314: 311.5663
# 253315: 401.6000
# 253316: 359.4545
head(flights)
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour    speed
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>    <num>
# 1:  2014     1     1        14        13      AA    JFK    LAX      359     2475     9 413.6490
# 2:  2014     1     1        -3        13      AA    JFK    LAX      363     2475    11 409.0909
# 3:  2014     1     1         2         9      AA    JFK    LAX      351     2475    19 423.0769
# 4:  2014     1     1        -8       -26      AA    LGA    PBI      157     1035     7 395.5414
# 5:  2014     1     1         2         1      AA    JFK    LAX      350     2475    13 424.2857
# 6:  2014     1     1         4         0      AA    EWR    LAX      339     2454    18 434.3363

## or using the functional form
# flights[, `:=`(delay = NULL)]
```

#### {#eliminar-conveniencia}

* Al asignar `NULL` a una columna, *se elimina* esa columna. Y esto sucede *instantáneamente*.

* También podemos pasar números de columnas en lugar de nombres en el `LHS`, aunque es una buena práctica de programación utilizar nombres de columnas.

* Cuando solo hay una columna para eliminar, podemos omitir el `c()` y las comillas dobles y simplemente usar el nombre de la columna *sin comillas*, para mayor comodidad. Es decir:

    
    ``` r
    flights[, delay := NULL]
    ```

    is equivalent to the code above.

### d) `:=` junto con la agrupación usando `by` {#ref-j-by}

Ya hemos visto el uso de `i` junto con `:=` en la [Sección 2b](#ref-i-j). Veamos ahora cómo podemos usar `:=` junto con `by`.

#### -- ¿Cómo podemos agregar una nueva columna que contenga para cada par `orig,dest` la velocidad máxima?


``` r
flights[, max_speed := max(speed), by = .(origin, dest)]
# Índice: <hour>
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
#            speed max_speed
#            <num>     <num>
#      1: 413.6490  526.5957
#      2: 409.0909  526.5957
#      3: 423.0769  526.5957
#      4: 395.5414  517.5000
#      5: 424.2857  526.5957
#     ---                   
# 253312: 422.6866  508.7425
# 253313: 444.4444  538.4615
# 253314: 311.5663  445.8621
# 253315: 401.6000  456.3636
# 253316: 359.4545  434.5055
head(flights)
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour    speed
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>    <num>
# 1:  2014     1     1        14        13      AA    JFK    LAX      359     2475     9 413.6490
# 2:  2014     1     1        -3        13      AA    JFK    LAX      363     2475    11 409.0909
# 3:  2014     1     1         2         9      AA    JFK    LAX      351     2475    19 423.0769
# 4:  2014     1     1        -8       -26      AA    LGA    PBI      157     1035     7 395.5414
# 5:  2014     1     1         2         1      AA    JFK    LAX      350     2475    13 424.2857
# 6:  2014     1     1         4         0      AA    EWR    LAX      339     2454    18 434.3363
#    max_speed
#        <num>
# 1:  526.5957
# 2:  526.5957
# 3:  526.5957
# 4:  517.5000
# 5:  526.5957
# 6:  518.4507
```

* Agregamos una nueva columna `max_speed` usando el operador `:=` por referencia.

* Proporcionamos las columnas para agrupar de la misma manera que se muestra en la viñeta *Introducción a data.table*. Para cada grupo, se calcula `max(speed)`, que devuelve un único valor. Ese valor se recicla para ajustarse a la longitud del grupo. Una vez más, no se realizan copias en absoluto. La tabla *data.table* `flights` se modifica *in situ*.

* También podríamos haber proporcionado `by` con un *vector de caracteres* como vimos en la viñeta *Introducción a data.table*, por ejemplo, `by = c("origin", "dest")`.

#

### e) Varias columnas y `:=`

#### -- ¿Cómo podemos agregar dos columnas más calculando `max()` de `dep_delay` y `arr_delay` para cada mes, usando `.SD`?


``` r
in_cols  = c("dep_delay", "arr_delay")
out_cols = c("max_dep_delay", "max_arr_delay")
flights[, c(out_cols) := lapply(.SD, max), by = month, .SDcols = in_cols]
# Índice: <hour>
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
#            speed max_speed max_dep_delay max_arr_delay
#            <num>     <num>         <int>         <int>
#      1: 413.6490  526.5957           973           996
#      2: 409.0909  526.5957           973           996
#      3: 423.0769  526.5957           973           996
#      4: 395.5414  517.5000           973           996
#      5: 424.2857  526.5957           973           996
#     ---                                               
# 253312: 422.6866  508.7425          1498          1494
# 253313: 444.4444  538.4615          1498          1494
# 253314: 311.5663  445.8621          1498          1494
# 253315: 401.6000  456.3636          1498          1494
# 253316: 359.4545  434.5055          1498          1494
head(flights)
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour    speed
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>    <num>
# 1:  2014     1     1        14        13      AA    JFK    LAX      359     2475     9 413.6490
# 2:  2014     1     1        -3        13      AA    JFK    LAX      363     2475    11 409.0909
# 3:  2014     1     1         2         9      AA    JFK    LAX      351     2475    19 423.0769
# 4:  2014     1     1        -8       -26      AA    LGA    PBI      157     1035     7 395.5414
# 5:  2014     1     1         2         1      AA    JFK    LAX      350     2475    13 424.2857
# 6:  2014     1     1         4         0      AA    EWR    LAX      339     2454    18 434.3363
#    max_speed max_dep_delay max_arr_delay
#        <num>         <int>         <int>
# 1:  526.5957           973           996
# 2:  526.5957           973           996
# 3:  526.5957           973           996
# 4:  517.5000           973           996
# 5:  526.5957           973           996
# 6:  518.4507           973           996
```

* Usamos el formato `LHS := RHS`. Almacenamos los nombres de las columnas de entrada y las nuevas columnas que se agregarán en variables separadas y las proporcionamos a `.SDcols` y a `LHS` (para una mejor legibilidad).

* Tenga en cuenta que, dado que permitimos la asignación por referencia sin citar los nombres de las columnas cuando solo hay una columna, como se explica en la [Sección 2c](#delete-convenience), no podemos hacer `out_cols := lapply(.SD, max)`. Eso daría como resultado la adición de una nueva columna llamada `out_cols`. En su lugar, deberíamos hacer `c(out_cols)` o simplemente `(out_cols)`. Envolver el nombre de la variable con `(` es suficiente para diferenciar entre los dos casos.

* La forma `LHS := RHS` nos permite operar en múltiples columnas. En la forma RHS, para calcular el `max` en las columnas especificadas en `.SDcols`, utilizamos la función base `lapply()` junto con `.SD` de la misma manera que hemos visto antes en la viñeta *"Introducción a data.table"*. Devuelve una lista de dos elementos, que contiene el valor máximo correspondiente a `dep_delay` y `arr_delay` para cada grupo.

#
Antes de pasar a la siguiente sección, limpiemos las columnas recién creadas `speed`, `max_speed`, `max_dep_delay` y `max_arr_delay`.


``` r
# RHS gets automatically recycled to length of LHS
flights[, c("speed", "max_speed", "max_dep_delay", "max_arr_delay") := NULL]
# Índice: <hour>
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
head(flights)
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
# 1:  2014     1     1        14        13      AA    JFK    LAX      359     2475     9
# 2:  2014     1     1        -3        13      AA    JFK    LAX      363     2475    11
# 3:  2014     1     1         2         9      AA    JFK    LAX      351     2475    19
# 4:  2014     1     1        -8       -26      AA    LGA    PBI      157     1035     7
# 5:  2014     1     1         2         1      AA    JFK    LAX      350     2475    13
# 6:  2014     1     1         4         0      AA    EWR    LAX      339     2454    18
```

#### -- ¿Cómo podemos actualizar varias columnas existentes utilizando `.SD`?


``` r
flights[, names(.SD) := lapply(.SD, as.factor), .SDcols = is.character]
# Índice: <hour>
#          year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#         <int> <int> <int>     <int>     <int>  <fctr> <fctr> <fctr>    <int>    <int> <int>
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
```
Limpiemos nuevamente y convirtamos nuestras columnas de factores recién creadas nuevamente en columnas de caracteres. Esta vez, utilizaremos `.SDcols`, que acepta una función para decidir qué columnas incluir. En este caso, `is.factor()` devolverá las columnas que son factores. Para obtener más información sobre el **S**subconjunto de los **D**ata, también hay una [viñeta de uso de SD](https://cran.r-project.org/package=data.table/vignettes/datatable-sd-usage.html).

A veces, también es bueno llevar un registro de las columnas que transformamos. De esa manera, incluso después de convertir nuestras columnas, podremos llamar a las columnas específicas que estábamos actualizando.

``` r
factor_cols <- sapply(flights, is.factor)
flights[, names(.SD) := lapply(.SD, as.character), .SDcols = factor_cols]
# Índice: <hour>
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
str(flights[, ..factor_cols])
# Classes 'data.table' and 'data.frame':	253316 obs. of  3 variables:
#  $ carrier: chr  "AA" "AA" "AA" "AA" ...
#  $ origin : chr  "JFK" "JFK" "JFK" "LGA" ...
#  $ dest   : chr  "LAX" "LAX" "LAX" "PBI" ...
#  - attr(*, ".internal.selfref")=<externalptr>
```

#### {.bs-callout.bs-callout-info}

* También podríamos haber usado `(factor_cols)` en el `LHS` en lugar de `names(.SD)`.

## 3. `:=` y `copy()`

`:=` modifica el objeto de entrada por referencia. Aparte de las características que ya hemos comentado, a veces podríamos querer utilizar la función de actualización por referencia por su efecto secundario. Y en otras ocasiones puede que no sea deseable modificar el objeto original, en cuyo caso podemos utilizar la función `copy()`, como veremos en un momento.

### a) `:=` por su efecto secundario

Digamos que queremos crear una función que devuelva la *velocidad máxima* de cada mes, pero al mismo tiempo también queremos añadir la columna `velocidad` a *vuelos*. Podríamos escribir una función sencilla de la siguiente manera:


``` r
foo <- function(DT) {
  DT[, speed := distance / (air_time/60)]
  DT[, .(max_speed = max(speed)), by = month]
}
ans = foo(flights)
head(flights)
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour    speed
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>    <num>
# 1:  2014     1     1        14        13      AA    JFK    LAX      359     2475     9 413.6490
# 2:  2014     1     1        -3        13      AA    JFK    LAX      363     2475    11 409.0909
# 3:  2014     1     1         2         9      AA    JFK    LAX      351     2475    19 423.0769
# 4:  2014     1     1        -8       -26      AA    LGA    PBI      157     1035     7 395.5414
# 5:  2014     1     1         2         1      AA    JFK    LAX      350     2475    13 424.2857
# 6:  2014     1     1         4         0      AA    EWR    LAX      339     2454    18 434.3363
head(ans)
#    month max_speed
#    <int>     <num>
# 1:     1  535.6425
# 2:     2  535.6425
# 3:     3  549.0756
# 4:     4  585.6000
# 5:     5  544.2857
# 6:     6  608.5714
```

* Tenga en cuenta que se ha añadido la nueva columna `speed` a la tabla de datos `flights`. Esto se debe a que `:=` realiza operaciones por referencia. Dado que `DT` (el argumento de la función) y `flights` hacen referencia al mismo objeto en la memoria, la modificación de `DT` también se refleja en `flights`.

* Y `ans` contiene la velocidad máxima para cada mes.

### b) La función `copy()`

En la sección anterior, usamos `:=` por su efecto secundario. Pero, por supuesto, esto puede no ser siempre deseable. A veces, nos gustaría pasar un objeto *data.table* a una función y podríamos querer usar el operador `:=`, pero *no* querríamos actualizar el objeto original. Podemos lograr esto usando la función `copy()`.

La función `copy()` copia *deep* el objeto de entrada y, por lo tanto, cualquier operación de actualización por referencia posterior realizada en el objeto copiado no afectará al objeto original.

#

Hay dos lugares particulares donde la función `copy()` es esencial:

1. Contrariamente a la situación que hemos visto en el punto anterior, es posible que no queramos que la tabla de datos de entrada de una función se modifique *por referencia*. Como ejemplo, consideremos la tarea de la sección anterior, excepto que no queremos modificar `vuelos` por referencia.

    Let's first delete the `speed` column we generated in the previous section.

    
    ``` r
    flights[, speed := NULL]
    # Índice: <hour>
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
    ```
    Now, we could accomplish the task as follows:

    
    ``` r
    foo <- function(DT) {
      DT <- copy(DT)                              ## deep copy
      DT[, speed := distance / (air_time/60)]     ## doesn't affect 'flights'
      DT[, .(max_speed = max(speed)), by = month]
    }
    ans <- foo(flights)
    head(flights)
    #     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
    #    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
    # 1:  2014     1     1        14        13      AA    JFK    LAX      359     2475     9
    # 2:  2014     1     1        -3        13      AA    JFK    LAX      363     2475    11
    # 3:  2014     1     1         2         9      AA    JFK    LAX      351     2475    19
    # 4:  2014     1     1        -8       -26      AA    LGA    PBI      157     1035     7
    # 5:  2014     1     1         2         1      AA    JFK    LAX      350     2475    13
    # 6:  2014     1     1         4         0      AA    EWR    LAX      339     2454    18
    head(ans)
    #    month max_speed
    #    <int>     <num>
    # 1:     1  535.6425
    # 2:     2  535.6425
    # 3:     3  549.0756
    # 4:     4  585.6000
    # 5:     5  544.2857
    # 6:     6  608.5714
    ```

* El uso de la función `copy()` no actualizó la tabla de datos `flights` por referencia. No contiene la columna `speed`.

* Y `ans` contiene la velocidad máxima correspondiente a cada mes.

Sin embargo, podríamos mejorar aún más esta funcionalidad mediante una copia *superficial* en lugar de una copia *profunda*. De hecho, nos gustaría mucho [ofrecer esta funcionalidad para `v1.9.8`](https://github.com/Rdatatable/data.table/issues/617). Volveremos a abordar este tema en la viñeta *diseño de data.table*.

#

2. Cuando almacenamos los nombres de las columnas en una variable, por ejemplo, `DT_n = names(DT)`, y luego *agregamos/actualizamos/eliminamos* columnas *por referencia*, también modificaría `DT_n`, a menos que hagamos `copy(names(DT))`.

    
    ``` r
    DT = data.table(x = 1L, y = 2L)
    DT_n = names(DT)
    DT_n
    # [1] "x" "y"
    
    ## add a new column by reference
    DT[, z := 3L]
    #        x     y     z
    #    <int> <int> <int>
    # 1:     1     2     3
    
    ## DT_n also gets updated
    DT_n
    # [1] "x" "y" "z"
    
    ## use `copy()`
    DT_n = copy(names(DT))
    DT[, w := 4L]
    #        x     y     z     w
    #    <int> <int> <int> <int>
    # 1:     1     2     3     4
    
    ## DT_n doesn't get updated
    DT_n
    # [1] "x" "y" "z"
    ```

## Resumen

#### El operador `:=`

* Se utiliza para *agregar/actualizar/eliminar* columnas por referencia.

* También hemos visto cómo utilizar `:=` junto con `i` y `by` de la misma forma que hemos visto en la viñeta *Introducción a data.table*. De la misma forma, podemos utilizar `keyby`, encadenar operaciones y pasar expresiones a `by` también de la misma forma. La sintaxis es *consistente*.

* Podemos usar `:=` por su efecto secundario o usar `copy()` para no modificar el objeto original mientras actualizamos por referencia.



#

Hasta ahora hemos visto mucho sobre `j`, y cómo combinarlo con `by` y un poco de `i`. Volvamos nuestra atención a `i` en la siguiente viñeta *"Subconjunto basado en claves y búsqueda binaria rápida"* para realizar *subconjuntos ultrarrápidos* mediante *claves data.tables*.

***

