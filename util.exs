# Integrantes: Leandro, Martin, Samuel
# Programación III - Parcial 1: Liquidación de la cosecha de una finca cafetera

defmodule Util do
  @moduledoc """
  Utilidades de apoyo para el resto del programa.

  El módulo tiene dos grupos de funciones:

    * **Impuras (con efectos secundarios)**: `leer/2`, `imprimir_mensaje/1` e
      `imprimir_error/1`. Son las únicas, junto con `Programa`, que tocan la consola.
    * **Puras**: validaciones numéricas genéricas, formateo de números, cálculo de
      promedios ponderados, búsqueda de máximos y conversión de listas a mapas.

  Ninguna función de este módulo conoce las reglas de negocio de la finca; solo
  resuelven tareas genéricas que `Validacion`, `Liquidacion` y `Reportes` reutilizan.
  """

  # ---------------------------------------------------------------------------
  # Funciones impuras: entrada y salida por consola
  # ---------------------------------------------------------------------------

  @doc """
  Lee una línea desde consola y la devuelve como texto sin espacios al inicio ni al final.

  Si la entrada estándar se cierra (por ejemplo, al ejecutar el programa con un archivo
  redirigido que ya no tiene más líneas), `IO.gets/1` devuelve `:eof`; en ese caso se
  devuelve `""` para que el programa continúe como si el usuario hubiera presionado Enter.

  Función **impura**: lee de la entrada estándar.
  """
  def leer(mensaje, :string) do
    case IO.gets(mensaje) do
      texto when is_binary(texto) -> String.trim(texto)
      _eof_o_error -> ""
    end
  end

  @doc """
  Imprime un mensaje en la salida estándar.

  Función **impura**: escribe en consola.
  """
  def imprimir_mensaje(mensaje) do
    IO.puts(mensaje)
  end

  @doc """
  Imprime un mensaje en la salida estándar de errores.

  Función **impura**: escribe en consola.
  """
  def imprimir_error(mensaje) do
    IO.puts(:standard_error, mensaje)
  end

  # ---------------------------------------------------------------------------
  # Funciones puras: validaciones numéricas genéricas
  # ---------------------------------------------------------------------------

  @doc """
  Valida que un valor sea un número estrictamente mayor que cero.

  Devuelve `{:ok, numero}` o `{:error, motivo}`. Cualquier valor que no sea número
  (texto, `nil`, átomo…) cae en la última cláusula y no hace fallar el programa.
  """
  def validar_positivo(numero) when is_number(numero) and numero > 0, do: {:ok, numero}
  def validar_positivo(numero) when is_number(numero), do: {:error, :debe_ser_positivo}
  def validar_positivo(_), do: {:error, :se_esperaba_un_numero}

  @doc """
  Valida que un número esté dentro del rango `[minimo, maximo]`, ambos incluidos.

  Devuelve `{:ok, numero}` o `{:error, motivo}`. Si `numero` no es un número o el rango
  está mal definido, devuelve `{:error, :argumentos_de_rango_invalidos}`.
  """
  def validar_rango(numero, minimo, maximo)
      when is_number(numero) and is_number(minimo) and is_number(maximo) and minimo <= maximo do
    if numero >= minimo and numero <= maximo, do: {:ok, numero}, else: {:error, :fuera_de_rango}
  end

  def validar_rango(_, _, _), do: {:error, :argumentos_de_rango_invalidos}

  # ---------------------------------------------------------------------------
  # Funciones puras: cálculos genéricos
  # ---------------------------------------------------------------------------

  @doc """
  Calcula un promedio ponderado a partir de una lista de pares `{valor, peso}`.

  La fórmula es `suma(valor × peso) / suma(peso)`. Se usa en el reporte R6 para el
  porcentaje de verdes ponderado por kilos.

      iex> Util.promedio_ponderado([{1.0, 200}, {15, 10}, {15, 10}])
      {:ok, 2.272727...}

  Devuelve `{:error, motivo}` si la lista está vacía, si algún par no es válido o si la
  suma de los pesos es cero (evita la división entre cero).
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
  `{clave, valor}` (por ejemplo, un mapa).

  Devuelve `{claves, valor_maximo}` con **todas** las claves empatadas, ordenadas, o
  `:vacio` si la colección no tiene elementos. Se usa en R5 para los empates.

      iex> Util.maximos_en(%{"R01" => 130, "R03" => 130, "R02" => 90})
      {["R01", "R03"], 130}
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

  Se usa en R8 para saber si un recolector pasó por todos los lotes.
  """
  def contiene_todos?(lista, requeridos) do
    Enum.all?(requeridos, &(&1 in lista))
  end

  @doc """
  Convierte una lista de mapas en un mapa indexado por el campo `clave`.

      iex> Util.indexar_por([%{codigo: "R01", nombre: "Luz"}], :codigo)
      %{"R01" => %{codigo: "R01", nombre: "Luz"}}

  Permite buscar un recolector por código o un lote por id en tiempo constante, en lugar
  de recorrer la lista completa cada vez (ver la justificación en la Parte A del README).
  """
  def indexar_por(lista, clave) do
    Map.new(lista, fn elemento -> {Map.get(elemento, clave), elemento} end)
  end

  # ---------------------------------------------------------------------------
  # Funciones puras: formateo de números para los reportes
  # ---------------------------------------------------------------------------

  @doc """
  Formatea un número con la cantidad de decimales indicada, sin notación científica.

      iex> Util.formatear_decimal(193.6666, 2)
      "193.67"
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

    * Si el número es entero (o un decimal sin parte fraccionaria) se muestra sin decimales:
      `410` → `"410"`, `92.0` → `"92"`.
    * Si tiene parte decimal se muestra con hasta dos decimales, sin ceros sobrantes:
      `300.5` → `"300.5"`, `92.25` → `"92.25"`.
    * Si no es un número (un dato mal digitado en `datos.exs`) se muestra con `inspect/1`
      para que el reporte R1 nunca falle.
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
