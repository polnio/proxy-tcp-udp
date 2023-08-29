defmodule Proxy do
  require Logger

  use Application

  @spec start(term, term) :: {:error, term} | {:ok, pid} | {:ok, pid, term}
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    upstreams = Application.get_env(:proxy, :upstreams, [])

    processes = upstreams
      |> Enum.map(fn upstream -> [
        {Proxy.TCP, parse_upstream(upstream, :tcp)},
        {Proxy.UDP, parse_upstream(upstream, :udp)}
      ] end)
      |> Enum.flat_map(& &1)
    opts = [strategy: :one_for_one, name: Proxy.Supervisor]
    Supervisor.start_link(processes, opts)
  end

  defp parse_upstream(upstream, mode) do
    {name, head} = List.pop_at(upstream, -1)
    new_name = name
      |> Atom.to_string()
      |> Kernel.<>("_#{Atom.to_string(mode)}")
      |> String.to_atom()

    List.insert_at(head, -1, new_name)
  end
end
