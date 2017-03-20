defmodule Accounting.Mixfile do
  use Mix.Project

  def project do
    [
      app: :accounting,
      build_embedded: Mix.env === :prod,
      deps: deps(),
      description: "Accounting.",
      elixir: "~> 1.4",
      package: package(),
      version: "0.3.0",
      start_permanent: Mix.env === :prod,
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:httpoison, "~> 0.9"},
      {:oauther, "~> 1.1.0"},
      {:poison, "~> 2.2 or ~> 3.0"},
    ]
  end

  defp package do
    [
      maintainers: ["Spartan"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/spartansystems/accounting"},
    ]
  end

  def application, do: [mod: {Accounting.Application, []}]
end
