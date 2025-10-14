-- Dear Imgui version: 1.88

M = {
    love = {},
    _common = {}
}


require("cimgui.cdef")

local ffi = require("ffi")

local binary = "cimgui.dll"

if love.system.getOS() == "Linux" then
    binary = "cimgui.so"
end

M.C = ffi.load(love.filesystem.getSourceBaseDirectory() .. "/bin/" .. binary)

require("cimgui.enums")
require("cimgui.wrap")
require("cimgui.love")
require("cimgui.shortcuts")

-- remove access to M._common
M._common = nil

return M
