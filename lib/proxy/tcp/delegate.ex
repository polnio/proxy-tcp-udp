defmodule Proxy.TCP.Delegate do
  require Logger
  import AddressUtil
  import FilterListUtil

  def start_proxy_loop(downstream_socket, upstream_socket, state) do
    {:ok, downstream_peer} = :inet.peername(downstream_socket)
    {:ok, local} = :inet.sockname(downstream_socket)
    {:ok, upstream_peer} = :inet.peername(upstream_socket)
    if !list_check(ipfmt(downstream_peer), state.whitelist, state.blacklist) do
      {:error, :unauthorized}
    else
      Logger.info "TCP connection: #{ipfmt(downstream_peer)} > #{ipfmt(local)} > #{ipfmt(upstream_peer)}"
      on_global_connect = state.global_events[:on_connect]
      if on_global_connect != nil do
        on_global_connect.(:tcp, ipfmt(downstream_peer), unparse_id(state.id))
      end
      on_connect = state.events[:on_connect]
      if on_connect != nil do
        on_connect.(:tcp, ipfmt(downstream_peer))
      end
      loop_pid = spawn_link(fn ->
        receive do :ready -> :ok end
        :ok = :inet.setopts(downstream_socket, [:binary, packet: 0, active: true, nodelay: true])
        downstream = %{socket: downstream_socket, amount: 0}
        upstream = %{socket: upstream_socket, amount: 0}
        proxy_loop(downstream, upstream, state)
      end)
      {:ok, loop_pid}
    end
  end

  defp proxy_loop(downstream, upstream, state) do
    receive do
      msg -> handle_receive(msg, downstream, upstream, state)
    end
  end

  defp handle_receive({:tcp, socket, data}, ds = %{socket: socket}, us, state) do
    {:ok, downstream_peer} = :inet.peername(socket)
    # {:ok, upstream_peer} = :inet.peername(us.socket)
    # Logger.info "TCP data: #{ipfmt(downstream_peer)} > #{ipfmt(upstream_peer)}\n#{data}"
    on_global_client_message = state.global_events[:on_client_message]
    if on_global_client_message != nil do
      on_global_client_message.(:tcp, ipfmt(downstream_peer), unparse_id(state.id), data)
    end
    on_client_message = state.events[:on_client_message]
    if on_client_message != nil do
      on_client_message.(:tcp, ipfmt(downstream_peer), data)
    end
    {:ok, count} = relay_to(us.socket, data)
    proxy_loop(%{ds | amount: ds.amount + count}, us, state)
  end

  defp handle_receive({:tcp_error, socket, reason}, %{socket: socket}, us, state) do
    Logger.info "tcp_error downstream #{reason}"
    {:ok, downstream_peer} = :inet.peername(socket)
    on_global_error = state.global_events[:on_error]
    if on_global_error != nil do
      on_global_error.(:tcp, ipfmt(downstream_peer), unparse_id(state.id), reason)
    end
    on_error = state.events[:on_error]
    if on_error != nil do
      on_error.(:tcp, ipfmt(downstream_peer), reason)
    end
    relay_to(us.socket, <<>>)
  end

  defp handle_receive({:tcp_closed, socket}, _ds = %{socket: socket}, us, state) do
    # Logger.info "Downstream socket closed"
    relay_to(us.socket, <<>>)
    on_global_disconnect = state.global_events[:on_disconnect]
    if on_global_disconnect != nil do
      on_global_disconnect.(:tcp, unparse_id(state.id))
    end
    on_disconnect = state.events[:on_disconnect]
    if on_disconnect != nil do
      on_disconnect.(:tcp)
    end
    :gen_tcp.close(us.socket)
    # Logger.info "Total bytes >#{ds.amount} <#{us.amount}"
  end

  defp handle_receive({:tcp, socket, data}, ds, us = %{socket: socket}, state) do
    {:ok, downstream_peer} = :inet.peername(ds.socket)
    # {:ok, upstream_peer} = :inet.peername(us.socket)
    # Logger.info "TCP data: #{ipfmt(downstream_peer)} < #{ipfmt(upstream_peer)}\n#{data}"
    on_global_server_message = state.global_events[:on_server_message]
    if on_global_server_message != nil do
      on_global_server_message.(:tcp, ipfmt(downstream_peer), unparse_id(state.id), data)
    end
    on_server_message = state.events[:on_server_message]
    if on_server_message != nil do
      on_server_message.(:tcp, ipfmt(us.peer), data)
    end
    {:ok, count} = relay_to(ds.socket, data)
    proxy_loop(ds, %{us | amount: us.amount + count}, state)
  end

  defp handle_receive({:tcp_error, socket, reason}, ds, %{socket: socket}, _state) do
    Logger.info "tcp_error upstream #{reason}"
    relay_to(ds.socket, <<>>)
  end

  defp handle_receive({:tcp_closed, socket}, ds, _us = %{socket: socket}, _state) do
    # Logger.info "Upstream socket closed"
    relay_to(ds.socket, <<>>)
    :gen_tcp.close(ds.socket)
    # Logger.info "Total bytes >#{ds.amount} <#{us.amount}"
  end

  defp handle_receive(msg, ds, us, state) do
    Logger.error "Invalid message:"
    IO.inspect msg
    proxy_loop(ds, us, state)
  end

  def relay_to(socket, data) do
    :ok = :gen_tcp.send(socket, data)
    {:ok, byte_size(data)}
  end
end
