local ffi = require("ffi")
local bit = require("bit")

Stringh = require("stringHelpers")

require("imguiLoader")
require("guiStyle")
table.clear = require("table.clear")
table.new = require("table.new")

local SummaryMode = false

local last = {}
local viewRanges = {}
local sortByString

local keyToGraph = nil

function love.load(args)
    for i, arg in ipairs(args) do
        if arg == "-generate-summary-texture" then
            SummaryMode = true

            function love.errorhandler(msg)
                print("Error: " .. debug.traceback(tostring(msg)))
                love.event.quit(1)
            end
        elseif i == #args then
            ProfilePath = arg
        end
    end

    require("load")
    require("postProcess")

    UpdateSelectionStatistics()

    for groupIdx, group in ipairs(Groups) do
        last[group.name] = 0

        local low, high = Percentiles[group.name].low, Percentiles[group.name].high

        viewRanges[group.name] = { min = low, max = high, offset = -low, scale = 1 / (high - low) }
    end

    sortByString = Groups[1] and Groups[1].name or error("No groups found")
    local best = 1
    local score = 0

    for groupIdx, group in ipairs(Groups) do
        if group.name == "time" then
            best = groupIdx
            score = 2
        elseif group.type == "time" and score < 1 then
            best = groupIdx
            score = 1
        end
    end

    keyToGraph = Groups[best].name
end

local screenPos = Imgui.ImVec2_Float(0, 0)
local function transformPoint(x, y)
    Imgui.GetCursorScreenPos(screenPos)

    ---@diagnostic disable-next-line: undefined-field
    return screenPos.x + x, screenPos.y + y
end
local function inverseTransformPoint(x, y)
    Imgui.GetCursorScreenPos(screenPos)

    ---@diagnostic disable-next-line: undefined-field
    return x - screenPos.x, y - screenPos.y
end

local function countNewlines(str)
    local count = 0
    for _ in str:gmatch("\n") do
        count = count + 1
    end
    return count
end

--- Format data for display based on type
---@param data number | integer
---@param type "time" | "byte" | "duration"
---@return string
local function formatFor(data, type)
    if type == "time" or type == "duration" then
        return Stringh.formatTime(data)
    elseif type == "byte" then
        return Stringh.formatBytes(data, false)
    else
        error("Unknown group type: " .. tostring(type))
    end
end

local hiddenGroupColorScale = 0.2
local selectedFrameRange = { -1, -1 }
local selectedEvent = nil
local highlightColor = { 0, 0.5, 0.8, 0.8 }

local windowPos = Imgui.ImVec2_Nil()
local windowSize = Imgui.ImVec2_Nil()

local function pointAABB(x, y, minX, minY, maxX, maxY)
    return x >= minX and x <= maxX and y >= minY and y <= maxY
        and y >= minY and y <= maxY
end

local selectionEventInfoByName = {}
local selectionTotalEventCount = 0
local eventInfoCache = {}

local function clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

function UpdateSelectionStatistics()
    table.clear(selectionEventInfoByName)
    selectionTotalEventCount = 0

    local firstFrameRangeInfo = FrameEventRangeIndices[selectedFrameRange[1]] or { start = 1, stop = #Events }
    local lastFrameRangeInfo = FrameEventRangeIndices[selectedFrameRange[2]] or { start = 1, stop = #Events }

    local eventRangeStart = firstFrameRangeInfo.start
    local eventRangeEnd = lastFrameRangeInfo.stop

    for i = eventRangeStart, eventRangeEnd do
        local event = Events[i]
        local name = event.name
        local eventInfo = selectionEventInfoByName[name]

        if event.type == "push" then
            if eventInfo == nil then
                selectionEventInfoByName[name] = {
                    count = 0,
                }

                for groupIdx, group in ipairs(Groups) do
                    selectionEventInfoByName[name][group.name] = 0
                end

                eventInfo = selectionEventInfoByName[name]
            end

            for groupIdx, group in ipairs(event.data) do
                local groupDescription = Groups[groupIdx]
                eventInfo[groupDescription.name] = eventInfo[groupDescription.name] + group.stop - group.start
            end

            eventInfo.count =
                eventInfo.count + 1

            selectionTotalEventCount = selectionTotalEventCount + 1
        end
    end


    for i, toSort in pairs(Sorted) do
        for j, info in ipairs(toSort) do table.insert(eventInfoCache, info) end
        table.clear(toSort)
    end

    for name, total in pairs(selectionEventInfoByName) do
        for groupIdx, group in ipairs(Groups) do
            local info = table.remove(eventInfoCache) or {}
            info.name = name
            info.total = total[group.name]
            info.count = total.count

            table.insert(Sorted[group.name], info)
        end
    end

    for name, total in pairs(selectionEventInfoByName) do
        local info = table.remove(eventInfoCache) or {}

        info.name = name
        info.total = total.count
        info.count = total.count

        table.insert(Sorted["count"], info)
    end

    for i, toSort in pairs(Sorted) do
        table.sort(toSort, function(a, b) return a.total > b.total end)
    end
end

local previousStart = -1
local previousEnd = -1

local function handleDrag(frameXStart, frameXEnd, frameCount, floor)
    local mx, my = love.mouse.getPosition()

    Imgui.GetWindowPos(windowPos)
    Imgui.GetWindowSize(windowSize)

    ---@diagnostic disable-next-line: undefined-field
    local windowMinX, windowMinY = windowPos.x, windowPos.y
    ---@diagnostic disable-next-line: undefined-field
    local windowMaxX, windowMaxY = windowPos.x + windowSize.x, windowPos.y + windowSize.y

    local inAABB = pointAABB(mx, my, windowMinX, windowMinY, windowMaxX, windowMaxY)

    if inAABB then
        if Imgui.IsMouseDragging(Imgui.ImGuiMouseButton_Left) then
            local dragDelta = Imgui.GetMouseDragDelta(Imgui.ImGuiMouseButton_Left, 0.0)

            local aX = mx - dragDelta.x
            local aY = my - dragDelta.y

            local bX = mx
            local bY = my

            local startX = math.min(aX, bX)
            local startY = math.min(aY, bY)

            local endX = math.max(aX, bX)
            local endY = math.max(aY, bY)

            local startXLocal, startYLocal = inverseTransformPoint(startX, startY)
            local endXLocal, endYLocal = inverseTransformPoint(endX, endY)

            local range = frameXEnd - frameXStart
            local offset = -frameXStart

            local frameStart, frameEnd

            if floor then
                frameStart = math.floor((startXLocal + offset) / range * frameCount)
                frameEnd = math.floor((endXLocal + offset) / range * frameCount)
            else
                frameStart = math.floor((startXLocal + offset) / range * frameCount + 0.5)
                frameEnd = math.floor((endXLocal + offset) / range * frameCount + 0.5)
            end

            selectedFrameRange[1] = clamp(frameStart, 0, frameCount - 1)
            selectedFrameRange[2] = clamp(frameEnd, 0, frameCount - 1)
        elseif love.mouse.isDown(1) then
            selectedFrameRange[1] = -1
            selectedFrameRange[2] = -1
        end
    end

    if previousStart ~= selectedFrameRange[1]
        or previousEnd ~= selectedFrameRange[2] then
        UpdateSelectionStatistics()
    end

    previousStart = selectedFrameRange[1]
    previousEnd = selectedFrameRange[2]
end

local viewingFrame = 0
local font = love.graphics.getFont()

local tooltipItem = nil
local frametimeInfo = {
    drawFrameInfo = 0,
    drawFrameGraph = 0,
    drawFrameList = 0,
}

local frameListCanvas
local frameGraphCanvas
local frameTimelineCanvas
local eventCounts = {}
local depthIndices = {}

local function frac(x)
    return x - math.floor(x)
end

local function drawFrame(index, width, height, key)
    local time = love.timer.getTime()
    local frame = Frames[index]

    if not frame then
        frametimeInfo.drawFrameInfo = love.timer.getTime() - time
        return
    end

    local groupIdxWithKey

    for groupIdx, group in ipairs(Groups) do
        if group.name == key then
            groupIdxWithKey = groupIdx
            break
        end
    end

    assert(groupIdxWithKey, "No group with name '" .. tostring(key) .. "' found")

    local frameStartValue = frame[1].data[groupIdxWithKey].start
    local frameEndValue = frame[#frame].data[groupIdxWithKey].stop

    local frameDifference = frameEndValue - frameStartValue

    frameDifference = math.abs(frameDifference)
    local noDifference = frameDifference == 0

    local offset = -frameStartValue
    local scale = width / frameDifference
    local depth = 0
    local maxDepthReached = 0
    local itemHeight = 22

    local mx, my = love.mouse.getPosition()

    width = math.max(width, 64)
    height = math.max(height, 64)

    if not frameTimelineCanvas
        or frameTimelineCanvas:getWidth() ~= width
        or frameTimelineCanvas:getHeight() ~= height then
        frameTimelineCanvas = love.graphics.newCanvas(width, height)
    end

    love.graphics.setCanvas(frameTimelineCanvas)
    love.graphics.clear(0, 0, 0, 0)

    for i = 1, 64 do
        depthIndices[i] = 0
    end

    local stack = {}

    for i, event in ipairs(frame) do
        if event.type == "push" then
            event.childCount = 0
            if #stack > 0 then
                stack[#stack].childCount = stack[#stack].childCount + 1
                event.parent = stack[#stack]
            end
            table.insert(stack, event)
        else
            table.remove(stack)
        end
    end

    depth = 0

    local screenMinX, screenMinY = transformPoint(0, 0)
    local screenMaxX, screenMaxY = transformPoint(0 + width, 0 + height)

    if love.mouse.isDown(1) and pointAABB(mx, my, screenMinX, screenMinY, screenMaxX, screenMaxY) then
        selectedEvent = nil
    end

    for i, event in ipairs(frame) do
        local eventData = event.data[groupIdxWithKey]
        local groupDescription = Groups[groupIdxWithKey]

        if event.type == "push" then
            depth = depth + 1
            maxDepthReached = math.max(maxDepthReached, depth)
            depthIndices[depth] = depthIndices[depth] + 1
        else
            depthIndices[depth + 1] = 0 -- reset for next use
            depth = math.max(0, depth - 1)

            goto continue
        end

        local x, w

        if noDifference then
            local widthAvailable = event.parent and event.parent.width or width
            local eventOffset = event.parent and event.parent.x or 0

            x = eventOffset + (depthIndices[depth] - 1) / (event.parent and event.parent.childCount or 1) *
                widthAvailable
            w = widthAvailable / (event.parent and event.parent.childCount or 1)

            event.width = w
            event.x = x
        else
            x = math.abs(eventData.start + offset) * scale
            w = math.abs(eventData.stop - eventData.start) * scale
        end

        local y = (depth - 1) * (itemHeight + 4)

        x = math.floor(x)
        y = math.floor(y)
        w = math.ceil(w + frac(x))

        love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
        if selectedEvent and event.name == selectedEvent.name then
            love.graphics.setColor(highlightColor)
        end
        love.graphics.rectangle("fill", x, y, w, itemHeight, 3, nil, 5)
        love.graphics.setColor(1, 1, 1, 0.5)
        if selectedEvent and event.name == selectedEvent.name then
            love.graphics.setColor(highlightColor)
        end
        love.graphics.rectangle("line", x, y, w, itemHeight, 3, nil, 5)

        local screenMinX, screenMinY = transformPoint(x, y)
        local screenMaxX, screenMaxY = transformPoint(x + w, y + itemHeight)

        love.graphics.setScissor(x, y, w, itemHeight)

        love.graphics.setColor(1, 1, 1)

        love.graphics.print(event.name .. " " .. formatFor(eventData.stop - eventData.start, groupDescription.type),
            x + 2, y + 2)

        love.graphics.setScissor()

        if pointAABB(mx, my, screenMinX, screenMinY, screenMaxX, screenMaxY) then
            tooltipItem = event.name .. "\n"

            for groupIdx, group in ipairs(event.data) do
                local gInfo = Groups[groupIdx]
                tooltipItem = tooltipItem .. string.format("%s: %s\n", gInfo.name,
                    "Delta:" .. formatFor(group.stop - group.start, gInfo.type))
            end

            if love.mouse.isDown(1) then
                selectedEvent = event
            end
        end

        ::continue::
    end

    frametimeInfo.drawFrameInfo = love.timer.getTime() - time

    love.graphics.setCanvas()

    return maxDepthReached * (itemHeight + 4)
end

local strings = {}

local function drawGroupInfo()
    if Imgui.Begin("Groups") then
        Imgui.Text("Groups:")
        table.clear(strings)
        local longestStringLength = 0

        for groupIdx, group in ipairs(Groups) do
            local str = string.format("%d. %s (%s)", groupIdx, group.name, group.type)
            table.insert(strings, str)
            longestStringLength = math.max(longestStringLength, #str)
        end

        for groupIdx, group in ipairs(Groups) do
            Imgui.Text(strings[groupIdx] .. string.rep(".", longestStringLength - #strings[groupIdx]))
            Imgui.SameLine()
            Imgui.ColorEdit4("Color##" .. groupIdx, group.color,
                Imgui.ImGuiColorEditFlags_NoInputs + Imgui.ImGuiColorEditFlags_NoLabel)
            Imgui.SameLine()
            Imgui.Checkbox("##Hide" .. groupIdx, group.hidden)

            group.workingColor[1] = group.color[0]
            group.workingColor[2] = group.color[1]
            group.workingColor[3] = group.color[2]
            group.workingColor[4] = group.color[3]
        end
    end
    Imgui.End()
end

local frameInfoCache = {}

local function getFrameInfo(frame)
    if frameInfoCache[frame] then
        return frameInfoCache[frame]
    end

    local firstEvent = frame[1]
    local lastEvent = frame[#frame]
    if firstEvent and lastEvent then
        local groupInfo = {}
        for groupIdx, group in ipairs(Groups) do
            local start = firstEvent.data[groupIdx].start
            local stop = lastEvent.data[groupIdx].stop
            local difference = stop - start
            local min = math.min(start, stop)
            local max = math.max(start, stop)

            groupInfo[group.name] = {
                difference = difference,
                min = min,
                max = max,
                valid = min ~= -math.huge
            }
        end

        local info = {
            eventCount = #frame,
            groupInfo = groupInfo,
        }

        frameInfoCache[frame] = info

        return info
    end
end

local function drawFrameList(width, height)
    local itemWidth = width / #Frames

    if not frameListCanvas
        or frameListCanvas:getWidth() ~= width
        or frameListCanvas:getHeight() ~= height then
        frameListCanvas = love.graphics.newCanvas(width, height)
    end

    love.graphics.setCanvas(frameListCanvas)
    love.graphics.clear(0, 0, 0, 0)

    local mx, my = love.mouse.getPosition()

    for i = 0, #Frames - 1, FrameIterationStep do
        local x = itemWidth * i

        local minScreenX, minScreenY = transformPoint(x, 0)
        local maxScreenX, maxScreenY = transformPoint(x + itemWidth * FrameIterationStep, height)

        local hovered = pointAABB(mx, my, minScreenX, minScreenY, maxScreenX, maxScreenY)

        if (i >= selectedFrameRange[1] and i <= selectedFrameRange[2]) then
            love.graphics.setColor(0.4, 0.4, 0.9, 0.4)
            love.graphics.rectangle("fill", x, 0, itemWidth * FrameIterationStep, height)
        elseif hovered then
            love.graphics.setColor(0.6, 0.6, 0.6, 0.8)
            love.graphics.rectangle("fill", x, 2, itemWidth * FrameIterationStep, height - 4)
        else
            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
            love.graphics.rectangle("fill", x, 2, itemWidth * FrameIterationStep, height - 4)
        end

        local info = assert(getFrameInfo(Frames[i]))

        if hovered then
            if love.mouse.isDown(1) then
                viewingFrame = i
            end
            tooltipItem = "Frame " .. i .. " (" .. #Frames[i] .. " events)\n"

            for groupIdx, group in ipairs(Groups) do
                local gInfo = info.groupInfo[group.name]
                tooltipItem = tooltipItem .. string.format("%s: %s; %s\n", group.name,
                    formatFor(Frames[i][#Frames[i]].data[groupIdx].stop, group.type),
                    "Delta:" .. (gInfo.valid and formatFor(gInfo.difference, group.type) or "N/A"))
            end
        end
    end

    handleDrag(0, width, #Frames, true)

    -- draw viewed frame highlight
    do
        local x = itemWidth * viewingFrame
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.rectangle("line", x, 0, itemWidth * FrameIterationStep, height)
    end

    love.graphics.setCanvas()
end

local function drawFrameGraph(width, height)
    local time = love.timer.getTime()

    local itemWidth = (width / #Frames)

    width = math.max(width, 64)
    height = math.max(height, 64)

    if not frameGraphCanvas
        or frameGraphCanvas:getWidth() ~= width
        or frameGraphCanvas:getHeight() ~= height then
        frameGraphCanvas = love.graphics.newCanvas(width, height)
    end

    love.graphics.setCanvas(frameGraphCanvas)
    love.graphics.clear(0, 0, 0, 0)

    for groupIdx, group in ipairs(Groups) do
        last[group.name] = 0
    end

    frametimeInfo.drawFrameList = love.timer.getTime() - time
    time = love.timer.getTime()

    for i = 0, #Frames - 1, FrameIterationStep do
        local x = itemWidth * i

        local firstEvent = Frames[i][1]
        local lastEvent = Frames[i][#Frames[i]]

        for groupIdx, group in ipairs(Groups) do
            local value = lastEvent.data[groupIdx].stop

            if group.type == "time" then
                value = value - firstEvent.data[groupIdx].start
            end

            local range = viewRanges[group.name]
            local y = (value + range.offset) * range.scale * height
            local y2 = (last[group.name] + range.offset) * range.scale * height

            love.graphics.setColor(group.workingColor[1], group.workingColor[2], group.workingColor[3],
                group.workingColor[4] * (group.hidden[0] and hiddenGroupColorScale or 1))
            love.graphics.line(x, height - y, x - itemWidth * FrameIterationStep, height - y2)

            last[group.name] = value
        end
    end

    handleDrag(0, width, #Frames, false)

    local mx, my = inverseTransformPoint(love.mouse.getPosition())

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.line(0, 0, width, 0)
    love.graphics.line(0, height, width, height)
    love.graphics.line(mx, 0, mx, height)

    local frameIndexAtCursor = math.floor(mx / itemWidth + 0.5)
    local frameAtCursor = Frames[frameIndexAtCursor]

    if frameAtCursor then
        local info = getFrameInfo(frameAtCursor)
        if pointAABB(mx, my, 0, 0, width, height) then
            tooltipItem = "Frame " .. frameIndexAtCursor .. " (" .. info.eventCount .. " events)\n"

            for groupIdx, group in ipairs(Groups) do
                local gInfo = info.groupInfo[group.name]
                tooltipItem = tooltipItem ..
                    string.format("%s: %s; %s\n", group.name,
                        formatFor(frameAtCursor[#frameAtCursor].data[groupIdx].stop, group.type),
                        "Delta:" .. (gInfo.valid and formatFor(gInfo.difference, group.type) or "N/A"))
            end

            if love.mouse.isDown(1) then
                viewingFrame = frameIndexAtCursor
            end
        end
    end

    if selectedFrameRange[2] > 0 then
        local xStart = itemWidth * (selectedFrameRange[1] - 0.5)
        local xEnd = itemWidth * (selectedFrameRange[2] + 0.5)

        love.graphics.setColor(0.4, 0.4, 0.9, 0.4)
        love.graphics.rectangle("fill", xStart, 0, xEnd - xStart, height)
    end

    frametimeInfo.drawFrameGraph = love.timer.getTime() - time

    love.graphics.setCanvas()
end

local function drawEventInfo(upTo)
    if selectedFrameRange[2] <= 0 then
        Imgui.Text("Total events: " .. #Events)
        Imgui.Text("Total frames: " .. #Frames)

        if not SummaryMode then
            if Imgui.BeginCombo("Sort by", sortByString) then
                for groupIdx, group in ipairs(Groups) do
                    if Imgui.Selectable_Bool(group.name, sortByString == group.name) then
                        sortByString = group.name
                    end
                end
                if Imgui.Selectable_Bool("Count", sortByString == "count") then
                    sortByString = "count"
                end

                Imgui.EndCombo()
            end

            Imgui.SeparatorText("Events:")
        else -- Summary mode, give info about average frametime etc
            Imgui.NewLine()

            Imgui.Text("Average frame time: " ..
                Stringh.formatTime(TotalFrameTime / #Frames))

            Imgui.Separator()
        end
    else
        local from = selectedFrameRange[1]
        local to = selectedFrameRange[2]
        local count = to - from + 1
        local name = count == 1 and "frame" or "frames"

        Imgui.Text(string.format("Selected frames: %d - %d (%d %s)", from, to, count, name))
        Imgui.Text(string.format("Total events in selection: %d", selectionTotalEventCount))

        if Imgui.BeginCombo("Sort by", sortByString) then
            for groupIdx, group in ipairs(Groups) do
                if Imgui.Selectable_Bool(group.name, sortByString == group.name) then
                    sortByString = group.name
                end
            end

            Imgui.EndCombo()
        end

        Imgui.SeparatorText("Events in selection:")
    end

    if sortByString == "count" then
        for i, eventInfo in ipairs(Sorted[sortByString]) do
            if selectedEvent and eventInfo.name == selectedEvent.name then
                Imgui.TextColored(
                    Imgui.ImVec4_Float(highlightColor[1], highlightColor[2], highlightColor[3], highlightColor[4]),
                    string.format("%d. %s - %d calls", i, eventInfo.name, eventInfo.count))
            elseif eventInfo.count > 0 then
                Imgui.Text(string.format("%d. %s - %d calls", i, eventInfo.name, eventInfo.count))
            else
                Imgui.TextDisabled(string.format("%d. %s - %d calls", i, eventInfo.name, eventInfo.count))
            end
        end
    else
        local type = Groups[GroupNameToIndex[sortByString]].type
        for i, eventInfo in ipairs(Sorted[sortByString]) do
            if i > upTo and upTo > 0 then
                break
            end

            if selectedEvent and eventInfo.name == selectedEvent.name then
                Imgui.TextColored(
                    Imgui.ImVec4_Float(highlightColor[1], highlightColor[2], highlightColor[3], highlightColor[4]),
                    string.format("%d. %s - %s (%d calls)", i, eventInfo.name,
                        formatFor(eventInfo.total, type),
                        eventInfo.count))
            elseif eventInfo.total > 0.00001 then
                Imgui.Text(string.format("%d. %s - %s (%d calls)", i, eventInfo.name,
                    formatFor(eventInfo.total, type),
                    eventInfo.count))
            else
                Imgui.TextDisabled(string.format("%d. %s - %s (%d calls)", i, eventInfo.name,
                    formatFor(eventInfo.total, type),
                    eventInfo.count))
            end
        end
    end
end

local function drawTooltipItem()
    if tooltipItem then
        local mx, my = love.mouse.getPosition()

        local padding = 5
        local offsetX = 15
        local offsetY = 0

        local width = font:getWidth(tooltipItem) + padding * 2
        local height = font:getHeight() * (countNewlines(tooltipItem) + 1) + padding * 2

        local screenWidth, screenHeight = love.graphics.getDimensions()

        local rectMinX = mx + offsetX
        local rectMinY = my + offsetY
        local rectMaxX = rectMinX + width
        local rectMaxY = rectMinY + height

        if rectMaxX > screenWidth then
            local diff = rectMaxX - screenWidth
            offsetX = offsetX - diff
            rectMinX = mx + offsetX
            rectMaxX = rectMinX + width
        end

        if rectMaxY > screenHeight then
            local diff = rectMaxY - screenHeight
            offsetY = offsetY - diff
            rectMinY = my + offsetY
            rectMaxY = rectMinY + height
        end

        rectMinX = math.floor(rectMinX + 0.5)
        rectMinY = math.floor(rectMinY + 0.5)

        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.rectangle("fill", rectMinX, rectMinY, width, height, 6, 6, 8)

        love.graphics.setColor(0.05, 0.05, 0.05, 1)
        love.graphics.print(tooltipItem, rectMinX + padding, rectMinY + padding)
    end
end

local flags = Imgui.love.WindowFlags("NoTitleBar", "NoMove", "NoResize",
    "NoCollapse", "NoSavedSettings", "NoFocusOnAppearing", "NoBringToFrontOnFocus", "NoScrollbar")

local regionAvailable = Imgui.ImVec2_Float(0, 0)



local frameIdx = 0
function love.draw()
    Imgui.love.Update(love.timer.getDelta())
    Imgui.NewFrame()

    FrameIterationStep = math.floor(#Frames / love.graphics.getWidth()) + 1

    tooltipItem = nil

    if Imgui.Begin("DockSpace", nil, flags) then
        Imgui.SetWindowPos_Vec2(Imgui.ImVec2_Float(0, 0))
        Imgui.SetWindowSize_Vec2(Imgui.ImVec2_Float(love.graphics.getDimensions()))
        Imgui.SetCursorScreenPos(Imgui.ImVec2_Float(0, 0))
        Imgui.DockSpace(1, Imgui.ImVec2_Float(love.graphics.getDimensions()),
            bit.bor(Imgui.ImGuiDockNodeFlags_AutoHideTabBar))
    end
    Imgui.End()

    if not SummaryMode then
        if Imgui.Begin("Frame Timeline") then
            Imgui.GetContentRegionAvail(regionAvailable)

            if Imgui.BeginCombo("Key to graph", keyToGraph) then
                for groupIdx, group in ipairs(Groups) do
                    if Imgui.Selectable_Bool(group.name, keyToGraph == group.name) then
                        keyToGraph = group.name
                    end
                end

                Imgui.EndCombo()
            end

            Imgui.Separator()

            ---@diagnostic disable-next-line: undefined-field
            drawFrame(viewingFrame, regionAvailable.x, regionAvailable.y, keyToGraph)

            Imgui.Image(frameTimelineCanvas, regionAvailable)
        end
        Imgui.End()

        if Imgui.Begin("Frame List") then
            local frameIndexAsInt = ffi.new("int[1]", viewingFrame)
            if Imgui.DragInt("Viewing Frame", frameIndexAsInt, 1, 0, #Frames - 1) then
                viewingFrame = clamp(frameIndexAsInt[0], 0, #Frames - 1)
            end

            if Imgui.BeginChild_Str("Frame list") then
                Imgui.GetContentRegionAvail(regionAvailable)

                ---@diagnostic disable-next-line: undefined-field
                drawFrameList(regionAvailable.x, regionAvailable.y)

                Imgui.Image(frameListCanvas, regionAvailable)
            end
            Imgui.EndChild()
        end
        Imgui.End()
    end

    if Imgui.Begin("Frame Graph") then
        Imgui.GetContentRegionAvail(regionAvailable)
        ---@diagnostic disable-next-line: undefined-field
        local width, height = regionAvailable.x, regionAvailable.y

        local legendTextWidth = 65

        drawFrameGraph(width - legendTextWidth * #Groups, height)

        Imgui.Image(frameGraphCanvas,
            Imgui.ImVec2_Float(regionAvailable.x - legendTextWidth * #Groups, regionAvailable.y))

        Imgui.SameLine(0)

        for _, group in ipairs(Groups) do
            local range = viewRanges[group.name]

            Imgui.BeginGroup()
            local pos = Imgui.GetCursorScreenPos()
            local x, y = pos.x, pos.y

            Imgui.GetWindowDrawList():AddLine(
                Imgui.ImVec2_Float(x, y),
                Imgui.ImVec2_Float(x, y + height),
                Imgui.ColorConvertFloat4ToU32(Imgui.ImVec4_Float(
                    group.workingColor[1],
                    group.workingColor[2],
                    group.workingColor[3],
                    group.workingColor[4] * (group.hidden[0] and hiddenGroupColorScale or 1)
                )),
                2.0
            )

            local legendHeight = height - Imgui.GetTextLineHeight()

            for i = 0, 8 do
                local t = i / 8
                local yPos = y + legendHeight - t * legendHeight

                local valueAtT = t / range.scale - range.offset
                local label = formatFor(valueAtT, group.type)

                Imgui.SetCursorScreenPos(Imgui.ImVec2_Float(x + 4, yPos))
                Imgui.Text(label)
            end

            Imgui.SetCursorScreenPos(pos)
            Imgui.Dummy(Imgui.ImVec2_Float(legendTextWidth, height))

            Imgui.EndGroup()
            Imgui.SameLine(0, 0)
        end
    end
    Imgui.End()

    if Imgui.Begin("Events Summary") then
        drawEventInfo(SummaryMode and 20 or 0)
    end
    Imgui.End()

    love.graphics.setColor(1, 1, 1)

    if not SummaryMode then
        drawGroupInfo()
    end

    Imgui.Render()
    Imgui.love.RenderDrawLists()

    -- drawProfilerDebugInfo()
    if not SummaryMode then
        drawTooltipItem()
    end

    frameIdx = frameIdx + 1
    if SummaryMode and frameIdx == 2 then
        love.graphics.captureScreenshot("graphics_screenshot.png")
        love.event.quit()
    end
end

love.keyboard.setTextInput(true)

function love.textinput(text)
    Imgui.love.TextInput(text)
end

function love.resize()
end

function love.mousepressed(x, y, button)
    Imgui.love.MousePressed(button)
end

function love.keypressed(key, scancode, isrepeat)
    Imgui.love.KeyPressed(key)
end

function love.keyreleased(key)
    Imgui.love.KeyReleased(key)
end

function love.mousereleased(x, y, button)
    Imgui.love.MouseReleased(button)
end

function love.mousemoved(x, y, dx, dy)
    Imgui.love.MouseMoved(x, y)
end

function love.wheelmoved(x, y)
    Imgui.love.WheelMoved(x, y)
end
