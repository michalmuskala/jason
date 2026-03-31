defmodule Bench.Helpers do
  def put_job_if_loaded(jobs, mod, fun) do
    if Code.ensure_loaded?(mod) do
      Map.put(jobs, Atom.to_string(mod), fun)
    else
      jobs
    end
  end

  def read_data!(name) do
    name
    |> String.downcase()
    |> String.replace(~r/([^\w]|-|_)+/, "-")
    |> String.trim("-")
    |> (&"data/#{&1}.json").()
    |> Path.expand(Path.dirname(Mix.Project.project_file()))
    |> File.read!()
  end
end
