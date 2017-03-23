local handles = {
  bgfx=nil,
  ffi=nil,
  glfw=nil,
  GLFW=nil,
  window=nil
}

return function(options)
  -- The one and only option. Just to make my example easier for myself.
  local use_opengl_not_default = options.use_opengl_not_default or false

  -- identify OS
  local wwos = 'linux'
  local wwjit = require('jit')
  if wwjit.os == 'Windows' then wwos = 'win' end
  if wwjit.os == 'OSX' then wwos = 'osx' end
  wwjit = nil

  local glfw_path = nil
  if wwos == 'win' then glfw_path = 'glfw/bin/libglfw.dll' end
  if wwos == 'osx' then glfw_path = 'glfw/bin/libglfw.dylib' end
  if wwos == 'linux' then glfw_path = '/usr/lib/libglfw.so.3.2' end

  local glfw = require('glfw.glfw')(glfw_path)
  local GLFW = glfw.const
  handles.glfw = glfw
  handles.GLFW = GLFW

  if glfw.Init() == 0 then
    error('glfw.Init() failed')
  end

  -- I did say you needed GLFW 3.2...
  glfw.WindowHint(GLFW.CLIENT_API, GLFW.NO_API)
  local window = glfw.CreateWindow(640, 400, 'o test')
  if window == 0 then
    -- consider doing glfw.Terminate() here if your prog would ever retry
    error('Glfw window creation failed')
  end
  handles.window = window

  glfw.MakeContextCurrent(window)

  local ffi = require('ffi')
  if wwos == 'linux' then
    -- implicit but as-yet unloaded dependency! grrrrrr
    -- ', true' makes symbols available globally
    ffi.load('/usr/lib/libX11.so.6', true)  -- what's a wayland?
  end
  handles.ffi = ffi

  local bgfx = require('bgfx_api')
  handles.bgfx = bgfx

  -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  -- !! Add some useful stuff the binding generator misses !!
  -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  bgfx.BGFX_STATE_BLEND_FUNC_SEPARATE = function(srcRGB, dstRGB, srcA, dstA)
    return tonumber(srcRGB) + bit.lshift(tonumber(dstRGB), 4) + bit.lshift(tonumber(srcA) + bit.lshift(tonumber(dstA), 4), 8)
  end
  bgfx.BGFX_STATE_BLEND_FUNC = function(src, dst)
    return bgfx.BGFX_STATE_BLEND_FUNC_SEPARATE(src, dst, src, dst)
  end
  --bgfx.BGFX_STATE_BLEND_NORMAL = bgfx.BGFX_STATE_BLEND_FUNC(bgfx.BGFX_STATE_BLEND_ONE, bgfx.BGFX_STATE_BLEND_INV_SRC_ALPHA)
  bgfx.BGFX_STATE_BLEND_ALPHA = bgfx.BGFX_STATE_BLEND_FUNC(bgfx.BGFX_STATE_BLEND_SRC_ALPHA, bgfx.BGFX_STATE_BLEND_INV_SRC_ALPHA)
  bgfx.BGFX_STATE_BLEND_MULTIPLY = bgfx.BGFX_STATE_BLEND_FUNC(bgfx.BGFX_STATE_BLEND_DST_COLOR, bgfx.BGFX_STATE_BLEND_ZERO)

  -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  print('constructing platdata')
  local pdparam = nil
  if wwos == 'win' then
    pdparam = {
      backBuffer = nil,
      backBufferDS = nil,
      ndt = nil,
      nwh = glfw.GetWin32Window(window),
      context = nil
    }
  elseif wwos == 'osx' then
    pdparam = {
      backBuffer = nil,
      backBufferDS = nil,
      ndt = nil,
      nwh = glfw.GetCocoaWindow(window),
      context = nil
    }
  elseif wwos == 'linux' then
    local nwh = ffi.cast('void *', glfw.GetX11Window(window))
    pdparam = {
      backBuffer = nil,
      backBufferDS = nil,
      ndt = glfw.GetX11Display(),
      nwh = nwh,
      context = nil
    }
  else
    error(wwos)
  end

  local pd = ffi.new('bgfx_platform_data_t', pdparam)

  print('set platdata')
  bgfx.C.bgfx_set_platform_data(pd)

  -- yet another implicit but as-yet unloaded bgfx dependency
  if wwos == 'linux' then
    -- What's a Vulkan?
    ffi.load('/usr/lib/libGL.so', true)
  end

  print('pre-init')
  local renderer_type = use_opengl_not_default and bgfx.BGFX_RENDERER_TYPE_OPENGL or bgfx.BGFX_RENDERER_TYPE_COUNT
  bgfx.C.bgfx_init(renderer_type, 0, 0, nil, nil)
  print('bgfx_reset')
  bgfx.C.bgfx_reset(640, 400, bgfx.BGFX_RESET_VSYNC)

  print('bgfx_set_debug')
  bgfx.C.bgfx_set_debug(bgfx.BGFX_DEBUG_TEXT)

  -- Make GLFW not crashy on OS X (do this once before any real work)
  glfw.PollEvents()

  -- ... and that's it! We're done! Phew.

  return handles
end
