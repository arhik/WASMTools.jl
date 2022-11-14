using GPUCompiler
using LLVM
using Serialization

HOMEPATH=ENV["HOME"]
WASI_SYSROOT="/Users/arhik/November2022/wasi-sdk/dist/wasi-sysroot"
WASI_SDK = "/Users/arhik/November2022/wasi-sdk/dist/wasi-sdk-16.5ga0a342ac182c/lib/clang/14.0.4"

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

GPUCompiler.llvm_triple(target::WasmCompilerTarget) = "wasm32-unknown-wasi"
GPUCompiler.llvm_datalayout(target::WasmCompilerTarget) = "e-m:e-p:32:32-i64:64-n32:64-S128"

GPUCompiler.runtime_slug(job::GPUCompiler.CompilerJob{WasmCompilerTarget}) = "wasm32-unknown-wasi"

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


function getVal(key)
	d = Dict{Int32, String}()
	d[1] = "One"
	d[2] = "Two"
	d[3] = "Three"
	get(d, key, "None")
end

function main(argc::Int, argv::Ptr{Ptr{UInt8}})
	key = argparse(Int64, argv, 2)
	if key > 4
		return -1
	else
		getVal(key)
	end
end

function wasm_job(@nospecialize(func), @nospecialize(types); kernel::Bool=false, name=GPUCompiler.safe_name(repr(func)), kwargs...)
	source = FunctionSpec(func, Base.to_tuple_type(types), kernel, name)
	target = WasmCompilerTarget()
	params = WasmCompilerParams()
	job = CompilerJob(target, source, params)
	(job, kwargs)
end

function generate_wasm(f, tt; wasi=false, path="./temp", name=GPUCompiler.safe_name(repr(f)), 
		filename=string(name),
		cflags=`--nostdlib`,
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

	if wasi==true
		run(`wasm-ld -m wasm32 --export-all -L$WASI_SYSROOT/lib/wasm32-wasi
		     $WASI_SYSROOT/lib/wasm32-wasi/crt1.o $objPath -o $(execPath)
	      	-lc $WASI_SDK/lib/wasi/libclang_rt.builtins-wasm32.a `)
	else
    	run(`wasm-ld --no-entry --export-all $objPath -o $(execPath)`)
    end

	html_ = """
		<!DOCTYPE html>

		<script type="module">
		  async function init() {
		    const { instance } = await WebAssembly.instantiateStreaming(
		      fetch("$(filename).wasm")
		    );
		    console.log(instance.exports.$(filename)(4));
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
	generate_wasm(main, (Int, Ptr{Ptr{UInt8}}))
end
