module IndirectImports

export @indirect

using MacroTools
using Pkg: TOML
using UUIDs

struct IndirectFunction{pkg, name}
end

struct IndirectPackage{uuid, pkgname}
end

IndirectPackage(pkg::IndirectPackage) = pkg
IndirectPackage(uuid::UUID, pkgname::Symbol) = IndirectPackage{uuid, pkgname}()
IndirectPackage(pkg::Base.PkgId) = IndirectPackage(pkg.uuid, Symbol(pkg.name))

function IndirectPackage(mod::Module)
    if parentmodule(mod) !== mod
        error("Only the top-level module can be indirectly imported.")
    end
    return IndirectPackage(Base.PkgId(mod))
end

Base.getproperty(pkg::IndirectPackage, name::Symbol) =
    IndirectFunction(pkg, name)

IndirectFunction(pkgish, name::Symbol) =
    IndirectFunction{IndirectPackage(pkgish), name}()


IndirectPackage(::IndirectFunction{pkg}) where pkg = pkg
Base.nameof(::IndirectFunction{_pkg, name}) where {_pkg, name} = name
Base.nameof(::IndirectPackage{_uuid, pkgname}) where {_uuid, pkgname} = pkgname
pkguuid(::IndirectPackage{uuid}) where uuid = uuid
Base.PkgId(pkg::IndirectPackage) = Base.PkgId(pkguuid(pkg), String(nameof(pkg)))

# Base.parentmodule(f::IndirectFunction) =
#     Base.loaded_modules[Base.PkgId(IndirectPackage(f))]

isloaded(pkg::IndirectPackage) = haskey(Base.loaded_modules, Base.PkgId(pkg))

function Base.show(io::IO, f::IndirectFunction)
    # NOTE: BE VERY CAREFUL inside this function.  Throwing an
    # exception inside `show` for `Type` can kill Julia.  Since
    # `IndirectFunction` can be put inside a `Val`, we need to be
    # extra careful.
    # https://github.com/JuliaLang/julia/issues/29428
    try
        show(io, MIME("text/plain"), f)
    catch
        invoke(show, Tuple{IO, Any}, io, f)
    end
    return
end

function Base.show(io::IO, ::MIME"text/plain", f::IndirectFunction)
    pkg = IndirectPackage(f)
    printstyled(io, nameof(pkg);
                color = isloaded(pkg) ? :green : :red)
    print(io, ".")
    print(io, nameof(f))
    return
end

topmodule(m::Module) = parentmodule(m) == m ? m : topmodule(parentmodule(m))

function _uuidfor(downstream::Module, upstream::Symbol)
    root = topmodule(downstream)
    tomlpath = joinpath(dirname(dirname(pathof(root))), "Project.toml")
    if !isfile(tomlpath)
        error("""
        `IndirectImports` needs package `$(nameof(root))` to use `Project.toml`
        file.  `Project.toml` is not found at:
            $tomlpath
        """)
    end
    name = String(upstream)
    pkg = TOML.parsefile(tomlpath)
    found = get(get(pkg, "deps", Dict()), name, false) ||
        get(get(pkg, "extras", Dict()), name, nothing)

    # Just to be extremely careful, editing Project.toml should
    # invalidate the compilation cache since the UUID may be changed
    # or removed:
    include_dependency(tomlpath)

    found !== nothing && return UUID(found)
    error("""
    Package `$upstream` is not listed in `[deps]` or `[extras]` of `Project.toml`
    file for `$(nameof(root))` found at:
        $tomlpath
    If you are developing `$(nameof(root))`, add `$upstream` to the dependency.
    Otherwise, please report this to `$(nameof(root))`'s issue tracker.
    """)
end

_indirectpackagefor(downstream::Module, upstream::Symbol) =
    IndirectPackage(_uuidfor(downstream, upstream), upstream)

function _typeof(f, name)
    @nospecialize f name
    if !(f isa IndirectFunction)
        msg = """
        Function name `$name` does not refer to an indirect function.
        See `?@indirect`.
        """
        return error(msg)
    end
    return typeof(f)
end

"""
    @indirect import Module

Import a module `Module` indirectly.  This defines a constant named
`Module` which acts like the module in a limited way.  Namely,
`Module.f` can be used to extend or call function `f`, provided that
`f` in the actual module `Module` is declared to be an "indirect
function" (see below).

    @indirect import Module: f1, f2, ..., fn

Import "indirect functions" `f1`, `f2`, ..., `fn`.  This defines
constants `f1`, `f2`, ..., and `fn` that are extendable (see below)
and callable.

    @indirect function Module.interface_function(...) ... end

Define a method of an indirectly imported function in a downstream module.

    @indirect function interface_function end

Declare an `interface_function` in the upstream module.  This function can be
used and/or extended in downstream packages (via `@indirect import Module`)
without loading the package defining `interface_function`.  This works only
at the top-level module.

# Examples

Suppose you want extend functions in `Upstream` package in
`Downstream` package without importing it.

## Step 1: Declare indirect functions in the Upstream package

There must be a package that "declares" the ownership of an indirect function.
Typically, such function is an interface extended by downstream packages.

To declare a function `fun` in a package `Upstream` wrap an empty
definition of a function `function fun end` with `@indirect`:

```julia
module Upstream
    using IndirectImports
    @indirect function fun end
end
```

To define a method of an indirect function inside `Upstream`, wrap it
in `@indirect`:

```julia
module Upstream
    using IndirectImports
    @indirect function fun end

    @indirect fun() = 0  # defining a method
end
```

## Step 2: Add the upstream package in the Downstream package

Use Pkg.jl interface as usual to add `Upstream` package as a
dependency of the `Downstream` package; i.e., type `]add Upstream⏎`:

```julia-repl
(Downstream) pkg> add Upstream
```

This puts the entry `Upstream` in `[deps]` of `Project.toml`:

```toml
[deps]
...
Upstream = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
...
```

If it is not ideal to install `Upstream` by default, move it to
`[extras]` section (you may need to create it manually):

```toml
[extras]
Upstream = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

## Step 3: Add method definitions in the Downstream package

Once `Upstream` is registered in `Project.toml`, you can import
`Upstream` and define its functions, provided that they are prefixed
with `@indirect` macro:

```julia
module Downstream
    using IndirectImports
    @indirect import Upstream
    @indirect Upstream.fun(x) = x + 1
    @indirect function Upstream.fun(x, y)
        return x + y
    end
end
```

**Note**: It looks like defining a method works without `@indirect` possibly
due to a "bug" in Julia [^1].  While it is handy to define methods without
`@indirect` for debugging, prototyping, etc., it is a good idea to wrap the
method definition in `@indirect` to be forward compatible with future Julia
versions.

[^1]: Extending a constructor is possible with only using `using`
      <https://github.com/JuliaLang/julia/issues/25744>
"""
macro indirect(expr)
    expr = longdef(unblock(expr))
    if @capture(expr, import name_)
        pkgexpr = :($_indirectpackagefor($__module__, $(QuoteNode(name))))
        return esc(:(const $name = $pkgexpr))
    elseif isexpr(expr, :import) &&
            isexpr(expr.args[1], :(:)) &&
            all(x -> isexpr(x, :.) && length(x.args) == 1, expr.args[1].args)
        # Handling cases like
        #     expr = :(import M: a, b, c)
        # or equivalently
        #     expr = Expr(
        #         :import,
        #         Expr(
        #             :(:),
        #             Expr(:., :M),
        #             Expr(:., :a),
        #             Expr(:., :b),
        #             Expr(:., :c)))
        @assert length(expr.args) == 1
        @assert length(expr.args[1].args) > 1
        name = expr.args[1].args[1].args[1] :: Symbol
        pkgexpr = :($_indirectpackagefor($__module__, $(QuoteNode(name))))
        @gensym pkg
        # Let's not use `pkgexpr` at the right hand side of `const $f = pkg.$f`
        # since it does I/O.
        assignments = :(let $pkg = $pkgexpr; end)
        @assert isexpr(assignments.args[2], :block)
        push!(assignments.args[2].args, __source__)
        for x in expr.args[1].args[2:end]
            f = x.args[1] :: Symbol
            push!(assignments.args[2].args, :(global const $f = $pkg.$f))
        end
        return esc(assignments)
    elseif @capture(expr, function name_ end)
        return esc(:(const $name = $(IndirectFunction(__module__, name))))
    elseif isexpr(expr, :function)
        dict = splitdef(expr)
        dict[:name] = :(::($_typeof($(dict[:name]), $(QuoteNode(dict[:name])))))
        return esc(MacroTools.combinedef(dict))
    else
        msg = """
        Cannot handle:
        $expr
        """
        return :(error($msg))
    end
end

end # module
