local lib = require('ray')

local function timeout(after, func)
   local timer = ray.timer()
   timer:start(after, 0)
   return ray.fiber(function()
      timer:wait()
      timer:stop()
      func()
   end)
end
local function run(main, ...)
   ray.fiber(main, ...)
   ray.run()
end

return {
   run = run;
   close = close;
   timeout = timeout;
}

