defmodule Liquidacion do
  @moduledoc """
  Módulo encargado de calcular el valor de los pesajes, bonificaciones, alimentación y
  resultados de liquidación para cada recolector.

  La lógica de negocio está centrada en la semana de cosecha y en la evaluación de los
  kilos acumulados por día y por finca.
  """

  @tarifa_base 1_000
  @kilos_para_bonificacion 120
  @bonificacion_diaria 8_000
  @descuento_alimentacion_dia 12_000
  @meta_diaria 400
  @dias_cosecha 1..6

  @doc """
  Calcula el valor pagado por un pesaje según la cantidad de kilos y el porcentaje de verdes.

  La fórmula aplica una tarifa base por kilo y ajusta el valor según la calidad del fruto.
  """
  def valor_pesaje(kilos, verdes) do
    base = kilos * @tarifa_base
    {:ok, %{total: total}} = ajuste_por_calidad(base, verdes)
    total
  end

  # Hasta 2 %: bonificación del 5 % -> un recargo, como el que calcula
  # Util.calcular_total_con_impuesto (subtotal + impuesto).
  defp ajuste_por_calidad(base, verdes) when verdes <= 2,
    do: Util.calcular_total_con_impuesto(base, 5)

  # Más de 2 % y hasta 5 %: sin ajuste = un "descuento" del 0 %.
  defp ajuste_por_calidad(base, verdes) when verdes <= 5,
    do: Util.calcular_descuento(base, 0)

  # Más de 5 % y hasta 10 %: descuento del 10 %.
  defp ajuste_por_calidad(base, verdes) when verdes <= 10,
    do: Util.calcular_descuento(base, 10)

  # Más de 10 %: descuento del 30 %.
  defp ajuste_por_calidad(base, _verdes),
    do: Util.calcular_descuento(base, 30)

  @doc "Determina si un recolector recibe bonificación por alcanzar la cantidad mínima de kilos en un día."
  def bonificacion_dia(kilos_dia) when kilos_dia >= @kilos_para_bonificacion,
    do: @bonificacion_diaria

  @doc "Devuelve 0 cuando un día no alcanza la meta de kilos para bonificación."
  def bonificacion_dia(_kilos_dia), do: 0

  @doc "Calcula el costo de alimentación según si el recolector tiene alimentación y la cantidad de días trabajados."
  def descuento_alimentacion(true, dias_trabajados),
    do: dias_trabajados * @descuento_alimentacion_dia

  def descuento_alimentacion(false, _dias_trabajados), do: 0

  @doc """
  Agrupa los kilos de un recolector por día.

  Ejemplo de salida:

      %{1 => 220, 2 => 150}
  """
  def kilos_por_dia_de_recolector(pesajes_del_recolector) do
    Enum.reduce(pesajes_del_recolector, %{}, fn p, acc ->
      Map.update(acc, p.dia, p.kilos, &(&1 + p.kilos))
    end)
  end

  @doc """
  Agrupa los kilos de toda la finca por día.

  Incluir los 6 días de la cosecha aunque alguno no tenga pesajes, con valor 0.
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

      %{"R01" => 200, "R02" => 120}
  """
  def kilos_por_recolector_en_dia(pesajes_validos, dia) do
    pesajes_validos
    |> Enum.filter(&(&1.dia == dia))
    |> Enum.reduce(%{}, fn p, acc -> Map.update(acc, p.recolector, p.kilos, &(&1 + p.kilos)) end)
  end

  @doc "Calcula la liquidación individual de un recolector en función de sus pesajes."
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

    dias_trabajados = kilos_por_dia |> Map.keys() |> length()
    alimentacion = descuento_alimentacion(recolector.alimentacion, dias_trabajados)

    kilos_totales = pesajes_validos_del_recolector |> Enum.map(& &1.kilos) |> Enum.sum()

    %{
      codigo: recolector.codigo,
      nombre: recolector.nombre,
      kilos: kilos_totales,
      suma_pesajes: suma_pesajes,
      bonificaciones: bonificaciones,
      alimentacion: alimentacion,
      neto: suma_pesajes + bonificaciones - alimentacion
    }
  end

  @doc "Genera la liquidación completa de todos los recolectores disponibles."
  def liquidar(recolectores, pesajes_validos) do
    Enum.map(recolectores, fn recolector ->
      pesajes_del_recolector = Enum.filter(pesajes_validos, &(&1.recolector == recolector.codigo))
      liquidar_recolector(recolector, pesajes_del_recolector)
    end)
  end

  @doc "Calcula el detalle diario de un recolector: kilos, valor de pesajes y bonificación."
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

  @doc "Obtiene el mejor recolector del día según los kilos entregados."
  def mejores_del_dia(pesajes_validos, dia) do
    case pesajes_validos |> kilos_por_recolector_en_dia(dia) |> Util.maximos_en() do
      :vacio -> :sin_pesajes
      {ganadores, kilos} -> {ganadores, kilos}
    end
  end

  @doc "Genera el resultado para cada día de la semana con el mejor recolector del día."
  def mejores_por_dia(pesajes_validos) do
    for dia <- @dias_cosecha, into: %{} do
      {dia, mejores_del_dia(pesajes_validos, dia)}
    end
  end

  @doc "Determina cuál recolector fue el mejor en más días del período."
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
