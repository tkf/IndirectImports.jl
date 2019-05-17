module _TestIndirectImportsPing

using IndirectImports
@indirect import _TestIndirectImportsPong: pong

@indirect function ping end
@indirect pong(x::Integer) = x < 2 ? x : ping(x - 1) + pong(x - 2)

end # module
