
"""
Walk through `test_dir` directory and execute all tests, excluding `exclude`

```jldoctests
julia> using Spec
julia> walktests(Spec)
```
"""
function walktests(testmodule::Module;
                   test_dir = joinpath(Pkg.dir(string(testmodule)), "test", "tests"),
                   exclude = [])
  tests = setdiff(readdir(test_dir), exclude)
  print_with_color(:blue, "Running tests:\n")

  # Single thread
  srand(345679)
  with_pre() do
    res = map(tests) do t
      println("Testing: ", t)
      include(joinpath(test_dir, t))
      nothing
    end
  end

  # print method ambiguities
  println("Potentially stale exports: ")
  display(Base.Test.detect_ambiguities(testmodule))
  println()
end
