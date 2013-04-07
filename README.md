LuaFn is an EXPERIMENTAL, lazy implementation of the traditional functional primitives (such as map, filter, cons, etc.) in Lua.

### Rationale

My reasons for writing LuaFn were (1) to learn Lua and (2) to better understand how functional languages, such as Haskell and Clojure, implement their sequence libraries, which are also lazy. As such, I have very little interest in optimizing LuaFn beyond what's needed to make it usable.

### A word on performance

As a rule of thumb, the lazy functions are about two orders of magnitude slower than eager implementations of the same algorithms. The overhead associated with *cons* and *lazy* accounts for the vast majority of that slowdown. LuaFn does include some eager implementations in its eager module, and I will probably write something similar to Clojure's reducers at some point, but for now, this is not the best choice if you intend on working with large sequences.

### Example

    F = require("core")
    N = require("numeric")
    S = require("strings")
    
    -- Print the first 20 Fibonacci numbers in a really elaborate way:
    print(S.str(F.take(20,
                       F.map(S.str,
                       F.partition(4,
                                   F.interleave(N.naturals(),
                                                F.repeatedly(F.constantly(": ")),
                                                N.fib(),
                                                F.repeatedly(F.constantly("\n"))))))))

