local ffi = require('ffi')
local lib = require('ray')

local QUEUE = lib.ray_queue_new(1024)
local ALIVE = { }
local IDGEN = 0

local function genid()
   IDGEN = IDGEN + 1
   return IDGEN
end


ffi.cdef [[
   typedef struct Timer {
      ray_handle_t* handle;
   } Timer;
]]

local Timer = ffi.metatype(ffi.typeof('Timer'), {
   __new = function()
      self.handle = lib.ray_timer_new(QUEUE)
      self.set_id(genid())
      self.react = {
         [tonumber(lib.RAY_TIMER)] = function()

         end
      }
   end,
   __index = {
      get_id = function(self)
         return lib.ray_handle_get_id(self.handle)
      end,
      set_id = function(self, id)
         lib.ray_handle_set_id(self.handle, id)
      end,
      cose = function(self)
         lib.ray_close(self.handle)
      end,
      start = function(self, timeout, rep)
         lib.ray_timer_start(self.handle, timeout, rep)
      end,
      stop = function(self)
         lib.ray_timer_stop(self.handle)
      end,
   }
})

local function loop()
   while true do
      local evt = lib.ray_queue_next(QUEUE)
      if evt == nil then
         break
      end
      local oid = lib.ray_handle_get_id(evt.self)
      if oid > 0 then
         local obj = ALIVE[oid]
         if obj then
            if type(obj) == 'function' then
               obj(evt)
            end
         end
      else
         error("no watcher")
      end
      lib.ray_evt_done(evt)
   end
end

local function close(handle, cb)
   if handle then
      local oid = lib.ray_handle_get_id(handle)
      if cb then
         ALIVE[oid] = function()
            ALIVE[oid] = nil
            cb()
         end
      else
         ALIVE[oid] = nil
      end
      lib.ray_close(handle)
   end
end

local function timeout(cb, ms, ...)
   local timer = lib.ray_timer_new(QUEUE)
   local oid   = genid()
   local args  = { ... }
   ALIVE[oid] = function(evt)
      lib.ray_timer_stop(timer)
      cb(unpack(args))
      close(timer, function()
         lib.ray_handle_free(timer)
      end)
   end
   lib.ray_handle_set_id(timer, oid)
   lib.ray_timer_start(timer, ms, 0)
end

local function open(path, mode)
   
end

local function run(main, ...)
   main(...)
   loop()
end

return {
   run = run;
   close = close;
   timeout = timeout;
}

