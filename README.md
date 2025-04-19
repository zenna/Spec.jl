# Spec.jl

[![codecov.io](http://codecov.io/github/zenna/Spec.jl/coverage.svg?branch=master)](http://codecov.io/github/zenna/Spec.jl?branch=master)

Spec is a package for expressing specifications.

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
@pre f(x::Float64) = x > 0 "x must be positive"
```

This should be interpreted as defining a precondition for the method `f(::Float64)` that specifies that the input `x` should be positive.

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
One precondition can be applied to many methods of a generic function.

The following example adds specification for a `divide` function, which works on Strings as well as numbers.

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

The second kind of specification is a __post condition__ which is a statement about the output and input of a proecdure after it has executed.
A canonical example of a post-condition is that of a sorted list, which states that a list is sorted if for every element `i` and every element `j`, if `i < j` then the position of `i` should be less than the position of `j`  


```julia
"p implies q"
p → q = !(p && !q)

"is `xs`  sorted"
issorted(xs) = 
  all((xs[i] < xs[j] → i < j for i = 1:length(xs) for j = 1:length(xs) if i != j))

"Is `y` sorted version of `x`"
isysortedx(xs, ys) = 
  length(ys) == length(xs) && all((y in xs for y in ys)) && issorted(ys)

mysort(x) = sort(x)
@post mysort(x) = isysortedx(x, __ret__) "Result is sorted version of input"
```

Note that in the post-condition, we use `__ret__` to refer to the return value of the function.

#### Capturing

As we have seen, a post-condition can also see values to a function.  So why bother have two constructs at all?
The main reason is that Julia procedures can have side-effects.

In the mutating sort function `sort!(xs)` the input is mutated.
Therefore if we want to check that the result is a sorted version of the input we have a problem, because we have lost information about the input.
The solution is to use `@cap` to capture variables in the input

```julia
@post sort! isysortedx(__pre__.x, __ret__) "Result is sorted version of input"
```

Note that we use `__pre__.x` to refer to the pre-state of `x`, and `__ret__` for the return value.

## Using Specifications 
By default, pre and post conditions will not affect the behaviour of your program at all, and incur no runtime cost.
To actually check specifications we use `specapply` or the `@specapply` macro.

```julia
specapply(f, args...)
```

This will evaluate `f(args)`, but for all function applications encountered in the execution of `f(args...)`, each and every associated spec will be checked.

A convenient macro alternative to `specapply` is `@specapply`, e.g.:

```julia
@specapply f(n)
```

For example, given the specs above for `sort` and `divide`, the following snippet will check the pre and post conditions:

```julia
function f(n)
  x = rand(n)
  y = sort(x)
  z = map(divide, y)
end

@specapply f(10)
```

### For Debugging


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
<!-- 
## QuickCheck
Testing using Spec can be as simple as:


```julia
spectest(some_generic_function)
```

Spec will try to generate inputs that are consistent with the input, then evaluate the function with those input using `specapply`.

If there are multiple methods for `some_generic_function`, `spectest` will test all those which have associated specs.
To spectest a specific method, simply pass a tuple of types as the second argument to `spectest` to apply to only methods matching those types.

```julia
spectest(sort, (Vector{Int},))
```

Sometimes it will be too difficult for Spec to generative valid inputs.
Othertimes you might want to test a function with a particular input distribution.
In this case, 

```julia
gen = rng -> rand(rng, Int, 10)
spectest(sort, (Vector{Int},); gen = gen)
``` -->

# Notes

- The concept of testing all the nested specs within a function call f(x) is orthogonal to pretty much everything else (that follows)
- For a given method, I may want to test all, some or none of the specs 
- For a given method and given spec, I may want to test it on (i) one input, (ii) samples from a distribution of inputs, (iii) all inputs, finitely enumerable, (iv) all inputs abstractly.

## Testing with Spec

You can use Spec in combination with Julia's built-in Test module for testing. Here's an example:

```julia
using Spec
using Test

f(x::Float64) = x * sqrt(x)
@pre f(x::Float64) = x > 0 "x must be positive"
@test @specapply(f(10.0)) == 10.0 * sqrt(10.0)
@test_throws PreconditionError @specapply(f(-10.0))

# Testing post-conditions
fakesort(x) = x
@post fakesort(x) = isysortedx(x, __ret__) "Result is sorted version of input"
@test_throws PostconditionError @specapply(fakesort(rand(10)))
```

This approach allows you to test both the correctness of your functions and the effectiveness of your specifications.

# Mini Guide
# Final Complete Technical Guide for Spec.jl

1. Preconditions (@pre): Specify valid input conditions.
   Example:
   ```julia
   @pre sqrt(x) = x >= 0 "`x` is non-negative"
   ```

2. Postconditions (@post): Define expected output properties. Use __ret__ to refer to the function's return value.
   Example:
   ```julia
   @post push!(v, x) = __ret__ === v && length(__ret__) == length(v) + 1 "size of returned value is increased by 1"
   ```

3. Invariants (@invariant): State conditions that always hold for a data structure.
   Example: `@invariant Vector(v) = length(v) >= 0 "`v`'s length is non-negative"`

4. Placement: Put specifications outside function definitions. Note: you can add specs to functions defined by other libraries.
   Example:
   ```julia
   function f(x)
       # implementation
   end
   @pre f(x) = x > 0
   @post f(x) = __ret__ > x
   ```

5. Type specifications: Use Julia's dispatch system to specify different conditions for different methods.
   Example:
   ```julia
   function process(x::Integer)
       # implementation
   end
   function process(x::String)
       # implementation
   end
   @pre process(x::Integer) = x > 0 "`x` is positive"
   @pre process(x::String) = !isempty(x) "`x` is not empty"
   ```

6. Multiple specifications: Use multiple @pre/@post for complex conditions. Avoid redundancy and incompleteness.
   Good example (complete):
   ```julia
   @post push!(v, x) = __ret__ === v && length(__ret__) == length(v) + 1 "`v`'s size is increased by 1"
   @post push!(v, x) = __ret__[end] == x "`x` is at the end of `v`"
   ```
   Bad example (redundant):
   ```julia
   @pre sort(arr) = length(arr) > 0 "`arr` is not empty"
   @pre sort(arr) = !isempty(arr) "`arr` has elements"
   ```
   Bad example (incomplete):
   ```julia
   @post push!(v, x) = __ret__ === v && length(__ret__) == length(v) + 1 "`v`'s size is increased by 1"
   ```
   This specification is incomplete because the postcondition doesn't check if the pushed item is actually at the end of the vector.

7. Logical operators: Use &&, ||, ! for complex conditions.
   Example: `@pre f(x, y) = x > 0 && y > 0 || x < 0 && y < 0 "`x` and `y` have the same sign"`

8. Quantifiers: Use `all` and `any` for collection-wide conditions.
   Example: `@post sort(arr) = all(arr[i] <= arr[i+1] for i in 1:length(arr)-1) "`arr` is sorted"`

9. Checking specifications: Use specapply() or @specapply macro, which checks all nested function calls.
   Example:
   ```julia
   using Test
   @test_throws PreconditionError specapply(sqrt, -1)
   @test specapply(sqrt, 4) ≈ 2
   ```

10. Documentation: Use string literals after specifications for explanations.
    Example: `@pre f(x) = x > 0 "`x` is positive for logarithm calculation"`

11. Avoid redundant type checking: Do not add specifications that can be enforced by Julia's type system.
    Bad example: `@pre process(x::String) = typeof(x) == String "`x` is a string"`
    Good example: Simply use Julia's type dispatch: `function process(x::String)`
