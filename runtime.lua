local ffi      = require('ffi')
local util     = require('util')
local compiler = require('compiler')
local system   = require('system')

package.loaded['@system'] = system

local function loader(filename)
   if string.match(filename, "%.nga") then
      local namelist = { }
      for path in string.gmatch(NYANGA_PATH, "([^;]+)") do
         if path ~= "" then
            local filepath = path .. "/" .. filename
            local file = io.open(filepath, "r")
            if file then
               local src = file:read("*a")
               local pth = { }
               local code = compiler.compile(src, '@'..filepath)
               local body = assert(loadstring(code, '@'..filepath))
               setfenv(body, GLOBAL)
               return body
            end
         end
      end
   end
end

table.insert(package.loaders, loader)

local function __is__(a, b)
   if type(a) == 'cdata' then
      return ffi.istype(a, b)
   else
      local m = getmetatable(a)
      while m do
         if m == b then return true end
         m = m.__base
      end
   end
   return false
end

local Class = { }
function Class.__call(class, ...)
   local obj
   if class.apply then
      obj = class:apply(...)
   else
      obj = { }
      setmetatable(obj, class)
      if class.__members__.self then
         class.__members__.self(obj, ...)
      end
   end
   return obj
end
local function class(name, base, body)
   local class = { __name = name, __base = base }
   class.__getters__ = setmetatable({ }, { __index = base.__getters__ })
   class.__setters__ = setmetatable({ }, { __index = base.__setters__ })
   class.__members__ = setmetatable({ }, { __index = base.__members__ })

   function class.__index(o, k)
      if class.__getters__[k] then
         return class.__getters__[k](o)
      end
      return class.__members__[k]
   end
   function class.__newindex(o, k, v)
      if class.__setters__[k] then
         class.__setters__[k](o, v)
      else
         rawset(o, k, v)
      end
   end
   function class.__tostring(o)
      if o.toString then
         return o:toString()
      else
         return string.format('<%s>:%p', name, o)
      end
   end
   body(setmetatable(class, Class), base.__members__)
   return class
end

local Object = setmetatable({ }, Class)
Object.self = function()
   return Object:create({ }, { })
end
function Object:defineProperties(obj, props)
   --local m = getmetatable(obj)
   local m = obj
   for k, d in pairs(props) do
      if d.get then
         m.__getters__[k] = d.get
      elseif d.set then
         m.__setters__[k] = d.set
      else
         m.__members__[k] = d.value
      end
   end
   return obj 
end
function Object:create(proto, props)
   local m = { }
   m.__getters__ = { }
   m.__setters__ = { }
   m.__members__ = setmetatable({ }, { __index = proto })
   function m.__index(o, k)
      if m.__getters__[k] then
         return m.__getters__[k](o)
      elseif m.__members__[k] ~= nil then
         return m.__members__[k]
      end
      return nil
   end
   function m.__newindex(o, k, v)
      if m.__setters__[k] then
         m.__setters__[k](o, v)
      else
         rawset(o, k, v)
      end
   end
   function m.__tostring(o)
      if o.toString then
         return o:toString()
      else
         return string.format('<Object>:%p', o)
      end
   end

   local o = { }
   for k, d in pairs(props) do
      if d.get then
         m.__getters__[k] = d.get
      elseif d.set then
         m.__setters__[k] = d.set
      else
         o[k] = d.value
      end
   end
   return setmetatable(o, m)
end

local Array = setmetatable({ __members__ = { } }, Class)
function Array:apply(...)
   return setmetatable({
      length = select('#', ...), [0] = select(1, ...), select(2, ...)
   }, self)
end
function Array:self() end
function Array.__iter(a)
   local l = a.length
   local i = -1
   return function(a)
      i = i + 1
      local v = a[i]
      if i < l then
         return i, v
      end
      return nil
   end, a
end
function Array.__pairs(a)
   local l = a.length
   return function(a, p)
      local i = p + 1
      local v = a[i]
      if i < l then
         return i, v
      end
   end, a, -1
end
function Array.__members__:join(sep)
   return table.concat({ Array.__spread(self) }, sep)
end
function Array.__spread(a)
   return unpack(a, 0, a.length - 1)
end
function Array.__len(a)
   return a.length
end
function Array.__tostring(a)
   if a.toString then
      return a:toString()
   end
   return string.format("[Array: %p]", self)
end
function Array.__index(a, k)
   if Array.__members__[k] then
      return Array.__members__[k]
   end
   return nil
end
function Array.__newindex(a, i, v)
   if type(i) == 'number' and i >= a.length then
      a.length = i + 1
   end
   rawset(a, i, v)
end
function Array.__members__:toString()
   local b = { }
   for i=0, self.length - 1 do
      b[#b + 1] = tostring(self[i])
   end
   return table.concat(b, ', ')
end
function Array.__members__:map(f)
   local b = Array()
   for i=0, self.length - 1 do
      b[i] = f(i, self[i])
   end
   return b
end

local function try(try, catch, finally)
   local ok, rv = xpcall(try, catch)
   if finally then finally() end
   return rv
end

local String = class("String", Object, function(self, super)
   for k, v in pairs(getmetatable("")) do
      self[k] = v
   end
   Object:defineProperties(self, {
      self = {
         value = function(self, that)
            return tostring(that)
         end
      },
      match = {
         value = function(self, regex)
            if type(regex) == 'string' then
               return string.match(self, regex)
            else
               local capt = Array()
               while true do
                  local result = regex:exec(self)
                  if result == nil then
                     break
                  end
                  capt[capt.length] = result[1]
               end
               if capt.length > 0 then
                  return capt
               else
                  return nil
               end
            end
         end
      },
      format = {
         value = string.format
      },
      find = {
         -- TODO: regex support
         value = string.find
      },
      toString = {
         value = function(self)
            return self
         end
      }
   })
end)
debug.setmetatable("", String)

local RegExp = class("RegExp", Object, function(self, super)
   local pcre = require('pcre')

   Object:defineProperties(self, {
      self = {
         value = function(self, source, flags)
            flags = flags or ''
            self.index = 0
            self.input = ''
            self.source  = source
            local opts = 0
            if string.find(flags, 'i') then
               opts = opts + pcre.lib.PCRE_CASELESS
               self.ignoreCase = true
            end
            if string.find(flags, 'm') then
               opts = opts + pcre.lib.PCRE_MULTILINE
               self.multiLine = true
            end
            self.pattern = assert(pcre.compile(source, opts))
            if string.find(flags, 'g') then
               self.global = true
            end
         end
      },
      exec = {
         value = function(self, str)
            if self.input ~= str then
               self.input = str
               self.index = 0
            end
            local result = pcre.execute(self.pattern, self.input, self.index)
            if type(result) == 'table' then
               self.index = self.index + #result[1] + 1
               return result
            elseif result == pcre.lib.PCRE_ERROR_NOMATCH then
               return nil
            else
               error(result, 2)
            end
         end
      },
      test = {
         value = function(self, str)
            local result = pcre.execute(self.pattern, str)
            if type(result) == 'table' then
               return true
            else
               return false
            end
         end
      },
      toString = {
         value = function(self)
            return string.format('RegExp(%q)', tostring(self.source))
         end
      }
   })
end)

local Error = class("Error", Object, function(self, super)
   Object:defineProperties(self, {
      self = {
         value = function(self, mesg)
            self.message = mesg
            self.trace = debug.traceback(mesg, 2)
         end
      },
      toString = {
         value = function(self)
            return self.message
         end
      }
   })
end)

local function spread(o)
   local m = getmetatable(o)
   if m and m.__spread then
      return m.__spread(o)
   end
   return unpack(o)
end
local function each(o, ...)
   if type(o) == 'function' then
      return o, ...
   end
   local m = getmetatable(o)
   if m and m.__iter then
      return m.__iter(o, ...)
   end
   return pairs(o)
end

local Range = { }
Range.__index = Range
function Range.__in(self, that)
   local n = tonumber(that)
   if type(n) == 'number' and n == n then
      return n >= self.min and n <= self.max
   end
   return false
end
function Range.__iter(self)
   local i, r = self.left, self.right
   local n = i <= r and 1 or -1
   return function()
      local j = i
      i = i + n
      if n > 0 and j > r then
         return nil
      elseif n < 0 and j < r then
         return nil
      end
      return j
   end
end
local function range(left, right, inclusive)
   return setmetatable({
      left = left,
      right = right,
      inclusive = inclusive == true,
   }, Range)
end
local function __in__(self, that)
   local m = getmetatable(that)
   if m and m.__in then
      return m.__in(self)
   end
   if type(that) == 'table' then
      return rawget(that, self) ~= nil
   end
   return false
end

local function import(from, ...)
   local mod  = require(from)
   local list = { }
   for i=1, select('#', ...) do
      list[i] = mod[select(i, ...)]
   end
   return unpack(list)
end

GLOBAL = setmetatable({
   try    = try;
   Object = Object;
   Array  = Array;
   Error  = Error;
   RegExp = RegExp;
   class  = class;
   import = import;
   system = system;
   __range__  = range;
   __spread__ = spread;
   __each__   = each;
   __in__  = __in__;
   __is__  = __is__;
   throw   = error;
   assert  = function(...) return assert(...) end;
   print   = function(...) print(...) end;
}, { __index = _G })

local function run(code, ...)
   setfenv(code, GLOBAL)
   system.run(code)
end

local function runfile(name, ...)
   local file = assert(io.open(name, 'r'))
   local code = file:read('*a')
   file:close()
   local main = assert(loadstring(compiler.compile(code, '@'..name)))
   setfenv(main, GLOBAL)
   system.run(main, ...)
end

return {
   run     = run;
   runfile = runfile;
}

