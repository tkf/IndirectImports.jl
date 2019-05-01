module _TestIndirectImportsUpstream

using IndirectImports
@indirect function fun end

@indirect function fun(x::Complex)
    return x + 1 + 1im
end

@indirect function op end

function reduceop(config, acc, xs)
    for x in xs
        acc = op(config, acc, x)
    end
    return acc
end

end # module
