defmodule Liquidacion do
  @moduledoc """
  Reglas de negocio 2 a 5 (valor del pesaje, bonificación, descuento de
  alimentación y neto), más las agregaciones por día que necesitan los
  reportes R3 y R5.

  El ajuste de calidad de la regla 2 se apoya en dos funciones de
  `Util`: una bonificación es un recargo porcentual (`Util.
  calcular_total_con_impuesto`) y un descuento es exactamente eso
  (`Util.calcular_descuento`); el tramo "sin ajuste" se resuelve con
  un descuento del 0 %, así las cuatro franjas de la tabla usan el
  mismo mecanismo en vez de tener una fórmula manual para cada una.

  El "¿quién(es) llegaron más alto, con empates?" de R5 (mejor
  recolector del día, y quién lo fue en más días) se resuelve con
  `Util.maximos_en/1`, en vez de repetir la búsqueda del máximo y el
  filtro de empatados en cada función.

  Todas las funciones de este módulo son puras: reciben datos y
  devuelven datos, sin leer ni imprimir nada.
  """

  @tarifa_base 1_000
  @kilos_para_bonificacion 120
  @bonificacion_diaria 8_000
  @descuento_alimentacion_dia 12_000
  @meta_diaria 400
  @dias_cosecha 1..6

  # ---------------------------------------------------------------
  # Regla 2. Valor de un pesaje
  # ---------------------------------------------------------------

  @doc """
  Valor de un pesaje válido: kilos × tarifa base, ajustado según el
  porcentaje de granos verdes de la muestra (tabla del enunciado).
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

  # ---------------------------------------------------------------
  # Regla 3. Bonificación por productividad
  # ---------------------------------------------------------------

  @doc "Bonificación de un recolector en un día, a partir de sus kilos válidos ese día."
  def bonificacion_dia(kilos_dia) when kilos_dia >= @kilos_para_bonificacion,
    do: @bonificacion_diaria

  def bonificacion_dia(_kilos_dia), do: 0

  # ---------------------------------------------------------------
  # Regla 4. Descuento de alimentación
  # ---------------------------------------------------------------

  @doc "Descuento total de alimentación, según si el recolector come en la finca y cuántos días trabajó."
  def descuento_alimentacion(true, dias_trabajados), do: dias_trabajados * @descuento_alimentacion_dia
  def descuento_alimentacion(false, _dias_trabajados), do: 0

  # ---------------------------------------------------------------
  # Agrupaciones base (las reutilizan la liquidación, R3, R5 y el
  # desprendible de pago de B.5)
  # ---------------------------------------------------------------

  @doc "Suma de kilos válidos de UN recolector, agrupados por día. %{dia => kilos}"
  def kilos_por_dia_de_recolector(pesajes_del_recolector) do
    Enum.reduce(pesajes_del_recolector, %{}, fn p, acc ->
      Map.update(acc, p.dia, p.kilos, &(&1 + p.kilos))
    end)
  end

  @doc "Kilos válidos de TODA la finca, agrupados por día. Incluye los 6 días aunque alguno no tenga pesajes (queda en 0)."
  def kilos_por_dia_finca(pesajes_validos) do
    base = for dia <- @dias_cosecha, into: %{}, do: {dia, 0}

    Enum.reduce(pesajes_validos, base, fn p, acc ->
      Map.update(acc, p.dia, p.kilos, &(&1 + p.kilos))
    end)
  end

  @doc "¿Los kilos de un día alcanzan la meta diaria de la finca?"
  def cumple_meta_diaria?(kilos_dia), do: kilos_dia >= @meta_diaria

  @doc "Kilos válidos de cada recolector en UN día específico. %{codigo => kilos}"
  def kilos_por_recolector_en_dia(pesajes_validos, dia) do
    pesajes_validos
    |> Enum.filter(&(&1.dia == dia))
    |> Enum.reduce(%{}, fn p, acc -> Map.update(acc, p.recolector, p.kilos, &(&1 + p.kilos)) end)
  end

  # ---------------------------------------------------------------
  # Regla 5. Liquidación (neto) — usa las reglas 2, 3 y 4
  # ---------------------------------------------------------------

  @doc """
  Liquidación de un recolector a partir de SUS pesajes ya válidos.
  Si la lista viene vacía, todo queda en cero (recolector sin pesajes
  válidos igual aparece en la liquidación).
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

  @doc """
  Liquidación de TODOS los recolectores (los que no tuvieron ningún
  pesaje válido igual salen, con todo en cero).
  """
  def liquidar(recolectores, pesajes_validos) do
    Enum.map(recolectores, fn recolector ->
      pesajes_del_recolector = Enum.filter(pesajes_validos, &(&1.recolector == recolector.codigo))
      liquidar_recolector(recolector, pesajes_del_recolector)
    end)
  end

  @doc """
  Detalle día por día de UN recolector (kilos, valor de sus pesajes y
  bonificación de ese día), ordenado por día. Lo usa el desprendible
  de pago de B.5.
  """
  def detalle_diario_recolector(pesajes_del_recolector) do
    pesajes_del_recolector
    |> Enum.group_by(& &1.dia)
    |> Enum.map(fn {dia, pesajes_del_dia} ->
      kilos = pesajes_del_dia |> Enum.map(& &1.kilos) |> Enum.sum()
      valor_pesajes = pesajes_del_dia |> Enum.map(&valor_pesaje(&1.kilos, &1.verdes)) |> Enum.sum()

      %{dia: dia, kilos: kilos, valor_pesajes: valor_pesajes, bonificacion: bonificacion_dia(kilos)}
    end)
    |> Enum.sort_by(& &1.dia)
  end

  # ---------------------------------------------------------------
  # Datos base para R5 (el texto del reporte lo arma Reportes)
  # ---------------------------------------------------------------

  @doc """
  Ganador(es) de UN día: todos los recolectores empatados en el máximo
  de kilos ese día. Devuelve {lista_codigos, kilos} o :sin_pesajes si
  nadie tuvo pesajes válidos ese día.
  """
  def mejores_del_dia(pesajes_validos, dia) do
    case pesajes_validos |> kilos_por_recolector_en_dia(dia) |> Util.maximos_en() do
      :vacio -> :sin_pesajes
      {ganadores, kilos} -> {ganadores, kilos}
    end
  end

  @doc "Ganador(es) de cada uno de los 6 días. %{dia => {ganadores, kilos} | :sin_pesajes}"
  def mejores_por_dia(pesajes_validos) do
    for dia <- @dias_cosecha, into: %{} do
      {dia, mejores_del_dia(pesajes_validos, dia)}
    end
  end

  @doc """
  Recolector(es) que fueron el mejor en más días. Si un día tuvo
  empate, cuenta para todos los empatados. Devuelve {lista_codigos,
  cantidad_dias} o :sin_ganadores si ningún día tuvo pesajes válidos.
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
