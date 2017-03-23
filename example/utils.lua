local utils = {}

local _M = nil
local bgfx = nil
local ffi = nil

function utils.init(__M, _bgfx, _ffi)
  _M = __M; bgfx = _bgfx; ffi = _ffi
end

local function readall(path)
  local f = io.open(path, 'rb')
  local xs = f:read('*all')
  f:close()
  return xs
end

function utils.shaderprog(vpath, fpath)
  local vs_f = readall(vpath)
  local fs_f = readall(fpath)
  local vs = bgfx.C.bgfx_create_shader(bgfx.C.bgfx_copy(ffi.cast('char *', vs_f), #vs_f))
  vs_f = nil
  local fs = bgfx.C.bgfx_create_shader(bgfx.C.bgfx_copy(ffi.cast('char *', fs_f), #fs_f))
  fs_f = nil
  local prog = bgfx.C.bgfx_create_program(vs, fs, false)
  bgfx.C.bgfx_destroy_shader(vs)
  vs = nil
  bgfx.C.bgfx_destroy_shader(fs)
  fs = nil
  return prog
end

function utils.gentexture()
  -- generates a really really simple 16x16 texture
  local raw = ffi.new('char [?]', 128*128*4)
  for y=0,127 do
    for x=0,127 do
      local dst = (y*128+x)*4
      raw[dst+0] = x*2
      raw[dst+1] = y*2
      raw[dst+2] = 127
      raw[dst+3] = 255
    end
  end

  local bgfx_owned_mem = bgfx.C.bgfx_copy(raw, 128*128*4)
  raw = nil

  local tfmt = bgfx.BGFX_TEXTURE_FORMAT_RGBA8

  local texturehandle = bgfx.C.bgfx_create_texture_2d(128, 128, false, 1, tfmt, bgfx.BGFX_TEXTURE_NONE, bgfx_owned_mem)
  return texturehandle
end

return utils
