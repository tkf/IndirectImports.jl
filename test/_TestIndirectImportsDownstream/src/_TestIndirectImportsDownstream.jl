module _TestIndirectImportsDownstream

using IndirectImports

@indirect import _TestIndirectImportsUpstream
@indirect _TestIndirectImportsUpstream.fun(x) = x + 1

dispatch(::typeof(_TestIndirectImportsUpstream.fun)) = :fun
dispatch(::typeof(_TestIndirectImportsUpstream.fun2)) = :fun2

# Test other importing syntax:
@indirect import _TestIndirectImportsUpstream: f1
@indirect import _TestIndirectImportsUpstream: f2, f3
@indirect import _TestIndirectImportsUpstream: f4, f5, f6

end # module
