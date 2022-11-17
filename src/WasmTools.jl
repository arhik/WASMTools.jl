module WasmTools

using LLVM
using LLVM.Interop

using ExprTools: splitdef, combinedef
using TimerOutputs
using Logging
using UUIDs
using Libdl

# Write your package code here.
include("runtime.jl")
include("target.jl")
include("jsrender.jl")

end
