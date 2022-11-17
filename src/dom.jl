using LLVM
using LLVM.Interop

ctx=Context()
module_ = LLVM.Module("sum"; ctx)

param_types = [LLVM.Int32Type(ctx), LLVM.Int32Type(ctx),]
ret_type = LLVM.Int32Type(ctx)
fun_type = LLVM.FunctionType(ret_type, param_types)
sum = LLVM.Function(module_, "sum", fun_type)

builder = LLVM.Builder(ctx)

bb = LLVM.BasicBlock(sum, "sum"; ctx)
position!(builder, bb)

tmp = add!(builder, parameters(sum)[1], parameters(sum)[2], "tmp")
ret!(builder, tmp)

verify(module_)

ir = string(module_)

engine = Interpreter(module_)

args = [
	GenericValue(LLVM.Int32Type(ctx), 1), 
	GenericValue(LLVM.Int32Type(ctx), 2)
]

res = LLVM.run(engine, sum, args)

convert(Int, res)

dispose.(args)
dispose(res)
dispose(engine)

println(ir)

module2_ = parse(LLVM.Module, ir; ctx)
sum = functions(module2_)["sum"]
@eval call_sum(x, y) = $(call_function(sum, Int32, Tuple{Int32, Int32}, :x, :y))

@code_llvm call_sum(((rand(1:10), rand(1:20)).|> Int32)...)


global workDay end

function test()
	a = workDay()
	return a
end

function codegen(cg::CodeGen, expr::PrototypeAST)
    if haskey(LLVM.functions(cg.mod), expr.name)
            error("existing function exists")
    end
    args = [LLVM.DoubleType(cg.ctx) for i in 1:length(expr.args)]
    func_type = LLVM.FunctionType(LLVM.DoubleType(cg.ctx), args)
    func = LLVM.Function(cg.mod, expr.name, func_type)
    LLVM.linkage!(func, LLVM.API.LLVMExternalLinkage)

    for (i, param) in enumerate(LLVM.parameters(func))
        LLVM.name!(param, expr.args[i])
    end
    return func
end

function consoleLog()
	Base.llvmcall(
	"""
		define i64 @consoleLog(i64 %$$c) {
		  %sym5 = add i64 1, 0
		  %sym7 = add i64 %$$c, 0
		  %sym6 = alloca i64, align 4
		  store i64 %sym7, i64* %sym6, align 4
		  %sym8 = add i64 1, 0
		  %sym9 = add i64 33554436, 0
		  %sym4 = call i64 asm sideeffect "syscall", "=r,{rax},{rdi},{rsi},{rdx},~{dirflag},~{fpsr},~{flags}" (i64 %sym9, i64 %sym5, i64* %sym6, i64 %sym8)
		}
	"""
	)
end
