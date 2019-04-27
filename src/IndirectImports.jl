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
