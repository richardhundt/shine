local parser      = require('parser')
local transformer = require('transformer')
local generator   = require('generator')
local util        = require('util')

local function compile(src, name)
   local srctree = parser.parse(src)
   --print("SRC:", util.dump(srctree))
   local dsttree = transformer.transform(srctree, src)
   --print("DST:", util.dump(dsttree))
   local luacode = generator.generate(dsttree, name)
   --local outfile = io.open("a.out", "w+")
   --outfile:write(luacode)
   --outfile:close()
   --print("LUA:", luacode)

   --[[
   local jbc = require("jit.bc")
   local fn = assert(loadstring(luacode))
   jbc.dump(fn, nil, true)
   --]]

   return luacode
end

return {
   compile = compile
}
