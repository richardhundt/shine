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

local tvm    = require('tvm')
local bcsave = require("jit.bcsave")

local usage = "usage: %s [options]... input output.\
Available options are:\
  -t type \tOutput file format.\
  -b      \tList formatted bytecode.\
  -n name \tProvide a chunk name.\
  -g      \tKeep debug info.\
  -p      \tPrint the parse tree.\
  -o      \tPrint the opcode tree.\
"

local function runopt(...)
   local util       = require('shine.lang.util')
   local parser     = require('shine.lang.parser')
   local translator = require('shine.lang.translator')

   local args = { ... }
   if #args == 0 then
      args = arg
   end

   if #args == 0 then
      print(string.format(usage, arg[0]))
      os.exit(1)
   end

   local opts = { }
   local i = 0
   repeat
      i = i + 1
      local a = args[i]
      if a == "-t" then
         i = i + 1
         opts['-t'] = args[i]
      elseif a == "-h" or a == "-?" then
         print(string.format(usage, arg[0]))
         os.exit(0)
      elseif a == "-n" then
         i = i + 1
	 opts['-n'] = args[i]
      elseif a == "-e" then
         i = i + 1
         opts['-e'] = args[i]
      elseif string.sub(a, 1, 1) == '-' then
         opts[a] = true
      else
         opts[#opts + 1] = a
      end
   until i == #args

   local code, name, dest
   if opts['-e'] then
      code = opts['-e']
      name = code
      dest = opts[1]
   elseif opts['--'] then
      code = io.stdin:read('*a')
      name = "stdin"
      dest = opts[1]
   else
      name = opts[1]
      if not name then
         io.stderr:write(string.format(usage, arg[0]))
         os.exit(1)
      end

      dest = opts[2]
      local file = assert(io.open(opts[1], 'r'))
      code = file:read('*a')
      file:close()
   end

   local srctree = parser.parse(code, name, opts)

   if opts['-p'] then
      io.stdout:write("--Shine parse tree:\n")
      io.stdout:write(util.dump(srctree).."\n")
      os.exit(0)
   end

   local dsttree = translator.translate(srctree, name, opts)

   if opts['-o'] then
      io.stdout:write(";TvmJIT opcode tree:\n")
      io.stdout:write(tostring(dsttree).."\n")
      os.exit(0)
   end

   local tvmcode
   if opts['-t'] == 'tp' or (dest and string.sub(dest, -4) == '.tp') then
      tvmcode = tostring(dsttree)
   else
      tvmcode = string.dump(assert(tvm.load(tostring(dsttree), '@'..name)))
   end

   if opts['-b'] then
      bcsave.start('-l', '-e', tvmcode)
      os.exit(0)
   end

   if not dest then
      io.stderr:write(string.format(usage, arg[0]))
      os.exit(1)
   end

   if opts['-t'] == 'tp' or string.sub(dest, -4) == '.tp' then
      local file = io.open(dest, 'w+')
      file:write(tvmcode)
      file:close()
      os.exit(0)
   end

   args = { }
   if opts['-n'] then
      args[#args + 1] = '-n'
      args[#args + 1] = opts['-n']
   end
   if opts['-t'] then
      args[#args + 1] = '-t'
      args[#args + 1] = opts['-t']
   end
   if opts['-g'] then
      args[#args + 1] = '-g'
   end
   args[#args + 1] = '-e'
   args[#args + 1] = tvmcode
   args[#args + 1] = dest

   bcsave.start(unpack(args))
end

return {
   start = runopt
}

