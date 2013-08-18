# NAME

Nyanga - Object Oriented Lua Dialect

# DESCRIPTION

Nyanga (Xhosa word for moon), is a super set of Lua which adds OO features, array comprehensions, ranges, modules, a smarter generic for loop, and more.

The goal of the project is to allow rapid experimentation with Lua's surface syntax and semantics. So if you've ever felt that Lua is too minimal, or missing that one killer feature, here's your chance to build it and try it out.

Nyanga consists of an LPeg based parser which uses the re.lua module, an AST transformer and bytecode generator for LuaJIT 2.

Here's a quick sample showing some of the features:

```
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

