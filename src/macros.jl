
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
````
expands to:

````
pre(typeof(sort!), x::Vector{Int})
post(::typeof(f), ret, x) = x > 0
capture(typeof(sort!), ret, x) = (x_ = deepcopy(x),)

"""

function transform(key, expr)
  # Expr(:(=), Expr(:call, :(Spec.pre), :(typeof)))
  @match expr begin
    Expr(:(=), Expr(:call, f, xs...), body) => :(Spec.pre(::Val{$key}, ::typeof($f), $(xs...)) = $body)
  end
end

function transformmeta(key, expr, meta)
  @match expr begin
    Expr(:(=), Expr(:call, f, xs...), body) => :(Spec.premeta(::Val{$key}, ::typeof($f), $(xs...)) = Spec.SpecMeta(; expr = $(QuoteNode(body))))
  end
end

function adddospec(expr, meta)
  @match expr begin
    Expr(:(=), Expr(:call, f, xs...), body) => :(Spec.overdub(specctx::Spec.SpecCtx, ::typeof($f), $(xs...)) = Spec.dospec(specctx, $f, $(xs...)))
  end
end

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

function transformpost(key, expr)
  # Expr(:(=), Expr(:call, :(Spec.pre), :(typeof)))
  @match expr begin
    Expr(:(=), Expr(:call, f, xs...), body) => :(Spec.post(::Val{$key}, __ret__, ::typeof($f), $(xs...)) = $body)
  end
end

function transformmetapost(key, expr, meta)
  @match expr begin
    Expr(:(=), Expr(:call, f, xs...), body) => :(Spec.postmeta(::Val{$key}, __ret__, ::typeof($f), $(xs...)) = Spec.SpecMeta(; expr = $(QuoteNode(body))))
  end
end

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

