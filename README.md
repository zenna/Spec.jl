# Spec.jl

[![Build Status](https://travis-ci.org/zenna/Spec.jl.svg?branch=master)](https://travis-ci.org/zenna/Spec.jl)

[![codecov.io](http://codecov.io/github/zenna/Spec.jl/coverage.svg?branch=master)](http://codecov.io/github/zenna/Spec.jl?branch=master)

A package for expressing specifications.

Spec.jl is small library for specfiying correctness properties of programs.
These tests are used both as documentation and for testing.

# Usage

Toadd:

- other meta dontcheck, e.g. existential propositions (example?)

### Pre Conditions

Preconditions are statements (also known as propositions or conditions) that must be true about the input before the function is executed.
On purpose of using preconditions is for documentation -- by being specifying precise constraints on the functions behaviour we are communicating more clearly what we expect it to do.

Preconditions are specified using the `@pre` macro, for example:

```julia
f(x::Float64) = x * sqrt(x)
@pre f(x::Float64) >= 0
```

This should be interpreted as defining a precondition for the function `f` that specifies that the input `x` should be non-negative.

If we are feeling lazy we can avoid writing the signature twice, and instead write:

```julia
f(x::Float64) = x * sqrt(x)
@pre f x > 0
```

This will define the precondition `x > 0` for the most recently defined method for `f`.

Multiple specifications can be expressed by simply adding additional lines.  For example:

```julia
"Body mass index"
bmi(height, weight) = height / weight 
@pre bmi height > 0 "Height must be positive"
@pre bmi weight > 0 "Weight must be positive"
```

This example also shows us that we can attach a description to any specification.

There is a many-to-one relationship between methods and generic functions in Julia.
One preconditions can be applied to many methods of a generic function

```julia

addelems(x::Tuple, y::Tuple) = 
addelems(x::Vector, y::Vector) = 
@pre addelems(x, y) length(x) == length(y) "Must be equal length"
@pre addelems(x::Tuple, y::Tuple) 
```
In this example the first precondition only applies to 

In fact, a good use of Spec is to define a precondition to __all__ methods of a function, in order to give a more rigorous definition of the behaviour that is expected of any of its method.

```julia
function addelems end
@pre ...
```


## Post Conditions

The secondkind of specification is a __post condition__ which is a statement on the output and input of a proecdure after it has executed
The most canonical example of a specificaiton is that of a sorted list, which states that a list is sorted if for every element `i` and every element `j`, if `i < j` then the position of `i` should be less than the position of `j`  


```julia
"p implies q"
p → q = !(p && !q)


"is `xs`  sorted"
issorted(xs) = 
  all((xs[i] < xs[j] → i < j for i = 1:length(xs) for j = 1:length(xs) if i != j))

"Is `y` sorted version of `x`"
isysortedx(xs, ys) = 
  length(ys) == length(xs) && all((y in xs for y in ys)) && issorted(y)

mysort(x) = sort(x)
@post mysort isysortedx(x, @ret) "Result is sorted version of input"
```


#### Capturing

As we have seen, `@post` can also input values to a function.  So why bother have two constructs at all?
The main reason is that Julia procedures can have side effects.

In the mutating sort function `sort!(xs)` the input is mutated.
Therefore if we want to check that the result is a sorted version of the input we have a problem, because we have lost our information about the input.
The solution is to use `@cap` to capture variables in the input

```julia
@post sort! isysortedx(@cap(x), @ret) "Result is sorted version of input"
```

## Activating Specifications -- Debugging
By default, pre and post conditions will not affect the behaviour of your program at all.
To activate specifications we use `@specapply`

```
@specapply mysort(rand(5))
```

One of the best uses of `specapply` is debugging.  Often a runtime error is the ressult of a pre-condition much further up the stack being violated.
For example:

```julia
function f()
  x = rand(4, 4)
  x[3,4]
end
```

Evaluating `f()` gives us this horribly uninfomrative stack trace.

If instead we run this function with `specapply`

## QuickTest
Testing using Spec can be as simply as writing


```julia
@spectest myspec
```

Spec will try to generate inputs that are consistent with the input, then evaluate the function with those input using `specapply`.

Sometimes it will be too difficult for Spec to generative valid inputs, for instance if X or Y or Z.
Othertimes you might want to test an function with a particular input or input distribution.
In this caseL

## Typical setup