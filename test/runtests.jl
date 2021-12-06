using Spec
using Test

f(x::Float64) = x * sqrt(x)
@pre f(x::Float64) = x > 0 "x must be positive"
@test specapply(f, 10.0) == 10.0 * sqrt(10.0)
@test_throws PreconditionError specapply(f, -10.0)
@pre f(x::Float64) = x < 10.0 "x must be less than 10.0"

# Multiple Preconditions
"Body mass index"
bmi(height, weight) = height / weight 
@pre bmi(height, weight) = height > 0 "height must be positive"

# Post conditions
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

fakesort(x) = x
@post fakesort(x) = isysortedx(x, __ret__) "Result is sorted version of input"
@test_throws PostconditionError specapply(fakesort, rand(10))

# ## mutating
# @post sort!(x) = isysortedx(__pre__.x, __ret__) "Result is sorted version of input"

# function mutate!(x, xs)
#   push!(x, xs)
# end
# @post mutate!(x, xs) = x in __post__.xs "x is in the post state xs"

# # Invariant
# struct FriendMatrix
#   x::Matrix
# end
# @invariant x::FriendMatrix issymetric(x)

# Spec.overdub(::Spec.SpecCtx, x::FriendMatrix, args...) = issymetric(issymetric)