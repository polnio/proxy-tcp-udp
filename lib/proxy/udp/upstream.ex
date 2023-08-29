defmodule Proxy.UDP.Upstream do
  alias Proxy.UDP
  require Logger
  import AddressUtil

  use GenServer

  defmodule State do
    defstruct(
      socket: nil,
      upstream_host: nil,
      upstream_port: nil,
      downstream: nil
    )
  end

  def start_link(upstream_host, upstream_port, downstream) do
    GenServer.start_link(__MODULE__, {upstream_host, upstream_port, downstream})
  end

  def init({upstream_host, upstream_port, downstream}) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: true])
    state = %State{
      socket: socket,
      upstream_host: upstream_host,
      upstream_port: upstream_port,
      downstream: downstream
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
    Logger.info "UDP: #{ipfmt({state.downstream.host, state.downstream.port})} > #{state.upstream_host}:#{state.upstream_port}\n#{data}"
    {:noreply, state}
  end

  def handle_cast(:close, %State{} = state) do
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
