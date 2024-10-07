---
title: "Importing data.table"
date: "2024-10-07"
output:
  markdown::html_format
vignette: >
  %\VignetteIndexEntry{Importing data.table}
  %\VignetteEngine{knitr::knitr}
  \usepackage[utf8]{inputenc}
---

<style>
h2 {
    font-size: 20px;
}
</style>

Este documento se centra en el uso de `data.table` como dependencia en otros paquetes R. Si está interesado en utilizar el código C de `data.table` desde una aplicación que no sea R, o en llamar directamente a sus funciones C, salte a la [última sección](#non-r-api) de esta viñeta.

Importar `data.table` no es diferente a importar otros paquetes R. Esta viñeta tiene como objetivo responder las preguntas más comunes que surgen en torno a ese tema; las lecciones presentadas aquí se pueden aplicar a otros paquetes R.

## ¿Por qué importar `data.table`?

Una de las principales características de `data.table` es su sintaxis concisa, que hace que el análisis exploratorio sea más rápido y más fácil de escribir y percibir; esta conveniencia puede impulsar a los autores de paquetes a utilizar `data.table`. Otra razón, quizás más importante, es el alto rendimiento. Al externalizar tareas informáticas pesadas de su paquete a `data.table`, generalmente obtiene el máximo rendimiento sin necesidad de reinventar ninguno de estos trucos de optimización numérica por su cuenta.

## Importar `data.table` es fácil

Es muy fácil usar `data.table` como una dependencia debido al hecho de que `data.table` no tiene ninguna dependencia propia. Esto se aplica tanto al sistema operativo como a las dependencias de R. Significa que si tiene R instalado en su máquina, ya tiene todo lo necesario para instalar `data.table`. También significa que agregar `data.table` como una dependencia de su paquete no resultará en una cadena de otras dependencias recursivas para instalar, lo que lo hace muy conveniente para la instalación fuera de línea.

## Archivo `DESCRIPTION` {#DESCRIPTION}

El primer lugar para definir una dependencia en un paquete es el archivo `DESCRIPTION`. Lo más común es que deba agregar `data.table` en el campo `Imports:`. Para ello, será necesario instalar `data.table` antes de que su paquete pueda compilarse/instalarse. Como se mencionó anteriormente, no se instalarán otros paquetes porque `data.table` no tiene ninguna dependencia propia. También puede especificar la versión mínima requerida de una dependencia; por ejemplo, si su paquete usa la función `fwrite`, que se introdujo en `data.table` en la versión 1.9.8, debe incorporarla como `Imports: data.table (>= 1.9.8)`. De esta manera, puede asegurarse de que la versión de `data.table` instalada sea 1.9.8 o posterior antes de que sus usuarios puedan instalar su paquete. Además del campo `Imports:`, también puede utilizar `Depends: data.table`, pero desaconsejamos enfáticamente este enfoque (y es posible que no lo permitamos en el futuro) porque esto carga `data.table` en el espacio de trabajo de su usuario; es decir, habilita la funcionalidad `data.table` en los scripts de su usuario sin que lo soliciten. `Imports:` es la forma correcta de utilizar `data.table` dentro de su paquete sin infligir `data.table` a su usuario. De hecho, esperamos que el campo `Depends:` quede obsoleto en R, ya que esto es cierto para todos los paquetes.

## Archivo `NAMESPACE` {#NAMESPACE}

El siguiente paso es definir qué contenido de `data.table` está usando tu paquete. Esto debe hacerse en el archivo `NAMESPACE`. Lo más común es que los autores de paquetes quieran usar `import(data.table)`, que importará todas las funciones exportadas (es decir, las que se enumeran en el archivo `NAMESPACE` de `data.table`) desde `data.table`.

También es posible que desee utilizar solo un subconjunto de funciones de `data.table`; por ejemplo, algunos paquetes pueden simplemente hacer uso del lector y escritor CSV de alto rendimiento de `data.table`, para lo cual puede agregar `importFrom(data.table, fread, fwrite)` en su archivo `NAMESPACE`. También es posible importar todas las funciones de un paquete _excluyendo_ algunas en particular usando `import(data.table, except=c(fread, fwrite))`.

Asegúrese de leer también la nota sobre la evaluación no estándar en `data.table` en [la sección sobre "globales indefinidos"](#globals)

## Uso

Como ejemplo, definiremos dos funciones en el paquete `a.pkg` que utiliza `data.table`. Una función, `gen`, generará un `data.table` simple; otra, `aggr`, realizará una agregación simple de este.

```r
gen = function (n = 100L) {
  dt = as.data.table(list(id = seq_len(n)))
  dt[, grp := ((id - 1) %% 26) + 1
     ][, grp := letters[grp]
       ][]
}
aggr = function (x) {
  stopifnot(
    is.data.table(x),
    "grp" %in% names(x)
  )
  x[, .N, by = grp]
}
```

## Pruebas

Asegúrese de incluir pruebas en su paquete. Antes de cada lanzamiento importante de `data.table`, verificamos las dependencias inversas. Esto significa que si algún cambio en `data.table` pudiera afectar su código, podremos detectar los cambios que afecten su código e informarle antes de lanzar la nueva versión. Por supuesto, esto supone que publicará su paquete en CRAN o Bioconductor. La prueba más básica puede ser un script R de texto simple en el directorio de su paquete `tests/test.R`:

```r
library(a.pkg)
dt = gen()
stopifnot(nrow(dt) == 100)
dt2 = aggr(dt)
stopifnot(nrow(dt2) < 100)
```

Al probar su paquete, puede utilizar `R CMD check --no-stop-on-test-error`, que continuará después de un error y ejecutará todas sus pruebas (en lugar de detenerse en la primera línea del script que falló). NB esto requiere R 3.4.0 o superior.

## Pruebas usando `testthat`

Es muy común utilizar el paquete `testthat` para realizar pruebas. Probar un paquete que importa `data.table` no es diferente de probar otros paquetes. Un ejemplo de script de prueba `tests/testthat/test-pkg.R`:

```r
context("pkg tests")

test_that("generate dt", { expect_true(nrow(gen()) == 100) })
test_that("aggregate dt", { expect_true(nrow(aggr(gen())) < 100) })
```

Si `data.table` está en Sugerencias (pero no en Importaciones), entonces necesita declarar `.datatable.aware=TRUE` en uno de los archivos R/* para evitar errores de "objeto no encontrado" al realizar pruebas a través de `testthat::test_package` o `testthat::test_check`.

## Cómo manejar "funciones o variables globales no definidas" {#globals}

El uso que hace `data.table` de la evaluación diferida de R (especialmente en el lado izquierdo de `:=`) no es bien reconocido por `R CMD check`. Esto da como resultado `NOTE`s como el siguiente durante la verificación del paquete:

```
* checking R code for possible problems ... NOTE
aggr: no visible binding for global variable 'grp'
gen: no visible binding for global variable 'grp'
gen: no visible binding for global variable 'id'
Undefined global functions or variables:
grp id
```

La forma más sencilla de solucionar este problema es predefinir esas variables dentro del paquete y configurarlas como `NULL`, agregando opcionalmente un comentario (como se hace en la versión refinada de `gen` a continuación). Cuando sea posible, también puede utilizar un vector de caracteres en lugar de símbolos (como en `aggr` a continuación):

```r
gen = function (n = 100L) {
  id = grp = NULL # due to NSE notes in R CMD check
  dt = as.data.table(list(id = seq_len(n)))
  dt[, grp := ((id - 1) %% 26) + 1
     ][, grp := letters[grp]
       ][]
}
aggr = function (x) {
  stopifnot(
    is.data.table(x),
    "grp" %in% names(x)
  )
  x[, .N, by = "grp"]
}
```

El caso de los símbolos especiales de `data.table` (por ejemplo, `.SD` y `.N`) y el operador de asignación (`:=`) es ligeramente diferente (consulte `?.N` para obtener más información, incluida una lista completa de dichos símbolos). Debe importar cualquiera de estos valores que utilice desde el espacio de nombres de `data.table` para protegerse contra cualquier problema que surja del escenario poco probable de que cambiemos el valor exportado de estos en el futuro, por ejemplo, si desea utilizar `.N`, `.I` y `:=`, un `NAMESPACE` mínimo tendría:

```r
importFrom(data.table, .N, .I, ':=')
```

Mucho más simple es simplemente usar `import(data.table)` que permitirá el uso en el código de su paquete de cualquier objeto exportado desde `data.table`.

Si no le importa tener `id` y `grp` registrados como variables globales en el espacio de nombres de su paquete, puede usar `?globalVariables`. Tenga en cuenta que estas notas no tienen ningún impacto en el código ni en su funcionalidad; si no va a publicar su paquete, puede simplemente optar por ignorarlas.

## Se debe tener cuidado al proporcionar y utilizar opciones

Una práctica común de los paquetes R es proporcionar opciones de personalización establecidas por `options(name=val)` y obtenidas usando `getOption("name", default)`. Los argumentos de función a menudo especifican una llamada a `getOption()` para que el usuario sepa (desde `?fun` o `args(fun)`) el nombre de la opción que controla el valor predeterminado para ese parámetro; por ejemplo, `fun(..., verbose=getOption("datatable.verbose", FALSE))`. Todas las opciones de `data.table` comienzan con `datatable.` para no entrar en conflicto con las opciones de otros paquetes. Un usuario simplemente llama a `options(datatable.verbose=TRUE)` para activar la verbosidad. Esto afecta a todas las llamadas de función data.table a menos que `verbose=FALSE` se proporcione explícitamente; por ejemplo, `fun(..., verbose=FALSE)`.

El mecanismo de opciones en R es _global_. Lo que significa que si un usuario establece una opción `data.table` para su propio uso, esa configuración también afecta al código dentro de cualquier paquete que también esté usando `data.table`. Para una opción como `datatable.verbose`, este es exactamente el comportamiento deseado ya que el deseo es rastrear y registrar todas las operaciones de `data.table` desde donde sea que se originen; activar la verbosidad no afecta los resultados. Otra opción exclusiva de R y excelente para producción es `options(warn=2)` de R que convierte todas las advertencias en errores. Nuevamente, el deseo es afectar cualquier advertencia en cualquier paquete para no perder ninguna advertencia en producción. Hay 6 opciones `datatable.print.*` y 3 opciones de optimización que no afectan el resultado de las operaciones. Sin embargo, hay una opción `data.table` que sí afecta y ahora es una preocupación: `datatable.nomatch`. Esta opción cambia la unión predeterminada de externa a interna. [Aparte, la unión predeterminada es externa porque externa es más segura; [No elimina los datos faltantes de forma silenciosa; además, es coherente con la forma básica de R de hacer coincidir por nombres e índices.] Algunos usuarios prefieren que la unión interna sea la opción predeterminada y les proporcionamos esta opción. Sin embargo, un usuario que configure esta opción puede cambiar involuntariamente el comportamiento de las uniones dentro de los paquetes que usan `data.table`. En consecuencia, en v1.12.4 (octubre de 2019) se imprimía un mensaje cuando se usaba la opción `datatable.nomatch` y, a partir de v1.14.2, ahora se ignora con una advertencia. Era la única opción `data.table` con este problema.

## Solución de problemas

Si enfrenta algún problema al crear un paquete que usa data.table, confirme que el problema se pueda reproducir en una sesión R limpia usando la consola R: `R CMD check package.name`.

Algunos de los problemas más comunes a los que se enfrentan los desarrolladores suelen estar relacionados con herramientas auxiliares que están pensadas para automatizar algunas tareas de desarrollo de paquetes, por ejemplo, usar `roxygen` para generar el archivo `NAMESPACE` a partir de los metadatos de los archivos de código R. Otros están relacionados con las herramientas auxiliares que compilan y comprueban el paquete. Desafortunadamente, estas herramientas auxiliares a veces tienen efectos secundarios no deseados u ocultos que pueden ocultar el origen de los problemas. Por lo tanto, asegúrese de volver a comprobarlo usando la consola R (ejecute R en la línea de comandos) y asegúrese de que la importación esté definida en los archivos `DESCRIPTION` y `NAMESPACE` siguiendo las [instrucciones](#DESCRIPTION) [arriba](#NAMESPACE).

Si no puede reproducir los problemas que tiene al usar la compilación y verificación de la consola R simple, puede intentar obtener ayuda en función de los problemas anteriores que hemos encontrado con la interacción de `data.table` con las herramientas auxiliares: [devtools#192](https://github.com/r-lib/devtools/issues/192) o [devtools#1472](https://github.com/r-lib/devtools/issues/1472).

## Licencia

Desde la versión 1.10.5, `data.table` tiene licencia pública de Mozilla (MPL). Las razones del cambio de GPL se deben leer en su totalidad [aquí](https://github.com/Rdatatable/data.table/pull/2456) y se puede leer más sobre MPL en Wikipedia [aquí](https://en.wikipedia.org/wiki/Mozilla_Public_License) y [aquí](https://en.wikipedia.org/wiki/Comparison_of_free_and_open-source_software_licenses).

## Importe opcionalmente `data.table`: Sugiere

Si desea utilizar `data.table` de forma condicional, es decir, solo cuando esté instalado, debe utilizar `Suggests: data.table` en su archivo `DESCRIPTION` en lugar de utilizar `Imports: data.table`. De forma predeterminada, esta definición no forzará la instalación de `data.table` al instalar su paquete. Esto también requiere que utilice `data.table` de forma condicional en el código de su paquete, lo que debe hacerse utilizando la función `?requireNamespace`. El siguiente ejemplo demuestra el uso condicional del rápido escritor CSV `?fwrite` de `data.table`. Si el paquete `data.table` no está instalado, se utiliza en su lugar la función base R `?write.table`, mucho más lenta.

```r
my.write = function (x) {
  if(requireNamespace("data.table", quietly=TRUE)) {
    data.table::fwrite(x, "data.csv")
  } else {
    write.table(x, "data.csv")
  }
}
```

Una versión un poco más extendida de esto también garantizaría que la versión instalada de `data.table` sea lo suficientemente reciente como para tener la función `fwrite` disponible:

```r
my.write = function (x) {
  if(requireNamespace("data.table", quietly=TRUE) &&
    utils::packageVersion("data.table") >= "1.9.8") {
    data.table::fwrite(x, "data.csv")
  } else {
    write.table(x, "data.csv")
  }
}
```

Cuando se utiliza un paquete como dependencia sugerida, no se debe "importar" en el archivo "NAMESPACE". Solo hay que mencionarlo en el archivo "DESCRIPTION". Cuando se utilizan funciones "data.table" en el código del paquete (archivos R/*), se debe utilizar el prefijo "data.table::" porque ninguna de ellas se importa. Cuando se utiliza "data.table" en pruebas de paquetes (por ejemplo, archivos tests/testthat/test*), se debe declarar ".datatable.aware=TRUE" en uno de los archivos R/*.

## `data.table` en `Importaciones` pero no se importó nada

Algunos usuarios ([eg](https://github.com/Rdatatable/data.table/issues/2341)) pueden preferir evitar el uso de `importFrom` o `import` en su archivo `NAMESPACE` y en su lugar usar la calificación `data.table::` en todo el código interno (por supuesto, manteniendo `data.table` debajo de su `Imports:` en `DESCRIPTION`).

En este caso, la función no exportada `[.data.table` volverá a llamar a `[.data.frame` como medida de protección, ya que `[.data.table` no tiene forma de saber que el paquete principal es consciente de que está intentando realizar llamadas contra la sintaxis de la API de consulta de `[.data.table` (lo que podría generar un comportamiento inesperado ya que la estructura de las llamadas a `[.data.frame` y `[.data.table` difieren fundamentalmente, por ejemplo, este último tiene muchos más argumentos).

Si este es de todos modos su enfoque preferido para el desarrollo de paquetes, defina `.datatable.aware = TRUE` en cualquier parte de su código fuente R (sin necesidad de exportar). Esto le indica a `data.table` que usted, como desarrollador de paquetes, ha diseñado su código para que dependa intencionalmente de la funcionalidad de `data.table`, aunque puede que no sea obvio al inspeccionar su archivo `NAMESPACE`.

`data.table` determina sobre la marcha si la función que llama es consciente de que está accediendo a `data.table` con la función interna `cedta` (**C**alling **E**nvironment is **D**ata **T**able **A**ware), que, además de verificar `?getNamespaceImports` para su paquete, también verifica la existencia de esta variable (entre otras cosas).

## Más información sobre dependencias

Para obtener documentación más canónica sobre la definición de dependencias de paquetes, consulte el manual oficial: [Escritura de extensiones R](https://cran.r-project.org/doc/manuals/r-release/R-exts.html).

## Importación de rutinas data.table C

Algunas de las rutinas C utilizadas internamente ahora se exportan a nivel C, por lo que se pueden usar en paquetes R directamente desde su código C. Consulte [`?cdt`](https://rdatatable.gitlab.io/data.table/reference/cdt.html) para obtener detalles y la sección [Escritura de extensiones R](https://cran.r-project.org/doc/manuals/r-release/R-exts.html) _Enlace a rutinas nativas en otros paquetes_ para su uso.

## Importación desde aplicaciones que no son R {#non-r-api}

Algunas pequeñas partes del código C de `data.table` se aislaron de la API de RC y ahora se pueden usar desde aplicaciones que no sean de R mediante la vinculación a archivos .so / .dll. Más adelante se brindarán detalles más concretos sobre esto; por ahora, puede estudiar el código C que se aisló de la API de RC en [src/fread.c](https://github.com/Rdatatable/data.table/blob/master/src/fread.c) y [src/fwrite.c](https://github.com/Rdatatable/data.table/blob/master/src/fwrite.c).

## Cómo convertir su dependencia Depends en data.table a Imports

Para convertir una dependencia `Depends` de `data.table` en una dependencia `Imports` en su paquete, siga estos pasos:

### Paso 0. Asegúrese de que su paquete pase la verificación R CMD inicialmente

### Paso 1. Actualice el archivo DESCRIPCIÓN para colocar data.table en Importaciones, no en Dependencias

**Antes:**
```dcf
Depends:
    R (>= 3.5.0),
    data.table
Imports:
```

**Después:**
```dcf
Depends:
    R (>= 3.5.0)
Imports:
    data.table
```

### Paso 2.1: Ejecutar `R CMD check`

Ejecute `R CMD check` para identificar las importaciones o los símbolos faltantes. Este paso ayuda a:

- Detecta automáticamente cualquier función o símbolo de `data.table` que no se importe explícitamente.
- Marca los símbolos especiales faltantes como `.N`, `.SD` y `:=`.
- Proporciona comentarios inmediatos sobre lo que se debe agregar al archivo NAMESPACE.

Nota: No todos estos usos son detectados por `R CMD check`. En particular, `R CMD check` omite algunos símbolos/funciones en fórmulas y no detecta expresiones analizadas como `parse(text = "data.table(a = 1)")`. Los paquetes necesitarán una buena cobertura de pruebas para detectar estos casos extremos.

### Paso 2.2: Modificar el archivo NAMESPACE

Según los resultados de `R CMD check`, asegúrese de que se importen todas las funciones utilizadas, los símbolos especiales, los genéricos S3 y las clases S4 de `data.table`.

Esto significa agregar directivas `importFrom(data.table, ...)` para símbolos, funciones y genéricos de S3, y/o directivas `importClassesFrom(data.table, ...)` para clases de S4 según corresponda. Consulte "Cómo escribir extensiones de R" para obtener detalles completos sobre cómo hacerlo correctamente.

#### Importación de mantas

Como alternativa, puede importar todas las funciones de `data.table` a la vez, aunque esto generalmente no se recomienda:

```r
import(data.table)
```

**Justificación para evitar importaciones generales:** =====1. **Documentación**: El archivo NAMESPACE puede servir como buena documentación de cómo depende de ciertos paquetes.
2. **Evitar conflictos**: Las importaciones generales lo dejan expuesto a fallas sutiles. Por ejemplo, si `import(pkgA)` e `import(pkgB)`, pero luego pkgB exporta una función también exportada por pkgA, esto romperá su paquete debido a conflictos en su espacio de nombres, lo cual no está permitido por `R CMD check` y CRAN.=====

### Paso 3: Actualice los archivos de código R fuera del directorio R/ del paquete

Cuando mueves un paquete de `Depends` a `Imports`, ya no se adjuntará automáticamente cuando se cargue el paquete. Esto puede ser importante para ejemplos, pruebas, viñetas y demostraciones, donde los paquetes `Imports` deben adjuntarse explícitamente.

**Antes (con `Depende`):**
```r
# data.table functions are directly available
library(MyPkgDependsDataTable)
dt <- data.table(x = 1:10, y = letters[1:10])
setDT(dt)
result <- merge(dt, other_dt, by = "x")
```

**Después (con `Importaciones`):**
```r
# Explicitly load data.table in user scripts or vignettes
library(data.table)
library(MyPkgDependsDataTable)
dt <- data.table(x = 1:10, y = letters[1:10])
setDT(dt)
result <- merge(dt, other_dt, by = "x")
```

### Beneficios de utilizar “Importaciones”
- **Facilidad de uso**: `Depends` modifica la ruta `search()` de sus usuarios, posiblemente sin que ellos lo deseen.
- **Gestión de espacios de nombres**: Solo las funciones que su paquete importa explícitamente están disponibles, lo que reduce el riesgo de conflictos de nombres de funciones.
- **Carga de paquetes más limpia**: Las dependencias de su paquete no se adjuntan a la ruta de búsqueda, lo que hace que el proceso de carga sea más limpio y potencialmente más rápido.
- **Mantenimiento más sencillo**: Simplifica las tareas de mantenimiento a medida que evolucionan las API de las dependencias ascendentes. Depender demasiado de `Depends` puede provocar conflictos y problemas de compatibilidad con el tiempo.

