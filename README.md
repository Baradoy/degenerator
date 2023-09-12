# Degenerator

Generators can be a helpful tool in writing idiomatic elixir code quickly. Why not take things a step further and make a generator for generators?

Degenerator takes a module that you give it and creates a generator for that module.

## Instalation

While this is in ealry stages, this will be available on github:

```elixir
def deps do
  [
    {:degenerator, github: "baradoy/degenerator", only: :dev}
  ]
end
```

Or you can install it through mix archive:

```bash
mix archive.install github baradoy/degenerator
```

## Usage

You can create a generator from an existing module with:
```bash
mix degenerator --module MyProject.MyModule
```

Subsequent runs of `degenerator` will ask if you wish to add the module to an existing generator or create a new generator.

## Roadmap

- A big refactor to organize code and reduce complexity and add tests
- Allow naming the generator for easier reuse / extention of generators.
- Support tests for the module being degenerated
- Supoport conditional sections, i.e. `--no-schema`
- Detect which generator a file or module belongs too.


## Limitations

- The generators that are created rely on Phoenix.Mix as at least a dev dependancy.
- This might not work with umbrella projects in the slightest.

## Bugs

- Does not detect ProjectWeb correctly
