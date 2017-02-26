defmodule ActionDataFetcher.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(ActionDataFetcher.GPO.Supervisor, []),
      worker(ActionDataFetcher.GPO.Server, []),
      supervisor(ActionDataFetcher.Propublica.Supervisor, []),
      worker(ActionDataFetcher.Propublica.Server, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ActionDataFetcher.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
