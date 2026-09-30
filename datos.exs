defmodule Datos do

  def recolectores do
    [
      %{codigo: "R01", nombre: "Luz Marina Ospina", alimentacion: true},
      %{codigo: "R02", nombre: "Jhon Fredy Castaño", alimentacion: false},
      %{codigo: "R03", nombre: "Dora Cardona", alimentacion: true},
      %{codigo: "R04", nombre: "Wilson Arango", alimentacion: false}
    ]
  end

  @doc "Lista de lotes. Cada uno: %{id, nombre, hectareas}."
  def lotes do
    [
      %{id: "L1", nombre: "El Mirador", hectareas: 2.5},
      %{id: "L2", nombre: "La Cañada", hectareas: 1.5},
      %{id: "L3", nombre: "Buenavista", hectareas: 3.0}
    ]
  end

  @doc "Lista de pesajes crudos, sin validar. Cada uno: %{recolector, lote, dia, kilos, verdes}."
  def pesajes do
    [
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
  end
end
