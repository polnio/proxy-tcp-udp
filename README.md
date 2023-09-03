# Proxy

## Configuration
You can configure the proxy in the `config/prod.exs` file.
You can check the `config/dev.exs` file as an example.
The available options are:

- `:upstreams`: a list of upstreams (array of keyword)
  - items:
    - `:id`: The id of the upstream. It must be unique. (atom)
    - `:listen_port`: The port to listen on (integer)
    - `:remote_host`: The remote host (string, in format `host:port`)
    - `:max_clients`: The maximum number of clients (integer),
    - `:events`: The events to listen to (keyword, optionnal),
      - `:on_connect`: Called when a client connects (function: \[protocol, client])
      - `:on_disconnect`: Called when a client disconnects (function: \[protocol])
      - `:on_client_message`: Called when a client sends a message (function: \[protocol, client, message])
      - `:on_server_message`: Called when a server sends a message (function, \[protocol, client, message])
      - `:on_error`: Called when an error occurs (function: \[protocol, reason])
- `:events`: The events to listen to (keyword, optionnal),
  - `:on_connect`: Called when a client connects (function: \[protocol, client, upstream_id])
  - `:on_disconnect`: Called when a client disconnects (function: \[protocol, upstream_id])
  - `:on_client_message`: Called when a client sends a message (function: \[protocol, client, upstream_id, message])
  - `:on_server_message`: Called when a server sends a message (function, \[protocol, client, upstream_id, message])
  - `:on_error`: Called when an error occurs (function: \[protocol, upstream_id, reason])

## Starting the proxy

### Elixir way
```sh
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix run --no-halt
```
Or
```sh
export MIX_ENV=prod
mix deps.get --only prod
mix run --no-halt
```

### Docker way
```sh
docker-compose up
```
