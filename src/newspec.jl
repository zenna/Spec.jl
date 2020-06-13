export post, pre, premeta, postmeta, specapply

import Cassette
using Parameters


## TODO:
# 1. pre/post over multiple lines wont work
# 2. should we refer to current function, or somehow look it up

@with_kw struct SpecMeta
  check::Bool = true    # Actually check this
  desc::String = ""     # Description
  expr::Expr            # Expression encoding the proposition
end

struct PreConditionFailure <: Exception
  specmeta::SpecMeta
  args
end

function Base.showerror(io::IO, e::PreConditionFailure)
  println(io, "Precondition fail", e.specmeta)
  println(io, "Expression:", e.specmeta.expr)
  println(io, "Failed on inputs", e.specmeta.args)
end


Cassette.@context SpecCtx

@inline function Cassette.overdub(ctx::SpecCtx, f, args...)
  pre = checkpre(f, args...)
  cap = capture(f, args...)
  ret = Cassette.recurse(ctx, f, args...)
  checkpost(cap, f, args...)
  ret
end

@inline function checkpre(f, args...)
  premeta_ = premeta(f, args...)
  if premeta_.check
    !pre(f, args...) && throw(PreConditionFailure(premeta_, args))
  end
end

@inline function checkpost(cap, f, args...)
  postmeta_ = postmeta(f, args...)
  if postmeta_.check
    @assert post(cap, f, args...) postmeta_.desc
  end
end

"No post condition defined"
struct NoPost end
struct NoPre end
struct NoCapture end

"A pre-condition"
function pre end

"A post-condition"
function post end

post(args...) = NoPost()
pre(args...) = NoPre()
premeta(args...) = SpecMeta(; check = false)
postmeta(args...) = SpecMeta(; check = false)
capture(args...) = NoCapture()

"""
`specapply(f, args...)`

Evaluate `f(args...)` and check pre and post conditions of all functions encountered.

```
f(x) = abs(x)
@post f(ret, x) = x > 0)
specapply(f, 0.3)
```

"""
specapply(f, args...) = Cassette.overdub(SpecCtx(), f, args...)


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
macro post(meta, funcexpr)
end

macro post(funcexpr)
  # Expr(:call, :=, :last, _) => Expr(:call)
end

function transform(expr)
  # Expr(:(=), Expr(:call, :(Spec.pre), :(typeof)))
  @match expr begin
    Expr(:(=), Expr(:call, f, xs...), body) => :(Spec.pre(::typeof($f), $(xs...)) = $body)
  end
end

function transformmeta(expr, meta)
  @match expr begin
    Expr(:(=), Expr(:call, f, xs...), body) => :(Spec.premeta(::typeof($f), $(xs...)) = Spec.SpecMeta($body))
  end
end

macro pre(funcexpr)
  esc(transform(funcexpr))
end

macro pre(meta, funcexpr)
  expr = quote
    transform(funcexpr)
    transformmeta(meta)
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