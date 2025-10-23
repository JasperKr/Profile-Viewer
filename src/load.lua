local ffi = require "ffi"
local loadStart = love.timer.getTime()

local mountDirectory = "Profile/"
ProfilePath = Stringh.sanitise(ProfilePath)

local profileDir = Stringh.directory(ProfilePath)
local path = (mountDirectory .. Stringh.filename(ProfilePath)):gsub("\\", "/")

---@diagnostic disable-next-line: undefined-field
assert(love.filesystem.mountFullPath(profileDir, mountDirectory, "read"))

--[[
local format = { "name:name", "type:type" }
local function addItemToFormat(name, type)
    assert(name and type, "Name or type is nil")
    assert(type == "time" or type == "byte", "Type must be 'time' or 'byte'")
    table.insert(format, name .. ":" .. type .. ":start")
    table.insert(format, name .. ":" .. type .. ":end")
end
]]

-- format might look like:
-- "name:name,type:type,time:time:start,time:time:end,memory:byte:start,memory:byte:end,graphicsMemory:byte:start,graphicsMemory:byte:end"

local function generateCreateEntryFunction(format)
    -- debug print the format

    print("generateCreateEntryFunction: format =")
    for i, f in ipairs(format) do
        print(string.format("  [%d] name=%s, type=%s, when=%s, group=%s", i, tostring(f.name), tostring(f.type),
            tostring(f.when), tostring(f.group)))
    end

    local str = ""
    local indentation = 0

    local function add(what)
        str = str .. string.rep(" ", indentation * 4) .. what .. "\n"
    end
    local function indent()
        indentation = indentation + 1
    end
    local function unindent()
        indentation = indentation - 1
    end

    add("return function(uintArrPtr, floatArrPtr, idxToName, idxToType)")
    indent()
    add("local entry = {}")
    add("entry.name = idxToName[tonumber(uintArrPtr[0])] -- hardcoded since these are always the first two entries")
    add("entry.type = idxToType[tonumber(uintArrPtr[1])]")
    add("entry.data = {}")
    add("")

    local groups = {}
    for i = 1, #format do
        local f = format[i]
        if not groups[f.group] then
            groups[f.group] = {}
        end

        table.insert(groups[f.group], { index = i, name = f.name, type = f.type, when = f.when })
    end

    for groupIdx, group in ipairs(groups) do
        print("Found start - end pair for group: '" .. group[1].name .. "' of type: " .. group[1].type)

        add("entry.data[" .. groupIdx .. "] = {")
        indent()
        for _, item in ipairs(group) do
            local entryName = item.when
            if entryName ~= "start" and entryName ~= "stop" then
                error("Invalid when: " .. tostring(entryName))
            end

            add(string.format("%s = tonumber(floatArrPtr[%d]),", entryName, item.index + 1))
        end
        unindent()
        add("}")
    end

    Groups = {}

    for groupIdx, group in ipairs(groups) do
        table.insert(Groups, { name = group[1].name, type = group[1].type, hidden = ffi.new("bool[1]", false) })
    end

    add("return entry")
    unindent()
    add("end")

    assert(indentation == 0, "Indentation is not zero")

    return assert(assert(loadstring(str))())
end

local colors = {
    { 0.9, 0.5, 0.1, 0.8 },
    { 0.1, 0.9, 0.5, 0.8 },
    { 0.5, 0.1, 0.9, 0.8 },
    { 0.9, 0.1, 0.5, 0.8 },
    { 0.5, 0.9, 0.1, 0.8 },
    { 0.1, 0.5, 0.9, 0.8 },
}

---@diagnostic disable-next-line: undefined-field
local file = love.filesystem.newFileData(path)
local nameToIdx, idxToName

Events = {}
Format = {}

local groupIndex = 1
local function parseHeader(header)
    for i, item in ipairs(header.format) do
        local name, type, when = item.name, item.type, item.when

        if name ~= "name" and name ~= "type" then
            assert(when, "When is nil for name '" .. name .. "'")
        end

        assert(type == "time" or type == "byte" or type == "name" or type == "type",
            "Type must be 'time', 'byte'")
        assert(when == "start" or when == "stop" or type == "name" or type == "type",
            "When must be 'start', 'stop'")

        Format[i] = { name = name, type = type, when = when, group = groupIndex }
        if when == "stop" or type == "name" or type == "type" then
            groupIndex = groupIndex + 1
        end
    end

    nameToIdx = header.names
    idxToName = setmetatable({}, {
        __index = function(t, k)
            error(k)
        end
    })
    for name, idx in pairs(nameToIdx) do
        idxToName[idx] = name
        print("Mapping name '" .. name .. "' to index " .. idx)
    end

    Format.components = #header.format
    print("Profile format has " .. Format.components .. " components per entry.")
    Format.createEntry = generateCreateEntryFunction(Format)
end

local headerSize = file:getUInt32(0)
local header = love.data.newDataView(file, 4, headerSize)
local profileData = love.data.newDataView(file, 4 + headerSize, file:getSize() - (4 + headerSize))
local headerData = require("string.buffer").decode(header:getString())
parseHeader(headerData)

local floatArrPtr = ffi.cast("float*", profileData:getFFIPointer())
local uintArrPtr = ffi.cast("uint32_t*", profileData:getFFIPointer())

local idxToType = {
    [1] = "push",
    [2] = "pop",
    [3] = "leaf",
}

-- divide by 4 -> uint32_t size, and then by number of components per entry
local totalComponentCount = Format.components + 2 -- +2 for name and type
for i = 0, profileData:getSize() / (4 * totalComponentCount) - 1 do
    local offset = i * totalComponentCount        -- No need to multiply by 4 since we're working in uint32_t indices

    -- print(uintArrPtr[offset],
    --     uintArrPtr[offset + 1],
    --     idxToName[uintArrPtr[offset]],
    --     idxToType[uintArrPtr[offset + 1]])

    -- print(floatArrPtr[offset + 2],
    --     floatArrPtr[offset + 3],
    --     floatArrPtr[offset + 4],
    --     floatArrPtr[offset + 5],
    --     floatArrPtr[offset + 6],
    --     floatArrPtr[offset + 7],
    --     floatArrPtr[offset + 8]
    -- )

    if tonumber(uintArrPtr[offset]) == 0 then
        error("Encountered event with name index 0 at entry " .. i .. ". This is invalid.")
    end

    if tonumber(uintArrPtr[offset + 1]) > 3 then
        error("Encountered event with invalid type index " .. tonumber(uintArrPtr[offset + 1]) .. " at entry " .. i)
    end

    if tonumber(uintArrPtr[offset + 1]) == 0 then
        error("Encountered event with invalid type index " .. tonumber(uintArrPtr[offset + 1]) .. " at entry " .. i)
    end

    local entry = Format.createEntry(uintArrPtr + offset, floatArrPtr + offset, idxToName, idxToType)
    table.insert(Events, entry)
end

print("Loaded " .. #Events .. " events from profile.")

---@diagnostic disable-next-line: undefined-field
love.filesystem.unmountFullPath(profileDir)

GroupNameToIndex = {}

for i, group in ipairs(Groups) do
    group.color = colors[((i - 1) % #colors) + 1]
    group.color = ffi.new("float[4]", group.color[1], group.color[2], group.color[3], 1)
    group.workingColor = { group.color[0], group.color[1], group.color[2], group.color[3] }

    GroupNameToIndex[group.name] = i
end

local loadEnd = love.timer.getTime()
print(string.format("Profile loaded in %.2f seconds.", loadEnd - loadStart))
