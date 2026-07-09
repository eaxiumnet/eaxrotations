local json = {
  decode = function(s)
    local function parse_val(str, i)
      local c = str:sub(i, i)
      if c == '"' then
        local j = i + 1
        while j <= #str do
          local ch = str:sub(j, j)
          if ch == '\\' then j = j + 2
          elseif ch == '"' then return str:sub(i+1, j-1):gsub('\\(.)', '%1'), j + 1
          else j = j + 1 end
        end
      elseif c == '{' then
        local obj, j = {}, i + 1
        while true do
          j = j + (str:sub(j, j):match("%s") and 1 or 0)
          if str:sub(j, j) == '}' then return obj, j + 1 end
          local key; key, j = parse_val(str, j)
          j = str:find(':', j) + 1
          local val; val, j = parse_val(str, j)
          obj[key] = val
          j = j + (str:sub(j, j):match("%s") and 1 or 0)
          if str:sub(j, j) == ',' then j = j + 1 end
        end
      elseif c == '[' then
        local arr, j = {}, i + 1
        while true do
          j = j + (str:sub(j, j):match("%s") and 1 or 0)
          if str:sub(j, j) == ']' then return arr, j + 1 end
          local val; val, j = parse_val(str, j)
          arr[#arr + 1] = val
          j = j + (str:sub(j, j):match("%s") and 1 or 0)
          if str:sub(j, j) == ',' then j = j + 1 end
        end
      elseif c == 't' and str:sub(i, i+3) == 'true' then return true, i + 4
      elseif c == 'f' and str:sub(i, i+4) == 'false' then return false, i + 5
      elseif c == 'n' and str:sub(i, i+3) == 'null' then return nil, i + 4
      else
        local num, nxt = str:match("^(-?%d+%.?%d*)", i)
        if num then return tonumber(num), i + #num end
      end
      return nil, i
    end
    local function skip_ws(str, i)
      while i <= #str and str:sub(i, i):match("%s") do i = i + 1 end
      return i
    end
    local i = skip_ws(s, 1)
    local val, j = parse_val(s, i)
    return val
  end
}

local f = io.open('tbc-new/ui/warrior/dps/apls/fury.apl.json', 'r')
if not f then print('FILE NOT FOUND') return end
local content = f:read('*a')
f:close()

local ok, apl = pcall(json.decode, content)
if not ok then
  print('JSON PARSE ERROR: ' .. tostring(apl))
  return
end

print('Type: ' .. tostring(apl.type))
print('Has priorityList: ' .. tostring(apl.priorityList ~= nil))
if apl.priorityList then
  print('Actions: ' .. #apl.priorityList)
  for i = 1, math.min(5, #apl.priorityList) do
    local entry = apl.priorityList[i]
    print('  ' .. i .. '. hide=' .. tostring(entry.hide) .. ' action=' .. tostring(entry.action ~= nil))
  end
end
