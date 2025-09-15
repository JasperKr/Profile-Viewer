-- Dear Imgui version: 1.88

M = {
    love = {},
    _common = {}
}


require("cimgui.cdef")

local ffi = require("ffi")
M.C = ffi.load(love.filesystem.getSourceBaseDirectory() .. "/bin/cimgui.dll")

require("cimgui.enums")
require("cimgui.wrap")
require("cimgui.love")
require("cimgui.shortcuts")

-- remove access to M._common
M._common = nil

return M
