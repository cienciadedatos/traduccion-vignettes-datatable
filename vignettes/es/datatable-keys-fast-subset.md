---
title: "Keys and fast binary search based subset"
date: "2024-10-07"
output:
  markdown::html_format
vignette: >
  %\VignetteIndexEntry{Keys and fast binary search based subset}
  %\VignetteEngine{knitr::knitr}
  \usepackage[utf8]{inputenc}
---



Esta viñeta está dirigida a aquellos que ya están familiarizados con la sintaxis de *data.table*, su forma general, cómo crear subconjuntos de filas en `i`, seleccionar y calcular columnas, agregar/modificar/eliminar columnas *por referencia* en `j` y agrupar utilizando `by`. Si no está familiarizado con estos conceptos, lea primero las viñetas *"Introducción a data.table"* y *"Semántica de referencia"*.

***

## Datos {#data}

Utilizaremos los mismos datos de "vuelos" que en la viñeta *"Introducción a data.table"*.




``` r
flights <- fread("flights14.csv")
head(flights)
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
# 1:  2014     1     1        14        13      AA    JFK    LAX      359     2475     9
# 2:  2014     1     1        -3        13      AA    JFK    LAX      363     2475    11
# 3:  2014     1     1         2         9      AA    JFK    LAX      351     2475    19
# 4:  2014     1     1        -8       -26      AA    LGA    PBI      157     1035     7
# 5:  2014     1     1         2         1      AA    JFK    LAX      350     2475    13
# 6:  2014     1     1         4         0      AA    EWR    LAX      339     2454    18
dim(flights)
# [1] 253316     11
```

## Introducción

En esta viñeta, vamos a

* primero introduzca el concepto de `clave` en *data.table*, y establezca y use claves para realizar *búsquedas binarias rápidas* basadas en subconjuntos en `i`,

* observa que podemos combinar subconjuntos basados en clave junto con `j` y `by` exactamente de la misma manera que antes,

* mira otros argumentos útiles adicionales: `mult` y `nomatch`,

* y finalmente concluimos mirando la ventaja de configurar claves: realizar *búsquedas binarias rápidas basadas en subconjuntos* y compararlas con el enfoque de escaneo vectorial tradicional.

## 1. Llaves

### a) ¿Qué es una *clave*?

En la viñeta *"Introducción a data.table"*, vimos cómo crear subconjuntos de filas en `i` utilizando expresiones lógicas, números de fila y el uso de `order()`. En esta sección, veremos otra forma de crear subconjuntos increíblemente rápido: utilizando *claves*.

Pero primero, comencemos por analizar los *data.frames*. Todos los *data.frames* tienen un atributo de nombre de fila. Considere el *data.frame* `DF` a continuación.


``` r
set.seed(1L)
DF = data.frame(ID1 = sample(letters[1:2], 10, TRUE),
                ID2 = sample(1:3, 10, TRUE),
                val = sample(10),
                stringsAsFactors = FALSE,
                row.names = sample(LETTERS[1:10]))
DF
#   ID1 ID2 val
# I   a   1  10
# D   a   3   9
# G   a   1   4
# A   a   1   7
# B   a   1   1
# E   b   1   8
# C   b   2   3
# J   b   1   2
# F   b   1   5
# H   a   2   6

rownames(DF)
#  [1] "I" "D" "G" "A" "B" "E" "C" "J" "F" "H"
```

Podemos crear un *subconjunto* de una fila particular usando su nombre de fila como se muestra a continuación:


``` r
DF["C", ]
#   ID1 ID2 val
# C   b   2   3
```

Es decir, los nombres de fila son más o menos *un índice* de las filas de un *data.frame*. Sin embargo,

1. Cada fila está limitada a *exactamente un* nombre de fila.

    But, a person (for example) has at least two names - a *first* and a *second* name. It is useful to organise a telephone directory by *surname* then *first name*.

2. Y los nombres de las filas deben ser *únicos*.

    
    ``` r
    rownames(DF) = sample(LETTERS[1:5], 10, TRUE)
    # Warning: non-unique values when setting 'row.names': 'C', 'D'
    # Error in `.rowNamesDF<-`(x, value = value): duplicate 'row.names' are not allowed
    ```

Ahora vamos a convertirlo en una *tabla de datos*.


``` r
DT = as.data.table(DF)
DT
#        ID1   ID2   val
#     <char> <int> <int>
#  1:      a     1    10
#  2:      a     3     9
#  3:      a     1     4
#  4:      a     1     7
#  5:      a     1     1
#  6:      b     1     8
#  7:      b     2     3
#  8:      b     1     2
#  9:      b     1     5
# 10:      a     2     6

rownames(DT)
#  [1] "1"  "2"  "3"  "4"  "5"  "6"  "7"  "8"  "9"  "10"
```

* Tenga en cuenta que los nombres de las filas se han restablecido.

* *data.tables* nunca utiliza nombres de fila. Dado que *data.tables* **hereda** de *data.frames*, aún tiene el atributo de nombres de fila, pero nunca los utiliza. En un momento veremos por qué.

    If you would like to preserve the row names, use `keep.rownames = TRUE` in `as.data.table()` - this will create a new column called `rn` and assign row names to this column.

En cambio, en *data.tables*, establecemos y usamos `keys`. Piense en una `key` como si fuera un conjunto de **nombres de fila supercargados**.

#### Claves y sus propiedades {#key-properties}

1. Podemos establecer claves en *varias columnas* y la columna puede ser de *diferentes tipos*: *entero*, *numérico*, *carácter*, *factor*, *entero64*, etc. Los tipos *lista* y *complejos* aún no son compatibles.

2. No se exige unicidad, es decir, se permiten valores de clave duplicados. Dado que las filas se ordenan por clave, los duplicados en las columnas de clave aparecerán de forma consecutiva.

3. Establecer una `clave` hace *dos* cosas:

    a. physically reorders the rows of the *data.table* by the column(s) provided *by reference*, always in *increasing* order.

    b. marks those columns as *key* columns by setting an attribute called `sorted` to the *data.table*.

    Since the rows are reordered, a *data.table* can have at most one key because it can not be sorted in more than one way.

Para el resto de la viñeta, trabajaremos con el conjunto de datos "vuelos".

### b) Establecer, obtener y utilizar claves en una *data.table*

#### -- ¿Cómo podemos establecer la columna `origen` como clave en la *tabla de datos* `vuelos`?


``` r
setkey(flights, origin)
head(flights)
# Key: <origin>
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
# 1:  2014     1     1         4         0      AA    EWR    LAX      339     2454    18
# 2:  2014     1     1        -5       -17      AA    EWR    MIA      161     1085    16
# 3:  2014     1     1       191       185      AA    EWR    DFW      214     1372    16
# 4:  2014     1     1        -1        -2      AA    EWR    DFW      214     1372    14
# 5:  2014     1     1        -3       -10      AA    EWR    MIA      154     1085     6
# 6:  2014     1     1         4       -17      AA    EWR    DFW      215     1372     9

## alternatively we can provide character vectors to the function 'setkeyv()'
# setkeyv(flights, "origin") # useful to program with
```

* Puede utilizar la función `setkey()` y proporcionar los nombres de las columnas (sin comillas). Esto resulta útil durante el uso interactivo.

* Alternativamente, puede pasar un vector de caracteres de nombres de columnas a la función `setkeyv()`. Esto es particularmente útil al diseñar funciones para pasar columnas a las que se les asignará una clave como argumentos de función.

* Tenga en cuenta que no tuvimos que asignar el resultado a una variable. Esto se debe a que, al igual que la función `:=` que vimos en la viñeta *"Semántica de referencia"*, `setkey()` y `setkeyv()` modifican la entrada *data.table* *por referencia*. Devuelven el resultado de forma invisible.

* La *data.table* ahora está reordenada (u ordenada) por la columna que proporcionamos: `origin`. Como reordenamos por referencia, solo necesitamos memoria adicional de una columna de longitud igual a la cantidad de filas en la *data.table* y, por lo tanto, es muy eficiente en el uso de la memoria.

* También puede establecer claves directamente al crear *data.tables* utilizando la función `data.table()` con el argumento `key`. Toma un vector de caracteres de nombres de columnas.

#### establecer* y `:=`:

En *data.table*, el operador `:=` y todas las funciones `set*` (por ejemplo, `setkey`, `setorder`, `setnames` etc.) son las únicas que modifican el objeto de entrada *por referencia*.

Una vez que se *identifica* una *tabla de datos* por determinadas columnas, se puede crear un subconjunto consultando esas columnas clave utilizando la notación `.()` en `i`. Recuerde que `.()` es un *alias* de `list()`.

#### -- Utilice la columna clave `origen` para crear un subconjunto de todas las filas donde el aeropuerto de origen coincida con *"JFK"*


``` r
flights[.("JFK")]
# Key: <origin>
#         year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#        <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
#     1:  2014     1     1        14        13      AA    JFK    LAX      359     2475     9
#     2:  2014     1     1        -3        13      AA    JFK    LAX      363     2475    11
#     3:  2014     1     1         2         9      AA    JFK    LAX      351     2475    19
#     4:  2014     1     1         2         1      AA    JFK    LAX      350     2475    13
#     5:  2014     1     1        -2       -18      AA    JFK    LAX      338     2475    21
#    ---                                                                                    
# 81479:  2014    10    31        -4       -21      UA    JFK    SFO      337     2586    17
# 81480:  2014    10    31        -2       -37      UA    JFK    SFO      344     2586    18
# 81481:  2014    10    31         0       -33      UA    JFK    LAX      320     2475    17
# 81482:  2014    10    31        -6       -38      UA    JFK    SFO      343     2586     9
# 81483:  2014    10    31        -6       -38      UA    JFK    LAX      323     2475    11

## alternatively
# flights[J("JFK")] (or)
# flights[list("JFK")]
```

* La columna *key* ya se ha establecido en `origin`. Por lo tanto, es suficiente proporcionar el valor, aquí *"JFK"*, directamente. La sintaxis `.()` ayuda a identificar que la tarea requiere buscar el valor *"JFK"* en la columna de clave de *data.table* (aquí, la columna `origin` de *data.table* `flights`).

* Primero se obtienen los *índices de fila* correspondientes al valor *"JFK"* en `origin`. Y como no hay expresión en `j`, se devuelven todas las columnas correspondientes a esos índices de fila.

* En una clave de columna única de tipo *carácter*, puede eliminar la notación `.()` y usar los valores directamente al crear subconjuntos, como un subconjunto que usa nombres de fila en *data.frames*.

    
    ``` r
    flights["JFK"]              ## same as flights[.("JFK")]
    ```

* Podemos crear subconjuntos de cualquier cantidad de valores según sea necesario

    
    ``` r
    flights[c("JFK", "LGA")]    ## same as flights[.(c("JFK", "LGA"))]
    ```

    This returns all columns corresponding to those rows where `origin` column matches either *"JFK"* or *"LGA"*.

#### -- ¿Cómo podemos obtener las columnas por las que se codifica una *data.table*?

Usando la función `key()`.


``` r
key(flights)
# [1] "origin"
```

* Devuelve un vector de caracteres de todas las columnas clave.

* Si no se establece ninguna clave, devuelve `NULL`.

### c) Claves y columnas múltiples

Para refrescar, las *claves* son como nombres de fila *supercargados*. Podemos establecer claves en varias columnas y pueden ser de varios tipos.

#### -- ¿Cómo puedo configurar claves en las columnas `origin` *y* `dest`?


``` r
setkey(flights, origin, dest)
head(flights)
# Key: <origin, dest>
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
# 1:  2014     1     2        -2       -25      EV    EWR    ALB       30      143     7
# 2:  2014     1     3        88        79      EV    EWR    ALB       29      143    23
# 3:  2014     1     4       220       211      EV    EWR    ALB       32      143    15
# 4:  2014     1     4        35        19      EV    EWR    ALB       32      143     7
# 5:  2014     1     5        47        42      EV    EWR    ALB       26      143     8
# 6:  2014     1     5        66        62      EV    EWR    ALB       31      143    23

## or alternatively
# setkeyv(flights, c("origin", "dest")) # provide a character vector of column names

key(flights)
# [1] "origin" "dest"
```

* Ordena la *data.table* primero por la columna `origen` y luego por `dest` *por referencia*.

#### -- Subconjunto de todas las filas utilizando columnas clave donde la primera columna clave `origin` coincide con *"JFK"* y la segunda columna clave `dest` coincide con *"MIA"*


``` r
flights[.("JFK", "MIA")]
# Key: <origin, dest>
#        year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#       <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
#    1:  2014     1     1        -1       -17      AA    JFK    MIA      161     1089    15
#    2:  2014     1     1         7        -8      AA    JFK    MIA      166     1089     9
#    3:  2014     1     1         2        -1      AA    JFK    MIA      164     1089    12
#    4:  2014     1     1         6         3      AA    JFK    MIA      157     1089     5
#    5:  2014     1     1         6       -12      AA    JFK    MIA      154     1089    17
#   ---                                                                                    
# 2746:  2014    10    31        -1       -22      AA    JFK    MIA      148     1089    16
# 2747:  2014    10    31        -3       -20      AA    JFK    MIA      146     1089     8
# 2748:  2014    10    31         2       -17      AA    JFK    MIA      150     1089     6
# 2749:  2014    10    31        -3       -12      AA    JFK    MIA      150     1089     5
# 2750:  2014    10    31        29         4      AA    JFK    MIA      146     1089    19
```

#### ¿Cómo funciona el subconjunto aquí? {#multiple-key-point}

* Es importante entender cómo funciona esto internamente. *"JFK"* primero se compara con la primera columna de clave `origin`. Y *dentro de esas filas coincidentes*, *"MIA"* se compara con la segunda columna de clave `dest` para obtener *índices de fila* donde tanto `origin` como `dest` coinciden con los valores dados.

* Dado que no se proporciona ninguna `j`, simplemente devolvemos *todas las columnas* correspondientes a esos índices de fila.

#### -- Subconjunto de todas las filas donde solo la primera columna de clave `origen` coincide con *"JFK"*


``` r
key(flights)
# [1] "origin" "dest"

flights[.("JFK")] ## or in this case simply flights["JFK"], for convenience
# Key: <origin, dest>
#         year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#        <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
#     1:  2014     1     1        10         4      B6    JFK    ABQ      280     1826    20
#     2:  2014     1     2       134       161      B6    JFK    ABQ      252     1826    22
#     3:  2014     1     7         6         6      B6    JFK    ABQ      269     1826    20
#     4:  2014     1     8        15       -15      B6    JFK    ABQ      259     1826    20
#     5:  2014     1     9        45        32      B6    JFK    ABQ      267     1826    20
#    ---                                                                                    
# 81479:  2014    10    31         0       -18      DL    JFK    TPA      142     1005     8
# 81480:  2014    10    31         1        -8      B6    JFK    TPA      149     1005    19
# 81481:  2014    10    31        -2       -22      B6    JFK    TPA      145     1005    14
# 81482:  2014    10    31        -8        -5      B6    JFK    TPA      149     1005     9
# 81483:  2014    10    31        -4       -18      B6    JFK    TPA      145     1005     8
```

* Dado que no proporcionamos ningún valor para la segunda columna clave `dest`, simplemente compara *"JFK"* con la primera columna clave `origin` y devuelve todas las filas coincidentes.

#### -- Subconjunto de todas las filas donde solo la segunda columna clave `dest` coincide con *"MIA"*


``` r
flights[.(unique(origin), "MIA")]
# Key: <origin, dest>
#        year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#       <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
#    1:  2014     1     1        -5       -17      AA    EWR    MIA      161     1085    16
#    2:  2014     1     1        -3       -10      AA    EWR    MIA      154     1085     6
#    3:  2014     1     1        -5        -8      AA    EWR    MIA      157     1085    11
#    4:  2014     1     1        43        42      UA    EWR    MIA      155     1085    15
#    5:  2014     1     1        60        49      UA    EWR    MIA      162     1085    21
#   ---                                                                                    
# 9924:  2014    10    31       -11        -8      AA    LGA    MIA      157     1096    13
# 9925:  2014    10    31        -5       -11      AA    LGA    MIA      150     1096     9
# 9926:  2014    10    31        -2        10      AA    LGA    MIA      156     1096     6
# 9927:  2014    10    31        -2       -16      AA    LGA    MIA      156     1096    19
# 9928:  2014    10    31         1       -11      US    LGA    MIA      164     1096    15
```

#### ¿Que está pasando aquí?

* Lea [esto](#multiple-key-point) nuevamente. El valor provisto para la segunda columna de clave *"MIA"* tiene que encontrar los valores coincidentes en la columna de clave `dest` *en las filas coincidentes provistas por la primera columna de clave `origin`*. No podemos omitir los valores de las columnas de clave *anteriores*. Por lo tanto, proporcionamos *todos* los valores únicos de la columna de clave `origin`.

* *"MIA"* se recicla automáticamente para ajustarse a la longitud de `unique(origin)` que es *3*.

## 2. Combinando teclas con `j` y `by`

Hasta ahora, todo lo que hemos visto es el mismo concepto: obtener *índices de fila* en `i`, pero utilizando un método diferente: el uso de `keys`. No debería sorprender que podamos hacer exactamente lo mismo en `j` y `by`, como se vio en los ejemplos anteriores. Lo destacaremos con algunos ejemplos.

### a) Seleccione en `j`

#### -- Devuelve la columna `arr_delay` como una *data.table* correspondiente a `origin = "LGA"` y `dest = "TPA"`.


``` r
key(flights)
# [1] "origin" "dest"
flights[.("LGA", "TPA"), .(arr_delay)]
#       arr_delay
#           <int>
#    1:         1
#    2:        14
#    3:       -17
#    4:        -4
#    5:       -12
#   ---          
# 1848:        39
# 1849:       -24
# 1850:       -12
# 1851:        21
# 1852:       -11
```

* Los *índices de fila* correspondientes a `origin == "LGA"` y `dest == "TPA"` se obtienen utilizando un *subconjunto basado en clave*.

* Una vez que tenemos los índices de fila, observamos `j`, que requiere solo la columna `arr_delay`. Por lo tanto, simplemente seleccionamos la columna `arr_delay` para esos *índices de fila* de la misma manera que hemos visto en la viñeta *Introducción a data.table*.

* Podríamos haber devuelto el resultado usando `with = FALSE` también.

    
    ``` r
    flights[.("LGA", "TPA"), "arr_delay", with = FALSE]
    ```

### b) Encadenamiento

#### -- Sobre el resultado obtenido anteriormente, utilice el encadenamiento para ordenar la columna en orden decreciente.


``` r
flights[.("LGA", "TPA"), .(arr_delay)][order(-arr_delay)]
#       arr_delay
#           <int>
#    1:       486
#    2:       380
#    3:       351
#    4:       318
#    5:       300
#   ---          
# 1848:       -40
# 1849:       -43
# 1850:       -46
# 1851:       -48
# 1852:       -49
```

### c) Calcular o *hacer* en `j`

#### -- Encuentra el retraso máximo de llegada correspondiente a `origin = "LGA"` y `dest = "TPA"`.


``` r
flights[.("LGA", "TPA"), max(arr_delay)]
# [1] 486
```

*Podemos verificar que el resultado es idéntico al primer valor (486) del ejemplo anterior.

### d) *sub-asignar* por referencia usando `:=` en `j`

Ya hemos visto este ejemplo en la viñeta *Semántica de referencia*. Echemos un vistazo a todas las `horas` disponibles en la *tabla de datos* `vuelos`:


``` r
# get all 'hours' in flights
flights[, sort(unique(hour))]
#  [1]  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
```

Vemos que hay un total de `25` valores únicos en los datos. Parece que están presentes tanto *0* como *24* horas. Reemplacemos *24* por *0*, pero esta vez usando *key*.


``` r
setkey(flights, hour)
key(flights)
# [1] "hour"
flights[.(24), hour := 0L]
#          year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#         <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
#      1:  2014     4    15       598       602      DL    EWR    ATL      104      746     0
#      2:  2014     5    22       289       267      DL    EWR    ATL      102      746     0
#      3:  2014     7    14       277       253      DL    EWR    ATL      101      746     0
#      4:  2014     2    14       128       117      EV    EWR    BDL       27      116     0
#      5:  2014     6    17       127       119      EV    EWR    BDL       24      116     0
#     ---                                                                                    
# 253312:  2014     8     3         1       -13      DL    JFK    SJU      196     1598     0
# 253313:  2014    10     8         1         1      B6    JFK    SJU      199     1598     0
# 253314:  2014     7    14       211       219      B6    JFK    SLC      282     1990     0
# 253315:  2014     7     3       440       418      FL    LGA    ATL      107      762     0
# 253316:  2014     6    13       300       280      DL    LGA    PBI      140     1035     0
key(flights)
# NULL
```

* Primero establecemos `key` en `hour`. Esto reordena `flights` por la columna `hour` y marca esa columna como la columna `key`.

* Ahora podemos crear un subconjunto en `hora` usando la notación `.()`. Creamos un subconjunto para el valor *24* y obtenemos los *índices de fila* correspondientes.

* Y en esos índices de fila, reemplazamos la columna `key` con el valor `0`.

* Dado que hemos reemplazado los valores en la columna *key*, la *data.table* `flights` ya no se ordena por `hour`. Por lo tanto, la clave se ha eliminado automáticamente al establecerla en NULL.

Ahora, no debería haber ningún *24* en la columna "hora".


``` r
flights[, sort(unique(hour))]
#  [1]  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23
```

### e) Agregación utilizando `por`

Primero, establezcamos nuevamente la clave en `origen, destino`.


``` r
setkey(flights, origin, dest)
key(flights)
# [1] "origin" "dest"
```

#### -- Obtener el retraso máximo de salida para cada `mes` correspondiente a `origen = "JFK"`. Ordenar el resultado por `mes`


``` r
ans <- flights["JFK", max(dep_delay), keyby = month]
head(ans)
# Key: <month>
#    month    V1
#    <int> <int>
# 1:     1   881
# 2:     2  1014
# 3:     3   920
# 4:     4  1241
# 5:     5   853
# 6:     6   798
key(ans)
# [1] "month"
```

* Creamos un subconjunto de la columna `clave` *origen* para obtener los *índices de fila* correspondientes a *"JFK"*.

* Una vez que obtenemos los índices de fila, solo necesitamos dos columnas: `month` para agrupar y `dep_delay` para obtener `max()` para cada grupo. Por lo tanto, la optimización de consultas de *data.table* subconjunto solo aquellas dos columnas correspondientes a los *índices de fila* obtenidos en `i`, para mayor velocidad y eficiencia de memoria.

* Y en ese subconjunto, agrupamos por *mes* y calculamos `max(dep_delay)`.

* Usamos `keyby` para clasificar automáticamente ese resultado por *mes*. Ahora entendemos lo que eso significa. Además de ordenar, también establece *mes* como la columna `key`.

## 3. Argumentos adicionales: `mult` y `nomatch`

### a) El argumento *mult*

Podemos elegir, para cada consulta, si se deben devolver *"all"* las filas coincidentes, o solo *"first"* o *"last"* utilizando el argumento `mult`. El valor predeterminado es *"all"*, lo que hemos visto hasta ahora.

#### -- Subconjunto solo de la primera fila coincidente de todas las filas donde `origin` coincide con *"JFK"* y `dest` coincide con *"MIA"*


``` r
flights[.("JFK", "MIA"), mult = "first"]
# Key: <origin, dest>
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
# 1:  2014     1     1         6         3      AA    JFK    MIA      157     1089     5
```

#### -- Subconjunto solo de la última fila coincidente de todas las filas donde `origin` coincide con *"LGA", "JFK", "EWR"* y `dest` coincide con *"XNA"*


``` r
flights[.(c("LGA", "JFK", "EWR"), "XNA"), mult = "last"]
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
# 1:  2014     5    23       163       148      MQ    LGA    XNA      158     1147    18
# 2:    NA    NA    NA        NA        NA    <NA>    JFK    XNA       NA       NA    NA
# 3:  2014     2     3       231       268      EV    EWR    XNA      184     1131    12
```

* La consulta *"JFK", "XNA"* no coincide con ninguna fila en `vuelos` y, por lo tanto, devuelve `NA`.

* Una vez más, la consulta para la segunda columna de clave `dest`, *"XNA"*, se recicla para ajustarse a la longitud de la consulta para la primera columna de clave `origin`, que tiene una longitud 3.

### b) El argumento *nomatch*

Podemos elegir si las consultas que no coinciden deben devolver "NA" o ignorarse por completo utilizando el argumento "nomatch".

#### -- Del ejemplo anterior, crea un subconjunto de todas las filas solo si hay una coincidencia


``` r
flights[.(c("LGA", "JFK", "EWR"), "XNA"), mult = "last", nomatch = NULL]
#     year month   day dep_delay arr_delay carrier origin   dest air_time distance  hour
#    <int> <int> <int>     <int>     <int>  <char> <char> <char>    <int>    <int> <int>
# 1:  2014     5    23       163       148      MQ    LGA    XNA      158     1147    18
# 2:  2014     2     3       231       268      EV    EWR    XNA      184     1131    12
```

* El valor predeterminado para `nomatch` es `NA`. Si se establece `nomatch = NULL`, se omiten las consultas sin coincidencias.

* La consulta “JFK”, “XNA” no coincide con ninguna fila en los vuelos y, por lo tanto, se omite.

## 4. Búsqueda binaria vs escaneo vectorial

Hemos visto hasta ahora cómo podemos establecer y utilizar claves para crear subconjuntos. Pero, ¿cuál es la ventaja? Por ejemplo, en lugar de hacer:


``` r
# key by origin,dest columns
flights[.("JFK", "MIA")]
```

Podríamos haber hecho:


``` r
flights[origin == "JFK" & dest == "MIA"]
```

Una de las ventajas más probables es que la sintaxis es más corta. Pero, además, los *subconjuntos basados en búsqueda binaria* son **increíblemente rápidos**.

A medida que pasa el tiempo, `data.table` obtiene una nueva optimización y actualmente la última llamada se optimiza automáticamente para usar *búsqueda binaria*.\
Para usar un *escaneo vectorial* lento, se debe eliminar la clave.


``` r
setkey(flights, NULL)
flights[origin == "JFK" & dest == "MIA"]
```

### a) Rendimiento del enfoque de búsqueda binaria

Para ilustrarlo, creemos una tabla de datos de muestra con 20 millones de filas y tres columnas y clasifiquémosla por las columnas «x» e «y».


``` r
set.seed(2L)
N = 2e7L
DT = data.table(x = sample(letters, N, TRUE),
                y = sample(1000L, N, TRUE),
                val = runif(N))
print(object.size(DT), units = "Mb")
# 381.5 Mb
```

`DT` ocupa aproximadamente 380 MB. No es realmente una cantidad enorme, pero esto servirá para ilustrar el punto.

De lo que hemos visto en la sección Introducción a data.table, podemos crear subconjuntos de aquellas filas donde las columnas `x = "g"` e `y = 877` de la siguiente manera:


``` r
key(DT)
# NULL
## (1) Usual way of subsetting - vector scan approach
t1 <- system.time(ans1 <- DT[x == "g" & y == 877L])
t1
#    user  system elapsed 
#    0.29    0.30    0.74
head(ans1)
#         x     y        val
#    <char> <int>      <num>
# 1:      g   877 0.57059767
# 2:      g   877 0.74859806
# 3:      g   877 0.03616756
# 4:      g   877 0.28087868
# 5:      g   877 0.83727299
# 6:      g   877 0.43867189
dim(ans1)
# [1] 762   3
```

Ahora vamos a intentar crear subconjuntos mediante el uso de claves.


``` r
setkeyv(DT, c("x", "y"))
key(DT)
# [1] "x" "y"
## (2) Subsetting using keys
t2 <- system.time(ans2 <- DT[.("g", 877L)])
t2
#    user  system elapsed 
#       0       0       0
head(ans2)
# Key: <x, y>
#         x     y        val
#    <char> <int>      <num>
# 1:      g   877 0.57059767
# 2:      g   877 0.74859806
# 3:      g   877 0.03616756
# 4:      g   877 0.28087868
# 5:      g   877 0.83727299
# 6:      g   877 0.43867189
dim(ans2)
# [1] 762   3

identical(ans1$val, ans2$val)
# [1] TRUE
```

* La aceleración es **~740x**!

### b) ¿Por qué al introducir datos en una *tabla de datos* se obtienen subconjuntos increíblemente rápidos?

Para entender esto, veamos primero qué hace el *enfoque de escaneo vectorial* (método 1).

#### Enfoque de escaneo vectorial

* Se busca el valor *"g"* en la columna `x` fila por fila, en los 20 millones de filas. Esto da como resultado un *vector lógico* de tamaño 20 millones, con valores `TRUE, FALSE o NA` correspondientes al valor de `x`.

* De manera similar, se busca la columna `y` en busca de `877` en las 20 millones de filas una por una, y se almacena en otro vector lógico.

* Las operaciones `&` elemento por elemento se realizan en los vectores lógicos intermedios y se devuelven todas las filas donde la expresión se evalúa como `VERDADERO`.

Esto es lo que llamamos un "enfoque de escaneo vectorial", y es bastante ineficiente, especialmente en tablas más grandes y cuando se necesita crear subconjuntos repetidamente, porque se deben escanear todas las filas cada vez.

Ahora veamos el enfoque de búsqueda binaria (método 2). Recordemos de [Propiedades de la clave](#key-properties): *la configuración de claves reordena la tabla de datos por columnas de clave*. Dado que los datos están ordenados, no tenemos que *explorar toda la longitud de la columna*. En cambio, podemos utilizar la *búsqueda binaria* para buscar un valor en `O(log n)` en lugar de `O(n)` en el caso del *enfoque de exploración vectorial*, donde `n` es el número de filas en la *tabla de datos*.

#### Enfoque de búsqueda binaria

He aquí una ilustración muy sencilla. Consideremos los números (ordenados) que se muestran a continuación:

```
1, 5, 10, 19, 22, 23, 30
```

Supongamos que queremos encontrar la posición coincidente del valor *1*, usando la búsqueda binaria, así es como procederíamos, porque sabemos que los datos están *ordenados*.

* Comienza con el valor del medio = 19. ¿1 = 19? No. 1 < 19.

* Dado que el valor que buscamos es menor que 19, debería estar en algún lugar anterior a 19. Por lo tanto, podemos descartar el resto de la mitad que sea >= 19.

* Nuestro conjunto ahora se reduce a *1, 5, 10*. Tomamos el valor medio una vez más = 5. ¿1 == 5? No. 1 < 5.

* Nuestro conjunto se reduce a *1*. ¿1 == 1? Sí. El índice correspondiente también es 1. Y esa es la única coincidencia.

Por otro lado, un enfoque de escaneo vectorial tendría que escanear todos los valores (aquí, 7).

Se puede observar que con cada búsqueda reducimos el número de búsquedas a la mitad. Es por esto que los subconjuntos basados en *búsquedas binarias* son **increíblemente rápidos**. Dado que las filas de cada columna de *data.tables* tienen ubicaciones contiguas en la memoria, las operaciones se realizan de una manera muy eficiente en el uso de la memoria caché (lo que también contribuye a la *velocidad*).

Además, dado que obtenemos los índices de fila correspondientes directamente sin tener que crear esos enormes vectores lógicos (iguales al número de filas en una *data.table*), también es bastante **eficiente en términos de memoria**.

## Resumen

En esta viñeta, hemos aprendido otro método para crear subconjuntos de filas en `i` mediante la introducción de claves en una *data.table*. La introducción de claves nos permite realizar subconjuntos increíblemente rápidos mediante la *búsqueda binaria*. En particular, hemos visto cómo

* establecer clave y subconjunto usando la clave en una *tabla de datos*.

* subconjunto que utiliza claves que obtienen *índices de fila* en `i`, pero mucho más rápido.

* combinar subconjuntos basados en claves con `j` y `by`. Tenga en cuenta que las operaciones `j` y `by` son exactamente las mismas que antes.

Los subconjuntos basados en claves son **increíblemente rápidos** y son particularmente útiles cuando la tarea implica *subconjuntos repetidos*. Pero puede que no siempre sea deseable establecer la clave y reordenar físicamente la *tabla de datos*. En el siguiente artículo, abordaremos este tema utilizando una *nueva* característica: *índices secundarios*.




