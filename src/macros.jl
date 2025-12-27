const _overlay_installed = Set{UInt}()
const _overlay_bypass = IdDict{Any, Bool}()

function _register_overlay_bypass!(f)
    _overlay_bypass[f] = true
    return nothing
end

function _has_overlay_bypass(f)::Bool
    return get(_overlay_bypass, f, false)
end

function _kw_default_unsafe(arg)
    !(arg isa Expr && arg.head === :kw) && return false
    val = arg.args[2]
    return val isa Expr && val.head === :call
end

function _requires_overlay_bypass(fcall_expr::Expr)::Bool
    @match fcall_expr begin
        Expr(:call, _, Expr(:parameters, kwargs...), _...) => any(_kw_default_unsafe, kwargs)
        _ => false
    end
end

function _kwarg_symbol(arg)
    if arg isa Symbol
        return arg
    end
    if arg isa Expr && arg.head === :(::)
        return _kwarg_symbol(arg.args[1])
    end
    return arg
end

function _forward_kwarg(arg)
    if arg isa Expr && arg.head === :kw
        name = _kwarg_symbol(arg.args[1])
        return Expr(:kw, name, name)
    end
    if arg isa Symbol
        return Expr(:kw, arg, arg)
    end
    return arg
end

function _overlay_call_args(fcall_expr::Expr)
    @match fcall_expr begin
        Expr(:call, fn, Expr(:parameters, kwargs...), args...) =>
            Any[Expr(:parameters, _forward_kwarg.(kwargs)...), fn, args...]
        Expr(:call, fn, args...) => Any[fn, args...]
        _ => throw(ArgumentError("Invalid call expression: $fcall_expr"))
    end
end

function _strip_ret_arg!(call_expr::Expr)
    call_expr.head === :call || return call_expr
    new_args = Any[call_expr.args[1]]
    seen_positional = false
    for arg in call_expr.args[2:end]
        if arg isa Expr && arg.head === :parameters
            push!(new_args, arg)
            continue
        end
        if !seen_positional && arg === :__ret__
            seen_positional = true
            continue
        end
        seen_positional = true
        push!(new_args, arg)
    end
    call_expr.args = new_args
    return call_expr
end

function _overlay_call_expr(fcall_expr::Expr)::Expr
    expr = deepcopy(fcall_expr)
    Base.remove_linenums!(expr)
    _strip_ret_arg!(expr)
    return expr
end

function _should_install_overlay(fcall_expr::Expr)::Bool
    sig = hash(fcall_expr, zero(UInt))
    if sig in _overlay_installed
        return false
    end
    push!(_overlay_installed, sig)
    return true
end

# f(x, y=1; z=2) => @overlay f(x, y=1; z=2) = prepostcall(f, x, y=1; z=2)
function _install_overlay(fdef::Expr)
    @assert is_top_level_func_def(fdef)
    fcall_expr = _overlay_call_expr(extract_function_call(fdef))
    if _requires_overlay_bypass(fcall_expr)
        fn = fcall_expr.args[1]
        return :(Spec._register_overlay_bypass!($fn))
    end
    _should_install_overlay(fcall_expr) || return :(nothing)
    lhs_call_expr = fcall_expr
    rhs_prepostcallexpr = Expr(:call, :(Spec.prepostcall), _overlay_call_args(fcall_expr)...)

    r = quote
      Spec.CassetteOverlay.@overlay Spec.Spectable ($lhs_call_expr = $rhs_prepostcallexpr)
    end
    # @show r
    # dump(r; maxdepth = 15)
    # return :(1+1)
    return r
end

"""
    @pre function_call(args...; kwargs...) = condition "description"

Define a precondition for a function.

This macro attaches a precondition to a function that is checked whenever the function
is called via `specapply`. If the precondition fails, the function will not be executed
and a `PreconditionError` will be thrown.

## Arguments
- `function_call`: The function and its arguments that the precondition applies to
- `condition`: An expression that evaluates to a boolean, representing the precondition
- `description`: An optional string describing the precondition

## Keyword Arguments
When specifying preconditions for functions with keyword arguments, you can include those
keyword arguments in your specification. The precondition will be checked with the actual
keyword values when the function is called.

## Examples
```jldoctest
julia> function sqrt_safe(x)
           sqrt(x)
       end;

julia> @pre sqrt_safe(x) = x >= 0 "Input must be non-negative";

julia> specapply(sqrt_safe, 4.0)
2.0

julia> try
           specapply(sqrt_safe, -1.0)
       catch e
           println("Caught expected error: \$(e isa PreconditionError)")
       end
Caught expected error: true

julia> function greeting(name; prefix="Hello", suffix="!")
           return "\$(prefix), \$(name)\$(suffix)"
       end;

julia> @pre greeting(name; prefix) = !isempty(name) && !isempty(prefix) "Name and prefix must not be empty";

julia> specapply(greeting, "World", prefix="Greetings")
"Greetings, World!"
```
"""
macro pre(precond, msg = "")
    key = hash(precond)                      # same hashing trick as upstream

    # 1. Generate predicate & metadata methods — existing helpers
    gen1 = Spec.transform(key, precond)
    gen2 = Spec.transformmeta(key, precond, msg)

    # 2. Ensure overlay exists for this function signature
    ov   = Spec._install_overlay(precond)

    return Expr(:block, gen1, gen2, ov) |> esc
end


"""
    @post function_call(__ret__, args...; kwargs...) = condition "description"

Define a postcondition for a function.

This macro attaches a postcondition to a function that is checked after the function
is called via `specapply`. If the postcondition fails, a `PostconditionError` will be thrown.

## Arguments
- `function_call`: The function and its arguments that the postcondition applies to
- `__ret__`: A special variable that represents the return value of the function
- `condition`: An expression that evaluates to a boolean, representing the postcondition
- `description`: An optional string describing the postcondition

## Keyword Arguments
When specifying postconditions for functions with keyword arguments, you can include those
keyword arguments in your specification. The postcondition will be checked with the actual
keyword values that were used in the function call.

## Examples
```jldoctest
julia> function inc(x)
           x + 1
       end;

julia> @post inc(__ret__, x) = __ret__ > x "Return value should be greater than input";

julia> specapply(inc, 5)
6

julia> function format_name(first, last; title="")
           if isempty(title)
               return "\$(first) \$(last)"
           else
               return "\$(title) \$(first) \$(last)"
           end
       end;

julia> @post format_name(__ret__, first, last; title) = contains(__ret__, first) && contains(__ret__, last) "Result should contain both names";

julia> @post format_name(__ret__, first, last; title="Dr.") = startswith(__ret__, "Dr.") "Doctor title should be at the beginning";

julia> specapply(format_name, "John", "Smith", title="Dr.")
"Dr. John Smith"
```
"""
macro post(postcond, msg = "")
    key  = hash(postcond)

    gen1 = Spec.transformpost(key, postcond)
    gen2 = Spec.transformmetapost(key, postcond, msg)

    ov   = Spec._install_overlay(postcond)

    return Expr(:block, gen1, gen2, ov) |> esc
end


function _transform(key, f, body, positional_args, default_args, keyword_args)
  # Produces expression of the form:
  # Spec.pre(Val{key}, typeof(f), positional_args..., default_args..., keyword_args...) = body

  method_signature = Expr(:call, :(::Val{$key}), :(::typeof($f)), positional_args..., default_args...)
  if !isempty(keyword_args)
      method_signature.args = vcat(Expr(:parameters, keyword_args...), method_signature.args)
  end
  expr = :(Spec.pre($(method_signature.args...)) = $body)
  # dump(expr)
  return expr
end

# @pre f(x, y=1; z=2) = x + y + z > 0 => Spec.pre(::Val{0x634c7875d71b9857}, f, x, y=1, z-2) = x + y + z > 0
function transform(key, fdefexpr)
    _call_expr = extract_function_call(fdefexpr)
    body = extract_fdef_components(fdefexpr).body
    lhs = @match _call_expr begin
        Expr(:call, fn, Expr(:parameters, kwargs...), args...) => Expr(:call, :(Spec.pre), Expr(:parameters, kwargs...), :(::Val{$key}), :(::typeof($fn)), args...)
        Expr(:call, fn, args...) => Expr(:call, :(Spec.pre), :(::Val{$key}), :(::typeof($fn)), args...)
    end
    :($lhs = $body)
end

function _transformmeta(key, fdefexpr, meta)
  _call_expr = extract_function_call(fdefexpr)
  body = extract_fdef_components(fdefexpr).body
  lhs = @match _call_expr begin
      Expr(:call, fn, Expr(:parameters, kwargs...), args...) => Expr(:call, :(Spec.premeta), Expr(:parameters, kwargs...), :(::Val{$key}), :(::typeof($fn)), args...)
      Expr(:call, fn, args...) => Expr(:call, :(Spec.premeta), :(::Val{$key}), :(::typeof($fn)), args...)
  end
  :($lhs = Spec.SpecMeta(; expr = $(QuoteNode(body)), desc = $meta))
end

function transformmeta(key, expr, meta)
  _transformmeta(key, expr, meta)
end

function transformpost(key, fdefexpr)
    _call_expr = extract_function_call(fdefexpr)
    body = extract_fdef_components(fdefexpr).body
    lhs = @match _call_expr begin
        Expr(:call, fn, Expr(:parameters, kwargs...), args...) => begin
            args_no_ret = (!isempty(args) && args[1] === :__ret__) ? args[2:end] : args
            Expr(:call, :(Spec.post), Expr(:parameters, kwargs...), :(::Val{$key}), :__ret__, :(::typeof($fn)), args_no_ret...)
        end
        Expr(:call, fn, args...) => begin
            args_no_ret = (!isempty(args) && args[1] === :__ret__) ? args[2:end] : args
            Expr(:call, :(Spec.post), :(::Val{$key}), :__ret__, :(::typeof($fn)), args_no_ret...)
        end
    end
    :($lhs = $body)
end

function transformmetapost(key, fdefexpr, meta)
    _call_expr = extract_function_call(fdefexpr)
    body = extract_fdef_components(fdefexpr).body
    lhs = @match _call_expr begin
        Expr(:call, fn, Expr(:parameters, kwargs...), args...) => begin
            args_no_ret = (!isempty(args) && args[1] === :__ret__) ? args[2:end] : args
            Expr(:call, :(Spec.postmeta), Expr(:parameters, kwargs...), :(::Val{$key}), :__ret__, :(::typeof($fn)), args_no_ret...)
        end
        Expr(:call, fn, args...) => begin
            args_no_ret = (!isempty(args) && args[1] === :__ret__) ? args[2:end] : args
            Expr(:call, :(Spec.postmeta), :(::Val{$key}), :__ret__, :(::typeof($fn)), args_no_ret...)
        end
    end
    :($lhs = Spec.SpecMeta(; expr = $(QuoteNode(body)), desc = $meta))
end

"""
    @invariant args...

Declare an invariant for a data structure.

This is a stub for planned functionality and is not implemented yet.
"""
macro invariant(args...)
    @warn "@invariant is not implemented yet"
end
