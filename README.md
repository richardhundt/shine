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

Nyanga makes a distinction between tables and arrays. Both types have a metatable.

```Lua
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
        print(self.messate.format(whom))
    end
}
friendly.greet("World")
```

Bitwise operators have been added using the `bit` library.

```Lua
b = a | 0x8000
c = b << 1
```

Since Nyanga is an OO language, the `.` operator is the equivalent of Lua's `:` operator. To call a function statically, use the `::` operator.

```
s = string::format("Hello %s", whom)
```

Parenthesese are optional (not this makes Nyanga a bit line oriented):
```
print("Hello World!")
print "Hello World!" -- same thing
```

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

Regular expressions are also added (libpcre needs to be installed, but it seems to be available on most unices):

```
lcword = /\b[a-z]+/
matches = lcword.exec("some words")
```


