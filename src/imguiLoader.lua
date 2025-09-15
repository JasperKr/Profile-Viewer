local lib_path = love.filesystem.getSource() .. "\\.."
local extension = jit.os == "Windows" and "dll" or jit.os == "Linux" and "so" or jit.os == "OSX" and "dylib"
package.cpath = string.format("%s;%s/?.%s", package.cpath, lib_path, extension)

Imgui = require("cimgui.init")
Imgui.love.Init()


Imgui.style = Imgui.GetStyle()

require("imguiHelper")

local io = Imgui.GetIO()
io.ConfigFlags = bit.bor(io.ConfigFlags, Imgui.ImGuiConfigFlags_DockingEnable)

M = nil
