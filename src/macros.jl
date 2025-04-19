"""
For writing post-specifications

```
"returns named tuple with `key` removed"
rmkey(nt::NamedTuple, key::Symbol) = (; (k => v for (k, v) in pairs(nt) if k != key)...)
@pre "Key must exist to be removed" rmkey(nt, key) = key in keys(nt)
@post rmkey(ret, nt, key) = (k = setdiff(keys(ret), keys(nt)); length(k) == 1 && k[1] == key)
```

expands to

```
Spec.premeta(::typeof(rmkey), nt, key) = Spec.SpecMeta(; desc = "Key must be exist to be removed")
Spec.pre(::typeof(rmkey), nt, key) = key in keys(nt)
Spec.post(::typeof(rmkey), ret, nt, key) = (k = setdiff(keys(ret), keys(nt)); length(k) == 1 && k[1] == key)
```

For mutating functions, we may wish to capture information before they are run.

```
@pre sort!(x::Vector{Int}) = (x_ = deepcopy(x))
@capture sort!(x) = (x = deepcopy(x))
@post sort!(cap, ret, x) = ret == sort(cap.x)
```
expands to:

```
pre(typeof(sort!), x::Vector{Int})
post(::typeof(f), ret, x) = x > 0
capture(typeof(sort!), ret, x) = (x_ = deepcopy(x),)

"""


function _transform(key, f, body, positional_args, default_args, keyword_args)
  # Produces expression of the form:
  # Spec.pre(Val{key}, typeof(f), positional_args..., default_args..., keyword_args...) = body
  method_signature = Expr(:call, :(::Val{$key}), :(::typeof($f)), positional_args..., default_args...)
  if !isempty(keyword_args)
      method_signature.args = vcat(Expr(:parameters, keyword_args...), method_signature.args)
  end
  :(Spec.pre($(method_signature.args...)) = $body)
end

function transform(key, expr)
    @match expr begin
        # Match function definitions with any combination of arguments
        Expr(:(=), Expr(:call, f, args...), body) => begin
            # Initialize argument lists
            positional_args = []
            default_args = []
            keyword_args = []

            # Iterate over the arguments
            for arg in args
                if arg isa Expr
                    if arg.head == :parameters
                        # Collect keyword arguments
                        append!(keyword_args, arg.args)
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
            # @show key
            # @show positional_args
            # @show default_args
            # @show keyword_args
            _transform(key, f, body, positional_args, default_args, keyword_args)
        end
    end
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
  @match expr begin
      Expr(:(=), Expr(:call, f, args...), body) => begin
          positional_args = []
          default_args = []
          keyword_args = []
          for arg in args
              if arg isa Expr
                  if arg.head == :parameters
                      append!(keyword_args, arg.args)
                  elseif arg.head == :kw
                      push!(default_args, arg)
                  else
                      push!(positional_args, arg)
                  end
              else
                  push!(positional_args, arg)
              end
          end
          
          _transformmeta(key, f, body, meta, positional_args, default_args, keyword_args)
      end
      _ => throw(ArgumentError("Invalid expression: $expr"))
  end
end

function adddospec(expr, meta)
  @match expr begin
    Expr(:(=), Expr(:call, f, xs...), body) => :(Spec.overdub(specctx::Spec.SpecCtx, ::typeof($f), $(xs...)) = Spec.dospec(specctx, $f, $(xs...)))
  end
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
macro pre(precond, meta)
  key = hash(precond)
  expr = quote
    $(transform(key, precond))
    $(transformmeta(key, precond, meta))
    # $(adddospec(precond, meta))
  end
  esc(expr)
end

macro pre(precond)
  meta = ""
  key = hash(precond)
  expr = quote
    $(transform(key, precond))
    $(transformmeta(key, precond, meta))
    # $(adddospec(precond, meta))
  end
  esc(expr)
end

macro invariant(args...)
end

macro ret()
  esc(:ret)
end

"Capture"
macro cap(var::Symbol)
  esc(Expr(:., :cap, QuoteNode(var)))
end

## Post Conditions

function _transformpost(key, f, body, positional_args, default_args, keyword_args)
  # Produces expression of the form:
  # Spec.post(::Val{key}, __ret__, ::typeof(f), positional_args..., default_args..., keyword_args...) = body
  method_signature = Expr(:call, :(::Val{$key}), :__ret__, :(::typeof($f)), positional_args..., default_args...)
  if !isempty(keyword_args)
      method_signature.args = vcat(Expr(:parameters, keyword_args...), method_signature.args)
  end
  :(Spec.post($(method_signature.args...)) = $body)
end

function transformpost(key, expr)
  @match expr begin
    Expr(:(=), Expr(:call, f, xs...), body) => begin
        positional_args = []
        default_args = []
        keyword_args = []
        
        for arg in xs
            if arg isa Expr
                if arg.head == :parameters
                    append!(keyword_args, arg.args)
                elseif arg.head == :kw
                    push!(default_args, arg)
                else
                    push!(positional_args, arg)
                end
            else
                push!(positional_args, arg)
            end
        end
        
        _transformpost(key, f, body, positional_args, default_args, keyword_args)
    end
    _ => throw(ArgumentError("Invalid expression: $expr"))
  end
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
  @match expr begin
    Expr(:(=), Expr(:call, f, xs...), body) => begin
        positional_args = []
        default_args = []
        keyword_args = []
        
        for arg in xs
            if arg isa Expr
                if arg.head == :parameters
                    append!(keyword_args, arg.args)
                elseif arg.head == :kw
                    push!(default_args, arg)
                else
                    push!(positional_args, arg)
                end
            else
                push!(positional_args, arg)
            end
        end
        
        _transformmetapost(key, f, body, meta, positional_args, default_args, keyword_args)
    end
    _ => throw(ArgumentError("Invalid expression: $expr"))
  end
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
macro post(postcond, meta)
  key = hash(postcond)
  expr = quote
    $(transformpost(key, postcond))
    $(transformmetapost(key, postcond, meta))
    # $(adddospec(postcond, meta))
  end
  esc(expr)
end

macro post(postcond)
  meta = ""
  key = hash(postcond)
  expr = quote
    $(transformpost(key, postcond))
    $(transformmetapost(key, postcond, meta))
    # $(adddospec(postcond, meta))
  end
  esc(expr)
end


