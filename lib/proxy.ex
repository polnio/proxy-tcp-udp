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
    |> Keyword.replace(:whitelist, parse_filter_list(upstream[:whitelist]))
    |> Keyword.replace(:blacklist, parse_filter_list(upstream[:blacklist]))
    |> Keyword.put(:global_events, Application.get_env(:proxy, :events, []))
    |> Keyword.put(:global_whitelist, parse_filter_list(Application.get_env(:proxy, :whitelist, nil)))
    |> Keyword.put(:global_blacklist, parse_filter_list(Application.get_env(:proxy, :blacklist, nil)))
  end

  @spec parse_id(atom, atom) :: atom
  defp parse_id(id, mode) do
    id
    |> Atom.to_string()
    |> Kernel.<>("_#{Atom.to_string(mode)}")
    |> String.to_atom()
  end

  @spec parse_filter_list(nil) :: nil
  defp parse_filter_list(nil), do: nil

  @spec parse_filter_list(list) :: list
  defp parse_filter_list(list) do
    list |> Enum.map(fn filter -> parse_filter(filter) end)
  end

  @spec parse_filter(String.t) :: Regex.t
  defp parse_filter(filter) when is_binary(filter) do
    if String.contains?(filter, ":"),
      do: text_to_regex(filter),
      else: text_to_regex(filter <> "(?:\:.*)?")
  end

  @spec parse_filter(Regex.t) :: Regex.t
  defp parse_filter(filter), do: filter

  @spec text_to_regex(String.t) :: Regex.t
  defp text_to_regex(text) do
    text
    |> String.trim()
    |> String.replace(".", "\\.")
    |> String.replace("*", ".*")
    |> Regex.compile!()
  end
end
