defmodule FilterListUtil do
  @spec whitelist_check(String.t, nil) :: boolean
  def whitelist_check(_client, nil), do: true
  @spec whitelist_check(String.t, list) :: boolean
  def whitelist_check(client, whitelist) do
    whitelist |> Enum.any?(&Regex.match?(&1, client))
  end

  @spec blacklist_check(String.t, nil) :: boolean
  def blacklist_check(_client, nil), do: true
  @spec blacklist_check(String.t, list) :: boolean
  def blacklist_check(client, blacklist) do
    blacklist
    |> Enum.any?(&Regex.match?(&1, client))
    |> Kernel.!
  end

  @spec list_check(String.t, list | nil, list | nil) :: boolean
  def list_check(client, whitelist, blacklist) do
    whitelist_check(client, whitelist) && blacklist_check(client, blacklist)
  end
end
