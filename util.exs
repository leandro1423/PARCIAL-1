defmodule Util do
  @moduledoc """
  Utilidades de apoyo para el resto del programa.
  """

  @doc """
  Lee una línea desde consola y la devuelve como texto sin espacios al inicio ni al final.
  """
  def leer(mensaje, :string) do
    case IO.gets(mensaje) do
      texto when is_binary(texto) -> String.trim(texto)
      _eof_o_error -> ""
    end
  end

  @doc """
  Imprime un mensaje en la salida estándar.
  """
  def imprimir_mensaje(mensaje) do
    IO.puts(mensaje)
  end

  @doc """
  Imprime un mensaje en la salida estándar de errores.
  """
  def imprimir_error(mensaje) do
    IO.puts(:standard_error, mensaje)
  end

  @doc """
  Valida que un valor sea un número estrictamente mayor que cero.
  """
  def validar_positivo(numero) when is_number(numero) and numero > 0, do: {:ok, numero}
  def validar_positivo(numero) when is_number(numero), do: {:error, :debe_ser_positivo}
  def validar_positivo(_), do: {:error, :se_esperaba_un_numero}

  @doc """
  Valida que un número esté dentro del rango `[minimo, maximo]`, ambos incluidos.
  """
  def validar_rango(numero, minimo, maximo)
      when is_number(numero) and is_number(minimo) and is_number(maximo) and minimo <= maximo do
    if numero >= minimo and numero <= maximo, do: {:ok, numero}, else: {:error, :fuera_de_rango}
  end

  def validar_rango(_, _, _), do: {:error, :argumentos_de_rango_invalidos}

  @doc """
  Calcula un promedio ponderado a partir de una lista de pares `{valor, peso}`.
  """
  def promedio_ponderado(datos) when is_list(datos) do
    datos_validos =
      Enum.all?(datos, fn
        {valor, peso} -> is_number(valor) and is_number(peso) and peso >= 0
        _ -> false
      end)

    cond do
      datos == [] ->
        {:error, :lista_vacia}

      not datos_validos ->
        {:error, :se_esperaban_pares_valor_peso_validos}

      true ->
        peso_total = datos |> Enum.map(fn {_valor, peso} -> peso end) |> Enum.sum()
        suma_ponderada = datos |> Enum.map(fn {valor, peso} -> valor * peso end) |> Enum.sum()

        if peso_total == 0,
          do: {:error, :el_peso_total_debe_ser_mayor_que_cero},
          else: {:ok, suma_ponderada / peso_total}
    end
  end

  def promedio_ponderado(_), do: {:error, :se_esperaba_una_lista}

  @doc """
  Obtiene las claves que tienen el valor máximo dentro de una colección de pares
  """
  def maximos_en(pares) do
    lista = Enum.to_list(pares)

    if lista == [] do
      :vacio
    else
      valor_maximo = lista |> Enum.map(fn {_clave, valor} -> valor end) |> Enum.max()

      claves =
        lista
        |> Enum.filter(fn {_clave, valor} -> valor == valor_maximo end)
        |> Enum.map(fn {clave, _valor} -> clave end)
        |> Enum.sort()

      {claves, valor_maximo}
    end
  end

  @doc """
  Comprueba si todos los elementos de `requeridos` aparecen en `lista`.
  """
  def contiene_todos?(lista, requeridos) do
    Enum.all?(requeridos, &(&1 in lista))
  end

  @doc """
  Convierte una lista de mapas en un mapa indexado por el campo `clave`.
  """
  def indexar_por(lista, clave) do
    Map.new(lista, fn elemento -> {Map.get(elemento, clave), elemento} end)
  end

  @doc """
  Formatea un número con la cantidad de decimales indicada, sin notación científica.
  """
  def formatear_decimal(valor, decimales)
      when is_number(valor) and is_integer(decimales) and decimales >= 0 do
    :erlang.float_to_binary(valor / 1, decimals: decimales)
  end

  def formatear_decimal(valor, _decimales), do: inspect(valor)

  @doc """
  Formatea un valor en pesos con dos decimales (por ejemplo `"62999.99999"` → `"63000.00"`).
  """
  def formatear_dinero(valor), do: formatear_decimal(valor, 2)

  @doc """
  Formatea una cantidad de kilos o un porcentaje de forma compacta.
  """
  def formatear_numero(valor) when is_integer(valor), do: Integer.to_string(valor)

  def formatear_numero(valor) when is_float(valor) do
    if valor == Float.round(valor, 0) do
      valor |> round() |> Integer.to_string()
    else
      :erlang.float_to_binary(valor, [:compact, decimals: 2])
    end
  end

  def formatear_numero(valor), do: inspect(valor)
end
