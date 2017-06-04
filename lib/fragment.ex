defmodule Antidote.Fragment do
  defstruct [:iodata]

  def new(iodata) when is_list(iodata) or is_binary(iodata) do
    %__MODULE__{iodata: iodata}
  end
end
