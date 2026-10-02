defmodule Liquidacion do
  @moduledoc """
  Módulo encargado de calcular el valor de los pesajes, bonificaciones, alimentación y
  resultados de liquidación para cada recolector
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

  @doc """
  Calcula el valor pagado por un pesaje según la cantidad de kilos y el porcentaje de verdes.
  """
  def valor_pesaje(kilos, verdes) do
    kilos * @tarifa_base * factor_calidad(verdes)
  end

  @doc """
  Devuelve el factor que ajusta el valor de un pesaje según el porcentaje de granos verdes.
  """
  def factor_calidad(verdes) when verdes <= 2, do: 1.05
  def factor_calidad(verdes) when verdes <= 5, do: 1.0
  def factor_calidad(verdes) when verdes <= 10, do: 0.9
  def factor_calidad(_verdes), do: 0.7

  @doc """
  Determina si un recolector recibe bonificación por alcanzar la cantidad mínima de kilos
  en un día.
  """
  def bonificacion_dia(kilos_dia) when kilos_dia >= @kilos_para_bonificacion,
    do: @bonificacion_diaria

  def bonificacion_dia(_kilos_dia), do: 0

  @doc """
  Calcula el descuento de alimentación según si el recolector come en la finca y la
  cantidad de días trabajados (días con al menos un pesaje válido).
  """
  def descuento_alimentacion(true, dias_trabajados),
    do: dias_trabajados * @descuento_alimentacion_dia

  def descuento_alimentacion(_alimentacion, _dias_trabajados), do: 0

  @doc """
  Agrupa los kilos de un recolector por día.
  """
  def kilos_por_dia_de_recolector(pesajes_del_recolector) do
    Enum.reduce(pesajes_del_recolector, %{}, fn p, acc ->
      Map.update(acc, p.dia, p.kilos, &(&1 + p.kilos))
    end)
  end

  @doc """
  Agrupa los kilos de toda la finca por día.
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
  """
  def kilos_por_recolector_en_dia(pesajes_validos, dia) do
    pesajes_validos
    |> Enum.filter(&(&1.dia == dia))
    |> Enum.reduce(%{}, fn p, acc -> Map.update(acc, p.recolector, p.kilos, &(&1 + p.kilos)) end)
  end

  @doc """
  Calcula la liquidación individual de un recolector en función de sus pesajes válidos.
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
  """
  def liquidar(recolectores, pesajes_validos) do
    pesajes_por_recolector = Enum.group_by(pesajes_validos, & &1.recolector)

    Enum.map(recolectores, fn recolector ->
      liquidar_recolector(recolector, Map.get(pesajes_por_recolector, recolector.codigo, []))
    end)
  end

  @doc """
  Calcula el detalle diario de un recolector para el desprendible de pago.
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

  @doc """
  Obtiene el (o los, si hay empate) mejor recolector de un día según los kilos entregados.
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
