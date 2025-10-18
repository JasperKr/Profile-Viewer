EventsByName = {}
Frames = { [0] = {} }
local frameIndex = 0
FrameEventRangeIndices = {}

local function percentile(items, p)
    if #items == 0 then return 0 end
    table.sort(items)
    local index = math.ceil(p / 100 * #items)
    index = math.max(1, math.min(#items, index))
    return items[index]
end

function PostProcessFiledata()
    frameIndex = 0

    local t1 = love.timer.getTime()
    print(#Events .. " events to process")
    for i, event in ipairs(Events) do
        local name = event.name

        if name == "Frame" then
            if event.type == "push" then -- ignore pop events
                frameIndex = frameIndex + 1
                Frames[frameIndex] = {}
                FrameEventRangeIndices[frameIndex] = { start = i, stop = i }
            else
                Frames[frameIndex].done = true
                FrameEventRangeIndices[frameIndex].stop = i
            end
        end

        if not Frames[frameIndex].done then
            if not EventsByName[name] then
                EventsByName[name] = {}
            end

            table.insert(Frames[frameIndex], event)
            table.insert(EventsByName[name], event)
        end
    end
    local indexEventsByFrame = love.timer.getTime() - t1

    TotalEventTimeByName = {}
    SortedEventGarbages = {}

    t1 = love.timer.getTime()

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

    local computeTotalsByName = love.timer.getTime() - t1
    t1 = love.timer.getTime()

    SortedEventTimes = {}
    SortedEventGarbages = {}

    for name, total in pairs(TotalEventTimeByName) do
        table.insert(SortedEventTimes, { name = name, total = total.duration, count = total.count })
        table.insert(SortedEventGarbages, { name = name, total = total.garbage, count = total.count })
    end

    table.sort(SortedEventTimes, function(a, b) return a.total > b.total end)
    table.sort(SortedEventGarbages, function(a, b) return a.total > b.total end)

    local sortTotalsByName = love.timer.getTime() - t1
    t1 = love.timer.getTime()

    local durations = {}

    for i, frame in ipairs(Frames) do
        local firstEvent = frame[1]
        local lastEvent = frame[#frame]
        if firstEvent and lastEvent then
            local duration = lastEvent.stop - firstEvent.start
            table.insert(durations, duration)
        end
    end

    GraphTimeMin = percentile(durations, 3)
    GraphTimeMax = percentile(durations, 97)

    local computeGraphMinMax = love.timer.getTime() - t1

    print(string.format("Post processing took %.2f ms",
        (indexEventsByFrame + computeTotalsByName + sortTotalsByName + computeGraphMinMax) * 1000))
    print(string.format(" - Index events by frame: %.2f ms", indexEventsByFrame * 1000))
    print(string.format(" - Compute totals by name: %.2f ms", computeTotalsByName * 1000))
    print(string.format(" - Sort totals by name: %.2f ms", sortTotalsByName * 1000))
    print(string.format(" - Compute graph min/max: %.2f ms", computeGraphMinMax * 1000))
end
