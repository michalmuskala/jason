defmodule Jason.App do
  use Application

  def start(_type, _args) do
    :ets.new(Jason, [:named_table, :set, :public])

    children = []
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
