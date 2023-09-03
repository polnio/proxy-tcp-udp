defmodule AddressUtil do
  def split_host_and_port(input) do
    parts = String.split(input, ":")
    {Enum.at(parts, 0), Enum.at(parts, 1) || "80"}
  end

  def ipfmt({addr, port}) do
    parts = [ip_string(addr), port]
    parts |> Enum.join(":")
  end

  def join_address(host, port) do
    "#{host}:#{port}"
  end

  @spec unparse_id(atom) :: atom
  def unparse_id(id) do
    id
    |> Atom.to_string()
    |> String.replace(~r/_[^_]+$/, "")
    |> String.to_atom()
  end

  defp ip_string(addr) do
    parts = Tuple.to_list(addr)
    parts |> Enum.join(".")
  end
end
