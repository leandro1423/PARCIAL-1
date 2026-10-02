defmodule Reportes do

  # R1. Pesajes rechazados y cantidad de rechazos por motivo.
  def pesajes_rechazados(pesajes, recolectores, lotes) do
    pesajes
    |> Enum.reduce([], fn pesaje, acumulado ->
      case Validacion.validar_pesaje(pesaje, recolectores, lotes) do
        {:ok, _} ->
          acumulado

        {:error, motivo} ->
          [{pesaje, motivo} | acumulado]
      end
    end)
    |> Enum.reverse()
  end

  def conteo_rechazos(rechazados) do
    Enum.reduce(rechazados, %{}, fn {_pesaje, motivo}, acumulado ->
      Map.update(acumulado, motivo, 1, fn cantidad -> cantidad + 1 end)
    end)
  end

  def texto_r1(pesajes, recolectores, lotes) do
    rechazados = pesajes_rechazados(pesajes, recolectores, lotes)
    conteos = conteo_rechazos(rechazados)

    lineas_pesajes =
      Enum.map(rechazados, fn {pesaje, motivo} ->
        "#{pesaje.recolector} | #{pesaje.lote} | día #{pesaje.dia} | " <>
          "#{pesaje.kilos} kg | #{pesaje.verdes} % -> #{motivo}"
      end)

    motivos = [
      :recolector_desconocido,
      :lote_desconocido,
      :dia_invalido,
      :kilos_fuera_de_rango,
      :porcentaje_invalido
    ]

    lineas_conteo =
      Enum.map(motivos, fn motivo ->
        "#{motivo}: #{Map.get(conteos, motivo, 0)}"
      end)

    "R1. Pesajes rechazados\n" <>
      Enum.join(lineas_pesajes, "\n") <>
      "\n\nRechazos por motivo\n" <>
      Enum.join(lineas_conteo, "\n")
  end

  # R2. Kilos por lote y rendimiento en kilos por hectárea.
  def kilos_por_lote(pesajes, recolectores, lotes) do
    pesajes_validos =
      Enum.filter(pesajes, fn pesaje ->
        case Validacion.validar_pesaje(pesaje, recolectores, lotes) do
          {:ok, _} -> true
          {:error, _} -> false
        end
      end)

    lotes
    |> Enum.map(fn lote ->
      kilos =
        Enum.reduce(pesajes_validos, 0, fn pesaje, total ->
          if pesaje.lote == lote.id do
            total + pesaje.kilos
          else
            total
          end
        end)

      %{
        nombre: lote.nombre,
        hectareas: lote.hectareas,
        kilos: kilos,
        rendimiento: kilos / lote.hectareas
      }
    end)
    |> Enum.sort_by(fn lote -> lote.rendimiento end, :desc)
  end

  def texto_r2(pesajes, recolectores, lotes) do
    resultados = kilos_por_lote(pesajes, recolectores, lotes)

    lineas =
      Enum.map(resultados, fn lote ->
        rendimiento = :io_lib.format("~.2f", [lote.rendimiento]) |> IO.iodata_to_binary()

        "#{lote.nombre} | #{lote.kilos} kg | #{lote.hectareas} ha | " <>
          "#{rendimiento} kg/ha"
      end)

    "R2. Kilos por lote\n" <> Enum.join(lineas, "\n")
  end

  # C2. Combina los kilos por día de dos fincas.
  def combinar_kilos(mapa_finca, mapa_vecina) do
    Map.merge(mapa_finca, mapa_vecina, fn _dia, kilos_finca, kilos_vecina ->
      kilos_finca + kilos_vecina
    end)
  end
end
