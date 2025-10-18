local ffi = require "ffi"
local wordCache = {}

local mountDirectory = "Profile/"
ProfilePath = Stringh.sanitise(ProfilePath)

local profileDir = Stringh.directory(ProfilePath)
local path = (mountDirectory .. Stringh.filename(ProfilePath)):gsub("\\", "/")

---@diagnostic disable-next-line: undefined-field
assert(love.filesystem.mountFullPath(profileDir, mountDirectory, "read"))
local fields = {}
local repl = function(c) table.insert(fields, c) end

local function split(str, sep)
    table.clear(fields)
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(str, pattern, repl)
    return fields
end

local function getWords(str)
    local i = 1
    for word in str:gmatch("([^,]+)") do
        wordCache[i] = word
        i = i + 1
    end
end

local function lines(s)
    local pos = 1
    return function()
        if pos > #s then return nil end
        local start = pos
        local _, eol = s:find("\n", pos)
        if eol then
            pos = eol + 1
            return s:sub(start, eol - 1)
        else
            pos = #s + 1
            return s:sub(start)
        end
    end
end

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

    add("return function(wordCache)")
    indent()
    add("local entry = {}")
    add("entry.name = wordCache[1] -- hardcoded since these are always the first two entries")
    add("entry.type = wordCache[2]")
    add("entry.data = {}")
    add("")

    local groups = {}
    for i = 3, #format do
        local f = format[i]
        if not groups[f.group - 2] then
            groups[f.group - 2] = {}
        end

        table.insert(groups[f.group - 2], { index = i, name = f.name, type = f.type, when = f.when })
    end

    for groupIdx, group in ipairs(groups) do
        print("Found start - end pair for group: '" .. group[1].name .. "' of type: " .. group[1].type)

        add("entry.data[" .. groupIdx .. "] = {")
        indent()
        for _, item in ipairs(group) do
            local entryName = item.when == "start" and "start" or
                (item.when == "end" and "stop" or error("Invalid 'when' value: " .. tostring(item.when)))
            add(string.format("%s = tonumber(wordCache[%d]),", entryName, item.index))
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
local file = love.filesystem.openFile(path, "r")
local filestring = file:read()

Events = {}
Format = {}
local groupIndex = 1

local line = 0
for str in lines(filestring) do
    line = line + 1

    getWords(str)

    if line == 1 then
        for i, word in ipairs(wordCache) do
            local name, type, when = unpack(split(word, ":"))

            assert(name and type, "Invalid header format at word '" .. tostring(word) .. "'")

            if name ~= "name" and name ~= "type" then
                assert(when, "When is nil for name '" .. name .. "'")
            end

            assert(type == "time" or type == "byte" or type == "name" or type == "type" or type == "duration",
                "Type must be 'time', 'byte' or 'duration'")
            assert(when == "start" or when == "end" or type == "name" or type == "type", "When must be 'start' or 'end'")

            Format[i] = { name = name, type = type, when = when, group = groupIndex }
            if when == "end" or type == "name" or type == "type" then
                groupIndex = groupIndex + 1
            end
        end

        Format.components = #wordCache
        Format.createEntry = generateCreateEntryFunction(Format)
    else
        local entry = Format.createEntry(wordCache)
        table.insert(Events, entry)
    end
end

---@diagnostic disable-next-line: undefined-field
love.filesystem.unmountFullPath(profileDir)

GroupNameToIndex = {}

for i, group in ipairs(Groups) do
    group.color = colors[((i - 1) % #colors) + 1]
    group.color = ffi.new("float[4]", group.color[1], group.color[2], group.color[3], 1)
    group.workingColor = { group.color[0], group.color[1], group.color[2], group.color[3] }

    GroupNameToIndex[group.name] = i
end
