defmodule Jason.Sigil do
  @doc ~S"""
  Handles the sigil `~j` for JSON strings.

  Calls `Jason.decode!/2` with modifiers mapped to options.

  ## Modifiers

    * `a` - keys are converted to atoms using String.to_atom/1
    * `A` - keys are converted to atoms using String.to_existing_atom/1
    * `r` - when possible tries to create a sub-binary into the original
    * `c` - always copies the strings

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

   without Elixir interpolations

  ## Examples

      iex> ~J'"#{string}"'
      "#{string}"

      iex> ~J'{"#{key}": "#{}"}'a
      %{"\#{key}": "#{}"}
  """
  @spec sigil_J(binary, charlist) :: term | no_return
  def sigil_J(input, modifiers),
    do: sigil_j(input, modifiers)

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
