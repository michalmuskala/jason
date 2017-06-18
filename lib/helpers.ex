defmodule Antidote.Helpers do
  alias Antidote.Encode

  defmacro json_map(kv, opts \\ []) do
    escape = quote(do: escape)
    encode_map = quote(do: encode_map)
    opts = quote(do: opts)
    kv_iodata = build_kv_iodata(Macro.expand(kv, __CALLER__), escape, encode_map, opts)
    quote do
      {unquote(escape), unquote(encode_map), unquote(opts)} =
        Antidote.Helpers.__prepare_opts__(unquote(opts))
      Antidote.Helpers.__build__(fn ->
        unquote(kv_iodata)
      end)
    end
  end

  # defmacro json_map_take(map, take, opts \\ []) do
  #   escape = quote(do: escape)
  #   encode_map = quote(do: encode_map)
  #   opts = quote(do: opts)
  #   kv_iodata = build_kv_iodata(kv, escape, encode_map, opts, __CALLER__)
  #   quote do
  #     {unquote(escape), unquote(encode_map), unquote(opts)} =
  #       Antidote.Helpers.__prepare_opts__(unquote(opts))
  #     unquote(kv_iodata)
  #   end
  # end

  # defmacro json_map_drop(map, take, opts \\ []) do

  # end

  defp build_kv_iodata(kv, escape, encode_map, opts) do
    elements = Enum.map(kv, &encode_pair(&1, escape, encode_map, opts))
    collapse_static(["{", elements, "}"])
  end

  def __prepare_opts__(opts) do
    opts = Enum.into(opts, %{escape: :json, validate: true, maps: :naive})
    {Encode.escape_function(opts), Encode.encode_map_function(opts), opts}
  end

  def __encode__(value, escape, encode_map, opts) do
    Antidote.Encode.encode_dispatch(value, escape, encode_map, opts)
  end

  def __build__(fun) do
    try do
      Antidote.Fragment.new(fun.())
    catch
      {:duplicate_key, _} = err ->
        raise Antidote.EncodeError, err
      {:invalid_byte, _, _} = err ->
        raise Antidote.EncodeError, err
    end
  end
end
