defmodule Programa do
  @moduledoc """
  Punto de entrada del programa. Se ejecuta con `elixir programa.exs`
  después de compilar los demás módulos con `elixirc` (ver README).

  Todo el I/O vive aquí (y en Util); Validacion, Liquidacion y Reportes
  siguen siendo puros.
  """

  def main do
    # 1. Cargar los datos crudos
    recolectores = Datos.recolectores()
    lotes = Datos.lotes()
    pesajes = Datos.pesajes()

    # 2. Validar (regla B.2)
    resultados = Validacion.validar_todos(pesajes, recolectores, lotes)
    pesajes_validos = pesajes_validos_de(resultados)
    pesajes_rechazados = pesajes_rechazados_de(resultados)

    # 3. Pedir un pesaje adicional por consola (B.5, primera parte)
    {pesajes_validos, pesajes_rechazados} =
      agregar_pesaje_adicional(recolectores, lotes, pesajes_validos, pesajes_rechazados)

    # 4. Liquidar (reglas 2 a 5) con los pesajes válidos ya completos
    liquidaciones = Liquidacion.liquidar(recolectores, pesajes_validos)

    # 5. Mostrar los 8 reportes, en orden
    imprimir_reportes(pesajes_validos, pesajes_rechazados, recolectores, lotes, liquidaciones)

    # 6. Desprendible de pago de un recolector (B.5, segunda parte)
    mostrar_desprendible(recolectores, pesajes_validos)
  end

  # ---------------------------------------------------------------
  # Paso 2: separar válidos / rechazados
  # ---------------------------------------------------------------

  defp pesajes_validos_de(resultados) do
    resultados
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, p} -> p end)
  end

  defp pesajes_rechazados_de(resultados) do
    Enum.filter(resultados, &match?({:error, _, _}, &1))
  end

  # ---------------------------------------------------------------
  # Paso 3: pesaje adicional (B.5)
  # ---------------------------------------------------------------

  defp agregar_pesaje_adicional(recolectores, lotes, pesajes_validos, pesajes_rechazados) do
    linea = Util.leer("Ingrese un pesaje adicional (recolector;lote;dia;kilos;verdes) o Enter para omitir: ", :string)

    if linea == "" do
      Util.imprimir_mensaje("No se agregó ningún pesaje.")
      {pesajes_validos, pesajes_rechazados}
    else
      procesar_linea_pesaje(linea, recolectores, lotes, pesajes_validos, pesajes_rechazados)
    end
  end

  defp procesar_linea_pesaje(linea, recolectores, lotes, pesajes_validos, pesajes_rechazados) do
    case parsear_pesaje(linea) do
      {:error, :formato_invalido} ->
        Util.imprimir_mensaje("Pesaje rechazado: formato_invalido")
        {pesajes_validos, pesajes_rechazados}

      {:ok, pesaje} ->
        case Validacion.validar(pesaje, recolectores, lotes) do
          {:ok, pesaje_valido} ->
            Util.imprimir_mensaje(
              "Pesaje agregado: #{pesaje_valido.recolector} en #{pesaje_valido.lote}, día #{pesaje_valido.dia}, #{pesaje_valido.kilos} kg, #{pesaje_valido.verdes} % de verdes."
            )

            {[pesaje_valido | pesajes_validos], pesajes_rechazados}

          {:error, motivo} ->
            Util.imprimir_mensaje("Pesaje rechazado: #{motivo}")
            {pesajes_validos, [{:error, motivo, pesaje} | pesajes_rechazados]}
        end
    end
  end

  # "recolector;lote;dia;kilos;verdes" -> %{recolector:, lote:, dia:, kilos:, verdes:}
  # Se rechaza con :formato_invalido si no hay 5 campos, si el día no es
  # un entero exacto o si kilos/verdes no son números exactos (sin
  # texto sobrante), tal como lo pide B.5.
  defp parsear_pesaje(linea) do
    case linea |> String.split(";") |> Enum.map(&String.trim/1) do
      [recolector, lote, dia_txt, kilos_txt, verdes_txt] ->
        with {:ok, dia} <- parsear_entero(dia_txt),
             {:ok, kilos} <- parsear_numero(kilos_txt),
             {:ok, verdes} <- parsear_numero(verdes_txt) do
          {:ok, %{recolector: recolector, lote: lote, dia: dia, kilos: kilos, verdes: verdes}}
        else
          :error -> {:error, :formato_invalido}
        end

      _otro_numero_de_campos ->
        {:error, :formato_invalido}
    end
  end

  defp parsear_entero(texto) do
    case Integer.parse(texto) do
      {numero, ""} -> {:ok, numero}
      _ -> :error
    end
  end

  defp parsear_numero(texto) do
    case Float.parse(texto) do
      {numero, ""} -> {:ok, numero}
      _ -> :error
    end
  end

  # ---------------------------------------------------------------
  # Paso 5: los 8 reportes, en orden
  # ---------------------------------------------------------------

  defp imprimir_reportes(pesajes_validos, pesajes_rechazados, recolectores, lotes, liquidaciones) do
    Util.imprimir_mensaje(Reportes.r1(pesajes_rechazados))
    Util.imprimir_mensaje(Reportes.r2(pesajes_validos, lotes))
    Util.imprimir_mensaje(Reportes.r3(pesajes_validos))
    Util.imprimir_mensaje(Reportes.r4(liquidaciones))
    Util.imprimir_mensaje(Reportes.r5(pesajes_validos, recolectores))
    Util.imprimir_mensaje(Reportes.r6(pesajes_validos))
    Util.imprimir_mensaje(Reportes.r7(liquidaciones))
    Util.imprimir_mensaje(Reportes.r8(pesajes_validos, lotes))
  end

  # ---------------------------------------------------------------
  # Paso 6: desprendible de pago (B.5)
  # ---------------------------------------------------------------

  defp mostrar_desprendible(recolectores, pesajes_validos) do
    codigo = Util.leer("Ingrese el código del recolector para ver su desprendible: ", :string)

    case Enum.find(recolectores, &(&1.codigo == codigo)) do
      nil ->
        Util.imprimir_mensaje("No existe un recolector con el código #{codigo}.")

      recolector ->
        Util.imprimir_mensaje(Reportes.desprendible(recolector, pesajes_validos))
    end
  end
end

Programa.main()
