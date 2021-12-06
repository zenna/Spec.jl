export post, pre, premeta, postmeta, specapply, PreconditionError, PostconditionError

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

struct PreconditionError <: Exception
  specmeta::SpecMeta
  args
end

function Base.showerror(io::IO, e::PreconditionError)
  println(io, "Precondition failure: ", e.specmeta.desc)
  println(io, "Expression: ", e.specmeta.expr)
  println(io, "Failed on inputs: ", e.args)
end

struct PostconditionError <: Exception
  specmeta::SpecMeta
  args
  ret
end

function Base.showerror(io::IO, e::PostconditionError)
  println(io, "Postondition failure: ", e.specmeta.desc)
  println(io, "Expression: ", e.specmeta.expr)
  println(io, "Failed on inputs: ", e.args)
  println(io, "and on return value: ", e.ret)
end

Cassette.@context SpecCtx

# @inline function Cassette.overdub(ctx::SpecCtx, f, args...)
#   @show f, args
#   pre = checkpre(f, args...)
#   cap = capture(f, args...)
#   ret = Cassette.recurse(ctx, f, args...)
#   checkpost(cap, f, args...)
#   ret
# end

@inline function dospec(ctx::SpecCtx, f, args...)
  # @show f, args
  ## For each one that matches pre(specid, f, args...)
  pre = checkpre(f, args...)
  # cap = capture(f, args...)
  ret = Cassette.recurse(ctx, f, args...)
  checkpost(ret, f, args...)
  ret
end

available_vals(fn) = (m.sig.types[2] for m in methods(fn).ms)

@inline function checkpre(f, args...)
  for v in available_vals(pre)
    if applicable(pre, v(), f, args...)
      premeta_ = premeta(v(), f, args...)
      if premeta_.check
        !pre(v(), f, args...) && throw(PreconditionError(premeta_, args))
      end
    end
  end
end

@inline function checkpost(ret, f, args...)
  for v in available_vals(post)
    if applicable(post, v(), ret, f, args...)
      postmeta_ = postmeta(v(), ret, f, args...)
      if postmeta_.check
        !post(v(), ret, f, args...) && throw(PostconditionError(postmeta_, args, ret))
      end
    end
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

function premeta end
function postmeta end
# premeta(args...) = SpecMeta(; check = false)
# postmeta(args...) = SpecMeta(; check = false)
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

