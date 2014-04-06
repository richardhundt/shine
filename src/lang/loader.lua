local tvm        = require('tvm')
local parser     = require('shine.lang.parser')
local translator = require('shine.lang.translator')

local magic = string.char(0x1b, 0x4c, 0x4a, 0x01)

local function loadchunk(code, name, opts)
   if string.sub(code, 1, #magic) ~= magic then
      local srctree = parser.parse(code, name, 1, opts)
      local dsttree = translator.translate(srctree, name, opts)
      code = tostring(dsttree)
   end
   return tvm.load(code, name)
end

local function loader(modname, opts)
   local filename, havepath
   if string.find(modname, '/') or string.sub(modname, -4) == '.shn' then
      filename = modname
   else
      filename = package.searchpath(modname, package.path)
   end
   if filename then
      local file = io.open(filename)
      if file then
         local code = file:read('*a')
         file:close()
         if string.sub(filename, -4) == '.shn' then
            return assert(loadchunk(code, filename, opts))
         elseif string.sub(filename, -3) == '.tp' then
            return tvm.load(code, '@'..filename)
         else
            require("lunokhod")
            return assert(loadstring(code, '@'..filename))
         end
      else
         -- die?
      end
   end
end

return {
   loader = loader;
   loadchunk = loadchunk;
}

