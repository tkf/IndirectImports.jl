module TestIndirectImports

using IndirectImports
using Test
using UUIDs

module Upstream
    # using IndirectImports
    # @indirect function fun end
    using IndirectImports: indirectfunction
    using UUIDs
    const fun = indirectfunction(Base.PkgId(UUID("332e404b-d707-4859-b48f-328b8b3632c0"), "Upstream"), :fun)
end

module Downstream
    using IndirectImports
    @indirect import Upstream="332e404b-d707-4859-b48f-328b8b3632c0"
    Upstream.fun(x) = x + 1
end

@testset "IndirectImports.jl" begin
    @test Upstream.fun(1) == 2
end

end  # module
