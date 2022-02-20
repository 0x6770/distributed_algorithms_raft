# Raft

**TODO: Add description**

## Ideas

use SVG to visualise communication among processes? Time as Y axis, different colors for different roles.

```
1--2--3--4--5
|  |  |--+->|
|->|  |<-+--|
|<-|  |  |  |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `raft` to your list of dependencies in `mix.exs`:

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `raft` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:raft, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/raft>.
