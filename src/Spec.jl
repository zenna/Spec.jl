__precompile__()
"Testing and specification"
module Spec

include("pre.jl")      # preconditions
include("testing.jl")      # preconditions

export @pre,
       @with_pre,
       with_pre,
       @post,
       @invariant,
       walktests

end
