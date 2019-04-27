module TestIndirectImports

using Base: PkgId
using Test
using UUIDs

using IndirectImports
using IndirectImports: IndirectFunction, IndirectPackage, isloaded

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

@testset "Core" begin
    @test Upstream.fun(1) == 2
    @test Upstream.fun === Downstream.Upstream.fun
end

@testset "Accessors" begin
    pkg = Downstream.Upstream
    @test IndirectPackage(pkg.fun) === pkg
    @test nameof(pkg) === :Upstream
    @test nameof(pkg.fun) === :fun
    @test PkgId(Test) === PkgId(IndirectPackage(Test))
end

@testset "Printing" begin
    @test repr(Upstream.fun) == "Upstream.fun"
    @test repr(IndirectPackage(Test).fun) == "Test.fun"

    # `Upstream` is a fake package so it's not loaded:
    pkg = Downstream.Upstream
    @test !isloaded(pkg)
    @test sprint(show, Upstream.fun; context=:color=>true) ==
        "\e[31mUpstream\e[39m.fun"  # `Upstream` in red

    # But `Test` is a genuine so it's loaded:
    @test isloaded(IndirectPackage(Test))
    @test sprint(show, IndirectPackage(Test).fun; context=:color=>true) ==
        "\e[32mTest\e[39m.fun"  # `Test` in green
end

end  # module
