# Parcial 1 · Programación III — Liquidación de la cosecha de una finca cafetera

**Integrantes:** Leandro, Martin, Samuel

Programa en Elixir que carga los pesajes de una semana de cosecha, los valida, liquida el
pago de cada recolector y genera ocho reportes de producción, además del ranking con
opciones (C.1), la combinación con la finca vecina (C.2) y el desprendible de pago (B.5).

---

## Índice

1. [Estructura del repositorio](#1-estructura-del-repositorio)
2. [Cómo compilar y ejecutar](#2-cómo-compilar-y-ejecutar)
3. [Flujo del programa](#3-flujo-del-programa)
4. [Parte A. Diseño](#4-parte-a-diseño)
5. [Reglas de negocio y reportes: dónde está cada cosa](#5-reglas-de-negocio-y-reportes-dónde-está-cada-cosa)
6. [Explicación de R6 (ponderado vs. promedio simple)](#6-explicación-de-r6-ponderado-vs-promedio-simple)
7. [Parte C. Investigación](#7-parte-c-investigación)
8. [Parte D. Uso justificado de IA](#8-parte-d-uso-justificado-de-ia)
9. [Datos del grupo y salida completa](#9-datos-del-grupo-y-salida-completa)
10. [Guía del código línea por línea](#10-guía-del-código-línea-por-línea)
11. [Guía de problemas: si algo falla, qué revisar](#11-guía-de-problemas-si-algo-falla-qué-revisar)
12. [Cómo hacer cambios en vivo (sustentación)](#12-cómo-hacer-cambios-en-vivo-sustentación)

---

## 1. Estructura del repositorio

| Archivo | Módulo | Qué contiene |
|---|---|---|
| `datos.exs` | `Datos` | **Solo** las tres funciones `recolectores/0`, `lotes/0` y `pesajes/0` con los datos del grupo. El docente lo reemplaza en la sustentación. |
| `util.exs` | `Util` | Entrada/salida por consola (impuras) y utilidades genéricas puras: validar números, promedio ponderado, máximos con empates, indexar listas en mapas y formatear números. |
| `validacion.exs` | `Validacion` | Regla 1: las cinco verificaciones encadenadas con `with`, la separación válidos/rechazados y la lectura de la línea `recolector;lote;dia;kilos;verdes`. |
| `liquidacion.exs` | `Liquidacion` | Reglas 2 a 5: valor del pesaje, bonificación, alimentación y liquidación. También los agrupamientos de kilos (por día, por recolector y día) y los mejores del día. |
| `reportes.exs` | `Reportes` | Texto de R1–R8, desprendible, `ranking/2` (C.1) y `combinar_kilos/2` (C.2). No imprime nada: devuelve `String`. |
| `programa.exs` | `Programa` | `main/0`: orquesta todo y es quien imprime y lee de consola. |
| `verificacion_anexo.exs` | `VerificacionAnexo` | Script de apoyo: compara el programa contra la salida esperada del Anexo con los datos de prueba del enunciado (24 comprobaciones). |
| `.gitignore` | — | Evita subir los `.beam` que genera `elixirc`. |

### Qué se unificó y qué se eliminó

El repositorio venía de tres ramas (`leandro`, `Martin`, `samuel`) y los archivos no encajaban:

| Problema encontrado | Solución |
|---|---|
| `reportes.exs` y `reportes_p1.exs` definían **los dos** el módulo `Reportes` → al compilar uno pisaba al otro. Además `reportes.exs` tenía R1, R2, R4, R6, R7 y R8 como "pendiente". | Se fusionaron en un solo `reportes.exs` con los 8 reportes. **Se eliminó `reportes_p1.exs`.** |
| `programa.exs` llamaba a `Validacion.validar_todos/3` y `Validacion.validar/3`, que no existían (el módulo tenía `validar_pesaje/3`). | `Validacion` ahora expone `validar_pesaje/3`, `separar_pesajes/3` y `parsear_linea/1`, y `Programa` usa esos nombres. |
| `reportes_p1.exs` volvía a validar todos los pesajes dentro de R1 y R2. | Se valida **una sola vez** en `Programa.main/0`; los reportes reciben listas ya separadas. |
| `util.exs` tenía funciones ajenas al problema (temperaturas, interés compuesto, edad, correo, dividir cuenta, área). | Se dejaron solo las que el programa usa. |
| `pruebas_persona1.exs` usaba `ExUnit`, que no está en las guías. | **Se eliminó** y se reemplazó por `verificacion_anexo.exs`, que hace las mismas comprobaciones (y más) solo con `Enum`, `if` y `==`. |
| `README.md` tenía marcadores de conflicto de `git merge` (`<<<<<<< HEAD`). | Reescrito (este archivo). |
| `datos.exs` tenía los datos del Anexo, pero el enunciado pide el conjunto del grupo. | `datos.exs` tiene ahora los datos del grupo; los del Anexo viven en `verificacion_anexo.exs`. |

---

## 2. Cómo compilar y ejecutar

Requisitos: Elixir 1.14 o superior (probado con Elixir 1.17.3 / Erlang OTP 27).

Desde la carpeta del proyecto:

```bash
# 1. Compilar los módulos de apoyo (genera los archivos .beam)
elixirc datos.exs util.exs validacion.exs liquidacion.exs reportes.exs

# 2. Ejecutar el programa
elixir programa.exs
```

**Cada vez que se cambie `datos.exs` hay que volver a compilarlo** (basta con ese archivo):

```bash
elixirc datos.exs
elixir programa.exs
```

Si se cambia cualquier otro módulo, se recompila ese archivo (o se repite el paso 1 completo).

### Verificar contra el Anexo del enunciado

```bash
elixir verificacion_anexo.exs
```

Debe terminar con `24 de 24 comprobaciones correctas.` y mostrar los reportes con los datos
de prueba del enunciado, idénticos a la salida del Anexo.

### Ejecutar sin escribir a mano (opcional)

```bash
# Enter (sin pesaje adicional) y luego el código R01 para el desprendible
printf '\nR01\n' | elixir programa.exs
```

> En Windows, si las tildes salen mal en la consola, ejecutar antes `chcp 65001`.

---

## 3. Flujo del programa

```
Datos.recolectores/lotes/pesajes   (listas crudas)
          │
          ▼
Util.indexar_por  ──►  recolectores_por_codigo  %{"R01" => %{...}}
                       lotes_por_id             %{"L1"  => %{...}}
          │
          ▼
Validacion.separar_pesajes  ──►  {pesajes_validos, pesajes_rechazados}
          │
          ▼
Programa.agregar_pesaje_adicional   (lee una línea; Validacion.parsear_linea + validar_pesaje)
          │
          ▼
Liquidacion.liquidar  ──►  liquidaciones  [%{codigo, nombre, kilos, suma_pesajes, ...}]
          │
          ▼
Reportes.r1 … r8, ranking ×3, reporte_fincas_combinadas   (devuelven texto)
          │
          ▼
Programa.imprimir_reportes  (Util.imprimir_mensaje)
          │
          ▼
Programa.mostrar_desprendible  (lee un código; Reportes.desprendible)
```

---

## 4. Parte A. Diseño

### A.1 Colecciones

| Dato | Colección | Qué operaciones se benefician | Qué se pierde |
|---|---|---|---|
| Recolectores | Llegan como **lista**; se convierten a **mapa por código** (`recolectores_por_codigo`) con `Util.indexar_por/2`. Se conserva también la lista original. | La regla 1 (`Map.has_key?/2`) y la búsqueda del nombre en R5, R6 y el desprendible son de tiempo constante, sin recorrer la lista por cada pesaje. | El mapa no garantiza el orden; por eso R4, R8 y la liquidación usan la **lista** original, que sí respeta el orden de `datos.exs`. |
| Lotes | Lista → **mapa por id** (`lotes_por_id`) + lista original. | Regla 2 (`Map.has_key?/2`) inmediata. | Igual que arriba: R2 y R8 recorren la lista para que aparezcan todos los lotes (incluso con 0 kg). |
| Pesajes | Se mantienen como **lista**. | Se recorren completos en casi todos los cálculos (`Enum.map`, `Enum.filter`, `Enum.reduce`, `Enum.group_by`); el orden importa en R1. | Buscar un pesaje concreto es lineal, pero el programa nunca lo necesita. |
| Pesajes válidos / rechazados | Dos **listas**: válidos (mapas) y rechazados (tuplas `{pesaje, motivo}`). | Los rechazados conservan el orden original para R1; los válidos entran directo a los cálculos. | — |
| Liquidaciones | **Lista** de mapas, una por recolector. | Se ordena con `Enum.sort_by` (R4, ranking) y se suma (R7). | — |
| Kilos por recolector y día (reglas 3 y 4) | **Mapa** `%{dia => kilos}` por recolector (`Liquidacion.kilos_por_dia_de_recolector/1`). | La bonificación es `Map.values |> Enum.map(&bonificacion_dia/1)`; los días trabajados son `map_size/1`, porque cada clave es un día con al menos un pesaje válido. | No guarda qué lotes ni cuántos pesajes formaron el día (no lo necesitan las reglas 3 y 4). |
| Kilos de la finca por día (R3, C.2) | **Mapa** `%{1 => kg, …, 6 => kg}` inicializado en 0 para los 6 días. | R3 siempre muestra los 6 días; C.2 lo combina con `Map.merge/3`. | — |
| Kilos por recolector en un día (R5) | **Mapa** `%{codigo => kilos}`. | `Util.maximos_en/1` obtiene el máximo y todos los empatados. | — |
| Mejores por día (R5) | **Mapa** `%{dia => {codigos, kilos} \| :sin_pesajes}`. | Acceso directo por día y conteo con `Enum.frequencies/1`. | — |
| Lotes por recolector (R8) | **Mapa** `%{codigo => [ids de lote]}` con `Enum.group_by/3`. | Se compara con la lista de todos los lotes con `Util.contiene_todos?/2`. | Puede tener lotes repetidos; no afecta porque solo se pregunta si "contiene". |

### A.2 Funciones puras e impuras

Funciones **con efectos secundarios** (solo en `Util` y `Programa`):

| Módulo | Función | Efecto |
|---|---|---|
| `Util` | `leer/2` | Lee de la entrada estándar (`IO.gets`). |
| `Util` | `imprimir_mensaje/1` | Escribe en consola (`IO.puts`). |
| `Util` | `imprimir_error/1` | Escribe en la salida de errores. |
| `Programa` | `main/0` | Orquesta lectura e impresión. |
| `Programa` | `agregar_pesaje_adicional/3` | Lee una línea e imprime el resultado. |
| `Programa` | `imprimir_reportes/5` | Imprime los reportes. |
| `Programa` | `mostrar_desprendible/2` | Lee un código e imprime el desprendible. |

**Todo lo demás es puro**: `Validacion`, `Liquidacion` y `Reportes` solo reciben datos y
devuelven valores (tuplas, números, mapas o `String`). Ninguna imprime, lee ni lanza excepciones.

### A.3 Módulos

| Módulo | Funciones | Por qué ahí |
|---|---|---|
| `Datos` | `recolectores/0`, `lotes/0`, `pesajes/0` | El docente reemplaza el archivo completo; cualquier transformación iría en otro módulo (B.1). |
| `Util` | `leer/2`, `imprimir_mensaje/1`, `imprimir_error/1`, `validar_positivo/1`, `validar_rango/3`, `promedio_ponderado/1`, `maximos_en/1`, `contiene_todos?/2`, `indexar_por/2`, `formatear_decimal/2`, `formatear_dinero/1`, `formatear_numero/1` | Herramientas genéricas que no conocen las reglas de la finca y que varios módulos reutilizan; además concentra la E/S para que el resto sea puro. |
| `Validacion` | `motivos/0`, `validar_pesaje/3`, `separar_pesajes/3`, `validar_recolector/2`, `validar_lote/2`, `validar_dia/1`, `validar_kilos/1`, `validar_verdes/1`, `parsear_linea/1` | Todo lo que decide si un dato entra o no a los cálculos (regla 1 y formato de B.5). |
| `Liquidacion` | `valor_pesaje/2`, `factor_calidad/1`, `bonificacion_dia/1`, `descuento_alimentacion/2`, `liquidar_recolector/2`, `liquidar/2`, `detalle_diario_recolector/1`, agrupamientos de kilos y mejores del día | Reglas de pago 2–5 y cálculos sobre kilos que comparten varios reportes. Sus parámetros son atributos de módulo. |
| `Reportes` | `r1/1` … `r8/3`, `kilos_por_lote/2`, `calidad_ponderada/1`, `desprendible/2`, `ranking/2`, `combinar_kilos/2`, `reporte_fincas_combinadas/2` | Convertir resultados en texto. Separarlo de `Liquidacion` permite cambiar el formato sin tocar las reglas. |
| `Programa` | `main/0` y las funciones de interacción | Único punto de entrada; decide el orden y muestra el texto (B.1). |

---

## 5. Reglas de negocio y reportes: dónde está cada cosa

| Requisito | Función |
|---|---|
| Parámetros (tarifa, meta, bonificación, alimentación, días) | Atributos al inicio de `liquidacion.exs` y `validacion.exs` |
| Regla 1 – Validación encadenada con `with` (B.2) | `Validacion.validar_pesaje/3` |
| Regla 2 – Valor de un pesaje | `Liquidacion.valor_pesaje/2` + `Liquidacion.factor_calidad/1` |
| Regla 3 – Bonificación por productividad | `Liquidacion.bonificacion_dia/1` |
| Regla 4 – Descuento de alimentación | `Liquidacion.descuento_alimentacion/2` |
| Regla 5 – Liquidación | `Liquidacion.liquidar_recolector/2` y `Liquidacion.liquidar/2` |
| R1 – Rechazados y conteo por motivo | `Reportes.r1/1` |
| R2 – Kilos y rendimiento por lote | `Reportes.kilos_por_lote/2` + `Reportes.r2/2` |
| R3 – Kilos por día y meta | `Liquidacion.kilos_por_dia_finca/1` + `Reportes.r3/1` |
| R4 – Liquidación ordenada por neto | `Reportes.r4/1` |
| R5 – Mejor recolector de cada día | `Liquidacion.mejores_por_dia/1`, `recolector_con_mas_dias_ganador/1` + `Reportes.r5/2` |
| R6 – Mejor calidad ponderada | `Reportes.calidad_ponderada/1` + `Reportes.r6/2` |
| R7 – Totales y costo por kilo | `Reportes.r7/1` |
| R8 – Recolectores en todos los lotes | `Reportes.r8/3` |
| B.5 – Pesaje adicional | `Validacion.parsear_linea/1` + `Programa.agregar_pesaje_adicional/3` |
| B.5 – Desprendible | `Reportes.desprendible/2` + `Programa.mostrar_desprendible/2` |
| C.1 – Ranking con keyword list | `Reportes.ranking/2` |
| C.2 – Combinar con la finca vecina | `Reportes.combinar_kilos/2` + `Reportes.reporte_fincas_combinadas/2` |

---

## 6. Explicación de R6 (ponderado vs. promedio simple)

El porcentaje ponderado es `suma(verdes × kilos) / suma(kilos)`. Cada muestra pesa según los
kilos que representa: una muestra de un pesaje de 180 kg describe 180 kg de café, y una de
15 kg describe solo 15 kg. El **promedio simple** (`suma(verdes) / número de pesajes`) trata
igual a todas las muestras, aunque correspondan a cantidades de café muy distintas, y por eso
no refleja la calidad real de lo que entregó el recolector.

**Caso de nuestros datos — Fabio Nelson Ríos (R10):**

| Día | Kilos | Verdes |
|---|---|---|
| 2 | 180 | 0.5 % |
| 3 | 15 | 14 % |
| 4 | 15 | 14 % |

* Promedio simple: (0.5 + 14 + 14) / 3 = **9.50 %** → sería el **peor** de la finca.
* Ponderado: (0.5·180 + 14·15 + 14·15) / (180 + 15 + 15) = 510 / 210 = **2.43 %** → es el **mejor** (gana R6).

De los 210 kg que entregó, 180 kg (el 86 %) tenían apenas 0.5 % de verdes. El promedio simple
deja que dos pesajes pequeños dominen el resultado. Con promedio simple, R6 habría elegido a
Marleny Quintero (2.83 % simple; 2.78 % ponderado), cuyos pesajes son de tamaño parecido, por
lo que en su caso los dos promedios casi coinciden.

---

## 7. Parte C. Investigación

### C.1 `Reportes.ranking/2` con keyword lists

Opciones: `campo` (`:neto` por defecto, `:kilos`, `:bruto`), `orden` (`:desc` por defecto,
`:asc`) y `limite` (entero positivo; por defecto todos). Cada opción se lee con
`Keyword.get(opciones, :clave, valor_por_defecto)`. Si llega un valor que no está permitido
(por ejemplo `campo: :otro` o `limite: -2`) se usa el valor por defecto. `:bruto` es lo
ganado antes de la alimentación: `suma_pesajes + bonificaciones`.

`main` la llama de las tres formas pedidas (la salida está en la sección 9):

```elixir
Reportes.ranking(liquidaciones, [])
Reportes.ranking(liquidaciones, campo: :kilos, limite: 3)
Reportes.ranking(liquidaciones, orden: :asc, campo: :bruto)
```

**1. ¿Por qué Elixir usa keyword lists, y no mapas, para pasar opciones?**

* **Sintaxis cómoda**: si la keyword list es el último argumento se pueden omitir los
  corchetes (`ranking(l, campo: :kilos)`), así se lee como "argumentos con nombre".
* **Conservan el orden** en que se escriben y **permiten claves repetidas**; algunas
  funciones y macros del lenguaje (por ejemplo `if cond, do: ..., else: ...` o
  `import List, only: [...]`) dependen de eso.
* Son listas pequeñas de pares `{atomo, valor}`; para pocas opciones recorrerlas es barato y
  no hace falta la estructura de un mapa.
* Es la convención de la librería estándar, y el módulo `Keyword` trae funciones pensadas para
  opciones (`get/3` con valor por defecto, `validate/2`, `merge/2`…).

Los mapas, en cambio, no admiten claves repetidas y no garantizan orden; se usan para datos
(como los recolectores), no para opciones.

**2. ¿Qué devuelve `ranking(liquidaciones, campo: :kilos, campo: :neto)` y por qué?**

Devuelve el ranking **por kilos** (`Ranking (campo: kilos, orden: desc, límite: todos)`).
`Keyword.get/3` recorre la lista desde el inicio y devuelve la **primera** aparición de la
clave; la segunda `campo: :neto` se ignora. (`verificacion_anexo.exs` lo comprueba.)

### C.2 Combinar con la finca vecina — `Reportes.combinar_kilos/2`

```elixir
Map.merge(mapa_finca, mapa_vecina, fn _dia, kilos_finca, kilos_vecina ->
  kilos_finca + kilos_vecina
end)
```

`Map.merge/3` llama la función **solo** para las claves que están en los dos mapas, y la usa
para resolver el conflicto (aquí, sumando).

Con nuestros datos (R3 = `%{1 => 912.5, 2 => 959.5, 3 => 319, 4 => 824, 5 => 704, 6 => 758.5}`)
y la vecina `%{1 => 520.5, 2 => 610, 3 => 480, 5 => 700, 7 => 300}`:

| Día | Finca | Vecina | `Map.merge/3` (correcto) | `Map.merge/2` |
|---|---|---|---|---|
| 1 | 912.5 | 520.5 | **1433** | 520.5 |
| 2 | 959.5 | 610 | **1569.5** | 610 |
| 3 | 319 | 480 | **799** | 480 |
| 4 | 824 | — | 824 | 824 |
| 5 | 704 | 700 | **1404** | 700 |
| 6 | 758.5 | — | 758.5 | 758.5 |
| 7 | — | 300 | 300 | 300 |

* **Con `Map.merge/2`** el segundo mapa **sobrescribe** al primero cuando una clave está en los
  dos: los días 1, 2, 3 y 5 quedarían con los kilos de la vecina y se perderían los de nuestra
  finca. Es incorrecto porque la cooperativa quiere **sumar** la producción, no reemplazarla.
* **Día 7**: solo está en el mapa de la vecina, así que no hay conflicto y se copia tal cual
  (300 kg) con cualquiera de las dos funciones; lo mismo pasa con los días 4 y 6, que solo
  están en el nuestro. El resultado tiene 7 días aunque nuestra cosecha sea de 6.

**Fuentes consultadas (Parte C):**

* Documentación oficial de `Keyword`: https://hexdocs.pm/elixir/Keyword.html (`get/3`: "If
  duplicate entries exist, it returns the first one").
* Guía oficial "Keyword lists and maps": https://hexdocs.pm/elixir/keywords-and-maps.html
* Documentación oficial de `Map.merge/2` y `Map.merge/3`: https://hexdocs.pm/elixir/Map.html#merge/3
* Asistente de IA (ver bitácora).

---

## 8. Parte D. Uso justificado de IA

> ⚠️ **Para completar por el grupo.** La nota de la Parte D depende de la honestidad del
> registro. Agreguen una fila por cada consulta relevante que hayan hecho ustedes y revisen
> las filas ya escritas (corresponden a la sesión en la que se unificó el proyecto).

### D.1 Bitácora

| Parte | Herramienta | Qué le pidieron | Por qué recurrieron a la IA en ese punto | Cómo verificaron la respuesta | Qué hicieron con ella |
|---|---|---|---|---|---|
| B (toda) | Claude (Cowork) | Unificar los archivos de las tres ramas para que compilaran juntos, eliminar los sobrantes y documentar. | Al fusionar las ramas quedaron dos módulos `Reportes`, nombres de funciones que no coincidían entre `Programa` y `Validacion` y reportes pendientes; no sabíamos cómo integrarlos sin romper lo que ya funcionaba. | Ejecutando `verificacion_anexo.exs` (24/24) y comparando reporte por reporte con la salida del Anexo; probando las tres entradas de ejemplo de B.5 y el código R99. | La usamos; revisamos cada función para poder explicarla (sección 10). |
| Datos | Claude (Cowork) | Generar el conjunto de datos del grupo (≥10 recolectores, 4 lotes, ≥80 pesajes válidos, ≥2 inválidos por motivo). | Escribir 97 pesajes a mano no aporta al aprendizaje; lo importante era que incluyeran casos útiles (empate en R5, caso de R6, límites de la tabla de calidad). | Contamos los pesajes y los rechazos por motivo en R1; revisamos que hubiera un empate y un día que no cumpliera la meta. | La usamos con correcciones (ver D.2). |
| C.1 | Claude (Cowork) | Cómo leer opciones con valor por defecto en una keyword list. | | | |
| _…_ | | | | | |

### D.2 Un error de la IA

**Caso 1 – respuesta poco clara.** La primera versión de `agregar_pesaje_adicional/3` que
propuso la IA usaba un `with` con una guarda (`{:linea, linea} when linea != "" <- {:linea, linea}`)
y un patrón con la misma variable repetida (`{pesaje, {:ok, pesaje}}`). Funcionaba, pero
ninguno de nosotros podía explicar con seguridad por qué, y en la sustentación hay que
explicar cada línea. Se reemplazó por un `if` (línea vacía) y dos `case` anidados, que es lo
que está hoy en `programa.exs`.

**Caso 2 – datos que no servían para un reporte.** El primer conjunto de datos generado no
tenía ningún recolector en los cuatro lotes, así que R8 solo mostraba "Ningún recolector
trabajó en todos los lotes". Lo notamos al leer la salida y se corrigió para que Jhon Fredy y
Dora pasaran por los cuatro lotes.

> Agreguen aquí sus propios casos (respuesta original, cómo notaron el problema y código final).

### D.3 Reflexión del grupo

> _Para completar por el grupo (media página a una página):_
> 1. ¿En qué partes la IA les ayudó a entender algo que no sabían, y en cuáles se limitó a darles código?
> 2. ¿Qué partes del proyecto decidieron hacer sin IA y por qué?
> 3. Si tuvieran que hacer el proyecto de nuevo sin ninguna herramienta de IA, ¿qué parte les costaría más?

---
## 9. Datos del grupo y salida completa

`datos.exs` cumple los mínimos del enunciado:

| Requisito | Pedido | En `datos.exs` |
|---|---|---|
| Recolectores | ≥ 10 (≥ 4 con alimentación) | 11 (5 con alimentación) |
| Lotes | 4 | 4 |
| Días con pesajes | los 6 | 1 a 6 |
| Pesajes válidos | ≥ 80 | 83 |
| Inválidos por motivo | ≥ 2 de cada uno | 3 · 2 · 4 · 3 · 2 (14 en total) |

Casos incluidos a propósito:

* **R1**: errores de digitación reales (`"r01"` y `"l2"` en minúscula, día `2.5`, kilos `-15`,
  verdes `-1` y `100.5`) y pesajes que incumplen varias reglas a la vez (`R20` con lote, día,
  kilos y verdes inválidos solo se informa como `recolector_desconocido`).
* **R3**: el día 3 no cumple la meta; los demás sí.
* **R4**: Carlos Arturo Montoya (R11) solo tiene pesajes rechazados → aparece con todo en 0.
* **R5**: empate el día 4 (Jhon Fredy y Gloria Inés, 160 kg) y empate en "más días" (2 días).
* **R6**: el caso de Fabio Nelson Ríos explicado en la sección 6.
* **R8**: Jhon Fredy y Dora trabajaron en los cuatro lotes.
* **Regla 2**: hay verdes exactamente en los límites 2 %, 5 % y 10 %.

### Salida completa con los datos del grupo

Ejecución con Enter en el pesaje adicional y `R01` en el desprendible:

```text
Ingrese un pesaje adicional (recolector;lote;dia;kilos;verdes) o Enter para omitir: No se agregó ningún pesaje.

R1. Pesajes rechazados
R15 | L1 | día 2 | 60 kg | 3 % -> recolector_desconocido
r01 | L2 | día 3 | 55 kg | 4 % -> recolector_desconocido
R20 | L9 | día 9 | 300 kg | 120 % -> recolector_desconocido
R02 | L5 | día 1 | 70 kg | 2 % -> lote_desconocido
R03 | l2 | día 4 | 65 kg | 3 % -> lote_desconocido
R05 | L2 | día 0 | 50 kg | 3 % -> dia_invalido
R06 | L3 | día 7 | 40 kg | 2 % -> dia_invalido
R07 | L1 | día 2.5 | 45 kg | 4 % -> dia_invalido
R11 | L1 | día 8 | 260 kg | 3 % -> dia_invalido
R04 | L3 | día 3 | 0 kg | 5 % -> kilos_fuera_de_rango
R08 | L3 | día 5 | 260 kg | 4 % -> kilos_fuera_de_rango
R11 | L2 | día 2 | -15 kg | 3 % -> kilos_fuera_de_rango
R09 | L4 | día 1 | 45 kg | -1 % -> porcentaje_invalido
R01 | L1 | día 5 | 50 kg | 100.5 % -> porcentaje_invalido

Rechazos por motivo
recolector_desconocido: 3
lote_desconocido: 2
dia_invalido: 4
kilos_fuera_de_rango: 3
porcentaje_invalido: 2

R2. Kilos por lote
La Cañada | 1210.25 kg | 1.5 ha | 806.83 kg/ha
La Esperanza | 1247.5 kg | 2.0 ha | 623.75 kg/ha
Buenavista | 1200 kg | 3.0 ha | 400.00 kg/ha
El Mirador | 819.75 kg | 2.5 ha | 327.90 kg/ha

R3. Kilos por día (meta: 400 kg)
Día 1: 912.5 kg -> cumplió la meta
Día 2: 959.5 kg -> cumplió la meta
Día 3: 319 kg -> no cumplió la meta
Día 4: 824 kg -> cumplió la meta
Día 5: 704 kg -> cumplió la meta
Día 6: 758.5 kg -> cumplió la meta
¿Se cumplió la meta todos los días? No
¿Se cumplió la meta al menos un día? Sí

R4. Liquidación de la semana
# | Recolector | Kilos | Pesajes | Bonificaciones | Alimentación | Neto
1. | Jhon Fredy Castaño | 745 kg | $702900.00 | $32000.00 | $0.00 | $734900.00
2. | Gloria Inés Valencia | 654 kg | $624275.00 | $24000.00 | $60000.00 | $588275.00
3. | Albeiro Restrepo | 510 kg | $513000.00 | $24000.00 | $0.00 | $537000.00
4. | Dora Cardona | 575 kg | $542450.00 | $24000.00 | $60000.00 | $506450.00
5. | Luz Marina Ospina | 526.25 kg | $510675.00 | $16000.00 | $60000.00 | $466675.00
6. | Hernán Darío Giraldo | 359.25 kg | $364800.00 | $16000.00 | $0.00 | $380800.00
7. | Wilson Arango | 309 kg | $287625.00 | $0.00 | $0.00 | $287625.00
8. | Yolanda Henao | 352.5 kg | $327700.00 | $0.00 | $48000.00 | $279700.00
9. | Fabio Nelson Ríos | 210 kg | $210000.00 | $8000.00 | $0.00 | $218000.00
10. | Marleny Quintero | 236.5 kg | $242850.00 | $0.00 | $60000.00 | $182850.00
11. | Carlos Arturo Montoya | 0 kg | $0.00 | $0.00 | $0.00 | $0.00

R5. Mejor recolector de cada día
Día 1: Jhon Fredy Castaño (227 kg)
Día 2: Luz Marina Ospina (201.5 kg)
Día 3: Wilson Arango (68 kg)
Día 4: Jhon Fredy Castaño, Gloria Inés Valencia (160 kg)
Día 5: Albeiro Restrepo (140.5 kg)
Día 6: Albeiro Restrepo (147.5 kg)
Más días como mejor recolector: Jhon Fredy Castaño, Albeiro Restrepo (2 días)

R6. Mejor calidad (mínimo 3 pesajes válidos)
Fabio Nelson Ríos, con 2.43 % de verdes ponderado por kilos

R7. Totales de la semana
Total a pagar: $4182275.00
Kilos válidos: 4477.5 kg
Costo promedio por kilo: $934.06

R8. Recolectores que trabajaron en todos los lotes
Jhon Fredy Castaño
Dora Cardona

Ranking (campo: neto, orden: desc, límite: todos)
1. Jhon Fredy Castaño | $734900.00
2. Gloria Inés Valencia | $588275.00
3. Albeiro Restrepo | $537000.00
4. Dora Cardona | $506450.00
5. Luz Marina Ospina | $466675.00
6. Hernán Darío Giraldo | $380800.00
7. Wilson Arango | $287625.00
8. Yolanda Henao | $279700.00
9. Fabio Nelson Ríos | $218000.00
10. Marleny Quintero | $182850.00
11. Carlos Arturo Montoya | $0.00

Ranking (campo: kilos, orden: desc, límite: 3)
1. Jhon Fredy Castaño | 745 kg
2. Gloria Inés Valencia | 654 kg
3. Dora Cardona | 575 kg

Ranking (campo: bruto, orden: asc, límite: todos)
1. Carlos Arturo Montoya | $0.00
2. Fabio Nelson Ríos | $218000.00
3. Marleny Quintero | $242850.00
4. Wilson Arango | $287625.00
5. Yolanda Henao | $327700.00
6. Hernán Darío Giraldo | $380800.00
7. Luz Marina Ospina | $526675.00
8. Albeiro Restrepo | $537000.00
9. Dora Cardona | $566450.00
10. Gloria Inés Valencia | $648275.00
11. Jhon Fredy Castaño | $734900.00

C.2. Producción combinada con la finca vecina
Día 1: 1433 kg
Día 2: 1569.5 kg
Día 3: 799 kg
Día 4: 824 kg
Día 5: 1404 kg
Día 6: 758.5 kg
Día 7: 300 kg

Ingrese el código del recolector para ver su desprendible: Desprendible de pago - Luz Marina Ospina (R01)
Día 1: 60 kg | pesajes $60000.00 | bonificación $0.00
Día 2: 201.5 kg | pesajes $200325.00 | bonificación $8000.00
Día 3: 61.25 kg | pesajes $61250.00 | bonificación $0.00
Día 4: 75 kg | pesajes $67500.00 | bonificación $0.00
Día 5: 128.5 kg | pesajes $121600.00 | bonificación $8000.00
Suma de pesajes: $510675.00
Bonificaciones: $16000.00
Alimentación (5 días): -$60000.00
Neto a pagar: $466675.00
```

### Pesaje adicional (B.5) con los datos del Anexo

```text
Ingrese un pesaje adicional (recolector;lote;dia;kilos;verdes) o Enter para omitir: R04;L3; 2;92.5;3
Pesaje agregado: R04 en L3, día 2, 92.5 kg, 3.0 % de verdes.

Ingrese un pesaje adicional (recolector;lote;dia;kilos;verdes) o Enter para omitir: R03;L2; 4.5;92;3
Pesaje rechazado: formato_invalido

Ingrese un pesaje adicional (recolector;lote;dia;kilos;verdes) o Enter para omitir: R04;L9; 2;50;3
Pesaje rechazado: lote_desconocido

Ingrese el código del recolector para ver su desprendible: R99
No existe un recolector con el código R99.
```

Un pesaje válido agregado entra en todos los reportes (cambian R2, R3, R4 y R7); uno con
formato correcto pero rechazado por las reglas aparece al final de R1 con su motivo.

---

## 10. Guía del código línea por línea

Esta guía recorre cada archivo en el mismo orden en que está escrito. Para cada función se
explica qué hace cada línea (o grupo pequeño de líneas), por qué se escribió así y qué pasa
con una entrada distinta. Sirve para preparar la sustentación y para saber dónde mirar cuando
algo falle (ver también la [sección 11](#11-guía-de-problemas-si-algo-falla-qué-revisar)).

Conceptos de Elixir que se repiten en todo el código:

| Construcción | Qué significa |
|---|---|
| `x \|> f(y)` | *Pipe*: pasa `x` como **primer** argumento de `f`; equivale a `f(x, y)`. |
| `&(&1.kilos)` o `& &1.kilos` | Función anónima corta: recibe un argumento (`&1`) y devuelve su campo `kilos`. |
| `fn {a, b} -> ... end` | Función anónima que además desestructura una tupla. |
| `def f(x) when guarda` | Cláusula que solo se usa si la guarda es verdadera; Elixir prueba las cláusulas de arriba hacia abajo. |
| `with {:ok, a} <- f(), {:ok, b} <- g(a) do ... end` | Ejecuta pasos en orden mientras cada uno calce con su patrón; en cuanto uno no calza, devuelve ese valor (el error). |
| `for x <- lista, into: %{}, do: {k, v}` | *Comprehension*: recorre la lista y construye un mapa. |
| `Map.update(mapa, clave, inicial, fun)` | Si la clave no existe la crea con `inicial`; si existe le aplica `fun` al valor actual. |
| `@nombre valor` | Atributo de módulo: una constante que se fija al compilar. |

---

### 10.1 `datos.exs` — módulo `Datos`

| Líneas | Explicación |
|---|---|
| Comentario inicial | Integrantes, qué contiene el archivo y el recordatorio de recompilarlo. |
| `def recolectores do [ ... ] end` | Devuelve una **lista** de mapas `%{codigo:, nombre:, alimentacion:}`. `alimentacion: true` significa que come en la finca y se le descuenta. |
| `def lotes do [ ... ] end` | Lista de mapas `%{id:, nombre:, hectareas:}`. Las hectáreas se usan para el rendimiento de R2. |
| `def pesajes do [ ... ] end` | Lista de mapas `%{recolector:, lote:, dia:, kilos:, verdes:}`. Los comentarios `# R10: …` y `# ---- Pesajes inválidos …` solo separan visualmente; no cambian nada. |

> No se debe agregar lógica aquí: el docente reemplaza el archivo completo (B.1).

---

### 10.2 `util.exs` — módulo `Util`

**`leer(mensaje, :string)`** *(impura)*

| Línea | Explicación |
|---|---|
| `case IO.gets(mensaje) do` | Muestra `mensaje` y espera una línea. `IO.gets` devuelve el texto **con** el salto de línea final, o `:eof` si ya no hay entrada (por ejemplo con `printf ... \| elixir programa.exs`). |
| `texto when is_binary(texto) -> String.trim(texto)` | Si llegó texto, se quitan espacios y el `\n` del final. `"R01\n"` → `"R01"`. |
| `_eof_o_error -> ""` | Si llegó `:eof` (o un error) se devuelve `""`, que el programa trata como "Enter". Sin esta línea, `String.trim(:eof)` haría fallar el programa. |

**`imprimir_mensaje/1` e `imprimir_error/1`** *(impuras)*: envuelven `IO.puts/1` y
`IO.puts(:standard_error, …)`. Tenerlas aquí deja claro qué funciones tienen efectos.

**`validar_positivo/1`** — tres cláusulas, se prueban en orden:

| Cláusula | Cuándo aplica | Devuelve |
|---|---|---|
| `when is_number(numero) and numero > 0` | `80`, `0.5` | `{:ok, numero}` |
| `when is_number(numero)` | `0`, `-15` (es número pero no > 0) | `{:error, :debe_ser_positivo}` |
| `validar_positivo(_)` | `"80"`, `nil`, `:abc` | `{:error, :se_esperaba_un_numero}` |

**`validar_rango(numero, minimo, maximo)`**

| Línea | Explicación |
|---|---|
| Guarda `when is_number(numero) and is_number(minimo) and is_number(maximo) and minimo <= maximo` | Solo entra si los tres son números y el rango tiene sentido. |
| `if numero >= minimo and numero <= maximo, do: {:ok, numero}, else: {:error, :fuera_de_rango}` | Rango **inclusivo**: `validar_rango(6, 1, 6)` es `{:ok, 6}`. |
| `def validar_rango(_, _, _)` | Cualquier otra cosa (por ejemplo `numero = nil`) devuelve error en lugar de fallar. |

**`promedio_ponderado(datos)`**

| Línea | Explicación |
|---|---|
| `datos_validos = Enum.all?(datos, fn {valor, peso} -> ... ; _ -> false end)` | Revisa que cada elemento sea un par `{número, número ≥ 0}`. La segunda cláusula `_ -> false` atrapa cualquier elemento que no sea par. |
| `cond do datos == [] -> {:error, :lista_vacia}` | Lista vacía: no hay promedio. |
| `not datos_validos -> {:error, ...}` | Algún par inválido. |
| `true ->` | Caso normal. |
| `peso_total = datos \|> Enum.map(fn {_valor, peso} -> peso end) \|> Enum.sum()` | Suma de los pesos (en R6, suma de kilos). |
| `suma_ponderada = ... Enum.map(fn {valor, peso} -> valor * peso end) \|> Enum.sum()` | Suma de `verdes × kilos`. |
| `if peso_total == 0, do: {:error, ...}, else: {:ok, suma_ponderada / peso_total}` | Evita dividir entre 0. `/` siempre devuelve float. |
| `def promedio_ponderado(_)` | Si no es lista, error. |

**`maximos_en(pares)`** — usada por R5 (mejor del día, más días) y R6.

| Línea | Explicación |
|---|---|
| `lista = Enum.to_list(pares)` | Acepta un mapa o una lista de tuplas; un mapa se convierte en `[{clave, valor}, ...]`. |
| `if lista == [] do :vacio` | Sin elementos no hay máximo; quien llama decide qué mostrar. |
| `valor_maximo = lista \|> Enum.map(fn {_clave, valor} -> valor end) \|> Enum.max()` | Toma solo los valores y busca el mayor. |
| `claves = lista \|> Enum.filter(... valor == valor_maximo) \|> Enum.map(... clave) \|> Enum.sort()` | Todas las claves con ese valor (así salen **todos** los empatados), ordenadas para que la salida sea siempre la misma. |
| `{claves, valor_maximo}` | Ej.: `{["R02", "R05"], 160}`. |

**`contiene_todos?(lista, requeridos)`**: `Enum.all?(requeridos, &(&1 in lista))` es verdadero
si cada elemento requerido está en `lista`. En R8: ¿están todos los ids de lote en los lotes
del recolector?

**`indexar_por(lista, clave)`**: `Map.new(lista, fn e -> {Map.get(e, clave), e} end)` construye
`%{"R01" => %{codigo: "R01", ...}}`. Si hubiera dos elementos con la misma clave, queda el último.

**`formatear_decimal(valor, decimales)`**

| Línea | Explicación |
|---|---|
| `:erlang.float_to_binary(valor / 1, decimals: decimales)` | `valor / 1` convierte enteros en float (la función de Erlang solo acepta floats). `decimals:` evita la notación científica: `62999.99999999999` → `"63000.00"`. |
| `def formatear_decimal(valor, _decimales), do: inspect(valor)` | Si no es número, lo muestra tal cual en lugar de fallar. |

**`formatear_dinero(valor)`**: atajo de `formatear_decimal(valor, 2)`; se usa para todos los pesos.

**`formatear_numero(valor)`** — para kilos y porcentajes:

| Cláusula | Ejemplo |
|---|---|
| `when is_integer(valor)` → `Integer.to_string` | `410` → `"410"` |
| `when is_float(valor)` y sin parte decimal (`valor == Float.round(valor, 0)`) → se redondea a entero | `92.0` → `"92"` |
| `when is_float(valor)` con decimales → `float_to_binary(valor, [:compact, decimals: 2])` | `300.5` → `"300.5"`, `30.25` → `"30.25"` (`:compact` quita ceros sobrantes) |
| Cualquier otro valor → `inspect(valor)` | `nil` → `"nil"`, `"80"` → `"\"80\""` (para que en R1 se note que era texto) |

---

### 10.3 `validacion.exs` — módulo `Validacion`

| Líneas | Explicación |
|---|---|
| `@dia_minimo 1`, `@dia_maximo 6`, `@kilos_maximos_por_pesaje 250`, `@verdes_minimo 0`, `@verdes_maximo 100` | Límites de la regla 1 como atributos. Para cambiar un límite se cambia solo aquí. |

**`motivos/0`**: lista de los cinco motivos **en el orden de validación**. R1 la recorre para
mostrar el conteo de todos los motivos, incluso los que tienen 0. Si se agrega un motivo nuevo,
hay que agregarlo también aquí.

**`validar_pesaje(pesaje, recolectores_por_codigo, lotes_por_id)`** — requisito B.2

| Línea | Explicación |
|---|---|
| `with {:ok, _} <- validar_recolector(Map.get(pesaje, :recolector), recolectores_por_codigo),` | Paso 1. `Map.get` devuelve `nil` si falta el campo (en vez de fallar como `pesaje.recolector`). |
| `{:ok, _} <- validar_lote(Map.get(pesaje, :lote), lotes_por_id),` | Paso 2. |
| `{:ok, _} <- validar_dia(Map.get(pesaje, :dia)),` | Paso 3. |
| `{:ok, _} <- validar_kilos(Map.get(pesaje, :kilos)),` | Paso 4. |
| `{:ok, _} <- validar_verdes(Map.get(pesaje, :verdes)) do` | Paso 5. |
| `{:ok, pesaje}` | Solo se llega aquí si los cinco dieron `{:ok, _}`. |
| *(sin `else`)* | Si un paso devuelve `{:error, motivo}`, no calza con `{:ok, _}` y `with` lo devuelve **tal cual**. Por eso se informa solo el **primer** motivo: `R04, L3, día 7, 300 kg` → `{:error, :dia_invalido}`, nunca llega a revisar los kilos. |

**`separar_pesajes(pesajes, recolectores_por_codigo, lotes_por_id)`**

| Línea | Explicación |
|---|---|
| `resultados = Enum.map(pesajes, fn pesaje -> {pesaje, validar_pesaje(...)} end)` | Valida cada pesaje **una sola vez** y guarda el pesaje junto a su resultado: `{pesaje, {:ok, pesaje}}` o `{pesaje, {:error, motivo}}`. |
| `validos = for {pesaje, {:ok, _}} <- resultados, do: pesaje` | En un `for`, los elementos que **no** calzan con el patrón se saltan: aquí solo pasan los `:ok`. |
| `rechazados = for {pesaje, {:error, motivo}} <- resultados, do: {pesaje, motivo}` | Igual, pero con los errores; se guarda `{pesaje, motivo}` para R1. |
| `{validos, rechazados}` | Ambos en el orden original de `datos.exs`. |

**`validar_recolector/2` y `validar_lote/2`**: `Map.has_key?(mapa, codigo)` revisa si existe la
clave. Los códigos distinguen mayúsculas: `"r01"` no es `"R01"` → `:recolector_desconocido`.

**`validar_dia/1`**

| Cláusula | Explicación |
|---|---|
| `def validar_dia(dia) when is_integer(dia)` | Solo enteros; `2.5`, `2.0`, `"3"` o `nil` van a la segunda cláusula. |
| `case Util.validar_rango(dia, @dia_minimo, @dia_maximo)` | `0` o `7` dan `{:error, _}` y se traducen a `{:error, :dia_invalido}`. |
| `def validar_dia(_dia), do: {:error, :dia_invalido}` | Todo lo que no es entero. |

**`validar_kilos/1`**

| Línea | Explicación |
|---|---|
| `with {:ok, kilos} <- Util.validar_positivo(kilos),` | Descarta `0`, negativos y no números. |
| `{:ok, kilos} <- Util.validar_rango(kilos, 0, @kilos_maximos_por_pesaje) do` | Descarta más de 250 (`250` sí es válido). |
| `else {:error, _} -> {:error, :kilos_fuera_de_rango}` | Cualquiera de los dos errores se traduce al motivo del enunciado. |

**`validar_verdes/1`**: `Util.validar_rango(verdes, 0, 100)`; `-1`, `100.5` o `nil` →
`:porcentaje_invalido`. `0` y `100` son válidos.

**`parsear_linea(linea)`** — B.5

| Línea | Explicación |
|---|---|
| `case linea \|> String.split(";") \|> Enum.map(&String.trim/1) do` | `"R04;L3; 2;92.5;3"` → `["R04", "L3", "2", "92.5", "3"]` (el `trim` quita el espacio antes del 2). |
| `[recolector, lote, dia_texto, kilos_texto, verdes_texto] ->` | Solo calza si hay **exactamente** cinco campos. |
| `with {:ok, dia} <- parsear_entero(dia_texto),` | El día debe ser entero. |
| `{:ok, kilos} <- parsear_numero(kilos_texto),` / `{:ok, verdes} <- parsear_numero(verdes_texto) do` | Kilos y verdes deben ser números. |
| `{:ok, %{recolector: ..., lote: ..., dia: ..., kilos: ..., verdes: ...}}` | Mapa con el mismo formato que los de `datos.exs`. |
| `_otro_numero_de_campos -> {:error, :formato_invalido}` | 4, 6 o cualquier otra cantidad de campos. |

**`parsear_entero/1`** *(privada)*: `Integer.parse("2")` → `{2, ""}` ✔. `Integer.parse("4.5")` →
`{4, ".5"}`: como sobra texto (`".5"`) no calza con `{numero, ""}` y se rechaza. `"abc"` → `:error`.

**`parsear_numero/1`** *(privada)*: `Float.parse("3")` → `{3.0, ""}` (por eso el mensaje dice
`3.0 % de verdes`). `Float.parse("92.5kg")` → `{92.5, "kg"}` → rechazado.

---

### 10.4 `liquidacion.exs` — módulo `Liquidacion`

| Líneas | Explicación |
|---|---|
| `@tarifa_base 1_000` … `@dias_cosecha 1..6` | Parámetros del problema. `1_000` es lo mismo que `1000` (el `_` solo ayuda a leer). `1..6` es un rango. |
| `def meta_diaria, do: @meta_diaria` / `def dias_cosecha, do: @dias_cosecha` | Exponen los atributos para que `Reportes` no repita los números 400 y 1..6. |

**`valor_pesaje(kilos, verdes)`**: `kilos * @tarifa_base * factor_calidad(verdes)`.
Ej.: `90 × 1000 × 0.7 = 62999.99999999999` (el float no representa 0.7 exacto) → se muestra `63000.00`.

**`factor_calidad(verdes)`** — cuatro cláusulas evaluadas en orden:

| Cláusula | Rango que atrapa | Factor |
|---|---|---|
| `when verdes <= 2` | 0 a 2 | `1.05` (+5 %) |
| `when verdes <= 5` | más de 2 hasta 5 (si llegó aquí ya es > 2) | `1.0` |
| `when verdes <= 10` | más de 5 hasta 10 | `0.9` (−10 %) |
| `factor_calidad(_verdes)` | más de 10 | `0.7` (−30 %) |

> Si se cambia el orden de las cláusulas, la tabla deja de funcionar (por ejemplo, poner
> `<= 10` primero haría que 1 % recibiera 0.9).

**`bonificacion_dia(kilos_dia)`**: recibe el **total del día**. Primera cláusula con guarda
`kilos_dia >= @kilos_para_bonificacion` → `8000`; si no, la segunda devuelve `0`. `120` exactos sí bonifican.

**`descuento_alimentacion(alimentacion, dias_trabajados)`**: la cláusula con `true` literal
multiplica `dias × 12000`. La otra (`_alimentacion`) atrapa `false`, `nil` o cualquier dato
mal digitado y devuelve `0`.

**`kilos_por_dia_de_recolector(pesajes)`**

| Línea | Explicación |
|---|---|
| `Enum.reduce(pesajes, %{}, fn p, acc ->` | Recorre los pesajes empezando con un mapa vacío. |
| `Map.update(acc, p.dia, p.kilos, &(&1 + p.kilos))` | Primer pesaje de un día: crea `dia => kilos`. Siguientes: suma. Resultado `%{1 => 125, 2 => 90}`. |

**`kilos_por_dia_finca(pesajes_validos)`**

| Línea | Explicación |
|---|---|
| `base = for dia <- @dias_cosecha, into: %{}, do: {dia, 0}` | `%{1 => 0, ..., 6 => 0}`: así los días sin pesajes aparecen con 0 kg en R3. |
| `Enum.reduce(pesajes_validos, base, fn p, acc -> Map.update(...) end)` | Igual que la anterior, pero para toda la finca y partiendo de `base`. |

**`cumple_meta_diaria?(kilos_dia)`**: `kilos_dia >= 400`. El `?` es convención para funciones que devuelven booleano.

**`kilos_por_recolector_en_dia(pesajes_validos, dia)`**: `Enum.filter` deja solo los pesajes
de ese día y `Enum.reduce` + `Map.update` suma por código: `%{"R01" => 125, "R02" => 145}`.

**`liquidar_recolector(recolector, pesajes_del_recolector)`** — regla 5

| Línea | Explicación |
|---|---|
| `kilos_por_dia = kilos_por_dia_de_recolector(...)` | Mapa día → kilos (reglas 3 y 4). |
| `suma_pesajes = ... \|> Enum.map(&valor_pesaje(&1.kilos, &1.verdes)) \|> Enum.sum()` | Regla 2 aplicada a **cada pesaje** y sumada. |
| `bonificaciones = kilos_por_dia \|> Map.values() \|> Enum.map(&bonificacion_dia/1) \|> Enum.sum()` | Regla 3 aplicada al **total de cada día**, no a cada pesaje: 70 + 55 = 125 kg el día 1 → bonifica. |
| `dias_trabajados = map_size(kilos_por_dia)` | Cada clave es un día con al menos un pesaje válido. |
| `alimentacion = descuento_alimentacion(Map.get(recolector, :alimentacion), dias_trabajados)` | Regla 4. `Map.get` evita fallar si el recolector no trae el campo. |
| `kilos_totales = ... \|> Enum.map(& &1.kilos) \|> Enum.sum()` | Kilos de la semana. |
| Mapa de retorno | `codigo`, `nombre`, `kilos`, `dias_trabajados`, `suma_pesajes`, `bonificaciones`, `alimentacion`, `bruto` (pesajes + bonificaciones) y `neto` (bruto − alimentación). Con lista vacía todo da 0 (`Enum.sum([])` es 0). |

**`liquidar(recolectores, pesajes_validos)`**

| Línea | Explicación |
|---|---|
| `pesajes_por_recolector = Enum.group_by(pesajes_validos, & &1.recolector)` | `%{"R01" => [p1, p2, ...], ...}`, recorriendo los pesajes una sola vez. |
| `Enum.map(recolectores, fn recolector -> liquidar_recolector(recolector, Map.get(pesajes_por_recolector, recolector.codigo, [])) end)` | Una liquidación por recolector, en el orden de `datos.exs`. El `[]` por defecto hace que quien no tiene pesajes aparezca con todo en 0. |

**`detalle_diario_recolector(pesajes)`** — para el desprendible

| Línea | Explicación |
|---|---|
| `\|> Enum.group_by(& &1.dia)` | `%{1 => [pesajes del día 1], 2 => [...]}`. Solo existen los días trabajados. |
| `\|> Enum.map(fn {dia, pesajes_del_dia} -> ...` | Para cada día calcula `kilos` (suma), `valor_pesajes` (suma de `valor_pesaje`) y `bonificacion` (`bonificacion_dia(kilos)`). |
| `\|> Enum.sort_by(& &1.dia)` | Ordena por día (el mapa no garantiza orden). |

**`mejores_del_dia(pesajes_validos, dia)`**: calcula los kilos por recolector de ese día y le
pide a `Util.maximos_en/1` el máximo. `:vacio` se traduce a `:sin_pesajes`.

**`mejores_por_dia(pesajes_validos)`**: `for dia <- 1..6, into: %{}` → `%{1 => {["R02"], 227}, 2 => ..., ...}`; un día sin pesajes queda como `:sin_pesajes`.

**`recolector_con_mas_dias_ganador(mejores_por_dia)`**

| Línea | Explicación |
|---|---|
| `\|> Map.values()` | Solo los resultados de cada día. |
| `\|> Enum.filter(&(&1 != :sin_pesajes))` | Quita los días sin pesajes. |
| `\|> Enum.flat_map(fn {ganadores, _kilos} -> ganadores end)` | Une las listas de ganadores: `["R02", "R01", "R02", "R05", ...]` (un empate aporta los dos). |
| `\|> Enum.frequencies()` | `%{"R02" => 2, "R01" => 1, ...}`. |
| `case Util.maximos_en(conteo)` | El o los que más días ganaron; `:vacio` → `:sin_ganadores`. |

---

### 10.5 `reportes.exs` — módulo `Reportes`

Patrón común: cada reporte arma una **lista de líneas** y al final hace
`Enum.join(lista, "\n")` para devolver un solo `String`. Nunca imprime.

**`r1(rechazados)`**

| Línea | Explicación |
|---|---|
| `case rechazados do [] -> ["No hubo pesajes rechazados."]` | Mensaje si no hay rechazos. |
| `Enum.map(rechazados, fn {pesaje, motivo} -> ...` | Para cada rechazo toma cada campo con `Map.get` (si falta da `nil`, sin fallar). |
| `recolector = texto(...)`, `lote = texto(...)` | Códigos como texto. |
| `dia = Util.formatear_numero(...)`, `kilos = ...`, `verdes = ...` | Números compactos (`80`, `2.5`, `100.5`). |
| `"#{recolector} \| #{lote} \| día #{dia} \| #{kilos} kg \| #{verdes} % -> #{motivo}"` | Línea del reporte. |
| `conteos = rechazados \|> Enum.map(fn {_p, motivo} -> motivo end) \|> Enum.frequencies()` | `%{dia_invalido: 4, ...}`. |
| `Enum.map(Validacion.motivos(), fn motivo -> "#{motivo}: #{Map.get(conteos, motivo, 0)}" end)` | Recorre los cinco motivos en orden; `Map.get(..., 0)` muestra 0 en los que no aparecen. |
| `Enum.join([...título] ++ lineas_pesajes ++ ["", "Rechazos por motivo"] ++ lineas_conteo, "\n")` | `++` concatena listas; `""` deja una línea en blanco. |

**`kilos_por_lote(pesajes_validos, lotes)`**

| Línea | Explicación |
|---|---|
| `kilos_por_id = Enum.reduce(... Map.update(acc, p.lote, p.kilos, &(&1 + p.kilos)))` | `%{"L1" => 385, ...}`. |
| `lotes \|> Enum.map(fn lote ->` | Recorre **la lista de lotes** (no el mapa de kilos) para que salgan todos. |
| `kilos = Map.get(kilos_por_id, lote.id, 0)` | Un lote sin pesajes queda en 0 kg. |
| `rendimiento = if lote.hectareas > 0, do: kilos / lote.hectareas, else: 0.0` | kg/ha, evitando dividir entre 0. |
| `\|> Enum.sort_by(& &1.rendimiento, :desc)` | Mayor rendimiento primero. |

**`r2/2`**: formatea cada lote como `Nombre | kg | ha (1 decimal) | kg/ha (2 decimales)`.

**`r3(pesajes_validos)`**

| Línea | Explicación |
|---|---|
| `kilos_por_dia = Liquidacion.kilos_por_dia_finca(pesajes_validos)` | Mapa con los 6 días. |
| `for dia <- Liquidacion.dias_cosecha() do ... end` | Una línea por día con `cumplió la meta` / `no cumplió la meta`. |
| `todos_cumplieron = Enum.all?(valores, &Liquidacion.cumple_meta_diaria?/1)` | ¿Todos los días ≥ 400? |
| `algun_dia_cumplio = Enum.any?(...)` | ¿Al menos uno? |
| `si_no/1` | Convierte `true/false` en `"Sí"/"No"`. |

**`r4(liquidaciones)`**

| Línea | Explicación |
|---|---|
| `\|> Enum.sort_by(& &1.neto, :desc)` | Mayor neto primero. Si dos tienen el mismo neto se respeta el orden de `datos.exs` (el ordenamiento es estable). |
| `\|> Enum.with_index(1)` | `[{liq, 1}, {liq, 2}, ...]` para numerar. |
| `"#{posicion}. \| #{l.nombre} \| ... \| $#{Util.formatear_dinero(l.neto)}"` | Pesos con 2 decimales y sin notación científica. |

**`r5(pesajes_validos, recolectores_por_codigo)`**

| Línea | Explicación |
|---|---|
| `mejores = Liquidacion.mejores_por_dia(pesajes_validos)` | Mapa día → `{codigos, kilos}` o `:sin_pesajes`. |
| `case mejores[dia] do :sin_pesajes -> "Día #{dia}: sin pesajes"` | Día vacío. |
| `{ganadores, kilos} -> "Día #{dia}: #{nombres_de(ganadores, ...)} (#{...} kg)"` | Si hay empate `nombres_de` los une con coma. |
| `case Liquidacion.recolector_con_mas_dias_ganador(mejores)` | Resumen final; `etiqueta_dias` pone "día" o "días". |

**`calidad_ponderada(pesajes_validos)`**

| Línea | Explicación |
|---|---|
| `\|> Enum.group_by(& &1.recolector)` | Pesajes por recolector. |
| `\|> Enum.filter(fn {_c, pesajes} -> length(pesajes) >= @minimo_pesajes_r6 end)` | Solo quienes tienen al menos 3 pesajes válidos. |
| `{:ok, ponderado} = Util.promedio_ponderado(Enum.map(pesajes, &{&1.verdes, &1.kilos}))` | Pares `{verdes, kilos}`. Siempre es `:ok` porque los pesajes ya son válidos (kilos > 0). |

**`r6/2`**: `Util.maximos_en/1` busca **máximos**, pero queremos el **menor** porcentaje. Por
eso se cambia el signo (`{c, -p}`): el mayor de los negativos es el menor porcentaje. Al
mostrarlo se vuelve a cambiar el signo (`-negativo`). Si nadie tiene 3 pesajes, se informa.

**`r7(liquidaciones)`**: `total` = suma de los netos, `kilos` = suma de kilos válidos,
`promedio = if kilos > 0, do: total / kilos, else: 0`.

**`r8(pesajes_validos, recolectores, lotes)`**

| Línea | Explicación |
|---|---|
| `ids_lotes = Enum.map(lotes, & &1.id)` | `["L1", "L2", "L3", "L4"]`. |
| `lotes_por_recolector = Enum.group_by(pesajes_validos, & &1.recolector, & &1.lote)` | El tercer argumento dice qué guardar: `%{"R02" => ["L1", "L2", "L3", "L4", "L1", ...]}`. |
| `Enum.filter(fn r -> Util.contiene_todos?(Map.get(lotes_por_recolector, r.codigo, []), ids_lotes) end)` | Deja a quien pasó por todos los lotes; se recorre la lista `recolectores` para respetar el orden. |
| `lineas = if nombres == [], do: ["Ningún recolector …"], else: nombres` | Mensaje si no hay ninguno. |

**`desprendible(recolector, pesajes_validos)`**

| Línea | Explicación |
|---|---|
| `pesajes_del_recolector = Enum.filter(...)` | Solo los de ese recolector. |
| `detalle = Liquidacion.detalle_diario_recolector(...)` | Líneas por día. |
| `liquidacion = Liquidacion.liquidar_recolector(...)` | Totales (se reutiliza la misma regla 5 que R4, así nunca se contradicen). |
| `case detalle do [] -> ["Sin pesajes válidos en la semana."]` | Recolector sin pesajes. |
| Líneas finales | Suma, bonificaciones, `Alimentación (N días): -$…` y neto. |

**`ranking(liquidaciones, opciones)`** — C.1

| Línea | Explicación |
|---|---|
| `@campos_ranking [:neto, :kilos, :bruto]`, `@ordenes_ranking [:desc, :asc]` | Valores permitidos. |
| `campo = valor_permitido(Keyword.get(opciones, :campo, :neto), @campos_ranking, :neto)` | Lee la opción (o `:neto` si no viene) y, si no es válida, usa `:neto`. |
| `orden = valor_permitido(Keyword.get(opciones, :orden, :desc), ...)` | Igual para el orden. |
| `limite = Keyword.get(opciones, :limite, length(liquidaciones))` | Por defecto, todos. |
| `limite = if is_integer(limite) and limite > 0, do: limite, else: length(liquidaciones)` | Un límite no válido (`0`, `-2`, `"3"`) se ignora. |
| `\|> Enum.sort_by(&Map.get(&1, campo), orden)` | Ordena por el campo elegido; `orden` es `:asc` o `:desc`, que `Enum.sort_by/3` acepta directamente. |
| `\|> Enum.take(limite)` | Primeros N. |
| `formatear_campo(campo, valor)` | Kilos en `kg`; neto y bruto en `$`. |

**`combinar_kilos(mapa_finca, mapa_vecina)`** — C.2: `Map.merge/3` con
`fn _dia, kilos_finca, kilos_vecina -> kilos_finca + kilos_vecina end`; la función solo se usa
para días que están en ambos mapas.

**`reporte_fincas_combinadas(pesajes_validos, finca_vecina)`**: combina el mapa de R3 con el de
la vecina, ordena por día (`Enum.sort_by(fn {dia, _} -> dia end)`) y arma el texto.

**Privadas**: `si_no/1` ("Sí"/"No"), `nombres_de/2` (códigos → nombres separados por coma; si
un código no existe muestra el código), `texto/1` (deja el texto tal cual; si no es texto usa
`Util.formatear_numero/1`).

---

### 10.6 `programa.exs` — módulo `Programa`

| Líneas | Explicación |
|---|---|
| Comentarios iniciales | Integrantes y comandos para compilar/ejecutar. |
| `@finca_vecina %{1 => 520.5, ...}` | Mapa de la vecina para C.2. |

**`main/0`**

| Paso | Línea | Explicación |
|---|---|---|
| 1 | `recolectores = Datos.recolectores()` … `pesajes = Datos.pesajes()` | Carga las listas crudas. |
| 2 | `recolectores_por_codigo = Util.indexar_por(recolectores, :codigo)` / `lotes_por_id = ...` | Mapas para buscar por clave (Parte A). |
| 3 | `{pesajes_validos, pesajes_rechazados} = Validacion.separar_pesajes(...)` | Valida todo una vez. |
| 4 | `{pesajes_validos, pesajes_rechazados} = agregar_pesaje_adicional(...)` | Se **reasignan** las variables con las listas actualizadas (en Elixir los datos no se modifican; se crea una lista nueva). |
| 5 | `liquidaciones = Liquidacion.liquidar(recolectores, pesajes_validos)` | Después del pesaje adicional, para que lo incluya. |
| 6 | `imprimir_reportes(...)` | R1–R8, ranking ×3 y C.2. |
| 7 | `mostrar_desprendible(...)` | Consulta final. |

**`agregar_pesaje_adicional({validos, rechazados}, recolectores_por_codigo, lotes_por_id)`**

| Línea | Explicación |
|---|---|
| `linea = Util.leer("Ingrese un pesaje adicional ...", :string)` | Lee la línea (o `""`). |
| `if linea == "" do ... {validos, rechazados}` | Enter: informa y devuelve las listas sin cambios. |
| `case Validacion.parsear_linea(linea) do {:error, :formato_invalido} -> ...` | Formato malo: informa, no agrega nada. |
| `{:ok, pesaje} -> case Validacion.validar_pesaje(pesaje, ...) do` | Formato bueno: mismas reglas que `datos.exs`. |
| `{:ok, pesaje_valido} -> ... {validos ++ [pesaje_valido], rechazados}` | Válido: se agrega **al final** de los válidos. |
| `{:error, motivo} -> ... {validos, rechazados ++ [{pesaje, motivo}]}` | Rechazado: se agrega al final de R1. |

**`imprimir_reportes/5`**: arma la lista de textos en orden y la recorre con
`Enum.each(reportes, fn reporte -> Util.imprimir_mensaje(reporte <> "\n") end)`; el `"\n"`
extra deja una línea en blanco entre reportes.

**`mostrar_desprendible(recolectores_por_codigo, pesajes_validos)`**

| Línea | Explicación |
|---|---|
| `codigo = Util.leer(...)` | Lee el código. |
| `case Map.get(recolectores_por_codigo, codigo) do nil when codigo == "" ->` | Enter sin código. |
| `nil -> "No existe un recolector con el código #{codigo}."` | Código inexistente: informa sin fallar. |
| `recolector -> Util.imprimir_mensaje(Reportes.desprendible(recolector, pesajes_validos))` | Imprime el desprendible. |

**`Programa.main()`** (última línea del archivo): es lo que hace que `elixir programa.exs`
ejecute el programa; sin ella el archivo solo definiría el módulo.

---

### 10.7 `verificacion_anexo.exs` — módulo `VerificacionAnexo`

| Líneas | Explicación |
|---|---|
| `@recolectores`, `@lotes`, `@pesajes` | Copia exacta de los datos del Anexo (independiente de `datos.exs`). |
| `por_codigo`, `por_id`, `{validos, rechazados}`, `liquidaciones` | El mismo flujo que `Programa.main/0`, sin consola. |
| `neto_de = fn codigo -> ... end` | Función anónima auxiliar: neto de un código. |
| `comprobaciones = [{"descripción", condición}, ...]` | Cada tupla es una prueba; la condición es un `==` entre lo calculado y lo esperado en el Anexo. Los pesos se comparan ya formateados (`"63000.00"`) para evitar problemas de decimales. |
| `Enum.each(comprobaciones, ...)` | Imprime `OK` o `FALLO` por cada una. |
| `fallos = Enum.count(...)` | Cuántas fallaron. |
| Lista final de reportes | Muestra los reportes con los datos del Anexo para compararlos a ojo. |

---
## 11. Guía de problemas: si algo falla, qué revisar

| Síntoma | Causa probable | Dónde mirar / qué hacer |
|---|---|---|
| `** (UndefinedFunctionError) function Datos.pesajes/0 is undefined (module Datos is not available)` | No se compiló `datos.exs` (o se ejecutó desde otra carpeta). | Ejecutar `elixirc datos.exs util.exs validacion.exs liquidacion.exs reportes.exs` **en la misma carpeta** donde se corre `elixir programa.exs`. |
| Cambié `datos.exs` y la salida no cambia | El `.beam` viejo sigue ahí. | `elixirc datos.exs` otra vez. |
| `error: cannot define module Reportes because it is currently being defined` (o `warning: redefining module Reportes`) | Hay dos archivos con `defmodule Reportes` (por ejemplo, alguien volvió a subir `reportes_p1.exs`). | Dejar un solo módulo por nombre. |
| `UndefinedFunctionError` en `Validacion.xxx` / `Reportes.xxx` | El nombre o la aridad (número de argumentos) que usa `Programa` no coincide con el del módulo. | Comparar la llamada en `programa.exs` con el `def` (sección 5). |
| Un pesaje que debería ser válido aparece en R1 | Un límite mal escrito o un código con otra mayúscula. | Atributos de `validacion.exs`; el motivo en R1 dice qué regla falló. |
| R1 informa un motivo distinto al esperado | Orden de los pasos del `with`. | `Validacion.validar_pesaje/3`: el orden debe ser recolector, lote, día, kilos, verdes. |
| Un valor da `62999.99999999999` | Normal en floats. | Mostrarlo siempre con `Util.formatear_dinero/1`; en comparaciones usar el texto formateado. |
| Un valor de pesaje no coincide | Tabla de calidad. | `Liquidacion.factor_calidad/1`: orden de las cláusulas y si el límite es `<=` o `<`. |
| La bonificación sale por pesaje y no por día | Se aplicó `bonificacion_dia/1` a cada pesaje. | `liquidar_recolector/2` debe aplicarla sobre `kilos_por_dia` (totales del día). |
| La alimentación cuenta días de más | Se contaron pesajes en lugar de días. | `dias_trabajados = map_size(kilos_por_dia)`. |
| Falta un día en R3 o un lote en R2 | Se recorrió el mapa de kilos en vez de la lista completa. | `kilos_por_dia_finca/1` (base con los 6 días en 0) y `kilos_por_lote/2` (recorre `lotes`). |
| En R5 falta un empatado | — | `Util.maximos_en/1` devuelve todas las claves con el máximo. |
| `ArithmeticError` (división entre 0) | Lote con 0 ha o semana sin kilos. | Ya está protegido en `kilos_por_lote/2` y `r7/1`; revisar si se agregó una división nueva. |
| `KeyError key :xxx not found` | Se usó `mapa.campo` sobre un dato que puede no traer ese campo. | En datos crudos usar `Map.get(mapa, :campo)`, como en `Validacion` y `r1/1`. |
| `FunctionClauseError` | Ninguna cláusula de una función aceptó el argumento. | Agregar una cláusula general (`def f(_)`) que devuelva `{:error, ...}` o un valor por defecto. |
| El programa se queda esperando | Está en `IO.gets` esperando una línea. | Escribir la línea o Enter. Con `printf` hay que mandar dos líneas (pesaje y código). |
| `elixir verificacion_anexo.exs` muestra `FALLO` | Un cambio rompió una regla. | La descripción del `FALLO` dice qué regla o reporte revisar. |

---

## 12. Cómo hacer cambios en vivo (sustentación)

**Otro umbral o valor** (bonificación con 100 kg, tarifa de 1.200, meta de 500): cambiar el
atributo al inicio de `liquidacion.exs` (`@kilos_para_bonificacion`, `@tarifa_base`,
`@meta_diaria`…) y recompilar `elixirc liquidacion.exs`.

**Otro límite de validación** (máximo 300 kg por pesaje): cambiar `@kilos_maximos_por_pesaje`
en `validacion.exs` y recompilar.

**Cambiar la tabla de calidad**: editar las guardas y factores de `Liquidacion.factor_calidad/1`,
manteniendo el orden de menor a mayor.

**Nuevo motivo de rechazo** (por ejemplo, "los kilos deben ser múltiplo de 0.5"):

1. En `validacion.exs` crear la función de la regla, que devuelva `{:ok, valor}` o `{:error, :nuevo_motivo}`:
   ```elixir
   def validar_multiplo(kilos) do
     if kilos * 2 == round(kilos * 2), do: {:ok, kilos}, else: {:error, :kilos_no_multiplo}
   end
   ```
2. Agregar el paso en el `with` de `validar_pesaje/3`, **en la posición** que diga el enunciado:
   `{:ok, _} <- validar_multiplo(Map.get(pesaje, :kilos)),`
3. Agregar `:kilos_no_multiplo` a `motivos/0` en el mismo orden, para que salga en el conteo de R1.
4. `elixirc validacion.exs` y ejecutar.

**Nuevo reporte** (por ejemplo, R9 "kilos totales por recolector"):

1. En `reportes.exs`, una función pura que devuelva el texto:
   ```elixir
   def r9(liquidaciones) do
     lineas = Enum.map(liquidaciones, fn l -> "#{l.nombre}: #{Util.formatear_numero(l.kilos)} kg" end)
     Enum.join(["R9. Kilos por recolector" | lineas], "\n")
   end
   ```
2. En `programa.exs`, agregar `Reportes.r9(liquidaciones)` a la lista de `imprimir_reportes/5`.
3. `elixirc reportes.exs` y `elixir programa.exs`.

**Nuevo campo en el ranking** (por ejemplo, `:bonificaciones`): agregarlo a `@campos_ranking`
en `reportes.exs`; si es un valor en pesos, `formatear_campo/2` ya lo muestra con `$`.
