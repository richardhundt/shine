local util = require("util")
local re   = require('re')
local defs = require('parser.defs')

local patt = [[
   chunk  <- {|
      s (<main_stmt> (<sep> s <main_stmt>)* <sep>?)? s (!. / '' => error)
   |} -> chunk

   close    <- ']' =eq ']' / . close

   lcomment <- (!%nl %s)* "--" (!%nl .)* %nl
   bcomment <- ('--[' {:eq: '='* :} '[' close)
   comment  <- <bcomment> / <lcomment>
   idsafe   <- !(%alnum / "_")
   s        <- (<comment> / %s)*
   S        <- (<comment> / %s)+
   hs       <- !%nl %s
   digits   <- %digit (%digit / (&('_' %digit) '_') %digit)*
   word     <- (%alpha / "_") (%alnum / "_")*

   keyword  <- (
      "local" / "function" / "class" / "module" / "meta"
      / "new" / "nil" / "true" / "false" / "return" / "end"
      / "yield" / "await" / "break" / "continue" / "not" / "throw"
      / "while" / "do" / "for" / "in" / "of" / "and" / "or"
      / "super" / "import" / "export" / "try" / "catch" / "finally"
      / "if" / "else" / "elseif" / "then" / "is" / "typeof"
      / "repeat" / "until"
   ) <idsafe>

   sep <- <bcomment>? (%nl / ";" / &"}" / <lcomment>) / %s <sep>?

   astring <- "'" { (!"'" .)* } "'"
   qstring <- '"' { (!'"' .)* } '"'
   lstring <- ('[' {:eq: '='* :} '[' close)

   special <- "\n" / "\$" / "\\" / "\" .

   rstring <- {|
      '`' (
         <raw_expr> / { (<special> / !(<raw_expr> / '`') .)+ }
      )* '`'
   |} -> rawString

   raw_expr <- (
      "%{" s <expr> s "}"
   ) -> rawExpr

   string  <- (
      <qstring> / <astring> / <lstring>
   ) -> string

   hexnum <- "-"? "0x" %xdigit+

   decimal <- "-"? <digits> "." <digits> (("e"/"E") "-"? <digits>)? -> tonumber

   integer <- "-"? <digits>

   octal   <- {~ { "-"? "0" [0-7]+ } -> octal ~}

   number  <- {~
      <hexnum> / <octal> / <decimal> / <integer>
   ~} -> tonumber

   boolean <- (
      {"true"/"false"} <idsafe>
   ) -> boolean

   literal <- ( <number> / <string> / <boolean> ) -> literal

   main_stmt <- (
        <module_decl>
      / <import_stmt>
      / <export_decl>
      / <stmt>
   )

   in  <- "in"  <idsafe>
   end <- "end" <idsafe>
   do  <- "do"  <idsafe>

   module_decl <- (
      "module" <idsafe> s <ident> s
         {| (<main_stmt> (<sep> s <main_stmt>)*)? |} s
      <end>
   ) -> moduleDecl

   export_decl <- (
      "export" <idsafe> s (<decl_stmt> / <module_decl>)
   ) -> exportDecl

   import_stmt <- (
      "import" <idsafe> s {| {"*"} / "{" s <ident> (s "," s <ident>)* s "}" |} s
      "from" <idsafe> s <string>
   ) -> importStmt

   stmt <- ({} (
      <if_stmt>
      / <while_stmt>
      / <repeat_stmt>
      / <for_stmt>
      / <for_in_stmt>
      / <do_stmt>
      / <expr_stmt>
      / <decl_stmt>
      / <return_stmt>
      / <try_stmt>
      / <throw_stmt>
      / <break_stmt>
   )) -> stmt

   stmt_list <- {|
      (<stmt> (<sep> s <stmt>)* <sep>?)?
   |}

   break_stmt <- (
      "break" <idsafe>
   ) -> breakStmt

   return_stmt <- (
      "return" <idsafe> s {| <expr_list> |}
   ) -> returnStmt

   throw_stmt <- (
      "throw" <idsafe> s <expr>
   ) -> throwStmt

   try_stmt <- (
      "try" <idsafe> s <block_stmt>
      {| <catch_clause>* |} (s "finally" <idsafe> s <block_stmt>)?
      s <end>
   ) -> tryStmt

   catch_clause <- (
      s "catch" <idsafe> s "(" s
      <ident> (s "if" <idsafe> s <expr>)? s ")" s <block_stmt> s
   ) -> catchClause

   decl_stmt <- (
      <local_decl> / <func_decl> / <class_decl>
   )

   local_decl <- (
      "local" <idsafe> s {| <name_list> |} (s "=" s {| <expr_list> |})?
   ) -> localDecl

   name_list <- (
      <ident> (s "," s <ident>)*
   )

   expr_list <- (
      <expr> (s "," s <expr>)*
   )

   func_path <- {|
      <ident> (s {"."/"::"} s <ident>)*
   |}

   func_decl <- (
      "function" <idsafe> s <func_path> "(" s {| <param_list>? |} s ")" s
      <func_body>
   ) -> funcDecl

   func_expr <- (
      "function" <idsafe> s "(" s {| <param_list>? |} s ")" s <func_body>
      / "(" s {| <param_list>? |} s ")" s "=>" s <func_body>
      / {| {| {:name: <ident> :} |} |} s "=>" s <func_body>
   ) -> funcExpr

   func_body <- <block_stmt> s <end> / <expr>

   class_decl <- (
      "class" <idsafe> s <ident> (s <class_heritage>)? s <class_body> s <end>
   ) -> classDecl

   class_body <- {|
      (<class_member> (<sep> s <class_member>)* <sep>?)?
   |}

   class_member <- (
      ({"meta"} <idsafe> s / '' -> "virt") <prop_defn>
   ) -> classMember

   class_heritage <- (
      "extends" <idsafe> s <expr> / {| |}
   )

   prop_defn <- (
      ({"get"/"set"} <idsafe> s / '' -> "init") <ident> s
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
      {| (<stmt> (<sep> s <stmt>)* <sep>?)? |}
   ) -> blockStmt

   if_stmt <- (
      "if" <idsafe> s <expr> s "then" <idsafe> s <block_stmt> (
           s "else" <if_stmt>
         / s "else" <idsafe> s <block_stmt> s <end>
         / s <end>
      )
   ) -> ifStmt

   for_stmt <- (
      "for" <idsafe> s <ident> s "=" s <expr> s "," s <expr>
      (s "," s <expr> / ('' -> '1') -> tonumber) s
      <loop_body>
   ) -> forStmt

   for_in_stmt <- (
      "for" <idsafe> s {| <name_list> |} s <in> s <expr> s
      <loop_body>
   ) -> forInStmt

   loop_body <- <do> s <block_stmt> s <end>

   do_stmt <- <loop_body> -> doStmt

   while_stmt <- (
      "while" <idsafe> s <expr> s <loop_body>
   ) -> whileStmt

   repeat_stmt <- (
      "repeat" <idsafe> s <block_stmt> s "until" <idsafe> s <expr>
   ) -> repeatStmt

   ident <- (
      !<keyword> { <word> }
   ) -> identifier

   term <- (
        <func_expr>
      / <nil_expr>
      / <super_expr>
      / <comp_expr>
      / <table_expr>
      / <array_expr>
      / <regex_expr>
      / <ident>
      / <literal>
      / <rstring>
      / "(" s <expr> s ")"
   )

   expr <- <infix_expr> / <new_expr> / <spread_expr>

   spread_expr <- (
      "..." <postfix_expr>
   ) -> spreadExpr

   nil_expr <- (
      "nil" <idsafe>
   ) -> nilExpr

   super_expr <- (
      "super" <idsafe>
   ) -> superExpr

   expr_stmt <- (
      {} (<assign_expr> / <update_expr> / <expr>)
   ) -> exprStmt

   binop <- {
      "+" / "-" / "~" / "/" / "**" / "*" / "%" / "^" / "|" / "&"
      / ">>>" / ">>" / ">=" / ">" / "<<" / "<=" / "<" / ".."
      / "!=" / "==" / ("or" / "and" / "is") <idsafe>
   }

   infix_expr  <- (
      {| <prefix_expr> (s <binop> s <prefix_expr>)+ |}
   ) -> infixExpr / <prefix_expr>

   prefix_expr <- (
      { "#" / "~" / "+" / "-" / "!" / ("not" / "typeof") <idsafe> } s <prefix_expr>
   ) -> prefixExpr / <postfix_expr>

   postfix_expr <- {|
      <term> (s <postfix_tail>)+
   |} -> postfixExpr / <term>

   postfix_tail <- {|
        { "." } s <ident>
      / { "::" } s <ident>
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
      / { "::" } s <ident>
      / { "[" } s <expr> s ("]" / '' => error)
   |}

   assop <- {
      "+=" / "-=" / "~=" / "**=" / "*=" / "/=" / "%="
      / "|=" / "&=" / "^=" / "<<=" / ">>>=" / ">>="
   }

   left_expr <- (
      <member_expr> / <ident>
   )

   assign_expr <- (
      {| <left_expr> (s "," s <left_expr>)* |} s "=" s {| <expr_list> |}
   ) -> assignExpr

   update_expr <- (
      <left_expr> s <assop> s <expr>
   ) -> updateExpr

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

   table_expr <- (
      "{" s {| <table_members>? |} s "}"
   ) -> tableExpr

   table_members <- (
      <table_member> (s (","/";") s <table_member>)* (s (","/";"))?
   )
   table_member <- (<prop_defn> / {|
      {:key: ("[" s <expr> s "]" / <ident>) :} s "=" s {:value: <expr> :}
   |} / <expr>) -> tableMember

   -- local t = { for x in y if x > 1 yield x + 1 }
   comp_expr <- (
      "[" s {| <comp_block>+ |}
      "yield" <idsafe> s <expr> s "]"
   ) -> compExpr

   comp_block <- (
      "for" <idsafe> s {| <name_list> |} s <in> s <expr>
      (s "if" <idsafe> s <expr>)? s
   ) -> compBlock

   regex_expr <- (
      "/" { ( "\\" / "\/" / !("/" / %nl) .)* } "/" {[gmi]*}
   ) -> regexExpr
]]

local grammar = re.compile(patt, defs)
local function parse(src)
   return grammar:match(src)
end

return {
   parse = parse
}


