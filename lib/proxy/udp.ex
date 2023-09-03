defmodule Proxy.UDP do
  require Logger
  alias Proxy.UDP.Upstream
  import AddressUtil

  use GenServer

  defmodule State do
    defstruct(
      id: nil,
      accept_pid: nil,
      client_count: 0,
      client_table: nil,
      client_map: %{},
      listen_port: 8000,
      listen_socket: nil,
      remote_host: nil,
      remote_port: nil,
      opts: [:binary, active: true],
      max_clients_allowed: 2,
      events: [],
      global_events: []
    )
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    {host, port} = split_host_and_port(opts[:remote_host])
    {:ok, socket} = :gen_udp.open(opts[:listen_port], [:binary, active: true])
    Logger.info "UDP: port #{opts[:listen_port]} => #{host}:#{port}"
    state = %State{
      id: opts[:id],
      client_table: :ets.new(opts[:id], [:named_table]),
      client_map: %{},
      listen_port: opts[:listen_port],
      listen_socket: socket,
      remote_host: host,
      remote_port: String.to_integer(port),
      max_clients_allowed: opts[:max_clients],
      events: opts[:events],
      global_events: opts[:global_events]
    }
    {:ok, state}
  end

  def recieve_data(downstream, data) do
    GenServer.cast(downstream.pid, {:recieve, downstream, data})
  end

  def handle_cast({:recieve, downstream, data}, %State{listen_socket: socket} = state) do
    # Logger.info "UDP data: #{ipfmt({downstream.host, downstream.port})} < #{state.remote_host}:#{state.remote_port}\n#{data}"
    on_global_server_message = state.global_events[:on_server_message]
    if on_global_server_message != nil do
      on_global_server_message.(:udp, ipfmt({downstream.host, downstream.port}), unparse_id(state.id), data)
    end
    on_server_message = state.events[:on_server_message]
    if on_server_message != nil do
      on_server_message.(:udp, ipfmt({downstream.host, downstream.port}), data)
    end
    :ok = :gen_udp.send(socket, downstream.host, downstream.port, data)
    {:noreply, state}
  end

  def handle_info({:udp, _socket, ip, port, data}, %State{} = state) do
    map_key = {ip, port}
    server_pid = self()
    is_in_client_table = Map.has_key?(state.client_map, map_key)
    client_pid = state.client_map
    |> Map.get_lazy(map_key, fn ->
        server = %{
          pid: server_pid,
          host: ip,
          port: port
        }
        {:ok, client_pid} = Upstream.start_link(state.remote_host, state.remote_port, server, state.id, state.events, state.global_events)
        client_pid
      end)
    unless is_in_client_table do
      Logger.info "UDP connection: #{ipfmt({ip, port})} > 127.0.0.1:#{state.listen_port} > #{state.remote_host}:#{state.remote_port}"
      on_global_connect = state.global_events[:on_connect]
      if on_global_connect != nil do
        on_global_connect.(:udp, ipfmt({ip, port}), unparse_id(state.id))
      end
      on_connect = state.events[:on_connect]
      if on_connect != nil do
        on_connect.(:udp, ipfmt({ip, port}))
      end
    end
    state = Map.put(
      state,
      :client_map,
      Map.put(state.client_map, map_key, client_pid)
    )
    Upstream.send_data(client_pid, data)
    {:noreply, state}
  end

  def handle_info({:udp_passive, _socket}, state) do
    {:noreply, state}
  end
end
