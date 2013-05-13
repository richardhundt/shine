
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

local Generator = { }
Generator.__index = Generator

function Generator:new(handlers)
   return setmetatable({
      handlers = handlers,
      writer   = Writer:new(),
      srcline  = 0,
      linemap  = { },
   }, self)
end
function Generator:write(...)
   self.writer:write(...)
end

local match = { }
Generator.match = match

function Generator:generate(tree)
   self:render(tree)
   return tostring(self.writer)
end

function Generator:render(node, ...)
   if node.loc and node.loc.start.line < self.srcline then
      self.srcline = node.loc.start.line
      self.linemap[self.writer.line] = self.srcline
   end
   local handler = self.match[node.kind]
   return handler(self, node, ...)
end

function match:Chunk(node)
   for i=1, #node.body do
      self:render(node.body[i])
      self.writer:writeln()
   end
end
function match:Identifier(node)
   self:write(node.name)
end
function match:BinaryExpression(node)
   self:render(node.left)
   self:write(node.operator.." ")
   self:render(node.right)
end
function match:UnaryExpression(node)
   self:write(node.operator)
   self:render(node.argument)
   self:write(" ")
end
function match:SequenceExpression(node)
   for i=1, #node.expressions do
      self:render(node.expressions[i])
      if i ~= #node.expressions then
         self:write(", ")
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
   self:render(node.left)
   self:write(" = ")
   self:render(node.right)
end
function match:LogicalExpression(node)
   self:render(node.left)
   self:write(" "..node.operator.." ")
   self:render(node.right)
   self:write(" ")
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
   self:render(node.arguments)
   self:write(")")
end
function match:SendExpression(node)
   self:render(node.receiver)
   self:write(":")
   self:render(node.method)
   self:write("(")
   self:render(node.arguments)
   self:write(")")
end
function match:Literal(node)
   if type(node.value) == "string" then
      self:write(string.format("%q", node.value))
   else
      self:write(tostring(node.value))
   end
end
function match:Table(node)
   self:write("{")
   for k,v in pairs(node.value) do
      self:write("[")
      self:render(k)
      self:write("] = ")
      self:render(v)
      self:write(";")
   end
   self:write("}")
end
function match:ExpressionStatement(node)
   self:render(node.expression)
   self:write(";")
end
function match:EmptyStatement(node)
   self:write(";")
end
function match:BlockStatement(node)
   self.writer:indent()
   for i=1, #node.body do
      self.writer:writeln()
      self:render(node.body[i])
   end
   self.writer:undent()
   self.writer:writeln()
end
function match:DoStatement(node)
   self:write("do")
   self:render(self.body)
   self:write("end")
end
function match:IfStatement(node, nest)
   self:write("if ")
   self:render(node.test)
   self:write(" then")
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
   self:write(";")
end
function match:BreakStatement(node)
   self:write("break;")
end
function match:ReturnStatement(node)
   self:write("return ")
   self:render(node.argument)
   self:write(";")
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
   self:write(" = ")
   self:render(node.expression)
   self:write(";")
end
function match:FunctionDeclaration(node)
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

local b = require("builder")
local tree = b.chunk{
   b.functionDeclaration(
      b.identifier("greet"), { b.identifier("message") },
      b.blockStatement{
         b.localDeclaration(
            { b.identifier("a"), b.identifier("b") },
            b.sequenceExpression{
               b.literal(42),
               b.literal("cheese")
            }
         ),
         b.expressionStatement(
            b.callExpression(b.identifier("print"), 
               b.sequenceExpression{
                  b.literal("Hello"),
                  b.identifier("message"),
               }
            )
         )
      }
   ),
   b.ifStatement(
      b.literal(true), b.blockStatement{
         b.expressionStatement(
            b.callExpression(b.identifier("print"), 
               b.sequenceExpression{ b.literal("true") }
            )
         )
      },
      b.ifStatement(
         b.literal(false), b.blockStatement{
            b.expressionStatement(
               b.callExpression(b.identifier("print"), 
                  b.sequenceExpression{ b.literal("false") }
               )
            )
         },
         b.blockStatement{
            b.expressionStatement(
               b.callExpression(b.identifier("print"), 
                  b.sequenceExpression{ b.literal("dunno") }
               )
            )
         }
      )
   ),
   b.forStatement(
      b.forInit(b.identifier("i"), b.literal(1)),
      b.literal(10),
      nil,
      b.blockStatement{
         b.expressionStatement(
            b.callExpression(b.identifier("print"), 
               b.sequenceExpression{ b.identifier("i") }
            )
         )
      }
   ),
   b.forInStatement(
      b.forNames{ b.identifier("k"), b.identifier("v") },
      b.callExpression(b.identifier("pairs"),
         b.sequenceExpression{ b.identifier("t") }
      ),
      b.blockStatement{
         b.expressionStatement(
            b.callExpression(b.identifier("print"), 
               b.sequenceExpression{ b.identifier("i") }
            )
         )
      }
   )
}

local gen = Generator:new()
print(gen:generate(tree))

