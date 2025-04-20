# Spec.jl

[![codecov.io](http://codecov.io/github/zenna/Spec.jl/coverage.svg?branch=master)](http://codecov.io/github/zenna/Spec.jl?branch=master)

Spec.jl is small library for specfiying correctness properties of programs.
These specifications can be used as documentation, for testing, and for debugging.

# Usage

### Pre Conditions

Preconditions are statements (also known as propositions or conditions) that must be true about the input before the function is executed.
One purpose of using preconditions is for documentation -- by specifying precise constraints on the function's behaviour we are communicating more clearly what we expect it to do.

Preconditions are specified using the `@pre` macro, for example:

```julia
f(x::Float64) = x * sqrt(x)
@pre f(x::Float64) = x > 0 "x must be positive"
```

This should be interpreted as defining a precondition for the method `f(::Float64)` that specifies that the input `x` should be positive.

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

## Using Specifications 
By default, pre and post conditions will not affect the behaviour of your program at all, and incur no runtime cost.
To actually check specifications we use `specapply`:

```julia
specapply(f, args...)
```

This will evaluate `f(args)`, but for all function applications encountered in the execution of `f(args...)`, each and every associated spec will be checked.

## Testing with Spec

You can use Spec in combination with Julia's built-in Test module for testing. Here's an example:

```julia
using Spec
using Test

f(x::Float64) = x * sqrt(x)
@pre f(x::Float64) = x > 0 "x must be positive"
@test specapply(f, 10.0) == 10.0 * sqrt(10.0)
@test_throws PreconditionError specapply(f, -10.0)

# Testing post-conditions
fakesort(x) = x
@post fakesort(x) = isysortedx(x, __ret__) "Result is sorted version of input"
@test_throws PostconditionError specapply(fakesort, rand(10))
```

This approach allows you to test both the correctness of your functions and the effectiveness of your specifications.

# Mini Guide -- How to write good Specs

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

3. Placement: Put specifications outside function definitions. Note: you can add specs to functions defined by other libraries.
   Example:
   ```julia
   function f(x)
       # implementation
   end
   @pre f(x) = x > 0
   @post f(x) = __ret__ > x
   ```

4. Type specifications: Use Julia's dispatch system to specify different conditions for different methods.
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

5. Multiple specifications: Use multiple @pre/@post for complex conditions. Avoid redundancy and incompleteness.
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

6. Logical operators: Use &&, ||, ! for complex conditions.
   Example: `@pre f(x, y) = x > 0 && y > 0 || x < 0 && y < 0 "`x` and `y` have the same sign"`

7. Quantifiers: Use `all` and `any` for collection-wide conditions.
   Example: `@post sort(arr) = all(arr[i] <= arr[i+1] for i in 1:length(arr)-1) "`arr` is sorted"`

8. Documentation: Use string literals after specifications for explanations.
   Example: `@pre f(x) = x > 0 "`x` is positive for logarithm calculation"`

9. Avoid redundant type checking: Do not add specifications that can be enforced by Julia's type system.
   Bad example: `@pre process(x::String) = typeof(x) == String "`x` is a string"`
   Good example: Simply use Julia's type dispatch: `function process(x::String)`

10. Keyword argument limitations: When specifying preconditions or postconditions for functions with keyword arguments, always include all keyword arguments with their default values.
   Example:
   ```julia
   function calculate_discount(price; discount_percent=0, min_price=0)
       # implementation
   end
   
   # Good - explicitly includes all keyword arguments with their default values
   @pre calculate_discount(price; discount_percent=0, min_price=0) = price >= 0 "Price must be non-negative"
   
   # Bad - missing default values for keyword arguments
   @pre calculate_discount(price; discount_percent, min_price) = price >= 0 "Price must be non-negative"
   ```
   This limitation exists because the implementation needs to match keyword arguments exactly when checking preconditions and postconditions.

# Planned Features (Not Yet Implemented)

## @specapply Macro

A convenient macro alternative to `specapply` would be `@specapply`, which is mentioned in examples but not yet implemented:

```julia
# This syntax is planned but not implemented yet
@specapply f(n)

# Currently, you must use:
specapply(f, n)
```

## State Capturing with __pre__ and __post__

For mutating functions, capturing the pre-state and post-state of variables would be useful:

```julia
# Not yet implemented
@post sort!(x) = isysortedx(__pre__.x, __ret__) "Result is sorted version of input"

function mutate!(x, xs)
  push!(x, xs)
end
# Not yet implemented
@post mutate!(x, xs) = x in __post__.xs "x is in the post state xs"
```

Currently, you can only use `__ret__` to refer to the return value, but not `__pre__` or `__post__` to capture state.

## Invariants

Invariants for data structures are planned but not yet implemented:

```julia
# Not yet implemented
struct FriendMatrix
  x::Matrix
end
@invariant x::FriendMatrix issymetric(x)
```

## QuickCheck-style Testing

Automated test generation based on specifications is planned:

```julia
# Not yet implemented
spectest(some_generic_function)
```

This would generate inputs consistent with preconditions and test the function with those inputs.
