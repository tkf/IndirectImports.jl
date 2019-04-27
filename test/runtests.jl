module TestIndirectImports

using Base: PkgId
using Pkg
using Test
using UUIDs

using IndirectImports
using IndirectImports: IndirectFunction, IndirectPackage, isloaded

module Upstream
    using IndirectImports: IndirectFunction
    using UUIDs
    const fun = IndirectFunction(Base.PkgId(UUID("332e404b-d707-4859-b48f-328b8b3632c0"), "Upstream"), :fun)
end

module Downstream
    using IndirectImports
    @indirect import Upstream="332e404b-d707-4859-b48f-328b8b3632c0"
    @indirect Upstream.fun(x) = x + 1

    @indirect import _TestIndirectImportsUpstream="20db8cd4-68a4-11e9-2de0-29cd367489cf"
    @indirect _TestIndirectImportsUpstream.fun(x) = x + 2
end

if Base.locate_package(PkgId(UUID("20db8cd4-68a4-11e9-2de0-29cd367489cf"),
                             "_TestIndirectImportsUpstream")) === nothing
    Pkg.develop(PackageSpec(
        name = "_TestIndirectImportsUpstream",
        path = joinpath(@__DIR__, "_TestIndirectImportsUpstream"),
    ))
end
using _TestIndirectImportsUpstream

@testset "Core" begin
    @test Upstream.fun(1) == 2
    @test Upstream.fun === Downstream.Upstream.fun

    @test _TestIndirectImportsUpstream.fun(1) == 3
    @test _TestIndirectImportsUpstream.fun ===
        Downstream._TestIndirectImportsUpstream.fun
end

@testset "Accessors" begin
    pkg = Downstream.Upstream
    @test IndirectPackage(pkg.fun) === pkg
    @test nameof(pkg) === :Upstream
    @test nameof(pkg.fun) === :fun
    @test PkgId(Test) === PkgId(IndirectPackage(Test))
end

struct Voldemort end
Base.nameof(::Voldemort) = error("must not be named")
IndirectImports.IndirectPackage(pkg::Voldemort) = pkg

@testset "Printing" begin
    @test repr(Upstream.fun) == "Upstream.fun"
    @test repr(IndirectPackage(Test).fun) == "Test.fun"

    @testset "2-arg `show` MUST NOT fail" begin
        f = IndirectFunction(Voldemort(), :fun)
        @debug "repr(f) = $(repr(f))"
        @test match(r".*\bIndirectFunction\{.*Voldemort\(\), *:fun\}",
                    repr(f)) !== nothing
    end

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
