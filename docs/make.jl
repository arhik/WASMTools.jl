using WasmTools
using Documenter

DocMeta.setdocmeta!(WasmTools, :DocTestSetup, :(using WasmTools); recursive=true)

makedocs(;
    modules=[WasmTools],
    authors="arhik <arhik23@gmail.com>",
    repo="https://github.com/arhik/WasmTools.jl/blob/{commit}{path}#{line}",
    sitename="WasmTools.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://arhik.github.io/WasmTools.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/arhik/WasmTools.jl",
    devbranch="main",
)
