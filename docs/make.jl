using Documenter, IndirectImports

makedocs(;
    modules=[IndirectImports],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/tkf/IndirectImports.jl/blob/{commit}{path}#L{line}",
    sitename="IndirectImports.jl",
    authors="Takafumi Arakaki",
    assets=[],
)

deploydocs(;
    repo="github.com/tkf/IndirectImports.jl",
)
