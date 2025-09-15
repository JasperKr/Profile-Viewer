local ffi = require("ffi")
Gui = {}

function Imgui.ButtonRight(name, size)
    local style = Imgui.style
    local width = size and size.x or (Imgui.CalcTextSize(name).x + style.FramePadding.x * 2)
    local widthNeeded = width + style.ItemSpacing.x
    Imgui.SetCursorPosX(Imgui.GetCursorPos().x + Imgui.GetContentRegionAvail().x - widthNeeded)
    return Imgui.Button(name, size)
end

function Imgui.TextRight(name)
    local style = Imgui.style
    local width = Imgui.CalcTextSize(name).x + style.FramePadding.x * 2
    local widthNeeded = width + style.ItemSpacing.x
    Imgui.SetCursorPosX(Imgui.GetCursorPos().x + Imgui.GetContentRegionAvail().x - widthNeeded)
    return Imgui.Text(name)
end

function Imgui.TextCentered(name)
    local style = Imgui.style
    local width = Imgui.CalcTextSize(name).x + style.FramePadding.x * 2
    local widthNeeded = width + style.ItemSpacing.x
    Imgui.SetCursorPosX(Imgui.GetCursorPos().x + (Imgui.GetContentRegionAvail().x - widthNeeded) / 2)
    return Imgui.Text(name)
end

function Gui.InputFloat(name, value, step, stepFast, format, flags)
    value = ffi.new("float[1]", value)
    local changed = Imgui.InputFloat(name, value, step, stepFast, format, flags)
    return value[0], changed
end

function Gui.InputInt(name, value, step, stepFast, flags)
    value = ffi.new("int[1]", value)
    local changed = Imgui.InputInt(name, value, step, stepFast, flags)
    return value[0], changed
end

function Gui.InputFloat2(name, value, step, stepFast)
    value = ffi.new("float[2]", unpack(value))
    local changed = Imgui.InputFloat2(name, value, step, stepFast)
    return value[0], value[1], changed
end

function Gui.InputFloat3(name, value, step, stepFast)
    value = ffi.new("float[3]", unpack(value))
    local changed = Imgui.InputFloat3(name, value, step, stepFast)
    return value[0], value[1], value[2], changed
end

function Gui.InputFloat4(name, value, step, stepFast)
    value = ffi.new("float[4]", unpack(value))
    local changed = Imgui.InputFloat4(name, value, step, stepFast)
    return value[0], value[1], value[2], value[3], changed
end

function Gui.Checkbox(name, value)
    local temp = ffi.new("bool[1]", value)
    local changed = Imgui.Checkbox(name, temp)
    return temp[0], changed
end
