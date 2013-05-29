local util = require('util')

local Writer = { }
Writer.__index = Writer

function Writer:new()
   return setmetatable({
      line   = 1,
      level  = 0,
      dent   = '   ',
      margin = '',
      buffer = { },
   }, self)
end
function Writer:indent()
   self.level  = self.level + 1
   self.margin = string.rep(self.dent, self.level)
end
function Writer:undent()
   self.level  = self.level - 1
   self.margin = string.rep(self.dent, self.level)
end
function Writer:writeln()
   self.buffer[#self.buffer + 1] = "\n"..self.margin
   self.line = self.line + 1
end
function Writer:write(str)
   self.buffer[#self.buffer + 1] = str
end
function Writer:__tostring()
   return table.concat(self.buffer)
end

local match = { }
function match:Chunk(node)
   for i=1, #node.body do
      self:render(node.body[i])
      local last = self.writer.buffer[#self.writer.buffer]
      if last ~= 'end' and last ~= '\n' then
         self:write(";")
      end
      self.writer:writeln()
   end
end
function match:Identifier(node)
   self:write(node.name)
end
function match:Vararg(node)
   self:write("...")
end
function match:BinaryExpression(node)
   self:render(node.left)
   self:write(" "..node.operator.." ")
   self:render(node.right)
end
function match:UnaryExpression(node)
   self:write(node.operator)
   self:render(node.argument)
   self:write(" ")
end
function match:ListExpression(node)
   for i=1, #node.expressions do
      self:render(node.expressions[i])
      if i ~= #node.expressions then
         self:write(node.operator)
      end
   end
end
function match:ParenExpression(node)
   self:write("(")
   for i=1, #node.expressions do
      self:render(node.expressions[i])
      if i ~= #node.expressions then
         self:write(", ")
      end
   end
   self:write(")")
end
function match:AssignmentExpression(node)
   for i=1, #node.left do
      self:render(node.left[i])
      if i ~= #node.left then
         self:write(", ")
      end
   end
   self:write(" = ")
   for i=1, #node.right do
      self:render(node.right[i])
      if i ~= #node.right then
         self:write(", ")
      end
   end
end
function match:LogicalExpression(node)
   self:render(node.left)
   self:write(" "..node.operator.." ")
   self:render(node.right)
end
function match:MemberExpression(node)
   if node.computed then
      self:render(node.object)
      self:write("[")
      self:render(node.property)
      self:write("]")
   else
      self:render(node.object)
      self:write(".")
      self:render(node.property)
   end
end
function match:CallExpression(node)
   self:render(node.callee)
   self:write("(")
   for i=1, #node.arguments do
      self:render(node.arguments[i])
      if i ~= #node.arguments then
         self:write(", ")
      end
   end
   self:write(")")
end
function match:SendExpression(node)
   self:render(node.receiver)
   self:write(":")
   self:render(node.method)
   self:write("(")
   for i=1, #node.arguments do
      self:render(node.arguments[i])
      if i ~= #node.arguments then
         self:write(", ")
      end
   end
   self:write(")")
end
function match:Literal(node)
   if type(node.value) == "string" then
      self:write(string.format("(%q)", node.value))
   else
      self:write("("..tostring(node.value)..")")
   end
end

function match:LabelStatement(node)
   self:write("::"..node.label.."::")
end
function match:GotoStatement(node)
   self:write("goto "..node.label)
end

function match:Table(node)
   self:write("{")
   self.writer:indent()
   local seen = { }
   for i=1, #node.value do
      self.writer:writeln()
      seen[i] = true
      self:render(node.value[i])
      self:write(";")
   end
   for k,v in pairs(node.value) do
      if not seen[k] then
         self.writer:writeln()
         self:write("[")
         if type(k) == 'table' then
            self:render(k)
         elseif type(k) == 'string' then
            self:write(string.format('%q', k))
         else
            self:write(tostring(k))
         end
         self:write("] = ")
         self:render(v)
         self:write(";")
      end
   end
   self.writer:undent()
   self.writer:writeln()
   self:write("}")
end
function match:ExpressionStatement(node)
   self:render(node.expression)
end
function match:EmptyStatement(node)
end
function match:BlockStatement(node)
   self.writer:indent()
   for i=1, #node.body do
      self.writer:writeln()
      self:render(node.body[i])
      local last = self.writer.buffer[#self.writer.buffer]
      if last ~= 'end' and last ~= '\n' then
         self:write(";")
      end
   end
   self.writer:undent()
   self.writer:writeln()
end
function match:DoStatement(node)
   self:write("do")
   self:render(node.body)
   self:write("end")
end
function match:IfStatement(node, nest)
   if node.test then
      self:write("if ")
      self:render(node.test)
      self:write(" then")
   end
   self:render(node.consequent)
   if node.alternate then
      self:write("else")
      self:render(node.alternate, true)
   end
   if not nest then
      self:write("end")
   end
end
function match:LabelStatement(node)
   self:write("::")
   self:render(node.label)
   self:write("::")
end
function match:GotoStatement(node)
   self:write("goto ")
   self:render(node.label)
end
function match:BreakStatement(node)
   self:write("do break; ")
   self:write("end")
end
function match:ReturnStatement(node)
   self:write("do return ")
   for i=1, #node.arguments do
      self:render(node.arguments[i])
      if i ~= #node.arguments then
         self:write(", ")
      else
         self:write(" ")
      end
   end
   self:write('end')
end
function match:WhileStatement(node)
   self:write("while ")
   self:render(node.test)
   self:write(" do")
   self:render(node.body)
   self:write("end")
end
function match:RepeatStatement(node)
   self:write("repeat")
   self:render(node.body)
   self:write("until ")
   self:render(node.test)
end
function match:ForInit(node)
   self:render(node.id)
   self:write(" = ")
   self:render(node.value)
end
function match:ForStatement(node)
   self:write("for ")
   self:render(node.init)
   self:write(", ")
   self:render(node.last)
   if node.step then
      self:write(", ")
      self:render(node.step)
   end
   self:write(" do")
   self:render(node.body)
   self:write("end")
end
function match:ForNames(node)
   for i=1, #node.names do
      self:render(node.names[i])
      if i ~= #node.names then
         self:write(", ")
      end
   end
end
function match:ForInStatement(node)
   self:write("for ")
   self:render(node.init)
   self:write(" in ")
   self:render(node.iter)
   self:write(" do")
   self:render(node.body)
   self:write("end")
end
function match:LocalDeclaration(node)
   self:write("local ")
   for i=1, #node.names do
      self:render(node.names[i])
      if i ~= #node.names then
         self:write(", ")
      end
   end
   if #node.expressions > 0 then
      self:write(" = ")
      for i=1, #node.expressions do
         self:render(node.expressions[i])
         if i ~= #node.expressions then
            self:write(", ")
         end
      end
   end
end
function match:FunctionDeclaration(node)
   if node.recursive then
      self:write("local ")
   end
   self:write("function ")
   self:render(node.id)
   self:write("(")
   for i=1, #node.params do
      self:render(node.params[i])
      if i ~= #node.params then
         self:write(", ")
      end
   end
   self:write(")")
   self:render(node.body)
   self:write("end")
end
function match:FunctionExpression(node)
   self:write("function ")
   self:write("(")
   for i=1, #node.params do
      self:render(node.params[i])
      if i ~= #node.params then
         self:write(", ")
      end
   end
   self:write(")")
   self:render(node.body)
   self:write("end")
end


local function generate(tree)
   local self = { }
   local writer = Writer:new()
   self.writer = writer
   function self:render(node, ...)
      if type(node) ~= "table" then
         error("not a table: "..tostring(node))
      end
      if not node.kind then
         error("don't know what to do with: "..util.dump(node))
      end
      if not match[node.kind] then
         error("no handler for "..node.kind)
      end
      return match[node.kind](self, node, ...)
   end
   function self:write(frag)
      writer:write(frag)
   end
   self:render(tree)
   return tostring(writer)
end

return {
   generate = generate
}

