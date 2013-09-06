local lib = require('ray')

local function timeout(func, after)
   local timer
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

