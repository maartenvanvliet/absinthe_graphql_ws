defmodule Test.Site do
  @moduledoc false

  @host "localhost"
  @port 29_876
  def host, do: @host
  def port, do: @port

  defmodule GraphSocket do
    use Absinthe.GraphqlWS.Socket, schema: Test.Site.Schema
  end

  defmodule Application do
    @moduledoc false
    use Elixir.Application

    def start(_type, _args) do
      children = [
        {Phoenix.PubSub, name: pubsub_name()},
        Test.Site.Endpoint,
        {Absinthe.Subscription, Test.Site.Endpoint}
      ]

      opts = [strategy: :one_for_one, name: Test.Site.Supervisor]
      Supervisor.start_link(children, opts)
    end

    defp pubsub_name,
      do:
        Application.get_env(:absinthe_graphql_ws, Test.Site.Endpoint)
        |> Keyword.fetch!(:pubsub_server)
  end

  defmodule Web do
    @moduledoc false
    def router do
      quote do
        use Phoenix.Router

        import Plug.Conn
        import Phoenix.Controller
      end
    end

    defmacro __using__(which) when is_atom(which) do
      apply(__MODULE__, which, [])
    end
  end

  defmodule TestPubSub do
    @moduledoc false
    def start_link, do: Registry.start_link(keys: :duplicate, name: __MODULE__)

    def subscribe(subscriber_key), do: Registry.register(__MODULE__, subscriber_key, nil)

    def notify(subscriber_key, message) do
      __MODULE__
      |> Registry.lookup(subscriber_key)
      |> Enum.map(fn {pid, _value} -> pid end)
      |> Enum.each(&send(&1, message))
    end
  end

  defmodule Router do
    @moduledoc false
    use Web, :router

    @dialyzer {:nowarn_function, {:call, 2}}

    pipeline :browser do
      plug(:accepts, ["html"])
      plug(:fetch_session)
      plug(:protect_from_forgery)
    end

    scope "/" do
      pipe_through(:browser)
    end
  end

  defmodule Endpoint do
    @moduledoc false
    use Phoenix.Endpoint, otp_app: :absinthe_graphql_ws
    use Absinthe.Phoenix.Endpoint

    @socket "/graphql"
    def socket, do: @socket

    socket @socket,
           Test.Site.GraphSocket,
           websocket: [path: "", subprotocols: ["graphql-transport-ws"]]

    plug(Plug.Head)
    plug(Test.Site.Router)

    @doc false
    def init(:supervisor, config) do
      {
        :ok,
        Keyword.merge(
          config,
          debug_errors: false,
          http: [
            port: Test.Site.port()
          ],
          https: false,
          secret_key_base: String.duplicate("abcdefgh", 8),
          server: true,
          url: [host: Test.Site.host()]
        )
      }
    end
  end
end
