import Config

config :proxy,
  upstreams: [
    [4040, "localhost:4000", 2, :proxy1],
    [4041, "localhost:4001", 2, :proxy2],
  ]

