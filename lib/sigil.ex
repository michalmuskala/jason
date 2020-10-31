defmodule Jason.Sigil do
  @doc ~S"""
  Handles the sigil `~j` for JSON strings.

  Calls `Jason.decode!/2` with modifiers mapped to options.

  ## Modifiers

  See `Jason.decode/2` for detailed descriptions.

    * `a` - maps to `{:keys, :atoms}`
    * `A` - maps to `{:keys, :atoms!}`
    * `r` - maps to `{:strings, :reference}`
    * `c` - maps to `{:strings, :copy}`

  ## Examples

      iex> {~j"0", ~j"[1, 2, 3]", ~j'"string"'r, ~j"{}"}
      {0, [1, 2, 3], "string", %{}}

      iex> ~j'{"atom": "value"}'a
      %{atom: "value"}

      iex> ~j'{"#{:j}": #{'"j"'}}'A
      %{j: "j"}
  """
  @spec sigil_j(binary, charlist) :: term | no_return
  def sigil_j(input, []), do: Jason.decode!(input)
  def sigil_j(input, modifiers), do: Jason.decode!(input, mods_to_opts(modifiers))

  @doc ~S"""
  Handles the sigil `~J` for raw JSON strings.

  Decodes a raw string ignoring Elixir interpolations and escape characters.

  ## Examples

      iex> ~J'"#{string}"'
      "\#{string}"

      iex> ~J'"\u0078\\y"'
      "x\\y"

      iex> ~J'{"#{key}": "#{}"}'a
      %{"\#{key}": "#{}"}
  """
  @spec sigil_J(binary, charlist) :: term | no_return
  def sigil_J(input, modifiers), do: sigil_j(input, modifiers)

  @spec mods_to_opts(charlist) :: [Jason.decode_opt()] | no_return
  def mods_to_opts(modifiers) do
    modifiers
    |> Enum.map(fn
      ?a -> {:keys, :atoms}
      ?A -> {:keys, :atoms!}
      ?r -> {:strings, :reference}
      ?c -> {:strings, :copy}
      m -> raise ArgumentError, "unknown sigil modifier #{<<?", m, ?">>}"
    end)
  end
end
