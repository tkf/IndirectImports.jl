module _TestIndirectImportsUpstream

using IndirectImports
@indirect function fun end

@indirect function fun(x::Complex)
    return x + 1 + 1im
end

end # module
