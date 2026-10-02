# Parcial 1 - Programación III

Este proyecto implementa una aplicación de liquidación agrícola para recolectores de café en Elixir. Carga datos de cosechas, valida pesajes bajo reglas de negocio, liquida pagos y genera reportes detallados de la semana.

## Módulos principales

* `Datos`: define la información base de recolectores, lotes y pesajes.
* `Util`: contiene utilidades de entrada/salida, validaciones genéricas, formateo y cálculos.
* `Validacion`: aplica las verificaciones del negocio y separa pesajes válidos de rechazados.
* `Liquidacion`: calcula el valor por día, bonificaciones, alimentación y netos finales.
* `Reportes`: genera los reportes de producción, rankings, calidad y desprendibles de pago.
* `Programa`: orquesta el flujo principal de la aplicación y la interacción por consola.

## Flujo general

1. Se cargan los datos iniciales desde `Datos`.
2. Se validan los pesajes con la lógica de negocio (`Validacion`).
3. Se agregan nuevos pesajes desde consola cuando se solicita.
4. Se liquida cada recolector y se calculan los pagos (`Liquidacion`).
5. Se muestran los reportes de la finca y el desprendible de un recolector (`Reportes`).

## Cómo ejecutar

```bash
elixirc datos.exs util.exs validacion.exs liquidacion.exs reportes.exs
elixir programa.exs
```

## Nota

El proyecto mantiene la lógica de negocio en funciones puras y utiliza documentación con `@moduledoc` y `@doc` para dejar la API clara para futuras revisiones o mantenimiento.