using Spec
using Test

# Include expression utilities tests
include("expr_test.jl")

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

@testset "Functions with keyword arguments" begin
    # Simple function with keyword arguments
    function calculate_discount(price; discount_percent=0, min_price=0)
        if price < min_price
            return price
        end
        return price * (1 - discount_percent/100)
    end
    
    @pre calculate_discount(price; discount_percent, min_price) = price >= 0 "Price must be non-negative"
    @pre calculate_discount(price; discount_percent, min_price) = 0 <= discount_percent <= 100 "Discount must be between 0 and 100"
    @post calculate_discount(price; discount_percent, min_price) = __ret__ <= price "Discounted price should not exceed original price"
    
    # Test successful cases
    @test specapply(calculate_discount, 100.0, discount_percent=20) == 80.0
    @test specapply(calculate_discount, 50.0, discount_percent=10, min_price=30) == 45.0
    @test specapply(calculate_discount, 25.0, discount_percent=10, min_price=30) == 25.0
    
    # Test precondition failures
    @test_throws PreconditionError specapply(calculate_discount, -50.0, discount_percent=10)
    @test_throws PreconditionError specapply(calculate_discount, 100.0, discount_percent=110)
    
    # More complex function with multiple keyword arguments
    function configure_api(endpoint; timeout=30, retries=3, headers=Dict(), debug=false)
        config = Dict(
            "endpoint" => endpoint,
            "timeout" => timeout,
            "retries" => retries,
            "headers" => headers,
            "debug" => debug
        )
        return config
    end
    
    @pre configure_api(endpoint; timeout, retries) = !isempty(endpoint) "Endpoint cannot be empty"
    @pre configure_api(endpoint; timeout, retries) = timeout > 0 "Timeout must be positive"
    @pre configure_api(endpoint; timeout, retries) = retries >= 0 "Retries cannot be negative"
    @post configure_api(endpoint; timeout, retries, headers, debug) = __ret__["endpoint"] == endpoint "Endpoint in config matches input"
    
    # Test successful cases
    @test specapply(configure_api, "https://api.example.com")["endpoint"] == "https://api.example.com"
    @test specapply(configure_api, "https://api.example.com", timeout=60)["timeout"] == 60
    @test specapply(configure_api, "https://api.example.com", 
                    headers=Dict("Authorization" => "Bearer token"))["headers"]["Authorization"] == "Bearer token"
    @test specapply(configure_api, "https://api.example.com", debug=true)["debug"] == true
    
    # Test failures
    @test_throws PreconditionError specapply(configure_api, "")
    @test_throws PreconditionError specapply(configure_api, "https://api.example.com", timeout=0)
    @test_throws PreconditionError specapply(configure_api, "https://api.example.com", retries=-1)
end