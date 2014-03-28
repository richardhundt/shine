--[=[
Copyright (C) 2013-2014 Richard Hundt and contributors.
See Copyright Notice in shine
]=]

local loader = require("shine.lang.loader").loader
table.insert(package.loaders, 1, loader)

local ffi  = require('ffi')
local lpeg = require('lpeg')
local null = ffi.cast('void*', 0x0)

local Class
local Range
local Object

local export = { }

local type, tonumber, tostring = _G.type, _G.tonumber, _G.tostring
local getmetatable, setmetatable = _G.getmetatable, _G.setmetatable
local xpcall = _G.xpcall

local __is__, __match__

local Meta = { }
Meta.__index = Meta
Meta.__members__ = { }
Meta.__getters__ = { }
Meta.__setters__ = { }
Meta.__getindex = rawget
Meta.__setindex = rawset
Meta.__tostring = function(o)
   if o.__tostring__ then return o:__tostring__() end
   return tostring(rawget(o, '__name') or type(o))
end

local Function = setmetatable({ }, Meta)
Function.__tostring = function(self)
   local info = debug.getinfo(self, 'un')
   local nparams = info.nparams
   local params = {}
   for i = 1, nparams do
      params[i] = debug.getlocal(self, i)
   end
   if info.isvararg then params[#params+1] = '...' end
   return string.format('function(%s): %p', table.concat(params,', '), self)
end
Function.clone = function(self)
   copy = loadstring(string.dump(self))
   info = debug.getinfo(self, 'u')
   for i=1, info.nups do
      debug.upvaluejoin(copy, i, self, i)
   end
   setfenv(copy, getfenv(self))
   return copy
end
debug.setmetatable(function() end, Function)

local Module = setmetatable({ }, Meta)
function Module.__tostring(self)
   return string.format("Module<%s>", self.__name)
end
function Module.__index(self, k)
   if self.__getters__[k] then
      return self.__getters__[k](self)
   end
   if self.__members__[k] then
      return self.__members__[k]
   end
   return nil
end
function Module.__newindex(self, k, v)
   if self.__setters__[k] then
      self.__setters__[k](self, v)
   else
      rawset(self, k, v)
   end
end
function Module.__tostring(self)
   if self.__tostring__ then
      return self:__tostring__()
   else
      return string.format('<%s>:%p', self.__name, self)
   end
end
function Module.__call(self, ...)
   local body = Function.clone(self.__body)
   local name = self.__name .. '@' .. string.format('%p', module)
   local module = { __body = body, __name = name }
   module.__getters__ = { }
   module.__setters__ = { }
   module.__members__ = { }

   setfenv(body, setmetatable({ }, { __index = getfenv(2) }))
   body(setmetatable(module, Module), ...)
   return module
end

local function module(name, body)
   local module = { __name = name, __body = body }
   module.__getters__ = { }
   module.__setters__ = { }
   module.__members__ = { }

   setfenv(body, setmetatable({ }, { __index = getfenv(2) }))
   body(setmetatable(module, Module))
   return module
end

Class = setmetatable({ }, Meta)
function Class.__call(class, ...)
   local obj
   if class.__apply then
      obj = class:__apply(...)
   else
      obj = { }
      setmetatable(obj, class)
      if class.__members__.self then
         class.__members__.self(obj, ...)
      end
   end
   return obj
end
function Class.__tostring(class)
   return string.format("%s", class.__name)
end
function Class.__index(class, key)
   return class.__members__[key]
end

Object = setmetatable({ }, Class)
Object.__name = 'Object'
Object.__body = function(self) end
Object.__getters__ = { }
Object.__setters__ = { }
Object.__members__ = { }

local special = {
   __add__ = { mmname = '__add', method = function(a, b) return a:__add__(b) end };
   __sub__ = { mmname = '__sub', method = function(a, b) return a:__sub__(b) end };
   __mul__ = { mmname = '__mul', method = function(a, b) return a:__mul__(b) end };
   __div__ = { mmname = '__div', method = function(a, b) return a:__div__(b) end };
   __pow__ = { mmname = '__pow', method = function(a, b) return a:__pow__(b) end };
   __mod__ = { mmname = '__mod', method = function(a, b) return a:__mod__(b) end };
   __len__ = { mmname = '__len', method = function(a, b) return a:__len__(b) end };
   __unm__ = { mmname = '__unm', method = function(a, b) return a:__unm__(b) end };
   __get__ = { mmname = '__getindex',  method = function(a, k) return a:__get__(k) end };
   __set__ = { mmname = '__setindex',  method = function(a, k, v) a:__set__(k, v) end };
   __concat__ = { mmname = '__concat', method = function(a, b) return a:__concat__(b) end };
   __pairs__  = { mmname = '__pairs',  method = function(a, b) return a:__pairs__() end };
   __ipairs__ = { mmname = '__ipairs', method = function(a, b) return a:__ipairs__() end };
   __call__   = { mmname = '__call',   method = function(self, ...) return self:__call__(...) end };
   __tostring__ = { mmname = '__tostring', method = function(self, ...) return self:__tostring__(...) end };
}

local function class(name, body, ...)
   local base
   if select('#', ...) > 0 then
      if select(1, ...) == nil then
         error("attempt to extend a 'nil' value", 2)
      end
      base = ...
   end

   if not base then base = Object end

   local class = { __name = name, __base = base, __body = body }
   local __getters__ = { }
   local __setters__ = { }
   local __members__ = { }

   setmetatable(__getters__, { __index = base.__getters__ })
   setmetatable(__setters__, { __index = base.__setters__ })
   setmetatable(__members__, { __index = base.__members__ })

   class.__getters__ = __getters__
   class.__setters__ = __setters__
   class.__members__ = __members__

   function __getters__.__class(self)
      return class
   end

   function class.__index(o, k)
      if __getters__[k] then
         return __getters__[k](o)
      end
      if __members__[k] then
         return __members__[k]
      end
      if class.__getindex then
         return class.__getindex(o, k)
      end
      return nil
   end
   function class.__newindex(o, k, v)
      if __setters__[k] then
         __setters__[k](o, v)
      elseif class.__setindex then
         class.__setindex(o, k, v)
      else
         rawset(o, k, v)
      end
   end
   function __members__.__tostring__(o)
      return string.format('<%s>: %p', tostring(class.__name), o)
   end

   setfenv(body, setmetatable({ }, { __index = getfenv(2) }))
   body(setmetatable(class, Class), base.__members__)

   for name, delg in pairs(special) do
      if __members__[name] then
         class[delg.mmname] = delg.method
      end
   end
   if class.__finalize then
      local retv = class:__finalize()
      if retv ~= nil then
         return retv
      end
   end
   return class
end

local function include(into, ...)
   for i=1, select('#', ...) do
      if select(i, ...) == nil then
         error("attempt to include a nil value", 2)
      end
   end

   local args = { ... }
   for i=1, #args do
      local from = args[i] 
      for k,v in pairs(from.__getters__) do
         into.__getters__[k] = v
      end
      for k,v in pairs(from.__setters__) do
         into.__setters__[k] = v
      end
      for k,v in pairs(from.__members__) do
         into.__members__[k] = v
      end
      if from.__included then
         from:__included(into)
      end
   end
end

local Array = class("Array", function(self)
   local Array = self
   local unpack, select, table = unpack, select, table

   function self:__apply(...)
      return setmetatable({
         length = select('#', ...), [0] = select(1, ...), select(2, ...)
      }, self)
   end
   function self.__each(a)
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
   function self.__pairs(self)
      return function(self, ctrl)
         local i = ctrl + 1
         if i < self.length then
            return i, self[i]
         end
      end, self, -1
   end
   function self.__ipairs(self)
      return function(self, ctrl)
         local i = ctrl + 1
         if i < self.length then
            return i, self[i]
         end
      end, self, -1
   end

   function self.__members__:join(sep)
      return table.concat({ Array.__spread(self) }, sep)
   end
   function self.__members__:push(val)
      self[self.length] = val
   end
   function self.__members__:pop()
      local last = self[self.length - 1]
      self[self.length - 1] = nil
      self.length = self.length - 1
      return last
   end
   function self.__members__:shift()
      local v = self[0]
      local l = self.length
      for i=1, l - 1 do
         self[i - 1] = self[i]
      end
      self.length = l - 1
      self[l - 1] = nil
      return v
   end
   function self.__members__:unshift(v)
      for i = l - 1, 0 do
         self[i + 1] = self[i]
      end
      self[0] = v
   end
   function self.__members__:slice(offset, count)
      local a = Array()
      for i=offset, offset + count do
         a[a.length] = self[i]
      end
      return a
   end
   function self.__members__:reverse()
      local a = Array()
      for i = self.length - 1, 0 do
         a[a.length] = self[i]
      end
      return a
   end
   local gaps = {
      1391376, 463792, 198768, 86961, 33936, 13776,
      4592, 1968, 861, 336, 112, 48, 21, 7, 3, 1
   }
   local less = function(a, b) return a < b end
   function self.__members__:sort(cmp, n)
      n = n or self.length
      cmp = cmp or less
      for i=1, #gaps do
         local gap = gaps[i]
         for i = gap, n - 1 do
           local v = self[i]
           for j = i - gap, 0, -gap do
             local tv = self[j]
             if not cmp(v, tv) then break end
             self[i] = tv
             i = j
           end
           self[i] = v
         end
       end
       return self
   end
   function self.__spread(a)
      return unpack(a, 0, a.length - 1)
   end
   function self.__len(a)
      return a.length
   end
   function self.__tostring(a)
      if a.__tostring__ then
         return a:__tostring__()
      end
      return string.format("<Array>: %p", self)
   end
   function self.__index(a, k)
      if Array.__members__[k] then
         return Array.__members__[k]
      end
      if type(k) == 'number' and k < 0 then
         return a[#a + k]
      end
      if type(k) == 'table' and getmetatable(k) == Range then
         local l, r = k.left, k.right
         if l < 0 then l = a.length + l end
         if r < 0 then r = a.length + r end
         return Array.__members__.slice(a, l, r - l)
      end
      return nil
   end
   function self.__newindex(a, k, v)
      if type(k) == 'number' and k >= a.length then
         a.length = k + 1
      end
      rawset(a, k, v)
   end
   function self.__members__:__tostring__()
      local b = { }
      for i=0, self.length - 1 do
         b[#b + 1] = tostring(self[i])
      end
      return '['..table.concat(b, ',')..']'
   end
   function self.__members__:map(f)
      local b = Array()
      for i=0, self.length - 1 do
         b[i] = f(i, self[i])
      end
      return b
   end
end)

local function try(try, catch, finally)
   local ok, rv = xpcall(try, catch)
   if finally then finally() end
   return rv
end

local String = class("String", function(self, super)
   local string = _G.string
   for k, v in pairs(string) do
      self.__members__[k] = v
   end
   self.__getindex = function(o, k)
      local t = type(k)
      if t == "table" and getmetatable(k) == Range then
         return string.sub(o, k.left, k.right)
      elseif t == 'number' then
         return string.sub(o, k, k)
      end
   end
   self.__members__.self = function(self, that)
      return tostring(that)
   end
   self.__members__.split = function(self, sep, max, raw)
      if not max then
         max = math.huge
      end
      if not sep then
         sep = '%s+'
      end
      local out = { }
      local pos = 1
      while max > 1 do
         local lhs, rhs = string.find(self, sep, pos, raw)
         if not lhs then
            break
         end
         if sep == "" then
            out[#out + 1] = string.sub(self, pos, lhs)
            pos = lhs + 1
         else
            out[#out + 1] = string.sub(self, pos, lhs - 1)
            pos = rhs + 1
         end
         max = max - 1
      end
      out[#out + 1] = string.sub(self, pos)
      return unpack(out)
   end
   self.__members__.__tostring__ = tostring
end)
debug.setmetatable("", String)

local Error = class("Error", function(self, super)
   self.__members__.self = function(self, mesg)
      self.message = mesg
      self.trace = debug.traceback(mesg, 2)
   end
   self.__members__.__tostring__ = function(self)
      return self.message
   end
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
   if m and m.__each then
      return m.__each(o, ...)
   end
   return pairs(o)
end

Range = { }
Range.__index = Range
function Range.__match(self, that)
   local n = tonumber(that)
   if type(n) == 'number' and n == n then
      return n >= self.left and n <= self.right
   end
   return false
end
function Range.__tostring(self)
   return string.format("Range(%s, %s)", self.left, self.right)
end
function Range.__each(self)
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

local function range(left, right, incl)
   return setmetatable({
      left  = left,
      right = right,
      incl  = incl,
   }, Range)
end

local function import(path, ...)
   local from = path
   if type(from) == 'string' then
      from = require(from)
   end
   local list = { }
   for i=1, select('#', ...) do
      local key = select(i, ...)
      local val = from[key]
      if val == nil then
	 local pkg
	 if type(path) == 'string' then
	    pkg = string.format("%q", path)
	 else
	    pkg = tostring(path)
	 end
	 error(string.format("import %q from %s is nil", key, pkg), 2)
      end
      list[i] = val
   end
   return unpack(list)
end

local ArrayPattern, TablePattern, ApplyPattern

local __var__ = newproxy()

function __match__(that, this)
   local type_this = type(this)
   local type_that = type(that)

   local meta_this = getmetatable(this)
   local meta_that = getmetatable(that)
   if meta_that then
      if meta_that.__match then
         return meta_that.__match(that, this)
      else
         return __is__(this, that)
      end
   elseif type_this ~= type_that then
      return false
   else
      return this == that
   end
end

local function expand(iter, stat, ctrl, ...)
   if iter == nil then return ... end
   local k, v, _1, _2, _3 = iter(stat, ctrl)
   if k == nil then return ... end
   if v == __var__ then
      return expand(_1, _2, _3, expand(iter, stat, k, ...))
   end
   return v, expand(iter, stat, k, ...)
end

local function extract(patt, subj)
   return expand(patt:bind(subj))
end

local TablePattern = class("TablePattern", function(self)
   self.__apply = function(self, keys, desc, meta)
      return setmetatable({
         keys = keys;
         desc = desc;
         meta = meta;
      }, self)
   end

   self.__pairs = function(self)
      local i = 0
      return function(self, _)
         i = i + 1
         local k = self.keys[i]
         if k ~= nil then
            return k, self.desc[k]
         end
      end, self, nil
   end

   self.__match = function(self, that)
      if type(that) ~= 'table' then
         return false
      end
      local desc = self.desc
      local meta = self.meta
      if meta and getmetatable(that) ~= meta then
         return false
      end
      for k, v in pairs(self) do
         if v == __var__ then
            if that[k] == nil then
               return false
            end
         else
            if not __match__(v, that[k]) then
               return false
            end
         end
      end
      return true
   end

   self.__members__.bind = function(self, subj)
      if subj == nil then return end
      local meta = self.meta
      local iter, stat, ctrl = pairs(self)
      return function(stat, ctrl)
         for k, v in iter, stat, ctrl do
            if v == __var__ then
               if meta then
                  -- XXX: assert instead?
                  return k, meta.__index(subj, k)
               else
                  return k, subj[k]
               end
            elseif type(v) == 'table' then
               return k, __var__, v:bind(subj[k])
            end
         end
      end, stat, ctrl
   end
end)

local ArrayPattern = class("ArrayPattern", function(self)
   self.__apply = function(self, ...)
      return setmetatable({
         length = select('#', ...), [0] = select(1, ...), select(2, ...)
      }, self)
   end

   self.__ipairs = function(self)
      return function(self, ctrl)
         local i = ctrl + 1
         if i < self.length then
            return i, self[i]
         end
      end, self, -1
   end

   self.__match = function(self, that)
      if type(that) ~= 'table' then
         return false
      end
      if getmetatable(that) ~= Array then
         return false
      end
      for k, v in ipairs(self) do
         if v ~= __var__ then
            if not __match__(v, that[i]) then
               return false
            end
         end
      end
      return true
   end

   self.__members__.bind = function(self, subj)
      if subj == nil then return end
      local iter, stat, ctrl = ipairs(self)
      return function(stat, ctrl)
         for i, v in iter, stat, ctrl do
            if v == __var__ then
               return i, subj[i]
            elseif type(v) == 'table' then
               return i, __var__, v:bind(subj[i])
            end
         end
      end, stat, ctrl
   end

end)

local ApplyPattern = class("ApplyPattern", function(self)
   self.__apply = function(self, base, ...)
      return setmetatable({
         base = base,
         narg = select('#', ...),
         ...
      }, self)
   end

   self.__match = function(self, that)
      local base = self.base
      if base.__match then
         return base.__match(base, that)
      end
      return getmetatable(that) == self.base
   end

   self.__members__.bind = function(self, subj)
      if subj == nil then return end
      local i = 1
      local si, ss, sc
      if self.base.__unapply then
         si, ss, sc = self.base:__unapply(subj)
      elseif type(subj) == 'table' then
         si, ss, sc = ipairs(subj)
      else
         error("cannot bind "..tostring(subj).." to: "..tostring(self.base))
      end
      local last = false
      return function(self)
         while i <= self.narg do
            local k = i
            local v = self[i]
            i = i + 1
            if last then
               return k, nil
            end
            local _k, _v = si(ss, sc)
            if _k == nil then
               last = true
            end
            sc = _k
            if v == __var__ then
               return k, _v
            elseif type(v) == 'table' then
               return k, __var__, v:bind(_v)
            end
         end
      end, self, nil
   end

end)

local Pattern = setmetatable(getmetatable(lpeg.P(1)), Meta)
Pattern.__call = function(self, ...)
   return self:match(...)
end
Pattern.__tostring = function(self)
   return string.format('Pattern<%p>', self)
end
Pattern.__index.__match = function(self, subj, ...)
   if type(subj) ~= 'string' then return false end
   return self:match(subj, ...)
end
Pattern.__index.__unapply = function(self, subj)
   return ipairs{ self:match(subj) }
end
local function grammar(name, patt)
   return patt
end

local rule = { }
lpeg.setmaxstack(1024)
do
   local def = { }

   def.nl  = lpeg.P("\n")
   def.pos = lpeg.Cp()

   local any=lpeg.P(1)
   lpeg.locale(def)

   def.a = def.alpha
   def.c = def.cntrl
   def.d = def.digit
   def.g = def.graph
   def.l = def.lower
   def.p = def.punct
   def.s = def.space
   def.u = def.upper
   def.w = def.alnum
   def.x = def.xdigit
   def.A = any - def.a
   def.C = any - def.c
   def.D = any - def.d
   def.G = any - def.g
   def.L = any - def.l
   def.P = any - def.p
   def.S = any - def.s
   def.U = any - def.u
   def.W = any - def.w
   def.X = any - def.x

   rule.def = def
   rule.Def = function(id)
      if def[id] == nil then
         error("No predefined pattern '"..tostring(id).."'", 2)
      end
      return def[id]
   end

   local mm = getmetatable(lpeg.P(0))
   mm.__mod = mm.__div

   rule.__add = mm.__add
   rule.__sub = mm.__sub
   rule.__pow = mm.__pow
   rule.__mul = mm.__mul
   rule.__div = mm.__div
   rule.__len = mm.__len
   rule.__unm = mm.__unm
   rule.__mod = mm.__div

   for k,v in pairs(lpeg) do rule[k] = v end

   local function backref(s, i, c)
      if type(c) ~= "string" then return nil end
      local e = #c + i
      if string.sub(s, i, e - 1) == c then
         return e
      else
         return nil
      end
   end

   rule.Cbr = function(name)
      return lpeg.Cmt(lpeg.Cb(name), backref)
   end
end

local __magic__
local function environ(mod)
   return setmetatable(mod, { __index = __magic__ })
end
local function warn(msg, lvl)
   info = debug.getinfo((lvl or 1) + 1, "Sl")
   tmpl = "%s:%s: %s\n"
   io.stderr:write(tmpl:format(info.short_src, info.currentline, msg))
end

local bit = require("bit")

local Nil       = setmetatable({ __name = 'Nil'       }, Meta)
local Number    = setmetatable({ __name = 'Number'    }, Meta)
local Boolean   = setmetatable({ __name = 'Boolean'   }, Meta)
local Table     = setmetatable({ __name = 'Table'     }, Meta)
local UserData  = setmetatable({ __name = 'UserData'  }, Meta)
local Coroutine = setmetatable({ __name = 'Coroutine' }, Meta)
local CData     = setmetatable({ __name = 'CData'     }, Meta)

for k, v in pairs(table) do
   Table[k] = v
end
for k, v in pairs(coroutine) do
   Coroutine[k] = v
end
for k, v in pairs(ffi) do
   CData[k] = v
end

local native = {
   [Nil]       = 'nil',
   [Number]    = 'number',
   [Boolean]   = 'boolean',
   [String]    = 'string',
   [Table]     = 'table',
   [Function]  = 'function',
   [Coroutine] = 'thread',
   [UserData]  = 'userdata',
   [CData]     = 'cdata',
}

function __is__(a, b)
   if type(b) == 'table' and b.__is then
      return b:__is(a)
   end
   if type(a) == 'cdata' then
      return ffi.istype(b, a)
   elseif native[b] then
      return type(a) == native[b]
   elseif b == Pattern then
      return lpeg.type(a) == 'pattern'
   elseif getmetatable(b) == Class then
      local m = getmetatable(a)
      while m do
         if m == b then return true end
         m = m.__base
      end
   elseif type(a) == type(b) then
      return a == b
   elseif getmetatable(a) == getmetatable(b) then
      return true
   end
   return false
end

local typemap = { }
for k, v in pairs(native) do
   typemap[v] = k
end
local function typeof(a)
   local t = type(a)
   if t == 'table' or t == 'userdata' then
      m = getmetatable(a)
      if m then return m end
   end
   if t == 'cdata' then
      return ffi.typeof(a)
   end
   return typemap[type(a)]
end

__magic__ = setmetatable({
   -- builtin types
   Nil = Nil;
   Number = Number;
   Boolean = Boolean;
   String = String;
   Function = Function;
   Coroutine = Coroutine;
   UserData = UserData;
   Table = Table;
   Array = Array;
   Error = Error;
   Module = Module;
   Class = Class;
   Object = Object;
   Pattern = Pattern;
   ArrayPattern = ArrayPattern;
   TablePattern = TablePattern;
   ApplyPattern = ApplyPattern;

   -- builtin functions
   try = try;
   class = class;
   module = module;
   import = import;
   yield = coroutine.yield;
   take = coroutine.yield;
   throw = error;
   warn = warn;
   grammar = grammar;
   include = include;
   typeof = typeof;

   -- utility
   environ = environ;

   -- constants
   null = null;

   -- operators
   __rule__ = rule;
   __range__ = range;
   __spread__ = spread;
   __match__ = __match__;
   __extract__ = extract;
   __each__ = each;
   __var__ = __var__;
   __in__ = __in__;
   __is__ = __is__;
   __as__ = setmetatable;
   __lshift__ = bit.lshift;
   __rshift__ = bit.rshift;
   __arshift__ = bit.arshift;
   __bnot__ = bit.bnot;
   __band__ = bit.band;
   __bor__ = bit.bor;
   __bxor__ = bit.bxor;
}, { __index = _G })

_G.__magic__ = __magic__
export.__magic__ = __magic__
package.loaded["core"] = export

return export

