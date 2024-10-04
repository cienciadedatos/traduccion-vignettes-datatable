---
title: "Frequently Asked Questions about data.table"
date: "2024-10-04"
output:
  markdown::html_format:
    options:
      toc: true
      number_sections: true
    meta:
      css: [default, css/toc.css]
vignette: >
  %\VignetteIndexEntry{Frequently Asked Questions about data.table}
  %\VignetteEngine{knitr::knitr}
  \usepackage[utf8]{inputenc}
---

<style>
h2 {
    font-size: 20px;
}
#TOC { width: 100%; }
</style>



La primera sección, Preguntas frecuentes para principiantes, está pensada para leerse en orden, de principio a fin. Está escrita en un estilo de preguntas frecuentes para que sea más fácil de digerir. En realidad, no son las preguntas más frecuentes. Una mejor manera de hacerlo es buscar en Stack Overflow.

Estas preguntas frecuentes son de lectura obligatoria y se consideran documentación básica. No hagas preguntas en Stack Overflow ni plantees problemas en GitHub hasta que las hayas leído. Todos sabemos que cuando preguntas no las has leído. Por lo tanto, si preguntas y no las has leído, no uses tu nombre real.

Este documento ha sido revisado rápidamente debido a los cambios en la versión 1.9.8 publicada en noviembre de 2016. Envíe solicitudes de incorporación de cambios para corregir errores o realizar mejoras. Si alguien sabe por qué la tabla de contenidos aparece tan estrecha y aplastada cuando la muestra CRAN, infórmenos. Este documento solía ser un PDF y lo cambiamos recientemente a HTML.


# Preguntas frecuentes para principiantes

## ¿Por qué `DT[, 5]` y `DT[2, 5]` devuelven una tabla de datos de una columna en lugar de vectores como `data.frame`? {#j-num}

Para mantener la coherencia, cuando utilice data.table en funciones que aceptan entradas variables, puede confiar en que `DT[...]` devolverá un data.table. No tiene que recordar incluir `drop=FALSE` como lo hace en data.frame. data.table se lanzó por primera vez en 2006 y esta diferencia con data.frame ha sido una característica desde el principio.

Es posible que hayas oído que, en general, es una mala práctica hacer referencia a las columnas por número en lugar de por nombre. Si tu colega viene y lee tu código más tarde, es posible que tenga que buscar por todas partes para averiguar qué columna es la número 5. Si tú o ellos cambian el orden de las columnas más arriba en tu programa R, puedes producir resultados erróneos sin advertencia ni error si olvidas cambiar todos los lugares en tu código que hacen referencia a la columna número 5. Eso es culpa tuya, no de R ni de data.table. Es realmente muy malo. Por favor, no lo hagas. Es el mismo mantra que tienen los desarrolladores profesionales de SQL: nunca uses `select *`, siempre selecciona explícitamente por nombre de columna para al menos intentar ser robusto a cambios futuros.

Digamos que la columna 5 se llama `"region"` y realmente debe extraer esa columna como un vector, no como un data.table. Es más robusto usar el nombre de la columna y escribir `DT$region` o `DT[["region"]]`; es decir, lo mismo que la base R. Se recomienda usar `$` y `[[` de la base R en data.table. No cuando se combinan con `<-` para asignar (use `:=` en su lugar para eso) sino solo para seleccionar una sola columna por nombre.

Existen algunas circunstancias en las que hacer referencia a una columna por número parece ser la única manera, como en el caso de una secuencia de columnas. En estas situaciones, al igual que en data.frame, puede escribir `DT[, 5:10]` y `DT[,c(1,4,10)]`. Sin embargo, nuevamente, es más robusto (para cambios futuros en el número y orden de las columnas de sus datos) usar un rango con nombre como `DT[,columnRed:columnViolet]` o nombrar cada una de ellas `DT[,c("columnRed","columnOrange","columnYellow")]`. Es un trabajo más arduo al principio, pero probablemente se lo agradecerá a usted mismo y sus colegas podrían agradecérselo en el futuro. Al menos puede decir que hizo lo mejor que pudo para escribir un código sólido si algo sale mal.

Sin embargo, lo que realmente queremos que hagas es `DT[,.(columnRed,columnOrange,columnYellow)]`; es decir, usar los nombres de columna como si fueran variables directamente dentro de `DT[...]`. No tienes que anteponer cada columna con `DT$` como lo haces en data.frame. La parte `.()` es solo un alias para `list()` y puedes usar `list()` en su lugar si lo prefieres. Puedes colocar cualquier expresión R de nombres de columna, usando cualquier paquete R, devolviendo diferentes tipos de diferentes longitudes, allí mismo. Queríamos alentarte a hacer eso con tanta fuerza en el pasado que deliberadamente no hicimos que `DT[,5]` funcionara en absoluto. Antes de que se lanzara v1.9.8 en noviembre de 2016, `DT[,5]` solía devolver simplemente `5`. La idea era que podíamos enseñar de manera más simple un hecho: las partes dentro de `DT[...]` siempre se evalúan dentro del marco de DT (ven los nombres de columna como si fueran variables). Y `5` evalúa a `5`, por lo que el comportamiento era coherente con la regla única. Te pedimos que pasaras por un obstáculo deliberado adicional `DT[,5,with=FALSE]` si realmente querías seleccionar una columna por nombre o número. A partir de noviembre de 2016, no necesitas usar `with=FALSE` y veremos cómo una mayor coherencia con data.frame en este sentido ayudará o perjudicará tanto a los usuarios nuevos como a los antiguos. Los nuevos usuarios que no lean estas preguntas frecuentes, ni siquiera esta primera entrada, con suerte no tropezarán tan pronto con data.table como lo hicieron antes si esperaban que funcionara como data.frame. Con suerte, no perderán la oportunidad de comprender nuestra intención y recomendación de colocar expresiones de columnas dentro de `DT[i, j, by]`. Si usan data.table como data.frame, no obtendrán ningún beneficio. Si conoces a alguien así, dale un empujoncito amistoso para que lea este documento como lo haces tú.

Recordatorio: puedes colocar _cualquier_ expresión R dentro de `DT[...]` usando nombres de columna como si fueran variables; por ejemplo, prueba `DT[, colA*colB/2]`. Eso devuelve un vector porque usaste nombres de columna como si fueran variables. Encierra con `.()` para devolver una tabla de datos; es decir, `DT[,.(colA*colB/2)]`. Nómbrala: `DT[,.(myResult = colA*colB/2)]`. Y te dejaremos que adivines cómo devolver dos cosas de esta consulta. También es bastante común hacer un montón de cosas dentro de un cuerpo anónimo: `DT[, { x<-colA+10; x*x/2 }]` o llamar a la función de otro paquete: `DT[ , fitdistr(columnA, "normal")]`.

## ¿Por qué `DT[,"region"]` devuelve una tabla de datos de 1 columna en lugar de un vector?

Consulte la [respuesta anterior](#j-num). Pruebe `DT$region` en su lugar. O `DT[["region"]]`.


## ¿Por qué `DT[, region]` devuelve un vector para la columna "region"? Me gustaría tener una tabla de datos de una columna.

Pruebe `DT[ , .(region)]` en su lugar. `.()` es un alias para `list()` y garantiza que se devuelva una tabla de datos.

Continúe leyendo y consulte las preguntas frecuentes a continuación. Lea todo el documento antes de quedarse atascado en una parte.

## ¿Por qué no funciona `DT[, x, y, z]`? Quería las 3 columnas `x`,`y` y `z`.

La expresión `j` es el segundo argumento. Pruebe `DT[ , c("x","y","z")]` o `DT[ , .(x,y,z)]`.

## Asigné una variable `mycol="x"` pero luego `DT[, mycol]` devuelve un error. ¿Cómo hago para que busque el nombre de la columna contenida en la variable `mycol`?

El error es que no se puede encontrar la columna denominada `"mycol"`, y este error es correcto. El alcance de `data.table` es diferente a `data.frame` en que puede usar nombres de columnas como si fueran variables directamente dentro de `DT[...]` sin anteponer `DT$` a cada nombre de columna; consulte la pregunta frecuente 1.1 anterior.

Para utilizar `mycol` para seleccionar la columna `x` de `DT`, hay algunas opciones:

```r
DT[, ..mycol]            # .. prefix conveys to look for the mycol one level up in calling scope
DT[, mycol, with=FALSE]  # revert to data.frame behavior
DT[[mycol]]               # treat DT as a list and use [[ from base R
```

Consulte `?data.table` para obtener más detalles sobre el prefijo `..`.

El argumento `with` toma su nombre de la función `base` `with()`. Cuando `with=TRUE` (predeterminado), `data.table` opera de manera similar a `with()`, es decir, `DT[, mycol]` se comporta como `with(DT, mycol)`. Cuando `with=FALSE`, las reglas de evaluación estándar de `data.frame` se aplican a todas las variables en `j` y ya no se pueden usar nombres de columnas directamente.

## ¿Cuáles son los beneficios de poder usar nombres de columnas como si fueran variables dentro de `DT[...]`?

`j` no tiene por qué ser simplemente nombres de columnas. Puede escribir cualquier _expresión_ R de nombres de columnas directamente en `j`, _p. ej._, `DT[ , mean(x*y/z)]`. Lo mismo se aplica a `i`, _p. ej._, `DT[x>1000, sum(y*z)]`.

Esto ejecuta la expresión `j` en el conjunto de filas donde la expresión `i` es verdadera. Ni siquiera necesita devolver datos, _p. ej._, `DT[x>1000, plot(y, z)]`. Puede hacer `j` por grupo simplemente agregando `by = `; p. ej., `DT[x>1000, sum(y*z), by = w]`. Esto ejecuta `j` para cada grupo en la columna `w` pero solo sobre las filas donde `x>1000`. Al colocar las 3 partes de la consulta (i=where, j=select y by=group by) dentro de los corchetes, data.table ve esta consulta como un todo antes de que se evalúe cualquier parte de ella. Por lo tanto, puede optimizar la consulta combinada para el rendimiento. Puede hacer esto porque el lenguaje R tiene una evaluación diferida única (Python y Julia no la tienen). data.table ve las expresiones dentro de `DT[...]` antes de que se evalúen y las optimiza antes de la evaluación. Por ejemplo, si data.table ve que solo está usando 2 columnas de 100, no se molestará en crear un subconjunto de las 98 que no son necesarias para su expresión j.

## Vale, estoy empezando a entender de qué se trata data.table, pero ¿por qué no mejoraron `data.frame` en R? ¿Por qué tiene que ser un paquete nuevo?

Como [se destacó arriba](#j-num), `j` en `[.data.table` es fundamentalmente diferente de `j` en `[.data.frame`. Incluso si algo tan simple como `DF[ , 1]` se cambiara en R base para devolver un data.frame en lugar de un vector, eso rompería el código existente en muchos miles de paquetes CRAN y código de usuario. Tan pronto como dimos el paso para crear una nueva clase que heredara de data.frame, tuvimos la oportunidad de cambiar algunas cosas y lo hicimos. Queremos que data.table sea ligeramente diferente y funcione de esta manera para que funcione una sintaxis más complicada. También hay otras diferencias (ver [abajo](#SmallerDiffs)).

Además, data.table _hereda_ de `data.frame`. También _es_ un `data.frame`. Se puede pasar un data.table a cualquier paquete que solo acepte `data.frame` y ese paquete puede usar la sintaxis `[.data.frame` en data.table. Consulta [esta respuesta](https://stackoverflow.com/a/10529888/403310) para saber cómo se logra esto.

También hemos propuesto mejoras para R siempre que ha sido posible. Una de ellas se aceptó como nueva característica en R 2.12.0:

> `unique()` y `match()` ahora son más rápidos en vectores de caracteres donde todos los elementos están en la caché CHARSXP global y tienen codificación sin marcar (ASCII). Gracias a Matt Dowle por sugerir mejoras en la forma en que se genera el código hash en unique.c.

Una segunda propuesta fue utilizar `memcpy` en duplicate.c, que es mucho más rápido que un bucle for en C. Esto mejoraría la _forma_ en que R copia datos internamente (en algunas mediciones, hasta 13 veces). El hilo sobre r-devel está [aquí](https://stat.ethz.ch/pipermail/r-devel/2010-April/057249.html).

Una tercera propuesta más significativa que fue aceptada es que R ahora usa el código de ordenamiento por radix de data.table a partir de R 3.3.0:

> El algoritmo de ordenación por base y la implementación de data.table (forder) reemplazan la ordenación por base (conteo) anterior y agregan un nuevo método para order(). Aportado por Matt Dowle y Arun Srinivasan, el nuevo algoritmo admite vectores lógicos, enteros (incluso con valores grandes), reales y de caracteres. Supera a todos los demás métodos, pero existen algunas salvedades (consulte ?sort).

Este fue un gran acontecimiento para nosotros y lo celebramos hasta el cansancio (en realidad, no).

## ¿Por qué los valores predeterminados son los que son? ¿Por qué funciona como lo hace?

La respuesta es sencilla: el autor principal lo diseñó originalmente para su propio uso. Así lo quiso. Le parece una forma más natural y rápida de escribir código, que también se ejecuta más rápidamente.

## ¿Esto no está ya hecho por `with()` y `subset()` en `base`?

Algunas de las características que hemos comentado hasta ahora son: sí. El paquete se basa en la funcionalidad básica. Hace el mismo tipo de cosas, pero requiere menos código y se ejecuta mucho más rápido si se utiliza correctamente.

## ¿Por qué `X[Y]` devuelve también todas las columnas de `Y`? ¿No debería devolver un subconjunto de `X`?

Esto se modificó en la versión v1.5.3 (febrero de 2011). Desde entonces, `X[Y]` incluye las columnas no unidas de `Y`. Nos referimos a esta característica como _ámbito heredado de unión_ porque no solo las columnas `X` están disponibles para la expresión `j`, sino también las columnas `Y`. La desventaja es que `X[Y]` es menos eficiente ya que cada elemento de las columnas no unidas de `Y` se duplica para que coincida con la cantidad (probablemente grande) de filas en `X` que coinciden. Por lo tanto, recomendamos encarecidamente `X[Y, j]` en lugar de `X[Y]`. Consulte [próximas preguntas frecuentes](#MergeDiff).

## ¿Cuál es la diferencia entre `X[Y]` y `merge(X, Y)`? {#MergeDiff}

`X[Y]` es una unión, que busca las filas de `X` utilizando `Y` (o la clave de `Y` si tiene una) como índice.

`Y[X]` es una unión, que busca las filas de `Y` usando `X` (o la clave de `X` si tiene una) como índice.

`merge(X,Y)`[^1] realiza ambas operaciones al mismo tiempo. La cantidad de filas de `X[Y]` e `Y[X]` suele ser diferente, mientras que la cantidad de filas devueltas por `merge(X, Y)` y `merge(Y, X)` es la misma.

_PERO_ eso pasa por alto el punto principal. La mayoría de las tareas requieren que se haga algo con los datos después de una unión o fusión. ¿Por qué fusionar todas las columnas de datos, solo para usar un pequeño subconjunto de ellas después? Puede sugerir `merge(X[ , ColsNeeded1], Y[ , ColsNeeded2])`, pero eso requiere que el programador determine qué columnas son necesarias. `X[Y, j]` en data.table hace todo eso en un solo paso para usted. Cuando escribe `X[Y, sum(foo*bar)]`, data.table inspecciona automáticamente la expresión `j` para ver qué columnas usa. Solo creará un subconjunto de esas columnas; las otras se ignoran. Solo se crea memoria para las columnas que usa `j` y las columnas `Y` disfrutan de las reglas de reciclaje estándar de R dentro del contexto de cada grupo. Digamos que `foo` está en `X` y `bar` está en `Y` (junto con otras 20 columnas en `Y`). ¿No es `X[Y, sum(foo*bar)]` más rápido de programar y más rápido de ejecutar que una `fusión` de todo desperdiciada seguida por un `subconjunto`?

[^1]: Aquí nos referimos al método `merge` para data.table o al método `merge` para `data.frame` ya que ambos métodos funcionan de la misma manera en este sentido. Consulte `?merge.data.table` y [a continuación](#r-dispatch) para obtener más información sobre el envío de métodos.

## ¿Algo más sobre `X[Y, sum(foo*bar)]`?

Este comportamiento cambió en la versión 1.9.4 (septiembre de 2014). Ahora realiza la unión `X[Y]` y luego ejecuta `sum(foo*bar)` sobre todas las filas; es decir, `X[Y][ , sum(foo*bar)]`. Antes ejecutaba `j` para cada _grupo_ de `X` con el que coincide cada fila de `Y`. Eso todavía se puede hacer porque es muy útil, pero ahora debe ser explícito y especificar `by = .EACHI`, _es decir_, `X[Y, sum(foo*bar), by = .EACHI]`. A esto lo llamamos _agrupamiento por cada `i`_.

Por ejemplo, (complicándolo aún más al utilizar _join legacy scope_ también):


``` r
X = data.table(grp = c("a", "a", "b",
                       "b", "b", "c", "c"), foo = 1:7)
setkey(X, grp)
Y = data.table(c("b", "c"), bar = c(4, 2))
X
# Key: <grp>
#       grp   foo
#    <char> <int>
# 1:      a     1
# 2:      a     2
# 3:      b     3
# 4:      b     4
# 5:      b     5
# 6:      c     6
# 7:      c     7
Y
#        V1   bar
#    <char> <num>
# 1:      b     4
# 2:      c     2
X[Y, sum(foo*bar)]
# [1] 74
X[Y, sum(foo*bar), by = .EACHI]
# Key: <grp>
#       grp    V1
#    <char> <num>
# 1:      b    48
# 2:      c    26
```

## Eso está muy bien. ¿Cómo lograste cambiarlo, dado que los usuarios dependían del comportamiento anterior?

La solicitud de cambio provino de los usuarios. La sensación era que si una consulta está haciendo agrupación, entonces debería estar presente un `by=` explícito por razones de legibilidad del código. Se proporcionó una opción para devolver el comportamiento anterior: `options(datatable.old.bywithoutby)`, por defecto `FALSE`. Esto permitió la actualización para probar las otras nuevas características / correcciones de errores en v1.9.4, con la migración posterior de cualquier consulta by-without-by cuando esté lista agregando `by=.EACHI` a ellas. Conservamos 47 pruebas previas al cambio y las agregamos nuevamente como pruebas nuevas, probadas bajo `options(datatable.old.bywithoutby=TRUE)`. Agregamos un mensaje de inicio sobre el cambio y cómo volver al comportamiento anterior. Después de 1 año, la opción quedó obsoleta con una advertencia cuando se usaba. Después de 2 años, se eliminó la opción para volver al comportamiento anterior.

De los 66 paquetes en CRAN o Bioconductor que dependían de data.table o lo importaban en el momento de la publicación de la versión 1.9.4 (ahora son más de 300), solo uno se vio afectado por el cambio. Esto podría deberse a que muchos paquetes no tienen pruebas exhaustivas o simplemente a que los paquetes posteriores no utilizaban mucho la agrupación por cada fila en `i`. Siempre probamos la nueva versión con todos los paquetes dependientes antes de su publicación y coordinamos los cambios con los encargados de su mantenimiento. Por lo tanto, esta versión fue bastante sencilla en ese sentido.

Otra razón de peso para realizar el cambio fue que, anteriormente, no había una forma eficiente de lograr lo que `X[Y, sum(foo*bar)]` hace ahora. Había que escribir `X[Y][ , sum(foo*bar)]`. Eso no era óptimo porque `X[Y]` unía todas las columnas y las pasaba todas a la segunda consulta compuesta sin saber que solo se necesitaban `foo` y `bar`. Para resolver ese problema de eficiencia, se requería un esfuerzo de programación adicional: `X[Y, list(foo, bar)][ , sum(foo*bar)]`. El cambio a `by = .EACHI` ha simplificado esto al permitir que ambas consultas se expresen dentro de una única consulta `DT[...]` para lograr eficiencia.

# Sintaxis general

## ¿Cómo puedo evitar escribir una expresión `j` muy larga? Has dicho que debería usar la columna _names_, pero tengo muchas columnas.

Al agrupar, la expresión `j` puede usar nombres de columnas como variables, como ya sabes, pero también puede usar un símbolo reservado `.SD` que hace referencia al **S**subconjunto de **D**ata.table para cada grupo (excluyendo las columnas de agrupación). Por lo tanto, para sumar todas las columnas, es simplemente `DT[ , lapply(.SD, sum), by = grp]`. Puede parecer complicado, pero es rápido de escribir y rápido de ejecutar. Ten en cuenta que no tienes que crear una función anónima. El objeto `.SD` se implementa internamente de manera eficiente y es más eficiente que pasar un argumento a una función. Pero si el símbolo `.SD` aparece en `j`, entonces data.table tiene que completar `.SD` por completo para cada grupo, incluso si `j` no lo usa todo.

Por lo tanto, no haga, por ejemplo, `DT[ , sum(.SD[["sales"]]), by = grp]`. Eso funciona, pero es ineficiente y poco elegante. `DT[ , sum(sales), by = grp]` es lo que se pretendía, y podría ser cientos de veces más rápido. Si utiliza _todos_ los datos en `.SD` para cada grupo (como en `DT[ , lapply(.SD, sum), by = grp]`), entonces ese es un muy buen uso de `.SD`. Si está utilizando _varias_ pero no _todas_ las columnas, puede combinar `.SD` con `.SDcols`; consulte `?data.table`.

## ¿Por qué el valor predeterminado para `mult` ahora es `"all"`?

En la versión 1.5.3, el valor predeterminado se cambió a `"all"`. Cuando `i` (o la clave de `i` si tiene una) tiene menos columnas que la clave de `x`, `mult` ya estaba configurado en `"all"` automáticamente. Cambiar el valor predeterminado hace que esto sea más claro y fácil para los usuarios, ya que se presentaba con bastante frecuencia.

En versiones anteriores a la v1.3, `"all"` era más lento. Internamente, `"all"` se implementaba uniendo mediante `"first"`, luego nuevamente desde cero mediante `"last"`, después de lo cual se realizaba una comparación entre ellos para calcular el intervalo de coincidencias en `x` para cada fila en `i`. Sin embargo, la mayoría de las veces unimos filas individuales, donde `"first"`, `"last"` y `"all"` devuelven el mismo resultado. Preferimos el máximo rendimiento para la mayoría de las situaciones, por lo que el valor predeterminado elegido fue `"first"`. Al trabajar con una clave no única (generalmente una sola columna que contiene una variable de agrupamiento), `DT["A"]` devolvía la primera fila de ese grupo, por lo que se necesitaba `DT["A", mult = "all"]` para devolver todas las filas de ese grupo.

En la v1.4, la búsqueda binaria en C se modificó para que se ramificara en el nivel más profundo para encontrar el primero y el último. Es probable que esa ramificación se produzca dentro de las mismas páginas finales de RAM, por lo que ya no debería haber una desventaja de velocidad al establecer `mult` como `"all"` de manera predeterminada. Advertimos que el valor predeterminado podría cambiar e hicimos el cambio en la v1.5.3.

Una versión futura de data.table puede permitir una distinción entre una clave y una _clave única_. Internamente, `mult = "all"` funcionaría más como `mult = "first"` cuando todas las columnas de clave de `x` se unieran y la clave de `x` fuera una clave única. data.table necesitaría verificaciones en la inserción y actualización para asegurarse de que se mantenga una clave única. Una ventaja de especificar una clave única sería que data.table garantizaría que no se puedan insertar duplicados, además del rendimiento.

## Estoy usando `c()` en `j` y obtengo resultados extraños.

Esta es una fuente común de confusión. En `data.frame`, por ejemplo, se suele decir:


``` r
DF = data.frame(x = 1:3, y = 4:6, z = 7:9)
DF
#   x y z
# 1 1 4 7
# 2 2 5 8
# 3 3 6 9
DF[ , c("y", "z")]
#   y z
# 1 4 7
# 2 5 8
# 3 6 9
```

que devuelve las dos columnas. En data.table sabes que puedes usar los nombres de las columnas directamente y puedes intentar:


``` r
DT = data.table(DF)
DT[ , c(y, z)]
# [1] 4 5 6 7 8 9
```

pero esto devuelve un vector. Recuerde que la expresión `j` se evalúa dentro del entorno de `DT` y `c()` devuelve un vector. Si se requieren 2 o más columnas, utilice `list()` o `.()` en su lugar:


``` r
DT[ , .(y, z)]
#        y     z
#    <int> <int>
# 1:     4     7
# 2:     5     8
# 3:     6     9
```

`c()` también puede ser útil en una tabla de datos, pero su comportamiento es diferente al de `[.data.frame`.

## He creado una tabla compleja con muchas columnas. Quiero usarla como plantilla para una nueva tabla; es decir, crear una nueva tabla sin filas, pero con los nombres y tipos de columnas copiados de mi tabla. ¿Puedo hacerlo fácilmente?

Sí. Si su tabla compleja se llama `DT`, intente `NEWDT = DT[0]`.

## ¿Es un data.table nulo lo mismo que `DT[0]`?

No. Por "data.table nulo" nos referimos al resultado de `data.table(NULL)` o `as.data.table(NULL)`; _es decir_,


``` r
data.table(NULL)
# Null data.table (0 rows and 0 cols)
data.frame(NULL)
# data frame with 0 columns and 0 rows
as.data.table(NULL)
# Null data.table (0 rows and 0 cols)
as.data.frame(NULL)
# data frame with 0 columns and 0 rows
is.null(data.table(NULL))
# [1] FALSE
is.null(data.frame(NULL))
# [1] FALSE
```

El data.table|`frame` nulo es `NULL` con algunos atributos adjuntos, lo que significa que ya no es `NULL`. En R, solo `NULL` puro es `NULL`, como se prueba con `is.null()`. Cuando nos referimos al "data.table nulo", usamos null en minúscula para ayudar a distinguirlo de `NULL` en mayúscula. Para probar el data.table nulo, use `length(DT) == 0` o `ncol(DT) == 0` (`length` es un poco más rápido ya que es una función primitiva).

Una tabla de datos _vacía_ (`DT[0]`) tiene una o más columnas, todas ellas vacías. Esas columnas vacías aún tienen nombres y tipos.


``` r
DT = data.table(a = 1:3, b = c(4, 5, 6), d = c(7L,8L,9L))
DT[0]
# Empty data.table (0 rows and 3 cols): a,b,d
sapply(DT[0], class)
#         a         b         d 
# "integer" "numeric" "integer"
```

## ¿Por qué se ha eliminado el alias `DT()`? {#DTremove1}
`DT` se introdujo originalmente como un contenedor para una lista de expresiones `j`. Dado que `DT` era un alias para data.table, era una forma conveniente de encargarse del reciclaje silencioso en los casos en que cada elemento de la lista `j` se evaluaba en longitudes diferentes. Sin embargo, el alias era una de las razones por las que la agrupación era lenta.

A partir de la versión 1.3, se deben pasar `list()` o `.()` en lugar del argumento `j`. Son mucho más rápidos, especialmente cuando hay muchos grupos. Internamente, este fue un cambio no trivial. El reciclaje de vectores ahora se realiza internamente, junto con varias otras mejoras de velocidad para la agrupación.

## Pero mi código usa `j = DT(...)` y funciona. La pregunta frecuente anterior dice que se ha eliminado `DT()`. {#DTremove2}

Entonces estás usando una versión anterior a la 1.5.3. Antes de la 1.5.3, `[.data.table` detectaba el uso de `DT()` en `j` y lo reemplazaba automáticamente con una llamada a `list()`. Esto era para ayudar a los usuarios existentes en la transición.

## ¿Cuáles son las reglas de alcance para las expresiones 'j'?

Piense en el subconjunto como un entorno donde todos los nombres de columna son variables. Cuando se utiliza una variable `foo` en la `j` de una consulta como `X[Y, sum(foo)]`, se busca `foo` en el siguiente orden:

 1. El alcance del subconjunto de `X`; _es decir_, los nombres de columna de `X`.
 2. El alcance de cada fila de `Y`; _es decir_, los nombres de columna de `Y` (_ámbito heredado de join_)
 3. El alcance del marco de llamada; _por ejemplo_, la línea que aparece antes de la consulta data.table.
 4. Ejercicio para el lector: ¿entonces se extiende a los marcos de llamada o va directamente a `globalenv()`?
 5. El entorno global

Este es el _alcance léxico_ como se explica en [R FAQ 3.3.1](https://cran.r-project.org/doc/FAQ/R-FAQ.html#Lexical-scoping). Sin embargo, el entorno en el que se creó la función no es relevante, porque _no hay función_. No se pasa ninguna _función_ anónima a `j`. En cambio, se pasa un _cuerpo_ anónimo a `j`; por ejemplo,


``` r
DT = data.table(x = rep(c("a", "b"), c(2, 3)), y = 1:5)
DT
#         x     y
#    <char> <int>
# 1:      a     1
# 2:      a     2
# 3:      b     3
# 4:      b     4
# 5:      b     5
DT[ , {z = sum(y); z + 3}, by = x]
#         x    V1
#    <char> <num>
# 1:      a     6
# 2:      b    15
```

Algunos lenguajes de programación llaman a esto _lambda_.

## ¿Puedo rastrear la expresión 'j' a medida que se ejecuta a través de los grupos? {#j-trace}

Prueba algo como esto:


``` r
DT[ , {
  cat("Objects:", paste(objects(), collapse = ","), "\n")
  cat("Trace: x=", as.character(x), " y=", y, "\n")
  sum(y)},
  by = x]
# Objects: -.POSIXt,Cfastmean,print,x,y 
# Trace: x= a  y= 1 2 
# Objects: -.POSIXt,Cfastmean,print,x,y 
# Trace: x= b  y= 3 4 5
#         x    V1
#    <char> <int>
# 1:      a     3
# 2:      b    12
```

## Dentro de cada grupo, ¿por qué las variables del grupo tienen una longitud de 1?

[Arriba](#j-trace), `x` es una variable de agrupamiento y (a partir de la versión v1.6.1) tiene una `longitud` de 1 (si se inspecciona o se utiliza en `j`). Esto es por eficiencia y conveniencia. Por lo tanto, no hay diferencia entre las dos afirmaciones siguientes:


``` r
DT[ , .(g = 1, h = 2, i = 3, j = 4, repeatgroupname = x, sum(y)), by = x]
#         x     g     h     i     j repeatgroupname    V6
#    <char> <num> <num> <num> <num>          <char> <int>
# 1:      a     1     2     3     4               a     3
# 2:      b     1     2     3     4               b    12
DT[ , .(g = 1, h = 2, i = 3, j = 4, repeatgroupname = x[1], sum(y)), by = x]
#         x     g     h     i     j repeatgroupname    V6
#    <char> <num> <num> <num> <num>          <char> <int>
# 1:      a     1     2     3     4               a     3
# 2:      b     1     2     3     4               b    12
```

Si necesita el tamaño del grupo actual, utilice `.N` en lugar de llamar a `length()` en cualquier columna.

## Solo se imprimen las primeras 10 filas, ¿cómo imprimo más?

Aquí suceden dos cosas. En primer lugar, si la cantidad de filas en una tabla de datos es grande (`> 100` por defecto), entonces se imprime un resumen de la tabla de datos en la consola por defecto. En segundo lugar, el resumen de una tabla de datos grande se imprime tomando las `n` filas superiores e inferiores (`= 5` por defecto) de la tabla de datos y solo imprimiendo esas. Ambos parámetros (cuándo activar un resumen y qué parte de una tabla utilizar como resumen) se pueden configurar mediante el mecanismo `options` de R o llamando directamente a la función `print`.

Por ejemplo, para hacer que el resumen de una tabla de datos solo se realice cuando una tabla de datos tenga más de 50 filas, puede usar `options(datatable.print.nrows = 50)`. Para deshabilitar por completo el resumen predeterminado, puede usar `options(datatable.print.nrows = Inf)`. También puede llamar a `print` directamente, como en `print(your.data.table, nrows = Inf)`.

Si desea mostrar más de las 10 filas superiores (e inferiores) de un resumen de data.table (digamos que desea 20), configure `options(datatable.print.topn = 20)`, por ejemplo. Nuevamente, también podría llamar a `print` directamente, como en `print(your.data.table, topn = 20)`.

## Con una unión `X[Y]`, ¿qué pasa si `X` contiene una columna llamada `"Y"`?

Cuando `i` es un nombre único, como `Y`, se evalúa en el marco de llamada. En todos los demás casos, como llamadas a `.()` u otras expresiones, `i` se evalúa dentro del alcance de `X`. Esto facilita las _autouniones_ sencillas, como `X[J(unique(colA)), mult = "first"]`.

## `X[Z[Y]]` falla porque `X` contiene una columna `"Y"`. Me gustaría que utilizara la tabla `Y` en el ámbito de llamada.

La parte `Z[Y]` no es un nombre único, por lo que se evalúa dentro del marco de `X` y se produce el problema. Pruebe `tmp = Z[Y]; X[tmp]`. Esto es robusto para `X` que contiene una columna `"tmp"` porque `tmp` es un nombre único. Si a menudo encuentra conflictos de este tipo, una solución sencilla puede ser nombrar todas las tablas en mayúsculas y todos los nombres de columnas en minúsculas, o algún esquema similar.

## ¿Puedes explicar con más detalle por qué data.table está inspirado en la sintaxis `A[B]` en `base`?

Considere la sintaxis `A[B]` usando una matriz de ejemplo `A`:

``` r
A = matrix(1:12, nrow = 4)
A
#      [,1] [,2] [,3]
# [1,]    1    5    9
# [2,]    2    6   10
# [3,]    3    7   11
# [4,]    4    8   12
```

Para obtener las celdas `(1, 2) = 5` y `(3, 3) = 11` muchos usuarios (creemos) pueden intentar esto primero:

``` r
A[c(1, 3), c(2, 3)]
#      [,1] [,2]
# [1,]    5    9
# [2,]    7   11
```

Sin embargo, esto devuelve la unión de esas filas y columnas. Para hacer referencia a las celdas, se requiere una matriz de 2 columnas. `?Extract` dice:

> Al indexar matrices mediante `[`, un único argumento `i` puede ser una matriz con tantas columnas como dimensiones de `x`; el resultado es entonces un vector con elementos correspondientes a los conjuntos de índices en cada fila de `i`.

Vamos a intentarlo de nuevo.


``` r
B = cbind(c(1, 3), c(2, 3))
B
#      [,1] [,2]
# [1,]    1    2
# [2,]    3    3
A[B]
# [1]  5 11
```

Una matriz es una estructura bidimensional con nombres de filas y nombres de columnas. ¿Podemos hacer lo mismo con los nombres?


``` r
rownames(A) = letters[1:4]
colnames(A) = LETTERS[1:3]
A
#   A B  C
# a 1 5  9
# b 2 6 10
# c 3 7 11
# d 4 8 12
B = cbind(c("a", "c"), c("B", "C"))
A[B]
# [1]  5 11
```

Entonces sí podemos. ¿Podemos hacer lo mismo con un `data.frame`?


``` r
A = data.frame(A = 1:4, B = letters[11:14], C = pi*1:4)
rownames(A) = letters[1:4]
A
#   A B         C
# a 1 k  3.141593
# b 2 l  6.283185
# c 3 m  9.424778
# d 4 n 12.566371
B
#      [,1] [,2]
# [1,] "a"  "B" 
# [2,] "c"  "C"
A[B]
# [1] "k"         " 9.424778"
```

Pero, observe que el resultado se convirtió a `character`. R convirtió `A` a `matrix` primero para que la sintaxis pudiera funcionar, pero el resultado no es ideal. Intentemos convertir `B` en `data.frame`.


``` r
B = data.frame(c("a", "c"), c("B", "C"))
cat(try(A[B], silent = TRUE))
# Error in `[.default`(A, B) : invalid subscript type 'list'
```

Por lo tanto, no podemos crear un subconjunto de un `data.frame` con un `data.frame` en R base. ¿Qué sucede si queremos nombres de filas y columnas que no sean `character` sino `integer` o `float`? ¿Qué sucede si queremos más de 2 dimensiones de tipos mixtos? Ingrese data.table.

Además, las matrices, especialmente las matrices dispersas, a menudo se almacenan en una tupla de 3 columnas: `(i, j, valor)`. Esto se puede considerar como un par clave-valor donde `i` y `j` forman una clave de 2 columnas. Si tenemos más de un valor, quizás de diferentes tipos, podría verse como `(i, j, val1, val2, val3, ...)`. Esto se parece mucho a un `data.frame`. Por lo tanto, data.table extiende `data.frame` de modo que un `data.frame` `X` puede ser subconjunto de un `data.frame` `Y`, lo que lleva a la sintaxis `X[Y]`.

## ¿Se puede cambiar la base para hacer esto, en lugar de un nuevo paquete?
`data.frame` se usa _en todas partes_ y por eso es muy difícil hacerle _algun_ cambio. data.table _hereda_ de `data.frame`. También _es_ un `data.frame`. Un data.table _se puede_ pasar a cualquier paquete que _solo_ acepte `data.frame`. Cuando ese paquete usa la sintaxis `[.data.frame` en el data.table, funciona. Funciona porque `[.data.table` busca ver desde dónde fue llamado. Si fue llamado desde un paquete así, `[.data.table` desvía a `[.data.frame`.

## He oído que la sintaxis data.table es análoga a SQL.
Sí:

 - `i` $\Leftrightarrow$ donde
 - `j` $\Leftrightarrow$ seleccionar
 - `:=` $\Leftrightarrow$ actualizar
 - `por` $\Leftrightarrow$ agrupar por
 - `i` $\Leftrightarrow$ ordenar por (en sintaxis compuesta)
 - `i` $\Leftrightarrow$ tener (en sintaxis compuesta)
 - `nomatch = NA` $\Leftrightarrow$ unión externa
 - `nomatch = NULL` $\Leftrightarrow$ unión interna
 - `mult = "first"|"last"` $\Leftrightarrow$ N/A porque SQL es inherentemente desordenado
 - `roll = TRUE` $\Leftrightarrow$ N/A porque SQL es inherentemente desordenado

La forma general es:

```r
DT[where, select|update, group by][order by][...] ... [...]
```

Una ventaja clave de los vectores de columna en R es que están _ordenados_, a diferencia de SQL[^2]. Podemos usar funciones ordenadas en consultas `data.table` como `diff()` y podemos usar _cualquier_ función de R de cualquier paquete, no solo las funciones que están definidas en SQL. Una desventaja es que los objetos de R deben caber en la memoria, pero con varios paquetes de R como `ff`, `bigmemory`, `mmap` e `indexing`, esto está cambiando.

[^2]: Puede resultar sorprendente saber que `select top 10 * from ...` no devuelve de manera confiable las mismas filas a lo largo del tiempo en SQL. Debe incluir una cláusula `order by` o usar un índice agrupado para garantizar el orden de las filas; es decir, SQL es inherentemente desordenado.

## ¿Cuáles son las diferencias de sintaxis más pequeñas entre `data.frame` y data.table? {#SmallerDiffs}

 - `DT[3]` se refiere a la 3ra _fila_, pero `DF[3]` se refiere a la 3ra _columna_
 - `DT[3, ] == DT[3]`, pero `DF[ , 3] == DF[3]` (de manera algo confusa en data.frame, mientras que data.table es consistente)
 - Por esta razón decimos que la coma es _opcional_ en `DT`, pero no opcional en `DF`
 - `DT[[3]] == DF[, 3] == DF[[3]]`
 - `DT[i, ]`, donde `i` es un solo entero, devuelve una sola fila, al igual que `DF[i, ]`, pero a diferencia de un subconjunto de una sola fila de la matriz que devuelve un vector.
 - `DT[ , j]` donde `j` es un entero único, devuelve un data.table de una columna, a diferencia de `DF[, j]` que devuelve un vector de forma predeterminada
 - `DT[ , "colA"][[1]] == DF[ , "colA"]`.
 - `DT[ , colA] == DF[ , "colA"]` (actualmente en data.table v1.9.8 pero está a punto de cambiar, consulte las notas de la versión)
 - `DT[ , list(colA)] == DF[ , "colA", drop = FALSE]`
 - `DT[NA]` devuelve 1 fila de `NA`, pero `DF[NA]` devuelve una copia completa de `DF` que contiene `NA` en todas partes. El símbolo `NA` es de tipo `lógico` en R y, por lo tanto, `[.data.frame` lo recicla. La intención del usuario probablemente era `DF[NA_integer_]`. `[.data.table` desvía a esta intención probable automáticamente, para mayor comodidad.
 - `DT[c(TRUE, NA, FALSE)]` trata a `NA` como `FALSE`, pero `DF[c(TRUE, NA, FALSE)]` devuelve===== `NA` filas para cada `NA` ===== - `DT[ColA == ColB]` es más simple que `DF[!is.na(ColA) & !is.na(ColB) & ColA == ColB, ]`
 - `data.frame(list(1:2, "k", 1:4))` crea 3 columnas, data.table crea una columna `list`.
 - `check.names` es por defecto `TRUE` en `data.frame` pero `FALSE` en data.table, para mayor comodidad.
 - `data.table` siempre ha establecido `stringsAsFactors=FALSE` de forma predeterminada. En R 4.0.0 (abril de 2020), el valor predeterminado de `data.frame` se cambió de `TRUE` a `FALSE` y ya no hay ninguna diferencia en este sentido; - Los vectores atómicos en las columnas de `list` se contraen cuando se imprimen usando `", "` en `data.frame`, pero `","` en data.table con una coma final después del sexto elemento para evitar la impresión accidental de objetos incrustados grandes.
 - A diferencia de data.frames, un data.table no puede almacenar filas sin columnas, ya que las filas se consideran hijas de las columnas: `nrow(DF[, 0])` devuelve el número de filas, mientras que `nrow(DT[, 0])` siempre devuelve 0; pero vea el problema [#2422](https://github.com/Rdatatable/data.table/issues/2422).

En `[.data.frame`, a menudo configuramos `drop = FALSE`. Cuando nos olvidamos, pueden surgir errores en casos extremos en los que se seleccionan columnas individuales y, de repente, se devuelve un vector en lugar de una sola columna `data.frame`. En `[.data.table`, aprovechamos la oportunidad para hacerlo coherente y eliminamos `drop`.

Cuando se pasa un data.table a un paquete que no es compatible con data.table, ese paquete no se preocupa por ninguna de estas diferencias; simplemente funciona.

## Estoy usando `j` solo por su efecto secundario, pero aún así obtengo datos. ¿Cómo puedo detenerlo?

En este caso, `j` se puede envolver con `invisible()`; por ejemplo, `DT[ , invisible(hist(colB)), by = colA]`[^3]

[^3]: _p. ej._, `hist()` devuelve los puntos de interrupción además de trazar en el dispositivo gráfico.

## ¿Por qué `[.data.table` ahora tiene un argumento `drop` desde v1.5?

Para que data.table pueda heredar de `data.frame` sin usar `...`. Si usáramos `...`, no se detectarían los nombres de argumentos no válidos.

El argumento `drop` nunca lo utiliza `[.data.table`. Es un marcador de posición para paquetes que no son compatibles con data.table cuando utilizan la sintaxis `[.data.frame` directamente en un data.table.

## ¡Las uniones continuas son geniales y muy rápidas! ¿Fue difícil programarlas?
De todos modos, la fila que prevalece sobre la fila `i` o antes es la fila final que prueba la búsqueda binaria. Por lo tanto, `roll = TRUE` es básicamente un cambio en el código C de búsqueda binaria para devolver esa fila.

## ¿Por qué `DT[i, col := value]` devuelve el `DT` completo? No esperaba ningún valor visible (coherente con `<-`), o un mensaje o valor de retorno que contenga cuántas filas se actualizaron. No es obvio que los datos hayan sido efectivamente actualizados por referencia.

Esto ha cambiado en la versión 1.8.3 para cumplir con tus expectativas. Actualiza.

Se devuelve la totalidad de `DT` (ahora de forma invisible) para que la sintaxis compuesta pueda funcionar; por ejemplo, `DT[i, done := TRUE][ , sum(done)]`. La cantidad de filas actualizadas se devuelve cuando `verbose` es `TRUE`, ya sea por consulta o de forma global mediante `options(datatable.verbose = TRUE)`.

## Vale, gracias. ¿Qué tenía de difícil que el resultado de `DT[i, col := value]` se devolviera de forma invisible?
R activa internamente la visibilidad para `[`. El valor de la columna eval de FunTab (ver [src/main/names.c](https://github.com/wch/r-source/blob/trunk/src/main/names.c)) para `[` es `0`, lo que significa que "activar `R_Visible`" (ver [R-Internals sección 1.6](https://cran.r-project.org/doc/manuals/r-release/R-ints.html#Autoprinting)). Por lo tanto, cuando probamos `invisible()` o configuramos `R_Visible` en `0` directamente nosotros mismos, `eval` en [src/main/eval.c](https://github.com/wch/r-source/blob/trunk/src/main/eval.c) lo activaría nuevamente.

Para resolver este problema, la clave fue dejar de intentar detener la ejecución del método de impresión después de un `:=`. En cambio, dentro de `:=` ahora (a partir de la versión 1.8.3) configuramos un indicador global que el método de impresión usa para saber si realmente debe imprimir o no.

## ¿Por qué a veces tengo que escribir `DT` dos veces después de usar `:=` para imprimir el resultado en la consola?

Este es un inconveniente desafortunado para que [#869](https://github.com/Rdatatable/data.table/issues/869) funcione. Si se usa un `:=` dentro de una función sin `DT[]` antes del final de la función, entonces la próxima vez que se escriba `DT` en el indicador, no se imprimirá nada. Se imprimirá un `DT` repetido. Para evitar esto: incluya un `DT[]` después del último `:=` en su función. Si eso no es posible (por ejemplo, no es una función que puede cambiar), entonces se garantiza que se imprimirán `print(DT)` y `DT[]` en el indicador. Como antes, agregar un `[]` adicional al final de la consulta `:=` es un modismo recomendado para actualizar y luego imprimir; por ejemplo, `DT[,foo:=3L][]`.

## He observado que `base::cbind.data.frame` (y `base::rbind.data.frame`) parecen haber sido modificados por data.table. ¿Cómo es posible? ¿Por qué?

Fue una solución temporal, de último recurso, antes de que se solucionara el envío de métodos S3 de rbind y cbind en R >= 4.0.0. Básicamente, el problema era que `data.table` hereda de `data.frame`, _y_ `base::cbind` y `base::rbind` (de manera única) realizan su propio envío S3 internamente, como lo documenta `?cbind`. La solución alternativa de `data.table` fue agregar un bucle `for` al comienzo de cada función directamente en `base`. Esa modificación se realizó de manera dinámica, _es decir_, se obtuvo la definición `base` de `cbind.data.frame`, se agregó el bucle `for` al comienzo y luego se asignó nuevamente a `base`. Esta solución fue diseñada para ser robusta ante diferentes definiciones de `base::cbind.data.frame` en diferentes versiones de R, incluidos cambios futuros desconocidos. Funcionó bien. Los requisitos en competencia fueron:

 - `cbind(DT, DF)` debe funcionar. La definición de `cbind.data.table` no funcionó porque `base::cbind` realiza su propio envío S3 y requería (antes de R 4.0.0) que el _primer_ método `cbind` para cada objeto que se le pasa sea _idéntico_. Esto no es cierto en `cbind(DT, DF)` porque el primer método para `DT` es `cbind.data.table` pero el primer método para `DF` es `cbind.data.frame`. `base::cbind` luego pasó a su código `bind` interno que parece tratar a `DT` como una `lista` regular y devuelve una salida `matrix` de aspecto muy extraño e inutilizable. Consulte [a continuación](#cbinderror). No podemos simplemente recomendar a los usuarios que no llamen a `cbind(DT, DF)` porque paquetes como `ggplot2` hacen dicha llamada ([prueba 167.2](https://github.com/Rdatatable/data.table/blob/master/inst/tests/tests.Rraw#L444-L447)).

 - Esto naturalmente llevó a intentar enmascarar `cbind.data.frame` en su lugar. Dado que un data.table es un `data.frame`, `cbind` encontraría el mismo método tanto para `DT` como para `DF`. Sin embargo, esto tampoco funcionó porque `base::cbind` parece encontrar métodos en `base` primero; _es decir_, `base::cbind.data.frame` no se puede enmascarar.

 - Finalmente, intentamos enmascarar `cbind` en sí (v1.6.5 y v1.6.6). Esto permitió que `cbind(DT, DF)` funcionara, pero introdujo problemas de compatibilidad con el paquete `IRanges`, ya que `IRanges` también enmascara `cbind`. Funcionó si `IRanges` estaba más abajo en la ruta `search()` que data.table, pero si `IRanges` estaba más arriba que data.table, `cbind` nunca se llamaría y la salida de `matrix` de aspecto extraño se produciría nuevamente (ver [a continuación](#cbinderror)).

Muchas gracias al equipo central de R por solucionar el problema en septiembre de 2019. data.table v1.12.6+ ya no aplica la solución alternativa en R >= 4.0.0.

## He leído sobre el envío de métodos (por ejemplo, `merge` puede o no enviarse a `merge.data.table`) pero ¿cómo sabe R cómo enviarlos? ¿Los puntos son importantes o especiales? ¿Cómo sabe R qué función enviar y cuándo? {#r-dispatch}

Esto se menciona con mucha frecuencia, pero es realmente muy simple. Una función como `merge` es _genérica_ si consiste en una llamada a `UseMethod`. Cuando ves a gente hablando sobre si las funciones son o no funciones _genéricas_, simplemente están escribiendo la función sin `()` después, mirando el código del programa dentro de ella y si ven una llamada a `UseMethod` entonces es _genérica_. ¿Qué hace `UseMethod`? Literalmente junta el nombre de la función con la clase del primer argumento, separados por un punto (`.`) y luego llama a esa función, pasando los mismos argumentos. Es así de simple. Por ejemplo, `merge(X, Y)` contiene una llamada a `UseMethod`, lo que significa que luego _despacha_ (es decir, llama) a `paste("merge", class(X), sep = ".")`. Las funciones con puntos en su nombre pueden ser métodos o no. El punto es realmente irrelevante, más allá de que el punto es el separador que utiliza `UseMethod`. Conocer estos antecedentes debería ahora resaltar por qué, por ejemplo, es obvio para la gente de R que `as.data.table.data.frame` es el método `data.frame` para la función genérica `as.data.table`. Además, puede ayudar a aclarar que, sí, tienes razón, no es obvio solo por su nombre que `ls.fit` no sea el método fit de la función genérica `ls`. Solo puedes saberlo escribiendo `ls` (no `ls()`) y observando que no es una sola llamada a `UseMethod`.

Ahora te preguntarás: ¿dónde está documentado esto en R? Respuesta: está bastante claro, pero primero debes saber que debes buscar en `?UseMethod` y _ese_ archivo de ayuda contiene:

> Cuando se aplica una función que llama a `UseMethod('fun')` a un objeto con el atributo de clase `c('first', 'second')`, el sistema busca una función llamada `fun.first` y, si la encuentra, la aplica al objeto. Si no se encuentra dicha función, se intenta una función llamada `fun.second`. Si ningún nombre de clase produce una función adecuada, se utiliza la función `fun.default`, si existe, o se produce un error.

Afortunadamente, una búsqueda en Internet de "Cómo funciona el envío de métodos R" (en el momento de escribir este artículo) devuelve la página de ayuda "UseMethod" entre los primeros enlaces. Es cierto que otros enlaces descienden rápidamente a las complejidades de S3 vs. S4, genéricos internos, etc.

Sin embargo, características como el envío básico de S3 (pegar el nombre de la función junto con el nombre de la clase) es la razón por la que a algunas personas de R les encanta. Es muy simple. No se requiere ningún registro o firma complicados. No hay mucho que aprender. Para crear el método `merge` para data.table, todo lo que se requirió, literalmente, fue simplemente crear una función llamada `merge.data.table`.

## ¿Por qué `T` y `F` se comportan de manera diferente a `TRUE` y `FALSE` en algunas consultas `data.table`?

El uso de `T` y `F` como abreviaturas de `TRUE` y `FALSE` en `data.table` puede generar un comportamiento inesperado. Esto se debe a que `T` y `F` son variables globales que se pueden redefinir, lo que hace que se las trate como nombres de variables en lugar de como constantes lógicas. Este problema no ocurre con `TRUE` y `FALSE`. Se recomienda evitar `T` y `F` para usar R en general, pero aparece en `data.table` de formas quizás sorprendentes, por ejemplo:

```r
DT <- data.table(x=rep(c("a", "b", "c"), each = 3), y=c(1, 3, 6), v=1:9)

# Using TRUE/FALSE works as expected in cases like the ones below:

DT[, .SD, .SDcols=c(TRUE, TRUE, FALSE)]
# A) This selects the first two columns (x and y) and excludes the third one (v). Output:
#>    x y
#> 1: a 1
#> 2: a 3
#> 3: a 6
#> 4: b 1
#> 5: b 3
#> 6: b 6
#> 7: c 1
#> 8: c 3
#> 9: c 6

DT[, .SD, .SDcols=c(T, T, F), with=FALSE]
# B) This forces data.table to treat T/F as logical constants.
# Same output as DT[, .SD, .SDcols=c(TRUE, TRUE, FALSE)]

# But, using T/F may lead to unexpected behavior in cases like:

DT[, .SD, .SDcols=c(T, T, F)]
# data.table treats T and F as variable names here, not logical constants. Output:
#> Detected that j uses these columns: <none>
#> [1]  TRUE  TRUE FALSE
```

Como consejo general, `lintr::T_and_F_symbol_linter()` detecta el uso de `T` y `F` y sugiere reemplazarlos con `TRUE` y `FALSE` para evitar tales problemas.

# Preguntas relacionadas con el tiempo de cómputo

## Tengo 20 columnas y una gran cantidad de filas. ¿Por qué una expresión de una columna es tan rápida?

Varias razones:

 - Solo se agrupa esa columna, las otras 19 se ignoran porque data.table inspecciona la expresión `j` y se da cuenta de que no usa las otras columnas.
 - Se realiza una asignación de memoria solo para el grupo más grande, luego esa memoria se reutiliza para los otros grupos. Hay muy poca basura para recolectar.
 - R es un almacén de columnas en memoria; es decir, las columnas son contiguas en RAM. Se minimizan las recuperaciones de páginas desde la RAM hacia la caché L2.

## No tengo una "clave" en una tabla grande, pero aun así la agrupación es muy rápida. ¿Por qué?

data.table utiliza ordenación por radio. Esto es significativamente más rápido que otros algoritmos de ordenación. Consulte [nuestras presentaciones](https://github.com/Rdatatable/data.table/wiki/Presentations) para obtener más información, en particular la de useR!2015 Dinamarca.

Esta es también una razón por la que `setkey()` es rápido.

Cuando no se establece ninguna `clave`, o agrupamos en un orden diferente al de la clave, lo llamamos un `por` _ad hoc_.

## ¿Por qué la agrupación por columnas en la clave es más rápida que un `por` _ad hoc_?

Debido a que cada grupo es contiguo en la RAM, se minimizan las recuperaciones de páginas y la memoria se puede copiar en masa (`memcpy` en C) en lugar de realizar un bucle en C.

## ¿Qué son los índices primarios y secundarios en data.table?

Manual: [`?setkey`](https://www.rdocumentation.org/packages/data.table/functions/setkey) SO: [¿Cuál es el propósito de configurar una clave en data.table?](https://stackoverflow.com/questions/20039335/what-is-the-purpose-of-setting-a-key-in-data-table/20057411#20057411)

`setkey(DT, col1, col2)` ordena las filas por la columna `col1` y luego, dentro de cada grupo de `col1`, ordena por `col2`. Este es un _índice primario_. El orden de las filas se cambia _por referencia_ en la RAM. Las uniones y grupos posteriores en esas columnas clave aprovechan el orden de clasificación para lograr eficiencia. (Imagínese lo difícil que sería buscar un número de teléfono en una guía telefónica impresa si no estuviera ordenado por apellido y luego por nombre. Eso es literalmente todo lo que hace `setkey`. Ordena las filas por las columnas que especifique). El índice no utiliza ninguna RAM. Simplemente cambia el orden de las filas en la RAM y marca las columnas clave. Análogo a un _índice agrupado_ en SQL.

Sin embargo, solo puede tener una clave principal porque los datos solo se pueden ordenar físicamente en RAM de una manera a la vez. Elija el índice principal para que sea el que use con más frecuencia (por ejemplo, `[id, fecha]`). A veces no hay una opción obvia para la clave principal o necesita unir y agrupar muchas columnas diferentes en diferentes órdenes. Ingrese un índice secundario. Esto usa memoria (`4*nrow` bytes independientemente del número de columnas en el índice) para almacenar el orden de las filas por las columnas que especifique, pero en realidad no reordena las filas en RAM. Las uniones y grupos posteriores aprovechan el orden de la clave secundaria, pero necesitan _saltar_ a través de ese índice, por lo que no son tan eficientes como los índices primarios. Pero aún así, mucho más rápido que un escaneo vectorial completo. No hay límite para la cantidad de índices secundarios, ya que cada uno es solo un vector de ordenamiento diferente. Por lo general, no necesita crear índices secundarios. Se crean automáticamente y se usan automáticamente al usar data.table normalmente; _p. ej._ `DT[someCol == someVal, ]` y `DT[someCol %in% someVals, ]` crearán, adjuntarán y luego usarán el índice secundario. Esto es más rápido en data.table que un escaneo vectorial, por lo que la indexación automática está activada de manera predeterminada, ya que no hay una penalización inicial. Hay una opción para desactivar la indexación automática; _p. ej._, si de alguna manera se están creando muchos índices e incluso la cantidad relativamente pequeña de memoria adicional se vuelve demasiado grande.

Utilizamos las palabras _índice_ y _clave_ indistintamente.

# Mensajes de error
## "No se pudo encontrar la función `DT`"
Véase arriba [aquí](#DTremove1) y [aquí](#DTremove2).

## "argumento(s) no utilizado(s) (`MySum = sum(v)`)"

Este error es generado por `DT[ , MySum = sum(v)]`. Se pretendía `DT[ , .(MySum = sum(v))]`, o `DT[ , j = .(MySum = sum(v))]`.

## "`translateCharUTF8` debe llamarse en un `CHARSXP`"
Este error (y otros similares, por ejemplo, "`getCharCE` debe ser llamado en un `CHARSXP`") puede no tener nada que ver con los datos de caracteres o la configuración regional. En cambio, puede ser un síntoma de una corrupción de memoria anterior. Hasta la fecha, estos errores se han podido reproducir y solucionar (rápidamente). Por favor, repórtelo a nuestro [seguidor de problemas](https://github.com/Rdatatable/data.table/issues).

## `cbind(DT, DF)` devuelve un formato extraño, _p. ej._ `Integer,5` {#cbinderror}

Esto ocurre antes de la versión 1.6.5, también para `rbind(DT, DF)`. Actualice a la versión 1.6.7 o posterior.

## "No se puede cambiar el valor del enlace bloqueado para `.SD`"

`.SD` está bloqueado por diseño. Consulte `?data.table`. Si desea manipular `.SD` antes de usarlo o devolverlo y no desea modificar `DT` utilizando `:=`, primero haga una copia (consulte `?copy`), _por ejemplo_,


``` r
DT = data.table(a = rep(1:3, 1:3), b = 1:6, c = 7:12)
DT
#        a     b     c
#    <int> <int> <int>
# 1:     1     1     7
# 2:     2     2     8
# 3:     2     3     9
# 4:     3     4    10
# 5:     3     5    11
# 6:     3     6    12
DT[ , { mySD = copy(.SD)
      mySD[1, b := 99L]
      mySD},
    by = a]
#        a     b     c
#    <int> <int> <int>
# 1:     1    99     7
# 2:     2    99     8
# 3:     2     3     9
# 4:     3    99    10
# 5:     3     5    11
# 6:     3     6    12
```

## "No se puede cambiar el valor del enlace bloqueado para `.N`"

Actualice a la versión 1.8.1 o posterior. A partir de esta versión, si `.N` se devuelve mediante `j`, se le cambia el nombre a `N` para evitar cualquier ambigüedad en cualquier agrupación posterior entre la variable especial `.N` y una columna denominada `".N"`.

El comportamiento anterior se puede reproducir forzando a que `.N` se llame `.N`, de la siguiente manera:

``` r
DT = data.table(a = c(1,1,2,2,2), b = c(1,2,2,2,1))
DT
#        a     b
#    <num> <num>
# 1:     1     1
# 2:     1     2
# 3:     2     2
# 4:     2     2
# 5:     2     1
DT[ , list(.N = .N), list(a, b)]   # show intermediate result for exposition
#        a     b    .N
#    <num> <num> <int>
# 1:     1     1     1
# 2:     1     2     1
# 3:     2     2     2
# 4:     2     1     1
cat(try(
    DT[ , list(.N = .N), by = list(a, b)][ , unique(.N), by = a]   # compound query more typical
, silent = TRUE))
# Error in `[.data.table`(DT[, list(.N = .N), by = list(a, b)], , unique(.N),  : 
#   La columna '.N' no se puede agrupar porque entra en conflicto con la variable especial .N. Pruebe setnames(DT,'.N','N') primero.
```

Si ya está ejecutando v1.8.1 o posterior, entonces el mensaje de error ahora es más útil que el error "no se puede cambiar el valor del enlace bloqueado", como puede ver arriba, ya que esta viñeta se produjo usando v1.8.1 o posterior.

Ahora funciona la sintaxis más natural:

``` r
if (packageVersion("data.table") >= "1.8.1") {
    DT[ , .N, by = list(a, b)][ , unique(N), by = a]
  }
#        a    V1
#    <num> <int>
# 1:     1     1
# 2:     2     2
# 3:     2     1
if (packageVersion("data.table") >= "1.9.3") {
    DT[ , .N, by = .(a, b)][ , unique(N), by = a]   # same
}
#        a    V1
#    <num> <int>
# 1:     1     1
# 2:     2     2
# 3:     2     1
```

# Mensajes de advertencia
## "Los siguientes objetos están enmascarados de `paquete:base`: `cbind`, `rbind`"

Esta advertencia solo estaba presente en las versiones v1.6.5 y v1.6.6, al cargar el paquete. La motivación era permitir que `cbind(DT, DF)` funcionara, pero, como se vio, esto rompió la compatibilidad (total) con el paquete `IRanges`. Actualice a la versión v1.6.7 o posterior.

## "Se convirtió el RHS numérico a entero para que coincida con el tipo de la columna"

Con suerte, esto se explicará por sí solo. El mensaje completo es:

Se ha convertido el RHS numérico en entero para que coincida con el tipo de columna; puede tener precisión truncada. Cambie la columna a numérica primero creando usted mismo un nuevo vector numérico de longitud 5 (nfilas de toda la tabla) y asígnelo (es decir, "reemplazar" la columna), o convierta usted mismo el RHS en entero (por ejemplo, 1L o as.integer) para que su intención quede clara (y para acelerar). O bien, configure el tipo de columna correctamente desde el principio cuando cree la tabla y cúmplalo, por favor.


Para generarlo, prueba:


``` r
DT = data.table(a = 1:5, b = 1:5)
suppressWarnings(
DT[2, b := 6]         # works (slower) with warning
)
#        a     b
#    <int> <int>
# 1:     1     1
# 2:     2     6
# 3:     3     3
# 4:     4     4
# 5:     5     5
class(6)              # numeric not integer
# [1] "numeric"
DT[2, b := 7L]        # works (faster) without warning
#        a     b
#    <int> <int>
# 1:     1     1
# 2:     2     7
# 3:     3     3
# 4:     4     4
# 5:     5     5
class(7L)             # L makes it an integer
# [1] "integer"
DT[ , b := rnorm(5)]  # 'replace' integer column with a numeric column
#        a          b
#    <int>      <num>
# 1:     1  0.2569706
# 2:     2  1.1985953
# 3:     3 -0.8928224
# 4:     4 -1.5378607
# 5:     5 -0.8016711
```

## Lectura de data.table desde un archivo RDS o RData

`*.RDS` y `*.RData` son tipos de archivos que pueden almacenar objetos R en memoria en el disco de manera eficiente. Sin embargo, al almacenar data.table en el archivo binario se pierde la sobreasignación de columnas. Esto no es un gran problema: su data.table se copiará en la memoria en la siguiente operación _por referencia_ y generará una advertencia. Por lo tanto, se recomienda llamar a `setalloccol()` en cada data.table cargado con llamadas `readRDS()` o `load()`.

# Preguntas generales sobre el paquete

## ¿Parece que la versión v1.3 falta en el archivo CRAN?
Es correcto. La versión 1.3 solo estaba disponible en R-Forge. Se realizaron varios cambios importantes a nivel interno y llevó un tiempo probarlos durante el desarrollo.

## ¿Es data.table compatible con S-plus?

No actualmente.

 - Algunas partes principales del paquete están escritas en C y utilizan funciones y estructuras internas de R.
 - El paquete utiliza alcance léxico, que es una de las diferencias entre R y **S-plus** explicadas en [R FAQ 3.3.1](https://cran.r-project.org/doc/FAQ/R-FAQ.html#Lexical-scoping)

## ¿Está disponible para Linux, Mac y Windows?
Sí, tanto para 32 bits como para 64 bits en todas las plataformas. Gracias a CRAN. No se utilizan bibliotecas especiales ni específicas de ningún sistema operativo.

## Me parece genial ¿Qué puedo hacer?
Envíe sugerencias, informes de errores y solicitudes de mejora a nuestro [seguimiento de problemas](https://github.com/Rdatatable/data.table/issues). Esto ayuda a mejorar el paquete.

Por favor, marque el paquete con una estrella en [GitHub](https://github.com/Rdatatable/data.table). Esto ayuda a alentar a los desarrolladores y ayuda a otros usuarios de R a encontrar el paquete.

Puede enviar solicitudes de extracción para cambiar el código y/o la documentación usted mismo; consulte nuestras [Pautas de contribución](https://github.com/Rdatatable/data.table/blob/master/.github/CONTRIBUTING.md).

## No me parece nada bueno. ¿Cómo puedo advertir a los demás sobre mi experiencia?

Agregamos todos los artículos que conocemos (ya sean positivos o negativos) a la página [Artículos](https://github.com/Rdatatable/data.table/wiki/Articles). Todas las páginas en la wiki del proyecto en GitHub son de acceso abierto sin restricciones de modificación. Siéntete libre de escribir un artículo, vincular a un artículo negativo que alguien más haya escrito y que hayas encontrado, o agregar una nueva página a nuestra wiki para recopilar tus críticas. Haz que sea constructiva para que tengamos la oportunidad de mejorar.

## Tengo una pregunta. Sé que la guía de publicación de R-Help me indica que me comunique con el encargado del mantenimiento (no con R-Help), pero ¿hay un grupo más grande de personas a quienes pueda preguntar?
Consulte la [guía de soporte](https://github.com/Rdatatable/data.table/wiki/Support) en la página de inicio del proyecto, que contiene enlaces actualizados.

## ¿Dónde están los archivos de ayuda de datatable?
La [página de inicio](https://github.com/Rdatatable/data.table/wiki) contiene enlaces a los archivos en varios formatos.

## Preferiría no publicar en la página de Problemas, ¿puedo enviar un correo electrónico privado a una o dos personas?
Por supuesto. Sin embargo, es más probable que obtengas una respuesta más rápida en la página de problemas o en Stack Overflow. Además, preguntar públicamente en esos lugares ayuda a construir la base de conocimiento general.

## He creado un paquete que utiliza data.table. ¿Cómo puedo asegurarme de que mi paquete sea compatible con data.table para que funcione la herencia de `data.frame`?

Por favor vea [esta respuesta](https://stackoverflow.com/a/10529888/403310).



