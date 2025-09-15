local header
local wordCache = {}

local profilerPath = "/LOVE/Rhodium/profiler.csv"
local mountDirectory = "Profile/"

local appdata = assert(os.getenv("APPDATA"))
local profileFullPath = (appdata .. profilerPath):gsub("\\", "/")
local profileDir = Stringh.directory(profileFullPath)
local path = (mountDirectory .. Stringh.filename(profileFullPath)):gsub("\\", "/")

assert(love.filesystem.mountFullPath(profileDir, mountDirectory, "read"))

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

local file = love.filesystem.openFile(path, "r")
local filestring = file:read()

Events = {}

local line = 0
for str in lines(filestring) do
    line = line + 1

    getWords(str)

    if line == 1 then
        header = {}

        for i, word in ipairs(wordCache) do
            header[word] = i
        end
    else
        local name, start, stop, garbageStart, garbageEnd, type = unpack(wordCache, 1, 6)
        start, stop                                             = tonumber(start), tonumber(stop)
        garbageStart, garbageEnd                                = tonumber(garbageStart), tonumber(garbageEnd)

        local garbage                                           = garbageEnd - garbageStart
        local duration                                          = stop - start

        local event                                             = table.new(0, 8)
        event.duration                                          = duration
        event.start                                             = start
        event.stop                                              = stop
        event.name                                              = name
        event.garbageStart                                      = garbageStart
        event.garbageEnd                                        = garbageEnd
        event.garbage                                           = garbage
        event.type                                              = type

        table.insert(Events, event)
    end
end

love.filesystem.unmountFullPath(profileDir)
