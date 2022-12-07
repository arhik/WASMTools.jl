using WASMTools
using Documenter

DocMeta.setdocmeta!(WASMTools, :DocTestSetup, :(using WASMTools); recursive=true)

makedocs(;
    modules=[WASMTools],
    authors="arhik <arhik23@gmail.com>",
    repo="https://github.com/arhik/WASMTools.jl/blob/{commit}{path}#{line}",
    sitename="WASMTools.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://arhik.github.io/WASMTools.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/arhik/WASMTools.jl",
    devbranch="main",
)
