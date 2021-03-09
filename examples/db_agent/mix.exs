defmodule DbAgent.Mixfile do
  use Mix.Project

  def project do
    [app: :db_agent,
     version: "0.0.1",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :db_conn_legacy]]
  end

  defp deps do
    [{:db_conn_legacy, ">= 0.0.0", path: "../../"}]
  end
end
