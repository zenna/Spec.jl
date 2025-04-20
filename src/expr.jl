## Utilities
## =========

# julia> dump(:(f(x, y, z = 1; kw1=2)))
# Expr
#   head: Symbol call
#   args: Array{Any}((5,))
#     1: Symbol f
#     2: Expr
#       head: Symbol parameters
#       args: Array{Any}((1,))
#         1: Expr
#           head: Symbol kw
#           args: Array{Any}((2,))
#             1: Symbol kw1
#             2: Int64 2
#     3: Symbol x
#     4: Symbol y
#     5: Expr
#       head: Symbol kw
#       args: Array{Any}((2,))
#         1: Symbol z
#         2: Int64 1
# julia> dump(:(f(x...) = 21))
# Expr
# head: Symbol =
# args: Array{Any}((2,))
#   1: Expr
#     head: Symbol call
#     args: Array{Any}((2,))
#       1: Symbol f
#       2: Expr
#         head: Symbol ...
#         args: Array{Any}((1,))
#           1: Symbol x
#   2: Expr
#     head: Symbol block
#     args: Array{Any}((2,))
#       1: LineNumberNode
#         line: Int64 1
#         file: Symbol REPL[5]
#       2: Int64 21

function is_valid_expr(expr::Expr)
  @match expr begin
    Expr(:call, args...) => is_call_expr(expr)
    _ => error("Not implemented for $expr")
  end
end

"""
    is_call_expr(expr::Expr) -> Bool

Return `true` when the expression `expr` is a well-formed call expression.

True iff it follows one of the following patterns:
```
f(x)	(call f x)
f(x, y=1, z=2)	(call f x (kw y 1) (kw z 2))
f(x; y=1)	(call f (parameters (kw y 1)) x)
f(x...)	(call f (... x))
````

"""
function is_call_expr(expr::Expr)
  @match expr begin
    Expr(:call, args...) => true
    _ => false # TODO: Implement more cases
  end
end

"""
    is_top_level_func_def(ex::Expr) -> Bool

Return `true` when the expression `ex` has the *syntactic* form of a
**top‑level** Julia function (method) definition.

Recognised patterns
-------------------
1. `function … end` blocks, including empty stubs (`function g end`);
2. one‑line definitions of the form `lhs = rhs`
   where `lhs` itself is a *call* expression
   (`f(x)=…`, `+(a,b)=…`, `(s::T)(x)=…`);
3. `@generated function … end`.

The test is purely structural; it does **not** check that the code
really appears at global scope or that it survives macro hygiene.
"""
function is_top_level_func_def(ex::Expr)::Bool
    # helper -----------------------------------------------------------
    _is_call(lhs) = lhs isa Expr && lhs.head === :call

    # 1.  `function name … end`
    ex.head === :function && return true

    # 2.  compact / operator / functor method  `lhs = rhs`
    if ex.head === :(=)
        lhs, _ = ex.args
        return _is_call(lhs)
    end

    # 3.  `@generated function … end`
    if ex.head === :macrocall &&
       !isempty(ex.args)       &&
       ex.args[1] === Symbol("@generated")
        fn_expr = ex.args[end]               # usually the last slot
        return fn_expr isa Expr && fn_expr.head === :function
    end

    return false
end

"""
    extract_function_call(expr::Expr)

From a function definition extract the function call expr

```jldoctest
julia> extract_function_call(:(f(x::Int, y::Real) = x > 0))
:(f(x::Int, y::Real))

julia> x = :(function  f(x::String)
         x * "hello"
       end)

julia> extract_function_call(x)
:(f(x::String))
```
"""
function extract_function_call(expr::Expr)
  @match expr begin
    Expr(:(=), Expr(:call, fn, args...), _) => Expr(:call, fn, args...)
    Expr(:function, Expr(:call, fn, args...), _) => Expr(:call, fn, args...)
    _ => throw(ArgumentError("Invalid expression: $expr"))
  end
end

"""
    call_expr_to_call_args(expr::Expr)

Extract the function call and its arguments from an expression as a list of arguments.
The output should be ae list of argument in the sense that 
This is useful for a common pattern when we want to use the function in a higher order call

```jldoctest
julia> timedf(f, args) = @timed f(args...);

julia> args = call_expr_to_call_args(:(f(x, y, z; y = 4)));

julia> expr = Expr(:call, :timedf, args...]

julia> @eval expr
```
"""
function call_expr_to_call_args(expr::Expr)
  # Need to handle all the different types.
  # Note if there are parameters these are the first arguments, se
  @match expr begin
    Expr(:call, fn, args...) => Any[fn, args...]
    Expr(:call, fn, Expr(:parameters, kwargs...), args...) => Any[Expr(:parameters, kwargs...), fn, args...]
    _ => throw(ArgumentError("Invalid expression: $expr"))
  end
end
# @pre call_expr_to_call_args(expr::Expr) = is_call_expr(expr) "`expr` must be a valid call expression"
# @post call_expr_to_call_args(expr::Expr) = is_well_formed(Expr(:call, :f, __ret__...)) "`expr` must be a valid arguments for a expression"

function extract_fdef_components(expr::Expr)
  @match expr begin
    # Match function definitions with any combination of arguments
    Expr(:(=), Expr(:call, f, args...), body) => begin
        # Initialize argument lists
        positional_args = []
        default_args = []
        keyword_args = Expr[]

        # Iterate over the arguments
        for arg in args
            if arg isa Expr
                if arg.head == :parameters
                    # Collect keyword arguments
                    push!(keyword_args, arg)
                elseif arg.head == :kw
                    # Collect default positional arguments
                    push!(default_args, arg)
                else
                    # Collect positional arguments
                    push!(positional_args, arg)
                end
            else
                # Collect positional arguments
                push!(positional_args, arg)
            end
        end
        return (f = f,
                positional_args = positional_args,
                default_args = default_args,
                keyword_args = keyword_args,
                body = body)
    end
    _ => throw(ArgumentError("Invalid expression: $expr"))
  end
end

function call_expr(; fn, args, kwargs)
    @show Expr(:call, fn, [kwargs; args]...)
end
