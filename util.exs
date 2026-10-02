defmodule Util do
  @moduledoc """
  Utilidades auxiliares para entrada de datos, validaciones, cálculos y formateo.

  Este módulo centraliza operaciones repetitivas usadas en la lógica de negocio, como
  la lectura desde consola, la validación de valores y el cálculo de promedios.
  """

  @doc """
  Lee un valor desde consola como texto, eliminando espacios en blanco al inicio y final.
  """
  def leer(mensaje, :string) do
    IO.gets(mensaje)
    |> String.trim()
  end

  @doc """
  Lee un valor desde consola y lo convierte a entero.

  Si el valor no es válido, se retorna `0` y se imprime un mensaje de error.
  """
  def leer(mensaje, :integer) do
    leer_con_parser(mensaje, &Integer.parse/1, 0)
  end

  @doc """
  Lee un valor desde consola y lo convierte a float.

  Si el valor no es válido, se retorna `0.0` y se imprime un mensaje de error.
  """
  def leer(mensaje, :float) do
    leer_con_parser(mensaje, &Float.parse/1, 0.0)
  end

  @doc """
  Ejecuta un parseo sobre el texto ingresado por consola.

  Si falla, usa el valor indicado en `valor_defecto` y registra el error con `imprimir_error/1`.
  """
  def leer_con_parser(mensaje, funcion, valor_defecto) do
    valor =
      IO.gets(mensaje)
      |> String.trim()
      |> funcion.()

    case valor do
      {numero, _} ->
        numero

      :error ->
        imprimir_error("Error. Se utilizará #{valor_defecto} como valor predeterminado.")
        valor_defecto
    end
  end

  @doc "Imprime un mensaje de error en la salida estándar de errores."
  def imprimir_error(mensaje) do
    IO.puts(:standard_error, mensaje)
  end

  @doc "Imprime un mensaje en la salida estándar."
  def imprimir_mensaje(mensaje) do
    IO.puts(mensaje)
  end

  @doc "Valida que un texto no esté vacío ni compuesto únicamente por espacios."
  def validar_no_vacio(valor) when is_binary(valor) do
    if String.trim(valor) == "", do: {:error, :texto_vacio}, else: {:ok, valor}
  end

  @doc "Retorna un error cuando el valor recibido no es un texto."
  def validar_no_vacio(_), do: {:error, :se_esperaba_texto}

  @doc "Valida que un número sea positivo."
  def validar_positivo(numero) when is_number(numero) and numero > 0, do: {:ok, numero}
  def validar_positivo(numero) when is_number(numero), do: {:error, :debe_ser_positivo}
  def validar_positivo(_), do: {:error, :se_esperaba_un_numero}

  @doc "Valida que un número esté dentro de un rango inclusive."
  def validar_rango(numero, minimo, maximo)
      when is_number(numero) and is_number(minimo) and is_number(maximo) and minimo <= maximo do
    if numero >= minimo and numero <= maximo, do: {:ok, numero}, else: {:error, :fuera_de_rango}
  end

  @doc "Retorna un error si el rango recibido no es válido."
  def validar_rango(_, _, _), do: {:error, :argumentos_de_rango_invalidos}

  @doc "Valida que un correo tenga formato de dirección de correo electrónico básico."
  def validar_correo(correo) when is_binary(correo) do
    patron = ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/u

    if Regex.match?(patron, String.trim(correo)),
      do: {:ok, correo},
      else: {:error, :correo_invalido}
  end

  @doc "Retorna un error cuando la entrada no es un texto."
  def validar_correo(_), do: {:error, :se_esperaba_texto}

  @doc "Calcula el promedio simple de una lista de números."
  def promedio_lista(lista) when is_list(lista) do
    cond do
      lista == [] -> {:error, :lista_vacia}
      not Enum.all?(lista, &is_number/1) -> {:error, :la_lista_debe_contener_numeros}
      true -> {:ok, Enum.sum(lista) / length(lista)}
    end
  end

  @doc "Devuelve un error cuando la entrada no es una lista."
  def promedio_lista(_), do: {:error, :se_esperaba_una_lista}

  @doc "Calcula un promedio ponderado a partir de pares `{valor, peso}`."
  def promedio_ponderado(datos) when is_list(datos) do
    datos_validos =
      Enum.all?(datos, fn
        {valor, peso} -> is_number(valor) and is_number(peso) and peso >= 0
        _ -> false
      end)

    peso_total =
      Enum.reduce(datos, 0, fn
        {_valor, peso}, total when is_number(peso) -> total + peso
        _, total -> total
      end)

    cond do
      datos == [] ->
        {:error, :lista_vacia}

      not datos_validos ->
        {:error, :se_esperaban_pares_valor_peso_validos}

      peso_total == 0 ->
        {:error, :el_peso_total_debe_ser_mayor_que_cero}

      true ->
        suma_ponderada =
          Enum.reduce(datos, 0, fn {valor, peso}, total -> total + valor * peso end)

        {:ok, suma_ponderada / peso_total}
    end
  end

  @doc "Devuelve un error si la entrada no es una lista."
  def promedio_ponderado(_), do: {:error, :se_esperaba_una_lista}

  @doc "Calcula el porcentaje indicado sobre un valor dado."
  def porcentaje(valor, porcentaje) when is_number(valor) and is_number(porcentaje) do
    {:ok, valor * porcentaje / 100}
  end

  @doc "Retorna error si los argumentos no son numéricos."
  def porcentaje(_, _), do: {:error, :argumentos_invalidos}

  @doc "Calcula el área de un rectángulo."
  def area_rectangulo(base, altura)
      when is_number(base) and is_number(altura) and base >= 0 and altura >= 0 do
    {:ok, base * altura}
  end

  @doc "Valida que las dimensiones del rectángulo sean correctas."
  def area_rectangulo(_, _), do: {:error, :dimensiones_invalidas}

  @doc "Convierte grados Celsius a Fahrenheit."
  def celsius_a_fahrenheit(celsius) when is_number(celsius), do: {:ok, celsius * 9 / 5 + 32}
  def celsius_a_fahrenheit(_), do: {:error, :se_esperaba_un_numero}

  @doc "Convierte grados Fahrenheit a Celsius."
  def fahrenheit_a_celsius(fahrenheit) when is_number(fahrenheit),
    do: {:ok, (fahrenheit - 32) * 5 / 9}

  def fahrenheit_a_celsius(_), do: {:error, :se_esperaba_un_numero}

  @doc "Calcula el descuento de un precio según un porcentaje."
  def calcular_descuento(precio, porcentaje)
      when is_number(precio) and precio >= 0 and is_number(porcentaje) and porcentaje >= 0 and
             porcentaje <= 100 do
    descuento = precio * porcentaje / 100
    {:ok, %{precio_original: precio, descuento: descuento, total: precio - descuento}}
  end

  @doc "Error de validación para precio o porcentaje inválidos."
  def calcular_descuento(_, _), do: {:error, :precio_o_porcentaje_invalido}

  @doc "Calcula el valor final de un precio con impuesto."
  def calcular_total_con_impuesto(precio, porcentaje)
      when is_number(precio) and precio >= 0 and is_number(porcentaje) and porcentaje >= 0 and
             porcentaje <= 100 do
    impuesto = precio * porcentaje / 100
    {:ok, %{subtotal: precio, impuesto: impuesto, total: precio + impuesto}}
  end

  @doc "Error de validación para precio o porcentaje inválidos."
  def calcular_total_con_impuesto(_, _), do: {:error, :precio_o_porcentaje_invalido}

  @doc "Divide una cuenta entre varias personas, incluyendo propina opcional."
  def dividir_cuenta(total, personas, propina_porcentaje)
      when is_number(total) and total >= 0 and is_integer(personas) and personas > 0 and
             is_number(propina_porcentaje) and propina_porcentaje >= 0 and
             propina_porcentaje <= 100 do
    propina = total * propina_porcentaje / 100
    total_con_propina = total + propina

    {:ok,
     %{
       subtotal_por_persona: total / personas,
       propina_por_persona: propina / personas,
       total_por_persona: total_con_propina / personas
     }}
  end

  @doc "Retorna un error si los datos de la cuenta no son válidos."
  def dividir_cuenta(_, _, _), do: {:error, :datos_de_cuenta_invalidos}

  @doc "Calcula el monto acumulado con interés compuesto."
  def interes_compuesto(capital, tasa_anual, anios, capitalizaciones_por_anio)
      when is_number(capital) and capital > 0 and is_number(tasa_anual) and tasa_anual >= 0 and
             is_number(anios) and anios >= 0 and is_integer(capitalizaciones_por_anio) and
             capitalizaciones_por_anio > 0 do
    tasa = tasa_anual / 100

    monto =
      capital * :math.pow(1 + tasa / capitalizaciones_por_anio, capitalizaciones_por_anio * anios)

    {:ok, monto}
  end

  @doc "Validación de argumentos para interés compuesto."
  def interes_compuesto(_, _, _, _), do: {:error, :parametros_de_interes_invalidos}

  @doc "Calcula la edad entre dos fechas, validando que la fecha de nacimiento no sea futura."
  def calcular_edad(%Date{} = nacimiento, %Date{} = fecha_actual) do
    cond do
      Date.compare(nacimiento, fecha_actual) == :gt -> {:error, :fecha_de_nacimiento_futura}
      nacimiento.month > fecha_actual.month -> {:ok, fecha_actual.year - nacimiento.year - 1}
      nacimiento.month < fecha_actual.month -> {:ok, fecha_actual.year - nacimiento.year}
      nacimiento.day > fecha_actual.day -> {:ok, fecha_actual.year - nacimiento.year - 1}
      true -> {:ok, fecha_actual.year - nacimiento.year}
    end
  end

  @doc "Error cuando alguno de los argumentos no es una fecha válida."
  def calcular_edad(_, _), do: {:error, :fechas_invalidas}

  @doc "Formatea un número con la cantidad de decimales indicada."
  def formatear_decimal(valor, decimales)
      when is_number(valor) and is_integer(decimales) and decimales >= 0 do
    :erlang.float_to_binary(valor / 1, decimals: decimales)
  end

  @doc "Error si el valor o la cantidad de decimales no es válida."
  def formatear_decimal(_, _), do: {:error, :argumentos_invalidos}

  @doc "Formatea un valor monetario con dos decimales."
  def formatear_dinero(valor), do: formatear_decimal(valor, 2)

  @doc "Obtiene las claves con el valor máximo dentro de un Enumerable de pares."
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

      {claves, valor_maximo}
    end
  end

  @doc "Comprueba si todos los elementos requeridos están presentes en la lista."
  def contiene_todos?(lista, requeridos) do
    Enum.all?(requeridos, &(&1 in lista))
  end
end
