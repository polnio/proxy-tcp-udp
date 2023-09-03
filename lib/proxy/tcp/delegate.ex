defmodule Proxy.TCP.Delegate do
  require Logger
  import AddressUtil

  def start_proxy_loop(downstream_socket, upstream_socket, proxy_id, events, global_events) do
    {:ok, downstream_peer} = :inet.peername(downstream_socket)
    {:ok, local} = :inet.sockname(downstream_socket)
    {:ok, upstream_peer} = :inet.peername(upstream_socket)
    Logger.info "TCP connection: #{ipfmt(downstream_peer)} > #{ipfmt(local)} > #{ipfmt(upstream_peer)}"
    on_global_connect = global_events[:on_connect]
    if on_global_connect != nil do
      on_global_connect.(:tcp, ipfmt(downstream_peer), unparse_id(proxy_id))
    end
    on_connect = events[:on_connect]
    if on_connect != nil do
      on_connect.(:tcp, ipfmt(downstream_peer))
    end
    loop_pid = spawn_link(fn ->
      receive do :ready -> :ok end
      :ok = :inet.setopts(downstream_socket, [:binary, packet: 0, active: true, nodelay: true])
      downstream = %{socket: downstream_socket, amount: 0}
      upstream = %{socket: upstream_socket, amount: 0}
      proxy_loop(downstream, upstream, proxy_id, events, global_events)
    end)
    {:ok, loop_pid}
  end

  defp proxy_loop(downstream, upstream, proxy_id, events, global_events) do
    receive do
      msg -> handle_receive(msg, downstream, upstream, proxy_id, events, global_events)
    end
  end

  defp handle_receive({:tcp, socket, data}, ds = %{socket: socket}, us, proxy_id, events, global_events) do
    {:ok, downstream_peer} = :inet.peername(socket)
    # {:ok, upstream_peer} = :inet.peername(us.socket)
    # Logger.info "TCP data: #{ipfmt(downstream_peer)} > #{ipfmt(upstream_peer)}\n#{data}"
    on_global_client_message = global_events[:on_client_message]
    if on_global_client_message != nil do
      on_global_client_message.(:tcp, ipfmt(downstream_peer), unparse_id(proxy_id), data)
    end
    on_client_message = events[:on_client_message]
    if on_client_message != nil do
      on_client_message.(:tcp, ipfmt(downstream_peer), data)
    end
    {:ok, count} = relay_to(us.socket, data)
    proxy_loop(%{ds | amount: ds.amount + count}, us, proxy_id, events, global_events)
  end

  defp handle_receive({:tcp_error, socket, reason}, %{socket: socket}, us, proxy_id, events, global_events) do
    Logger.info "tcp_error downstream #{reason}"
    {:ok, downstream_peer} = :inet.peername(socket)
    on_global_error = global_events[:on_error]
    if on_global_error != nil do
      on_global_error.(:tcp, ipfmt(downstream_peer), unparse_id(proxy_id), reason)
    end
    on_error = events[:on_error]
    if on_error != nil do
      on_error.(:tcp, ipfmt(downstream_peer), reason)
    end
    relay_to(us.socket, <<>>)
  end

  defp handle_receive({:tcp_closed, socket}, _ds = %{socket: socket}, us, proxy_id, events, global_events) do
    # Logger.info "Downstream socket closed"
    relay_to(us.socket, <<>>)
    on_global_disconnect = global_events[:on_disconnect]
    if on_global_disconnect != nil do
      on_global_disconnect.(:tcp, unparse_id(proxy_id))
    end
    on_disconnect = events[:on_disconnect]
    if on_disconnect != nil do
      on_disconnect.(:tcp)
    end
    :gen_tcp.close(us.socket)
    # Logger.info "Total bytes >#{ds.amount} <#{us.amount}"
  end

  defp handle_receive({:tcp, socket, data}, ds, us = %{socket: socket}, proxy_id, events, global_events) do
    {:ok, downstream_peer} = :inet.peername(ds.socket)
    # {:ok, upstream_peer} = :inet.peername(us.socket)
    # Logger.info "TCP data: #{ipfmt(downstream_peer)} < #{ipfmt(upstream_peer)}\n#{data}"
    on_global_server_message = global_events[:on_server_message]
    if on_global_server_message != nil do
      on_global_server_message.(:tcp, ipfmt(downstream_peer), unparse_id(proxy_id), data)
    end
    on_server_message = events[:on_server_message]
    if on_server_message != nil do
      on_server_message.(:tcp, ipfmt(us.peer), data)
    end
    {:ok, count} = relay_to(ds.socket, data)
    proxy_loop(ds, %{us | amount: us.amount + count}, proxy_id, events, global_events)
  end

  defp handle_receive({:tcp_error, socket, reason}, ds, %{socket: socket}, _proxy_id, _events, _global_events) do
    Logger.info "tcp_error upstream #{reason}"
    relay_to(ds.socket, <<>>)
  end

  defp handle_receive({:tcp_closed, socket}, ds, _us = %{socket: socket}, _proxy_id, _events, _global_events) do
    # Logger.info "Upstream socket closed"
    relay_to(ds.socket, <<>>)
    :gen_tcp.close(ds.socket)
    # Logger.info "Total bytes >#{ds.amount} <#{us.amount}"
  end

  defp handle_receive(msg, ds, us, proxy_id, events, global_events) do
    Logger.error "Invalid message:"
    IO.inspect msg
    proxy_loop(ds, us, proxy_id, events, global_events)
  end

  def relay_to(socket, data) do
    :ok = :gen_tcp.send(socket, data)
    {:ok, byte_size(data)}
  end
end
