-- do somewhat hairy & platform-specific setup work
-- (and patch in a couple of things the bindings generator misses (e.g. BLEND_FUNC))
local do_setup = require('wrangling')
local handles = do_setup({
  use_opengl_not_default=true  -- Just so I don't have to build more shaders, I swear!
})

local bgfx = handles.bgfx
local ffi = handles.ffi
local glfw = handles.glfw
local GLFW = handles.GLFW
local window = handles.window


-- with apologies to https://github.com/pixeljetstream/luajit_gfx_sandbox/blob/master/runtime/lua/math3d.lua
local _M = {}
function _M.m4float()
  local m = ffi.new('float[16]')
  for i = 0,15 do m[i] = 0 end
  m[0] = 1
  m[5] = 1
  m[10] = 1
  m[15] = 1
  return m
end
function _M.m4orthoMS(mat, left, right, bottom, top, near, far)
  -- NOTE: assumes matrix 'mat' is identity!
  mat[0] = 2.0/(right-left)
  mat[5] = 2.0/(top-bottom)
  mat[10] = 1.0/(near-far)
  mat[12] = (left + right)/(left - right)
  mat[13] = (top + bottom)/(bottom - top)
  mat[14] = near / (near - far)
  mat[15] = 1.0
end


bgfx.C.bgfx_set_view_clear(0, bgfx.BGFX_CLEAR_COLOR + bgfx.BGFX_CLEAR_DEPTH, 0x303030ff, 1.0, 0)
bgfx.C.bgfx_set_view_rect(0, 0, 0, 640, 400)

local w = 640
local h = 400
local whChanged = true

glfw.SetWindowSizeCallback(window, function(wnd, ww, hh)
  w = ww; h = hh; whChanged = true
end)


local utils = require('utils')
utils.init(_M, bgfx, ffi)

local simpleprog = utils.shaderprog('shaders/bin/glsl/simple.vs.bin', 'shaders/bin/glsl/simple.fs.bin')
local simplevdecl = ffi.new('bgfx_vertex_decl_t[1]')
bgfx.C.bgfx_vertex_decl_begin(simplevdecl, bgfx.BGFX_RENDERER_TYPE_NOOP)
bgfx.C.bgfx_vertex_decl_add(simplevdecl, bgfx.BGFX_ATTRIB_POSITION, 2, bgfx.BGFX_ATTRIB_TYPE_FLOAT, false, false)
bgfx.C.bgfx_vertex_decl_add(simplevdecl, bgfx.BGFX_ATTRIB_TEXCOORD0, 2, bgfx.BGFX_ATTRIB_TYPE_FLOAT, false, false)
bgfx.C.bgfx_vertex_decl_add(simplevdecl, bgfx.BGFX_ATTRIB_COLOR0, 4, bgfx.BGFX_ATTRIB_TYPE_FLOAT, false, false)
bgfx.C.bgfx_vertex_decl_end(simplevdecl)
local samplerColor = bgfx.C.bgfx_create_uniform('s_texColor', bgfx.BGFX_UNIFORM_TYPE_INT1, 1)

local texture = utils.gentexture()

local projMtx = _M.m4float()
local viewMtx = _M.m4float()
local mdlMtx = _M.m4float()

local verts = {}
local function pushv(x, y, u, v, r, g, b, a)
  verts[#verts+1] = x
  verts[#verts+1] = y
  verts[#verts+1] = u
  verts[#verts+1] = v
  verts[#verts+1] = r
  verts[#verts+1] = g
  verts[#verts+1] = b
  verts[#verts+1] = a
end
local function pushquad(x, y, w, h)
  pushv(x, y,     0, 0,    1, 1, 1, 1)
  pushv(x, y+h,   0, 1,    1, 1, 1, 1)
  pushv(x+w, y,   1, 0,    1, 1, 1, 1)
  pushv(x+w, y,   1, 0,    1, 1, 1, 1)
  pushv(x, y+h,   0, 1,    1, 1, 1, 1)
  pushv(x+w, y+h, 1, 1,    1, 1, 1, 1)
end

pushquad(100, 100, 128, 128)

while glfw.WindowShouldClose(window) == 0 do
  if whChanged then
    bgfx.C.bgfx_reset(w, h, bgfx.BGFX_RESET_VSYNC)
    bgfx.C.bgfx_set_view_rect(0, 0, 0, w, h)
    _M.m4orthoMS(projMtx, 0, w, h, 0, 0, 2)
    whChanged = false
  end

  bgfx.C.bgfx_set_view_seq(0, true)
  bgfx.C.bgfx_set_view_transform(0, viewMtx, projMtx)

  -- hey, i never said it was a well-written example. i'm cribbing from my own code here.
  local tvb = ffi.new('bgfx_transient_vertex_buffer_t[1]')
  local numverts = #verts/8
  bgfx.C.bgfx_alloc_transient_vertex_buffer(tvb, numverts, simplevdecl)
  local vdptr = ffi.cast('float *', tvb[0].data)
  for i = 1,#verts do
    vdptr[i-1] = verts[i]
  end

  bgfx.C.bgfx_set_transform(mdlMtx, 1)
  bgfx.C.bgfx_set_state(bgfx.BGFX_STATE_BLEND_ALPHA + bgfx.BGFX_STATE_ALPHA_WRITE + bgfx.BGFX_STATE_DEPTH_WRITE + bgfx.BGFX_STATE_RGB_WRITE, 0xffffffff)
  bgfx.C.bgfx_set_transient_vertex_buffer(tvb, 0, #verts/8)
  -- texture unit 0
  bgfx.C.bgfx_set_texture(0, samplerColor, texture, 0xffffffff)
  bgfx.C.bgfx_submit(0, simpleprog, 0, false)

  bgfx.C.bgfx_touch(0)
  bgfx.C.bgfx_dbg_text_clear(0, false)
  bgfx.C.bgfx_dbg_text_printf(0, 1, 0x4f, 'Hi there!')

  bgfx.C.bgfx_frame(false)
  glfw.PollEvents()
end


bgfx.C.bgfx_shutdown()
glfw.DestroyWindow(window)
glfw.Terminate()
