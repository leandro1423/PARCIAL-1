<<<<<<< HEAD
hola profe 
=======
# Parcial 1 - Programación III

Este proyecto implementa una pequeña aplicación de liquidación agrícola para recolectores. El flujo principal carga datos, valida pesajes, calcula pagos y genera reportes de la semana.

## Módulos principales

- `Datos`: define la información base de recolectores, lotes y pesajes.
- `Util`: contiene utilidades de entrada, validación, formateo y cálculo.
- `Liquidacion`: calcula valores por día, bonificaciones, alimentación y resultados finales.
- `Reportes`: genera los reportes de lectura y resumen para la finca.
- `Programa`: orquesta el flujo principal de la aplicación.

## Flujo general

1. Se cargan los datos iniciales desde `Datos`.
2. Se validan los pesajes con la lógica de negocio.
3. Se agregan nuevos pesajes desde consola cuando se solicita.
4. Se liquida cada recolector y se calculan los pagos.
5. Se muestran los reportes y el desprendible de un recolector.

## Cómo ejecutar

```bash
elixir programa.exs
```

## Nota

El proyecto usa documentación con `@moduledoc` y `@doc` para dejar la API y la lógica más clara para futuras revisiones o mantenimiento.
>>>>>>> origin/martin
