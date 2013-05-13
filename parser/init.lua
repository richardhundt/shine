local util = require("util")
local re   = require('re')
local defs = require('parser.defs')

local patt = [[
   program  <- {|
      s <stmt>* s (!. / '' => error)
   |} -> program

   nl       <- "\n"
   lcomment <- (!nl %s)* "//" (!nl .)* nl
   bcomment <- "/*" !"*/"* "*/"
   comment  <- <lcomment> / <bcomment>
   idsafe   <- !(%alnum / "_")
   s        <- (<comment> / %s)*
   S        <- (<comment> / %s)+
   hs       <- !<nl> %s
   digits   <- %digit (%digit / &('_' %digit) {~ '_' -> '' ~} %digit)*
   word     <- (%alpha / "_") (%alnum / "_")*

   keyword  <- (
      "var" / "function" / "class" / "in" / "of" / "new" /
      "true" / "false" / "return" / "static" / "for" / "throw" / "break" /
      "continue" / "switch" / "case" / "default" / "while" / "do" / "super" /
      "import" / "export" / "try" / "catch" / "finally" / "if" / "else"
   ) <idsafe>

   sep      <- <bcomment>? ("\n" / ";" / &"}" / <lcomment>) / [\t ] <sep>?

   qstring  <- '"' (!'"' .)* '"'
   astring  <- "'" (!"'" .)* "'"
   string   <- <qstring> / <astring>

   hexadec  <- "-"? "0x" %xdigit+

   decimal  <- "-"? <digits> "." <digits> (("e"/"E") "-"? <digits>)?

   integer  <- "-"? <digits>

   octal    <- {~ { "-"? "0" [0-7]+ } -> octal ~}

   number   <- {~
      <hexadec> / <octal> / <decimal> / <integer>
   ~}

   boolean  <- (
      {"true"/"false"} <idsafe>
   ) -> boolean

   literal  <- ( <number> / <string> / <boolean> ) -> literal

   stmt <- (
      <if_stmt>
      / <while_stmt>
      / <for_of_stmt>
      / <expr_stmt>
      / <decl_stmt>
   )

   decl_stmt <- (
      <var_decl> / <func_decl> / <class_decl>
   )

   var_decl <- (
      "var" <idsafe> s <patt> (s "=" s <expr>)?
   ) -> varDecl

   patt <- (
      <array_patt> / <object_patt> / <member_expr>
   )

   array_patt <- (
      "[" s {| <patt> (s "," s <patt>)* |} "]"
   ) -> arrayPatt

   object_patt <- (
      "{" s {| <object_patt_pair> (s "," s <object_patt_pair>)* |} "}"
   ) -> objectPatt
   object_patt_pair <- (
      (<literal> / <ident>) s ":" s <patt>
   )

   func_decl <- (
      "function" <idsafe> s <ident> "(" s {| <param_list>? |} s ")" s <func_body>
   ) -> funcDecl

   func_expr <- (
      "function" <idsafe> s "(" s {| <param_list>? |} s ")" s <func_body>
      / "(" s {| <param_list>? |} s ")" s "=>" s <func_body>
      / {| {| {:name: <ident> :} |} |} s "=>" s <func_body>
   ) -> funcExpr

   func_body <- <block_stmt> / <expr>

   class_decl <- (
      "class" <idsafe> s <ident> (s <class_heritage>)? s "{" s <class_body> s "}"
   ) -> classDecl

   class_body <- {|
      (<class_element> (<sep> <class_element>)* <sep>?)?
   |}

   class_element <- <prop_defn>

   class_heritage <- (
      "extends" <idsafe> s <expr> / {| |}
   )

   prop_defn <- (
      ({"get"/"set"} s / '' -> "init") <ident> s
      "(" s {| <param_list>? |} s ")" s
      <func_body>
   ) -> propDefn

   param <- {|
      {:name: <ident> :} (s "=" s {:default: <expr> :})?
   |}
   param_list <- (
        <param> s "," s <param_list>
      / <param> s "," s <param_rest>
      / <param>
      / <param_rest>
   )

   param_rest <- {| "..." {:name: <ident> :} {:rest: '' -> 'true' :} |}

   block_stmt <- (
      "{" s {| (<stmt> (<sep> <stmt>)* <sep>?)? |} s "}"
   ) -> blockStmt

   if_stmt <- (
      "if" <idsafe> s "(" s <expr> s ")" s <if_body>
      (s "else" <idsafe> s <if_stmt> / s "else" <idsafe> s <if_body>)?
   ) -> ifStmt

   if_body <- <block_stmt> / <expr_stmt>

   for_of_stmt <- (
      "for" <idsafe> s "(" s <for_of_init> s "of" <idsafe> s <expr> s ")" s
      <for_of_body>
   ) -> forOfStmt

   for_of_init <- <var_decl> / <patt>

   for_of_body <- <block_stmt> / <expr_stmt>

   while_stmt <- (
      "while" <idsafe> s "(" s <expr> s ")" s <while_body>
   ) -> whileStmt

   while_body <- <block_stmt> / <expr_stmt>

   ident <- (
      !<keyword> { (%alpha / "_") (%alnum / "_")* }
   ) -> identifier

   term <- (
        <func_expr>
      / <this_expr>
      / <super_expr>
      / <array_expr>
      / <object_expr>
      / <comp_expr>
      / <ident>
      / <literal>
      / "(" s <expr> s ")"
   )

   expr        <- <infix_expr> / <new_expr>

   this_expr   <- (
      "this" <idsafe>
   ) -> thisExpr

   super_expr  <- (
      "super" <idsafe>
   ) -> superExpr

   expr_stmt   <- (
      <assign_expr> / !("{" / ("class" / "function")<idsafe>) <expr>
   ) -> exprStmt

   binop <- {
      "+" / "-" / "/" / "*" / "%" / "^" / "||" / "&&" / "|" / "&"
      / ">>>" / ">>" / ">=" / ">" / "<<" / "<=" / "<"
      / "!==" / "===" / "!=" / "=="
   }

   infix_expr  <- (
      {| <prefix_expr> (s <binop> s <prefix_expr>)+ |}
   ) -> infixExpr / <prefix_expr>

   prefix_expr <- (
      { "~" / "+" / "-" / "!" } s <prefix_expr>
   ) -> prefixExpr / <postfix_expr>

   postfix_expr <- {|
      <term> (s <postfix_tail>)+
   |} -> postfixExpr / <term>

   postfix_tail <- {|
        { "." } s <ident>
      / { "[" } s <expr> s ("]" / '' => error)
      / { "(" } s {| (<expr> (s "," s <expr>)*)? |} s (")" / '' => error)
   |}

   member_expr <- {|
      <term> (s <member_next>)?
   |} -> postfixExpr / <term>
   member_next <- (
      <postfix_tail> s <member_next> / <member_tail>
   )
   member_tail <- {|
        { "." } s <ident>
      / { "[" } s <expr> s ("]" / '' => error)
   |}

   assop <- {
      "=" / "+=" / "-=" / "*=" / "/=" / "%="
      / "|=" / "&=" / "^=" / "<<=" / ">>>=" / ">>="
   }

   assign_expr <- (
      <patt> s <assop> s <expr>
   ) -> assignExpr

   new_expr <- (
      "new" <idsafe> s <member_expr> (
         s "(" s {| (<expr> (s "," s <expr>)*)? |} s ")"
         / {| |}
      )
   ) -> newExpr

   array_expr <- (
      "[" s {| <array_elements>? |} s "]"
   ) -> arrayExpr

   array_elements <- <expr> (s "," s <expr>)* (s ",")?

   object_expr <- (
      "{" s {| <object_members>? |} s "}"
   ) -> objectExpr

   object_members <- (
      <object_member> (s "," s <object_member>)* (s ",")?
   )
   object_member <- {|
      <prop_defn> / {:key: (<literal> / <ident>) :} s ":" s {:value: <expr> :}
   |} -> objectMember

   comp_expr <- (
      "[" s {| <comp_block>+ |} <expr> (s "if" <idsafe> s "(" s <expr> s ")")? s "]"
   ) -> compExpr

   comp_block <- (
      "for" <idsafe> s "(" s <patt> s "of" <idsafe> s <expr> s ")" s
   ) -> compBlock
]]

local grammar = re.compile(patt, defs)
local function parse(src)
   return grammar:match(src)
end

return {
   parse = parse
}


