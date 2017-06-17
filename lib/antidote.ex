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

  def encode(input, opts \\ []) do
    case Antidote.Encode.encode(input, format_opts(opts)) do
      {:ok, result} -> {:ok, IO.iodata_to_binary(result)}
      {:error, error} -> {:error, error}
    end
  end

  def encode!(input, opts \\ []) do
    case Antidote.Encode.encode(input, format_opts(opts)) do
      {:ok, result} -> IO.iodata_to_binary(result)
      {:error, error} -> raise error
    end
  end

  def encode_to_iodata(input, opts \\ []) do
    Antidote.Encode.encode(input, format_opts(opts))
  end

  def encode_to_iodata!(input, opts \\ []) do
    case Antidote.Encode.encode(input, format_opts(opts)) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  defp format_opts(opts) do
    Enum.into(opts, %{escape: :json, validate: true, maps: :naive})
  end
end
