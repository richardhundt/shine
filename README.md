
```Lua
import like from "util.guards"

Shiny = like { luminosity = Number }

function bling(what is Shiny)
   print "\u2606\u20AC %{what.luminosity} \u20AC\u2606"
end

bling { luminosity = 42 }
```

# Shine Reference

This document aims to be a fairly concise, but broad reference.

To help get you started, though, have a look at the [wiki](https://github.com/richardhundt/shine/wiki)
which has a growing collection of tutorials.

* [Introduction](#introduction)
* [Philosophy](#philosophy)
* [Getting Started](#getting-started)
* [Language Basics](#language-basics)
  * [Comments](#comments)
  * [Identifiers](#identifiers)
  * [Scoping](#scoping)
  * [Builtin Types](#builtin-types)
    * [Booleans](#booleans)
    * [Numbers](#numbers)
    * [`nil` and `null`](#nil-and-null)
    * [Strings](#strings)
    * [Ranges](#ranges)
    * [Tables](#tables)
    * [Arrays](#arrays)
    * [Patterns](#patterns)
  * [Expressions](#expressions)
    * [Operators](#operators)
    * [Call Expressions](#call-expressions)
    * [Member Expressions](#member-expressions)
    * [Assignment](#assignment)
    * [Destructuring](#destructuring)
    * [Comprehensions](#comprehensions)
    * [Lambda Expressions](#lambda-expressions)
  * [Statements](#statements)
    * [Do Statement](#do-statement)
    * [If Statement](#if-statement)
    * [Given Statement](#given-statement)
    * [While Statement](#while-statement)
    * [Numeric For Loop](#numeric-for-loop)
    * [Generic For Loop](#generic-for-loop)
    * [Try Statement](#try-statement)
    * [Import Statement](#import-statement)
    * [Export Statement](#export-statement)
  * [Guards](#guards)
  * [Functions](#functions)
  * [Generators](#generators)
  * [Modules](#modules)
  * [Classes](#classes)
    * [Methods](#methods)
    * [Properties](#properties)
    * [Constructor](#constructor)
    * [Inheritance](#inheritance)
    * [Module Mixins](#module-mixins)
  * [Grammars](#grammars)
  * [Decorators](#decorators)
  * [Macros](#macros)
* [Standard Libraries](#standard-libraries)
  * [Concurrency](#concurrency)
    * [Fibers](#fibers)
    * [Threads](#threads)
  * [Serialization](#serialization)

## <a name="introduction"></a>Introduction

Shine is a general purpose, dynamic, multi-paradigm programming
language which is based on, and extends, Lua with features geared
more to programming in the large. For maximum performance it uses
a [modified](https://github.com/fperrad/tvmjit) version of the
[LuaJIT](http://luajit.org) virtual machine, which is known for its
small footprint and impressive performance which rivals that of C.

Most of the language features are those of the underlying LuaJIT
VM, and the extensions are implemented in terms of lower level
constructs already present in LuaJIT, so anyone familiar with
Lua and LuaJIT should quickly feel right at home with Shine.

Moreover, vanilla Lua libraries can be loaded and run unmodified,
and although compilation of Lua code is slower than with LuaJIT or
PuC Lua, there is no additional runtime penalty, and since they
share the same bytecode, this means that Shine users can leverage
all of the existing Lua libraries out there without writing wrappers
or additional bindings. You can, of course, call seamlessly into
Shine code from Lua too, as long as Lua is running within the
Shine runtime.

Another goal of Shine, is that the standard libraries which are
included are focused on providing
[CSP](http://en.wikipedia.org/wiki/Communicating_sequential_processes)
style concurrency, so although the language itself has no concurrency
primitives, the fibers, channels, threads, pipes and I/O libraries
are all centered around building highly scalable, low-footprint,
network oriented concurrent applications.

## <a name="philosophy"></a>Philosophy

Shine strives for a pragmatic balance between safety and syntactic
and semantic flexibility.

Summary of safety features:

* Static local variable name resolution.
* Default declaration scope is localized.
* Function and method parameter guards.
* Scoped variable guards.
* Self-type assertions in methods.

Summary of flexibility features:

* Operator meta-methods as in Lua with Shine specific extensions.
* Deep introspection into nominal types.
* Lambda expressions (short function syntax).
* Optional parentheses.
* Property getters and setters with fallback.
* User-only operators.
* Procedural Macros
* Decorators

Additionally, all constructs can be nested. Classes can be declared
inside other classes and even inside functions, which allows for
run-time construction of classes, modules and grammars.

Other notable extensions to Lua:

* Bitwise operators.
* Standard libraries.
* Tight LPeg integration.
* Classes and modules .
* `continue` statement.
* `try`, `catch`, `finally`
* Destructuring assignment.
* Pattern matching.
* Default function parameters.
* Parameter and variable guards.
* Richer type system.
* Concurrency primitives
* OS Threads

## <a name="getting-started"></a>Getting Started

Shine ships with all its dependencies, so simply clone the git
repository and run `make && sudo make install`:

```
$ git clone --recursive https://github.com/richardhundt/shine.git
$ make && sudo make install
```

Standard `package.path` and `package.cpath` values set up by virtual machine
could be customized with passing `TVMJIT_PREFIX` and `TVMJIT_MULTILIB`
parameters to `make`. It could be useful for accessing Lua libraries installed
by standard Linux distro way. For example, on Debian following parameter
values could be used:

```
$ make TVMJIT_PREFIX=/usr TVMJIT_MULTILIB="lib/$(gcc -print-multiarch)" && sudo make install
```

This will install two executables `shinec` and `shine` (along with standard
library).  The `shinec` executable is just the compiler and has the following
usage:

```
usage: shinec [options]... input output.
Available options are:
  -t type   Output file format.
  -b        List formatted bytecode.
  -n name   Provide a chunk name.
  -g        Keep debug info.
  -p        Print the parse tree.
  -o        Print the opcode tree.
```

The main executable and runtime is `shine`, which includes
all the functionality of `shinec` via the `-c` option and
has the following usage:

```
usage: shine [options]... [script [args]...].
Available options are:
  -e chunk  Execute string 'chunk'.
  -c ...    Compile or list bytecode.
  -i        Enter interactive mode after executing 'script'.
  -v        Show version information.
  --        Stop handling options. 
  -         Execute stdin and stop handling options.
```

The `script` file argument extension is significant in that
files with a `.lua` extension are passed to the built-in Lua
compiler, whereas files with a `.shn` extension are compiled
as Shine source.

Shine has been tested on Linux and Mac OS X, and support for
Windows is in progress.

## <a name="language-basics"></a>Language Basics

Shine is a line-oriented language. Statements are generally seperated
by a line terminator. If several statements appear on the same line, they
must be may be separated by a semicolon `;`.

Long expressions with infix operators may be wrapped with the operator
leading after the line break, however for function and method calls, the
argument list must start on the same line as the callee:

```
a = 40
  + 2 -- OK

foo
  .bar() -- OK

print "answer:", 42 -- OK [means: print("answer:", 42)]

print(
  "answer:", 42 -- OK
)

print
  "answer:", 42 -- BAD [syntax error]
```

A bare word by itself is parsed as a function call:

```
if waiting then
   yield -- compiles as yield()
end
```

### <a name="comments"></a>Comments

Comments come in 3 forms:

* Lua-style line comments starting with `--`
* Lua-style block comments of the form `--[=*[ ... ]=*]`
* Shine block comments of the form `--:<token>([^)]*)?: ... :<token>:`

The last form is designed to allow Shine sources to be annotated
for processing by external tools such as documentation generators:

```
-- a line comment

--[[
a familiar Lua-style
block comment
]]

--::
simple Shine block comment
::

--:md(github-flavored):
perhaps this is extracted by a markdown processor
:md:
```

### <a name="identifiers"></a>Identifiers

Identifiers must start with `[a-zA-Z_$!?]` (alphabetical characters
or `_` or `$` or `!` or `?`) which may be followed by zero or more
`[a-zA-Z_$!?0-9]` characters (alphanumeric or `_` or `$` or `!` or `?`).

```
$this_is_valid
so_is_$this
!this_is_valid_too
unusual?_but_still_valid
```

### <a name="scoping"></a>Scoping

Shine scoping rules are similar to Lua's with the addition of the concept
of a default storage if `local` is not specified when introducing a new
declaration.

The default storage for variables is always `local`. For other
declarations, it depends on the enclosing scope:

* If at the top level of a compilation unit, the default is package
  scoped for all non-variable declarations.
* Inside class and module bodies, the default is scoped to the body
  environment.
* Everwhere else (i.e. functions and blocks) it is `local`.

Declarations can always be lexically scoped by declaring them as `local`.

In short, what this means is that most of the time you can simply leave out
the `local` keyword without worrying about creating globals or leaking out
declarations to the surrounding environment.

There are cases where a `local` is useful for reusing a variable name in
a nested scope when the inner scope should shadow the variable in the outer
scope.

### <a name="builtin-types"></a>Builtin Types

Shine includes all of LuaJIT's builtin types:

* `nil`
* `boolean`
* `number`
* `string`
* `table`
* `function`
* `thread` (coroutine)
* `userdata`
* `cdata`

All other extensions are built primarily using `table`s and `cdata`.

These include:

Primitive meta types:

* `Nil`
* `Boolean`
* `Number`
* `String`
* `Table`
* `Function`
* `Coroutine`
* `UserData`
* `CData`

Additional builtins:

* `null` (CData meta type)
* `Array`
* `Range`
* `Error`

Nominal meta types:

* `Class`
* `Module`
* `Grammar`

Pattern matching meta types:

* `Pattern`
* `ArrayPattern`
* `TablePattern`
* `ApplyPattern`

The meta meta type:

* `Meta`

#### <a name="booleans"></a>Booleans

The constants `true` and `false`. The only values which are logically
false are `false` and `nil`. Everything else evaluates to `true` in a
boolean context.

#### <a name="numbers"></a>Numbers

The Shine parser recognizes LuaJIT `cdata` long integers as well as
Lua numbers. This is extended with octals.

The following are represented as Lua `number` type:

* `123`
* `123.45`
* `1.2e3`
* `0x42` - heximal
* `0o644` - octal

These are LuaJIT extensions enabled by default in Shine:

* `42LL` - LuaJIT long integer `cdata`
* `42ULL` - LuaJIT unsigned long integer `cdata`

#### <a name="nil-and-null"></a>`nil` and `null`

The constant `nil` has exactly the same meaning as in Lua.

The constant `null` is exactly the cdata `NULL` value. It compares
to `nil` as true, however, unlike in C, in a boolean context also
evaluates to true. That is, although `null == nil` holds, `if null
then print 42 end` will print "42".

#### <a name="strings"></a>Strings

As in Lua, strings are 8-bit clean, immutable and interned. The
extensions added by Shine relate to delimiters, escape sequences
and expression interpolation.

There are two types of strings:

* Single quoted
* Double quoted

Single quoted strings are verbatim strings. The only escape sequences
which they recognise are `\'` and `\\`. All other bytes are passed
through as is.

Double quoted strings allow the common C-style escape sequences, including
unicode escapes. These are all valid strings:

```
"text"
"tab\t"
"quote\""
"\x3A"      -- hexadecimal 8-bits character
"\u20AC"    -- unicode char UTF-8 encoded
"
multiline
string
"
```

Additionally, double quoted strings interpolate expressions inside
`%{` and `}` marks. When constructing strings programmatically it
is encouraged to use this form as the fragments produced are
concatenated in a single VM instruction without creating short-lived
temporary strings.

```
"answer = %{40 + 2}" -- interpolated
```

Both types of strings can be delimited with single and triple
delimiters. This is just a convenience to save escaping quotation
marks:

```
"a quoted string"
"""a triple quoted string"""
'a verbatim string'
'''a triple quoted verbatim string'''
```

##### <a name="string-operations"></a>String Operations

Strings have a metatable with all the methods supported by Lua,
namely: `len`, `match`, `uppper`, `sub`, `char`, `rep`, `lower`,
`dump`, `gmatch`, `reverse`, `byte`, `gsub`, `format` and `find`.

Shine adds a `split` method with the following signature:

* `str.split(sep = '%s+', max = math::huge, raw = false)`

Splits `str` on `sep`, which is interpreted as a Lua match pattern
unless `raw` is `true`. The default value for `sep` is `%s+`. If
`max` is given, then this is the maximum number of fragments returned.
If the pattern is not found, the `split` returns the entire string.
The `split` method is only available as a method, and is not defined
in the `string` library.

Strings can additionally be subscripted with numbers and ranges.
Both subscripts have the effect of calling `string.sub()` internally.
If a number is passed then a single character is returned at that
offset, otherwise the two extremes of the range are passed to
`string.sub`.  Negative offsets may be used.

#### <a name="ranges"></a>Ranges

Ranges are objects which represent numeric spans and are constructed with
`<expr> .. <expr>`. They can be used for slicing strings, or for looping
constructs.

#### <a name="tables"></a>Tables

Tables work just as in Lua with the addition that line-breaks serve as
separators, in addition to `,` and `;`

```
-- these are equivalent
t = { answer = 42, 1, 'b' }
t = {
    answer = 42
    1
    'b'
}
```

#### <a name="arrays"></a>Arrays

Arrays are zero-based, numerically indexed lists of values, based on Lua
tables, with the difference being that they track their length, and so
may contain `nil` values.

Arrays have a literal syntax delimited by `[` and `]` as in languages
such as Perl, JavaScript or Ruby, but may also be constructed by
calling `Array(...)`.

```
a = [ 1, 'two', 33 ]
a = Array(1, 'two', 33) -- same thing
```

The array type defines the following methods:

* `join(sep = '')`

* `push(val)`

* `pop()`

* `shift()`

* `unshift(val)`

* `slice(offset, count)`

  Returns a new array with `count` elements, starting at `offset`.

* `reverse()`

  Returns a new array with elements in reverse order.

* `sort(cmp = less, len = #self)`

  Sorts the array in place using the comparison function `cmp` if given
  and limits the number of items sorted to `len` if provided.

#### <a name="patterns"></a>Patterns

Shine integrates Parsing Expression Grammars into the language as
a first-class type, thanks to the excellent
[LPeg](http://www.inf.puc-rio.br/~roberto/lpeg/) library.

Patterns are delimited by a starting and ending `/`, which borrows from
commonly used regular expression quotation. However, Shine's patterns
are very different and far more powerful than regular expressions.

Syntax borrows heavily from the [re.lua](luahttp://www.inf.puc-rio.br/~roberto/lpeg/re.html) module.  Notable differences are that `|` replaces re's `/` as an
alternation separator, `%pos` replaces `{}` as a position capture, and `+>`
replaces `=>` as a match-time capture. Fold captures are added using `~>`.

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

### <a name="expressions"></a>Expressions

Expressions are much the same as in Lua, with a few changes and some
additions, notable C-style bitwise operators.

String concatenation is done using `~` instead of `..` as the latter
is reserved for ranges. The `**` operator replaces `^` as exponentiation
(`^` is bitwise xor instead).

Moreover, methods can be called directly on literals without the need to
surround them in parentheses. So whereas in Lua one would say:

```
local quote = ("%q"):format(val)
```

in Shine it's simply:

```
local quote = "%q".format(val)
```

#### <a name="operators"></a>Operators

The following table lists Shine's operators in order of increasing
precedence. Operators marked with a trailing `_` are unary operators.

| Operator | Precedence | Associativity | Comment |
|----------|------------|---------------|---------|
| `..._`   | 1          | right         | unpack |
| `or`     | 1          | left          | logical or |
| `and`    | 2          | left          | logical and |
| `==`     | 3          | left          | equality |
| `!=`     | 3          | left          | inequality |
| `is`     | 4          | left          | type equality |
| `as`     | 4          | left          | type coercion |
| `>=`     | 5          | left          | greater than or equal to |
| `<=`     | 5          | left          | less than or equal to |
| `>`      | 5          | left          | greater than |
| `<`      | 5          | left          | less than |
| &#124;   | 6          | left          | bitwise or |
| `^`      | 7          | left          | bitwise exclusive or |
| `&`      | 8          | left          | bitwise and |
| `<<`     | 9          | left          | bitwise left shift |
| `>>`     | 9          | left          | bitwise right shift |
| `>>>`    | 9          | left          | bitwise arithmetic right shift |
| `~`      | 10         | left          | concatenation |
| `+`      | 10         | left          | addition |
| `-`      | 10         | left          | subtraction |
| `..`     | 10         | right         | range |
| `*`      | 11         | left          | multiplication |
| `/`      | 11         | left          | division |
| `%`      | 11         | left          | remainder (modulo) |
| `~_`     | 12         | right         | bitwise not |
| `!_`     | 12         | right         | logical not |
| `not_`   | 12         | right         | logical not |
| `**`     | 13         | right         | exponentiation |
| `#_`     | 14         | right         | length of |

Many infix operators are also available in update, or assigment, form:

| Operator  | Comment |
|-----------|---------|
| `+=`      | add assign |
| `-=`      | subtract assign |
| `~=`      | concatenate assign |
| `*=`      | multiply assign |
| `/=`      | divide assign |
| `%=`      | modulo assign |
| `**=`     | exponentiation assign |
| `and=`    | logical and assign |
| `or=`     | logical or assign |
| `&=`      | bitwise and assign |
| &#124;=   | bitwise or assign |
| `^=`      | bitwise xor assign |
| `<<=`     | bitwise left shift assign |
| `>>=`     | bitwise right shift assign |
| `>>>=`    | bitwise arithmetic right shift assign |

The following operators are used in [patterns](#patterns):

| Operator | Precedence | Associativity | Comment |
|----------|------------|---------------|---------|
| `~>`     | 1          | left          | fold capture |
| `->`     | 1          | left          | production capture |
| `+>`     | 1          | left          | match-time capture |
| &#124;   | 2          | left          | ordered choice |
| `&_`     | 3          | right         | lookahead assertion |
| `!_`     | 3          | right         | negative lookahead assertion |
| `+`      | 3          | left          | one or more repetitions |
| `*`      | 3          | left          | zero or more repetitions |
| `?`      | 3          | left          | zero or one |
| `^+`<N>  | 4          | right         | at least `N` repetitions |
| `^-`<N>  | 4          | right         | at most `N` repetitions |

Not listed above are the common `(` and `)` for grouping, and
postcircumfix `()` and `[]` operators for function/method calls and
subscripting respectively.

In addition to the built-in operators, Shine exposes a full suite
of user-definable operators, which share precedence with their
built-in counterparts, but have no intrinsic meaning to the language.

Shine will simply try to call the corresponding meta-method as with
the built-in operators. The full listing is:

| Operator | Precedence | Associativity | Meta-Method |
|----------|------------|---------------|-------------|
|`:!`      | 3          | left          | `__ubang`   |
|`:?`      | 3          | left          | `__uques`   |
|`:=`      | 5          | left          | `__ueq`     |
|`:>`      | 5          | left          | `__ugt`     |
|`:<`      | 5          | left          | `__ult`     |
|:&#124;   | 6          | left          | `__upipe`   |
|`:^`      | 7          | left          | `__ucar`    |
|`:&`      | 8          | left          | `__uamp`    |
|`:~`      | 10         | left          | `__utilde`  |
|`:+`      | 10         | left          | `__uadd`    |
|`:-`      | 10         | left          | `__usub`    |
|`:*`      | 11         | left          | `__umul`    |
|`:/`      | 11         | left          | `__udiv`    |
|`:%`      | 11         | left          | `__umod`    |

#### <a name="call-expressions"></a>Call Expressions

When calling a function, method, or other callable, parenthesis
may be omitted provided there is either at least one argument.
The following are all valid:

```
fido.bark(loudness)
fido.move x, y          -- fido.move(x, y)
```

As a special case, if the callee is a single word as a statement
on its own, then no parentheses or arguments are required:

```
yield                   -- OK yield()
fido.greet              -- BAD (not a word)
print yield             -- BAD (yield not a statement)
```

#### <a name="member-expressions"></a>Member Expressions

Member expressions have three lexical forms:

* method call
* property call
* property access

Shine deviates from Lua in that the `.` operator when followed by
a call expression is a method call, whereas Lua uses `:`. To call
a property without passing an implicit receiver, use `::` instead:

```
s.format(...)          -- method call (self is implicit)
string::format(s, ...) -- property call
```

For property access, either `::` or `.` may be used with identical
semantics. By convention, one may prefer `::` for indicating namespace
access such as `async::io::StreamReader`, whereas `.` may be used to
access instance members.

#### <a name="assignment"></a>Assignment

Assignment expressions are based on Lua allowing multiple left and
right hand sides. If an identifier on the left is previously
undefined, then a new local variable is automatically introduced
the fist time it is assigned.  This prevents global namespace
pollution. Examples:

```
a, b = 1, 2             -- implicit locals a, b
o.x, y = y, o.x         -- implicit local y 
local o, p = f()        -- explicit
a[42] = 'answer'
```

#### <a name="destructuring"></a>Destructuring

Shine also supports destructuring of tables, arrays and application
patterns. This can be used during assignment as well as pattern
matching in [given](#given-statement) statements.

For tables and arrays, Shine knows how to extract values for you:

```
a = ['foo', { bar = 42 }, 'baz']
[x, { bar = y }, z] = a
print x, y, z           -- prints: foo  42  baz
```

However, with objects you have to implement an `__unapply` hook to make
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
print x, y              -- prints: 42   69
```

[Patterns](#patterns) already implement the relevant hooks, so the following
works as expected:

```
Split2 = / { [a-z]+ } %s+ { [a-z]+ } /
str = "two words"

Split2(a, b) = str

assert a == 'two' and b == 'words'
```

#### <a name="comprehensions"></a>Comprehensions

Comprehensions are an experimental feature only implemented for
arrays currently. They are also _not_ lazy generators. They should
look familiar to Python programmers. Here are two examples:

```
a1 = [ i * 2 for i in 1..10 if i % 2 == 0 ]
a2 = [ i * j for i in 1..5 for j in 1..5 ]
```

#### <a name="lambda-expressions"></a>Lambda Expressions

Shine has a syntactic short-hand form for creating functions:

`(<param_list>)? => <func_body> <end>`

The parameter list is optional.

```
-- these two are identical
f1 = (x) =>
   return x * 2
end
function f1(x)
    return x * 2
end
```

Additionally, if the function body contains a single expression
and appears on one line, then an implicit `return` is inserted
and the `end` token is omitted:

```
b = a.map((x) => x * 2)

-- shorter still
b = a.map (x) => x * 2
```

Means:

```
b = a.map((x) =>
   return x * 2
end)
```

### <a name="statements"></a>Statements

#### <a name="do-statement"></a>Do Statement

`do <chunk> end`

Same as in Lua.

#### <a name="if-statement"></a>If Statement

`if <expr> then <chunk> (elseif <expr> then <chunk>)* (else <chunk>)? end`

Same as in Lua.

#### <a name="given-statement"></a>Given Statement

`given <expr> (case <bind_expr> then <chunk>)* (else <chunk>)? end`

This is analogous to C's `switch` statement, however, the discriminant
is not simply compared for equality. Instead, Shine provides pattern
and smart matching capabilities.

If `<bind_expr>` is not an extractor used for destructuring:

* If the `<bind_expr>` evaluates to an object which implements a
  `__match` metamethod, then this is used to determine of the
  discriminant given by `<expr>` matches.

* Otherwise the `is` operator is used for comparison.

If `<bind_expr>` is a destructuring expression, then the extractor
is bound and evaluated.

Example:

```
function match(disc)
   given disc
      case "Hello World!" then
         print "a greeting"
      case String then
         print "a string"
      case { answer = A } then
         print "%{A} is the answer"
      else
         print "something else"
   end
end
match "Hello World!"    -- prints: "a greeting"
match "cheese"          -- prints: "a string"
match { answer = 42 }   -- prints: "42 is the answer"
match 42                -- prints: "something else"
```

#### <a name="while-statement"></a>While Statement

`while <expr> do <chunk> end`

Same as in Lua.

#### <a name="repeat-statement"></a>Repeat Statement

`repeat <chunk> until <expr>`

Same as in Lua.

#### <a name="numeric-for-loop"></a>Numeric For Loop

`for <ident>=<init>,<limit>,<step> do <chunk> end`

Same as in Lua.

#### <a name="generic-for-loop"></a>Generic For Loop

`for <name_list> in <expr_list> do <chunk> end`

Generally works as in Lua, except that you don't need to use `pairs`
as it is called implicitly (via a builtin called `__each__`), if
the first argument in `<expr_list>` is not a function.

The builtin `__each__` also calls a meta-method hook `__each`. This
allows objects to differentiate `pairs`, `ipairs` iterators which
return pairs, from the notion of a /default/ iterator, which may
return an arbitrary number of values.

#### <a name="try-statement"></a>Try Statement

`try <chunk> (catch <ident> (if <expr>)? then <chunk>)* (finally <chunk>)? end`

Does an `xpcall` internally, however it ensures that the `finally` clause is
run, even if `return` is used in the `try` block or one of the `catch`
bodies.

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

--:output:

caught:  cheese
cleanup
GOT:    69

--:output:
```

Just bear in mind that this still creates up to three closures
inline, so it's best to place loops inside the try block and not
around it.

#### <a name="import-statement"></a>Import Statement

`import macro? (<alias> = )? <symbol> (, (<alias> = )? <symbol>)* from <expr>`

Calls `require(expr)` and then extracts and assigns the named symbols
to `local` variables. May be used anywhere.

`import macro ...` doesn't assign the named symbols to `local` variables, but
introduces them as [macros](#macros) in current scope. `import macro ..` is a
compile time statement evaluated in translating phase.

Alternative syntaxes:
```
import macro? <module_path>.<symbol>
import macro? <module_path>.{(<alias> = )? <symbol> (, (<alias> = )? <symbol>)*}
```

`import a.b.{x = m, y = n}` is equivalent to `import x = m, y = n from "a.b"`

#### <a name="export-statement"></a>Export Statement

`export <ident> (, <ident>)*`

Copies the values refered to by the identifiers into a table which is
returned by the compilation unit. By default, the `_M` table is visible
along with all non-local declarations being available for import or
public access. By using an explicit `export`, only the symbols declared
are exported and the compilation unit's namespace is essentially sealed.

The `export` statement may not precede the declarations which are being
exported.

### <a name="guards"></a>Guards

Variables and function parameters can have guards associated with them.
The Shine compiler inserts checks which are executed at runtime each
time the variable is updated, or in the case of parameters, on
function entry.

A variable guard is introduced by using the `is` keyword in a
declaration:

```
local a is Number = 42

-- or simply
b is Number = 101

-- works for destructuring too:
{ x is Number = X, y is Number = Y } = point
```

The mechanics are simple: The right hand side of a guard expression
can be any object which implements an `__is` hook. If the hook
returns a non-true value, an error is raised.

The builtin types such as `Number`, as well as classes and modules
already have the `__is` hook implemented, so these should "just work".

Guards are lexically bound, static entities. That is, the value of
the variable does not carry around additional run-time meta-data
with it, so passing it to a different scope (or returning it) does
not guarantee that its type remains constrained:

```
function random()
   local x is Number = math::random()
   return x
end

x = random()
x = "cheese"        -- no error here
```

However, in practice, functions and methods can enforce a contract:

```
function addone(x is Number)
   return x + 1
end
addone "cheese"     -- Error: bad argument #1 to 'addone'...
```

### <a name="functions"></a>Functions

Functions are closures with all the same semantics as in Lua, however
Shine extends function declarations with _default parameter expressions_,
_parameter guards_, and _rest arguments_.

Default parameter expressions can be any valid Shine expression and are
scoped to the body of the function. That is, they are evaluate at the top
of the function body.

```
function greet(whom = "World")
   print "Hello %{whom}!"
end
greet()             -- prints: "Hello World!"
greet("romix")      -- prints: "Hello romix!"
```

Since defaults can be any expression, they can be used to enforce a
contract:

```
function addone(n = assert(type(n) == 'number') and n)
   return n + 1
end
```

However, this can be better achieved using _parameter guards_. Guards
are checked against by using the `is` operator, and if they evaluate
to `false`, an error is raised.

```
function addone(n is Number)
   return n + 1
end

addone(40)          -- OK
addone("cheese")    -- bad argument #1 to 'addone' (Number expected got String)
```

Like in Lua, functions can be declared on tables. However, the `.` notation
defines a method with an implicit `self`, whereas the `::` notation does not.
Therefore the `.` is the equivalent of Lua's `:`, and `::` is the equivalent
of Lua's `.`. For example:

```
o = { }
function o.greet()
   print "Hi, I'm %{self}"      -- implicit self parameter
end
function o::greet()
   print self                   -- Error: self is undefined
end
```

Calling functions attached to tables follows the same conventions,
with `.` passing the receiver, whereas `::` does not.

Lastly, although the Lua-style `...` notation may be used for
"vararg" functions as the last parameter. Shine extends this by
adding `...<ident>` syntax. This has the effect of collecting the
remaining arguments and packing them into an array:

```
-- the Lua way
function luaesque(...)
   for i=1, select('#', ...) do
      a = select(i, ...)
      print "arg: %{i} is %{a}"
   end
   return ...
end

-- the Shine way
function shiny(...args)
   for i, v in args do
      print "arg: %{i} is %{v}"
   end
   return ...args   -- unpack
end
```

Of course, the Lua way may often be preferred, especially for
performance sensitive code which passes `...` along to avoid
allocating arrays at each invocation.

### <a name="generators"></a>Generators

Generators are special functions which return a wrapped coroutine
up invocation. Generators are declared as functions decorated with
a `*`. The position of the asterisk depends on whether the generator
is declared using long or short syntax.

The long syntax takes the form:

`function* '(' <param_list> ')' <chunk> end`

Example:

```
function* seq(x)
   -- inside the coroutine
   for i in 1..x do
      yield i       -- i.e. coroutine::yield(i)
   end
end
gen = seq(3)

print gen()         -- prints: 1
print gen()         -- prints: 2
print gen()         -- prints: 3
```

The short syntax takes the form:

`*'(' <param_list> ')' => (<nl> <chunk> end) | <expr>`

Example:

```
seq = *(x) =>
   -- inside the coroutine
   for i in 1..x do
      yield i       -- i.e. coroutine::yield(i)
   end
end
gen = seq(3)

print gen()         -- prints: 1
print gen()         -- prints: 2
print gen()         -- prints: 3
```

Generators can also be defined as [class members](#methods)


### <a name="classes"></a>Classes

Classes are Lua tables used as constructors and metatables for their
instances. A class is declared using the `class` keyword, which has
the following form.

`class <ident> (extends <expr>)? <chunk> end`

Classes support single inheritance with implementation sharing via module
mixins. Much like Ruby.

Class bodies are closures internally, so all the ordinary scoping rules for
functions apply. Two parameters `self` and `super` are passed to the class
body, where `super` either references the base class, or the builtin `Object`
if no base class is specified.

The behaviour expressed by a class is contained in three special
tables attached to the class as properties: `__members__`, `__getters__`
and `__setters__`.

Shine overloads the `__index` and `__newindex` metamethods to
delegate to these tables - as well as two fallbacks: `__getindex`,
and `__setindex` - according to the following rules:

* if the access is a read access (`__index` hook)
  * if `__getters__` contains the key, then call `__getters__[key](obj)`
  * otherwise if `__members__` defines the key, return `__members__[key]`
  * otherwise if `class.__getindex` is defined, call `__getindex(obj, key)`
  * otherwise return `nil`

* if the access is a write access (`__newindex` hook)
  * if `__setters__` contains the key, then call `__setters__[key](obj, val)`
  * otherwise, if `class.__setindex` is defined, call `__setindex(obj, key, val)`
  * otherwise call `rawset(obj, key, val)`

#### <a name="methods"></a>Methods

Methods are shared by all instances, and attached to the class's
`__members__` property, keyed on their name, who's value is an
ordinary function, with an implicit `self` parameter.

Methods are introduced with an identifier followed by the parameters
and the body:

`<ident> '( <param_list> ')' <chunk> end`

The `function` keyword is omitted. This allows functions local to
the class body to be distinguised from instance methods. Here is
the canonical `Point` class in Shine, with comments to illustrate:

```
class Point
   -- constructor
   self(x = 0, y = 0)
      self.x = x    -- property 'x'
      self.y = y    -- property 'y'
   end

   -- instance method
   move(dx, dy)
      self.x = delta(self.x, dx)
      self.y = delta(self.y, dy)
   end

   -- class-scoped function
   function delta(v, dv)
      return v + dv
   end
end
```

As a special case, generators may also be declared as methods, if
they are prefixed with a `*`:

```
class Bomb
   *ticker()
      while true do
         yield "tick"
      end
   end
end
b = Bomb()
g = b.ticker()
print g()       -- prints: "tick"
```

#### <a name="properties"></a>Properties

Properties are typically not part of the class model, and can be
simply set inside the constructor, or externally as needed.

For cases where more control is needed, however, classes may also
define /getters/ and /setters/, which are method declarations
prefixed with `get` or `set` respectively. These special methods
behave like properties in that they can be read from or assigned
to as with ordinary properties by users of the objects, but they
are invoked by the runtime as methods on the object. The following
illustrates:

```
class Point
   set x(x)
      self._x = x
   end
   get x()
      return self._x
   end

   set y(v)
      self._y = y
   end
   get y()
      return self._y
   end
end

p = Point()
p.x = 42            -- means: Point::__setters__::x(p, 42)
print p.x           -- means: print(Point::__getters__::y(p, 42))
```

This allows for lazy construction of default property values,
read-only or write-only properties,  enforcing type constraints,
or coercing to and from `cdata` values.

#### <a name"constructors"></a>Constructors

The constructor of a class is a an ordinary method called `self`.
Classes overload the `__apply` hook, which is called from the `Class`
metatype's `__call` metamethod, and so are callable directly.  This
is used to create instances of the class. Arguments are passed
through to the constructor.

However, this is largely a convention. An instance can also be created
by using Lua's `setmetatable`:

```
p = setmetatable({ x = 0, y = 0}, Point)
```

A more concise form is supported by Shine using `as`:

```
p = { x = 0, y = 0 } as Point
```

The default `__apply` implementation calls `self` on the class, passing
in a table with the metatable already set to that of the receiving class.
In some cases - especially when creating metatypes for FFI bindings - this
is undesirable, since FFI bindings construct `cdata` types and not insances
based on tables.

In this case a custom `__apply` method should be used. The following
illustates:

```
import ffi from "sys.ffi"
class Buffer
   local ctype = ffi::typeof('struct { char* ptr; size_t len; };')
   function self.__apply(str)
      return ctype(str, #str)
   end
   -- make this class the metatype
   ffi::metatype(ctype, self)
end

buf = Buffer("Hello World!")
```

#### <a name="inheritance"></a>Inheritance

Inheritance uses the `extends <expr>` clause. The following illustrates:

```
class Point3D extends Point
   self(x, y, z = 0)
      super(x, y)           -- super refers to Point::__members__
      self.z = z
   end
   move(dx, dy, dz)
      super.move(dx, dy)    -- compiles to super::move(self, dx, dy)
      self.z += dz
   end
end
```

The argument to `extends` can be any valid expression, so even literal
tables, and call expressions are allowed, which can be powerful tools for
constructing parameterized class hierarchies at runtime.

```
function DBRecord(table)
   dbh = DB.connection()
   class base
      fetch()
         dbh.with(table) (handle) =>
            -- do something
         end
      end
   end
   return base
end
class DBUser extends DBRecord("user_table")
   -- whatever
end
```

The above also shows that all declarations - including class
declarations - can be nested.

### <a name="modules"></a>Modules

Shine's modules are not to be confused with Lua's modules.

In Shine modules are almost identical to classes in every way,
except that they are without a constructor and don't inherit. Modules
are often used as singletons, or namespaces to contain related
pieces of code. Their real power, however, comes from the fact that
they can be composed into classes and even other modules using
`include <expr_list>`.

This example shows similarities with classes, and how modules may be
used as namespaces:

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

The following shows composing a module into a class using the `include`
statement:

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

### <a name="grammars"></a>Grammars

Shine grammars are a special kind of [module](#modules) which can
contain [patterns](#patterns) as well as module body declarations
such as methods, properties and statements. Grammar bodies have
a lexical scope, just as with classes and modules.

Grammars are composable via `include` statements.

Grammars override the `__call` metamethod for matching.


```
grammar Macro
   function fail(err)
      return (s, i) =>
         local msg = (#s < i + 20) and s.sub(i)
         msg = "error %{err} near '%s'".format(msg)
         error(msg, 2)
      end
   end

   function expect(tok)
      return / <{tok}> | <{fail("'%{tok}' expected")}> /
   end

   text  <- {~ <item>* ~}
   item  <- <macro> | [^()] | '(' <item>* <{expect(')')}>
   arg   <- ' '* {~ (!',' <item>)* ~}
   args  <- '(' <arg> (',' <arg>)* ')'
   macro <- (
        ('apply' <args>) -> '%1(%2)'
      | ('add'   <args>) -> '%1 + %2'
      | ('mul'   <args>) -> '%1 * %2'
   )
end

local s = "add(mul(a,b),apply(f,x))"
print(Macro(s))
```

### <a name="decorators"></a>Decorators

Decorators are annotations associated with class, module, grammar,
function or local declarations.

```
@classdeco(whatever)
class Foo

   @methdeco({ doc = "does something" }, 42)
   munge(...)
      ---
   end

end

@funcdeco
function bar()
   --
end

@localdeco
local a, b = 40, 2
```

The semantics are simple. A decorator is a function or other callable
which is passed the decorated object as a first argument, followed
by any remaining arguments declared in the annotation. The exception
being local variable declarations, in which case the decorator
function is passed the right-hand side of the assignment as a list.

A decorator is expected to return a value to be used as the value
of the declaration. The transormation inserted by the compiler has
the following pattern:

```
@deco1(42)
@deco2({ answer = 0 })
function greet()
   print "Hello World!"
end

@deco3("cheese")
local a, b = 1, 2
```

becomes:

```
function greet()
   print "Hello World!"
end
greet = deco1(deco2(greet, { answer = 0 }), 42)

local a, b = deco3(1, 2, "cheese")
```

That's it. Simple.

### <a name="macros"></a>Macros

Shine currently has experimental support for procedural macros.
Macros are functions run at compile time, which receive the compiler
context and abstract syntax tree (AST) nodes as arguments.

A macro is expected to transform the AST nodes into opcode tree
fragments exactly as is done by the Shine
[translator](./src/lang/translator.lua). This is a powerful
feature, but also allows one to produce invalid code, so
not for the faint of heart.

The following macro does a compile-time string concatenation and
inserts `print "Hello World!"`.

```
-- file: hello.shn
macro hello!(ctx, expr)
   util = require("shine.lang.util")
   mesg = util::unquote(ctx.get(expr))
   return ctx.op{'!call', 'print', ctx.op"Hello %{mesg}"}
end

hello!("World!")
```

Running the above with `shinec -o` to print the opcode tree, yields:

```
$ shinec -o hello.shn 
;TvmJIT opcode tree:

(!line "@hello.shn" 1)(!define __magic__ (!index (!call1 require "core") "__magic__"))(!call (!index _G "module") !vararg (!index __magic__ "environ"))
(!line 2) 
(!line 8) (!call print "Hello World!")
```

The first line is the standard Shine prelude which loads the runtime
environment. The interesting part comes next. We see the constant
string passed to `print` is pre-computed as we expected.

Note that the macro itself is a compile-time entity and is not
present in the output.

Of course, defining macros only within a given compilation unit limits
their usefulness, so macro definitions have an alternative syntax:

```
macro <name> '=' <ident>
```

Where `<ident>` is either a locally declared function, or an imported
symbol. The following illustrates:

```
-- file: macros.shn

function hello(ctx, expr)
   util = require("shine.lang.util")
   mesg = util::unquote(ctx.get(expr))
   return ctx.op{'!call', 'print', ctx.op"Hello %{mesg}"}
end

export hello
```

```
-- file: hello.shn
import hello from "macros"

macro hello! = hello

hello!("World!")
```

Running `hello.shn` with `shinec -o` now shows:

```
$ shinec -o hello.shn 
;TvmJIT opcode tree:

(!line "@hello.shn" 1)(!define __magic__ (!index (!call1 require "core") "__magic__"))(!call (!index _G "module") !vararg (!index __magic__ "environ"))
(!line 1) (!define (hello) ((!call import "macros" "hello")))
(!line 3) 
(!line 5) (!call print "Hello World!")
```

This comes with a couple of caveats. First, the compiler needs to
load and evaluate the module at compile time, so if the module's
code has side effects (such as sending an email), then this will
happen when the code is *compiled*. This is the only case (along with
`import macro ...` statement) where the compiler does any sort of early
linking or binding.

Secondly, if the function to be used as the macro implementation is
declared in the same compilation unit, then it must be declared in
its canonical form: i.e. `function <name> <params> <body> end`. It
cannot be a property or expression or any other computed form.

Lastly, macro functions are run early, so generally need to import
what they need locally.

Some tips:

* Macros could be imported with shorthand syntax:
```
-- file: hello.shn
import macro hello from "macros"

hello("World!")
```
* To implement macros, one needs to know the structure of the
  AST, so `shinec -p` will print it out.
* The "shine.lang.util" module has a `dump` function which pretty
  prints AST nodes.
* The best reference is the Shine [translator](./src/lang/translator.lua) itself.

## <a name="standard-libaries"></a>Standard Libraries

See [./lib](./lib)

### <a name="concurrency"></a>Concurrency

The standard libraries have a strong focus on concurrency using
scheduled coroutines, wrapped as the class `Fiber`, which cooperate
with (but not scheduled by) an event loop.

This gives a clean linear flow to writing concurrent applications
without the need for inverting everything using callbacks.

Here's the canonical TCP echo server example:

```
import async, yield from "async"
import TCPServer from "async.io"

server = TCPServer()
server.reuseaddr(true)
server.bind("localhost", 1976)
server.listen(128)

async =>
   while true do
      client = server.accept()
      async =>
         while true do
            got = client.read()
            if got == nil then
               client.close()
               break
            end
            client.write("you said %{got}")
         end
      end
   end
end

yield
```

#### <a name="fibers"></a>Fibers

See [./lib/async/fiber.shn](./lib/async/fiber.shn),
[./lib/async/util.shn](./lib/async/util.shn)

#### <a name="threads"></a>Threads

See [./lib/sys/thread.shn](./lib/sys/thread.shn) and the
[czmq bindings](https://github.com/richardhundt/shine-zsys).

### <a name="serialization"></a>Serialization

See [./lib/codec/serializer.shn](./lib/codec/serializer.shn)

Big TODO here.

