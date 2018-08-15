using Spec

f(x, y) = x / y 
@spec y !== 0

g(x) = asin(x) / x
@spec -1 <= x <= 1 x !== 0

check(f, (::Float64, ::Float64))

