# f(x, y=1; z=2) => @overlay f(x, y=1; z=2) = prepostcall(f, x, y=1; z=2)
function _install_overlay(fdef::Expr)
    @assert is_top_level_func_def(fdef)
    fcall_expr = extract_function_call(fdef)

    # Replace all keyword default values with a reference to the keyword
    # variable itself, e.g. `timeout = 30`  ->  `timeout = timeout` so that the
    # run‑time value supplied by the caller is forwarded to `prepostcall`.
    # Build LHS (wrapper signature) and RHS (forwarding call) simultaneously so
    # that keyword arguments are *names only* on the LHS (no default value
    # needed) but are *forwarded* with their run‑time value on the RHS.

    lhs_call_expr, rhs_prepostcallexpr = @match fcall_expr begin
        # Methods that contain keyword arguments --------------------------------
        Expr(:call, fn_, Expr(:parameters, kwargs__...), posargs__...) => begin
            # Keep the original keyword expressions (with their default values)
            kw_lhs  = kwargs__                          # e.g. timeout=30

            # In the RHS forward the **variable** carrying the run‑time value
            kw_pairs = [Expr(:kw, kw.args[1], kw.args[1]) for kw in kwargs__]

            lhs = Expr(:call, fn_, Expr(:parameters, kw_lhs...), posargs__...)

            rhs_args = Any[Expr(:parameters, kw_pairs...), fn_, posargs__...]
            rhs = Expr(:call, :(Spec.prepostcall), rhs_args...)

            (lhs, rhs)
        end

        # Methods without keyword arguments ------------------------------------
        Expr(:call, fn_, posargs__...) => begin
            lhs = fcall_expr
            rhs = Expr(:call, :(Spec.prepostcall), fn_, posargs__...)
            (lhs, rhs)
        end
    end

    quote
        Spec.CassetteOverlay.@overlay Spec.Spectable ($lhs_call_expr = $rhs_prepostcallexpr)
    end
end

macro pre(precond, msg = "")
    key = hash(precond)                      # same hashing trick as upstream

    # 1. Generate predicate & metadata methods — existing helpers
    gen1 = Spec.transform(key, precond)
    gen2 = Spec.transformmeta(key, precond, msg)

    # 2. Ensure overlay exists for this function signature
    # Need to extract the function call
    fncall = extract_function_call(precond)
    ov   = Spec._install_overlay(precond)

    return Expr(:block, gen1, gen2, ov) |> esc
end


macro post(postcond, msg = "")
    key  = hash(postcond)

    gen1 = Spec.transformpost(key, postcond)
    gen2 = Spec.transformmetapost(key, postcond, msg)

    # Need to extract the function call
    fncall = extract_function_call(postcond)
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
macro pre end

## Post Conditions

function transformpost(key, fdefexpr)
    _call_expr = extract_function_call(fdefexpr)
    body = extract_fdef_components(fdefexpr).body
    lhs = @match _call_expr begin
        Expr(:call, fn, Expr(:parameters, kwargs...), args...) => Expr(:call, :(Spec.post), Expr(:parameters, kwargs...), :(::Val{$key}), :__ret__, :(::typeof($fn)), args...)
        Expr(:call, fn, args...) => Expr(:call, :(Spec.post), :(::Val{$key}), :__ret__, :(::typeof($fn)), args...)
    end
    :($lhs = $body)
end

function transformmetapost(key, fdefexpr, meta)
    _call_expr = extract_function_call(fdefexpr)
    body = extract_fdef_components(fdefexpr).body
    lhs = @match _call_expr begin
        Expr(:call, fn, Expr(:parameters, kwargs...), args...) => Expr(:call, :(Spec.postmeta), Expr(:parameters, kwargs...), :(::Val{$key}), :__ret__, :(::typeof($fn)), args...)
        Expr(:call, fn, args...) => Expr(:call, :(Spec.postmeta), :(::Val{$key}), :__ret__, :(::typeof($fn)), args...)
    end
    :($lhs = Spec.SpecMeta(; expr = $(QuoteNode(body)), desc = $meta))
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
macro post end

