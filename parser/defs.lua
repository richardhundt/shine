local defs = { }
defs.tonumber = tonumber
defs.tostring = tostring

function defs.octal(s)
   return tostring(tonumber(s, 8))
end
function defs.quote(s)
   return string.format("%q", s)
end
function defs.program(body)
   return { type = "Program", body = body }
end
function defs.error(src, pos)
   local loc = string.sub(src, pos, pos)
   if loc == '' then
      error("Unexpected end of input")
   else
      error("Unexpected token '"..loc.."'")
   end
end

function defs.literal(val)
   return { type = "Literal", value = val }
end
function defs.boolean(val)
   return val == 'true'
end
function defs.identifier(name)
   return { type = "Identifer", name = name }
end
function defs.compExpr(bs, b, f)
   return { type = "ComprehensionExpression", blocks = bs, body = b, filter = f }
end
function defs.compBlock(lhs, rhs)
   return { type = "ComprehensionBlock", left = lhs, right = rhs }
end
function defs.arrayExpr(elements)
   return { type = "ArrayExpression", elements = elements }
end
function defs.objectExpr(properties)
   return { type = "ObjectExpression", properties = properties }
end
function defs.arrayPatt(elements)
   return { type = "ArrayPattern", elements = elements }
end
function defs.objectPatt(properties)
   return { type = "ObjectPattern", properties = properties }
end
function defs.objectMember(prop)
   prop.kind = "init"
   return prop
end
function defs.ifStmt(test, cons, alt)
   return { type = "IfStatement", test = test, consequent = cons, alternate = alt }
end
function defs.whileStmt(test, body)
   return { type = "WhileStatement", test = test, body = body }
end
function defs.forOfStmt(left, right, body)
   return { type = "ForOfStatement", left = left, right = right, body = body }
end
function defs.varDecl(name, init)
   return { type = "VariableDeclaration", id = name, init = init }
end
function defs.funcDecl(name, head, body)
   local decl = { type = "FunctionDeclaration", id = name, body = body }
   local defaults, params, rest = { }, { }, nil
   for i=1, #head do
      local p = head[i]
      if p.rest then
         rest = p.name
      else
         params[#params + 1] = p.name
         if p.default then
            defaults[i] = p.default
         end
      end 
   end
   decl.params   = params
   decl.defaults = defaults
   decl.rest     = rest
   return decl
end
function defs.funcExpr(head, body)
   local decl = defs.funcDecl(nil, head, body)
   decl.expression = true
   return decl
end
function defs.blockStmt(body)
   return {
      type = "BlockStatement",
      body = body
   }
end
function defs.classDecl(name, base, body)
   return { type = "ClassDeclaration", id = name, base = base, body = body }
end
function defs.propDefn(k, n, h, b)
   return {
      type = "PropertyDefinition", kind = k, key = n, value = defs.funcExpr(h, b)
   }
end
function defs.exprStmt(e)
   return { type = "ExpressionStatement", expression = e }
end
function defs.thisExpr()
   return { type = "ThisExpression" }
end
function defs.superExpr()
   return { type = "SuperExpression" }
end
function defs.prefixExpr(o, a)
   return { type = "UnaryExpression", operator = o, argument = a }
end
function defs.postfixExpr(expr)
   local base = expr[1]
   for i=2, #expr do
      if expr[i][1] == "(" then
         base = defs.callExpr(base, expr[i][2])
      else
         base = defs.memberExpr(base, expr[i][2], expr[i][1] == "[")
      end
   end
   return base
end
function defs.memberExpr(b, e, c)
   return { type = "MemberExpression", object = b, property = e, computed = c }
end
function defs.callExpr(expr, args)
   return { type = "CallExpression", callee = expr, arguments = args } 
end
function defs.newExpr(expr, args)
   return { type = "NewExpression", callee = expr, arguments = args } 
end

function defs.binaryExpr(op, lhs, rhs)
   return { type = "BinaryExpression", operator = op, left = lhs, right = rhs }
end
function defs.logicalExpr(op, lhs, rhs)
   return { type = "LogicalExpression", operator = op, left = lhs, right = rhs }
end
function defs.assignExpr(lhs, op, rhs)
   return { type = "AssignmentExpression", operator = op, left = lhs, right = rhs }
end

local prec = {
   ["||"] = 1,
   ["&&"] = 2,
   ["|"] = 3,
   ["^"] = 4,
   ["&"] = 5,

   ["=="] = 6,
   ["!="] = 6,
   ["==="] = 6,
   ["!=="] = 6,

   ["instanceof"] = 7,
   ["in"] = 8,

   [">="] = 9,
   ["<="] = 9,
   [">"] = 9,
   ["<"] = 9,

   ["<<"] = 10,
   [">>"] = 10,
   [">>>"] = 10,

   ["-"] = 11,
   ["+"] = 11,

   ["*"] = 12,
   ["/"] = 12,
   ["%"] = 12,
}

local shift = table.remove

local function fold_infix(exp, lhs, min)
   while prec[exp[1]] ~= nil and prec[exp[1]] >= min do
      local op  = shift(exp, 1)
      local rhs = shift(exp, 1)
      while prec[exp[1]] ~= nil and prec[exp[1]] > prec[op] do
         rhs = fold_infix(exp, rhs, prec[exp[1]])
      end
      if op == "||" or op == "&&" then
         lhs = defs.logicalExpr(op, lhs, rhs)
      else
         lhs = defs.binaryExpr(op, lhs, rhs)
      end
   end
   return lhs
end

function defs.infixExpr(exp)
   return fold_infix(exp, shift(exp, 1), 0)
end

return defs
