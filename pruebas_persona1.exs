ExUnit.start()

Code.require_file("util.exs")
Code.require_file("validacion.exs")
Code.require_file("reportes_p1.exs")

defmodule PruebasPersona1Test do
  use ExUnit.Case

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

  test "validacion devuelve los seis rechazos del anexo" do
    rechazados = Reportes.pesajes_rechazados(@pesajes, @recolectores, @lotes)

    motivos = Enum.map(rechazados, fn {_pesaje, motivo} -> motivo end)

    assert motivos == [
      :recolector_desconocido,
      :lote_desconocido,
      :dia_invalido,
      :kilos_fuera_de_rango,
      :kilos_fuera_de_rango,
      :porcentaje_invalido
    ]
  end

  test "un pesaje con dos errores devuelve el primero" do
    pesaje = %{recolector: "R04", lote: "L3", dia: 7, kilos: 300, verdes: 3}

    assert Validacion.validar_pesaje(pesaje, @recolectores, @lotes) ==
             {:error, :dia_invalido}
  end

  test "los kilos por lote coinciden con el anexo" do
    resultados = Reportes.kilos_por_lote(@pesajes, @recolectores, @lotes)

    assert Enum.map(resultados, fn lote -> lote.nombre end) ==
             ["La Cañada", "El Mirador", "Buenavista"]

    assert Enum.map(resultados, fn lote -> lote.kilos end) ==
             [290.5, 385, 280]
  end

  test "combinar_kilos suma los dias repetidos y conserva los exclusivos" do
    finca = %{1 => 410, 2 => 300.5, 3 => 245, 4 => 0, 5 => 0, 6 => 0}
    vecina = %{1 => 520.5, 2 => 610, 3 => 480, 5 => 700, 7 => 300}

    assert Reportes.combinar_kilos(finca, vecina) == %{
             1 => 930.5,
             2 => 910.5,
             3 => 725,
             4 => 0,
             5 => 700,
             6 => 0,
             7 => 300
           }
  end
end

