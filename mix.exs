defmodule Accounting.Mixfile do
  use Mix.Project

  def project do
    [
      app: :accounting,
      build_embedded: Mix.env === :prod,
      deps: deps(),
      description: "Accounting.",
      elixir: "~> 1.5",
      package: package(),
      version: "0.7.0",
      start_permanent: Mix.env === :prod,
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:httpoison, "~> 0.9"},
      {:oauther, "~> 1.1.0"},
      {:poison, "~> 2.2 or ~> 3.0"},
    ]
  end

  defp package do
    [
      maintainers: ["Very"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/verypossible/accounting"},
    ]
  end
end
