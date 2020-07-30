defmodule SevenottersMongo.MixProject do
  use Mix.Project

  def project do
    [
      app: :sevenotters_mongo,
      version: "0.1.3",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "Seven Otters MongoDB support",
      source_url: "https://github.com/sevenotters",
      homepage_url: "https://www.sevenotters.org",
      docs: docs(),

      # Package
      description: "MongoDB persistence support for Seven Otters.",
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      main: "getting_started",
      logo: "markdown/icon.png",
      extras: ["markdown/getting_started.md"]
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Nicola Fiorillo"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/sevenotters/sevenotters_mongo"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.1", only: :dev, runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:mongodb, "~> 0.5"}
    ]
  end
end
