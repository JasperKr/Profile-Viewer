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

    return wordCache
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

local function loadHeader(words)
    header = {}

    for i, word in ipairs(words) do
        header[word] = i
    end
end

local function loadEvent(words)
    local name, start, stop, garbageStart, garbageEnd, type = unpack(words, 1, 6)
    start, stop                                             = tonumber(start) or 0, tonumber(stop) or 0
    garbageStart, garbageEnd                                = tonumber(garbageStart) or 0, tonumber(garbageEnd) or 0

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

    return event
end

local file = love.filesystem.openFile(path, "r")
local filestring = file:read()

Events = {}

loadHeader(getWords(lines(filestring)()))
local secondLinePos = filestring:find("\n")

local function loadEvents(eventsStr, from, to)
    print(from, to)
    local clampedStr = eventsStr:sub(from, to)
    for str in lines(clampedStr) do
        local event = loadEvent(getWords(str))
        table.insert(Events, event)
    end

    return #clampedStr
end

local lastPos = secondLinePos
local modtime = 0
local size = 0

function UpdateGraphEvents()
    local newModtime = assert(love.filesystem.getInfo(path)).modtime

    if newModtime ~= modtime then
        modtime = newModtime

        local newSize = assert(love.filesystem.getInfo(path)).size

        if newSize < size then
            print("File was reset, reloading from start")
            lastPos = secondLinePos
            Events = {}
            Frames = { [0] = {} }
        end

        size = newSize

        local t = love.timer.getTime()
        file = love.filesystem.openFile(path, "r")
        filestring = file:read()
        print("Reloaded profiler file in " .. string.format("%.2f ms", (love.timer.getTime() - t) * 1000))
        t = love.timer.getTime()
        loadEvents(filestring, lastPos + 1, nil)
        lastPos = newSize
        print("Loaded " .. #Events .. " events in " .. string.format("%.2f ms", (love.timer.getTime() - t) * 1000))

        PostProcessFiledata()
    end
end
