defmodule Antidote.Helpers do
  @moduledoc """
  Provides macro facilities for partial compile-time encoding of JSON.
  """
  alias Antidote.Encode

  @doc ~S"""
  Encodes a JSON map from a compile-time keyword.

  Encodes they key at compile time and strives to create as flat iodata
  structure as possible to achieve maximum efficiency. Does encoding
  right at the call site, but returns an `%Antidote.Fragment{}` struct
  that needs to be passed to one of the "main" encoding functions -
  for example `Antidote.encode/2` for final encoding into JSON - this
  makes it completely transparent for most uses.

  Only allows keys that do not require escaping in any of the supported
  encoding modes. This means only ASCII characters from the range
  0x1F..0x7F excluding '\', '/' and '"' are allowed - this also excludes
  all control characters like newlines.

  Preserves the order of the keys.

  ## Example

      iex> json_map(foo: 1, bar: 2)
      %Antidote.Fragment{iodata: ["{\"foo\":", "1", ",\"bar\":", "2", "}"]}

  """
  defmacro json_map(kv, opts \\ []) do
    escape = quote(do: escape)
    encode_map = quote(do: encode_map)
    encode_opts = quote(do: opts)
    encode_args = [escape, encode_map, encode_opts]
    kv_iodata = build_kv_iodata(Macro.expand(kv, __CALLER__), encode_args)
    quote do
      try do
        {unquote(escape), unquote(encode_map), unquote(encode_opts)} =
          Antidote.Helpers.__prepare_opts__(unquote(opts))
        Antidote.Fragment.new(unquote(kv_iodata))
      catch
        {:antidote_encode_error, err} ->
          raise Antidote.EncodeError, err
      end
    end
  end

  @doc ~S"""
  Encodes a JSON map from a variable containing a map and a compile-time
  list of keys.

  It is equivalent to calling `Map.take/2` before encoding. Otherwise works
  similar to `json_map/2`.

  ## Example

      iex> map = %{a: 1, b: 2, c: 3}
      iex> json_map_take(map, [:c, :b])
      %Antidote.Fragment{iodata: ["{\"c\":", "3", ",\"b\":", "2", "}"]}

  """
  defmacro json_map_take(map, take, opts \\ []) do
    kv = Enum.map(Macro.expand(take, __CALLER__), &{&1, Macro.var(&1, __MODULE__)})
    escape = quote(do: escape)
    encode_map = quote(do: encode_map)
    encode_opts = quote(do: opts)
    encode_args = [escape, encode_map, encode_opts]
    kv_iodata = build_kv_iodata(kv, encode_args)
    quote do
      try do
        {unquote(escape), unquote(encode_map), unquote(encode_opts)} =
          Antidote.Helpers.__prepare_opts__(unquote(opts))
        case unquote(map) do
          %{unquote_splicing(kv)} ->
            Antidote.Fragment.new(unquote(kv_iodata))
          other ->
            raise ArgumentError, "expected a map with keys: #{inspect unquote(take)}, got: #{inspect other}"
        end
      catch
        {:antidote_encode_error, err} ->
          raise Antidote.EncodeError, err
      end
    end
  end

  defp build_kv_iodata(kv, encode_args) do
    elements =
      kv
      |> Enum.map(&encode_pair(&1, encode_args))
      |> Enum.intersperse(",")
    collapse_static(List.flatten(["{", elements, "}"]))
  end

  defp encode_pair({key, value}, encode_args) do
    key = IO.iodata_to_binary(Antidote.Encode.encode_key(key, &escape_key/4))
    ["\"" <> key <> "\":", quote do
      Antidote.Helpers.__encode__(unquote_splicing([value | encode_args]))
    end]
  end

  defp escape_key(binary, _original, _skip, [] = _tail) do
    check_safe_key!(binary)
    binary
  end

  defp check_safe_key!(binary) do
    for << <<byte>> <- binary >> do
      if byte > 0x7F or byte < 0x1F or byte in '"\\/' do
        raise Antidote.EncodeError, "invalid byte #{inspect byte, base: :hex} in literal key: #{inspect binary}"
      end
    end
    :ok
  end

  defp collapse_static([bin1, bin2 | rest]) when is_binary(bin1) and is_binary(bin2) do
    collapse_static([bin1 <> bin2 | rest])
  end
  defp collapse_static([other | rest]) do
    [other | collapse_static(rest)]
  end
  defp collapse_static([]) do
    []
  end

  def __prepare_opts__(opts) do
    opts = Enum.into(opts, %{escape: :json, validate: true, maps: :naive})
    {Encode.escape_function(opts), Encode.encode_map_function(opts), opts}
  end

  def __encode__(value, escape, encode_map, opts) do
    Antidote.Encode.encode_dispatch(value, escape, encode_map, opts)
  end
end
