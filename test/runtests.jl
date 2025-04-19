using Spec
using Test

@testset "Basic precondition tests" begin
    f(x::Float64) = x * sqrt(x)
    @pre f(x::Float64) = x > 0 "x must be positive"
    @test specapply(f, 10.0) == 10.0 * sqrt(10.0)
    @test_throws PreconditionError specapply(f, -10.0)
    @pre f(x::Float64) = x < 10.0 "x must be less than 10.0"
    @test_throws PreconditionError specapply(f, 15.0)
end

@testset "Multiple Preconditions" begin
    "Body mass index"
    bmi(height, weight) = weight / (height * height)
    @pre bmi(height, weight) = height > 0 "height must be positive"
    @pre bmi(height, weight) = weight > 0 "weight must be positive"
    
    @test specapply(bmi, 1.8, 70.0) ≈ 70.0 / (1.8 * 1.8)
    @test_throws PreconditionError specapply(bmi, -1.8, 70.0)
    @test_throws PreconditionError specapply(bmi, 1.8, -70.0)
end

@testset "Post conditions" begin
    "p implies q"
    p → q = !(p && !q)

    "is `xs` sorted"
    issorted(xs) = 
      all((xs[i] < xs[j] → i < j for i = 1:length(xs) for j = 1:length(xs) if i != j))

    "Is `y` sorted version of `x`"
    isysortedx(xs, ys) = 
      length(ys) == length(xs) && all((y in xs for y in ys)) && issorted(ys)

    mysort(x) = sort(x)
    @post mysort(x) = isysortedx(x, __ret__) "Result is sorted version of input"

    fakesort(x) = x
    @post fakesort(x) = isysortedx(x, __ret__) "Result is sorted version of input"
    
    @test specapply(mysort, [3, 1, 2]) == [1, 2, 3]
    @test_throws PostconditionError specapply(fakesort, [3, 1, 2])
end

@testset "Absolute value function" begin
    f(x) = abs(x)
    @post f(x) = __ret__ >= 0 "Return value is non-negative"
    
    @test specapply(f, 5) == 5
    @test specapply(f, -5) == 5
    @test specapply(f, 0) == 0
end

@testset "String functions" begin
    search(text, pattern) = occursin(pattern, text)
    @pre search(text, pattern) = !isempty(pattern) "Search pattern must not be empty"
    
    @test specapply(search, "hello world", "world")
    @test !specapply(search, "hello world", "universe")
    @test_throws PreconditionError specapply(search, "hello world", "")
end

# More complex examples with multiple arguments
@testset "Complex function with multiple arguments" begin
    function calculate_area(shape::Symbol, args...)
        if shape == :rectangle
            length, width = args
            return length * width
        elseif shape == :circle
            radius = args[1]
            return π * radius^2
        elseif shape == :triangle
            base, height = args
            return 0.5 * base * height
        else
            error("Unknown shape")
        end
    end
    
    @pre calculate_area(shape::Symbol, args...) = length(args) > 0 "Must provide shape dimensions"
    @pre calculate_area(shape::Symbol, args...) = all(arg > 0 for arg in args) "All dimensions must be positive"
    @post calculate_area(shape::Symbol, args...) = __ret__ > 0 "Area must be positive"
    
    @test specapply(calculate_area, :rectangle, 5, 10) == 50
    @test specapply(calculate_area, :circle, 2) ≈ π * 4
    @test specapply(calculate_area, :triangle, 4, 6) == 12
    
    @test_throws PreconditionError specapply(calculate_area, :rectangle)
    @test_throws PreconditionError specapply(calculate_area, :rectangle, -5, 10)
end

# TODO: Future tests with keyword arguments will be added later

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