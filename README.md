# Spec.jl

[![Build Status](https://travis-ci.org/zenna/Spec.jl.svg?branch=master)](https://travis-ci.org/zenna/Spec.jl)

[![codecov.io](http://codecov.io/github/zenna/Spec.jl/coverage.svg?branch=master)](http://codecov.io/github/zenna/Spec.jl?branch=master)

A package for expressing specifications.

Spec.jl is (very small) library for specfiying correctness properties of programs.
These tests are used both as documentation and for testing.

# Usage


## Post Conditions

The most common kind of specification is a __post condition__ which is a test that is on the output of a function.
The most canonical example of a specificaiton is that of a sorted list., which states that a list is sorted if for every element `i` and every element `j`, if `i < j` then the position of `i` should be less than the position of `j`  


```julia
"p implies q"
p → q = !(p && !q)

sorted(xs) = 
  all((xs[i] < xs[j] → i < j for i = 1:length(xs) for j = 1:length(xs) if i != j))

mysort(x) = sort(x)
@post sorted(res)
```

It's often useful to give a specification a description

```julia
@post sorted(res) "The output was sorted: x_i < x_j implies i < j"
```

One use of a spec is to execute a function.

Suppose we have a functio

```julia 
function myfunction
  x = rand(0)
  myspec(x)
end
```


## Operations

Preconditions are defined using `@pre`

```julia
julia> f(x::Real) = (@pre x > 0; sqrt(x) + 5)
f (generic function with 1 method)

julia> f(-3)
ERROR: DomainError:
Stacktrace:
 [1] f(::Int64) at ./REPL[2]:1

julia> @with_pre begin
               f(-3)
             end
ERROR: ArgumentError: x > 0
Stacktrace:
```