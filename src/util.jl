"all methods that are consistent with `f(args...)`"
function matchingmethods(@nospecialize(f), args...)
  types = Base.typesof(f, args...)
  filter(methods(f).ms) do mthd
    types <: mthd.sig 
  end
end