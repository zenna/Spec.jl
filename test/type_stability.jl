using Spec
using Test

@testset "Type stability" begin
    ts_f(x::Float64) = x * sqrt(x)
    @pre ts_f(x::Float64) = x > 0 "x>0"
    @test @inferred specapply(ts_f, 10.0) == 10.0 * sqrt(10.0)

    ts_g(x::Int) = x + 1
    @pre ts_g(x::Int) = x >= 0 "x>=0"
    @test @inferred specapply(ts_g, 2) == 3

    ts_h(x::Int) = iseven(x)
    @test @inferred specapply(ts_h, 4) == true

    ts_tup(x::Int, y::Int) = (x, y, x + y)
    @pre ts_tup(x::Int, y::Int) = x >= 0 "x>=0"
    @test @inferred specapply(ts_tup, 1, 2) == (1, 2, 3)

    ts_nt(x::Int) = (x = x, y = x + 1)
    @test @inferred specapply(ts_nt, 3) == (x = 3, y = 4)

    ts_vec(x::Int) = [x, x + 1, x + 2]
    @test @inferred specapply(ts_vec, 1) == [1, 2, 3]

    struct TsPoint
        x::Float64
        y::Float64
    end
    ts_point(x::Float64, y::Float64) = TsPoint(x, y)
    @test @inferred specapply(ts_point, 1.0, 2.0) == TsPoint(1.0, 2.0)

    ts_kw(x::Int; y::Int = 1) = x + y
    @pre ts_kw(x::Int; y::Int = 1) = y >= 0 "y>=0"
    @test @inferred specapply(ts_kw, 2; y = 3) == 5

    ts_kw2(x::Float64; scale::Float64 = 1.0, shift::Float64 = 0.0) = x * scale + shift
    @post ts_kw2(__ret__, x::Float64; scale::Float64 = 1.0, shift::Float64 = 0.0) =
        __ret__ >= x "ret>=x"
    @test @inferred specapply(ts_kw2, 2.0; scale = 2.0, shift = 1.0) == 5.0

    ts_sumvec(xs::Vector{Int}) = sum(xs)
    @pre ts_sumvec(xs::Vector{Int}) = !isempty(xs) "nonempty"
    @test @inferred specapply(ts_sumvec, [1, 2, 3]) == 6

    ts_k(x::Int) = x * 2
    @pre ts_k(x::Int) = x < 10 "x<10"
    @post ts_k(__ret__, x::Int) = __ret__ == x * 2 "ret==x*2"
    @test @inferred Spec.prepostcall(ts_k, 4) == 8
end
