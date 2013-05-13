local essyntax = {
   Node = {
      kind = "Node",
      abstract = true
   },
   Expression = {
      kind = "Expression",
      base = "Node",
      abstract = true,
   },
   Statement = {
      kind = "Statement",
      base = "Node",
      abstract = true,
   },

   Program = {
      kind = "Program",
      base = "Node",
      properties = {
         body = {
            type = "list",
            kind = "Statement"
         }
      }
   },
   Identifier = {
      kind = "Identifier",
      base = "Expression",
      properties = {
         name = {
            type = "string"
         }
      }
   },
   BinaryExpression = {
      kind = "BinaryExpression",
      base = "Expression",
      properties = {
         operator = {
            type   = "enum",
            values = {
               "==", "!=", "===", "!==",
               "<", "<=", ">", ">=",
               "<<", ">>", ">>>",
               "+", "-", "*", "/", "%",
               "|", "^", "in",
               "instanceof", ".."
            }
         },
         left = {
            type = "node",
            kind = "Expression",
         },
         right = {
            type = "node",
            kind = "Expression",
         }
      }
   },
   UnaryExpression = {
      kind = "UnaryExpression",
      base = "Expression",
      properties = {
         operator = {
            type   = "enum",
            values = { "-", "+", "!", "~", "typeof", "void", "delete" }
         },
         argument = {
            type = "node",
            kind = "Expression"
         }
      }
   },
   SequenceExpression = {
      kind = "SequenceExpression",
      base = "Expression",
      properties = {
         expressions = {
            type = "list",
            kind = "Expression"
         }
      }
   },
   ParenExpression = {
      kind = "ParenExpression",
      base = "Expression",
      properties = {
         expressions = {
            type = "list",
            kind = "Expression"
         }
      }
   },
   AssignmentExpression = {
      kind = "AssignmentExpression",
      base = "Expression",
      properties = {
         operator = {
            type = "enum",
            values = {
               "=", "+=", "-=", "*=", "/=", "%="
               "<<=", ">>=", ">>>="
               "|=", "^=", "&="
            }
         },
         left = {
            type = "list",
            kind = { "MemberExpression", "Identifier" },
         },
         right = {
            type = "list",
            kind = "Expression",
         }
      }
   },
   LogicalExpression = {
      kind = "LogicalExpression",
      base = "Expression",
      properties = {
         operator = {
            type = "enum",
            values = { "||", "&&" }
         },
         left = {
            type = "node",
            kind = "Expression"
         },
         right = {
            type = "node",
            kind = "Expression"
         }
      }
   },
   MemberExpression = {
      kind = "MemberExpression",
      base = "Expression",
      properties = {
         object = {
            type = "node",
            kind = "Expression"
         },
         property = {
            type = "node",
            kind = "Expression"
         },
         computed = {
            type    = "boolean",
            default = false
         },
      }
   },
   CallExpression = {
      kind = "CallExpression",
      base = "Expression",
      properties = {
         callee = {
            type = "node",
            kind = "Expression"
         },
         arguments = {
            type = "node",
            kind = "SequenceExpression"
         }
      }
   },
   SendExpression = {
      kind = "SendExpression",
      base = "Expression",
      properties = {
         receiver = {
            type = "node",
            kind = "Expression"
         },
         method = {
            type = "node",
            kind = "Identifier",
         },
         arguments = {
            type = "node",
            kind = "SequenceExpression"
         }
      }
    },
    Literal = {
      kind = "Literal",
      base = "Expression",
      properties = {
         value = {
            type = { "string", "number", "nil", "boolean" }
         }
      }
   },
   Table = {
      kind = "Table",
      base = "Expression",
      properties = {
         value = {
            type = "table"
         }
      }
   },
   ExpressionStatement = {
      kind = "ExpressionStatement",
      base = "Statement",
      properties = {
         expression = {
            type = "node",
            kind = "Expression"
         }
      }
   },
   EmptyStatement = {
      kind = "EmptyStatement",
      base = "Statement",
      properties = { },
   },
   BlockStatement = {
      kind = "BlockStatement",
      base = "Statement",
      properties = {
         body = {
            type = "list",
            kind = "Statement"
         }
      }
   },
   DoStatement = {
      kind = "DoStatement",
      base = "Statement",
      properties = {
         body = {
            type = "list",
            kind = "BlockStatement",
         }
      }
   },
   IfStatement = {
      kind = "IfStatement",
      base = "Statement",
      properties = {
         test = {
            type = "node",
            kind = "Expression"
         },
         consequent = {
            type = "node",
            kind = "BlockStatement"
         },
         alternate = {
            type = "node",
            kind = { "BlockStatement", "IfStatement" },
            optional = true,
         }
      }
   },
   LabelStatement = {
      kind = "LabelStatement",
      base = "Statement",
      properties = {
         label = {
            type = "node",
            kind = "Identifier"
         }
      }
   },
   GotoStatement = {
      kind = "GotoStatement",
      base = "Statement",
      properties = {
         label = {
            type = "node",
            kind = "Identifier"
         }
      }
   },
   BreakStatement = {
      kind = "BreakStatement",
      base = "Statement",
      properties = { },
   },
   ReturnStatement = {
      kind = "ReturnStatement",
      base = "Statement",
      properties = {
         argument = {
            type = "node",
            kind = "Expression"
         }
      }
   },
   WhileStatement = {
      kind = "WhileStatement",
      base = "Statement",
      properties = {
         test = {
            type = "node",
            kind = "Expression"
         },
         body = {
            type = "node",
            kind = "Statement"
         }
      }
   },
   RepeatStatement = {
      kind = "RepeatStatement",
      base = "Statement",
      properties = {
         test = {
            type = "node",
            kind = "Expression",
         },
         body = {
            type = "node",
            kind = "BlockStatement"
         }
      }
   },
   ForInit = {
      kind = "ForInit",
      base = "Expression",
      properties = {
         id = {
            type = "node",
            kind = "Identifier",
         },
         value = {
            type = "node",
            kind = "Expression"
         }
      }
   },
   ForStatement = {
      kind = "ForStatement",
      base = "Statement",
      properties = {
         init = {
            type = "node",
            kind = "ForInit"
         },
         last = {
            type = "node",
            kind = "Expression"
         },
         step = {
            type = "node",
            kind = "Expression",
            optional = true,
         },
         body = {
            type = "node",
            kind = "BlockStatement"
         }
      }
   },
   ForNames = {
      kind = "ForNames",
      base = "Expression",
      properties = {
         names = {
            type = "list",
            kind = "Identifier",
         }
      }
   },
   ForInStatement = {
      kind = "ForInStatement",
      base = "Statement",
      properties = {
         init = {
            type = "node",
            kind = "ForNames"
         },
         iter = {
            type = "node",
            kind = "Expression"
         },
         body = {
            type = "node",
            kind = "BlockStatement"
         }
      }
   },
   LocalDeclaration = {
      kind = "LocalDeclaration",
      base = "Statement",
      properties = {
         names = {
            type = "list",
            kind = "Identifier"
         },
         expression = {
            type = "node",
            kind = "Expression"
         }
      }
   },
   FunctionDeclaration = {
      kind = "FunctionDeclaration",
      base = "Statement",
      properties = {
         id = {
            type = "node",
            kind = "Identifier"
         },
         body = {
            type = "node",
            kind = "BlockStatement",
         },
         params = {
            type = "list",
            kind = "Identifier",
         },
         vararg = {
            type = "boolean",
            default = false
         },
         expression = {
            type = "boolean",
            default = false
         },
         recursive = {
            type = "boolean",
            default = false
         }
      }
   }
}

