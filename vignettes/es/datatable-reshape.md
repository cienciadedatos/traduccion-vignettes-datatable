---
title: "Efficient reshaping using data.tables"
date: "2024-10-07"
output:
  markdown::html_format
vignette: >
  %\VignetteIndexEntry{Efficient reshaping using data.tables}
  %\VignetteEngine{knitr::knitr}
  \usepackage[utf8]{inputenc}
---



Esta viñeta analiza el uso predeterminado de las funciones de remodelación `melt` (de ancho a largo) y `dcast` (de largo a ancho) para *data.tables*, así como las **nuevas funcionalidades extendidas** de fusión y conversión en *múltiples columnas* disponibles a partir de `v1.9.6`.

***



## Datos

Cargaremos los conjuntos de datos directamente dentro de las secciones.

## Introducción

Las funciones `melt` y `dcast` para `data.table`s sirven para cambiar la forma de ancho a largo y de largo a ancho, respectivamente; las implementaciones están diseñadas específicamente teniendo en mente grandes datos en memoria (por ejemplo, 10 Gb).

En esta viñeta, vamos a

1. Primero, observe brevemente la conversión predeterminada de ``melt`` y ``dcast`` de ``data.table`` para convertirlas de formato *ancho* a *largo* y _viceversa_

2. Analice los escenarios en los que las funcionalidades actuales se vuelven engorrosas e ineficientes

3. Por último, observe las nuevas mejoras en los métodos `melt` y `dcast` para que `data.table` pueda manejar múltiples columnas simultáneamente.

Las funcionalidades extendidas están en línea con la filosofía de `data.table` de realizar operaciones de manera eficiente y sencilla.

## 1. Funcionalidad predeterminada

### a) ``fusión`` de `data.table`` (de ancho a largo)

Supongamos que tenemos una `data.table` (datos artificiales) como se muestra a continuación:


``` r
s1 <- "family_id age_mother dob_child1 dob_child2 dob_child3
1         30 1998-11-26 2000-01-29         NA
2         27 1996-06-22         NA         NA
3         26 2002-07-11 2004-04-05 2007-09-02
4         32 2004-10-10 2009-08-27 2012-07-21
5         29 2000-12-05 2005-02-28         NA"
DT <- fread(s1)
DT
#    family_id age_mother dob_child1 dob_child2 dob_child3
#        <int>      <int>     <IDat>     <IDat>     <IDat>
# 1:         1         30 1998-11-26 2000-01-29       <NA>
# 2:         2         27 1996-06-22       <NA>       <NA>
# 3:         3         26 2002-07-11 2004-04-05 2007-09-02
# 4:         4         32 2004-10-10 2009-08-27 2012-07-21
# 5:         5         29 2000-12-05 2005-02-28       <NA>
## dob stands for date of birth.

str(DT)
# Classes 'data.table' and 'data.frame':	5 obs. of  5 variables:
#  $ family_id : int  1 2 3 4 5
#  $ age_mother: int  30 27 26 32 29
#  $ dob_child1: IDate, format: "1998-11-26" "1996-06-22" "2002-07-11" ...
#  $ dob_child2: IDate, format: "2000-01-29" NA "2004-04-05" ...
#  $ dob_child3: IDate, format: NA NA "2007-09-02" ...
#  - attr(*, ".internal.selfref")=<externalptr>
```


#### - Convertir 'DT' a formato *largo* donde cada 'dob' es una observación separada.

Podríamos lograr esto usando `melt()` especificando los argumentos `id.vars` y `measure.vars` de la siguiente manera:


``` r
DT.m1 = melt(DT, id.vars = c("family_id", "age_mother"),
                measure.vars = c("dob_child1", "dob_child2", "dob_child3"))
DT.m1
#     family_id age_mother   variable      value
#         <int>      <int>     <fctr>     <IDat>
#  1:         1         30 dob_child1 1998-11-26
#  2:         2         27 dob_child1 1996-06-22
#  3:         3         26 dob_child1 2002-07-11
#  4:         4         32 dob_child1 2004-10-10
#  5:         5         29 dob_child1 2000-12-05
#  6:         1         30 dob_child2 2000-01-29
#  7:         2         27 dob_child2       <NA>
#  8:         3         26 dob_child2 2004-04-05
#  9:         4         32 dob_child2 2009-08-27
# 10:         5         29 dob_child2 2005-02-28
# 11:         1         30 dob_child3       <NA>
# 12:         2         27 dob_child3       <NA>
# 13:         3         26 dob_child3 2007-09-02
# 14:         4         32 dob_child3 2012-07-21
# 15:         5         29 dob_child3       <NA>
str(DT.m1)
# Classes 'data.table' and 'data.frame':	15 obs. of  4 variables:
#  $ family_id : int  1 2 3 4 5 1 2 3 4 5 ...
#  $ age_mother: int  30 27 26 32 29 30 27 26 32 29 ...
#  $ variable  : Factor w/ 3 levels "dob_child1","dob_child2",..: 1 1 1 1 1 2 2 2 2 2 ...
#  $ value     : IDate, format: "1998-11-26" "1996-06-22" "2002-07-11" ...
#  - attr(*, ".internal.selfref")=<externalptr>
```

* `measure.vars` especifica el conjunto de columnas que nos gustaría contraer (o combinar) juntas.

* También podemos especificar *posiciones* de columnas en lugar de *nombres*.

* De manera predeterminada, la columna `variable` es del tipo `factor`. Establezca el argumento `variable.factor` en `FALSO` si desea devolver un vector de *`carácter`* en su lugar.

* De manera predeterminada, las columnas fundidas se denominan automáticamente `variable` y `valor`.

* `melt` conserva los atributos de la columna en el resultado.

#### - Nombra las columnas `variable` y `valor` como `hijo` y `dob` respectivamente



``` r
DT.m1 = melt(DT, measure.vars = c("dob_child1", "dob_child2", "dob_child3"),
               variable.name = "child", value.name = "dob")
DT.m1
#     family_id age_mother      child        dob
#         <int>      <int>     <fctr>     <IDat>
#  1:         1         30 dob_child1 1998-11-26
#  2:         2         27 dob_child1 1996-06-22
#  3:         3         26 dob_child1 2002-07-11
#  4:         4         32 dob_child1 2004-10-10
#  5:         5         29 dob_child1 2000-12-05
#  6:         1         30 dob_child2 2000-01-29
#  7:         2         27 dob_child2       <NA>
#  8:         3         26 dob_child2 2004-04-05
#  9:         4         32 dob_child2 2009-08-27
# 10:         5         29 dob_child2 2005-02-28
# 11:         1         30 dob_child3       <NA>
# 12:         2         27 dob_child3       <NA>
# 13:         3         26 dob_child3 2007-09-02
# 14:         4         32 dob_child3 2012-07-21
# 15:         5         29 dob_child3       <NA>
```

* De manera predeterminada, cuando falta una de las `id.vars` o `measure.vars`, el resto de las columnas se *asigna automáticamente* al argumento faltante.

* Cuando no se especifican ni `id.vars` ni `measure.vars`, como se menciona en `?melt`, todas las columnas *no* `numéricas`, `enteras`, `lógicas` se asignarán a `id.vars`.

    In addition, a warning message is issued highlighting the columns that are automatically considered to be `id.vars`.

### b) `dcast` de `data.table` (de largo a ancho)

En la sección anterior, vimos cómo pasar del formato ancho al formato largo. Veamos la operación inversa en esta sección.

#### - ¿Cómo podemos volver a la tabla de datos original `DT` desde `DT.m1`?

Es decir, nos gustaría recopilar todas las observaciones de *child* correspondientes a cada `family_id, age_mother` juntas en la misma fila. Podemos lograrlo usando `dcast` de la siguiente manera:


``` r
dcast(DT.m1, family_id + age_mother ~ child, value.var = "dob")
# Key: <family_id, age_mother>
#    family_id age_mother dob_child1 dob_child2 dob_child3
#        <int>      <int>     <IDat>     <IDat>     <IDat>
# 1:         1         30 1998-11-26 2000-01-29       <NA>
# 2:         2         27 1996-06-22       <NA>       <NA>
# 3:         3         26 2002-07-11 2004-04-05 2007-09-02
# 4:         4         32 2004-10-10 2009-08-27 2012-07-21
# 5:         5         29 2000-12-05 2005-02-28       <NA>
```

* `dcast` utiliza la interfaz *formula*. Las variables del *lado izquierdo* de la fórmula representan las variables *id* y del *lado derecho* las variables *measure*.

* `value.var` indica la columna que se debe completar al convertir a formato ancho.

* `dcast` también intenta preservar los atributos en el resultado siempre que sea posible.

#### - A partir de `DT.m1`, ¿cómo podemos obtener el número de hijos en cada familia?

También puede pasar una función para agregar en `dcast` con el argumento `fun.agregate`. Esto es particularmente esencial cuando la fórmula proporcionada no identifica una sola observación para cada celda.


``` r
dcast(DT.m1, family_id ~ ., fun.agg = function(x) sum(!is.na(x)), value.var = "dob")
# Key: <family_id>
#    family_id     .
#        <int> <int>
# 1:         1     2
# 2:         2     1
# 3:         3     3
# 4:         4     3
# 5:         5     2
```

Consulte `?dcast` para obtener otros argumentos útiles y ejemplos adicionales.

## 2. Limitaciones de los métodos actuales de «fusión/desintegración»

Hasta ahora hemos visto características de `melt` y `dcast` que se implementan de manera eficiente para `data.table`s, utilizando la maquinaria interna de `data.table` (*ordenamiento rápido de radix*, *búsqueda binaria*, etc.).

Sin embargo, existen situaciones en las que podemos encontrarnos con la operación deseada que no se expresa de manera sencilla. Por ejemplo, considere la tabla `data.table` que se muestra a continuación:


``` r
s2 <- "family_id age_mother dob_child1 dob_child2 dob_child3 gender_child1 gender_child2 gender_child3
1         30 1998-11-26 2000-01-29         NA             1             2            NA
2         27 1996-06-22         NA         NA             2            NA            NA
3         26 2002-07-11 2004-04-05 2007-09-02             2             2             1
4         32 2004-10-10 2009-08-27 2012-07-21             1             1             1
5         29 2000-12-05 2005-02-28         NA             2             1            NA"
DT <- fread(s2)
DT
#    family_id age_mother dob_child1 dob_child2 dob_child3 gender_child1 gender_child2 gender_child3
#        <int>      <int>     <IDat>     <IDat>     <IDat>         <int>         <int>         <int>
# 1:         1         30 1998-11-26 2000-01-29       <NA>             1             2            NA
# 2:         2         27 1996-06-22       <NA>       <NA>             2            NA            NA
# 3:         3         26 2002-07-11 2004-04-05 2007-09-02             2             2             1
# 4:         4         32 2004-10-10 2009-08-27 2012-07-21             1             1             1
# 5:         5         29 2000-12-05 2005-02-28       <NA>             2             1            NA
## 1 = female, 2 = male
```

Y desea combinar (`melt`) todas las columnas `dob` y `gender`. Con la funcionalidad actual, podemos hacer algo como esto:


``` r
DT.m1 = melt(DT, id = c("family_id", "age_mother"))
DT.m1[, c("variable", "child") := tstrsplit(variable, "_", fixed = TRUE)]
#     family_id age_mother variable      value  child
#         <int>      <int>   <char>     <IDat> <char>
#  1:         1         30      dob 1998-11-26 child1
#  2:         2         27      dob 1996-06-22 child1
#  3:         3         26      dob 2002-07-11 child1
#  4:         4         32      dob 2004-10-10 child1
#  5:         5         29      dob 2000-12-05 child1
#  6:         1         30      dob 2000-01-29 child2
#  7:         2         27      dob       <NA> child2
#  8:         3         26      dob 2004-04-05 child2
#  9:         4         32      dob 2009-08-27 child2
# 10:         5         29      dob 2005-02-28 child2
# 11:         1         30      dob       <NA> child3
# 12:         2         27      dob       <NA> child3
# 13:         3         26      dob 2007-09-02 child3
# 14:         4         32      dob 2012-07-21 child3
# 15:         5         29      dob       <NA> child3
# 16:         1         30   gender 1970-01-02 child1
# 17:         2         27   gender 1970-01-03 child1
# 18:         3         26   gender 1970-01-03 child1
# 19:         4         32   gender 1970-01-02 child1
# 20:         5         29   gender 1970-01-03 child1
# 21:         1         30   gender 1970-01-03 child2
# 22:         2         27   gender       <NA> child2
# 23:         3         26   gender 1970-01-03 child2
# 24:         4         32   gender 1970-01-02 child2
# 25:         5         29   gender 1970-01-02 child2
# 26:         1         30   gender       <NA> child3
# 27:         2         27   gender       <NA> child3
# 28:         3         26   gender 1970-01-02 child3
# 29:         4         32   gender 1970-01-02 child3
# 30:         5         29   gender       <NA> child3
#     family_id age_mother variable      value  child
DT.c1 = dcast(DT.m1, family_id + age_mother + child ~ variable, value.var = "value")
DT.c1
# Key: <family_id, age_mother, child>
#     family_id age_mother  child        dob     gender
#         <int>      <int> <char>     <IDat>     <IDat>
#  1:         1         30 child1 1998-11-26 1970-01-02
#  2:         1         30 child2 2000-01-29 1970-01-03
#  3:         1         30 child3       <NA>       <NA>
#  4:         2         27 child1 1996-06-22 1970-01-03
#  5:         2         27 child2       <NA>       <NA>
#  6:         2         27 child3       <NA>       <NA>
#  7:         3         26 child1 2002-07-11 1970-01-03
#  8:         3         26 child2 2004-04-05 1970-01-03
#  9:         3         26 child3 2007-09-02 1970-01-02
# 10:         4         32 child1 2004-10-10 1970-01-02
# 11:         4         32 child2 2009-08-27 1970-01-02
# 12:         4         32 child3 2012-07-21 1970-01-02
# 13:         5         29 child1 2000-12-05 1970-01-03
# 14:         5         29 child2 2005-02-28 1970-01-02
# 15:         5         29 child3       <NA>       <NA>

str(DT.c1) ## gender column is class IDate now!
# Classes 'data.table' and 'data.frame':	15 obs. of  5 variables:
#  $ family_id : int  1 1 1 2 2 2 3 3 3 4 ...
#  $ age_mother: int  30 30 30 27 27 27 26 26 26 32 ...
#  $ child     : chr  "child1" "child2" "child3" "child1" ...
#  $ dob       : IDate, format: "1998-11-26" "2000-01-29" NA ...
#  $ gender    : IDate, format: "1970-01-02" "1970-01-03" NA ...
#  - attr(*, ".internal.selfref")=<externalptr> 
#  - attr(*, "sorted")= chr [1:3] "family_id" "age_mother" "child"
```

#### Asuntos

1. Lo que queríamos hacer era combinar todas las columnas de tipo `dob` y `gender` respectivamente. En lugar de eso, estamos combinando *todo* y luego dividiendo todo. Creo que es fácil ver que es bastante indirecto (e ineficiente).

    As an analogy, imagine you've a closet with four shelves of clothes and you'd like to put together the clothes from shelves 1 and 2 together (in 1), and 3 and 4 together (in 3). What we are doing is more or less to combine all the clothes together, and then split them back on to shelves 1 and 3!

2. Las columnas que se van a `melt` pueden ser de tipos diferentes, como en este caso (tipos `character` y `integer`). Al `melt` todas juntas, las columnas se convertirán en el resultado, como se explica en el mensaje de advertencia anterior y se muestra en la salida de `str(DT.c1)`, donde `gender` se ha convertido al tipo *`character`*.

3. Estamos generando una columna adicional dividiendo la columna `variable` en dos columnas, cuyo propósito es bastante críptico. Lo hacemos porque lo necesitamos para la *conversión* en el siguiente paso.

4. Finalmente, convertimos el conjunto de datos. Pero el problema es que es una operación que requiere mucho más trabajo computacional que *melt*. En concreto, requiere calcular el orden de las variables en la fórmula, y eso es costoso.

De hecho, `stats::reshape` es capaz de realizar esta operación de una manera muy sencilla. Es una función extremadamente útil y a menudo subestimada. ¡Definitivamente deberías probarla!

## 3. Funcionalidad mejorada (nueva)

### a) Fusión mejorada

Como nos gustaría que `data.table` realice esta operación de manera sencilla y eficiente utilizando la misma interfaz, seguimos adelante e implementamos una *funcionalidad adicional*, donde podemos `fusionar` varias columnas *simultáneamente*.

#### - `fundir` múltiples columnas simultáneamente

La idea es bastante sencilla. Pasamos una lista de columnas a `measure.vars`, donde cada elemento de la lista contiene las columnas que deben combinarse.


``` r
colA = paste0("dob_child", 1:3)
colB = paste0("gender_child", 1:3)
DT.m2 = melt(DT, measure = list(colA, colB), value.name = c("dob", "gender"))
DT.m2
#     family_id age_mother variable        dob gender
#         <int>      <int>   <fctr>     <IDat>  <int>
#  1:         1         30        1 1998-11-26      1
#  2:         2         27        1 1996-06-22      2
#  3:         3         26        1 2002-07-11      2
#  4:         4         32        1 2004-10-10      1
#  5:         5         29        1 2000-12-05      2
#  6:         1         30        2 2000-01-29      2
#  7:         2         27        2       <NA>     NA
#  8:         3         26        2 2004-04-05      2
#  9:         4         32        2 2009-08-27      1
# 10:         5         29        2 2005-02-28      1
# 11:         1         30        3       <NA>     NA
# 12:         2         27        3       <NA>     NA
# 13:         3         26        3 2007-09-02      1
# 14:         4         32        3 2012-07-21      1
# 15:         5         29        3       <NA>     NA

str(DT.m2) ## col type is preserved
# Classes 'data.table' and 'data.frame':	15 obs. of  5 variables:
#  $ family_id : int  1 2 3 4 5 1 2 3 4 5 ...
#  $ age_mother: int  30 27 26 32 29 30 27 26 32 29 ...
#  $ variable  : Factor w/ 3 levels "1","2","3": 1 1 1 1 1 2 2 2 2 2 ...
#  $ dob       : IDate, format: "1998-11-26" "1996-06-22" "2002-07-11" ...
#  $ gender    : int  1 2 2 1 2 2 NA 2 1 1 ...
#  - attr(*, ".internal.selfref")=<externalptr>
```

* Podemos eliminar la columna `variable` si es necesario.

* La funcionalidad está implementada completamente en C y, por lo tanto, es *rápida* y *eficiente en el uso de la memoria*, además de ser *sencilla*.

#### - Usando `patrones()`

Por lo general, en estos problemas, las columnas que queremos fundir se pueden distinguir por un patrón común. Podemos utilizar la función `patterns()`, implementada por conveniencia, para proporcionar expresiones regulares para las columnas que se combinarán. La operación anterior se puede reescribir como:


``` r
DT.m2 = melt(DT, measure = patterns("^dob", "^gender"), value.name = c("dob", "gender"))
DT.m2
#     family_id age_mother variable        dob gender
#         <int>      <int>   <fctr>     <IDat>  <int>
#  1:         1         30        1 1998-11-26      1
#  2:         2         27        1 1996-06-22      2
#  3:         3         26        1 2002-07-11      2
#  4:         4         32        1 2004-10-10      1
#  5:         5         29        1 2000-12-05      2
#  6:         1         30        2 2000-01-29      2
#  7:         2         27        2       <NA>     NA
#  8:         3         26        2 2004-04-05      2
#  9:         4         32        2 2009-08-27      1
# 10:         5         29        2 2005-02-28      1
# 11:         1         30        3       <NA>     NA
# 12:         2         27        3       <NA>     NA
# 13:         3         26        3 2007-09-02      1
# 14:         4         32        3 2012-07-21      1
# 15:         5         29        3       <NA>     NA
```

#### - Usar `measure()` para especificar `measure.vars` a través de un separador o patrón

Si, como en los datos anteriores, las columnas de entrada que se van a fundir tienen nombres regulares, entonces podemos usar `measure`, que permite especificar las columnas que se van a fundir mediante un separador o una expresión regular. Por ejemplo, considere los datos del iris:


``` r
(two.iris = data.table(datasets::iris)[c(1,150)])
#    Sepal.Length Sepal.Width Petal.Length Petal.Width   Species
#           <num>       <num>        <num>       <num>    <fctr>
# 1:          5.1         3.5          1.4         0.2    setosa
# 2:          5.9         3.0          5.1         1.8 virginica
```

Los datos del iris tienen cuatro columnas numéricas con una estructura regular: primero la parte de la flor, luego un punto y luego la dimensión de la medida. Para especificar que queremos fusionar esas cuatro columnas, podemos usar `measure` con `sep="."`, lo que significa usar `strsplit` en todos los nombres de columna; las columnas que resulten en la cantidad máxima de grupos después de la división se usarán como `measure.vars`:


``` r
melt(two.iris, measure.vars = measure(part, dim, sep="."))
#      Species   part    dim value
#       <fctr> <char> <char> <num>
# 1:    setosa  Sepal Length   5.1
# 2: virginica  Sepal Length   5.9
# 3:    setosa  Sepal  Width   3.5
# 4: virginica  Sepal  Width   3.0
# 5:    setosa  Petal Length   1.4
# 6: virginica  Petal Length   5.1
# 7:    setosa  Petal  Width   0.2
# 8: virginica  Petal  Width   1.8
```

Los primeros dos argumentos de `measure` en el código anterior (`part` y `dim`) se utilizan para nombrar las columnas de salida; la cantidad de argumentos debe ser igual a la cantidad máxima de grupos después de dividir con `sep`.

Si queremos dos columnas de valores, una para cada parte, podemos usar la palabra clave especial `value.name`, lo que significa generar una columna de valores para cada nombre único encontrado en ese grupo:


``` r
melt(two.iris, measure.vars = measure(value.name, dim, sep="."))
#      Species    dim Sepal Petal
#       <fctr> <char> <num> <num>
# 1:    setosa Length   5.1   1.4
# 2: virginica Length   5.9   5.1
# 3:    setosa  Width   3.5   0.2
# 4: virginica  Width   3.0   1.8
```

Con el código anterior obtenemos una columna de valores por cada parte de la flor. Si, en cambio, queremos una columna de valores para cada dimensión de medida, podemos hacer lo siguiente:


``` r
melt(two.iris, measure.vars = measure(part, value.name, sep="."))
#      Species   part Length Width
#       <fctr> <char>  <num> <num>
# 1:    setosa  Sepal    5.1   3.5
# 2: virginica  Sepal    5.9   3.0
# 3:    setosa  Petal    1.4   0.2
# 4: virginica  Petal    5.1   1.8
```

Volviendo al ejemplo de los datos con familias e hijos, podemos ver un uso más complejo de `measure`, que involucra una función que se utiliza para convertir los valores de la cadena `child` en números enteros:


``` r
DT.m3 = melt(DT, measure = measure(value.name, child=as.integer, sep="_child"))
DT.m3
#     family_id age_mother child        dob gender
#         <int>      <int> <int>     <IDat>  <int>
#  1:         1         30     1 1998-11-26      1
#  2:         2         27     1 1996-06-22      2
#  3:         3         26     1 2002-07-11      2
#  4:         4         32     1 2004-10-10      1
#  5:         5         29     1 2000-12-05      2
#  6:         1         30     2 2000-01-29      2
#  7:         2         27     2       <NA>     NA
#  8:         3         26     2 2004-04-05      2
#  9:         4         32     2 2009-08-27      1
# 10:         5         29     2 2005-02-28      1
# 11:         1         30     3       <NA>     NA
# 12:         2         27     3       <NA>     NA
# 13:         3         26     3 2007-09-02      1
# 14:         4         32     3 2012-07-21      1
# 15:         5         29     3       <NA>     NA
```

En el código anterior, usamos `sep="_child"`, lo que da como resultado la fusión de solo las columnas que contienen esa cadena (seis nombres de columnas divididos en dos grupos cada uno). El argumento `child=as.integer` significa que el segundo grupo dará como resultado una columna de salida llamada `child` con valores definidos al insertar las cadenas de caracteres de ese grupo en la función `as.integer`.

Finalmente, consideramos un ejemplo (tomado del paquete tidyr) donde necesitamos definir los grupos usando una expresión regular en lugar de un separador.


``` r
(who <- data.table(id=1, new_sp_m5564=2, newrel_f65=3))
#       id new_sp_m5564 newrel_f65
#    <num>        <num>      <num>
# 1:     1            2          3
melt(who, measure.vars = measure(
  diagnosis, gender, ages, pattern="new_?(.*)_(.)(.*)"))
#       id diagnosis gender   ages value
#    <num>    <char> <char> <char> <num>
# 1:     1        sp      m   5564     2
# 2:     1       rel      f     65     3
```

Al utilizar el argumento `patrón`, debe ser una expresión regular compatible con Perl que contenga la misma cantidad de grupos de captura (subexpresiones entre paréntesis) que la cantidad de otros argumentos (nombres de grupos). El código siguiente muestra cómo utilizar una expresión regular más compleja con cinco grupos, dos columnas de salida numérica y una función de conversión de tipo anónima.


``` r
melt(who, measure.vars = measure(
  diagnosis, gender, ages,
  ymin=as.numeric,
  ymax=function(y) ifelse(nzchar(y), as.numeric(y), Inf),
  pattern="new_?(.*)_(.)(([0-9]{2})([0-9]{0,2}))"
))
#       id diagnosis gender   ages  ymin  ymax value
#    <num>    <char> <char> <char> <num> <num> <num>
# 1:     1        sp      m   5564    55    64     2
# 2:     1       rel      f     65    65   Inf     3
```

### b) `dcast` mejorado

¡Genial! Ahora podemos fusionar varias columnas simultáneamente. Ahora, dado el conjunto de datos `DT.m2` como se muestra arriba, ¿cómo podemos volver al mismo formato que los datos originales con los que comenzamos?

Si usamos la funcionalidad actual de `dcast`, entonces tendríamos que realizar la conversión dos veces y vincular los resultados. Pero eso es, una vez más, demasiado verboso, no es sencillo y también es ineficiente.

#### - Conversión de múltiples `value.var` simultáneamente

Ahora podemos proporcionar **múltiples columnas `value.var`** a `dcast` para `data.table` directamente para que las operaciones se realicen de manera interna y eficiente.


``` r
## new 'cast' functionality - multiple value.vars
DT.c2 = dcast(DT.m2, family_id + age_mother ~ variable, value.var = c("dob", "gender"))
DT.c2
# Key: <family_id, age_mother>
#    family_id age_mother      dob_1      dob_2      dob_3 gender_1 gender_2 gender_3
#        <int>      <int>     <IDat>     <IDat>     <IDat>    <int>    <int>    <int>
# 1:         1         30 1998-11-26 2000-01-29       <NA>        1        2       NA
# 2:         2         27 1996-06-22       <NA>       <NA>        2       NA       NA
# 3:         3         26 2002-07-11 2004-04-05 2007-09-02        2        2        1
# 4:         4         32 2004-10-10 2009-08-27 2012-07-21        1        1        1
# 5:         5         29 2000-12-05 2005-02-28       <NA>        2        1       NA
```

* Los atributos se conservan en el resultado siempre que sea posible.

* Todo se gestiona internamente y de manera eficiente. Además de ser rápido, también es muy eficiente en el uso de la memoria.

#

#### Varias funciones para `fun.agregate`:

También puede proporcionar *múltiples funciones* a `fun.agregate` para `dcast` para *data.tables*. Consulte los ejemplos en `?dcast` que ilustran esta funcionalidad.



#

***

