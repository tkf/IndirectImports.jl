module IndirectImports

export @indirect

using MacroTools
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

"""
    @indirect import Module=UUID

Define an indirectly imported `Module` in a downstream module.

    @indirect function Module.interface_function(...) ... end

Define a method of an indirectly imported function in a downstream module.

    @indirect function interface_function end

Declare an `interface_function` in the upstream module.  This function can be
used and/or extended in downstream packages (via `@indirect import Module=UUID`)
without loading the package defining `interface_function`.  This works only
at the top-level module.

# Examples

## Step 1: Declare indirect function in an upstream package

There must be a package that "declares" the ownership of an indirect function.
Typically, such function is an interface extended by downstream packages.

To declare a function `fun` in a package `Upstream`,

```julia
module Upstream
    using IndirectImports
    @indirect function fun end
end
```

## Step 2: Add method definition in downstream packages

First, find out the UUID of `Upstream` package by

```julia-repl
julia> using Upstream

julia> Base.PkgId(Upstream)
Upstream [332e404b-d707-4859-b48f-328b8b3632c0]
```

Using this UUID, the `Upstream` package can be indirectly imported and
methods for the indirect function `Upstream.fun` can be defined as follows:

```julia
module Downstream
    using IndirectImports
    @indirect import Upstream="332e404b-d707-4859-b48f-328b8b3632c0"
    @indirect Upstream.fun(x) = x + 1
end
```

"""
macro indirect(expr)
    expr = longdef(unblock(expr))
    if @capture(expr, import name_=uuid_)
        return esc(:(const $name = $(IndirectPackage(UUID(uuid), name))))
    elseif @capture(expr, function name_ end)
        return esc(:(const $name = $(IndirectFunction(__module__, name))))
    elseif isexpr(expr, :function)
        dict = splitdef(expr)
        f = Base.eval(__module__, dict[:name])
        if !(f isa IndirectFunction)
            msg = """
            Function name $(dict[:name]) does not refer to an indirect function.
            See `?@indirect`.
            """
            return :(error($msg))
        end
        dict[:name] = :(::$(typeof(f)))
        return MacroTools.combinedef(dict)
    else
        error("""
        Cannot handle:
        $expr
        """)
    end
end

end # module
