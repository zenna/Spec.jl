using Test
using Spec

# Import the module that contains the expr.jl functions
# Adjust the import statement based on your actual module structure
include("../src/expr.jl")

@testset "Expression Utilities Tests" begin
    
    @testset "is_call_expr" begin
        # Simple function call
        @test is_call_expr(:(f(x)))
        
        # Function call with multiple arguments
        @test is_call_expr(:(f(x, y, z)))
        
        # Function call with keyword arguments
        @test is_call_expr(:(f(x; y=1)))
        
        # Function call with default arguments
        @test is_call_expr(:(f(x, y=1, z=2)))
        
        # Function call with splat operator
        @test is_call_expr(:(f(x...)))
        
        # Not a call expression
        @test !is_call_expr(:(x + y))
    end
    
    @testset "is_top_level_func_def" begin
        # Function definition with function...end syntax
        @test is_top_level_func_def(:(function f(x) x + 1 end))
        
        # Function definition with compact syntax
        @test is_top_level_func_def(:(f(x) = x + 1))
        
        # Function definition with operator
        @test is_top_level_func_def(:((+)(a, b) = a - b))
        
        # Function definition with type parameters
        @test is_top_level_func_def(:(function f{T}(x::T) x end))
        
        # Function definition with empty stub
        @test is_top_level_func_def(:(function g end))
        
        # Generated function
        @test is_top_level_func_def(:(@generated function h(x) x end))
        
        # Not a function definition
        @test !is_top_level_func_def(:(x = 1))
        @test !is_top_level_func_def(:(if x > 0 x else -x end))
    end
    
    @testset "extract_function_call" begin
        # Simple function definition
        @test extract_function_call(:(f(x) = x + 1)) == :(f(x))
        
        # Function with type annotations
        @test extract_function_call(:(f(x::Int, y::Real) = x > 0)) == :(f(x::Int, y::Real))
        
        # Function with multiple arguments
        @test extract_function_call(:(function f(a, b, c) a + b + c end)) == :(f(a, b, c))
        
        # Test error case with invalid expression
        @test_throws ArgumentError extract_function_call(:(x = 1))
    end
    
    @testset "call_expr_to_call_args" begin
        # Simple function call
        @test call_expr_to_call_args(:(f(x))) == [:f, :x]
        
        # Function call with multiple arguments
        @test call_expr_to_call_args(:(f(x, y, z))) == [:f, :x, :y, :z]
        
        # Function call with keyword arguments
        expr = call_expr_to_call_args(:(f(x; y=1)))
        @test expr[1] isa Expr && expr[1].head == :parameters
        @test expr[2] == :f
        @test expr[3] == :x
        
        # Test error case with invalid expression
        @test_throws ArgumentError call_expr_to_call_args(:(x + y))
    end
    
    @testset "extract_fdef_components" begin
        # Simple function definition
        components = extract_fdef_components(:(f(x) = x + 1))
        @test components.f == :f
        @test components.positional_args == [:x]
        @test isempty(components.default_args)
        @test isempty(components.keyword_args)
        @test components.body == :(x + 1)
        
        # Function with default arguments
        components = extract_fdef_components(:(f(x, y=1, z=2) = x + y + z))
        @test components.f == :f
        @test components.positional_args == [:x]
        @test length(components.default_args) == 2
        @test components.default_args[1].args[1] == :y
        @test components.default_args[1].args[2] == 1
        @test components.body == :(x + y + z)
        
        # Function with keyword arguments
        expr = :(f(x; y=1, z=2) = x + y + z)
        expr.args[2].args[1] = Expr(:parameters, Expr(:kw, :y, 1), Expr(:kw, :z, 2))
        components = extract_fdef_components(expr)
        @test components.f == :f
        @test components.positional_args == [:x]
        @test length(components.keyword_args) == 1
        @test components.keyword_args[1].head == :parameters
        
        # Test error case with invalid expression
        @test_throws ArgumentError extract_fdef_components(:(x = 1))
    end
    
    # Tests for is_valid_expr would depend on implementation details
    # Since it's not fully implemented (only handles call expressions), 
    # we can add a basic test
    @testset "is_valid_expr" begin
        # Valid call expression
        @test_nowarn is_valid_expr(:(f(x)))
        
        # Invalid expression (should error based on current implementation)
        @test_throws ErrorException is_valid_expr(:(x + y))
    end
end 