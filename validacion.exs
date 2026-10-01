defmodule Validacion do

  def validar_pesaje(pesaje, recolectores, lotes) do
    with {:ok, _} <- validar_recolector(Map.get(pesaje, :recolector), recolectores),
         {:ok, _} <- validar_lote(Map.get(pesaje, :lote), lotes),
         {:ok, _} <- validar_dia(Map.get(pesaje, :dia)),
         {:ok, _} <- validar_kilos(Map.get(pesaje, :kilos)),
         {:ok, _} <- validar_verdes(Map.get(pesaje, :verdes)) do
      {:ok, pesaje}
    end
  end

  def validar_recolector(codigo, recolectores) do
    existe =
      Enum.any?(recolectores, fn recolector ->
        Map.get(recolector, :codigo) == codigo
      end)

    if existe do
      {:ok, codigo}
    else
      {:error, :recolector_desconocido}
    end
  end

  def validar_lote(id, lotes) do
    existe =
      Enum.any?(lotes, fn lote ->
        Map.get(lote, :id) == id
      end)

    if existe do
      {:ok, id}
    else
      {:error, :lote_desconocido}
    end
  end

  def validar_dia(dia) do
    if is_integer(dia) do
      case Util.validar_rango(dia, 1, 6) do
        {:ok, dia} -> {:ok, dia}
        {:error, _} -> {:error, :dia_invalido}
      end
    else
      {:error, :dia_invalido}
    end
  end

  def validar_kilos(kilos) do
    case Util.validar_positivo(kilos) do
      {:ok, kilos} ->
        case Util.validar_rango(kilos, 0, 250) do
          {:ok, kilos} -> {:ok, kilos}
          {:error, _} -> {:error, :kilos_fuera_de_rango}
        end

      {:error, _} ->
        {:error, :kilos_fuera_de_rango}
    end
  end

  def validar_verdes(verdes) do
    case Util.validar_rango(verdes, 0, 100) do
      {:ok, verdes} -> {:ok, verdes}
      {:error, _} -> {:error, :porcentaje_invalido}
    end
  end
end
