# Integrantes: Leandro, Martin, Samuel
# Programación III - Parcial 1: Liquidación de la cosecha de una finca cafetera
#
# Compilar los módulos de apoyo (repetirlo cada vez que cambie datos.exs):
#   elixirc datos.exs util.exs validacion.exs liquidacion.exs reportes.exs
# Ejecutar:
#   elixir programa.exs

defmodule Programa do
  @moduledoc """
  Punto de entrada de la aplicación.

  Orquesta el flujo completo: carga los datos de `Datos`, los valida, pide un pesaje
  adicional por consola, liquida a los recolectores, imprime los reportes R1 a R8, el
  ranking (C.1), la combinación con la finca vecina (C.2) y, al final, el desprendible de
  un recolector.

  Junto con `Util`, es el único módulo con funciones **impuras** (leen o escriben en
  consola): `main/0`, `agregar_pesaje_adicional/3`, `imprimir_reportes/5` y
  `mostrar_desprendible/2`. Toda la lógica de validación, liquidación y reportes que
  invoca es pura.
  """

  @finca_vecina %{1 => 520.5, 2 => 610, 3 => 480, 5 => 700, 7 => 300}

  @doc "Ejecuta el flujo principal del programa."
  def main do
    # 1. Cargar los datos crudos (listas, tal como saldrían de una planilla).
    recolectores = Datos.recolectores()
    lotes = Datos.lotes()
    pesajes = Datos.pesajes()

    # 2. Indexar recolectores y lotes en mapas para buscarlos por código/id (Parte A).
    recolectores_por_codigo = Util.indexar_por(recolectores, :codigo)
    lotes_por_id = Util.indexar_por(lotes, :id)

    # 3. Validar (regla 1 / B.2) y separar válidos de rechazados.
    {pesajes_validos, pesajes_rechazados} =
      Validacion.separar_pesajes(pesajes, recolectores_por_codigo, lotes_por_id)

    # 4. Pedir un pesaje adicional por consola (B.5, primera parte).
    {pesajes_validos, pesajes_rechazados} =
      agregar_pesaje_adicional(
        {pesajes_validos, pesajes_rechazados},
        recolectores_por_codigo,
        lotes_por_id
      )

    # 5. Liquidar (reglas 2 a 5) con los pesajes válidos ya completos.
    liquidaciones = Liquidacion.liquidar(recolectores, pesajes_validos)

    # 6. Mostrar los 8 reportes, el ranking (C.1) y la combinación de fincas (C.2).
    imprimir_reportes(
      {pesajes_validos, pesajes_rechazados},
      recolectores,
      recolectores_por_codigo,
      lotes,
      liquidaciones
    )

    # 7. Desprendible de pago de un recolector (B.5, segunda parte).
    mostrar_desprendible(recolectores_por_codigo, pesajes_validos)
  end

  @doc """
  Pide al usuario un pesaje adicional y lo agrega a los válidos o a los rechazados.

  * Enter (línea vacía): no agrega nada.
  * Formato incorrecto: informa `formato_invalido` y no lo agrega a ninguna lista (no hay
    un pesaje que mostrar en R1).
  * Formato correcto: lo valida con las mismas reglas que los pesajes de `datos.exs`. Si es
    válido se suma a los válidos (y entra en todos los reportes); si no, se suma a los
    rechazados con su motivo (aparece en R1).

  En todos los casos el programa informa qué pasó y continúa.
  """
  def agregar_pesaje_adicional({validos, rechazados}, recolectores_por_codigo, lotes_por_id) do
    linea =
      Util.leer(
        "Ingrese un pesaje adicional (recolector;lote;dia;kilos;verdes) o Enter para omitir: ",
        :string
      )

    if linea == "" do
      Util.imprimir_mensaje("No se agregó ningún pesaje.\n")
      {validos, rechazados}
    else
      case Validacion.parsear_linea(linea) do
        {:error, :formato_invalido} ->
          Util.imprimir_mensaje("Pesaje rechazado: formato_invalido\n")
          {validos, rechazados}

        {:ok, pesaje} ->
          case Validacion.validar_pesaje(pesaje, recolectores_por_codigo, lotes_por_id) do
            {:ok, pesaje_valido} ->
              Util.imprimir_mensaje(
                "Pesaje agregado: #{pesaje_valido.recolector} en #{pesaje_valido.lote}, " <>
                  "día #{pesaje_valido.dia}, #{pesaje_valido.kilos} kg, " <>
                  "#{pesaje_valido.verdes} % de verdes.\n"
              )

              {validos ++ [pesaje_valido], rechazados}

            {:error, motivo} ->
              Util.imprimir_mensaje("Pesaje rechazado: #{motivo}\n")
              {validos, rechazados ++ [{pesaje, motivo}]}
          end
      end
    end
  end

  @doc "Imprime, en orden, los reportes R1 a R8 y los resultados de la Parte C."
  def imprimir_reportes(
        {validos, rechazados},
        recolectores,
        recolectores_por_codigo,
        lotes,
        liquidaciones
      ) do
    reportes = [
      Reportes.r1(rechazados),
      Reportes.r2(validos, lotes),
      Reportes.r3(validos),
      Reportes.r4(liquidaciones),
      Reportes.r5(validos, recolectores_por_codigo),
      Reportes.r6(validos, recolectores_por_codigo),
      Reportes.r7(liquidaciones),
      Reportes.r8(validos, recolectores, lotes),
      # C.1: las tres llamadas que pide el enunciado.
      Reportes.ranking(liquidaciones, []),
      Reportes.ranking(liquidaciones, campo: :kilos, limite: 3),
      Reportes.ranking(liquidaciones, orden: :asc, campo: :bruto),
      # C.2: combinación con la finca vecina.
      Reportes.reporte_fincas_combinadas(validos, @finca_vecina)
    ]

    Enum.each(reportes, fn reporte -> Util.imprimir_mensaje(reporte <> "\n") end)
  end

  @doc """
  Pide el código de un recolector e imprime su desprendible de pago.
  Si el código no existe lo informa sin fallar.
  """
  def mostrar_desprendible(recolectores_por_codigo, pesajes_validos) do
    codigo = Util.leer("Ingrese el código del recolector para ver su desprendible: ", :string)

    case Map.get(recolectores_por_codigo, codigo) do
      nil when codigo == "" ->
        Util.imprimir_mensaje("No se ingresó ningún código de recolector.")

      nil ->
        Util.imprimir_mensaje("No existe un recolector con el código #{codigo}.")

      recolector ->
        Util.imprimir_mensaje(Reportes.desprendible(recolector, pesajes_validos))
    end
  end
end

Programa.main()
