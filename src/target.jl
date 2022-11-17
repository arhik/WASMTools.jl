using LLVM
using LLVM: Context
using Serialization
using Clang_jll
using StaticTools
using GPUCompiler
using GPUCompiler: safe_name, codegen, generate_wasm
using WasmTools

include(joinpath(pathof(WasmTools) |> dirname, "jsrender.jl"))

@noinline consoleLog(a) = a

function testingFunc(b)
	return b*b
end

function constMul(a)
	b = a*2.10
	consoleLog(b)
	return testingFunc(b)
end

if abspath(PROGRAM_FILE) == @__FILE__
	generate_wasm(constMul, (Int32,); wasi=false)
end

generate_wasm(constMul, (Int32,); wasi=false)
