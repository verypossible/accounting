use Mix.Config

config :ssl, protocol_version: :"tlsv1.2"

if Mix.env === :dev do
  config :mix_test_watch,
    tasks: [
      "test",
      "dialyzer",
    ]
end
