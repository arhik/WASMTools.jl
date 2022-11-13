using GPUCompiler
using LLVM
using Serialization

module WasmRuntime
	signal_exception() = return
	malloc(sz) = C_NULL
	report_oom(sz) = return
	report_exception(ex) = return
	report_exception_name(ex) = return
	report_exception_frame(idx, func, file, line) = return
end

struct WasmCompilerParams <: AbstractCompilerParams end
struct WasmCompilerTarget <: AbstractCompilerTarget end

GPUCompiler.llvm_triple(target::WasmCompilerTarget) = "wasm32-unknown-unknown"
GPUCompiler.llvm_machine(target::WasmCompilerTarget) = "wasm32"
GPUCompiler.llvm_datalayout(target::WasmCompilerTarget) = "e-m:e-p:32:32-i64:64-n32:64-S128"

GPUCompiler.runtime_slug(job::GPUCompiler.CompilerJob{WasmCompilerTarget}) = "wasm32"

function GPUCompiler.llvm_machine(target::WasmCompilerTarget)
    triple = GPUCompiler.llvm_triple(target)

    t = LLVM.Target(triple=triple)

    tm = LLVM.TargetMachine(t, triple)
    GPUCompiler.asm_verbosity!(tm, true)

    return tm
end

GPUCompiler.runtime_module(::CompilerJob{<:Any, WasmCompilerParams}) = Main.WasmRuntime

function testingFunc(b)
	# print("Hello") # TODO this has to be captured and changed into console.log function
	return b*b
end

function constMul(a)
	b = a*2.10
	return testingFunc(b)
end

function wasm_job(@nospecialize(func), @nospecialize(types); kernel::Bool=false, name=GPUCompiler.safe_name(repr(func)), kwargs...)
	source = FunctionSpec(func, Base.to_tuple_type(types), kernel, name)
	target = WasmCompilerTarget()
	params = WasmCompilerParams()
	job = CompilerJob(target, source, params)
	(job, kwargs)
end

function generate_wasm(f, tt; path="./temp", name=GPUCompiler.safe_name(repr(f)), 
		filename=string(name),
		cflags=``,
		kwargs...
	)
	mkpath(path)
	objPath = joinpath(path, "$(filename).o")
	execPath = joinpath(path, "$filename.wasm")
	htmlPath = joinpath(path, "$(filename).html")
	(job, kwargs) = wasm_job(f, tt; kernel=false, name=name, kwargs=kwargs)
	obj, _ = GPUCompiler.codegen(:obj, job; strip=true, only_entry=false, validate=false)

	open(objPath, "w") do io
		write(io, obj)
	end

	run(`wasm-ld --no-entry --export-all -o $(execPath) $objPath`)

	html_ = """
		<!DOCTYPE html>

		<script type="module">
		  async function init() {
		    const { instance } = await WebAssembly.instantiateStreaming(
		      fetch("$(filename).wasm")
		    );
		    console.log(instance.exports.julia_$(filename)(4));
		  }
		  init();
		</script>
	"""
	open(htmlPath, "w") do io
		write(io, html_)
	end

	run(`python -m http.server 8000`)
	
end

if abspath(PROGRAM_FILE) == @__FILE__
	generate_wasm(constMul, (Int32,))
end
