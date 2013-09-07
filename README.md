# NAME

Nyanga - Object Oriented Lua Dialect

# DESCRIPTION

Nyanga (Xhosa word for moon), is a super set of Lua which adds OO features, array comprehensions, ranges, modules, a smarter generic for loop, and more.

The goal of the project is to allow rapid experimentation with Lua's surface syntax and semantics. So if you've ever felt that Lua is too minimal, or missing that one killer feature, here's your chance to build it and try it out.

Nyanga consists of an LPeg based parser which uses the re.lua module, an AST transformer and bytecode generator for LuaJIT 2.

Here's a quick sample showing some of the features:

```Lua
module shapes

   class Point
      self(x = 0, y = 0)
         self.x = x
         self.y = y
      end
   end

   class Point3D extends Point

      self(x = 0, y = 0, z = 0)
         super(x, y)
      end
      set x(x)
         self._x = x
      end
      get x()
         return self._x
      end
      toString()
         return "Point3D<%p>".format(self)
      end
   end

   p = Point3D()
   print(p)
end
```

## Language Basics


### Operators

Nyanga supports additional operators to Lua, adding C-style bitwise operators. String concatenation is done using `~` instead of `..` as the latter is reserved for ranges.

Binary operators:

```
"+" "-" "~" "/" "**" "*" "%" "^" "|" "&"
">>>" ">>" ">=" ">" "<<" "<=" "<" ".."
"!=" "==" "or" "and" "is" "..."
"+=" "-=" "~=" "**=" "*=" "/=" "%="
"|=" "&=" "^=" "<<=" ">>>=" ">>="
```

Unary operators:
```
"#" "~" "+" "-" "!" "not" "typeof"
```

Bitwise operators have been added using the `bit` library.

```
b = a | 0x8000
c = b << 1
```

Since Nyanga is an OO language, the `.` operator is the equivalent of Lua's `:` operator. To call a function statically, use the `::` operator.

```
s = string::format("Hello %s", whom)
```

Additionally there is the spread prefix operator `...` which calls `unpack` internally:
```
a = [1, 2, 3]
x, y, x = ...a
print(x, y, z) -- 1  2  3
```

### Strings

Strings come in three flavours:

```
s1 = "simple"
s2 = 'another'
s3 = `a ${s1} string and ${s2}` -- backticks interpolate
s4 = `
    strings can span
    multiple lines
`
```

### RegExp

Regular expressions are also added (libpcre needs to be installed, but it seems to be available on most unices):

```
lcword = /\b[a-z]+/
matches = lcword.exec("some words")
```

### Structural Types

Nyanga makes a distinction between tables and arrays. Both types have a metatable.

```
a1 = [ "a", 2, "three" ]
t1 = { answer = 42, ["duff"] = "beer" }

-- newlines count as pair separators
t2 = {
    foo = "bar"
    baz = "quux"
}

-- sugar for functions (self is implicit)
friendly = {
    message = "Hello %s!"
    greet(whom)
        print(self.message.format(whom))
    end
}
friendly.greet("World")
```

### Functions

Parenthesese are optional (not this makes Nyanga a bit line oriented):
```
print("Hello World!")
print "Hello World!" -- same thing
```

Short function syntax:
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

Combined with optional params, makes functional programming nicer (note that the space after `map` is significant):

```
["a","b","c"].map (i,v) => print(v)
```

Functions also support default parameters:

```
function greet(whom = "World")
   print `Hello ${whom}!`
end
```

The last parameter of a function may be a rest parameter which "slurps" up the remaining arguments:

```
function slurpy(arg1, ...args)
   print `argument 1 is ${arg1}`
   print `the rest of the arguments: `, ...args
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
```

### Classes

Nyanga supports single inheritance, static methods (via the `static` prefix) and lexical class bodies (they're just functions internally).

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
   static __len()
      return 2
   end
end
```

### Modules import/export

By default, all symbols declared in a compilation unit are private. To export a symbol, prefix the declaration with `export`.

```
-- file a.nga
export function eat()
   print "nom nom"
end
export function pwn()
   print "pew pew" 
end
```

To import a symbol:

```
-- file b.nga
import {eat, pwn} from "b.nga"
eat()
pwn()
```

Classes can also be exported. To export a variable, it must be declared with `local`:

```
export local DEBUG = true

export class Nuke
   launch()
      print "Kaboom!"
   end
end
```

Namespaces can also be introduced via the `module` keyword:

```
module armory
   -- exported classes are visible outside the package
   export class PlasmaRifle
      trigger()
         print "pew pew"
      end
   end

   -- this class is private
   class BootKnife
      unsheath()
         print "snick"
      end
   end
end

gun = armory::PlasmaRifle()
```

To export a module, prefix it with `export`:

```
-- file: utils.nga
export module utils
   quote(val)
      string::format("%q", val)
   end
end

-- file: app.nga
import {utils} from 'utils.nga'

print `she yelled: ${utils::quote('fire in the hole!')}`
```


