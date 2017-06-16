defmodule Antidote do
  def decode(input) do
    Antidote.Parser.parse(input)
  end

  def decode!(input) do
    case Antidote.Parser.parse(input) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end
end
