--[=[
Copyright (C) 2013-2014 Richard Hundt and contributors.
See Copyright Notice in shine
]=]

local export = { }

local function dump(node, level)
   if not level then level = 1 end
   if type(node) == 'nil' then
      return "null"
   end
   if type(node) == "string" then
      return '"'..node..'"'
   end
   if type(node) == "number" then
      return node
   end
   if type(node) == "boolean" then
      return tostring(node)
   end
   if type(node) == "function" then
      return tostring(node)
   end

   local buff = { }
   local dent = string.rep("    ", level)
   local tput = table.insert

   if #node == 0 and next(node, nil) then
      tput(buff, "{")
      local i_buff = { }
      local p_buff = { }
      for k,data in pairs(node) do
         tput(buff, "\n"..dent..dump(k)..': '..dump(data, level + 1))
         if next(node, k) then
            tput(buff, ",")
         end
      end
      tput(buff, "\n"..string.rep("    ", level - 1).."}")
   else
      tput(buff, "[")
      for i,data in pairs(node) do
         tput(buff, "\n"..dent..dump(data, level + 1))
         if i ~= #node then
            tput(buff, ",")
         end
      end
      tput(buff, "\n"..string.rep("    ", level - 1).."]")
   end

   return table.concat(buff, "")
end

export.dump = dump

local ID = 0
export.genid = function(prefix)
   ID = ID + 1
   prefix = prefix or '$#'
   return prefix..ID
end

function export.unquote(str)
   if string.sub(str, 1) == '"' and string.sub(str, -1) == '"' then
      return string.sub(str, 2, -2)
   end
   return str
end

function export.extend(base, with)
   with.__super = base
   with.__index = with
   return setmetatable(with, { __index = base, __call = base.__call })
end

function export.fold_left(list, func)
   local accu = list[1]
   for i=2, #list do
      accu = func(accu, list[i])
   end
   return accu
end

function export.fold_right(list, func)
   local accu = list[#list]
   for i=#list - 1, 1, -1 do
      accu = func(accu, list[i])
   end
   return accu
end


return export
