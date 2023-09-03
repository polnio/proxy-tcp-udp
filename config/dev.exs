import Config

proxy1 = [
  id: :proxy1,
  listen_port: 4040,
  remote_host: "localhost:4000",
  max_clients: 2,
  events: [
    on_connect: fn protocol, client ->
      IO.puts "protocol: #{protocol}, client: #{client}"
    end,
    on_client_message: fn protocol, client, message ->
      IO.puts "protocol: #{protocol}, client: #{client}, message: #{String.trim(message)}"
    end
  ],
  whitelist: [
    ~r/127\.0\.0\.[1-3]/,
  ]
]

proxy2 = [
  id: :proxy2,
  listen_port: 4041,
  remote_host: "localhost:4001",
  max_clients: 2,
  blacklist: ["127.*"]
]

global_events = [
  on_connect: fn protocol, client, upstream_id ->
    IO.puts "protocol: #{protocol}, client: #{client}, upstream_id: #{upstream_id}"
  end,
  on_error: fn protocol, upstream_id, reason ->
    IO.puts "protocol: #{protocol}, upstream_id: #{upstream_id}, reason: #{reason}"
  end
]

config :proxy,
  upstreams: [ proxy1, proxy2 ],
  events: global_events,
  blacklist: ["127.0.0.1:1000", "localhost:1000"]
