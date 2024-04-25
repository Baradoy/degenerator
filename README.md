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
mix degenerator --module MyProject.MyModule --generator degenerator.gen.my_generator
```

Subsequent runs of `degenerator` will add to the new module template to the existing generator.

## Roadmap

- A big refactor to organize code and reduce complexity and add tests
- Support module names with prefix or suffixes such as `MyProjectWeb.MyModuleController,
- Supoport conditional sections, i.e. `--no-schema`


## Limitations

- The generators that are created rely on Phoenix.Mix as at least a dev dependancy.
- This might not work with umbrella projects in the slightest.

## Bugs

- Does not detect ProjectWeb correctly
