module _TestIndirectImportsPong

using IndirectImports
@indirect import _TestIndirectImportsPing: ping

@indirect function pong end
@indirect ping(x::Integer) = x < 2 ? x : pong(x - 1) + ping(x - 2)

end # module
