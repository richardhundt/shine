local exports = { }

local util   = require('util')
local syntax = require("syntax")

function exports.tempnam()
   return exports.identifier(util.genid())
end
function exports.chunk(body, loc)
   return syntax.build("Chunk", { body = body, loc = loc })
end
function exports.identifier(name, loc)
   return syntax.build("Identifier", { name = name, loc = loc })
end
function exports.vararg(loc)
   return syntax.build("Vararg", { loc = loc })
end
function exports.binaryExpression(op, left, right, loc)
   return syntax.build("BinaryExpression", {
      operator = op, left = left, right = right, loc = loc
   })
end
function exports.unaryExpression(op, arg, loc)
   return syntax.build("UnaryExpression", {
      operator = op, argument = arg, loc = loc
   })
end
function exports.listExpression(op, exprs, loc)
   return syntax.build("ListExpression", {
      operator = op, expressions = exprs, loc = loc
   })
end

function exports.parenExpression(exprs, loc)
   return syntax.build("ParenExpression", {
      expressions = exprs, loc = loc
   })
end
function exports.assignmentExpression(left, right, loc)
   return syntax.build("AssignmentExpression", {
      left = left, right = right, loc = loc
   })
end
function exports.logicalExpression(op, left, right, loc)
   return syntax.build("LogicalExpression", {
      operator = op, left = left, right = right, loc = loc
   })
end
function exports.memberExpression(obj, prop, comp, loc)
   return syntax.build("MemberExpression", {
      object = obj, property = prop, computed = comp or false, loc = loc
   })
end
function exports.callExpression(callee, args, loc)
   return syntax.build("CallExpression", {
      callee = callee, arguments = args, loc = loc
   })
end
function exports.sendExpression(recv, meth, args, loc)
   return syntax.build("SendExpression", {
      receiver = recv, method = meth, arguments = args, loc = loc
   })
end
function exports.literal(val, loc)
   return syntax.build("Literal", { value = val, loc = loc })
end
function exports.table(val, loc)
   return syntax.build("Table", { value = val, loc = loc })
end
function exports.expressionStatement(expr, loc)
   return syntax.build("ExpressionStatement", { expression = expr, loc = loc })
end
function exports.emptyStatement(loc)
   return syntax.build("EmptyStatement", { loc = loc })
end
function exports.blockStatement(body, loc)
   return syntax.build("BlockStatement", { body = body, loc = loc })
end
function exports.doStatement(body, loc)
   return syntax.build("DoStatement", { body = body, loc = loc })
end
function exports.ifStatement(test, cons, alt, loc)
   return syntax.build("IfStatement", {
      test = test, consequent = cons, alternate = alt, loc = loc
   })
end
function exports.labelStatement(label, loc)
   return syntax.build("LabelStatement", { label = label, loc = loc })
end
function exports.gotoStatement(label, loc)
   return syntax.build("GotoStatement", { label = label, loc = loc })
end
function exports.breakStatement(loc)
   return syntax.build("BreakStatement", { loc = loc })
end
function exports.returnStatement(arg, loc)
   return syntax.build("ReturnStatement", { arguments = arg, loc = loc })
end
function exports.whileStatement(test, body, loc)
   return syntax.build("WhileStatement", {
      test = test, body = body, loc = loc
   })
end
function exports.repeatStatement(test, body, loc)
   return syntax.build("RepeatStatement", {
      test = test, body = body, loc = loc
   })
end
function exports.forInit(name, value, loc)
   return syntax.build("ForInit", { id = name, value = value, loc = loc })
end
function exports.forStatement(init, last, step, body, loc)
   return syntax.build("ForStatement", {
      init = init, last = last, step = step, body = body, loc = loc
   })
end
function exports.forNames(names, loc)
   return syntax.build("ForNames", { names = names, loc = loc })
end
function exports.forInStatement(init, iter, body, loc)
   return syntax.build("ForInStatement", {
      init = init, iter = iter, body = body, loc = loc
   })
end
function exports.localDeclaration(names, exprs, loc)
   return syntax.build("LocalDeclaration", {
      names = names, expressions = exprs, loc = loc
   })
end
function exports.functionDeclaration(name, params, body, vararg, rec, loc)
   return syntax.build("FunctionDeclaration", {
      id         = name,
      body       = body,
      params     = params or { },
      vararg     = vararg,
      recursive  = rec,
      loc        = loc
   })
end
function exports.functionExpression(params, body, vararg, loc)
   return syntax.build("FunctionExpression", {
      body       = body,
      params     = params or { },
      vararg     = vararg,
      loc        = loc
   })
end


return exports
