using Spec
using Test

f(x::Float64) = x * sqrt(x)
@pre f(x::Float64) = x > 0 "x must be positive"
@test specapply(f, 10.0) == 10.0 * sqrt(10.0)
@test_throws PreconditionError specapply(f, -10.0)

# Multiple Preconditions
"Body mass index"
bmi(height, weight) = height / weight 
@pre bmi(height, weight) = height > 0 "height must be positive"
@pre bmi(height, weight) = weight > 0 "weight must be positive"

# Post conditions
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

# Invariant

struct FriendMatrix
  x::Matrix
end
@invariant x::FriendMatrix issymetric(x)

Spec.overdub(::SpecCtx, x::FriendMatrix, args...) = issymetric(issymetric)