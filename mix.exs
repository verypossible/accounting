defmodule Accounting.Mixfile do
  use Mix.Project

  def project do
    [
      app: :accounting,
      build_embedded: Mix.env === :prod,
      deps: deps(),
      description: "Accounting.",
      dialyzer: [
        flags: [
          :unmatched_returns,
          :error_handling,
          :race_conditions,
          :underspecs,
        ],
        plt_add_apps: [:ex_unit],
      ],
      elixir: "~> 1.5",
      package: package(),
      version: "0.7.1",
      start_permanent: Mix.env === :prod,
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:httpoison, "~> 0.11"},
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
