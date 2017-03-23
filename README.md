# luajit-bgfx

LuaJIT bindings for bgfx.

![Win64 screenshot](https://github.com/leafi/luajit-bgfx/blob/master/example/screenshots/win_screenshot.png)

(This is a port of work I've created for a personal project.)

The binding generator is barely sufficient for parsing the BGFX C headers.

It worked when I ran it 7 months ago, and it worked when I ran it today, so it
might be useful for your own projects.

## Generator requirements

The generator itself will run under any modern Lua.

However, **you need cpp available in $PATH**. I've only tested the generator on Linux.

And watch out for the hardcoded library paths in the bgfx_api.lua output. Just, you know, change them.

## Bindings runtime requirements

Tested on LuaJIT on Windows, OSX, and Linux. Seems to work.

Oh: **Only tested on (and designed for) 64-bit systems.**

The example code especially may fall over on a 32-bit system. Who knows?

## Directory layout

* **built/**: Output from the bindings generator & a few binaries (warning: Arch Linux .so build)
* **bgfx-include/**: What the binding generator builds from
* **example/**: An example application using BGFX and GLFW together to show a quad
* **this directory**: Fluff &amp; the binding generator.

License: MIT for my work - the binding generator, basically. I use someone else's
GLFW bindings in the example. And bgfx itself is of course courtesy of the wonderous @bkaradzic.

GLHF
