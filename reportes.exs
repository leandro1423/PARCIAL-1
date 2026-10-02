defmodule Reportes do
  @moduledoc """
  Construye el texto de los ocho reportes (R1 a R8), el desprendible de pago, el ranking
  con opciones (C.1) y la combinación con la finca vecina (C.2).


  @doc ""Reporte R1: lista los pesajes rechazados con su motivo y cuenta los rechazos por motivo.

  Recibe la lista de tuplas `{pesaje, motivo}` que produce `Validacion.separar_pesajes/3`.
  El conteo muestra los cinco motivos en el orden de validación, incluso los que quedaron en 0.
  Se usa `Map.get/2` (y no `pesaje.kilos`) para que un pesaje al que le falte un campo no
  haga fallar el reporte."
  """
  def r1(rechazados) do
    lineas_pesajes =
      case rechazados do
        [] ->
          ["No hubo pesajes rechazados."]

        _ ->
          Enum.map(rechazados, fn {pesaje, motivo} ->
            recolector = texto(Map.get(pesaje, :recolector))
            lote = texto(Map.get(pesaje, :lote))
            dia = Util.formatear_numero(Map.get(pesaje, :dia))
            kilos = Util.formatear_numero(Map.get(pesaje, :kilos))
            verdes = Util.formatear_numero(Map.get(pesaje, :verdes))

            "#{recolector} | #{lote} | día #{dia} | #{kilos} kg | #{verdes} % -> #{motivo}"
          end)
      end

    conteos = rechazados |> Enum.map(fn {_pesaje, motivo} -> motivo end)
    |> Enum.frequencies()

    lineas_conteo =
      Enum.map(Validacion.motivos(), fn motivo ->
        "#{motivo}: #{Map.get(conteos, motivo, 0)}"
      end)

    Enum.join(
      ["R1. Pesajes rechazados"] ++
        lineas_pesajes ++ ["", "Rechazos por motivo"] ++ lineas_conteo,
      "\n"
    )
  end

  @doc """
  Calcula los kilos y el rendimiento (kg/ha) de cada lote, ordenados de mayor a menor
  rendimiento. Un lote sin pesajes válidos aparece con 0 kg.
  """
  def kilos_por_lote(pesajes_validos, lotes) do
    kilos_por_id =
      Enum.reduce(pesajes_validos, %{}, fn p, acc ->
        Map.update(acc, p.lote, p.kilos, &(&1 + p.kilos))
      end)

    lotes
    |> Enum.map(fn lote ->
      kilos = Map.get(kilos_por_id, lote.id, 0)
      rendimiento = if lote.hectareas > 0, do: kilos / lote.hectareas, else: 0.0

      %{nombre: lote.nombre, hectareas: lote.hectareas, kilos: kilos, rendimiento: rendimiento}
    end)
    |> Enum.sort_by(& &1.rendimiento, :desc)
  end

  @doc "Reporte R2: texto con los kilos y el rendimiento por hectárea de cada lote."
  def r2(pesajes_validos, lotes) do
    lineas =
      pesajes_validos
      |> kilos_por_lote(lotes)
      |> Enum.map(fn lote ->
        "#{lote.nombre} | #{Util.formatear_numero(lote.kilos)} kg | " <>
          "#{Util.formatear_decimal(lote.hectareas, 1)} ha | " <>
          "#{Util.formatear_decimal(lote.rendimiento, 2)} kg/ha"
      end)

    Enum.join(["R2. Kilos por lote" | lineas], "\n")
  end

  @doc """
  Reporte R3: compara la producción diaria de la finca con la meta establecida.

  Muestra por cada día si se cumplió o no la meta de 400 kg y responde si la meta se
  cumplió todos los días y si al menos hubo un día exitoso.
  """
  def r3(pesajes_validos) do
    kilos_por_dia = Liquidacion.kilos_por_dia_finca(pesajes_validos)

    lineas =
      for dia <- Liquidacion.dias_cosecha() do
        kilos = kilos_por_dia[dia]

        estado =
          if Liquidacion.cumple_meta_diaria?(kilos),
            do: "cumplió la meta",
            else: "no cumplió la meta"

        "Día #{dia}: #{Util.formatear_numero(kilos)} kg -> #{estado}"
      end

    valores = Map.values(kilos_por_dia)
    todos_cumplieron = Enum.all?(valores, &Liquidacion.cumple_meta_diaria?/1)
    algun_dia_cumplio = Enum.any?(valores, &Liquidacion.cumple_meta_diaria?/1)

    Enum.join(
      ["R3. Kilos por día (meta: #{Liquidacion.meta_diaria()} kg)"] ++
        lineas ++
        [
          "¿Se cumplió la meta todos los días? #{si_no(todos_cumplieron)}",
          "¿Se cumplió la meta al menos un día? #{si_no(algun_dia_cumplio)}"
        ],
      "\n"
    )
  end

  @doc """
  Reporte R4: liquidación de todos los recolectores, numerada y ordenada por neto de mayor
  a menor. Los valores en pesos van con dos decimales y sin notación científica.
  """
  def r4(liquidaciones) do
    lineas =
      liquidaciones
      |> Enum.sort_by(& &1.neto, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {l, posicion} ->
        "#{posicion}. | #{l.nombre} | #{Util.formatear_numero(l.kilos)} kg | " <>
          "$#{Util.formatear_dinero(l.suma_pesajes)} | $#{Util.formatear_dinero(l.bonificaciones)} | " <>
          "$#{Util.formatear_dinero(l.alimentacion)} | $#{Util.formatear_dinero(l.neto)}"
      end)

    Enum.join(
      [
        "R4. Liquidación de la semana",
        "# | Recolector | Kilos | Pesajes | Bonificaciones | Alimentación | Neto"
      ] ++ lineas,
      "\n"
    )
  end

  @doc """
  Reporte R5: muestra el mejor recolector de cada día y resume quién ganó más días.
  """
  def r5(pesajes_validos, recolectores_por_codigo) do
    mejores = Liquidacion.mejores_por_dia(pesajes_validos)

    lineas =
      for dia <- Liquidacion.dias_cosecha() do
        case mejores[dia] do
          :sin_pesajes ->
            "Día #{dia}: sin pesajes"

          {ganadores, kilos} ->
            "Día #{dia}: #{nombres_de(ganadores, recolectores_por_codigo)} (#{Util.formatear_numero(kilos)} kg)"
        end
      end

    resumen =
      case Liquidacion.recolector_con_mas_dias_ganador(mejores) do
        :sin_ganadores ->
          "Nadie fue el mejor recolector en ningún día."

        {ganadores, dias} ->
          etiqueta_dias = if dias == 1, do: "día", else: "días"

          "Más días como mejor recolector: #{nombres_de(ganadores, recolectores_por_codigo)} (#{dias} #{etiqueta_dias})"
      end

    Enum.join(["R5. Mejor recolector de cada día"] ++ lineas ++ [resumen], "\n")
  end

  @minimo_pesajes_r6 3

  @doc """
  Calcula el porcentaje de verdes **ponderado por kilos** de cada recolector que tenga al
  menos 3 pesajes válidos:
  """
  def calidad_ponderada(pesajes_validos) do
    pesajes_validos
    |> Enum.group_by(& &1.recolector)
    |> Enum.filter(fn {_codigo, pesajes} -> length(pesajes) >= @minimo_pesajes_r6 end)
    |> Enum.map(fn {codigo, pesajes} ->
      {:ok, ponderado} = Util.promedio_ponderado(Enum.map(pesajes, &{&1.verdes, &1.kilos}))
      {codigo, ponderado}
    end)
  end

  @doc """
  Reporte R6: recolector con mejor calidad (menor porcentaje de verdes ponderado por kilos)
  entre quienes tienen al menos 3 pesajes válidos. Si hay empate se muestran todos.
  """
  def r6(pesajes_validos, recolectores_por_codigo) do
    titulo = "R6. Mejor calidad (mínimo #{@minimo_pesajes_r6} pesajes válidos)"

    candidatos = pesajes_validos |> calidad_ponderada() |> Enum.map(fn {c, p} -> {c, -p} end)

    case Util.maximos_en(candidatos) do
      :vacio ->
        "#{titulo}\nNingún recolector tiene al menos #{@minimo_pesajes_r6} pesajes válidos."

      {ganadores, negativo} ->
        "#{titulo}\n#{nombres_de(ganadores, recolectores_por_codigo)}, con " <>
          "#{Util.formatear_decimal(-negativo, 2)} % de verdes ponderado por kilos"
    end
  end

  @doc """
  Reporte R7: total que paga la finca (suma de los netos) y costo promedio por kilo
  (total pagado / kilos válidos). Si no hay kilos válidos el promedio se muestra en 0.
  """
  def r7(liquidaciones) do
    total = liquidaciones |> Enum.map(& &1.neto) |> Enum.sum()
    kilos = liquidaciones |> Enum.map(& &1.kilos) |> Enum.sum()
    promedio = if kilos > 0, do: total / kilos, else: 0

    Enum.join(
      [
        "R7. Totales de la semana",
        "Total a pagar: $#{Util.formatear_dinero(total)}",
        "Kilos válidos: #{Util.formatear_numero(kilos)} kg",
        "Costo promedio por kilo: $#{Util.formatear_dinero(promedio)}"
      ],
      "\n"
    )
  end

  @doc """
  Reporte R8: recolectores que recogieron café (con pesajes válidos) en **todos** los lotes.
  """
  def r8(pesajes_validos, recolectores, lotes) do
    ids_lotes = Enum.map(lotes, & &1.id)
    lotes_por_recolector = Enum.group_by(pesajes_validos, & &1.recolector, & &1.lote)

    nombres =
      recolectores
      |> Enum.filter(fn r ->
        Util.contiene_todos?(Map.get(lotes_por_recolector, r.codigo, []), ids_lotes)
      end)
      |> Enum.map(& &1.nombre)

    lineas =
      if nombres == [], do: ["Ningún recolector trabajó en todos los lotes."], else: nombres

    Enum.join(["R8. Recolectores que trabajaron en todos los lotes" | lineas], "\n")
  end

  @doc """
  Construye el desprendible de pago de un recolector: detalle por día (kilos, valor de los
  pesajes y bonificación), suma de pesajes, bonificaciones, alimentación y neto.
  """
  def desprendible(recolector, pesajes_validos) do
    pesajes_del_recolector = Enum.filter(pesajes_validos, &(&1.recolector == recolector.codigo))
    detalle = Liquidacion.detalle_diario_recolector(pesajes_del_recolector)
    liquidacion = Liquidacion.liquidar_recolector(recolector, pesajes_del_recolector)

    lineas_dias =
      case detalle do
        [] ->
          ["Sin pesajes válidos en la semana."]

        _ ->
          Enum.map(detalle, fn d ->
            "Día #{d.dia}: #{Util.formatear_numero(d.kilos)} kg | " <>
              "pesajes $#{Util.formatear_dinero(d.valor_pesajes)} | " <>
              "bonificación $#{Util.formatear_dinero(d.bonificacion)}"
          end)
      end

    etiqueta_dias = if liquidacion.dias_trabajados == 1, do: "día", else: "días"

    Enum.join(
      ["Desprendible de pago - #{recolector.nombre} (#{recolector.codigo})"] ++
        lineas_dias ++
        [
          "Suma de pesajes: $#{Util.formatear_dinero(liquidacion.suma_pesajes)}",
          "Bonificaciones: $#{Util.formatear_dinero(liquidacion.bonificaciones)}",
          "Alimentación (#{liquidacion.dias_trabajados} #{etiqueta_dias}): -$#{Util.formatear_dinero(liquidacion.alimentacion)}",
          "Neto a pagar: $#{Util.formatear_dinero(liquidacion.neto)}"
        ],
      "\n"
    )
  end

  @campos_ranking [:neto, :kilos, :bruto]
  @ordenes_ranking [:desc, :asc]

  @doc """
  Ranking de liquidaciones configurable con una keyword.
  """
  def ranking(liquidaciones, opciones) do
    campo = valor_permitido(Keyword.get(opciones, :campo, :neto), @campos_ranking, :neto)
    orden = valor_permitido(Keyword.get(opciones, :orden, :desc), @ordenes_ranking, :desc)
    limite = Keyword.get(opciones, :limite, length(liquidaciones))
    limite = if is_integer(limite) and limite > 0, do: limite, else: length(liquidaciones)

    texto_limite =
      if limite == length(liquidaciones), do: "todos", else: Integer.to_string(limite)

    lineas =
      liquidaciones
      |> Enum.sort_by(&Map.get(&1, campo), orden)
      |> Enum.take(limite)
      |> Enum.with_index(1)
      |> Enum.map(fn {l, posicion} ->
        "#{posicion}. #{l.nombre} | #{formatear_campo(campo, Map.get(l, campo))}"
      end)

    Enum.join(
      ["Ranking (campo: #{campo}, orden: #{orden}, límite: #{texto_limite})" | lineas],
      "\n"
    )
  end

  # Devuelve `valor` si está en la lista de permitidos; si no, el valor por defecto.
  defp valor_permitido(valor, permitidos, por_defecto) do
    if valor in permitidos, do: valor, else: por_defecto
  end

  # Los kilos se muestran en kg; el neto y el bruto, en pesos con dos decimales.
  defp formatear_campo(:kilos, valor), do: "#{Util.formatear_numero(valor)} kg"
  defp formatear_campo(_campo_en_pesos, valor), do: "$#{Util.formatear_dinero(valor)}"

  @doc """
  Combina el mapa de kilos por día de la finca (el de R3) con el de una finca vecina.
  """
  def combinar_kilos(mapa_finca, mapa_vecina) do
    Map.merge(mapa_finca, mapa_vecina, fn _dia, kilos_finca, kilos_vecina ->
      kilos_finca + kilos_vecina
    end)
  end

  @doc "Texto con la producción combinada de las dos fincas, ordenada por día."
  def reporte_fincas_combinadas(pesajes_validos, finca_vecina) do
    combinado = combinar_kilos(Liquidacion.kilos_por_dia_finca(pesajes_validos), finca_vecina)

    lineas =
      combinado
      |> Enum.sort_by(fn {dia, _kilos} -> dia end)
      |> Enum.map(fn {dia, kilos} -> "Día #{dia}: #{Util.formatear_numero(kilos)} kg" end)

    Enum.join(["C.2. Producción combinada con la finca vecina" | lineas], "\n")
  end

  defp si_no(true), do: "Sí"
  defp si_no(false), do: "No"

  # Convierte una lista de códigos en "Nombre 1, Nombre 2". Si un código no existe en el
  # mapa se muestra el código tal cual.
  defp nombres_de(codigos, recolectores_por_codigo) do
    codigos
    |> Enum.map(fn codigo ->
      case Map.get(recolectores_por_codigo, codigo) do
        nil -> codigo
        recolector -> recolector.nombre
      end
    end)
    |> Enum.join(", ")
  end

  # Muestra el código de recolector o de lote tal cual si es texto; si no (por ejemplo
  # `nil` o un número mal digitado), lo convierte con `Util.formatear_numero/1`.
  defp texto(valor) when is_binary(valor), do: valor
  defp texto(valor), do: Util.formatear_numero(valor)
end
