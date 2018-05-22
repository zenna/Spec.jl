# Spec.jl

[![Build Status](https://travis-ci.org/zenna/Spec.jl.svg?branch=master)](https://travis-ci.org/zenna/Spec.jl)

[![codecov.io](http://codecov.io/github/zenna/Spec.jl/coverage.svg?branch=master)](http://codecov.io/github/zenna/Spec.jl?branch=master)

A package for expressing specifications.

# Usage

Spec has a number of primitives for specfiying correctness properties.
Currently these serve both as functional tests (like asserts which can be disabled globally), or just a non-executable documentation.

```julia

function f()
  @pre x + y == 2
end
```