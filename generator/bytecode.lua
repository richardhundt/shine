local bc   = require('bytecode')
local util = require('util')

-- invert these since usually we branch if *not* condition
local cmpop = {
   ['=='] = 'NE',
   ['~='] = 'EQ',
   ['>='] = 'LT',
   ['<='] = 'GT',
   ['>' ] = 'LE',
   ['<' ] = 'GE',
}
-- comparisons in expression context
local cmpop2 = {
   ['=='] = 'EQ',
   ['~='] = 'NE',
   ['>='] = 'GE',
   ['<='] = 'LE',
   ['>' ] = 'GT',
   ['<' ] = 'LT',
}


local match = { }

local MULTIRES = -1

function match:CallExpression(node, base, want, tail)
   local free = self.ctx.freereg

   want = want or 0
   base = base or self.ctx:nextreg()
   base = self:emit(node.callee, base, want)

   local narg = #node.arguments
   self.ctx:nextreg(narg)

   local args = { }
   local mres = false
   for i=1, narg do
      if i == narg then
         args[#args + 1] = self:emit(node.arguments[i], base + i, MULTIRES)
      else
         args[#args + 1] = self:emit(node.arguments[i], base + i, 1)
      end
      if args[#args] == MULTIRES then
         mres = true
      end
   end

   self.ctx.freereg = free
   if mres then
      if tail then
         self.ctx:op_callmt(base, narg - 1)
      else
         self.ctx:op_callm(base, want, narg - 1)
      end
   else
      if tail then
         self.ctx:op_callt(base, narg)
      else
         self.ctx:op_call(base, want, narg)
      end
   end

   return want == MULTIRES and MULTIRES or base
end

function match:SendExpression(node, base, want, tail)
   local free = self.ctx.freereg
   local narg = #node.arguments

   want = want or 0
   base = base or self.ctx:nextreg()
   base = self:emit(node.receiver, base, 1)

   self.ctx:nextreg(narg + 1)

   local recv = base + 1
   local meth = recv + 1
   self.ctx:op_move(recv, base)
   self.ctx:op_load(meth, node.method.name)
   self.ctx:op_tget(base, base, meth)

   local args = { }
   local mres = false
   for i=1, narg do
      if i == narg then
         args[#args + 1] = self:emit(node.arguments[i], recv + i, MULTIRES)
      else
         args[#args + 1] = self:emit(node.arguments[i], recv + i, 1)
      end
      if args[#args] == MULTIRES then
         mres = true
      end
   end

   self.ctx.freereg = free
   if want == MULTIRES then
      if tail then
         self.ctx:op_callt(base, narg + 1)
      else
         self.ctx:op_call(base, want, narg + 1)
      end
      return MULTIRES
   elseif mres then
      if tail then
         self.ctx:op_callmt(base, narg)
      else
         self.ctx:op_callm(base, want, narg)
      end
   else
      if tail then
         self.ctx:op_callt(base, narg + 1)
      else
         self.ctx:op_call(base, want, narg + 1)
      end
   end

   return base
end

function match:LabelStatement(node)
   return self.ctx:here(node.label)
end
function match:GotoStatement(node)
   return self.ctx:jump(node.label)
end

function match:Literal(node, dest)
   dest = dest or self.ctx:nextreg()
   self.ctx:op_load(dest, node.value)
   return dest
end
function match:Table(node, dest)
   local free = self.ctx.freereg
   dest = dest or self.ctx:nextreg()
   local narry, nhash = 0, 0
   local seen = { }
   for i=1, #node.value do
      seen[i] = true
      narry = narry + 1
   end
   for k,v in pairs(node.value) do
      if not seen[k] then
         nhash = nhash + 1
      end
   end
   self.ctx:op_tnew(dest, narry, nhash)
   local vtop = self.ctx.freereg
   for k,v in pairs(node.value) do
      self.ctx.freereg = vtop
      local kreg, vreg
      if type(k) == 'table' then
         kreg = self.ctx:nextreg()
         kreg = self:emit(k, kreg, 1)
      elseif type(k) == 'string' then
         kreg = k
      else
         kreg = self.ctx:nextreg()
         self.ctx:op_load(kreg, k)
      end
      vreg = self.ctx:nextreg()
      if type(v) == 'table' then
         self:emit(v, vreg, 1)
      else
         self.ctx:op_load(vreg, v)
      end
      self.ctx:op_tset(dest, kreg, vreg)
   end
   self.ctx.freereg = free
   return dest
end
function match:Identifier(node, dest, want)
   dest = dest or self.ctx:nextreg()
   want = want or 0
   local info, uval = self.ctx:lookup(node.name)
   if info then
      if uval then
         self.ctx:op_uget(dest, node.name)
      else
         local var = self.ctx.varinfo[node.name]
         if dest ~= var.idx then
            self.ctx:op_move(dest, var.idx)
         end
      end
   else
      self.ctx:op_gget(dest, node.name)
   end
   return dest
end
function match:Vararg(node, base, want)
   assert(base, "Vararg needs a base")
   self.ctx:op_varg(base, want)
   return MULTIRES
end
function match:BlockStatement(node)
   for i=1, #node.body do
      self:emit(node.body[i])
   end
end
function match:DoStatement(node)
   self:block_enter()
   self:emit(node.body)
   self:block_leave()
end
function match:IfStatement(node, nest, exit)
   local free = self.ctx.freereg
   exit = exit or util.genid()
   local altl = util.genid()
   if node.test then
      local test = node.test
      local treg = self.ctx:nextreg()
      local o = test.operator
      if test.kind == 'BinaryExpression' and cmpop[o] then
         local a = self:emit(test.left, self.ctx:nextreg())
         local b = self:emit(test.right, self.ctx:nextreg())
         self.ctx.freereg = free
         self.ctx:op_comp(cmpop[o], a, b, altl)
      else
         self:emit(test, treg, 1)
         self.ctx.freereg = free
         self.ctx:op_test(false, treg, altl)
      end
   end

   local block_exit = node.alternate and exit

   self:block_enter()
   self:emit(node.consequent)
   self:block_leave(block_exit)

   self.ctx:here(altl)
   if node.alternate then
      self:block_enter()
      self:emit(node.alternate, true, exit)
      self:block_leave()
   end
   if not nest then
      self.ctx:here(exit)
   end
   self.ctx.freereg = free
end
function match:ExpressionStatement(node, dest, ...)
   return self:emit(node.expression, dest, ...)
end
function match:BinaryExpression(node, dest, want)
   local free = self.ctx.freereg
   dest = dest or self.ctx:nextreg()
   local o = node.operator
   local a = self:emit(node.left, self.ctx:nextreg(), 1)
   local b = self:emit(node.right, self.ctx:nextreg(), 1)
   if o == '+' then
      self.ctx:op_add(dest, a, b)
   elseif o == '-' then
      self.ctx:op_sub(dest, a, b)
   elseif o == '/' then
      self.ctx:op_div(dest, a, b)
   elseif o == '*' then
      self.ctx:op_mul(dest, a, b)
   elseif o == '^' then
      self.ctx:op_pow(dest, a, b)
   elseif o == '%' then
      self.ctx:op_mod(dest, a, b)
   elseif o == '..' then
      self.ctx:op_cat(dest, a, b)
   elseif cmpop[o] then
      want = want or 0
      local j1 = util.genid()
      local j2 = util.genid()
      self.ctx:op_comp(cmpop2[o], a, b, j1)
      self.ctx:op_load(dest, false)
      self.ctx:jump(j2)
      self.ctx:here(j1)
      self.ctx:op_load(dest, true)
      self.ctx:here(j2)
   else
      error("bad binary operator: "..o, 2)
   end
   self.ctx.freereg = free
   return dest
end
function match:UnaryExpression(node, dest, want)
   local free = self.ctx.freereg
   dest = dest or self.ctx:nextreg()
   local o = node.operator
   local a = self:emit(node.argument, self.ctx:nextreg(), want)
   if o == '-' then
      self.ctx:op_unm(dest, a)
   elseif o == '#' then
      self.ctx:op_len(dest, a)
   elseif o == 'not' then
      self.ctx:op_not(dest, a)
   else
      error("bad unary operator: "..o, 2)
   end
   self.ctx.freereg = free
   return dest
end
function match:ListExpression(node, dest, want)
   local free = self.ctx.freereg
   dest = dest or self.ctx:nextreg()
   local o = node.operator
   local rbot = self.ctx:nextreg(#node.expressions)
   local rtop = rbot + #node.expressions - 1
   for i=1, #node.expressions do
      self:emit(node.expressions[i], rbot + (i - 1), 1)
   end
   if o == '..' then
      self.ctx:op_cat(dest, rbot, rtop)
   elseif o == ',' then
      -- hmm... not sure
   else
      error("bad list operator: "..o, 2)
   end
   self.ctx.freereg = free
   return dest
end
function match:ParenExpression(node, dest, want)
   return self:emit(node.expressions[1], dest, 1)
end
function match:LocalDeclaration(node)
   local base = self.ctx:nextreg(#node.names)

   local want = #node.expressions
   for i=1, #node.expressions do
      local w = want - (i - 1)
      self:emit(node.expressions[i], base + (i - 1), w)
   end

   for i=1, #node.names do
      local lhs = node.names[i]
      self.ctx:newvar(lhs.name, base + (i - 1))
   end
end

function match:AssignmentExpression(node)
   local free = self.ctx.freereg
   local want = #node.left

   local base = self.ctx:nextreg(want)
   for i=1, #node.right do
      local w = want - (i - 1)
      self:emit(node.right[i], base + i - 1, w)
   end

   for i = #node.left, 1, -1 do
      local lhs  = node.left[i]
      local expr = base + i - 1
      if lhs.kind == 'Identifier' then
         local info, uval = self.ctx:lookup(lhs.name)
         if info then
            if uval then
               self.ctx:op_uset(lhs.name, expr)
            else
               self.ctx:op_move(info.idx, expr)
            end
         else
            self.ctx:op_gset(expr, lhs.name)
         end
      elseif lhs.kind == 'MemberExpression' then
         local obj = self:emit(lhs.object, self.ctx:nextreg(), 1)
         local key
         if lhs.property.kind == 'Identifier' and not lhs.computed then
            key = self.ctx:nextreg()
            self.ctx:op_load(key, lhs.property.name)
         else
            key = self:emit(lhs.property, self.ctx:nextreg(), 1)
         end
         self.ctx:op_tset(obj, key, expr)
      else
         error("Invalid left-hand side in assignment")
      end
   end

   self.ctx.freereg = free
end
function match:LogicalExpression(node, dest, want)
   local free = self.ctx.freereg
   dest = dest or self.ctx:nextreg()
   local a = self:emit(node.left, dest, 1)
   local l = util.genid()
   if node.operator == 'or' then
      self.ctx:op_test(true, a, l)
   elseif node.operator == 'and' then
      self.ctx:op_test(false, a, l)
   else
      error("bad operator in logical expression: "..node.operator)
   end
   self:emit(node.right, dest, 1)
   self.ctx:here(l)
   self.ctx.freereg = free
   return dest
end
function match:MemberExpression(node, base, want)
   local free = self.ctx.freereg
   base = base or self.ctx:nextreg()
   local base = self:emit(node.object, base, 1)
   local expr = self.ctx:nextreg()
   if node.computed then
      expr = self:emit(node.property, expr, 1)
   elseif node.property.kind == 'Identifier' then
      self.ctx:op_load(expr, node.property.name)
   else
      expr = self:emit(node.property, expr, 1)
   end
   self.ctx:op_tget(base, base, expr)
   self.ctx.freereg = free
   return base
end
function match:FunctionDeclaration(node)
   local free = self.ctx.freereg

   local func = self.ctx:child()
   self.ctx = func

   for i=1, #node.params do
      self.ctx:param(node.params[i].name)      
   end
   self:emit(node.body)

   self.ctx = self.ctx.outer

   local dest
   if node.recursive then
      dest = self.ctx:newvar(node.id.name).idx
      self.ctx:op_fnew(dest, func.idx)
   else
      dest = self.ctx:nextreg()
      self.ctx:op_fnew(dest, func.idx)
      self.ctx:op_gset(dest, node.id.name)
      self.ctx.freereg = free
   end

   return dest
end
function match:FunctionExpression(node, dest)
   local free = self.ctx.freereg
   dest = dest or self.ctx:nextreg()
   local func = self.ctx:child()
   self.ctx = func
   for i=1, #node.params do
      if node.params[i].kind == 'Vararg' then
         self.ctx.flags = bit.bor(self.ctx.flags, bc.Proto.VARARG)
      else
         self.ctx:param(node.params[i].name)      
      end
   end
   self:emit(node.body)
   if not self.ctx.explret then
      self.ctx:op_ret0()
   end

   self.ctx = self.ctx.outer
   self.ctx:op_fnew(dest, func.idx)
   self.ctx.freereg = free

   return dest
end
function match:WhileStatement(node)
   local free = self.ctx.freereg
   self:block_enter()

   local loop = util.genid()
   local exit = util.genid()

   local saveexit = self.exit
   self.exit = exit

   self.ctx:here(loop)
   local treg = self.ctx:nextreg()
   local test = node.test
   local o = test.operator
   if test.kind == 'BinaryExpression' and cmpop[o] then
      local a = self:emit(test.left, self.ctx:nextreg())
      local b = self:emit(test.right, self.ctx:nextreg())
      self.ctx.freereg = free
      self.ctx:op_comp(cmpop[o], a, b, exit)
   else
      self:emit(test, treg, 1)
      self.ctx.freereg = free
      self.ctx:op_test(false, treg, exit)
   end

   self.ctx:loop(exit)
   self:emit(node.body)
   self.ctx:jump(loop)
   self.ctx:here(exit)
   self:block_leave()
   self.exit = saveexit
   self.ctx.freereg = free
end
function match:RepeatStatement(node)
   local free = self.ctx.freereg
   self:block_enter()

   local loop = util.genid()
   local exit = util.genid()

   local saveexit = self.exit
   self.exit = exit

   self.ctx:here(loop)
   self.ctx:loop(exit)
   self:emit(node.body)

   local treg = self.ctx:nextreg()
   local test = node.test
   if test.kind == 'BinaryExpression' and cmpop[o] then
      local o = test.operator
      local a = self:emit(test.left, self.ctx:nextreg())
      local b = self:emit(test.right, self.ctx:nextreg())
      self.ctx.freereg = free
      self.ctx:op_comp(cmpop[o], a, b)
   else
      self:emit(test, treg, 1)
      self.ctx.freereg = free
      self.ctx:op_test(false, treg)
   end

   self.ctx:jump(loop)
   self.ctx:here(exit)
   self:block_leave()
   self.exit = saveexit
   self.ctx.freereg = free
end
function match:BreakStatement()
   if self.exit then
      return self.ctx:jump(self.exit)
   else
      error("no loop to break")
   end
end
function match:ForStatement(node)
   local free = self.ctx.freereg
   self:block_enter(3)
   local init = node.init
   local base = self.ctx:nextreg(4)
   local var_base = base + 3
   local name = init.id.name

   local saveexit = self.exit
   self.exit = util.genid()

   self.ctx:newvar(name, var_base)
   self:emit(init.value, base, 1)
   self:emit(node.last, base + 1, 1)
   if node.step then
      self:emit(node.step, base + 2, 1)
   else
      self.ctx:op_load(base + 2, 1)
   end
   local loop = self.ctx:op_fori(base)
   self:emit(node.body)
   self.ctx:op_forl(base, loop)
   self.ctx:here(self.exit)
   self.exit = saveexit
   self:block_leave()
   self.ctx.freereg = free
end
function match:ForInStatement(node)
   local free = self.ctx.freereg
   self:block_enter(3)

   local vars = node.init.names
   local expr = node.iter
   local loop = util.genid()

   local base = self.ctx:nextreg(#vars + 3)
   local iter = base + 3

   local saveexit = self.exit
   self.exit = util.genid()

   self:emit(expr, base, 3) -- func, state, ctl
   self.ctx:jump(loop)

   for i=1, #vars do
      local name = vars[i].name
      self.ctx:newvar(name, iter + i - 1)
   end

   local ltop = self.ctx:here(util.genid())
   self:emit(node.body)
   self.ctx:here(loop)
   self.ctx:op_iterc(iter, #vars + 2)
   self.ctx:op_iterl(iter, ltop)
   self.ctx:here(self.exit)
   self.exit = saveexit
   self:block_leave()
   self.ctx.freereg = free
end
function match:ReturnStatement(node)
   local free = self.ctx.freereg
   local base = self.ctx:nextreg(#node.arguments)
   local narg = #node.arguments
   for i=1, narg do
      local arg = node.arguments[i]
      if i == narg then
         self:emit(arg, base + i - 1, narg + 1 - i, true)
      else
         self:emit(arg, base + i - 1, narg + 1 - i)
      end
   end
   if narg == 0 then
      self.ctx:op_ret0()
   elseif narg == 1 then
      self.ctx:op_ret1(base)
   else
      self.ctx:op_ret(base, narg)
   end
   self.ctx.freereg = free
   if self.ctx:is_root_scope() then
      self.ctx.explret = true
   end
end
function match:Chunk(tree, name)
   for i=1, #tree.body do
      self:emit(tree.body[i])
   end
   if not self.ctx.explret then
      self.ctx:op_ret0()
   end
end

local function generate(tree, name)
   local self = { line = 0 }
   self.main = bc.Proto.new(bc.Proto.VARARG)
   self.dump = bc.Dump.new(self.main, name)
   self.ctx = self.main
   self.savereg = { }

   function self:block_enter(used_reg)
      used_reg = used_reg or 0
      self.savereg[#self.savereg + 1] = self.ctx.freereg + used_reg
      self.ctx:enter()
   end

   function self:block_leave(exit)
      local free = self.savereg[#self.savereg]
      self.savereg[#self.savereg] = nil
      self.ctx:close_block_uvals(free, exit)
      self.ctx:leave()
   end

   function self:emit(node, ...)
      if type(node) ~= "table" then
         error("not a table: "..tostring(node))
      end
      if not node.kind then
         error("don't know what to do with: "..util.dump(node))
      end
      if not match[node.kind] then
         error("no handler for "..node.kind)
      end
      if node.line then
         self.ctx:line(node.line)
      end
      return match[node.kind](self, node, ...)
   end
   self:emit(tree)
   return self.dump:pack()
end

return {
   generate = generate
}

