local B = require('builder')
local util = require('util')

local Scope = { }
Scope.__index = Scope
function Scope.new(outer)
   local self = {
      outer = outer;
      entries = { };
   }
   return setmetatable(self, Scope)
end
function Scope:define(name, info)
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
function Context.new()
   local self = {
      scope = Scope.new()
   }
   return setmetatable(self, Context)
end
function Context:enter()
   self.scope = Scope.new(self.scope)
end
function Context:leave()
   self.scope = self.scope.outer
end
function Context:define(name, info)
   info = info or { }
   self.scope:define(name, info)
   return info
end
function Context:lookup(name)
   local info = self.scope:lookup(name)
   return info
end

local match = { }

function match:Chunk(node)
   self.hoist = { }
   self.scope = { }
   local export = B.identifier('export')
   self.scope[#self.scope + 1] = B.localDeclaration({ export }, { B.table({}) })
   for i=1, #node.body do
      local stmt = self:get(node.body[i])
      self.scope[#self.scope + 1] = stmt
   end
   for i=#self.hoist, 1, -1 do
      table.insert(self.scope, 1, self.hoist[i])
   end
   self.scope[#self.scope + 1] = B.returnStatement({ export })
   return B.chunk(self.scope)
end
function match:ImportStatement(node)
   local args = { B.literal(node.from) }
   for i=1, #node.names do
      args[#args + 1] = B.literal(node.names[i].name)
   end
   return B.localDeclaration(self:list(node.names), {
      B.callExpression(B.identifier('import'), args)
   })
end
function match:ModuleDeclaration(node)
   local name = self:get(node.id)
   self.hoist[#self.hoist + 1] = B.localDeclaration({ name }, { })

   local outer_scope = self.scope
   local outer_hoist = self.hoist

   self.scope = { }
   self.hoist = { }

   local export = B.identifier('export')
   self.scope[#self.scope + 1] = B.localDeclaration({ export }, { B.table({}) })

   for i=1, #node.body do
      local stmt = self:get(node.body[i])
      self.scope[#self.scope + 1] = stmt
   end
   for i=#self.hoist, 1, -1 do
      table.insert(self.scope, 1, self.hoist[i])
   end

   local body = self.scope

   self.scope = outer_scope
   self.hoist = outer_hoist

   body[#body + 1] = B.returnStatement({ export })

   return B.assignmentExpression({ name }, {
      B.callExpression(
         B.parenExpression{
            B.functionExpression({ }, B.blockStatement(body))
         }, { }
      )
   })
end
function match:Literal(node)
   return B.literal(node.value)
end
function match:Identifier(node)
   return B.identifier(node.name)
end
function match:VariableDeclaration(node)
   local inits = node.inits and self:list(node.inits) or { }
   if node.export then
      for i=1, #node.names do
         local expr = B.memberExpression(
            B.identifier('export'), self:get(node.names[i])
         )
         self.scope[#self.scope + 1] = B.assignmentExpression(
            { expr }, { inits[i] }
         )
         inits[i] = expr
      end
   end
   for i=1, #node.names do
      local n = node.names[i]
      if n.type == 'Identifier' and not self.ctx:lookup(n.name) then
         self.ctx:define(n.name)
      end
   end
   return B.localDeclaration(self:list(node.names), inits)
end
function match:AssignmentExpression(node)
   local body = { }
   local decl = { }
   for i=1, #node.left do
      local n = node.left[i]
      if n.type == 'Identifier' and not self.ctx:lookup(n.name) then
         self.ctx:define(n.name)
         decl[#decl + 1] = self:get(n)
      end
   end
   if #decl > 0 then
      body[#body + 1] = B.localDeclaration(decl, { })
   end
   body[#body + 1] = B.assignmentExpression(
      self:list(node.left), self:list(node.right)
   )
   return B.blockStatement(body)
end
function match:UpdateExpression(node)
   local oper = string.sub(node.operator, 1, 1)
   return B.assignmentExpression({
      self:get(node.left)
   }, {
      B.binaryExpression(oper, self:get(node.left), self:get(node.right))
   })
end
function match:MemberExpression(node)
   return B.memberExpression(
      self:get(node.object), self:get(node.property), node.computed
   )
end
function match:SelfExpression(node)
   return B.identifier('self')
end
function match:SuperExpression(node)
   return B.identifier('super')
end

function match:ThrowStatement(node)
   return B.expressionStatement(
      B.callExpression(B.identifier('throw'), { self:get(node.argument) }) 
   )
end

function match:ReturnStatement(node)
   if self.retsig then
      return B.doStatement(
         B.blockStatement{
            B.assignmentExpression(
               { self.retsig }, { B.literal(true) }
            );
            B.assignmentExpression(
               { self.retval }, self:list(node.arguments)
            );
            B.returnStatement{ self.retval }
         }
      )
   end
   return B.returnStatement(self:list(node.arguments))
end

function match:YieldStatement(node)
   return B.expressionStatement(
      B.callExpression(
         B.memberExpression(B.identifier('coroutine'), B.identifier('yield')),
         self:list(node.arguments)
      )
   )
end

function match:IfStatement(node)
   local test, cons, altn = self:get(node.test)
   if node.consequent then
      cons = self:get(node.consequent)
   end
   if node.alternate then
      altn = self:get(node.alternate)
   end
   local stmt = B.ifStatement(test, cons, altn)
   return stmt
end

function match:TryStatement(node)
   local oldret = self.retsig
   local oldval = self.retval

   self.retsig = B.tempnam()
   self.retval = B.tempnam()

   local try = B.functionExpression({ }, self:get(node.body))

   local finally
   if node.finalizer then
      finally = B.functionExpression({ }, self:get(node.finalizer))
   end

   local exit = util.genid()

   local clauses = { }
   for i=#node.guardedHandlers, 1, -1 do
      local clause = node.guardedHandlers[i]
      local cons = self:get(clause.body)
      local head = B.localDeclaration(
         { self:get(clause.param) }, { B.vararg() }
      )
      cons.body[#cons.body + 1] = B.gotoStatement(B.identifier(exit))
      clauses[#clauses + 1] = head
      clauses[#clauses + 1] = B.ifStatement(self:get(clause.guard), cons)
   end
   if node.handler then
      local clause = node.handler
      local cons = self:get(clause.body)
      local head = B.localDeclaration(
         { self:get(clause.param) }, { B.vararg() }
      )
      cons.body[#cons.body + 1] = B.gotoStatement(B.identifier(exit))
      clauses[#clauses + 1] = head
      clauses[#clauses + 1] = B.doStatement(cons)
   end
   clauses[#clauses + 1] = B.labelStatement(B.identifier(exit))

   local catch = B.functionExpression(
      { B.vararg() }, B.blockStatement(clauses)
   )

   local expr = B.callExpression(B.identifier('try'), { try, catch, finally })
   local temp = self.retval
   local rets = self.retsig

   self.retsig = oldret
   self.retval = oldval

   return B.doStatement(
      B.blockStatement{
         B.localDeclaration({ rets }, { B.literal(false) });
         B.localDeclaration({ temp }, { B.literal(nil) });
         B.expressionStatement(expr);
         B.ifStatement(
            rets, B.blockStatement{ B.returnStatement{ temp } }
         )
      }
   )
end
function match:BreakStatement(node)
   return B.breakStatement()
end

function match:LogicalExpression(node)
   return B.logicalExpression(
      node.operator, self:get(node.left), self:get(node.right)
   )
end

local bitop = {
   [">>"]  = 'rshift',
   [">>>"] = 'arshift',
   ["<<"]  = 'lshift',
   ["|"]   = 'bor',
   ["&"]   = 'band',
   ["^"]   = 'bxor',
}
function match:BinaryExpression(node)
   local o = node.operator
   if bitop[o] then
      local call = B.memberExpression(
         B.identifier('bit'),
         B.identifier(bitop[o])
      )
      local args = { self:get(node.left), self:get(node.right) }
      return B.callExpression(call, args)
   end
   if o == 'is' then
      return B.callExpression(B.identifier('__is__'), {
         self:get(node.left), self:get(node.right)
      })
   end
   if o == '..' then
      return B.callExpression(B.identifier('__range__'), {
         self:get(node.left), self:get(node.right)
      })
   end
   if o == '**' then o = '^'  end
   if o == '~'  then o = '..' end
   if o == '!=' then o = '~=' end

   return B.binaryExpression(o, self:get(node.left), self:get(node.right))
end
function match:UnaryExpression(node)
   local o = node.operator
   local a = self:get(node.argument)
   return B.unaryExpression(o, a)
end
function match:FunctionDeclaration(node)
   local name
   if not node.expression then
      name = self:get(node.id[1])
   end

   local params  = { }
   local prelude = { }
   local vararg  = false

   for i=1, #node.params do
      params[#params + 1] = self:get(node.params[i])
      if node.defaults[i] then
         local name = self:get(node.params[i])
         local test = B.binaryExpression("==", name, B.literal(nil))
         local expr = self:get(node.defaults[i])
         local cons = B.blockStatement{
            B.assignmentExpression({ name }, { expr })
         }
         prelude[#prelude + 1] = B.ifStatement(test, cons)
      end
   end

   if node.rest then
      params[#params + 1] = B.vararg()
      prelude[#prelude + 1] = B.localDeclaration(
         { B.identifier(node.rest.name) },
         { B.callExpression(B.identifier('Array'), { B.vararg() }) }
      )
   end

   local body = self:get(node.body)
   for i=#prelude, 1, -1 do
      table.insert(body.body, 1, prelude[i])
   end

   local func
   if node.generator then
      local inner = B.functionExpression({ }, body, vararg)
      func = B.functionExpression(params, B.blockStatement{
         B.returnStatement{
            B.callExpression(
               B.memberExpression(B.identifier("coroutine"), B.identifier("wrap")),
               { inner }
            )
         }
      }, vararg)
   else
      func = B.functionExpression(params, body, vararg)
   end
   if node.expression then
      return func
   end
   if node.export then
      local expr = B.memberExpression(
         B.identifier('export'), name
      )
      self.scope[#self.scope + 1] = B.assignmentExpression(
         { expr }, { func }
      )
   end
   return B.localDeclaration({ name }, { func })
end

--[[
   local Point = class("Point", function(this, super)
      Object:defineProperties(this, {
         move = {
            value = function(self, x, y)

            end,
         }
      })
   end)
]]
function match:ClassDeclaration(node)
   local name = self:get(node.id)
   local base = node.base and self:get(node.base) or B.identifier('Object')

   local properties = { }
   local body = { }

   for i=1, #node.body do
      if node.body[i].type == "PropertyDefinition" then
         local prop = node.body[i]
         local desc = properties[prop.key.name] or { }
         if prop.kind == 'get' then
            desc.get = self:get(prop)
         elseif prop.kind == 'set' then
            desc.set = self:get(prop)
         else
            desc.value = self:get(prop)
         end
         if desc.static then
            if desc.static.value ~= prop.static then
               error("property "..prop.key.name.." already defined as static")
            end
         end

         desc.static = B.literal(prop.static)
         properties[prop.key.name] = desc

         if desc.get then
            -- self.__getters__[key] = desc.get
            body[#body + 1] = B.assignmentExpression(
               { B.memberExpression(
                  B.memberExpression(B.identifier("self"), B.identifier("__getters__")),
                  B.identifier(prop.key.name)
               ) },
               { desc.get }
            )
         elseif desc.set then
            -- self.__setters__[key] = desc.set
            body[#body + 1] = B.assignmentExpression(
               { B.memberExpression(
                  B.memberExpression(B.identifier("self"), B.identifier("__setters__")),
                  B.identifier(prop.key.name)
               ) },
               { desc.set }
            )
         else
            -- self.__members__[key] = desc.value
            local base
            if prop.static then
               base = B.identifier("self")
            else
               base = B.memberExpression(
                  B.identifier("self"), B.identifier("__members__")
               )
            end
            body[#body + 1] = B.assignmentExpression(
               { B.memberExpression(base, B.identifier(prop.key.name)) },
               { desc.value }
            )
         end
      else
         body[#body + 1] = self:get(node.body[i])
      end
   end

   self.hoist[#self.hoist + 1] = B.localDeclaration({ name }, { })

   local init = B.callExpression(
      B.identifier('class'), {
         B.literal(node.id.name), base,
         B.functionExpression(
            { B.identifier('self'), B.identifier('super') },
            B.blockStatement(body)
         )
      }
   )

   if node.export then
      local expr = B.memberExpression(B.identifier('export'), name)
      self.scope[#self.scope + 1] = B.assignmentExpression(
         { expr }, { init }
      )
      init = expr
   end

   return B.assignmentExpression(
      { name }, { init }
   )
end
function match:SpreadExpression(node)
   return B.callExpression(
      B.identifier('__spread__'), { self:get(node.argument) }
   )
end
function match:NilExpression(node)
   return B.literal(nil)
end
function match:PropertyDefinition(node)
   node.value.generator = node.generator
   return self:get(node.value)
end
function match:BlockStatement(node)
   return B.blockStatement(self:list(node.body))
end
function match:ExpressionStatement(node)
   return B.expressionStatement(self:get(node.expression))
end
function match:CallExpression(node)
   local callee = node.callee
   if callee.type == 'MemberExpression' and not callee.computed then
      if callee.object.type == 'SuperExpression' then
         local args = self:list(node.arguments)
         local recv = B.memberExpression(
            B.identifier('super'),
            self:get(callee.property)
         )
         table.insert(args, 1, B.identifier('self'))
         return B.callExpression(recv, args)
      else
         if callee.namespace then
            return B.callExpression(self:get(callee), self:list(node.arguments))
         else
            local recv = self:get(callee.object)
            local prop = self:get(callee.property)
            return B.sendExpression(recv, prop, self:list(node.arguments))
         end
      end
   else
      if callee.type == 'SuperExpression' then
         local args = self:list(node.arguments)
         local recv = B.memberExpression(
            B.identifier('super'),
            B.identifier('self')
         )
         table.insert(args, 1, B.identifier('self'))
         return B.callExpression(recv, args)
      else
         local args = self:list(node.arguments)
         --table.insert(args, 1, B.literal(nil))
         return B.callExpression(self:get(callee), args)
      end
   end
end
function match:NewExpression(node)
   return B.callExpression(B.identifier('new'), {
      self:get(node.callee), unpack(self:list(node.arguments))
   })
end
function match:WhileStatement(node)
   return B.whileStatement(self:get(node.test), self:get(node.body))
end
function match:ForStatement(node)
   local name = self:get(node.name)
   local init = self:get(node.init)
   local last = self:get(node.last)
   local step = B.literal(node.step)
   local body = self:get(node.body)
   return B.forStatement(B.forInit(name, init), last, step, body)
end
function match:RegExp(node)
   return B.callExpression(
      B.identifier('RegExp'), {
         B.literal(node.pattern),
         B.literal(node.flags)
      }
   )
end
function match:RangeExpression(node)
   return B.callExpression(B.identifier('__range__'), {
      self:get(node.min), self:get(node.max)
   })
end
function match:ArrayExpression(node)
   return B.callExpression(B.identifier('Array'), self:list(node.elements))
end
function match:TableExpression(node)
   local properties = { }
   for i=1, #node.members do
      local prop = node.members[i]

      local key, val
      if prop.key then
         if prop.key.type == 'Identifier' then
            key = prop.key.name
         elseif prop.key.type == "Literal" then
            key = prop.key.value
         end
      else
         assert(prop.type == "Identifier")
         key = prop.name
      end

      local desc = properties[key] or { }

      if prop.kind == 'get' then
         desc.get = self:get(prop.value)
      elseif prop.kind == 'set' then
         desc.set = self:get(prop.value)
      elseif prop.value then
         desc.value = self:get(prop.value)
      else
         desc.value = B.identifier(key)
      end

      properties[key] = desc
   end

   for k,v in pairs(properties) do
      properties[k] = B.table(v)
   end

   return B.sendExpression(
      B.identifier('Object'), B.identifier("create"), {
         B.literal(nil);
         B.table(properties);
      }
   )
end
function match:ForInStatement(node)
   local none = B.tempnam()
   local temp = B.tempnam()
   local iter = B.callExpression(B.identifier('__each__'), { self:get(node.right) })
   local left = { }
   for i=1, #node.left do
      left[i] = self:get(node.left[i])
   end
   local body = self:get(node.body)
   return B.forInStatement(B.forNames(left), iter, body)
end
function match:RawString(node)
   local list = { }
   local tostring = B.identifier('tostring')
   for i=1, #node.expressions do
      local expr = node.expressions[i]
      if type(expr) == 'string' then
         list[#list + 1] = B.literal(expr)
      else
         list[#list + 1] = B.callExpression(tostring, { self:get(expr.expression) })
      end
   end
   return B.listExpression('..', list)
end
function match:ArrayComprehension(node)
   local temp = B.tempnam()
   local body = B.blockStatement{
      B.localDeclaration({ temp }, {
         B.callExpression(B.identifier('Array'), { })
      })
   }
   local last = body
   for i=1, #node.blocks do
      local loop = self:get(node.blocks[i])
      local test = node.blocks[i].filter
      if test then
         local body = loop.body
         local cond = B.ifStatement(self:get(test), body)
         loop.body = B.blockStatement{ cond }
         last.body[#last.body + 1] = loop
         last = body
      else
         last.body[#last.body + 1] = loop
         last = loop.body
      end
   end
   last.body[#last.body + 1] = B.assignmentExpression({
      B.memberExpression(temp, B.unaryExpression('#', temp), true)
   }, {
      self:get(node.body)    
   })
   body.body[#body.body + 1] = B.returnStatement{ temp }
   return B.callExpression(
      B.parenExpression{
         B.functionExpression({ }, body)
      }, { }
   )
end
function match:ComprehensionBlock(node)
   local iter = B.callExpression(
      B.identifier('__each__'), { self:get(node.right) }
   )
   local left = self:list(node.left)
   local body = { }
   return B.forInStatement(B.forNames(left), iter, B.blockStatement(body))
end

local function countln(src, pos, idx)
   local line = 0
   local index, limit = idx or 1, pos
   while index <= limit do
      local s, e = string.find(src, "\n", index, true)
      if s == nil or e > limit then
         break
      end
      index = e + 1
      line  = line + 1
   end
   return line 
end

local function transform(tree, src)
   local self = { }
   self.line = 1
   self.pos  = 0

   self.ctx = Context.new()

   function self:sync(node)
      local pos = node.pos
      if pos ~= nil and pos > self.pos then
         local prev = self.pos
         local line = countln(src, pos, prev + 1) + self.line
         self.line = line
         self.pos = pos
      end
   end

   function self:get(node)
      if not match[node.type] then
         error("no handler for "..tostring(node.type))
      end
      self:sync(node)
      local out = match[node.type](self, node)
      out.line = self.line
      return out
   end

   function self:list(nodes)
      local list = { }
      for i=1, #nodes do
         list[#list + 1] = self:get(nodes[i])
      end
      return list
   end

   return self:get(tree)
end

return {
   transform = transform
}
