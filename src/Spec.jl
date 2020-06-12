"Testing and specification"
module Spec

using Cassette
using Test
import Pkg
import Random

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
