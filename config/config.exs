import Config

config :proxy,
  upstreams: [
    [4040, "localhost:4000", 2, :proxy],
  ]

