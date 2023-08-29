FROM elixir:1.15.0
WORKDIR /app
ENV MIX_ENV=prod
COPY . .
RUN mix deps.get --only prod
RUN mix compile
CMD mix run --no-halt
