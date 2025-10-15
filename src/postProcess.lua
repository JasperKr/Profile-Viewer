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

Sorted["count"] = {}

Differences = {}

local lowest = math.huge
local highest = -math.huge

for i, frame in ipairs(Frames) do
    local firstEvent = frame[1]
    local lastEvent = frame[#frame]
    if firstEvent and lastEvent then
        for groupIdx, group in ipairs(Groups) do
            if not Differences[group.name] then
                Differences[group.name] = {}
            end

            local diff = lastEvent.data[groupIdx].stop

            if group.type == "time" then
                diff = diff - firstEvent.data[groupIdx].start
            end

            if lastEvent.data[groupIdx].stop == -math.huge or firstEvent.data[groupIdx].start == -math.huge then
                goto continue
            end

            table.insert(Differences[group.name], diff)

            lowest = math.min(lowest, diff)
            highest = math.max(highest, diff)
            ::continue::
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
    local p = 3

    Percentiles[groupName] = {
        low = percentile(Differences[groupName], p),
        high = percentile(Differences[groupName], 100 - p),
    }

    if lowest == highest then
        Percentiles[groupName].low = lowest * 0.9
        Percentiles[groupName].high = highest * 1.1

        print("Lowest equals highest, adjusting percentiles to:", Percentiles[groupName].low, Percentiles[groupName]
            .high)
    end

    while Percentiles[groupName].low == Percentiles[groupName].high do
        p = p / 2

        Percentiles[groupName].low = percentile(Differences[groupName], p)
        Percentiles[groupName].high = percentile(Differences[groupName], 100 - p)
    end

    if Percentiles[groupName].low > 0 then
        Percentiles[groupName].low = Percentiles[groupName].low * 0.975
    else
        Percentiles[groupName].low = Percentiles[groupName].low * 1.025
    end

    if Percentiles[groupName].high > 0 then
        Percentiles[groupName].high = Percentiles[groupName].high * 1.025
    else
        Percentiles[groupName].high = Percentiles[groupName].high * 0.975
    end
end
