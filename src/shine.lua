--[=[
Shine -- Modifiable OO Lua Dialect. http://github.com/richardhundt/shine

Copyright (C) 2013-2014 Richard Hundt and contributors. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

[ MIT license: http://www.opensource.org/licenses/mit-license.php ]
]=]

package.path  = './lib/?.raw;./lib/?.lua;'..package.path
package.path  = './?.shn;./lib/?.shn;/usr/local/share/shine/?.shn;'..package.path
package.path  = './?/init.shn;./lib/?/init.shn;/usr/local/share/shine/?/init.shn;'..package.path..';'
package.cpath = './lib/?.so;'..package.cpath
package.cpath = '/usr/local/lib/shine/?.so;'..package.cpath..';'

require("lunokhod")

local usage = "usage: %s [options]... [script [args]...].\
Available options are:\
  -e chunk\tExecute string 'chunk'.\
  -c ...  \tCompile or list bytecode.\
  -i      \tEnter interactive mode after executing 'script'.\
  -v      \tShow version information.\
  --      \tStop handling options. \
  -       \tExecute stdin and stop handling options."

local function interactive(env)
   local tvm        = require("tvm")
   local parser     = require("shine.lang.parser")
   local translator = require("shine.lang.translator")
   local core       = require("core")

   local prompt1 = 'shine> '
   local prompt2 = '      | '

   local buf = { }
   local env = env or core.__magic__.environ({ })
   local function eval()
      local fun, src, ast, ops
      local ok, er = pcall(function()
         src = table.concat(buf, "\n")
         ast = parser.parse(src, 'stdin')
         ops = translator.translate(ast, 'stdin', { eval = true })
         fun = tvm.load(tostring(ops))
         buf = { }
      end)
      if not ok then
         if not string.find(er, "Unexpected end of input") then
            print(er)
            buf = { }
         end
      end
      if fun then
         setfenv(fun, env)
         ok, er = pcall(fun, 'stdin')
         if not ok then
            print(er)
         end
      end
   end
   local function doline(line)
      buf[#buf + 1] = line
      eval()
   end

   while true do
      if #buf == 0 then
         io.stdout:write(prompt1)
      else
         io.stdout:write(prompt2)
      end
      local line = io.stdin:read('*l')
      if line == nil then
         io.stdout:write('^D\n')
         break
      end
      doline(line)
   end
end

local function print_version()
   local core = require("core")
   local info = "Shine %s -- Copyright (C) 2013-2014 Richard Hundt.\n"
   io.stdout:write(string.format(info, core._VERSION))
end

local function print_usage()
   print(string.format(usage, arg[0]))
end

local function runopt(args)
   local loader = require("shine.lang.loader")

   local args = { unpack(args) }
   local opts = { }

   while #args > 0 do
      local a = table.remove(args, 1)
      if a == "-e" then
         opts['-e'] = table.remove(args, 1)
      elseif a == "-c" then
         opts['-c'] = true
         -- pass remaining args to compiler
         break
      elseif a == "-h" or a == "-?" then
         print_usage()
         os.exit(0)
      elseif a == '--' then
         break
      elseif string.sub(a, 1, 1) == '-' then
         opts[a] = true
      elseif #opts == 0 and not opts['-e'] then
         -- the file to run
         opts[#opts + 1] = a
         break
      else
         -- pass remaining args to script
         break
      end
   end

   if next(opts) == nil and next(args) == nil then
      print_version()
      interactive()
      os.exit(0)
   end

   if opts['-v'] then
      print_version()
      os.exit(0)
   end

   -- try to load the code
   local code, name
   if opts['-e'] then
      code = opts['-e']
      name = '(command line)'
   elseif opts['-'] then
      name = 'stdin'
      code = io.stdin:read('*a')
   elseif opts['-c'] then
      require("shinec").start(unpack(args))
      os.exit(0)
   else 
      if not opts[1] then
         error("no chunk or script file provided")
      end
      name = opts[1]
      local file = assert(io.open(opts[1], 'r'))
      code = file:read('*a')
      file:close()
   end

   local main
   if string.sub(name, -4) == '.lua' then
      main = assert(loadstring(code, '@'..name))
   else
      main = assert(loader.loadchunk(code, name))
   end

   _G.arg = { [0] = name, unpack(args) }
   main(name, unpack(args))
   if opts['-i'] then
      interactive(getfenv(main))
   end
end

runopt(arg)

