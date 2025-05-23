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

@inline function Cassette.overdub(ctx::SpecCtx, f, args...)
  # @show f, args
  pre = checkpre(f, args...)
  # cap = capture(f, args...)
  ret = Cassette.recurse(ctx, f, args...)
  checkpost(ret, f, args...)
  ret
end

# @inline function dospec(ctx::SpecCtx, f, args...)
#   # @show f, args
#   ## For each one that matches pre(specid, f, args...)
#   pre = checkpre(f, args...)
#   # cap = capture(f, args...)
#   ret = Cassette.recurse(ctx, f, args...)
#   checkpost(ret, f, args...)
#   ret
# end

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
    specapply(f, args...; kwargs...)

Evaluate a function with pre- and postcondition checking.

This function executes `f(args...; kwargs...)` while checking all pre- and postconditions
that have been defined for the function using the `@pre` and `@post` macros.

## Behavior
- Before executing the function, all preconditions are checked
- If any precondition fails, a `PreconditionError` is thrown and the function is not executed
- If all preconditions pass, the function is executed
- After execution, all postconditions are checked
- If any postcondition fails, a `PostconditionError` is thrown
- If all postconditions pass, the function's return value is returned

## Keyword Arguments
When calling functions with keyword arguments, the specifications will be checked with
those keyword values. This allows you to specify different pre/postconditions for different
keyword argument values.

## Examples
```jldoctest
julia> function sqrt_safe(x)
           sqrt(x)
       end;

julia> # Define preconditions and postconditions
       @pre sqrt_safe(x) = x >= 0 "Input must be non-negative";
       @post sqrt_safe(__ret__, x) = __ret__ >= 0 "Output must be non-negative";

julia> # Use specapply to call the function with specification checking
       specapply(sqrt_safe, 4.0)
2.0

julia> try
           specapply(sqrt_safe, -1.0)
       catch e
           println("Caught expected error: \$(e isa PreconditionError)")
       end
Caught expected error: true

julia> # Function with keyword arguments
       function search(text; pattern="", case_sensitive=true)
           if case_sensitive
               count(==(pattern), text)
           else
               count(==(lowercase(pattern)), lowercase(text))
           end
       end;

julia> @pre search(text; pattern) = !isempty(pattern) "Search pattern cannot be empty";

```
f(x) = abs(x)
@post f(ret, x) = x > 0)
specapply(f, 0.3)
```

"""
specapply(f, args...) = Cassette.overdub(SpecCtx(), f, args...)

