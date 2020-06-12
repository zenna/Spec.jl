export post, pre, premeta, postmeta, specapply

import Cassette
using Parameters


## TODO:
# 1. pre/post over multiple lines wont work
# 2. should we refer to current function, or somehow look it up

@with_kw struct SpecMeta
  check::Int = true     # Actually check this
  desc::String = ""     # Description
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
  if premeta_.check == true
    @assert pre(f, args...) premeta_.desc # FIXME Replace assert with something else
  end
end

@inline function checkpost(cap, f, args...)
  postmeta_ = postmeta(f, args...)
  if postmeta_.check == true
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

# "Is expr an inline function definition like `:(f(x) = 2x)`"
# isinlinefuncdef(expr::Expr) = expr.head == :(=) && length(expr.args) == 2 && expr.args[1] isa Expr && expr.args[1].head == :call

# function handlepostexpr(expr)
#   if isinlinefuncdef(expr)
#     Expr()

# end

# # Macros 
# THese macros make it easier to cosntruct specifications

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

function postexpr(expr)
  @match expr begin
    Expr(:(=), :last, ) => post(Expr(:(=), findlastmethod(f)))
  end
end

macro post(funcexpr)
  Expr(:call, :=, :last, _) => Expr(:call)
end

macro pre(funcexpr)

end

macro pre(meta, funcexpr)

end

macro invariant(args...)

end