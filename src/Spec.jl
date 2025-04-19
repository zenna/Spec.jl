"Testing and specification"
module Spec

using Cassette
using MLStyle
using Test
import Random

include("util.jl")
include("prepost.jl")

## Unit Testing
include("sampletype.jl")
include("testing.jl")      # Testing Tools

## Helper Macros
include("macros.jl")


export @pre,
       @with_pre,
       with_pre,
       @post,
       @invariant,
       walktests,
       @spec,
       specapply

end
