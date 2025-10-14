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

Sorted = {}

for idx, group in ipairs(Groups) do
    local groupName = group.name
    Sorted[groupName] = {}
end

Differences = {}

for i, frame in ipairs(Frames) do
    local firstEvent = frame[1]
    local lastEvent = frame[#frame]
    if firstEvent and lastEvent then
        for groupIdx, group in ipairs(Groups) do
            if not Differences[group.name] then
                Differences[group.name] = {}
            end

            local diff = lastEvent.data[groupIdx].stop - firstEvent.data[groupIdx].start
            table.insert(Differences[group.name], diff)
        end
    end
end

local function percentile(items, p)
    if #items == 0 then return 0 end
    table.sort(items)
    local index = math.ceil(p / 100 * #items)
    index = math.max(1, math.min(#items, index))
    return items[index]
end

Percentiles = {}

for groupName, diffs in pairs(Differences) do
    Percentiles[groupName] = {
        low = percentile(diffs, 3),
        high = percentile(diffs, 97),
    }
end
