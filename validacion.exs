defmodule Validacion do
  @moduledoc """
  Valida los pesajes antes de que entren a cualquier cálculo (regla de negocio 1).

  También convierte la línea que escribe el usuario en B.5 ('recolector;lote;dia;kilos;verdes')
  en un pesaje, o la rechaza con '{:error, :formato_invalido}'.

  Todas las funciones de este módulo son **puras**: reciben datos y devuelven tuplas
  '{:ok, valor}' / '{:error, motivo}'; nunca imprimen ni lanzan excepciones.
  """

  @dia_minimo 1
  @dia_maximo 6
  @kilos_maximos_por_pesaje 250
  @verdes_minimo 0
  @verdes_maximo 100

  @doc """
  Lista, en el orden en que se revisan, de todos los motivos de rechazo posibles.

  'Reportes.r1/1' la usa para mostrar el conteo de cada motivo, incluso los que tienen 0.
  """
  def motivos,
    do: [
      :recolector_desconocido,
      :lote_desconocido,
      :dia_invalido,
      :kilos_fuera_de_rango,
      :porcentaje_invalido
    ]

  @doc """
  Valida un pesaje encadenando las cinco verificaciones con 'with' (requisito B.2).
  Si todas las verificaciones devuelven '{:ok, _}' el resultado es '{:ok, pesaje}'. En
  cuanto una devuelve '{:error, motivo}', 'with' se detiene y devuelve ese error tal cual,
  por eso solo se informa el primer motivo (por ejemplo, el pesaje de R04 con día 7 y
  300 kg se rechaza por ':dia_invalido').
  """
  def validar_pesaje(pesaje, recolectores_por_codigo, lotes_por_id) do
    with {:ok, _} <- validar_recolector(Map.get(pesaje, :recolector), recolectores_por_codigo),
         {:ok, _} <- validar_lote(Map.get(pesaje, :lote), lotes_por_id),
         {:ok, _} <- validar_dia(Map.get(pesaje, :dia)),
         {:ok, _} <- validar_kilos(Map.get(pesaje, :kilos)),
         {:ok, _} <- validar_verdes(Map.get(pesaje, :verdes)) do
      {:ok, pesaje}
    end
  end

  @doc """
  Valida una lista completa de pesajes y la separa en válidos y rechazados.

  Devuelve {validos, rechazados} donde:

    * validos es la lista de pesajes que pasaron todas las reglas, en su orden original.
    * rechazados es una lista de tuplas '{pesaje, motivo}', también en su orden original,
      que es la que se muestra en el reporte R1.
  """
  def separar_pesajes(pesajes, recolectores_por_codigo, lotes_por_id) do
    resultados =
      Enum.map(pesajes, fn pesaje ->
        {pesaje, validar_pesaje(pesaje, recolectores_por_codigo, lotes_por_id)}
      end)

    validos = for {pesaje, {:ok, _}} <- resultados, do: pesaje
    rechazados = for {pesaje, {:error, motivo}} <- resultados, do: {pesaje, motivo}

    {validos, rechazados}
  end

  @doc "Regla 1: el código del recolector debe existir en el mapa de recolectores."
  def validar_recolector(codigo, recolectores_por_codigo) do
    if Map.has_key?(recolectores_por_codigo, codigo),
      do: {:ok, codigo},
      else: {:error, :recolector_desconocido}
  end

  @doc "Regla 2: el id del lote debe existir en el mapa de lotes."
  def validar_lote(id, lotes_por_id) do
    if Map.has_key?(lotes_por_id, id),
      do: {:ok, id},
      else: {:error, :lote_desconocido}
  end

  @doc """
  Regla 3: el día debe ser un **entero** entre 1 y 6.

  Un decimal como '2.0' o '4.5', un texto como '"3"' o 'nil' se rechazan.
  """
  def validar_dia(dia) when is_integer(dia) do
    case Util.validar_rango(dia, @dia_minimo, @dia_maximo) do
      {:ok, dia} -> {:ok, dia}
      {:error, _} -> {:error, :dia_invalido}
    end
  end

  def validar_dia(_dia), do: {:error, :dia_invalido}

  @doc """
  Regla 4: los kilos deben ser un número mayor que 0 y como máximo 250.

  Primero se exige que sea positivo (descarta '0', negativos y valores que no son número) y
  luego que no supere el máximo por pesaje.
  """
  def validar_kilos(kilos) do
    with {:ok, kilos} <- Util.validar_positivo(kilos),
         {:ok, kilos} <- Util.validar_rango(kilos, 0, @kilos_maximos_por_pesaje) do
      {:ok, kilos}
    else
      {:error, _} -> {:error, :kilos_fuera_de_rango}
    end
  end

  @doc "Regla 5: el porcentaje de verdes debe ser un número entre 0 y 100 (incluidos)."
  def validar_verdes(verdes) do
    case Util.validar_rango(verdes, @verdes_minimo, @verdes_maximo) do
      {:ok, verdes} -> {:ok, verdes}
      {:error, _} -> {:error, :porcentaje_invalido}
    end
  end

  @doc """
  Convierte una línea 'recolector;lote;dia;kilos;verdes' en un mapa de pesaje.

  Devuelve '{:ok, pesaje}' o '{:error, :formato_invalido}' cuando:

    - la línea no tiene exactamente cinco campos,
    - el día no es un entero ('"4.5"' o '"cuatro"' se rechazan),
    - los kilos o los verdes no son números.

  Esta función **solo revisa el formato**; las reglas de negocio se aplican después con
  validar_pesaje/3', igual que a los pesajes de 'datos.exs'.

  """
  def parsear_linea(linea) do
    case linea |> String.split(";") |> Enum.map(&String.trim/1) do
      [recolector, lote, dia_texto, kilos_texto, verdes_texto] ->
        with {:ok, dia} <- parsear_entero(dia_texto),
             {:ok, kilos} <- parsear_numero(kilos_texto),
             {:ok, verdes} <- parsear_numero(verdes_texto) do
          {:ok, %{recolector: recolector, lote: lote, dia: dia, kilos: kilos, verdes: verdes}}
        end

        {:error, :formato_invalido}
    end
  end

  # Acepta solo textos que sean enteros completos: "2" -> 2; "4.5" o "2x" -> error.
  defp parsear_entero(texto) do
    case Integer.parse(texto) do
      {numero, ""} -> {:ok, numero}
      _ -> {:error, :formato_invalido}
    end
  end

  # Acepta enteros o decimales completos y los devuelve como float: "3" -> 3.0, "92.5" -> 92.5.
  defp parsear_numero(texto) do
    case Float.parse(texto) do
      {numero, ""} -> {:ok, numero}
      _ -> {:error, :formato_invalido}
    end
  end
end
