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
      elixirc_paths: elixirc_paths(Mix.env),
      package: package(),
      version: "0.10.5",
      start_permanent: Mix.env === :prod,
    ]
  end

  defp deps do
    [
      {:credo, "~> 0.8.10", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:httpoison, "~> 0.11"},
      {:mix_test_watch, "~> 0.5", only: :dev, runtime: false},
      {:oauther, "~> 1.1.0"},
      {:poison, "~> 2.2 or ~> 3.0"},
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp package do
    [
      maintainers: ["Very"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/verypossible/accounting"},
    ]
  end
end
