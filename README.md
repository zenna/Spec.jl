# Spec.jl

[![Build Status](https://travis-ci.org/zenna/Spec.jl.svg?branch=master)](https://travis-ci.org/zenna/Spec.jl)

[![codecov.io](http://codecov.io/github/zenna/Spec.jl/coverage.svg?branch=master)](http://codecov.io/github/zenna/Spec.jl?branch=master)

A package for expressing specifications.

Spec.jl is small library for specfiying correctness properties of programs.
These specifications can be used as documentation, for testing, and for debugging.

# Usage

Toadd:

- other meta dontcheck, e.g. existential propositions (example?)

### Pre Conditions

Preconditions are statements (also known as propositions or conditions) that must be true about the input before the function is executed.
One purpose of using preconditions is for documentation -- by specifying precise constraints on the function's behaviour we are communicating more clearly what we expect it to do.

Preconditions are specified using the `@pre` macro, for example:

```julia
f(x::Float64) = x * sqrt(x)
@pre f(::Float64) x >= 0
```

This should be interpreted as defining a precondition for the method `f(::Int)` that specifies that the input `x` should be non-negative.

If we are feeling lazy we can avoid writing the signature twice, and instead write:

```julia
f(x::Float64) = x * sqrt(x)
@pre f x > 0
```

This will define the precondition `x > 0` for the most recently defined method for the generic function `f`.

Multiple specifications can be expressed by simply adding additional lines.  For example:

```julia
"Body mass index"
bmi(height, weight) = height / weight 
@pre bmi(height, weight) = height > 0 "height must be positive"
@pre bmi(height, weight) = weight > 0 "weight must be positive"
```

The semantics of this is conjuctive: __all__ the different specs should be true.
This example also shows us that we can attach a description to any specification.  

There is a many-to-one relationship between methods and generic functions in Julia.
One preconditions can be applied to many methods of a generic function.

```julia
"is x a number?"
isnumstring(x::String) = occursin(r"^\d+$", x)
divide(x::String, y::String) = parse(Int64, x) / parse(Int64, y)
@pre divide(x::String, y::String) = isnumstring(x) && isnumstring(y) "String should be a number"

specapply(divide, "123", "114")
specapply(divide, "123", "aa4")

divide(x::Int, y::Int) = x / y

"Convert `x` to number if string"
asnum(x::String) = parse(Int64, x)
asnum(x) = x

# This precondition Applies to both methods
@pre divide(x, y) = asnum(y) != 0 "Denominator cannot be zero"

specapply(divide, 100, 0)
specapply(divide, "100", "0")
```
In this example the first precondition only applies to the string based method, whereas the second precondition applies to both.


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
@post mysort(x) = isysortedx(x, @ret) "Result is sorted version of input"
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