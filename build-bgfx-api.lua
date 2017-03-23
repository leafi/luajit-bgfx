local wtmp = io.open('built/bgfx_tmp.h', 'w+')
for line in io.lines('bgfx-include/bgfx.h') do
  if string.find(line, 'defines.h') == nil then wtmp:write(line .. '\n') end
end
wtmp:flush()
wtmp:close()

local w = io.open('built/bgfx_api.lua', 'w+')

w:write('local ffi = require("ffi")\n')
w:write('ffi.cdef [[\n')

local copy_on = false

local pf = io.popen('cpp -E -x c built/bgfx_tmp.h', 'r')
local h = {}

for line in pf:lines() do
  if copy_on or line == 'typedef enum bgfx_renderer_type' then
    copy_on = true
    h[#h+1] = line
  end
end

pf:close()


local function format_bgfx_h(all_lines)
  -- deal with inadvertently multiline func definitions
  local function join_func_defs(lines)
    local out = {}
    local whitelist = {'{', '}', 'typedef', 'BGFX_'}
    local waiting_semicolon = false

    for i = 1,#lines do
      local care = true

      for j = 1,#whitelist do
        care = care and (string.find(lines[i], whitelist[j]) == nil)
      end

      if care and waiting_semicolon then
        out[#out] = out[#out] .. ' ' .. lines[i]
      else
        out[#out+1] = lines[i]
      end

      if care then
        local nosp = string.gsub(lines[i], '[\t ]', '')
        if string.sub(nosp, -1) == ';' then
          waiting_semicolon = false
        elseif nosp == '_Bool' or string.sub(nosp, -1) == ',' or string.sub(nosp, -1) == '(' then
          waiting_semicolon = true
        end
      end
    end

    return out
  end

  local function line_by_line(f)
    local out = {}
    for i = 1,#all_lines do
      local ls = f(all_lines[i])
      if type(ls) == 'table' then
        -- bunch of lines to add
        for i = 1,#ls do
          if ls[i] ~= nil then out[#out+1] = ls[i] end
        end
      elseif type(ls) == 'function' then
        -- function to run on previous line (probably to append to it)
        out[#out] = ls(out[#out])
      elseif type(ls) == 'string' then
        -- just a new line to add
        out[#out+1] = ls
      end
    end
    all_lines = out
  end

  -- trim & crush lines
  line_by_line(function(line)
    local l = string.gsub(string.gsub(line, '^%s+', ''), '%s+$', '')
    return #l > 0 and l or nil
  end)

  -- strip cpp crap
  line_by_line(function(line)
    return (string.sub(line, 1, 1) ~= '#') and line or nil
  end)

  -- hoist open squiggles
  line_by_line(function(line)
    if line == '{' then
      return function(prevline) return prevline .. ' {' end
    else
      return line
    end
  end)

  -- call to function joiner thingy (make sure func defs are all on one line...)
  all_lines = join_func_defs(all_lines)

  -- capture stuff inside 'typedef enum bgfx_...' (to be hoisted to bgfx.*)
  local captured_enums = {}
  local in_enum = nil
  local vals = {}
  line_by_line(function(line)
    if in_enum == nil then
      local m = string.match(line, 'typedef enum bgfx_([%w_]+) {')
      if m ~= nil then
        in_enum = 'bgfx_' .. m
        vals = {}
      end
    else
      if string.find(line, '}') then
        captured_enums[in_enum] = vals
        in_enum = nil
      else
        local mn = string.match(line, 'BGFX_([%w_]+),?$')
        if mn ~= nil then vals[#vals+1] = 'BGFX_' .. mn end
      end
    end
    return line
  end)
  if in_enum ~= nil then
    captured_enums[in_enum] = vals
    in_enum = nil
  end

  -- Now, time to pretty-print...

  -- fix line spacing between stuff
  line_by_line(function(line)
    if string.sub(line, 1, 1) == '}' then
      return {line, ''}
    elseif string.sub(line, 1, #'typedef void') == 'typedef void' then
      return {'', line, ''}
    else
      return line
    end
  end)

  -- add initial spacing (double inside enums/structs...)
  local in_squiggles = false
  line_by_line(function(line)
    if string.sub(line, 1, 1) == '}' then in_squiggles = false end
    local l = (in_squiggles and '    ' or '  ') .. line
    if string.sub(line, -1) == '{' then in_squiggles = true end
    return l
  end)

  return all_lines, captured_enums
end

local captured_enums = nil
h, captured_enums = format_bgfx_h(h)

for i = 1,#h do
  w:write(h[i]); w:write('\n')
end

w:write(']]\n\n')


-- platform crap
w:write('\n')
w:write('-- and the platform data...\n')
w:write('ffi.cdef [[\n')
w:write([[
  typedef struct bgfx_platform_data {
    void* ndt;
    void* nwh;
    void* context;
    void* backBuffer;
    void* backBufferDS;
    void* session;
  } bgfx_platform_data_t;

  void bgfx_set_platform_data(const bgfx_platform_data_t* _data);
]])
w:write(']]\n')

-- loader...
w:write([[


local wwjit = require('jit')
local C = nil

if wwjit.os == 'Windows' then
  C = ffi.load('../built/bgfx-shared-libDebug.dll')
elseif wwjit.os == 'OSX' then
  C = ffi.load('../built/libbgfx-shared-libDebug.dylib')
else
  C = ffi.load('../built/libbgfx-shared-libDebug.so')
end

local bgfx_api = {C = C}
]])

-- defines...

for line in io.lines('bgfx-include/defines.h') do
  if string.sub(line, 1, 7) == '#define' then
    local line_clean = string.gsub(line, '[ \t]+', ' ')
    line_clean = string.gsub(line_clean, ' //.+', '')

    local parts = {}
    local p = ''
    for i = 1,#line_clean do
      local c = string.sub(line_clean, i, i)
      if c == ' ' then
        if #p > 0 then
          parts[#parts+1] = p
          p = ''
        end
      else
        p = p .. c
      end
    end
    if #p > 0 then parts[#parts+1] = p end

    if #parts == 3 then
      local k = parts[2]
      local v = parts[3]

      if string.sub(v, 1, #'UINT8_C(') == 'UINT8_C(' then
        w:write('bgfx_api.' .. k .. ' = ' .. string.sub(v, 9, -2) .. '\n')
      elseif string.sub(v, 1, #'UINT16_C(') == 'UINT16_C(' then
        w:write('bgfx_api.' .. k .. ' = ' .. string.sub(v, 10, -2) .. '\n')
      elseif string.sub(v, 1, #'UINT32_C(') == 'UINT32_C(' then
        w:write('bgfx_api.' .. k .. ' = ' .. string.sub(v, 10, -2) .. '\n')
      elseif string.sub(v, 1, #'UINT64_C(') == 'UINT64_C(' then
        w:write('bgfx_api.' .. k .. ' = ' .. string.sub(v, 10, -2) .. 'ULL\n')
      elseif string.sub(v, 1, 1) == '(' then
        -- something complicated? not interested (at least right now...!)
        w:write('-- not binding ' .. k .. '\n')
      elseif string.sub(v, 1, 1) == 'B' then
        -- whatever...
        w:write('-- not binding ' .. k .. '\n')
      else
        w:write('bgfx_api.' .. k .. ' = ' .. v .. '\n')
      end
    end
  end
end

w:write('\n')

-- stuff found & copied from 'typedef enum bgfx_(...)' in bgfx.lua
for k,v in pairs(captured_enums) do
  w:write('-- from typedef enum ' .. k .. ' (' .. k .. '_t)\n')
  for i,v2 in ipairs(v) do
    w:write('bgfx_api.' .. v2 .. ' = ' .. tostring(i - 1) .. '\n')
  end
  w:write('\n')
end



w:write([[

return bgfx_api
]])

w:flush()
w:close()
