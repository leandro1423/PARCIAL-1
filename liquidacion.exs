# Integrantes: Leandro, Martin, Samuel
# Programación III - Parcial 1: Liquidación de la cosecha de una finca cafetera

defmodule Liquidacion do
  @moduledoc """
  Módulo encargado de calcular el valor de los pesajes, bonificaciones, alimentación y
  resultados de liquidación para cada recolector (reglas de negocio 2 a 5).

  La lógica de negocio está centrada en la semana de cosecha y en la evaluación de los
  kilos acumulados por día y por finca. También contiene los agrupamientos de kilos que
  necesitan varios reportes (por día de la finca, por recolector y día, mejores del día).

  Todas las funciones son **puras**: reciben listas de pesajes **ya validados** y
  devuelven números, listas o mapas. Nunca imprimen.

  Los parámetros del problema se definen como atributos de módulo; para cambiar una regla
  (por ejemplo, otro umbral de bonificación) basta con cambiar el atributo correspondiente.
  """

  @tarifa_base 1_000
  @kilos_para_bonificacion 120
  @bonificacion_diaria 8_000
  @descuento_alimentacion_dia 12_000
  @meta_diaria 400
  @dias_cosecha 1..6

  @doc "Meta diaria de kilos de la finca (la usa `Reportes.r3/1` en el título del reporte)."
  def meta_diaria, do: @meta_diaria

  @doc "Rango con los días de cosecha (1..6). Lo usan los reportes que recorren todos los días."
  def dias_cosecha, do: @dias_cosecha

  # ---------------------------------------------------------------------------
  # Regla 2: valor de un pesaje
  # ---------------------------------------------------------------------------

  @doc """
  Calcula el valor pagado por un pesaje según la cantidad de kilos y el porcentaje de verdes.

  La fórmula aplica la tarifa base por kilo y la multiplica por el factor de calidad:

      valor = kilos × tarifa_base × factor_calidad(verdes)

  Ejemplo del enunciado: `valor_pesaje(70, 1.5)` = 70 × 1.000 × 1,05 = 73.500.

  El resultado puede quedar como `62999.99999999999` en lugar de `63000` porque los decimales
  se guardan de forma aproximada; al mostrarlo con dos decimales queda `63000.00`.
  """
  def valor_pesaje(kilos, verdes) do
    kilos * @tarifa_base * factor_calidad(verdes)
  end

  @doc """
  Devuelve el factor que ajusta el valor de un pesaje según el porcentaje de granos verdes.

  | Porcentaje de verdes      | Ajuste                 | Factor |
  |---------------------------|------------------------|--------|
  | Hasta 2 %                 | Bonificación del 5 %   | 1.05   |
  | Más de 2 % y hasta 5 %    | Sin ajuste             | 1.00   |
  | Más de 5 % y hasta 10 %   | Descuento del 10 %     | 0.90   |
  | Más de 10 %               | Descuento del 30 %     | 0.70   |

  Las cláusulas se evalúan de arriba hacia abajo, por eso cada guarda solo necesita revisar
  el límite superior: si `verdes` llegó a la segunda cláusula es porque ya es mayor que 2.
  """
  def factor_calidad(verdes) when verdes <= 2, do: 1.05
  def factor_calidad(verdes) when verdes <= 5, do: 1.0
  def factor_calidad(verdes) when verdes <= 10, do: 0.9
  def factor_calidad(_verdes), do: 0.7

  # ---------------------------------------------------------------------------
  # Regla 3: bonificación por productividad
  # ---------------------------------------------------------------------------

  @doc """
  Determina si un recolector recibe bonificación por alcanzar la cantidad mínima de kilos
  en un día.

  Recibe el **total de kilos del día** (no un pesaje suelto): con 120 kg o más devuelve
  8.000; con menos devuelve 0.
  """
  def bonificacion_dia(kilos_dia) when kilos_dia >= @kilos_para_bonificacion,
    do: @bonificacion_diaria

  def bonificacion_dia(_kilos_dia), do: 0

  # ---------------------------------------------------------------------------
  # Regla 4: descuento de alimentación
  # ---------------------------------------------------------------------------

  @doc """
  Calcula el descuento de alimentación según si el recolector come en la finca y la
  cantidad de días trabajados (días con al menos un pesaje válido).

  Si `alimentacion` es `true` se descuentan 12.000 por día; con cualquier otro valor
  (`false`, `nil` o un dato mal digitado) el descuento es 0.
  """
  def descuento_alimentacion(true, dias_trabajados),
    do: dias_trabajados * @descuento_alimentacion_dia

  def descuento_alimentacion(_alimentacion, _dias_trabajados), do: 0

  # ---------------------------------------------------------------------------
  # Agrupamientos de kilos
  # ---------------------------------------------------------------------------

  @doc """
  Agrupa los kilos de un recolector por día.

  Es la estructura que necesitan las reglas 3 y 4: las claves son los días trabajados y los
  valores, el total de kilos de ese día.

  Ejemplo de salida:

      %{1 => 125, 2 => 90}
  """
  def kilos_por_dia_de_recolector(pesajes_del_recolector) do
    Enum.reduce(pesajes_del_recolector, %{}, fn p, acc ->
      Map.update(acc, p.dia, p.kilos, &(&1 + p.kilos))
    end)
  end

  @doc """
  Agrupa los kilos de toda la finca por día.

  Incluye los 6 días de la cosecha aunque alguno no tenga pesajes, con valor 0 (R3).

      %{1 => 410, 2 => 300.5, 3 => 245, 4 => 0, 5 => 0, 6 => 0}
  """
  def kilos_por_dia_finca(pesajes_validos) do
    base = for dia <- @dias_cosecha, into: %{}, do: {dia, 0}

    Enum.reduce(pesajes_validos, base, fn p, acc ->
      Map.update(acc, p.dia, p.kilos, &(&1 + p.kilos))
    end)
  end

  @doc "Indica si la meta diaria de la finca fue cumplida con la cantidad de kilos dada."
  def cumple_meta_diaria?(kilos_dia), do: kilos_dia >= @meta_diaria

  @doc """
  Retorna los kilos agrupados por recolector para un día específico.

  La estructura resultante es:

      %{"R01" => 125, "R02" => 145}
  """
  def kilos_por_recolector_en_dia(pesajes_validos, dia) do
    pesajes_validos
    |> Enum.filter(&(&1.dia == dia))
    |> Enum.reduce(%{}, fn p, acc -> Map.update(acc, p.recolector, p.kilos, &(&1 + p.kilos)) end)
  end

  # ---------------------------------------------------------------------------
  # Regla 5: liquidación
  # ---------------------------------------------------------------------------

  @doc """
  Calcula la liquidación individual de un recolector en función de sus pesajes válidos.

  Devuelve un mapa con:

    * `kilos`: total de kilos válidos de la semana.
    * `suma_pesajes`: suma de `valor_pesaje/2` de cada pesaje (regla 2).
    * `bonificaciones`: suma de `bonificacion_dia/1` sobre el total de cada día (regla 3).
    * `alimentacion`: `descuento_alimentacion/2` según los días trabajados (regla 4).
    * `bruto`: `suma_pesajes + bonificaciones` (lo ganado antes del descuento).
    * `neto`: `suma_pesajes + bonificaciones - alimentacion` (regla 5).

  Si la lista de pesajes está vacía todos los valores quedan en 0, como pide la regla 5.
  """
  def liquidar_recolector(recolector, pesajes_validos_del_recolector) do
    kilos_por_dia = kilos_por_dia_de_recolector(pesajes_validos_del_recolector)

    suma_pesajes =
      pesajes_validos_del_recolector
      |> Enum.map(&valor_pesaje(&1.kilos, &1.verdes))
      |> Enum.sum()

    bonificaciones =
      kilos_por_dia
      |> Map.values()
      |> Enum.map(&bonificacion_dia/1)
      |> Enum.sum()

    dias_trabajados = map_size(kilos_por_dia)

    alimentacion =
      descuento_alimentacion(Map.get(recolector, :alimentacion), dias_trabajados)

    kilos_totales = pesajes_validos_del_recolector |> Enum.map(& &1.kilos) |> Enum.sum()

    %{
      codigo: recolector.codigo,
      nombre: recolector.nombre,
      kilos: kilos_totales,
      dias_trabajados: dias_trabajados,
      suma_pesajes: suma_pesajes,
      bonificaciones: bonificaciones,
      alimentacion: alimentacion,
      bruto: suma_pesajes + bonificaciones,
      neto: suma_pesajes + bonificaciones - alimentacion
    }
  end

  @doc """
  Genera la liquidación completa de todos los recolectores, en el orden de `recolectores`.

  Los pesajes se agrupan **una sola vez** por código de recolector con `Enum.group_by/2`,
  y luego cada recolector toma su grupo con `Map.get/3` (lista vacía si no tiene pesajes,
  así aparece igual en la liquidación con todo en cero).
  """
  def liquidar(recolectores, pesajes_validos) do
    pesajes_por_recolector = Enum.group_by(pesajes_validos, & &1.recolector)

    Enum.map(recolectores, fn recolector ->
      liquidar_recolector(recolector, Map.get(pesajes_por_recolector, recolector.codigo, []))
    end)
  end

  @doc """
  Calcula el detalle diario de un recolector para el desprendible de pago.

  Devuelve una lista ordenada por día con `%{dia:, kilos:, valor_pesajes:, bonificacion:}`.
  Solo aparecen los días en que el recolector tiene pesajes válidos.
  """
  def detalle_diario_recolector(pesajes_del_recolector) do
    pesajes_del_recolector
    |> Enum.group_by(& &1.dia)
    |> Enum.map(fn {dia, pesajes_del_dia} ->
      kilos = pesajes_del_dia |> Enum.map(& &1.kilos) |> Enum.sum()

      valor_pesajes =
        pesajes_del_dia |> Enum.map(&valor_pesaje(&1.kilos, &1.verdes)) |> Enum.sum()

      %{
        dia: dia,
        kilos: kilos,
        valor_pesajes: valor_pesajes,
        bonificacion: bonificacion_dia(kilos)
      }
    end)
    |> Enum.sort_by(& &1.dia)
  end

  # ---------------------------------------------------------------------------
  # Mejores recolectores (R5)
  # ---------------------------------------------------------------------------

  @doc """
  Obtiene el (o los, si hay empate) mejor recolector de un día según los kilos entregados.

  Devuelve `{codigos_ganadores, kilos}` o `:sin_pesajes` si ese día nadie entregó café.
  """
  def mejores_del_dia(pesajes_validos, dia) do
    case pesajes_validos |> kilos_por_recolector_en_dia(dia) |> Util.maximos_en() do
      :vacio -> :sin_pesajes
      {ganadores, kilos} -> {ganadores, kilos}
    end
  end

  @doc """
  Genera un mapa `%{dia => resultado}` con el mejor recolector de cada uno de los 6 días.
  """
  def mejores_por_dia(pesajes_validos) do
    for dia <- @dias_cosecha, into: %{} do
      {dia, mejores_del_dia(pesajes_validos, dia)}
    end
  end

  @doc """
  Determina cuál recolector fue el mejor en más días del período.

  Cuenta cuántas veces aparece cada código como ganador (un empate le suma un día a cada
  empatado) y devuelve `{codigos, dias}` con todos los que tienen el máximo, o
  `:sin_ganadores` si ningún día tuvo pesajes.
  """
  def recolector_con_mas_dias_ganador(mejores_por_dia) do
    conteo =
      mejores_por_dia
      |> Map.values()
      |> Enum.filter(&(&1 != :sin_pesajes))
      |> Enum.flat_map(fn {ganadores, _kilos} -> ganadores end)
      |> Enum.frequencies()

    case Util.maximos_en(conteo) do
      :vacio -> :sin_ganadores
      {ganadores, dias} -> {ganadores, dias}
    end
  end
end
