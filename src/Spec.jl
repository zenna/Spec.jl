"Testing and specification"
module Spec

using Cassette
using MLStyle
using Test
import Pkg
import Random

import Cassette: overdub
export overdub

include("newspec.jl")
include("sampletype.jl")
# include("specs.jl")         # Specifications
# include("pre.jl")          # Preconditions
include("testing.jl")      # Testing Tools

export @pre,
       @with_pre,
       with_pre,
       @post,
       @invariant,
       walktests,
       @spec,
       specapply

end
