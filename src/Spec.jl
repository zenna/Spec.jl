"Testing and specification"
module Spec

using CassetteOverlay
using MLStyle
using Test
import Random


include("overlay.jl")                # brings in SpecOverlay & specapply
include("util.jl")
include("expr.jl")                   # Expression utilities
include("macros.jl")                 # Defines transform functions
include("prepost.jl")                # Defines @gen_pre/@gen_post


export @pre,
       @post,
       @invariant,
       specapply,
       PreconditionError,
       PostconditionError

end
