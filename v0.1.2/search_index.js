var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "#IndirectImports.IndirectImports",
    "page": "Home",
    "title": "IndirectImports.IndirectImports",
    "category": "module",
    "text": "IndirectImports\n\n(Image: Stable) (Image: Dev) (Image: GitHub commits since tagged version) (Image: Build Status) (Image: Codecov) (Image: Coveralls)\n\nIndirectImports.jl lets Julia packages call and extend (a special type of) functions without importing the package defining them.  This is useful for managing optional dependencies.\n\nCompared to Requires.jl, IndirectImports.jl\'s approach is more static and there is no run-time eval hence more compiler friendly. However, unlike Requires.jl, both upstream and downstream packages need to rely on IndirectImports.jl API.\nCompared to \"XBase.jl\" approach, IndirectImports.jl is more flexible in the sense that you don\'t need to create an extra package and keep it in sync with the \"implementation\" package(s).  However, unlike \"XBase.jl\" approach, IndirectImports.jl is usable only for functions, not for types.\n\nExample\n\n# MyPlot/src/MyPlot.jl\nmodule MyPlot\n    using IndirectImports\n\n    @indirect function plot end  # declare an \"indirect function\"\n\n    @indirect function plot(x)  # optional\n        # generic implementation\n    end\nend\n\n# MyDataFrames/src/MyDataFrames.jl\nmodule MyDataFrames\n    using IndirectImports\n\n    @indirect import MyPlot  # this does not actually load MyPlot.jl\n\n    # you can extend indirect functions\n    @indirect function MyPlot.plot(df::MyDataFrame)\n        # you can call indirect functions\n        MyPlot.plot(df.columns)\n    end\nend\n\nYou can install it with ]add IndirectImports.  See more details in the documentation.\n\n\n\n\n\n"
},

{
    "location": "#IndirectImports.@indirect-Tuple{Any}",
    "page": "Home",
    "title": "IndirectImports.@indirect",
    "category": "macro",
    "text": "@indirect function interface_function end\n\nDeclare an interface_function in the upstream module (i.e., the module \"owning\" the function interface_function).  This function can be used and/or extended in downstream packages (via @indirect import Module) without loading the package defining interface_function. This from of @indirect works only at the top-level module.\n\n@indirect function interface_function(...) ... end\n\nDefine a method of interface_function in the upstream module.  The function interface_function must be declared first by the above syntax.\n\nThis can also be used in downstream modules provided that interface_function is imported by @indirect import Module: interface_function (see below).\n\n@indirect import Module\n\nImport an upstream module Module indirectly.  This defines a constant named Module which acts like the module in a limited way. Namely, Module.f can be used to extend or call function f, provided that f in the actual module Module is declared to be an \"indirect function\" (see above).\n\n@indirect import Module: f1, f2, ..., fn\n\nImport \"indirect functions\" f1, f2, ..., fn.  This defines constants f1, f2, ..., and fn that are extendable (see above) and callable.\n\n@indirect function Module.interface_function(...) ... end\n\nDefine a method of an indirectly imported function.  This form can be usable only in downstream modules where Module is imported via @indirect import Module.\n\nExamples\n\nSuppose you want extend functions in Upstream package in Downstream package without importing it.\n\nStep 1: Declare indirect functions in the Upstream package\n\nThere must be a package that \"declares\" the ownership of an indirect function. Typically, such function is an interface extended by downstream packages.\n\nTo declare a function fun in a package Upstream wrap an empty definition of a function function fun end with @indirect:\n\nmodule Upstream\n    using IndirectImports\n    @indirect function fun end\nend\n\nTo define a method of an indirect function inside Upstream, wrap it in @indirect:\n\nmodule Upstream\n    using IndirectImports\n    @indirect function fun end\n\n    @indirect fun() = 0  # defining a method\nend\n\nStep 2: Add the upstream package in the Downstream package\n\nUse Pkg.jl interface as usual to add Upstream package as a dependency of the Downstream package; i.e., type ]add Upstream⏎:\n\n(Downstream) pkg> add Upstream\n\nThis puts the entry Upstream in [deps] of Project.toml:\n\n[deps]\n...\nUpstream = \"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\"\n...\n\nIf it is not ideal to install Upstream by default, move it to [extras] section (you may need to create it manually):\n\n[extras]\nUpstream = \"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\"\n\nStep 3: Add method definitions in the Downstream package\n\nOnce Upstream is registered in Project.toml, you can import Upstream and define its functions, provided that they are prefixed with @indirect macro:\n\nmodule Downstream\n    using IndirectImports\n    @indirect import Upstream\n    @indirect Upstream.fun(x) = x + 1\n    @indirect function Upstream.fun(x, y)\n        return x + y\n    end\nend\n\nNote: It looks like defining a method works without @indirect possibly due to a \"bug\" in Julia [1].  While it is handy to define methods without @indirect for debugging, prototyping, etc., it is a good idea to wrap the method definition in @indirect to be forward compatible with future Julia versions.\n\n[1]: Extending a constructor is possible with only using using   https://github.com/JuliaLang/julia/issues/25744\n\nLimitation\n\nFunction declarations can be documented as usual\n\n\"\"\"\nDocstring for `fun`.\n\"\"\"\n@indirect function fun end\n\nbut it does not work with the method definitions:\n\n# Commenting out the following errors:\n\n# \"\"\"\n# Docstring for `fun`.\n# \"\"\"\n@indirect function fun()\nend\n\nTo add a docstring to indirect functions in downstream packages, one workaround is to use \"off-site\" docstring:\n\n@indirect function fun() ... end\n\n\"\"\"\nDocstring for `fun`.\n\"\"\"\nfun\n\nHow it works\n\nSee https://discourse.julialang.org/t/23526/38 for a simple self-contained code to understanding the idea.  Note that the actual implementation is slightly different.\n\n\n\n\n\n"
},

{
    "location": "#IndirectImports.jl-1",
    "page": "Home",
    "title": "IndirectImports.jl",
    "category": "section",
    "text": "Modules = [IndirectImports]\nPrivate = false"
},

{
    "location": "internals/#",
    "page": "Internals",
    "title": "Internals",
    "category": "page",
    "text": ""
},

{
    "location": "internals/#IndirectImports.IndirectFunction",
    "page": "Internals",
    "title": "IndirectImports.IndirectFunction",
    "category": "type",
    "text": "IndirectFunction(pkgish::Union{Module,PkgId,IndirectPackage}, name::Symbol)\n\nExamples\n\njulia> using IndirectImports: IndirectFunction, IndirectPackage\n\njulia> using UUIDs\n\njulia> Dummy = IndirectPackage(\n           UUID(\"f315346e-6bf8-11e9-0cba-43b0a27f0f55\"),\n           :Dummy);\n\njulia> Dummy.fun\nDummy.fun\n\njulia> Dummy.fun isa IndirectFunction\ntrue\n\njulia> Dummy.fun ===\n           IndirectFunction(Dummy, :fun) ===\n           IndirectFunction(\n               Base.PkgId(\n                   UUID(\"f315346e-6bf8-11e9-0cba-43b0a27f0f55\"),\n                   \"Dummy\"),\n               :fun)\ntrue\n\njulia> IndirectPackage(Dummy.fun) === Dummy\ntrue\n\n\n\n\n\n"
},

{
    "location": "internals/#IndirectImports.IndirectPackage",
    "page": "Internals",
    "title": "IndirectImports.IndirectPackage",
    "category": "type",
    "text": "IndirectPackage(pkgish::Union{Module,PkgId,IndirectPackage})\nIndirectPackage(uuid::UUID, pkgname::Symbol)\n\nExamples\n\njulia> using IndirectImports: IndirectPackage\n\njulia> using Test\n\njulia> IndirectPackage(Test) ===\n           IndirectPackage(IndirectPackage(Base.PkgId(Test))) ===\n           IndirectPackage(Base.PkgId(Test)) ===\n           IndirectPackage(\n               Base.UUID(\"8dfed614-e22c-5e08-85e1-65c5234f0b40\"),\n               :Test)\ntrue\n\n\n\n\n\n"
},

{
    "location": "internals/#Internals-1",
    "page": "Internals",
    "title": "Internals",
    "category": "section",
    "text": "Modules = [IndirectImports]\nPublic = false"
},

]}
