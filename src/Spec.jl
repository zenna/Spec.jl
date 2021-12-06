"Testing and specification"
module Spec

using Cassette
using MLStyle
using Test
# import Pkg
import Random

import Cassette: overdub
export overdub

include("util.jl")
include("prepost.jl")

## Unit Testing
include("sampletype.jl")
include("testing.jl")      # Testing Tools

## Helper Macros
include("macros.jl")

include("legacy.jl")


export @pre,
       @with_pre,
       with_pre,
       @post,
       @invariant,
       walktests,
       @spec,
       specapply

end
