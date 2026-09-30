defmodule Reportes do
  @moduledoc """
  Genera los reportes y resúmenes de la operación agrícola.

  El módulo centraliza el texto legible que se muestra en consola para cada uno de los
  indicadores del parcial: kilos por día, mejor recolector, liquidación y desprendibles.
  """

  @doc """
  Reporte R3: compara la producción diaria con la meta establecida.

  Muestra por cada día si se cumplió o no la meta de 400 kg y responde si la meta se
  cumplió todos los días y si al menos hubo un día exitoso.
  """
  def r3(pesajes_validos) do
    kilos_por_dia = Liquidacion.kilos_por_dia_finca(pesajes_validos)

    lineas =
      for dia <- 1..6 do
        kilos = kilos_por_dia[dia]

        estado =
          if Liquidacion.cumple_meta_diaria?(kilos),
            do: "cumplió la meta",
            else: "no cumplió la meta"

        "Día #{dia}: #{formatear_kilos(kilos)} kg -> #{estado}"
      end
      |> Enum.join("\n")

    valores = Map.values(kilos_por_dia)
    todos_cumplieron = Enum.all?(valores, &Liquidacion.cumple_meta_diaria?/1)
    algun_dia_cumplio = Enum.any?(valores, &Liquidacion.cumple_meta_diaria?/1)

    """
    R3. Kilos por día (meta: 400 kg)
    #{lineas}

    ¿Se cumplió la meta todos los días? #{si_no(todos_cumplieron)}
    ¿Se cumplió la meta al menos un día? #{si_no(algun_dia_cumplio)}
    """
  end

  @doc """
  Reporte R5: muestra el mejor recolector de cada día y resume quién ganó más días.
  """
  def r5(pesajes_validos, recolectores) do
    mejores = Liquidacion.mejores_por_dia(pesajes_validos)

    lineas =
      for dia <- 1..6 do
        case mejores[dia] do
          :sin_pesajes ->
            "Día #{dia}: sin pesajes"

          {ganadores, kilos} ->
            nombres = ganadores |> Enum.map(&nombre_de(&1, recolectores)) |> Enum.join(", ")
            "Día #{dia}: #{nombres} (#{formatear_kilos(kilos)} kg)"
        end
      end
      |> Enum.join("\n")

    resumen =
      case Liquidacion.recolector_con_mas_dias_ganador(mejores) do
        :sin_ganadores ->
          "Nadie fue el mejor recolector en ningún día."

        {ganadores, dias} ->
          nombres = ganadores |> Enum.map(&nombre_de(&1, recolectores)) |> Enum.join(", ")
          etiqueta_dias = if dias == 1, do: "día", else: "días"
          "Más días como mejor recolector: #{nombres} (#{dias} #{etiqueta_dias})"
      end

    """
    R5. Mejor recolector de cada día
    #{lineas}

    #{resumen}
    """
  end

  @doc "Construye el desprendible de pago de un recolector específico."
  def desprendible(recolector, pesajes_validos) do
    pesajes_del_recolector = Enum.filter(pesajes_validos, &(&1.recolector == recolector.codigo))
    detalle = Liquidacion.detalle_diario_recolector(pesajes_del_recolector)
    liquidacion = Liquidacion.liquidar_recolector(recolector, pesajes_del_recolector)
    dias_trabajados = length(detalle)

    lineas_dias =
      detalle
      |> Enum.map(fn d ->
        "Día #{d.dia}: #{formatear_kilos(d.kilos)} kg | pesajes $#{Util.formatear_dinero(d.valor_pesajes)} | bonificación $#{Util.formatear_dinero(d.bonificacion)}"
      end)
      |> Enum.join("\n")

    """
    Desprendible de pago - #{recolector.nombre} (#{recolector.codigo})
    #{lineas_dias}

    Suma de pesajes: $#{Util.formatear_dinero(liquidacion.suma_pesajes)}
    Bonificaciones: $#{Util.formatear_dinero(liquidacion.bonificaciones)}
    Alimentación (#{dias_trabajados} días): -$#{Util.formatear_dinero(liquidacion.alimentacion)}
    Neto a pagar: $#{Util.formatear_dinero(liquidacion.neto)}
    """
  end

  @doc "Reporte R1: deja el espacio para mostrar los pesajes rechazados."
  def r1(_pesajes_rechazados) do
    "R1. Pesajes rechazados\n(pendiente — lo hace el compañero de Validacion/Reportes)"
  end

  @doc "Reporte R2: deja un placeholder para el resumen de kilos por lote."
  def r2(_pesajes_validos, _lotes) do
    "R2. Kilos por lote\n(pendiente)"
  end

  @doc "Reporte R4: placeholder para la liquidación total de la semana."
  def r4(_liquidaciones) do
    "R4. Liquidación de la semana\n(pendiente)"
  end

  @doc "Reporte R6: placeholder para la mejor calidad según promedio ponderado."
  def r6(_pesajes_validos) do
    "R6. Mejor calidad\n(pendiente — usa Util.promedio_ponderado)"
  end

  @doc "Reporte R7: placeholder para los totales de la semana."
  def r7(_liquidaciones) do
    "R7. Totales de la semana\n(pendiente)"
  end

  @doc "Reporte R8: placeholder para encontrar recolectores en todos los lotes."
  def r8(_pesajes_validos, _lotes) do
    "R8. Recolectores que trabajaron en todos los lotes\n(pendiente — usa Util.contiene_todos?/2 con los lotes de cada recolector y la lista completa de lotes)"
  end

  defp si_no(true), do: "Sí"
  defp si_no(false), do: "No"

  defp nombre_de(codigo, recolectores) do
    case Enum.find(recolectores, &(&1.codigo == codigo)) do
      nil -> codigo
      recolector -> recolector.nombre
    end
  end

  defp formatear_kilos(kilos) when is_float(kilos) do
    if kilos == Float.round(kilos, 0) do
      kilos |> round() |> Integer.to_string()
    else
      :erlang.float_to_binary(kilos, decimals: 1)
    end
  end

  defp formatear_kilos(kilos), do: Integer.to_string(kilos)
end
