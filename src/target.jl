# using GPUCompiler: process_entry!, can_throw, lower_throw!, add_lowering_passes!,
	# uses_julia_runtime, load_runtime, defs, decls, link_libraries!, link_library!,
	# finish_module!, finish_ir!

using LLVM
using LLVM: Context
using Serialization
using Clang_jll
using StaticTools
using GPUCompiler
using GPUCompiler: safe_name, codegen
using WasmTools

include(joinpath(pathof(WasmTools) |> dirname, "jsrender.jl"))


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

GPUCompiler.runtime_slug(job::CompilerJob{WasmCompilerTarget}) = "wasm32-unknown-wasi"

function GPUCompiler.llvm_machine(target::WasmCompilerTarget)
    triple = GPUCompiler.llvm_triple(target)

    t = LLVM.Target(triple=triple)

    tm = LLVM.TargetMachine(t, triple)
    asm_verbosity!(tm, true)

    return tm
end

GPUCompiler.runtime_module(::CompilerJob{<:Any, WasmCompilerParams}) = Main.WasmRuntime

function testingFunc(b)
	# print("Hello") # TODO this has to be captured and changed into console.log function
	return b*b
end



function constMul(a)
	b = a*2.10
	# JS.consoleLog(b)
	return testingFunc(b)
end

function getVal(key)::StaticString
	d = Dict{Int32, StaticString}()
	d[1] = c"One"
	d[2] = c"Two"
	d[3] = c"Three"
	get(d, key, c"None")
end

using StaticTools

function GPUCompiler.process_module!(@nospecialize(job::CompilerJob{WasmCompilerTarget}), mod::LLVM.Module)
    ctx = context(mod)

    # calling convention
    for f in functions(mod)
        # JuliaGPU/GPUCompiler.jl#97
        #callconv!(f, LLVM.API.LLVMPTXDeviceCallConv)
        @info f
    end
end


function print_args(argc::Int32, argv::Ptr{Ptr{UInt8}})
    # for i=1:argc
        # pᵢ = unsafe_load(argv, i) # Get pointer
        # strᵢ = MallocString(pᵢ) # Can wrap to get high-level interface
        # println(strᵢ)
    # end
    return Int32(0)
end

function wasm_job(@nospecialize(func), @nospecialize(types); kernel::Bool=false, name=safe_name(repr(func)), kwargs...)
	source = FunctionSpec(func, Base.to_tuple_type(types), kernel, name)
	target = WasmCompilerTarget()
	params = WasmCompilerParams()
	job = CompilerJob(target, source, params)
	(job, kwargs)
end


function generate_wasm(f, tt; wasi=false, path="./temp", name=safe_name(repr(f)), 
		filename=string(name),
		cflags=`-nostartfiles -nostdlib -Wl,--export-all -Wl,--no-entry -Wl,--allow-undefineds`,
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

	cc = nothing
	if Sys.isapple()
		local cc
		cc = "$WASI_Clang"
		# entry = "$name"
		# run(`$cc --target=wasm32-unknown-wasi -v -e $entry $cflags $objPath -o $execPath`)
	end


	if wasi==true
		# wrapper_path = joinpath(path, "wrapper.c")
		# wrap_obj = joinpath(path, "wrapper.o")
		# f = open(wrapper_path, "w")
		# print(f, """int julia_$name(int argc, char** argv);
		# void* __stack_chk_guard = (void*) $(rand(UInt) >> 1);
		# __stack_chk_fail (void)
		# {
		  # // printf("stack smashing detected");
		# }
# 
# 
		# int main(int argc, char** argv)
		# {
		    # julia_$name(argc, argv);
		    # return 0;
		# }""")
		# close(f)

		# run(`$cc --target=wasm32-unknown-wasi -e $filename $wrapper_path -c $cflags -L$(WASI_SYSROOT)/lib/wasm32-wasi
			 # $objPath -o $wrap_obj -lc $(WASI_ClangRT) `)
 		run(`wasm-ld -m wasm32 --export-all -L$(WASI_SYSROOT)/lib/wasm32-wasi \
		     $(WASI_SYSROOT)/lib/wasm32-wasi/crt1.o $objPath \#$wrap_obj \
	      	-lc $(WASI_ClangRT) -o $(execPath)`)

	else
    	run(`wasm-ld --no-entry --export-all --allow-undefined $objPath -o $(execPath)`)
    end

	html_ = render(filename)
	
	open(htmlPath, "w") do io
		write(io, html_)
	end

	run(`python -m http.server 8000`)
	
end

if abspath(PROGRAM_FILE) == @__FILE__
	generate_wasm(constMul, (Int32,); wasi=false)
end
