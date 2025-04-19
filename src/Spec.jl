"Testing and specification"
module Spec

using CassetteOverlay
using MLStyle
using Test
# import Pkg
import Random


include("overlay.jl")                # brings in SpecOverlay & specapply
include("util.jl")
include("macros.jl")                 # Defines transform functions
include("prepost.jl")                # Defines @gen_pre/@gen_post

## Unit Testing
include("sampletype.jl")
include("testing.jl")      # Testing Tools

## Export everything needed
export @pre,
       @post,
       @invariant,
       specapply,
       PreconditionError,
       PostconditionError

end
