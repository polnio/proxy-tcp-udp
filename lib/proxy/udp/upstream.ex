defmodule Proxy.UDP.Upstream do
  alias Proxy.UDP
  require Logger
  import AddressUtil

  use GenServer

  defmodule State do
    defstruct(
      id: nil,
      socket: nil,
      upstream_host: nil,
      upstream_port: nil,
      downstream: nil,
      events: [],
      global_events: []
    )
  end

  def start_link(upstream_host, upstream_port, downstream, id, events, global_events) do
    GenServer.start_link(__MODULE__, {upstream_host, upstream_port, downstream, id, events, global_events})
  end

  def init({upstream_host, upstream_port, downstream, id, events, global_events}) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: true])
    state = %State{
      id: id,
      socket: socket,
      upstream_host: upstream_host,
      upstream_port: upstream_port,
      downstream: downstream,
      events: events,
      global_events: global_events
    }
    {:ok, state}
  end

  def send_data(upstream, data) do
    GenServer.cast(upstream, {:send, data})
  end

  def close(upstream) do
    GenServer.cast(upstream, :close)
  end

  def handle_cast({:send, data}, %State{} = state) do
    :gen_udp.send(
      state.socket,
      String.to_charlist(state.upstream_host),
      state.upstream_port,
      data
    )
    # Logger.info "UDP: #{ipfmt({state.downstream.host, state.downstream.port})} > #{state.upstream_host}:#{state.upstream_port}\n#{data}"
    on_global_client_message = state.global_events[:on_client_message]
    if on_global_client_message != nil do
      on_global_client_message.(:udp, ipfmt({state.downstream.host, state.downstream.port}), state.id, data)
    end
    on_client_message = state.events[:on_client_message]
    if on_client_message != nil do
      on_client_message.(:udp, ipfmt({state.downstream.host, state.downstream.port}), data)
    end
    {:noreply, state}
  end

  def handle_cast(:close, %State{} = state) do
    on_global_disconnect = state.global_events[:on_disconnect]
    if on_global_disconnect != nil do
      on_global_disconnect.(:udp, join_address(state.downstream.host, state.downstream.port))
    end
    on_disconnect = state.events[:on_disconnect]
    if on_disconnect != nil do
      on_disconnect.(:udp, join_address(state.downstream.host, state.downstream.port))
    end
    :gen_udp.close(state.socket)
    {:stop, :normal, state}
  end

  def handle_info({:udp, _socket, _ip, _port, data}, %State{} = state) do
    UDP.recieve_data(state.downstream, data)
    {:noreply, state}
  end

  def handle_info({:udp_passive, _socket}, state) do
    {:noreply, state}
  end
end
