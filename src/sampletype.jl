export sampletype, samplemethodargs

"`sampletype(rng, ::Type{T})` samples an element in the of type `T`"
function sampletype end

function sampletype(rng, ::Type{T}) where {T <: Tuple}
  T isa UnionAll && error("UnionAll not implemented")
  tuple((sampletype(rng, type) for type in @show T.parameters)...)
end

"""
`samplemethodargs(rng, mthd::Method)`
  
Samples arguments for method `mthd` using rng `rng`

```
f(x::Int, y::Real) = x + y
args = samplemethodargs(f)
f(args...)
```
"""
samplemethodargs(rng, mthd::Method)  = sampletype(rng, Tuple{mthd.sig.parameters[2:end]...})
samplemethodargs(mthd) = samplemethodargs(Random.GLOBAL_RNG, mthd)

# Default samplers

# sampletype(rng, ::Type{Symbol}) = 
# sampletype(rng, ::Type{<:NamedTuple{K, V}}) where {K, V} = sample(rng, NamedTuple{K, V}) 
# sampletype(rng, ::Type{<:NamedTuple}) = sampletype(rng, NamedTuple{K, V}) 

struct IsAbstract end
struct NotIsAbstract end
struct IsConcrete end
struct NotIsConcrete end

sampletype(rng, ::Type{T}) where {T <:Number} = rand(rng, T)

traitisabstract(::Type{T}) where T = isabstracttype(T) ? IsAbstract() : NotIsAbstract()
traitisconcrete(::Type{T}) where T = isconcretetype(T) ? IsConcrete() : IsConcrete()

sampletype(rng, ::Type{T}) where {T <: Union} = sampletype(rng, (T.a, T.b))

sampletype(rng, ::Type{Complex{T}}) where T = Complex(sampletype(T), sampletype(T))

sampletype(rng, ::IsAbstract, _, T) = sampletype(rng, subtypes(T))

sampletype(rng, ::Type{T}) where T = sampletype(rng, traitisabstract(T), traitisconcrete(T))


sampletype(x) = sampletype(Random.GLOBAL_RNG, x)