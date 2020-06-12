using Spec
using Test

@testset "Test Post" begin
  f(x) = x * x
  @post ret > 0

  specapply(f, 3)

  g(x) = -1
  @post g(x) = ret > 0
  specapply(g, 3)

function f(x)
  x
end


