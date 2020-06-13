using Spec
using Test

f(x::Float64) = x * sqrt(x)
@pre f(x::Float64) = x > 0 "x must be positive"
@test specapply(f, 10.0) == 10.0 * sqrt(10.0)
@test_throws PreconditionError specapply(f, -10.0)

# Multiple Preconditions
"Body mass index"
bmi(height, weight) = height / weight 
@pre bmi(height, weight) = height > 0 "Height must be positive"
@pre bmi(height, weight) = weight > 0 "Weight must be positive"



"Body mass index"
bmi(height, weight) = height / weight 
@pre bmi height > 0 "Height must be positive"
@pre bmi weight > 0 "Weight must be positive"



@testset "Test Post" begin
  f(x) = x * x
  @post ret > 0

  specapply(f, 3)

  g(x) = -1
  @post g ret > 0
  @post "Input must be greater than result" g(x) x > ret
  specapply(g, 3)

function f(x)
  x
end


