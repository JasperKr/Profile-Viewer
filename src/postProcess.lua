EventsByName = {}
Frames = { [0] = {} }
local frameIndex = 0
FrameEventRangeIndices = {}

for i, event in ipairs(Events) do
    if event.name == "\"Frame\"" or event.name == "Frame" then
        if event.type == "push" then -- ignore pop events
            table.insert(Frames, {})
            frameIndex = frameIndex + 1
            FrameEventRangeIndices[frameIndex] = { start = i, stop = i }
        else
            FrameEventRangeIndices[frameIndex].stop = i
        end
    end
    table.insert(Frames[frameIndex], event)

    if not EventsByName[event.name] then
        EventsByName[event.name] = {}
    end

    table.insert(EventsByName[event.name], event)
end

TotalEventTimeByName = {}
SortedEventGarbages = {}

for name, events in pairs(EventsByName) do
    local total = 0
    local garbageTotal = 0
    local count = 0
    for i, event in ipairs(events) do
        if event.type == "push" then
            total = total + event.duration
            garbageTotal = garbageTotal + event.garbage
            count = count + 1
        end
    end
    TotalEventTimeByName[name] = {
        duration = total,
        count = count,
        garbage = garbageTotal,
    }
end

SortedEventTimes = {}
SortedEventGarbages = {}

for name, total in pairs(TotalEventTimeByName) do
    table.insert(SortedEventTimes, { name = name, total = total.duration, count = total.count })
    table.insert(SortedEventGarbages, { name = name, total = total.garbage, count = total.count })
end

table.sort(SortedEventTimes, function(a, b) return a.total > b.total end)
table.sort(SortedEventGarbages, function(a, b) return a.total > b.total end)

local durations = {}

for i, frame in ipairs(Frames) do
    local firstEvent = frame[1]
    local lastEvent = frame[#frame]
    if firstEvent and lastEvent then
        local duration = lastEvent.stop - firstEvent.start
        table.insert(durations, duration)
    end
end

local function percentile(items, p)
    if #items == 0 then return 0 end
    table.sort(items)
    local index = math.ceil(p / 100 * #items)
    index = math.max(1, math.min(#items, index))
    return items[index]
end

GraphTimeMin = percentile(durations, 3)
GraphTimeMax = percentile(durations, 97)
