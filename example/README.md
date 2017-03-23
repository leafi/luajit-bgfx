# An example

This is an example program. It uses BGFX and GLFW together.

GLFW version required: 3.2

I've slipped some binaries in for Windows & OS X users. Linux users,
your package manager should have a decent version of GLFW there somewhere.
We'll try to load `/usr/lib/libglfw.so.3.2`.

You probably can't get away with an older version of GLFW.

**OS X, Linux, Windows**: `luajit ./main.lua`

(Windows? Consider luapower. It has a 64-bit build of LuaJIT and uses it by default.)

![Win64 screenshot](https://github.com/leafi/luajit-bgfx/blob/master/example/screenshots/win_screenshot.png)

![OSX64 screenshot... via VNC, excuse color banding...](https://github.com/leafi/luajit-bgfx/blob/master/example/screenshots/osx_screenshot.png)
