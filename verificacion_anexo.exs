defmodule VerificacionAnexo do
  @moduledoc """
  Compara los resultados del programa con la salida esperada del Anexo y con el ejemplo
  de liquidación de Luz Marina. Imprime `OK` o `FALLO` por cada comprobación y, al final,
  los reportes completos generados con los datos del Anexo.

  """

  @recolectores [
    %{codigo: "R01", nombre: "Luz Marina Ospina", alimentacion: true},
    %{codigo: "R02", nombre: "Jhon Fredy Castaño", alimentacion: false},
    %{codigo: "R03", nombre: "Dora Cardona", alimentacion: true},
    %{codigo: "R04", nombre: "Wilson Arango", alimentacion: false}
  ]

  @lotes [
    %{id: "L1", nombre: "El Mirador", hectareas: 2.5},
    %{id: "L2", nombre: "La Cañada", hectareas: 1.5},
    %{id: "L3", nombre: "Buenavista", hectareas: 3.0}
  ]

  @pesajes [
    %{recolector: "R01", lote: "L1", dia: 1, kilos: 70, verdes: 1.5},
    %{recolector: "R01", lote: "L2", dia: 1, kilos: 55, verdes: 6},
    %{recolector: "R01", lote: "L1", dia: 2, kilos: 90, verdes: 12},
    %{recolector: "R02", lote: "L1", dia: 1, kilos: 100, verdes: 2},
    %{recolector: "R02", lote: "L3", dia: 1, kilos: 45, verdes: 3},
    %{recolector: "R02", lote: "L2", dia: 2, kilos: 60.5, verdes: 4},
    %{recolector: "R02", lote: "L3", dia: 2, kilos: 65, verdes: 5},
    %{recolector: "R02", lote: "L3", dia: 3, kilos: 110, verdes: 1},
    %{recolector: "R03", lote: "L2", dia: 1, kilos: 80, verdes: 3},
    %{recolector: "R03", lote: "L3", dia: 1, kilos: 60, verdes: 4},
    %{recolector: "R03", lote: "L1", dia: 2, kilos: 85, verdes: 2.5},
    %{recolector: "R03", lote: "L2", dia: 3, kilos: 95, verdes: 8},
    %{recolector: "R03", lote: "L1", dia: 3, kilos: 40, verdes: 0},
    %{recolector: "R09", lote: "L1", dia: 1, kilos: 80, verdes: 3},
    %{recolector: "R03", lote: "L7", dia: 2, kilos: 50, verdes: 2},
    %{recolector: "R04", lote: "L3", dia: 7, kilos: 300, verdes: 3},
    %{recolector: "R02", lote: "L2", dia: 3, kilos: 0, verdes: 4},
    %{recolector: "R01", lote: "L3", dia: 3, kilos: 300, verdes: 2},
    %{recolector: "R01", lote: "L2", dia: 3, kilos: 40, verdes: 130}
  ]

  @doc "Ejecuta todas las comprobaciones e imprime el resultado."
  def ejecutar do
    por_codigo = Util.indexar_por(@recolectores, :codigo)
    por_id = Util.indexar_por(@lotes, :id)
    {validos, rechazados} = Validacion.separar_pesajes(@pesajes, por_codigo, por_id)
    liquidaciones = Liquidacion.liquidar(@recolectores, validos)
    neto_de = fn codigo -> Enum.find(liquidaciones, &(&1.codigo == codigo)).neto end
    dinero = &Util.formatear_dinero/1

    comprobaciones = [
      {"R1: seis rechazos con los motivos del Anexo, en orden",
       Enum.map(rechazados, fn {_p, motivo} -> motivo end) ==
         [
           :recolector_desconocido,
           :lote_desconocido,
           :dia_invalido,
           :kilos_fuera_de_rango,
           :kilos_fuera_de_rango,
           :porcentaje_invalido
         ]},
      {"Validación: R04 (día 7 y 300 kg) se rechaza solo por dia_invalido",
       Validacion.validar_pesaje(Enum.at(@pesajes, 15), por_codigo, por_id) ==
         {:error, :dia_invalido}},
      {"Regla 2: 70 kg con 1.5 % = $73500.00",
       dinero.(Liquidacion.valor_pesaje(70, 1.5)) == "73500.00"},
      {"Regla 2: 55 kg con 6 % = $49500.00",
       dinero.(Liquidacion.valor_pesaje(55, 6)) == "49500.00"},
      {"Regla 2: 90 kg con 12 % = $63000.00",
       dinero.(Liquidacion.valor_pesaje(90, 12)) == "63000.00"},
      {"Regla 3: 125 kg en el día dan $8000 y 90 kg dan $0",
       Liquidacion.bonificacion_dia(125) == 8000 and Liquidacion.bonificacion_dia(90) == 0},
      {"Regla 4: 2 días con alimentación = $24000",
       Liquidacion.descuento_alimentacion(true, 2) == 24000},
      {"Regla 5: neto de Luz Marina = $170000.00", dinero.(neto_de.("R01")) == "170000.00"},
      {"R4: neto de Jhon Fredy = $407000.00", dinero.(neto_de.("R02")) == "407000.00"},
      {"R4: neto de Dora = $332500.00", dinero.(neto_de.("R03")) == "332500.00"},
      {"R4: Wilson aparece con neto $0.00", dinero.(neto_de.("R04")) == "0.00"},
      {"R2: orden por rendimiento La Cañada, El Mirador, Buenavista",
       Enum.map(Reportes.kilos_por_lote(validos, @lotes), & &1.nombre) ==
         ["La Cañada", "El Mirador", "Buenavista"]},
      {"R3: kilos por día 410, 300.5, 245, 0, 0, 0",
       Liquidacion.kilos_por_dia_finca(validos) == %{
         1 => 410,
         2 => 300.5,
         3 => 245,
         4 => 0,
         5 => 0,
         6 => 0
       }},
      {"R5: Jhon Fredy fue el mejor 2 días",
       Liquidacion.recolector_con_mas_dias_ganador(Liquidacion.mejores_por_dia(validos)) ==
         {["R02"], 2}},
      {"R5: un empate muestra a todos los empatados",
       Liquidacion.mejores_del_dia(
         [%{recolector: "R03", dia: 4, kilos: 130}, %{recolector: "R01", dia: 4, kilos: 130}],
         4
       ) == {["R01", "R03"], 130}},
      {"R6: Jhon Fredy con 2.66 %",
       String.contains?(Reportes.r6(validos, por_codigo), "Jhon Fredy Castaño, con 2.66 %")},
      {"R7: total $909500.00, 955.5 kg y $951.86 por kilo",
       Reportes.r7(liquidaciones) ==
         "R7. Totales de la semana\nTotal a pagar: $909500.00\nKilos válidos: 955.5 kg\nCosto promedio por kilo: $951.86"},
      {"R8: Jhon Fredy y Dora trabajaron en todos los lotes",
       Reportes.r8(validos, @recolectores, @lotes) ==
         "R8. Recolectores que trabajaron en todos los lotes\nJhon Fredy Castaño\nDora Cardona"},
      {"B.5: 'R04;L3; 2;92.5;3' tiene formato correcto",
       Validacion.parsear_linea("R04;L3; 2;92.5;3") ==
         {:ok, %{recolector: "R04", lote: "L3", dia: 2, kilos: 92.5, verdes: 3.0}}},
      {"B.5: 'R03;L2; 4.5;92;3' es formato_invalido",
       Validacion.parsear_linea("R03;L2; 4.5;92;3") == {:error, :formato_invalido}},
      {"B.5: 'R04;L9; 2;50;3' pasa el formato y la validación da lote_desconocido",
       with(
         {:ok, p} <- Validacion.parsear_linea("R04;L9; 2;50;3"),
         do: Validacion.validar_pesaje(p, por_codigo, por_id)
       ) == {:error, :lote_desconocido}},
      {"B.5: una línea con cuatro campos es formato_invalido",
       Validacion.parsear_linea("R01;L1;2;50") == {:error, :formato_invalido}},
      {"C.1: con campo: :kilos, campo: :neto se usa la primera (:kilos)",
       String.starts_with?(
         Reportes.ranking(liquidaciones, campo: :kilos, campo: :neto),
         "Ranking (campo: kilos"
       )},
      {"C.2: Map.merge/3 suma los días comunes y conserva el día 7",
       Reportes.combinar_kilos(Liquidacion.kilos_por_dia_finca(validos), %{
         1 => 520.5,
         2 => 610,
         3 => 480,
         5 => 700,
         7 => 300
       }) ==
         %{1 => 930.5, 2 => 910.5, 3 => 725, 4 => 0, 5 => 700, 6 => 0, 7 => 300}}
    ]

    Enum.each(comprobaciones, fn {descripcion, resultado} ->
      Util.imprimir_mensaje("#{if resultado, do: "OK   ", else: "FALLO"} #{descripcion}")
    end)

    fallos = Enum.count(comprobaciones, fn {_descripcion, resultado} -> not resultado end)

    Util.imprimir_mensaje(
      "\n#{length(comprobaciones) - fallos} de #{length(comprobaciones)} comprobaciones correctas.\n"
    )

    Util.imprimir_mensaje("===== Reportes con los datos del Anexo =====\n")

    [
      Reportes.r1(rechazados),
      Reportes.r2(validos, @lotes),
      Reportes.r3(validos),
      Reportes.r4(liquidaciones),
      Reportes.r5(validos, por_codigo),
      Reportes.r6(validos, por_codigo),
      Reportes.r7(liquidaciones),
      Reportes.r8(validos, @recolectores, @lotes),
      Reportes.desprendible(por_codigo["R01"], validos)
    ]
    |> Enum.each(fn reporte -> Util.imprimir_mensaje(reporte <> "\n") end)
  end
end

VerificacionAnexo.ejecutar()
