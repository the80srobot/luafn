local F = require("core")
local S = require("strings")
local N = require("numeric")

-- Print the first 20 Fibonacci numbers in a really elaborate way:
print(S.str(F.take(20, F.map(S.str, F.partition(4, F.interleave(N.naturals(), F.repeatedly(F.constantly(": ")), N.fibonacci(), F.repeatedly(F.constantly("\n"))))))))
