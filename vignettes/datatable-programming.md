---
title: "Programming on data.table"
date: "2024-10-04"
output:
  markdown::html_format
vignette: >
  %\VignetteIndexEntry{Programming on data.table}
  %\VignetteEngine{knitr::knitr}
  \usepackage[utf8]{inputenc}
---




## Introducción

`data.table`, desde sus primeras versiones, habilitó el uso de las funciones `subset` y `with` (o `within`) al definir el método `[.data.table`. `subset` y `with` son funciones básicas de R que son útiles para reducir la repetición en el código, mejorar la legibilidad y reducir la cantidad total de caracteres que el usuario debe escribir. Esta funcionalidad es posible en R debido a una característica bastante única llamada *evaluación diferida*. Esta característica permite que una función capte sus argumentos, antes de que se evalúen, y los evalúe en un ámbito diferente de aquel en el que fueron llamados. Recapitulemos el uso de la función `subset`.




``` r
subset(iris, Species == "setosa")
#   Sepal.Length Sepal.Width Petal.Length Petal.Width Species
# 1          5.1         3.5          1.4         0.2  setosa
# 2          4.9         3.0          1.4         0.2  setosa
# ...
```

Aquí, `subset` toma el segundo argumento y lo evalúa dentro del alcance del `data.frame` dado como su primer argumento. Esto elimina la necesidad de repetir variables, lo que lo hace menos propenso a errores y hace que el código sea más legible.

## Descripción del problema

El problema con este tipo de interfaz es que no podemos parametrizar fácilmente el código que la utiliza, ya que las expresiones que se pasan a esas funciones se sustituyen antes de ser evaluadas.

### Ejemplo


``` r
my_subset = function(data, col, val) {
  subset(data, col == val)
}
my_subset(iris, Species, "setosa")
# Error: objeto 'Species' no encontrado
```

### Aproximaciones al problema

Hay varias formas de solucionar este problema.

#### Evite la *evaluación perezosa*

La solución más sencilla es evitar la *evaluación perezosa* en primer lugar y recurrir a enfoques menos intuitivos y más propensos a errores, como `df[["variable"]]`, etc.


``` r
my_subset = function(data, col, val) {
  data[data[[col]] == val & !is.na(data[[col]]), ]
}
my_subset(iris, col = "Species", val = "setosa")
#   Sepal.Length Sepal.Width Petal.Length Petal.Width Species
# 1          5.1         3.5          1.4         0.2  setosa
# 2          4.9         3.0          1.4         0.2  setosa
# ...
```

Aquí, calculamos un vector lógico de longitud `nrow(iris)`, luego este vector se suministra al argumento `i` de `[.data.frame` para realizar un subconjunto ordinario basado en "vectores lógicos". Para alinearlo con `subset()`, que también descarta NA, necesitamos incluir un uso adicional de `data[[col]]` para capturarlo. Funciona bastante bien para este ejemplo simple, pero carece de flexibilidad, introduce repetición de variables y requiere que el usuario cambie la interfaz de la función para pasar el nombre de la columna como un carácter en lugar de un símbolo sin comillas. Cuanto más compleja sea la expresión que necesitamos parametrizar, menos práctico se vuelve este enfoque.

#### Uso de `parse` / `eval`

Este método suele ser el preferido por los principiantes en R, ya que es, quizás, el más sencillo desde el punto de vista conceptual. Esta forma requiere generar la expresión requerida mediante concatenación de cadenas, analizarla y, luego, evaluarla.


``` r
my_subset = function(data, col, val) {
  data = deparse(substitute(data))
  col  = deparse(substitute(col))
  val  = paste0("'", val, "'")
  text = paste0("subset(", data, ", ", col, " == ", val, ")")
  eval(parse(text = text)[[1L]])
}
my_subset(iris, Species, "setosa")
#   Sepal.Length Sepal.Width Petal.Length Petal.Width Species
# 1          5.1         3.5          1.4         0.2  setosa
# 2          4.9         3.0          1.4         0.2  setosa
# ...
```

Tenemos que usar `deparse(substitute(...))` para capturar los nombres reales de los objetos pasados a la función, de modo que podamos construir la llamada a la función `subset` usando esos nombres originales. Aunque esto proporciona una flexibilidad ilimitada con una complejidad relativamente baja, **se debe evitar el uso de `eval(parse(...))`**. Las principales razones son:

- falta de validación de sintaxis
- [vulnerabilidad a la inyección de código](https://github.com/Rdatatable/data.table/issues/2655#issuecomment-376781159)
- la existencia de mejores alternativas

Martin Machler, desarrollador principal del proyecto R, [dijo una vez](https://stackoverflow.com/a/40164111/2490497):

> Lo siento, pero no entiendo por qué tanta gente piensa que una cadena es algo que se puede evaluar. Debes cambiar tu mentalidad, de verdad. Olvídate de todas las conexiones entre cadenas de un lado y expresiones, llamadas y evaluaciones del otro. La (posiblemente) única conexión es a través de `parse(text = ....)` y todos los buenos programadores de R deberían saber que esto rara vez es un medio eficiente o seguro para construir expresiones (o llamadas). En lugar de eso, aprende más sobre `substitute()`, `quote()` y posiblemente el poder de usar `do.call(substitute, ......)`.

#### Computación sobre el lenguaje

Las funciones mencionadas anteriormente, junto con algunas otras (incluidas `as.call`, `as.name`/`as.symbol`, `bquote` y `eval`), se pueden categorizar como funciones para *computar en el lenguaje*, ya que operan en objetos _del lenguaje_ (por ejemplo, `call`, `name`/`symbol`).


``` r
my_subset = function(data, col, val) {
  eval(substitute(subset(data, col == val)))
}
my_subset(iris, Species, "setosa")
#   Sepal.Length Sepal.Width Petal.Length Petal.Width Species
# 1          5.1         3.5          1.4         0.2  setosa
# 2          4.9         3.0          1.4         0.2  setosa
# ...
```

Aquí, usamos la función base R `substitute` para transformar la llamada `subset(data, col == val)` en `subset(iris, Species == "setosa")` sustituyendo `data`, `col` y `val` con sus nombres originales (o valores) de su entorno padre. Los beneficios de este enfoque con respecto a los anteriores deberían ser claros. Tenga en cuenta que, debido a que operamos en el nivel de objetos del lenguaje y no tenemos que recurrir a la manipulación de cadenas, nos referimos a esto como *computación en el lenguaje*. Hay un capítulo dedicado a *Computación en el lenguaje* en [Manual del lenguaje R](https://cran.r-project.org/doc/manuals/r-release/R-lang.html). Aunque no es necesario para *programar en data.table*, alentamos a los lectores a leer este capítulo para comprender mejor esta característica poderosa y única del lenguaje R.

#### Utilice paquetes de terceros

Hay paquetes de terceros que pueden lograr lo que hace la computación R basada en las rutinas del lenguaje (`pryr`, `lazyeval` y `rlang`, por nombrar algunos).

Si bien esto puede ser útil, aquí analizaremos un enfoque exclusivo de `data.table`.

## Programación en data.table

Ahora que hemos establecido la forma correcta de parametrizar el código que utiliza *evaluación perezosa*, podemos pasar al tema principal de esta viñeta, *programación en data.table*.

A partir de la versión 1.15.0, data.table proporciona un mecanismo robusto para parametrizar expresiones pasadas a los argumentos `i`, `j` y `by` (o `keyby`) de `[.data.table`. Está construido sobre la función `substitute` de R base e imita su interfaz. Aquí, presentamos `substitute2` como una versión más robusta y más fácil de usar de `substitute` de R base. Para obtener una lista completa de las diferencias entre `base::substitute` y `data.table::substitute2`, lea el [manual de `substitute2`](https://rdatatable.gitlab.io/data.table/library/data.table/html/substitute2.html).

### Sustituir variables y nombres

Digamos que queremos tener una función general que aplique una función a la suma de dos argumentos a los que se les ha aplicado otra función. Como ejemplo concreto, a continuación tenemos una función para calcular la longitud de la hipotenusa en un triángulo rectángulo, conociendo la longitud de sus catetos.

${\displaystyle c = \sqrt{a^2 + b^2}}$


``` r
square = function(x) x^2
quote(
  sqrt(square(a) + square(b))
)
# sqrt(square(a) + square(b))
```

El objetivo es hacer que cada nombre en la llamada anterior pueda pasarse como parámetro.


``` r
substitute2(
  outer(inner(var1) + inner(var2)),
  env = list(
    outer = "sqrt",
    inner = "square",
    var1 = "a",
    var2 = "b"
  )
)
# sqrt(square(a) + square(b))
```

Podemos ver en la salida que se han reemplazado tanto los nombres de las funciones como los nombres de las variables pasadas a esas funciones. Usamos `substitute2` por conveniencia. En este caso simple, también se podría haber usado `substitute` de R base, aunque hubiera requerido el uso de `lapply(env, as.name)`.

Ahora, para usar la sustitución dentro de `[.data.table`, no necesitamos llamar a la función `substitute2`. Como ahora se está usando internamente, todo lo que tenemos que hacer es proporcionar el argumento `env`, de la misma manera que lo hemos proporcionado a la función `substitute2` en el ejemplo anterior. La sustitución se puede aplicar a los argumentos `i`, `j` y `by` (o `keyby`) del método `[.data.table`. Tenga en cuenta que configurar el argumento `verbose` en `TRUE` se puede utilizar para imprimir expresiones después de que se aplique la sustitución. Esto es muy útil para la depuración.

Utilicemos el conjunto de datos `iris` como demostración. Solo como ejemplo, supongamos que queremos calcular `Sepal.Hypotenuse`, tratando el ancho y la longitud del sépalo como si fueran los catetos de un triángulo rectángulo.


``` r
DT = as.data.table(iris)

str(
  DT[, outer(inner(var1) + inner(var2)),
     env = list(
       outer = "sqrt",
       inner = "square",
       var1 = "Sepal.Length",
       var2 = "Sepal.Width"
    )]
)
#  num [1:150] 6.19 5.75 5.69 5.55 6.16 ...

# return as a data.table
DT[, .(Species, var1, var2, out = outer(inner(var1) + inner(var2))),
   env = list(
     outer = "sqrt",
     inner = "square",
     var1 = "Sepal.Length",
     var2 = "Sepal.Width",
     out = "Sepal.Hypotenuse"
  )]
#        Species Sepal.Length Sepal.Width Sepal.Hypotenuse
#         <fctr>        <num>       <num>            <num>
#   1:    setosa          5.1         3.5         6.185467
#   2:    setosa          4.9         3.0         5.745433
#  ---                                                    
# 149: virginica          6.2         3.4         7.071068
# 150: virginica          5.9         3.0         6.618912
```

En la última llamada, agregamos otro parámetro, `out = "Sepal.Hypotenuse"`, que transmite el nombre deseado de la columna de salida. A diferencia del `substitute` de la base R, `substitute2` también se encargará de la sustitución de los nombres de los argumentos de la llamada.

La sustitución también funciona en `i` y `by` (o `keyby`).


``` r
DT[filter_col %in% filter_val,
   .(var1, var2, out = outer(inner(var1) + inner(var2))),
   by = by_col,
   env = list(
     outer = "sqrt",
     inner = "square",
     var1 = "Sepal.Length",
     var2 = "Sepal.Width",
     out = "Sepal.Hypotenuse",
     filter_col = "Species",
     filter_val = I(c("versicolor", "virginica")),
     by_col =  "Species"
  )]
#         Species Sepal.Length Sepal.Width Sepal.Hypotenuse
#          <fctr>        <num>       <num>            <num>
#   1: versicolor          7.0         3.2         7.696753
#   2: versicolor          6.4         3.2         7.155418
#  ---                                                     
#  99:  virginica          6.2         3.4         7.071068
# 100:  virginica          5.9         3.0         6.618912
```

### Sustituir variables y valores de caracteres

En el ejemplo anterior, hemos visto una característica conveniente de `substitute2`: conversión automática de cadenas en nombres/símbolos. Surge una pregunta obvia: ¿qué pasa si realmente queremos sustituir un parámetro con un valor de *carácter*, de modo de tener un comportamiento `substitute` de R base? Proporcionamos un mecanismo para escapar de la conversión automática envolviendo los elementos en la llamada `I()` de R base. La función `I` marca un objeto como *AsIs*, evitando que sus argumentos se conviertan automáticamente de carácter a símbolo. (Lea la documentación de `?AsIs` para obtener más detalles). Si se desea un comportamiento de R base para todo el argumento `env`, entonces es mejor envolver todo el argumento en `I()`. Alternativamente, cada elemento de la lista se puede envolver en `I()` individualmente. Exploremos ambos casos a continuación.


``` r
substitute(    # base R behaviour
  rank(input, ties.method = ties),
  env = list(input = as.name("Sepal.Width"), ties = "first")
)
# rank(Sepal.Width, ties.method = "first")

substitute2(   # mimicking base R's "substitute" using "I"
  rank(input, ties.method = ties),
  env = I(list(input = as.name("Sepal.Width"), ties = "first"))
)
# rank(Sepal.Width, ties.method = "first")

substitute2(   # only particular elements of env are used "AsIs"
  rank(input, ties.method = ties),
  env = list(input = "Sepal.Width", ties = I("first"))
)
# rank(Sepal.Width, ties.method = "first")
```

Tenga en cuenta que la conversión funciona de forma recursiva en cada elemento de la lista, incluido el mecanismo de escape, por supuesto.


``` r
substitute2(   # all are symbols
  f(v1, v2),
  list(v1 = "a", v2 = list("b", list("c", "d")))
)
# f(a, list(b, list(c, d)))
substitute2(   # 'a' and 'd' should stay as character
  f(v1, v2),
  list(v1 = I("a"), v2 = list("b", list("c", I("d"))))
)
# f("a", list(b, list(c, "d")))
```

### Sustitución de listas de longitud arbitraria

El ejemplo presentado anteriormente ilustra una forma elegante y poderosa de hacer que su código sea más dinámico. Sin embargo, existen muchos otros casos mucho más complejos con los que un desarrollador podría tener que lidiar. Un problema común es manejar una lista de argumentos de longitud arbitraria.

Un caso de uso obvio podría ser imitar la funcionalidad de `.SD` inyectando una llamada `list` en el argumento `j`.


``` r
cols = c("Sepal.Length", "Sepal.Width")
DT[, .SD, .SDcols = cols]
#      Sepal.Length Sepal.Width
#             <num>       <num>
#   1:          5.1         3.5
#   2:          4.9         3.0
#  ---                         
# 149:          6.2         3.4
# 150:          5.9         3.0
```

Teniendo el parámetro `cols`, nos gustaría unirlo en una llamada `list`, haciendo que el argumento `j` se vea como en el código a continuación.


``` r
DT[, list(Sepal.Length, Sepal.Width)]
#      Sepal.Length Sepal.Width
#             <num>       <num>
#   1:          5.1         3.5
#   2:          4.9         3.0
#  ---                         
# 149:          6.2         3.4
# 150:          5.9         3.0
```

*Empalmar* es una operación en la que una lista de objetos se debe incluir en una expresión como una secuencia de argumentos para llamar. En el lenguaje R básico, empalmar `cols` en una `lista` se puede lograr usando `as.call(c(quote(list), lapply(cols, as.name)))`. Además, a partir de R 4.0.0, hay una nueva interfaz para dicha operación en la función `bquote`.

En data.table, lo hacemos más fácil al incluir automáticamente una lista de objetos en una llamada de lista con esos objetos. Esto significa que cualquier objeto `list` dentro del argumento de lista `env` se convertirá en una `call` de lista, lo que hace que la API para ese caso de uso sea tan simple como se presenta a continuación.


``` r
# this works
DT[, j,
   env = list(j = as.list(cols)),
   verbose = TRUE]
# Argument 'j' after substitute: list(Sepal.Length, Sepal.Width)
# Detected that j uses these columns: [Sepal.Length, Sepal.Width]
#      Sepal.Length Sepal.Width
#             <num>       <num>
#   1:          5.1         3.5
#   2:          4.9         3.0
#  ---                         
# 149:          6.2         3.4
# 150:          5.9         3.0

# this will not work
#DT[, list(cols),
#   env = list(cols = cols)]
```

Es importante proporcionar una llamada a `as.list`, en lugar de simplemente una lista, dentro del argumento de lista `env`, como se muestra en el ejemplo anterior.

Exploremos el _alistamiento_ con más detalle.


``` r
DT[, j,  # data.table automatically enlists nested lists into list calls
   env = list(j = as.list(cols)),
   verbose = TRUE]
# Argument 'j' after substitute: list(Sepal.Length, Sepal.Width)
# Detected that j uses these columns: [Sepal.Length, Sepal.Width]
#      Sepal.Length Sepal.Width
#             <num>       <num>
#   1:          5.1         3.5
#   2:          4.9         3.0
#  ---                         
# 149:          6.2         3.4
# 150:          5.9         3.0

DT[, j,  # turning the above 'j' list into a list call
   env = list(j = quote(list(Sepal.Length, Sepal.Width))),
   verbose = TRUE]
# Argument 'j' after substitute: list(Sepal.Length, Sepal.Width)
# Detected that j uses these columns: [Sepal.Length, Sepal.Width]
#      Sepal.Length Sepal.Width
#             <num>       <num>
#   1:          5.1         3.5
#   2:          4.9         3.0
#  ---                         
# 149:          6.2         3.4
# 150:          5.9         3.0

DT[, j,  # the same as above but accepts character vector
   env = list(j = as.call(c(quote(list), lapply(cols, as.name)))),
   verbose = TRUE]
# Argument 'j' after substitute: list(Sepal.Length, Sepal.Width)
# Detected that j uses these columns: [Sepal.Length, Sepal.Width]
#      Sepal.Length Sepal.Width
#             <num>       <num>
#   1:          5.1         3.5
#   2:          4.9         3.0
#  ---                         
# 149:          6.2         3.4
# 150:          5.9         3.0
```

Ahora, en lugar de llamar a esos símbolos a través de una lista, intentaremos pasar una lista de símbolos. Usaremos `I()` para evitar la conversión automática de _enlist_ pero, como esto también desactivará la conversión de caracteres a símbolos, también tenemos que usar `as.name`.


``` r
DT[, j,  # list of symbols
   env = I(list(j = lapply(cols, as.name))),
   verbose = TRUE]
# Argument 'j' after substitute: list(Sepal.Length, Sepal.Width)
# Error in `[.data.table`(DT, , j, env = I(list(j = lapply(cols, as.name))), : Cuando with=FALSE, el argumento j debe ser de tipo lógico/carácter/entero indicando las columnas a seleccionar.

DT[, j,  # again the proper way, enlist list to list call automatically
   env = list(j = as.list(cols)),
   verbose = TRUE]
# Argument 'j' after substitute: list(Sepal.Length, Sepal.Width)
# Detected that j uses these columns: [Sepal.Length, Sepal.Width]
#      Sepal.Length Sepal.Width
#             <num>       <num>
#   1:          5.1         3.5
#   2:          4.9         3.0
#  ---                         
# 149:          6.2         3.4
# 150:          5.9         3.0
```

Tenga en cuenta que ambas expresiones, aunque visualmente parecen iguales, no son idénticas.


``` r
str(substitute2(j, env = I(list(j = lapply(cols, as.name)))))
# List of 2
#  $ : symbol Sepal.Length
#  $ : symbol Sepal.Width

str(substitute2(j, env = list(j = as.list(cols))))
#  language list(Sepal.Length, Sepal.Width)
```

Para obtener una explicación más detallada sobre este asunto, consulte los ejemplos en la [documentación de`substitute2`](https://rdatatable.gitlab.io/data.table/library/data.table/html/substitute2.html).

### Sustitución de una consulta compleja

Tomemos como ejemplo de una función más compleja el cálculo del valor cuadrático medio.

${\displaystyle x_{\text{RMS}}={\sqrt{{\frac{1}{n}}\left(x_{1}^{2}+x_{2}^{2}+\cdots +x_{n}^{2}\right)}}}$

Toma una cantidad arbitraria de variables en la entrada, pero ahora no podemos simplemente *unir* una lista de argumentos en una llamada de lista porque cada uno de esos argumentos tiene que estar envuelto en una llamada `cuadrada`. En este caso, tenemos que *unir* a mano en lugar de confiar en el _enlist_ automático de data.table.

Primero, tenemos que construir llamadas a la función `square` para cada una de las variables (ver `inner_calls`). Luego, tenemos que reducir la lista de llamadas a una sola llamada, que tenga una secuencia anidada de llamadas `+` (ver `add_calls`). Por último, tenemos que sustituir la llamada construida en la expresión circundante (ver `rms`).


``` r
outer = "sqrt"
inner = "square"
vars = c("Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width")

syms = lapply(vars, as.name)
to_inner_call = function(var, fun) call(fun, var)
inner_calls = lapply(syms, to_inner_call, inner)
print(inner_calls)
# [[1]]
# square(Sepal.Length)
# 
# [[2]]
# square(Sepal.Width)
# 
# [[3]]
# square(Petal.Length)
# 
# [[4]]
# square(Petal.Width)

to_add_call = function(x, y) call("+", x, y)
add_calls = Reduce(to_add_call, inner_calls)
print(add_calls)
# square(Sepal.Length) + square(Sepal.Width) + square(Petal.Length) + 
#     square(Petal.Width)

rms = substitute2(
  expr = outer((add_calls) / len),
  env = list(
    outer = outer,
    add_calls = add_calls,
    len = length(vars)
  )
)
print(rms)
# sqrt((square(Sepal.Length) + square(Sepal.Width) + square(Petal.Length) + 
#     square(Petal.Width))/4L)

str(
  DT[, j, env = list(j = rms)]
)
#  num [1:150] 3.17 2.96 2.92 2.87 3.16 ...

# same, but skipping last substitute2 call and using add_calls directly
str(
  DT[, outer((add_calls) / len),
     env = list(
       outer = outer,
       add_calls = add_calls,
       len = length(vars)
    )]
)
#  num [1:150] 3.17 2.96 2.92 2.87 3.16 ...

# return as data.table
j = substitute2(j, list(j = as.list(setNames(nm = c(vars, "Species", "rms")))))
j[["rms"]] = rms
print(j)
# list(Sepal.Length = Sepal.Length, Sepal.Width = Sepal.Width, 
#     Petal.Length = Petal.Length, Petal.Width = Petal.Width, Species = Species, 
#     rms = sqrt((square(Sepal.Length) + square(Sepal.Width) + 
#         square(Petal.Length) + square(Petal.Width))/4L))
DT[, j, env = list(j = j)]
#      Sepal.Length Sepal.Width Petal.Length Petal.Width   Species      rms
#             <num>       <num>        <num>       <num>    <fctr>    <num>
#   1:          5.1         3.5          1.4         0.2    setosa 3.172538
#   2:          4.9         3.0          1.4         0.2    setosa 2.958462
#  ---                                                                     
# 149:          6.2         3.4          5.4         2.3 virginica 4.594834
# 150:          5.9         3.0          5.1         1.8 virginica 4.273757

# alternatively
j = as.call(c(
  quote(list),
  lapply(setNames(nm = vars), as.name),
  list(Species = as.name("Species")),
  list(rms = rms)
))
print(j)
# list(Sepal.Length = Sepal.Length, Sepal.Width = Sepal.Width, 
#     Petal.Length = Petal.Length, Petal.Width = Petal.Width, Species = Species, 
#     rms = sqrt((square(Sepal.Length) + square(Sepal.Width) + 
#         square(Petal.Length) + square(Petal.Width))/4L))
DT[, j, env = list(j = j)]
#      Sepal.Length Sepal.Width Petal.Length Petal.Width   Species      rms
#             <num>       <num>        <num>       <num>    <fctr>    <num>
#   1:          5.1         3.5          1.4         0.2    setosa 3.172538
#   2:          4.9         3.0          1.4         0.2    setosa 2.958462
#  ---                                                                     
# 149:          6.2         3.4          5.4         2.3 virginica 4.594834
# 150:          5.9         3.0          5.1         1.8 virginica 4.273757
```

## Interfaces retiradas

En `[.data.table`, también es posible utilizar otros mecanismos para la sustitución de variables o para pasar expresiones entre comillas. Estos incluyen `get` y `mget` para la inyección en línea de variables proporcionando sus nombres como cadenas, y `eval` que le dice a `[.data.table` que la expresión que pasamos a un argumento es una expresión entre comillas y que debe manejarse de manera diferente. Esas interfaces ahora deben considerarse retiradas y recomendamos utilizar el nuevo argumento `env` en su lugar.

### `obtener`


``` r
v1 = "Petal.Width"
v2 = "Sepal.Width"

DT[, .(total = sum(get(v1), get(v2)))]
#    total
#    <num>
# 1: 638.5

DT[, .(total = sum(v1, v2)),
   env = list(v1 = v1, v2 = v2)]
#    total
#    <num>
# 1: 638.5
```

### `Obtener`


``` r
v = c("Petal.Width", "Sepal.Width")

DT[, lapply(mget(v), mean)]
#    Petal.Width Sepal.Width
#          <num>       <num>
# 1:    1.199333    3.057333

DT[, lapply(v, mean),
   env = list(v = as.list(v))]
#          V1       V2
#       <num>    <num>
# 1: 1.199333 3.057333

DT[, lapply(v, mean),
   env = list(v = as.list(setNames(nm = v)))]
#    Petal.Width Sepal.Width
#          <num>       <num>
# 1:    1.199333    3.057333
```

### `evaluar`

En lugar de utilizar la función `eval`, podemos proporcionar una expresión entre comillas en el elemento del argumento `env`, por lo que no se necesita una llamada `eval` adicional.


``` r
cl = quote(
  .(Petal.Width = mean(Petal.Width), Sepal.Width = mean(Sepal.Width))
)

DT[, eval(cl)]
#    Petal.Width Sepal.Width
#          <num>       <num>
# 1:    1.199333    3.057333

DT[, cl, env = list(cl = cl)]
#    Petal.Width Sepal.Width
#          <num>       <num>
# 1:    1.199333    3.057333
```



