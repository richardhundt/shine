# NAME

Shine - Object Oriented Lua Dialect

# SYNOPSIS

```
usage: shine [options]... [script [args]...].
Available options are:
  -e chunk	Execute string 'chunk'.
  -c ...  	Compile or list bytecode.
  -i      	Enter interactive mode after executing 'script'.
  -v      	Show version information.
  --      	Stop handling options. 
  -       	Execute stdin and stop handling options.
```

If `script` ends with a `.lua` extension it is parsed and executed
as Lua, otherwise it is passed to the Shine loader. In both cases
pre-compiled bytecode is detected and executed directly. The default
Shine file extension is `.shn`, which is used by `require`'s search
paths.

```
usage: shinec [options]... input output.
Available options are:
  -t type 	Output file format.
  -b      	List formatted bytecode.
  -n name 	Provide a chunk name.
  -g      	Keep debug info.
  -p      	Print the parse tree.
  -o      	Print the opcode tree.
```

# OVERVIEW

This document is written primarily for Lua hackers and assumes you
know Lua's semantics and syntax, and that you know what LPeg is.

# DESCRIPTION

Shine (Xhosa word for moon), is a loose super set of Lua which
adds OO features, array comprehensions, ranges, modules, a smarter
generic for loop, destructuring assignment, and more.

Kinda like C++ for Lua.

The goal of the project is to allow rapid experimentation with Lua's
surface syntax and semantics. So if you've ever felt that Lua is
too minimal, or missing that one killer feature, here's your chance
to build it and try it out.

Shine consists of an LPeg based parser and is built on top of
[TvmJIT](https://github.com/fperrad/tvmjit), which is itself a hack
around LuaJIT-2.0.3, and a minimal core runtime of builtin types
and functions.

The rest is pushed into libraries which come included.  Of course,
you still have access to all the Lua libraries out there as Shine
can load and run vanilla Lua code just fine.

Programming - if not in the large, then at least in the medium -
doesn't seem to be a goal for Lua (although there are some large
Lua code-bases out there). Shine aims to make it more feasible
though, by making a best effort to detect unresolved symbol names
statically and raising an error.  This means that the only globals
you can reference without a fully qualified name are those which
are pre-defined.

It also means that providing libraries such for accessing the file
system, sockets, threads, binary serialization, regular expressions,
JSON, HTTP and "fibers" (coroutines scheduled by an event-loop) is
also in scope.

Here's a quick sample showing some of the features:

```Lua
module shapes

   class Point
      -- default parameter values with guards
      self(x = 0 is 'number', y = 0 is 'number')
         self.x = x
         self.y = y
      end
   end

   -- single inheritance
   class Point3D extends Point

      -- constructor
      self(x = 0, y = 0, z = 0)
         super(x, y)
      end

      -- getters/setters
      set x(x)
         self._x = x
      end
      get x()
         return self._x
      end

      -- delegated meta-methods
      __tostring__()
         return "Point3D<%p>".format(self)
      end
   end

end

a = [ 'foo', 'bar', { answer = 42 }, 101 ]

-- destructuring assignment
[ x, y, { answer = z } ] = a

print x, y, z

-- short lambda syntax
a = ["a", "b", "c"].map (i, v) => i ~ v

-- string interpolation
answer = 42
print "the answer is ${answer}"

-- LPeg is a first class citizen
pattern = /
   text  <- {~ <item>* ~}
   item  <- <macro> | [^()] | '(' <item>* ')'
   arg   <- ' '* {~ (!',' <item>)* ~}
   args  <- '(' <arg> (',' <arg>)* ')'
   macro <- (
        ('apply' <args>) -> '%1(%2)'
      | ('add'   <args>) -> '%1 + %2'
      | ('mul'   <args>) -> '%1 * %2'
   )
/

s = "add(mul(a,b),apply(f,x))"
print(pattern.match(s))

```

## Language Basics

Block comments have been extended to include `--:<mark>: ... :<mark>:`
as well as supporting the Lua style block comments:

```
   --[[ Lua's block comment. ]]
   --:: But this also works. ::
   --:foo: And so does this. :foo:
```

The motivation for this is to allow you to add metadata hints to
the source to support documentation generators (for example).

Symbol names are the same as in Lua with the addition that `$` is
a valid character. For example `$_$` is a valid variable name.

Shine is a line oriented language, so to some degree whitespace
is significant. In particular, call expressions may have parentheses
omitted even when the arguments are not tables or constants (as in Lua).

This means that although you can say:

```
   answer = 42
   prefix = "the answer is: "
   print prefix, answer -- no parens
```

You can't say:

```
   answer = 42
   prefix = "the answer is: "

   print
   prefix, answer  -- WRONG
```

In the second case you need parentheses for the `print()` function call.

Moreover, in Shine, everything can be nested. You can have classes
and modules inside functions, and vice versa.

### Operators

Shine supports additional operators to Lua, adding C-style bitwise
operators. String concatenation is done using `~` instead of `..`
as the latter is reserved for ranges. The `**` operator replaces `^` as
exponentiation (`^` is bitwise xor instead).

Binary operators:

```
"+" "-" "~" "/" "**" "*" "%" "^"
"|" "&" ">>>" ">>" "<<"
">=" ">" "<=" "<"
"!=" "==" "or" "and" "is" "as"
"+=" "-=" "~=" "**=" "*=" "/=" "%=" "|=" "&=" "^=" "<<=" ">>>=" ">>="
"or=" "and="
".."
```

The `as` operator calls `setmetatable` internally, and `is` checks to see
if its left operand is an instance of its right.

Unary operators:

```
"#" "~" "+" "-" "not" "..."
```

Bitwise operators have been added using the `bit` library. All borrow from C:

```
b = a | 0x8000
c = b << 1
```

Since Shine is an OO language, the `.` operator is the equivalent
of Lua's `:` operator. To call a function statically, use the `::`
operator.

```
s = string::format("Hello %s", whom)
```

Additionally there is the spread prefix operator `...` which calls
`unpack` internally:

```
a = [1, 2, 3]
x, y, x = ...a
print(x, y, z) -- 1  2  3
```

### Null

Shine adds a addtional global singleton type `null` which is the
ctype `NULL`, which evaluates to `true` in a boolean context, but
`null == nil` still holds.

It's useful for adding holes to lists, passing to C libraries, and creating
segmentation faults (couldn't resist, sorry).

### Strings

Strings come in four flavours. Double quoted, double quoted long string,
single quoted, and single quoted long string. The double quoted variants
interpolate `${ <expr> }` escapes, whereas the single quoted strings don't.

The long versions are delimited with `"""` and `'''` for double and single
quoted strings respectively. All four strings types can span multiple lines.

```
s1 = 'another'
s2 = 'short'
s3 = "a ${s1} string and ${s2}" -- double quoted strings interpolate
s4 = "
    strings can span
    multiple lines
"
s5 = """
a Pythonesue long string
"""
s6 = '''
a long one where ${this doesn't interpolate}
'''
```

### Ranges

Ranges are a builtin which represent and generate sequences of numbers.

```
r = 1..10
for i in r do
   print i
end
```

Strings can be sliced with a range:

```
s = "Hello World!"
print s[1..4]

print "Hello World!"[1..4] -- also OK
```

### Structural Types

Shine makes a distinction between tables and arrays. Arrays have a metatable
are zero-based, and can have "holes". Tables are vanilla Lua tables.

```
a1 = [ "a", 2, "three" ]
t1 = { answer = 42, ["duff"] = "beer" }

-- newlines also count as pair separators
t2 = {
   foo = "bar"
   baz = "quux"
}

-- tables can still be a sequence as in Lua
t3 = { 'a', 'b', 'c' }

```

### Functions

Shine allows function calls without parentheses, and bare word
expressions are compiled as calls as well:

```
print "Hello", "World!" -- compiled as: print("Hello", "World!")

yield -- compiled as: yield()
```

Shine supports Lua-style function declarations:

```
function f(a, b, ...)
   -- just like Lua
end
local function g()
   -- just like Lua
end
```

Functions can also be declared on tables, however, note that
the meaning of the `.` replaces `:` in Lua, and `::` replaces Lua's `.`:

```
o = { }
function o.greet()
   -- implies self == o here
end
function o::munge()
   -- no self parameter
end
```

Shine also supports short function syntax:

```
addone = (x) => x + 1
addone 41

compare = (a, b) =>
   if a > b then
      return 1
   elseif a == b then
      return 0
   else
      return -1
   end
end -- required, body is not an expression
```

If the body of a function is not an expression, then a closing `end` is required

Combined with optional params, makes functional programming nicer
(note that the space after `map` is significant):

```
a = ["a","b","c"].map (i,v) => i ~ v
```

Functions can have default parameters:

```
function greet(whom = "World")
   print `Hello ${whom}!`
end
```

The last parameter of a function may be a rest parameter which
"slurps" up the remaining arguments into an Array:

```
function slurpy(arg1, ...args)
   print "argument 1 is ${arg1}"
   print "the rest of the arguments: ", ...args
end
```

Of course, you can still do it the Lua way:

```
function slurpy(arg1, ...)
   print "argument 1 is ${arg1}"
   print "the rest of the arguments: ", ...
end
```

### Generators

Functions declared with an asterisk are coroutine generators.

```
function* seq(x)
   for i in 1..x do
      yield i
   end
end
gen = seq(3)
print(gen()) -- 1
print(gen()) -- 2
print(gen()) -- 3

-- short syntax
powseq = *(x) =>
   for i in 1 .. 10 do
      yield i ** x
   end
end

squares = powseq(2)
for i in squares do
   if i % 2 == 0 then
      continue
   end
   print i
end

-- works for methods as well
class Foo
   *ticker()
      while true do
         yield "tick"
      end
   end
end
f = Foo()
g = f.ticker()
print g()
```

### Control structures

Shine supports the standard Lua if-then/elseif-then/else control structure:

```
if a > 10 then
   print "biggish"
elseif a > 10 and a < 5 then
   print "medium"
else
   print "widdle"
end
```

The familiar `while`, `repeat` and `for` loops are included as well.
However, the generic `for` loop implicitly does a `pairs` call on
its argument if it is not a function.

```
t = { aye = 'a', bee = 'b', see = 'c' }
for k,v in t do
   print k, '=>', v
end
```

Additionally we have `given/case` statements which try to be smart in matching
the discriminant and can also do pattern matching (case guards coming soon):

```
o = { answer = 42 }
given o
   case { answer = X } then -- this matches
      print "answer: ${X}"  -- X is extracted and in scope
   case 69 then
      print "got 69"
   else
      print "HUH?"
end
```

We also have `try/catch/finally` with optional guard expressions:

```
function foo()
   try
      throw Error("cheese")
      return 42
   catch e if e is Error then
      print("caught:", e)
      return 69
   catch e then
      print("something else")
   finally
      print('cleanup')
   end
end

print("GOT:", foo())
```

Just bear in mind that this still creates up to three closures
inline, so it's best to place loops inside the try block and not
around it.

### Classes

Shine supports single inheritance, static methods (via the `static`
prefix) and lexical class bodies (they're just functions internally).

```
class Point
   -- the constructor
   self(x = 0, y = 0)
      self.x = x
      self.y = y
   end

   -- getters and setters
   set x(v)
      self._x = v
   end
   get x()
      self._x
   end
end

class Point3D extends Point
   self.DEBUG = true -- static property

   self(x, y, z)
      super(x, y) -- call base class initializer
      self.z = z
   end

   -- static method (defined on Point)
   function self.__len()
      return super.__len() + 1
   end

   -- alternatively as a method (note the tailing "__")
   __len__()
      return super.__len__() + 1
   end
end
```

Additional `__getindex` and `__setindex` hooks are defined as metamethods,
and these delegate to `__get__` and `__set__` instance methods, if present,
respectively.

To overload the constructor, classes provide an `__apply` hook
(since `__call` must be defined on the class's metatable, so this
delegates down to the class object from the meta-class).

The `super` expression is a little special in that, although it's
just a variable like any other (you can assign to it), the compiler
will pass the value of `self` as an implicit parameter to any methods
called on it.

### Modules

Modules are containers for pieces of code. They're a lot like classes, but
without a constructor.

```
module armory
   local ANSWER = 42

   -- they can have getters/setters
   get answer()
      return ANSWER
   end
   set answer(v)
      ANSWER = v
   end

   -- they can contain other classes
   class PlasmaRifle
      trigger()
         print "pew pew"
      end
   end

   class BootKnife
      unsheath()
         print "snick"
      end
   end

end

gun = armory::PlasmaRifle()

```

Although only single inheritance is supported, Shine follows Ruby's
approach to module mixins via the `include <expr>[, ...<expr>]` statement:

```
module Explosive
   ignite()
      throw "BOOM!"
   end
end

class Grenade
   include Explosive
end

g = Grenade()
g.ignite() -- crashes your program
```

Modules are also callable, which lets you parametrize them during mixin:

```
module Explosive
   message = ...
   ignite()
      throw message
   end
end

class Grenade
   include Explosive "BOOM!"
end

g = Grenade()
g.ignite() -- also crashes your program

```

### Grammars

Grammars in Shine can either be introduced with the `grammar` statement, or
as an expression:

```
grammar Macro
   text  <- {~ <item>* ~}
   item  <- <macro> | [^()] | '(' <item>* ')'
   arg   <- ' '* {~ (!',' <item>)* ~}
   args  <- '(' <arg> (',' <arg>)* ')'
   macro <- (
        ('apply' <args>) -> '%1(%2)'
      | ('add'   <args>) -> '%1 + %2'
      | ('mul'   <args>) -> '%1 * %2'
   )
end

local s = "add(mul(a,b),apply(f,x))"
print(Macro.match(s))

-- same thing, but as an expression
g2 = /
   text  <- {~ <item>* ~}
   item  <- <macro> | [^()] | '(' <item>* ')'
   arg   <- ' '* {~ (!',' <item>)* ~}
   args  <- '(' <arg> (',' <arg>)* ')'
   macro <- (
        ('apply' <args>) -> '%1(%2)'
      | ('add'   <args>) -> '%1 + %2'
      | ('mul'   <args>) -> '%1 * %2'
   )
/
print(g2, g2.match(s))

```

The syntax for defining patterns borrows heavily from the `re.lua` module
shipped with LPeg. Notable differences are that `|` replaces re's `/` as an
alternative separator, `%pos` replaces `{}` as a position capture, and `+>`
replaces `=>` as a match-time capture and `~>` is added as a fold capture.

Unlike the `re.lua` module, grammars aren't represented as strings,
but are compiled to LPeg API calls directly, so production rules
for `->`, `~>` and `+>` captures can be any term or postfix expression
supported by the language itself.

Which means you can say `rule <- %digit -> function(c) ... end`
with functions inlined directly in the grammar.

It also means that patterns can be composed using the standard Lua
operators as with the LPeg library:

```
word = / { %alnum+ } /
patt = / %s+ / * word + function()
   error "d'oh!"
end
```

### Destructuring

Shine supports destructuring in assignment as well as in `given/case`
matching. For tables and arrays, Shine knows how to extract values for
you:

```
a = ['foo','bar','baz']
[x, y, z] = a
```

However, with objects you have to implement an `unapply` hook to make
it work. The hook is expected to return an iterator which would be valid
for use in a generic for loop. Here's an example:

```
class Point
   self(x = 0, y = 0)
      self.x = x
      self.y = y
   end
   function self.__unapply(o)
      return ipairs{ o.x, o.y }
   end
end

p = Point(42, 69)
Point(x, y) = p
print x, y  -- prints 42   69
```

### Symbol import and export

By default, all symbols declared in the top scope of a compilation unit
are public unless prefixed with `local`. If you want to explictly control
what is exported, the `export`, but still want your symbols anchored in
the module's environment, then you can use `export <name_list>`
which desugars to a `return { symbol1 = symbol1, ..., symbolN = symbolN }`
statement at the end of the compilation unit.

Public symbols can be imported with the `import` statement, which
has the form:

```
import (<alias> =)? <symbol>, ... from <expr>
```

An `import` calls `require` internally if <expr> is a string, otherwise
if it is a table then symbols are copied out of that. If it is neither,
you'll get an error.

Examples:

```
import create, yield from "coroutine"
import join = concat, push = insert from _G.table
```

Imported symbols are always private to the package. To re-export,
either assign the symbols to `_M`, use `export` or add an explicit
return at the end of the compilation unit to control what is exported
as with Lua.

## MAILING LIST

Get involved! http://www.freelists.org/list/shine

## ACKNOWLEDGEMENTS

* Francesco Abbate - my first early adopter with lots of contributions
* romix - giving me instant karma whenever I break master
* François Perrad - creating TvmJIT and keeping it up-to-date

