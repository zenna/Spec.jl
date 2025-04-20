

# Utility: ensure an overlay wrapper exists for this `fncall`
function _install_overlay(fdef::Expr)
    @assert is_top_level_func_def(fdef)
    # fn   = fdef.args[1]
    # args = fdef.args[2:end]
    @show c = extract_fdef_components(fdef)
    fn = c.f
    args = c.positional_args
    lhs_call_expr = call_expr(fn = fn, args = c.positional_args, kwargs = c.keyword_args)
    prepostcallexpr = call_expr(fn = :(Spec.prepostcall), args = [c.f; c.positional_args], kwargs = c.keyword_args)

    # escfn   = esc(fn)
    # escargs = map(esc, args)

    r = quote
      Spec.CassetteOverlay.@overlay Spec.Spectable ($lhs_call_expr = $prepostcallexpr)
    end
    @show r
    dump(r; maxdepth = 15)
    return r
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

function transform(key, expr)
    components = extract_fdef_components(expr)
    _transform(key, components.f, components.body, components.positional_args, components.default_args, components.keyword_args)
end

function _transformmeta(key, f, body, meta, positional_args, default_args, keyword_args)
  # Produces expression of the form:
  # Spec.premeta(::Val{key}, ::typeof(f), positional_args..., default_args..., keyword_args...) = SpecMeta(...)
  method_signature = Expr(:call, :(::Val{$key}), :(::typeof($f)), positional_args..., default_args...)
  if !isempty(keyword_args)
      method_signature.args = vcat(Expr(:parameters, keyword_args...), method_signature.args)
  end
  :(Spec.premeta($(method_signature.args...)) = Spec.SpecMeta(; expr = $(QuoteNode(body)), desc = $meta))
end

function transformmeta(key, expr, meta)
  components = extract_fdef_components(expr)
  _transformmeta(key, components.f, components.body, meta, components.positional_args, components.default_args, components.keyword_args)
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

function _transformpost(key, f, body, positional_args, default_args, keyword_args)
  # Produces expression of the form:
  # Spec.post(Val{key}, __ret__, typeof(f), positional_args..., default_args..., keyword_args...) = body
  method_signature = Expr(:call, :(::Val{$key}), :__ret__, :(::typeof($f)), positional_args..., default_args...)
  if !isempty(keyword_args)
      method_signature.args = vcat(Expr(:parameters, keyword_args...), method_signature.args)
  end
  expr = :(Spec.post($(method_signature.args...)) = $body)
  return expr
end

function transformpost(key, expr)
    components = extract_fdef_components(expr)
    _transformpost(key, components.f, components.body, components.positional_args, components.default_args, components.keyword_args)
end

function _transformmetapost(key, f, body, meta, positional_args, default_args, keyword_args)
  # Produces expression of the form:
  # Spec.postmeta(::Val{key}, __ret__, ::typeof(f), positional_args..., default_args..., keyword_args...) = SpecMeta(...)
  method_signature = Expr(:call, :(::Val{$key}), :__ret__, :(::typeof($f)), positional_args..., default_args...)
  if !isempty(keyword_args)
      method_signature.args = vcat(Expr(:parameters, keyword_args...), method_signature.args)
  end
  :(Spec.postmeta($(method_signature.args...)) = Spec.SpecMeta(; expr = $(QuoteNode(body)), desc = $meta))
end

function transformmetapost(key, expr, meta)
    components = extract_fdef_components(expr)
    _transformmetapost(key, components.f, components.body, meta, components.positional_args, components.default_args, components.keyword_args)
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

