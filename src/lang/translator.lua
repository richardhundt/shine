--[=[
Copyright (C) 2013-2014 Richard Hundt and contributors.
See Copyright Notice in shine
]=]

local util = require('shine.lang.util')
local tvm  = require("tvm")
local DEBUG = true
 
local Op = { }
setmetatable(Op, {
   __call = function(Op, ...)
      local v = ...
      local t = type(v)
      if t == 'string' then
         if v == '...' then
            return '!vararg'
         end
         return tvm.quote(v)
      elseif v == true then
         return '!true'
      elseif v == false then
         return '!false'
      elseif v == nil then
         if select('#', ...) == 0 then
            return setmetatable({ }, Op)
         else
            return '!nil'
         end
      elseif t == 'table' then
         return setmetatable(v, Op)
      else
         return tostring(v)
      end
   end
})

local wantnl = {
   ['!line'] = true,
   ['!do'] = true,
}

function Op.__tostring(o)
   local t = { }
   if o[0] then
      t[#t+1] = '0: '..tostring(o[0])
   end
   for i = 1, #o do
      t[#t+1] = tostring(o[i])
   end
   for k, v in pairs(o) do
      if type(k) ~= 'number' or k < 0 or k > #o then
         t[#t+1] = tostring(k)..': '..tostring(v)
      end
   end
   return (wantnl[o[1]] and "\n(" or "(")..table.concat(t, ' ')..')'
end

local OpList = { }
setmetatable(OpList, {
   __call = function(mt, t)
      return setmetatable(t or { }, mt)
   end
})
function OpList.__tostring(o)
   local t = { }
   for i=1, #o do
      t[#t+1] = tostring(o[i])
   end
   return table.concat(t, " ")
end


local OpChunk = { }
setmetatable(OpChunk, {
   __call = function(mt, t)
      return setmetatable(t or { }, mt)
   end
})
function OpChunk.__tostring(o)
   local t = { }
   for i=1, #o do
      t[#t+1] = tostring(o[i])
   end
   return table.concat(t, "")
end


local Scope = { }
Scope.__index = Scope
function Scope.new(outer)
   local self = {
      outer   = outer;
      entries = { };
      hoist   = { };
      block   = { };
      macro   = { };
   }
   if outer then
      setmetatable(self.macro, { __index = outer.macro })
   end
   return setmetatable(self, Scope)
end
function Scope:define(name, info)
   info.name = name
   self.entries[name] = info
end
function Scope:lookup(name)
   if self.entries[name] then
      return self.entries[name]
   elseif self.outer then
      return self.outer:lookup(name)
   else
      return nil
   end
end

local Context = { }
Context.__index = Context
function Context.new(name, opts)
   local self = {
      scope = Scope.new();
      line  = 1;
      name  = name or "(eval)";
      undef = { };
      opts  = opts or { };
   }
   return setmetatable(self, Context)
end
function Context:abort(mesg, line)
   local name = self.name
   mesg = string.format("shine: %s:%s: %s\n", self.name, line or self.line, mesg)
   if DEBUG then
      error(mesg)
   else
      io.stderr:write(mesg)
      os.exit(1)
   end
end
function Context:enter(type)
   local topline
   if type == "function" or type == "module" then
      topline = self.line
   else
      topline = self.scope.topline
   end
   self.scope.type = type
   self.scope = Scope.new(self.scope)
   self.scope.topline = topline
   if type == "function" then
      self.scope.level = (self.scope.outer.level or 0) + 1
   else
      self.scope.level = self.scope.outer.level or 1
   end
   return self.scope.block
end
function Context:leave(block)
   block = block or self.scope.hoist
   -- propagate hoisted statements to outer scope
   self:unhoist(block)
   self.scope = self.scope.outer
end
function Context:in_module()
   return self.scope.outer and self.scope.outer.type == "module"
end
function Context:hoist(stmt)
   self.scope.hoist[#self.scope.hoist + 1] = stmt
end
function Context:unhoist(block)
   for i=#self.scope.hoist, 1, -1 do
      table.insert(block, 1, self.scope.hoist[i])
   end
   self.scope.hoist = { }
end
function Context:push(stmt)
   scope = self.scope.outer or self.scope
   scope.block[#scope.block + 1] = stmt
end
function Context:shift(into)
   for i=1, #self.scope.block do
      into[#into + 1] = self.scope.block[i]
   end
   self.scope.block = { }
end
function Context:define(name, info, guard)
   info = info or { line = self.line }
   if guard then
      info.guard = guard
   end
   self.scope:define(name, info)
   for i=#self.undef, 1, -1 do
      local u = self.undef[i]
      if u.name == name and u.line < self.line then
         if u.from.level <= self.scope.level then
            self:abort(string.format("%q used before defined", u.name), u.line)
         else
            -- XXX: scan up
            table.remove(self.undef, i)
         end
      end
   end
   return info
end
function Context:lookup(name)
   return self.scope:lookup(name)
end
function Context:resolve(name)
   if not self.opts.eval then
      self.undef[#self.undef + 1] = {
         name = name, line = self.line, from = self.scope
      }
   end
end
function Context:close()
   for i=1, #self.undef do
      local u = self.undef[i]
      self:abort(string.format("%q used but not defined", u.name), u.line)
   end
end
function Context:op(...)
   return Op(...)
end
function Context:opchunk(...)
   return OpChunk(...)
end
function Context:oplist(...)
   return OpList(...)
end

function Context:sync(node)
   if node.line then
      self.line = node.line
   end
   return self.line
end

local match = { }

local globals = {
   'Nil','Number','Boolean', 'String', 'Function', 'Coroutine', 'Range',
   'UserData', 'Table', 'Array', 'Error', 'Module', 'Class', 'Object',
   'Grammar', 'Pattern', 'ArrayPattern', 'TablePattern', 'ApplyPattern',
   '__magic__', 'yield', 'take', 'typeof', 'null', 'warn', 'eval',
   '__FILE__', '__LINE__', '_M', '_PACKAGE', '_NAME', 'Meta'
}
for k,v in pairs(_G) do
   globals[#globals + 1] = k
end

local magic = {
   'null', '__range__', '__spread__', '__match__', '__extract__', '__each__',
   '__var__', '__in__', '__is__', '__as__', '__lshift__', '__rshift__',
   '__arshift__', '__bor__', '__bxor__', '__band__', '__bnot__'
}

function match:Chunk(node, opts)
   local chunk = { }
   for i=1, #globals do
      self.ctx:define(globals[i])
   end

   self.ctx:enter("module")

   -- import magic from core

   chunk[#chunk + 1] = Op{'!line', Op("@"..self.ctx.name), Op(1) }
   if not self.ctx.opts.eval then
      chunk[#chunk + 1] = OpChunk{
         Op{'!define', '__magic__', Op{'!index',
            Op{'!call1', 'require', Op "core" }, Op"__magic__" } },
         Op{'!call', Op{'!index', '_G', Op"module"}, '!vararg',
            Op{'!index', '__magic__', Op"environ" } }
      }

      --[[
      local sym = { }
      for i = 1, #magic do
         sym[#sym + 1] = magic[i]
      end
      chunk[#chunk + 1] = Op{'!define', Op(sym), Op(sym)}
      --]]
   end

   for i=1, #node.body do
      local line = self.ctx:sync(node.body[i])
      local stmt = self:get(node.body[i])
      self.ctx:shift(chunk)
      chunk[#chunk + 1] = OpList{Op{'!line', line}, stmt}
   end

   local seen_export = self.ctx.seen_export
   if seen_export then
      self.ctx:hoist(Op{'!define', 'export', Op{ }})
   end
   self.ctx:leave(chunk)

   if seen_export then
      chunk[#chunk + 1] = Op{'!return', 'export'}
   end

   return OpChunk(chunk)
end

local translate

function match:ImportStatement(node)
   local args = OpList{ self:get(node.from) }
   local syms = OpList{ }
   for i=1, #node.names do
      local n = node.names[i]
      self.ctx:define(n[1].name)
      if n[2] then
         args[#args + 1] = Op(n[2].name)
      else
         args[#args + 1] = Op(n[1].name)
      end
      syms[#syms + 1] = n[1].name
   end
   if self.ctx.opts.eval then
      return Op{'!massign', Op{ syms }, Op{ Op{'!call', 'import', args } } }
   else
      return Op{'!define', Op{ syms }, Op{ Op{'!call', 'import', args } } }
   end
end
function match:ExportStatement(node)
   local ops = { }
   self.ctx.seen_export = true
   for i=1, #node.names do
      local expr = Op{'!index', 'export', Op(self:get(node.names[i])) }
      ops[#ops + 1] = Op{'!assign', expr, self:get(node.names[i]) }
   end
   return OpChunk(ops)
end
function match:Literal(node)
   return Op(node.value)
end
function match:Identifier(node)
   if node.name == '__FILE__' then
      return Op(self.ctx.name)
   end
   if node.name == '__LINE__' then
      return Op(self.ctx.line)
   end
   if node.check then
      local info = self.ctx:lookup(node.name)
      if info == nil then
         self.ctx:resolve(node.name)
      end
   end
   return node.name
end

function match:MacroDeclaration(node)
   local eval = self.ctx.opts.eval
   self.ctx.opts.eval = true
   local head = self:list(node.head)
   local body = self:list(node.body)
   self.ctx.opts.eval = eval

   local name = node.name.name
   local wrap = OpChunk{
      Op{'!return', Op{'!lambda', Op{ OpList(head) }, OpChunk(body) } }
   }
   wrap = assert(tvm.load(tostring(wrap)))
   setfenv(wrap, require("core").__magic__.environ({ }))
   local func = wrap()

   self.ctx.scope.macro[name] = func
   return OpChunk{ }
end

function match:LocalDeclaration(node)
   local decl = { }
   local simple = true
   local body = { }
   for i=1, #node.names do
      -- recursively define new variables
      local queue = { node.names[i] }
      while #queue > 0 do
         local n = table.remove(queue, 1)
         if n.type == 'ArrayPattern' then
            simple = false
            for i=1, #n.elements do
               queue[#queue + 1] = n.elements[i]
            end
         elseif n.type == 'TablePattern' then
            simple = false
            for i=1, #n.entries do
               queue[#queue + 1] = n.entries[i].value
            end
         elseif n.type == 'ApplyPattern' then
            simple = false
            for i=1, #n.arguments do
               queue[#queue + 1] = n.arguments[i]
            end
         elseif n.type == 'Identifier' then
            if n.guard then
               simple = false
            else
               self.ctx:define(n.name)
            end
            decl[#decl + 1] = n.name
         end
      end
   end

   if simple then
      if node.inits then
         body[#body + 1] = Op{'!define', Op(decl), Op(self:list(node.inits)) }
      else
         body[#body + 1] = Op{'!define', Op(decl), Op{Op(nil)} }
      end
      return OpChunk(body)
   else
      node.left  = node.names
      node.right = node.inits

      return OpChunk{
         Op{'!define', Op(decl), Op{Op(nil)} },
         match.AssignmentExpression(self, node)
      }
   end
end
local function extract_bindings(node, ident)
   local list = { }
   local queue = { node }
   while #queue > 0 do
      local n = table.remove(queue)
      if n.type == 'ArrayPattern' then
         for i=#n.elements, 1, -1 do
            queue[#queue + 1] = n.elements[i]
         end
      elseif n.type == 'TablePattern' then
         for i=#n.entries, 1, -1 do
            queue[#queue + 1] = n.entries[i].value
         end
      elseif n.type == 'ApplyPattern' then
         for i=#n.arguments, 1, -1 do
            queue[#queue + 1] = n.arguments[i]
         end
      elseif n.type == 'Identifier' then
         list[#list + 1] = n
      elseif n.type == 'MemberExpression' then
         if ident then
            queue[#queue + 1] = n.object
         else
            list[#list + 1] = n
         end
      else
         assert(n.type == 'Literal')
      end
   end
   return list
end
function match:AssignmentExpression(node)
   local body = { }
   local decl = { }
   local init = { }
   local dest = { }
   local chks = { }
   local exps
   if node.right then
      exps = self:list(node.right)
   else
      exps = Op{Op(nil)}
   end
   for i=1, #node.left do
      local n = node.left[i]
      local t = n.type
      if t == 'TablePattern' or t == 'ArrayPattern' or t == 'ApplyPattern' then
         -- destructuring
         local tvar = util.genid()
         self.ctx:define(tvar)

         local temp = tvar
         local left = { }
         n.temp = temp
         n.left = left

         init[#init + 1] = temp
         decl[#decl + 1] = temp
         dest[#dest + 1] = n

         -- define new variables
         local bind = extract_bindings(n)
         for i=1, #bind do
            local n = bind[i]
            if n.type == 'Identifier' then
               if n.guard or not self.ctx:lookup(n.name) then
                  local guard
                  if n.guard then
                     guard = util.genid()
                     body[#body + 1] = Op{'!let', guard, self:get(n.guard)}
                  end
                  self.ctx:define(n.name, nil, guard)
                  if not self.ctx.opts.eval then
                     decl[#decl + 1] = n.name
                  end
               end
               if self.ctx:lookup(n.name).guard then
                  chks[#chks + 1] = self.ctx:lookup(n.name)
               end
               left[#left + 1] = n.name
            elseif n.type == 'MemberExpression' then
               left[#left + 1] = self:get(n)
            end
         end
      else
         -- simple case
         if n.type == 'Identifier' then
            if n.guard or not self.ctx:lookup(n.name) then
               local guard
               if n.guard then
                  guard = util.genid()
                  body[#body + 1] = Op{'!let', guard, self:get(n.guard)}
               end
               self.ctx:define(n.name, nil, guard)
               if not self.ctx.opts.eval then
                  decl[#decl + 1] = n.name
               end
            end
            if self.ctx:lookup(n.name).guard then
               chks[#chks + 1] = self.ctx:lookup(n.name)
            end
         end
         init[#init + 1] = self:get(n)
      end
   end

   -- declare locals
   if #decl > 0 then
      if #decl == 0 then
         body[#body + 1] = Op{'!define', Op(decl)}
      else
         body[#body + 1] = Op{'!define', Op(decl), Op{Op(nil)}}
      end
   end

   for i=1, #dest do
      local patt = util.genid()
      body[#body + 1] = Op{'!define', Op{ patt }, Op{ self:get(dest[i])} }
      dest[i].patt = patt
   end

   body[#body + 1] = Op{'!massign', Op(init), Op(exps) }

   -- destructure
   for i=1, #dest do
      body[#body + 1] = Op{'!massign',
         Op(dest[i].left),
         Op{ Op{'!call', '__extract__', dest[i].patt, dest[i].temp } } }
   end

   for i=1, #chks do
      body[#body + 1] = Op{'!call', '__check__', chks[i].name, chks[i].guard}
   end

   return OpChunk(body)
end
function match:ArrayPattern(node)
   local list = { }
   for i=1, #node.elements do
      local n = node.elements[i]
      if n.type == 'Identifier' or n.type == 'MemberExpression' then
         list[#list + 1] = '__var__'
      else
         list[#list + 1] = self:get(n)
      end
   end
   return Op{'!call', 'ArrayPattern', unpack(list) }
end
function match:TablePattern(node)
   local idx = 1
   local keys = { }
   local desc = { }
   for i=1, #node.entries do
      local n = node.entries[i]

      local key, val
      if n.name then
         key = Op(n.name.name)
      elseif n.expr then
         key = self:get(n.expr)
      else
         -- array part
         key = Op(idx)
         idx = idx + 1
      end
      local nv = n.value
      if nv.type == 'Identifier' or nv.type == 'MemberExpression' then
         val = '__var__'
      else
         val = self:get(nv)
      end
      keys[#keys + 1] = key
      desc[key] = val
   end
   keys = Op(keys)
   desc = Op(desc)
   local args = { keys, desc }
   if node.coerce then
      args[#args + 1] = self:get(node.coerce)
   end
   return Op{'!call', 'TablePattern', unpack(args)}
end
function match:ApplyPattern(node)
   local args = { self:get(node.callee) }
   for i=1, #node.arguments do
      local n = node.arguments[i]
      if n.type == 'Identifier' or n.type == 'MemberExpression' then
         args[#args + 1] = '__var__'
      else
         args[#args + 1] = self:get(n)
      end
   end
   return Op{'!call', 'ApplyPattern', unpack(args)}
end
function match:UpdateExpression(node)
   local oper = string.sub(node.operator, 1, -2)
   local expr
   if oper == 'or' or oper == 'and' then
      expr = match.LogicalExpression(self, {
         operator = oper,
         left     = node.left,
         right    = node.right
      })
   else
      expr = match.BinaryExpression(self, {
         operator = oper,
         left     = node.left,
         right    = node.right
      })
   end
   return Op{'!assign', self:get(node.left), expr}
end
function match:MemberExpression(node)
   if node.computed then
      return Op{'!index', self:get(node.object), self:get(node.property)}
   else
      return Op{'!index', self:get(node.object), Op(self:get(node.property))}
   end
end
function match:SelfExpression(node)
   return 'self'
end
function match:SuperExpression(node)
   return 'super'
end

function match:ThrowStatement(node)
   return Op{'!call', 'throw', self:get(node.argument)}
end

function match:ReturnStatement(node)
   local args = self:list(node.arguments)
   if self.retsig then
      return Op{'!do',
         Op{'!assign', self.retsig, '!true' },
         Op{'!assign', self.retval, #args > 0 and OpList(args) or '!nil'},
         Op{'!return', self.retval },
      }
   end
   return Op{'!return', OpList(args)}
end

function match:IfStatement(node)
   local test, cons, altn = self:get(node.test), nil, nil
   if node.consequent then
      self.ctx:enter()
      cons = self:get(node.consequent)
      self.ctx:leave()
   end
   if node.alternate then
      self.ctx:enter()
      altn = self:get(node.alternate)
      self.ctx:leave()
   end
   return Op{'!if', test, Op{'!do', cons}, Op{'!do', altn } }
end

function match:GivenStatement(node)
   local body = { }
   local disc = util.genid()

   body[#body + 1] = Op{'!define', disc, self:get(node.discriminant) }

   local labels = { }

   for i=1, #node.cases do
      labels[#labels + 1] = util.genid()
   end

   self.ctx:enter()

   for i=1, #node.cases do
      local n = node.cases[i]
      if n.test then
         local t = n.test.type
         local case = { }
         if t == 'ArrayPattern' or t == 'TablePattern' or t == 'ApplyPattern' then
            local cons = { }

            -- for storing the template
            local temp = util.genid()
            self.ctx:define(temp)

            case[#case + 1] = Op{'!define', temp, self:get(n.test) }

            cons[#cons + 1] = Op{'!if',
               Op{'!not', Op{'!call', '__match__', temp, disc } },
               Op{'!goto', labels[i] }
            }

            self.ctx:enter() -- consequent

            local into = { }
            local bind = extract_bindings(n.test)
            local vars = { }
            local chks = { }
            for i=1, #bind do
               local n = bind[i]
               if n.type == 'Identifier' then
                  local guard
                  if n.guard then
                     guard = util.genid()
                     case[#case + 1] = Op{'!let', guard, self:get(n.guard)}
                  end
                  self.ctx:define(n.name, nil, guard)
                  if guard then
                     chks[#chks + 1] = self.ctx:lookup(n.name)
                  end
                  vars[#vars + 1] = n.name
               end
               bind[i] = self:get(n)
            end

            if #vars > 0 then
               case[#case + 1] = Op{'!define', Op(vars), Op{ Op(nil) } }
            end

            cons[#cons + 1] = Op{'!massign',
               Op(bind), Op{ Op{'!call', '__extract__', temp, disc } }
            }

            for i=1, #chks do
               cons[#cons + 1] = Op{'!call', '__check__', chks[i].name, chks[i].guard}
            end

            if n.guard then
               cons[#cons + 1] = Op{'!if',
                  Op{'!not', self:get(n.guard) }, Op{'!goto', labels[i] }
               }
            end

            cons[#cons + 1] = self:get(n.consequent)
            self.ctx:leave()

            case[#case + 1] = Op{'!do', OpChunk(cons)}
            case[#case + 1] = Op{'!goto', labels[#labels] }
         else
            case[#case + 1] = Op{'!if',
               Op{'!not', Op{'!call', '__match__', self:get(n.test), disc } },
               Op{'!goto', labels[i] }
            }
            if n.guard then
               case[#case + 1] = Op{'!if',
                  Op{'!not', self:get(n.guard) }, Op{'!goto', labels[i] }
               }
            end
            case[#case + 1] = self:get(n.consequent)
            case[#case + 1] = Op{'!goto', labels[#labels] }
         end
         body[#body + 1] = Op{'!do', OpChunk(case) }
      else
         -- else clause
         body[#body + 1] = Op{'!do', self:get(n.consequent) }
      end
      body[#body + 1] = Op{'!label', labels[i]}
   end

   self.ctx:leave(body)

   return Op{'!do', OpChunk(body) }
end

function match:TryStatement(node)
   local oldret = self.retsig
   local oldval = self.retval
   local oldbrk = self.brksig
   local oldcnt = self.cntsig

   self.retsig = util.genid()
   self.retval = util.genid()
   self.brksig = util.genid()
   self.cntsig = util.genid()

   local try = Op{'!lambda', Op{ }, self:get(node.body)}

   local finally
   if node.finalizer then
      finally = Op{'!lambda', Op{ }, self:get(node.finalizer)}
   end

   local exit = util.genid()

   local clauses = { }
   for i=#node.guardedHandlers, 1, -1 do
      local clause = node.guardedHandlers[i]
      self.ctx:define(clause.param.name)
      local cons = self:get(clause.body)
      local head = Op{'!define', self:get(clause.param), '!vararg'}
      cons[#cons + 1] = Op{'!goto', exit }
      clauses[#clauses + 1] = Op{'!do', head,
         Op{'!if', self:get(clause.guard), Op{'!do', OpChunk(cons)}} }
   end
   if node.handler then
      local clause = node.handler
      self.ctx:define(clause.param.name)
      local cons = self:get(clause.body)
      local head = Op{'!define', self:get(clause.param), '!vararg'}
      cons[#cons + 1] = Op{'!goto', exit}
      clauses[#clauses + 1] = Op{'!do', head, Op{'!do', OpChunk(cons)}}
   end
   clauses[#clauses + 1] = Op{'!label', exit }

   local catch = Op{'!lambda', Op{'!vararg'}, OpChunk(clauses)}

   local expr = Op{'!call', 'try', try, catch, finally }

   local temp = self.retval
   local rets = self.retsig
   local brks = self.brksig
   local cnts = self.cntsig

   self.retsig = oldret
   self.retval = oldval
   self.brksig = oldbrk
   self.cntsig = oldcnt

   return Op{'!do', 
      Op{'!define', Op{ rets, brks, cnts }, Op{ '!false', '!false', '!false' } },
      Op{'!define', temp, Op(nil) },
      Op(expr),
      Op{'!if', rets, Op{'!return', temp } },
      Op{'!if', cnts, Op{'!goto', self.loop} },
      Op{'!if', brks, Op{'!break'} }
   }
end
function match:LabelStatement(node)
   return Op{'!label', node.label.name }
end
function match:GotoStatement(node)
   return Op{'!goto', node.label.name }
end
function match:BreakStatement(node)
   if self.brksig then
      return OpChunk{
         Op{'!assign', self.brksig, '!true'},
         Op{'!return'}
      }
   end
   return Op{'!break'}
end
function match:ContinueStatement(node)
   if self.cntsig then
      return OpChunk{
         Op{'!assign', self.cntsig, '!true'},
         Op{'!return'}
      }
   end
   return Op{'!goto', self.loop}
end

function match:LogicalExpression(node)
   local op = node.operator
   if op == 'and' then
      return Op{'!and', self:get(node.left), self:get(node.right) }
   elseif op == 'or' then
      return Op{'!or', self:get(node.left), self:get(node.right) }
   else
      assert(false, "Unhandled operator "..op.." in logical expression")
   end
end

local bitop = {
   [">>"]  = '__rshift__',
   [">>>"] = '__arshift__',
   ["<<"]  = '__lshift__',
   ["|"]   = '__bor__',
   ["&"]   = '__band__',
   ["^"]   = '__bxor__',
}
local binop = {
   ['+']  = '!add',
   ['-']  = '!sub',
   ['*']  = '!mul',
   ['/']  = '!div',
   ['%']  = '!mod',
   ['**'] = '!pow',
   ['~']  = '!concat',
   ['=='] = '!eq',
   ['!='] = '!ne',
   ['>='] = '!ge',
   ['<='] = '!le',
   ['>']  = '!gt',
   ['<']  = '!lt',
}
function match:BinaryExpression(node)
   local o = node.operator
   if bitop[o] then
      return Op{'!call', bitop[o], self:get(node.left), self:get(node.right) }
   end
   if o == 'is' then
      return Op{'!call', '__is__', self:get(node.left), self:get(node.right)}
   end
   if o == 'as' then
      return Op{'!call', '__as__', self:get(node.left), self:get(node.right)}
   end
   if o == '..' then
      return Op{'!call', '__range__', self:get(node.left), self:get(node.right)}
   end
   if string.sub(o, 1, 1) == ':' then
      return Op{'!call', '__usrop__', Op(o), self:get(node.left), self:get(node.right) }
   end
   return Op{binop[o], self:get(node.left), self:get(node.right)}
end
local unop = {
   ['#']   = '!len',
   ['-']   = '!neg',
   ['!']   = '!not',
   ['not'] = '!not',
}
function match:UnaryExpression(node)
   local o = node.operator
   local a = self:get(node.argument)
   if o == '~' then
      return Op{'!call', '__bnot__', a }
   end
   return Op{unop[o], a }
end
function match:FunctionDeclaration(node)
   local name
   if not node.expression then
      name = self:get(node.name)
      if node.name.type == 'Identifier' then
         if node.islocal or self.ctx:in_module() then
            self.ctx:define(name)
         else
            -- in function scope, hoist it
            self.ctx:define(name, { line = self.ctx.scope.topline })
            self.ctx:hoist(Op{'!define', name })
         end
      end
   end

   local params  = { }
   local prelude = { }

   self.ctx:enter("function")

   for i=1, #node.params do
      self.ctx:define(node.params[i].name)
      local name = self:get(node.params[i])
      params[#params + 1] = name
      if node.defaults[i] then
         local test = Op{'!eq', name, '!nil'}
         local expr = self:get(node.defaults[i])
         local cons = Op{'!assign', name, expr }
         prelude[#prelude + 1] = Op{'!if', test, cons }
      end
      if node.guards[i] then
         local expr = self:get(node.guards[i])

         -- hoist guards constructors to the outer scope
         local temp = util.genid()
         self.ctx:push(Op{'!let', temp, expr})
         expr = temp

         local test = Op{'!call', '__is__', name, expr }
         local mesg
         if i == 1 and expr == '__self__' then
            mesg = "calling '%s' on bad self (%s expected got %s)"
         else
	    mesg = string.format(
               "bad argument #%s to '%%s' (%%s expected got %%s)", i
            )
         end
         local level = node.level or 1
         local cons
         if node.name then
            cons = Op{'!call', 'error',
               Op{'!callmeth', Op(mesg), 'format',
                  Op(self:get(node.name)),
                  Op{'!call1', 'tostring', expr },
                  Op{'!call1', 'typeof', name }
               }, Op(level + 1)
            }
         else
            cons = Op{'!call', 'error',
               Op{'!callmeth', Op(mesg), 'format',
                  Op{'!or',
                     Op{'!index',
                        Op{'!call1',
                           Op{'!index', 'debug', Op"getinfo"},
                           Op(level), Op"n" },
                        Op"name"
                     },
                     Op('?')
                  },
                  Op{'!call1', 'tostring', expr },
                  Op{'!call1', 'typeof', name }
               }, Op(level + 1)
            }
         end
         prelude[#prelude + 1] = Op{'!if', Op{'!not', test }, cons }
      end
   end

   if node.rest then
      params[#params + 1] = '!vararg'
      if node.rest ~= "" then
         self.ctx:define(node.rest.name)
         prelude[#prelude + 1] = Op{'!define', node.rest.name,
            Op{'!call1', 'Array', '!vararg' } }
      end
   end

   local body = self:get(node.body)

   for i=#prelude, 1, -1 do
      table.insert(body, 1, prelude[i])
   end

   self.ctx:leave(body)

   local func
   if node.generator then
      local inner = Op{'!lambda', Op{ }, body}
      func = Op{'!lambda', Op(params),
         OpChunk{
            Op{'!return', Op{'!call1', Op{'!index', 'coroutine', Op"wrap"}, inner}}
         }}
   else
      func = Op{'!lambda', Op(params), body}
   end

   if node.expression then
      return func
   end

   local decl
   if node.islocal then
      decl = OpChunk{
         Op{'!define', name},
         Op{'!assign', name, func}
      }
   else
      decl = Op{'!assign', name, func }
   end

   local wrap = OpChunk{ }
   self.ctx:shift(wrap)
   wrap[#wrap + 1] = decl
   return wrap
end

function match:IncludeStatement(node)
   local args = self:list(node.list)
   table.insert(args, 1, 'self')
   return Op{'!call', 'include', unpack(args)}
end

function match:ModuleDeclaration(node)
   local name = self:get(node.id)
   if self.ctx:in_module() and node.scope ~= 'local' then
      self.ctx:define(name)
   else
      self.ctx:define(name, { line = self.ctx.scope.topline })
      self.ctx:hoist(Op{'!define', name})
   end

   self.ctx:enter("module")
   self.ctx:define('self')
   self.ctx:define('__self__')

   local body = self:get(node.body)

   self.ctx:unhoist(body)
   self.ctx:leave()

   local init = Op{'!call', 'module', Op(node.id.name),
      Op{'!lambda', Op{ 'self', '!vararg' }, body } }
   return Op{'!assign', name, init}
end

function match:ClassDeclaration(node)
   local name = self:get(node.id)
   if self.ctx:in_module() and node.scope ~= 'local' then
      self.ctx:define(name)
   else
      self.ctx:define(name, { line = self.ctx.scope.topline })
      self.ctx:hoist(Op{'!define', name})
   end

   local base = node.base and self:get(node.base) or nil
   self.ctx:enter("module")

   self.ctx:define('self')
   self.ctx:define('super')
   self.ctx:define('__self__')

   local body = self:get(node.body)

   self.ctx:unhoist(body)
   self.ctx:leave()

   local init = Op{'!call', 'class', Op(node.id.name),
      Op{'!lambda', Op{ 'self', 'super' }, body }, base }
   return Op{'!assign', name, init}
end

function match:ClassBodyStatement(node, body)
   local line = self.ctx:sync(node)
   line = Op{'!line', line }
   if node.type == "PropertyDefinition" then
      local prop = node
      if prop.kind == "get" then
         -- self.__getters__[key] = desc.get
         prop.value.name = prop.key
         prop.value.level = 2

         local decl = self:get(prop)
         self.ctx:shift(body)

         body[#body + 1] = OpList{line, Op{'!assign',
            Op{'!index',
               Op{'!index', 'self', Op"__getters__" },
            Op(prop.key.name) }, decl }}

      elseif prop.kind == "set" then
         -- self.__setters__[key] = desc.set
         prop.value.name = prop.key
         prop.value.level = 2

         local decl = self:get(prop)
         self.ctx:shift(body)

         body[#body + 1] = OpList{line, Op{'!assign',
            Op{'!index',
               Op{'!index', 'self', Op"__setters__" },
            Op(prop.key.name) }, decl }}
      else
         -- hack to skip a frame for the constructor
         if prop.key.name == 'self' then
            prop.value.level = 2
         end

         local decl = self:get(prop)
         self.ctx:shift(body)

         -- self.__members__[key] = desc.value
         body[#body + 1] = OpList{line, Op{'!assign',
            Op{'!index',
               Op{'!index', 'self', Op"__members__" },
            Op(prop.key.name) }, decl }}
      end
   elseif node.type == 'ClassDeclaration'
       or node.type == 'ModuleDeclaration'
   then

      local stmt = self:get(node)
      self.ctx:shift(body)
      body[#body + 1] = stmt

      if node.scope ~= 'local' then
         local inner_name = self:get(node.id)
         body[#body + 1] = OpList{line,
            Op{'!assign', Op{'!index', 'self', Op(inner_name)}, inner_name }
         }
      end
   else
      local stmt = self:get(node)
      self.ctx:shift(body)
      body[#body + 1] = OpList{line, stmt}
   end
end

function match:ClassBody(node)
   local body = { }
   for i=1, #node.body do
      match.ClassBodyStatement(self, node.body[i], body)
   end
   return OpChunk(body)
end

function match:SpreadExpression(node)
   if node.argument ~= '...' then
      return Op{'!call', '__spread__', self:get(node.argument) }
   else
      return '!vararg'
   end
end
function match:NilExpression(node)
   return '!nil'
end
function match:PropertyDefinition(node)
   node.value.generator = node.generator
   return self:get(node.value)
end
function match:DoStatement(node)
   return Op{'!do', self:get(node.body)}
end
function match:BlockStatement(node)
   local body = OpChunk{ }
   for i=1, #node.body do
      local line = self.ctx:sync(node.body[i])
      local stmt = self:get(node.body[i])
      self.ctx:shift(body)
      body[#body + 1] = OpList{Op{'!line', line}, stmt}
   end
   return body
end
function match:ExpressionStatement(node)
   if node.expression.type == 'Identifier' then
      return Op{'!call', self:get(node.expression)}
   end
   return self:get(node.expression)
end
function match:CallExpression(node)
   local callee = node.callee
   if callee.type == 'MemberExpression' and not callee.computed then
      if callee.object.type == 'SuperExpression' then
         local args = self:list(node.arguments)
         local recv = Op{'!index', 'super', Op(self:get(callee.property)) }
         table.insert(args, 1, 'self')
         return Op{'!call', recv, unpack(args)}
      else
         if callee.namespace then
            return Op{'!call', self:get(callee), unpack(self:list(node.arguments))}
         else
            local recv = self:get(callee.object)
            local prop = self:get(callee.property)
            return Op{'!callmeth', recv, prop, unpack(self:list(node.arguments))}
         end
      end
   else
      if callee.type == 'SuperExpression' then
         local args = self:list(node.arguments)
         local recv = Op{'!index', 'super', Op('self')}
         table.insert(args, 1, 'self')
         return Op{'!call', recv, unpack(args)}
      else
         local scope = self.ctx.scope
         if callee.type == 'Identifier' and scope.macro[callee.name] then
            local macro = scope.macro[callee.name]
            local frag  = macro(self.ctx, unpack(node.arguments))
            return frag
         else
            local args = self:list(node.arguments)
            return Op{'!call', self:get(callee), unpack(args)}
         end
      end
   end
end
function match:WhileStatement(node)
   local loop = util.genid()
   local save = self.loop
   self.loop = loop
   self.ctx:enter()
   local body = self:get(node.body)
   body[#body + 1] = Op{'!label', loop}
   self.ctx:leave()
   self.loop = save
   return Op{'!while', self:get(node.test), body}
end
function match:RepeatStatement(node)
   local loop = util.genid()
   local save = self.loop
   self.loop = loop
   self.ctx:enter()
   local body = self:get(node.body)
   body[#body + 1] = Op{'!label',loop}
   self.ctx:leave()
   self.loop = save
   return Op{'!repeat', body, self:get(node.test) }
end
function match:ForStatement(node)
   local loop = util.genid()
   local save = self.loop
   self.loop = loop
   self.ctx:enter()
   self.ctx:define(node.name.name)
   local name = self:get(node.name)
   local init = self:get(node.init)
   local last = self:get(node.last)
   local step = self:get(node.step)
   local body = self:get(node.body)
   body[#body + 1] = Op{'!label',loop}
   self.loop = save
   self.ctx:leave()
   return Op{'!loop', OpList{name, init, last, step}, body}
end
function match:ForInStatement(node)
   local loop = util.genid()
   local save = self.loop
   self.loop = loop

   local none = util.genid()
   local temp = util.genid()
   local iter = Op{'!call', '__each__', self:get(node.right) }

   self.ctx:enter()
   local left = { }
   for i=1, #node.left do
      self.ctx:define(node.left[i].name)
      left[i] = self:get(node.left[i])
   end

   local body = self:get(node.body)
   body[#body + 1] = Op{'!label', loop}

   self.loop = save
   self.ctx:leave()
   return Op{'!for', OpList{Op(left), Op{iter}}, body}
end
function match:RangeExpression(node)
   return Op{'!call1', '__range__', self:get(node.left), self:get(node.left) }
end
function match:ArrayExpression(node)
   return Op{'!call1', 'Array', unpack(self:list(node.elements))}
end
function match:TableExpression(node)
   local tab = { }
   for i=1, #node.entries do
      local item = node.entries[i]

      local key, val
      if item.name then
         key = Op(item.name.name)
      elseif item.expr then
         key = self:get(item.expr)
      end

      if key ~= nil then
         tab[key] = self:get(item.value)
      else
         tab[#tab + 1] = self:get(item.value)
      end
   end

   return Op(tab)
end
function match:RawString(node)
   if #node.expressions == 0 then
      return Op("")
   elseif #node.expressions == 1 then
      return Op(node.expressions[1])
   end
   local list = { }
   for i=1, #node.expressions do
      local expr = node.expressions[i]
      if type(expr) == 'string' then
         list[#list + 1] = Op(expr)
      else
         list[#list + 1] = Op{'!call', 'tostring', self:get(expr.expression) }
      end
   end
   return Op{'!mconcat', unpack(list)}
end
function match:ArrayComprehension(node)
   local temp = util.genid()
   for i=1, #node.blocks do
      local n = node.blocks[i]
      for j=1, #n.left do
         self.ctx:define(n.left[j].name)
      end
   end
   local head = Op{'!define', temp, Op{'!call', 'Array'} };
   local body = OpChunk{
      Op{'!assign',
         Op{'!index', temp, Op{'!len', temp}},
         self:get(node.body) };
   }
   local tail = Op{'!return', temp }
   for i=1, #node.blocks do
      body = self:get(node.blocks[i], body)
   end
   return Op{'!call', Op{'!lambda', Op{ }, OpChunk{ head, body, tail }}}
end
function match:ComprehensionBlock(node, body)
   local iter = Op{'!call', '__each__', self:get(node.right) }
   local left = OpList(self:list(node.left))
   if node.filter then
      body = Op{'!if', self:get(node.filter), Op{'!do', body }}
   end
   return Op{'!for', OpList{Op{ left }, Op{ iter }}, OpChunk{ body }}
end

function match:RegExp(node)
   return Op{'!call1',
      Op{'!index', '__rule__', Op'P' }, self:get(node.pattern)
   }
end
function match:GrammarDeclaration(node)
   local name = self:get(node.id)
   if self.ctx:in_module() and node.scope ~= 'local' then
      self.ctx:define(name)
   else
      self.ctx:define(name, { line = self.ctx.scope.topline })
      self.ctx:hoist(Op{'!define', name})
   end

   self.ctx:enter("module")
   self.ctx:define('self')
   self.ctx:define('__self__')

   local body = OpChunk{ }
   local init = nil
   for i=1, #node.body do
      local n = node.body[i]
      if n.type == 'PatternRule' then
         if not init then
            init = n.name
            body[#body + 1] = Op{'!assign',
               Op{'!index', Op{'!index', 'self', Op"__members__" }, Op(1) },
               Op(n.name)
            }
         end
         self.ctx:shift(body)
         body[#body + 1] = Op{'!assign',
            Op{'!index', Op{'!index', 'self', Op"__members__"}, Op(n.name) }, 
            self:get(n.body)
         }
      else
         match.ClassBodyStatement(self, n, body)
      end
   end
   if not init then
      self.ctx:abort("no initial rule in grammar '"..name.."'")
   end

   self.ctx:unhoist(body)
   self.ctx:leave()

   body = Op{'!lambda', Op{ 'self' }, body }
   return Op{'!assign',
      name, Op{'!call1', 'grammar', Op(name), body }
   }
end
function match:PatternGrammar(node)
   local tab = { [1] = Op(node.rules[1].name) }
   for i=1, #node.rules do
      local n = node.rules[i]
      local key = Op(n.name)
      local val = self:get(n.body)
      tab[key] = OpList{ Op{'!line', self.ctx:sync(n.body) }, val }
   end
   return Op{'!call1', Op{'!index', '__rule__', Op'P'}, Op(tab) }
end
function match:PatternAlternate(node)
   local left, right
   if node.left then
      left  = self:get(node.left)
      right = self:get(node.right)
   else
      left = self:get(node.right)
   end
   local line = self.ctx:sync(node)
   return OpList{
      Op{'!line', line},
      Op{'!call1', Op{'!index', '__rule__', Op"__add"}, left, right}
   }
end
function match:PatternSequence(node)
   local left, right
   if node.left then
      left  = self:get(node.left)
      right = self:get(node.right)
   else
      left = self:get(node.right)
   end
   local line = self.ctx:sync(node)
   return OpList{
      Op{'!line', line},
      Op{'!call1', Op{'!index', '__rule__', Op"__mul"}, left, right}
   }
end
function match:PatternAny(node)
   return Op{'!call1', Op{'!index', '__rule__', Op"P"}, Op(1)}
end
function match:PatternAssert(node)
   local call
   if node.operator == '&' then
      call = '__len'
   else
      call = '__unm'
   end
   return Op{'!call1', Op{'!index', '__rule__', Op(call)}, self:get(node.argument)}
end
function match:PatternProduction(node)
   local oper, call = node.operator
   if oper == '~>' then
      call = 'Cf'
   elseif oper == '+>' then
      call = 'Cmt'
   else
      assert(oper == '->')
      call = '__div'
   end
   local left  = self:get(node.left)
   local right = self:get(node.right)

   return Op{'!call1', Op{'!index', '__rule__', Op(call)}, left, right}
end
function match:PatternRepeat(node)
   local left, right = self:get(node.left), Op(node.count)
   return Op{'!call1', Op{'!index', '__rule__', Op"__pow"}, left, right}
end

function match:PatternCaptBasic(node)
   return Op{'!call1', Op{'!index', '__rule__', Op"C"}, self:get(node.pattern)}
end
function match:PatternCaptSubst(node)
   return Op{'!call1', Op{'!index', '__rule__', Op"Cs"}, self:get(node.pattern)}
end
function match:PatternCaptTable(node)
   return Op{'!call1', Op{'!index', '__rule__', Op"Ct"}, self:get(node.pattern)}
end
function match:PatternCaptConst(node)
   return Op{'!call1', Op{'!index', '__rule__', Op"Cc"}, self:get(node.argument)}
end
function match:PatternCaptGroup(node)
   local args = { self:get(node.pattern) }
   if node.name then
      args[#args + 1] = Op(node.name)
   end
   return Op{'!call1', Op{'!index', '__rule__', Op"Cg"}, unpack(args)}
end
function match:PatternCaptBack(node)
   return Op{'!call1', Op{'!index', '__rule__', Op"Cb"}, Op(node.name)}
end
function match:PatternCaptBackRef(node)
   return Op{'!call1', Op{'!index', '__rule__', Op"Cbr"}, Op(node.name)}
end
function match:PatternReference(node)
   return Op{'!call1', Op{'!index', '__rule__', Op"V"}, Op(node.name)}
end
function match:PatternClass(node)
   local expr = self:get(node.alternates)
   if node.negated then
      local any = Op{'!call1', Op{'!index', '__rule__', Op"P"}, Op(1)}
      expr = Op{'!call1', Op{'!index', '__rule__', Op"__sub"}, any, expr}
   end
   return expr
end
function match:PatternRange(node)
   return Op{'!call1', Op{'!index', '__rule__', Op"R"}, Op(node.left..node.right)}
end
function match:PatternTerm(node)
   return Op{'!call1', Op{'!index', '__rule__', Op"P"}, Op(node.literal)}
end
function match:PatternPredef(node)
   return Op{'!call1', Op{'!index', '__rule__', Op"Def"}, Op(node.name)}
end
function match:PatternArgument(node)
   local argn = tonumber(node.index)
   return Op{'!call1', Op{'!index', '__rule__', Op"Carg"}, Op(argn)}
end

function translate(tree, name, opts)
   local self = { }
   self.ctx = Context.new(name, opts)

   function self:get(node, ...)
      if not match[node.type] then
         error("no handler for "..tostring(node.type))
      end
      self.ctx:sync(node)
      local out = match[node.type](self, node, ...)
      --if out then out.line = node.line or self.ctx.line end
      return out
   end

   function self:list(nodes, ...)
      local list = { }
      for i=1, #nodes do
         list[#list + 1] = self:get(nodes[i], ...)
      end
      return list
   end

   -- TODO: this is messy
   function self.ctx.get(_, ...)
      return self:get(...)
   end
   function self.ctx.list(_, ...)
      return self:list(...)
   end

   local tout = self:get(tree)
   self.ctx:close()
   return tout, self.ctx
end

return {
   translate = translate
}
