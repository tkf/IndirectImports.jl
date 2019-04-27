module IndirectImports

export @indirect

using MacroTools
using UUIDs

struct IndirectFunction{pkg, name}
end

struct IndirectPackage{uuid, pkgname}
end

IndirectPackage(uuid::UUID, pkgname::Symbol) = IndirectPackage{uuid, pkgname}()
IndirectPackage(pkg::Base.PkgId) = IndirectPackage(pkg.uuid, Symbol(pkg.name))

function IndirectPackage(mod::Module)
    if parentmodule(mod) !== mod
        error("Only the top-level module can be indirectly imported.")
    end
    return IndirectPackage(Base.PkgId(mod))
end

Base.getproperty(pkg::IndirectPackage, name::Symbol) =
    IndirectFunction{pkg, name}

function indirectfunction(pkgish, name::Symbol)
    return IndirectFunction{IndirectPackage(pkgish), name}
end

IndirectPackage(::Type{<:IndirectFunction{pkg}}) where pkg = pkg
Base.nameof(::Type{IndirectFunction{_pkg, name}}) where {_pkg, name} = name
Base.nameof(::IndirectPackage{_uuid, pkgname}) where {_uuid, pkgname} = pkgname
pkguuid(::IndirectPackage{uuid}) where uuid = uuid
Base.PkgId(pkg::IndirectPackage) = Base.PkgId(pkguuid(pkg), String(nameof(pkg)))

# Base.parentmodule(f::Type{<:IndirectFunction}) =
#     Base.loaded_modules[Base.PkgId(IndirectPackage(f))]

isloaded(pkg::IndirectPackage) = haskey(Base.loaded_modules, Base.PkgId(pkg))

function Base.show(io::IO, f::Type{<:IndirectFunction})
    # NOTE: BE VERY CAREFUL inside this function.  Throwing an
    # exception inside this function can kill Julia.
    # https://github.com/JuliaLang/julia/issues/29428
    try
        show(io, MIME("text/plain"), f)
    catch
        invoke(show, Tuple{IO, Type}, io, f)
    end
    return
end

function Base.show(io::IO, ::MIME"text/plain", f::Type{<:IndirectFunction})
    pkg = IndirectPackage(f)
    printstyled(io, nameof(pkg);
                color = isloaded(pkg) ? :green : :red)
    print(io, ".")
    print(io, nameof(f))
    return
end

"""
    @indirect import Module=UUID

Define an indirectly imported `Module`.

    @indirect function interface_function end

Define an `interface_function` which can be used and extended in downstream
packages (via `@indirect import Module=UUID`) without loading the package
defining `interface_function`.
"""
macro indirect(expr)
    if @capture(expr, import name_=uuid_)
        return esc(:(const $name = $(IndirectPackage(UUID(uuid), name))))
    elseif @capture(expr, function name_ end)
        return esc(:(const $name = $(indirectfunction(__module__, name))))
    else
        error("""
        Cannot handle:
        $expr
        """)
    end
end

end # module