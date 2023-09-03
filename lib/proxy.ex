defmodule Proxy do
  require Logger

  use Application

  @spec start(term, term) :: {:error, term} | {:ok, pid} | {:ok, pid, term}
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    upstreams = Application.get_env(:proxy, :upstreams, [])

    processes = upstreams |> Enum.flat_map(fn upstream ->
      id_tcp = parse_id(upstream[:id], :tcp)
      id_udp = parse_id(upstream[:id], :udp)
      [
        Supervisor.child_spec({Proxy.TCP, parse_upstream(upstream, :tcp)}, id: id_tcp),
        Supervisor.child_spec({Proxy.UDP, parse_upstream(upstream, :udp)}, id: id_udp)
      ]
    end)
    opts = [strategy: :one_for_one, name: Proxy.Supervisor]
    Supervisor.start_link(processes, opts)
  end

  @spec parse_upstream(Keyword.t, atom) :: Keyword.t
  defp parse_upstream(upstream, mode) do
    upstream
    |> Keyword.replace(:id, parse_id(upstream[:id], mode))
    |> Keyword.put(:global_events, Application.get_env(:proxy, :events, []))
  end

  @spec parse_id(atom, atom) :: atom
  defp parse_id(id, mode) do
    id
    |> Atom.to_string()
    |> Kernel.<>("_#{Atom.to_string(mode)}")
    |> String.to_atom()
  end
end
