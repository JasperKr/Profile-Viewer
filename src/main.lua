local ffi = require("ffi")
local bit = require("bit")

Stringh = require("stringHelpers")

require("imguiLoader")
require("guiStyle")
table.clear = require("table.clear")
table.new = require("table.new")

require("load")
require("postProcess")

local screenPos = Imgui.ImVec2_Float(0, 0)
local function transformPoint(x, y)
    Imgui.GetCursorScreenPos(screenPos)

    return screenPos.x + x, screenPos.y + y
end
local function inverseTransformPoint(x, y)
    Imgui.GetCursorScreenPos(screenPos)

    return x - screenPos.x, y - screenPos.y
end

local function countNewlines(str)
    local count = 0
    for _ in str:gmatch("\n") do
        count = count + 1
    end
    return count
end

local selectedFrameRange = { -1, -1 }

local windowPos = Imgui.ImVec2_Nil()
local windowSize = Imgui.ImVec2_Nil()

local function pointAABB(x, y, minX, minY, maxX, maxY)
    return x >= minX and x <= maxX and y >= minY and y <= maxY
        and y >= minY and y <= maxY
end

local selectionEventInfoByName = {}
local selectedSortedEventTimes = {}
local selectedSortedEventGarbages = {}
local selectionTotalEventCount = 0
local eventInfoCache = {}

local function clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

local function updateSelectionStatistics()
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
                    duration = 0,
                    count = 0,
                    garbage = 0,
                }

                eventInfo = selectionEventInfoByName[name]
            end

            eventInfo.duration =
                eventInfo.duration + event.duration

            eventInfo.garbage =
                eventInfo.garbage + event.garbage

            eventInfo.count =
                eventInfo.count + 1

            selectionTotalEventCount = selectionTotalEventCount + 1
        end
    end

    for i, info in ipairs(selectedSortedEventTimes) do table.insert(eventInfoCache, info) end
    for i, info in ipairs(selectedSortedEventGarbages) do table.insert(eventInfoCache, info) end

    table.clear(selectedSortedEventTimes)
    table.clear(selectedSortedEventGarbages)

    for name, total in pairs(selectionEventInfoByName) do
        local info0 = table.remove(eventInfoCache) or {}
        info0.name = name
        info0.total = total.duration
        info0.count = total.count

        local info1 = table.remove(eventInfoCache) or {}
        info1.name = name
        info1.total = total.garbage
        info1.count = total.count

        table.insert(selectedSortedEventTimes, info0)
        table.insert(selectedSortedEventGarbages, info1)
    end

    table.sort(selectedSortedEventTimes, function(a, b) return a.total > b.total end)
    table.sort(selectedSortedEventGarbages, function(a, b) return a.total > b.total end)
end

local function handleDrag(frameXStart, frameXEnd, frameCount, floor)
    local mx, my = love.mouse.getPosition()

    Imgui.GetWindowPos(windowPos)
    Imgui.GetWindowSize(windowSize)

    local windowMinX = windowPos.x
    local windowMinY = windowPos.y
    local windowMaxX = windowPos.x + windowSize.x
    local windowMaxY = windowPos.y + windowSize.y

    if pointAABB(mx, my, windowMinX, windowMinY, windowMaxX, windowMaxY)
        and Imgui.IsMouseDragging(Imgui.ImGuiMouseButton_Left) then
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

        local previousStart = selectedFrameRange[1]
        local previousEnd = selectedFrameRange[2]

        selectedFrameRange[1] = clamp(frameStart, 0, frameCount - 1)
        selectedFrameRange[2] = clamp(frameEnd, 0, frameCount - 1)

        if previousStart ~= selectedFrameRange[1]
            or previousEnd ~= selectedFrameRange[2] then
            updateSelectionStatistics()
        end
    end
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

local function drawFrame(index, width, height)
    local time = love.timer.getTime()
    local frame = Frames[index]

    if not frame then
        frametimeInfo.drawFrameInfo = love.timer.getTime() - time
        return
    end

    local frameStartTime = frame[1].start
    local frameEndTime = frame[#frame].stop
    local frameDuration = frameEndTime - frameStartTime

    local offset = -frameStartTime
    local scale = width / frameDuration
    local depth = 0
    local maxDepthReached = 0
    local itemHeight = 22

    local mx, my = love.mouse.getPosition()

    if not frameTimelineCanvas
        or frameTimelineCanvas:getWidth() ~= width
        or frameTimelineCanvas:getHeight() ~= height then
        frameTimelineCanvas = love.graphics.newCanvas(width, height)
    end

    love.graphics.setCanvas(frameTimelineCanvas)
    love.graphics.clear(0, 0, 0, 0)

    for i, event in ipairs(frame) do
        local x = (event.start + offset) * scale
        local y = depth * (itemHeight + 4)
        local w = event.duration * scale

        if event.type == "push" then
            depth = depth + 1
            maxDepthReached = math.max(maxDepthReached, depth)
        else
            depth = math.max(0, depth - 1)

            goto continue
        end

        love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
        love.graphics.rectangle("fill", x, y, w, itemHeight)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("line", x, y, w, itemHeight)

        local screenMinX, screenMinY = transformPoint(x, y)
        local screenMaxX, screenMaxY = transformPoint(x + w, y + itemHeight)

        love.graphics.setScissor(x, y, w, itemHeight)

        love.graphics.setColor(1, 1, 1)
        love.graphics.print(event.name .. " " .. Stringh.formatTime(event.duration), x + 2, y + 2)

        love.graphics.setScissor()

        if pointAABB(mx, my, screenMinX, screenMinY, screenMaxX, screenMaxY) then
            tooltipItem = event.name .. "\n" ..
                "Duration: " .. Stringh.formatTime(event.duration) .. "\n" ..
                "Start: " .. Stringh.formatTime(event.start) .. "\n" ..
                "Stop: " .. Stringh.formatTime(event.stop) .. "\n" ..
                "Garbage: " .. (event.garbage > 0 and (Stringh.formatBytes(event.garbage * 1024, false)) or "N/A")
        end

        ::continue::
    end

    frametimeInfo.drawFrameInfo = love.timer.getTime() - time

    love.graphics.setCanvas()

    return maxDepthReached * (itemHeight + 4)
end

local frameInfoCache = {}

local function getFrameInfo(frame)
    if frameInfoCache[frame] then
        return frameInfoCache[frame]
    end

    local firstEvent = frame[1]
    local lastEvent = frame[#frame]
    if firstEvent and lastEvent then
        local duration = lastEvent.stop - firstEvent.start

        local minGarbage = math.huge
        local maxGarbage = 0
        local invalidGarbage = false

        if firstEvent.garbageStart > 0 and firstEvent.garbageEnd > 0 then
            minGarbage = math.min(minGarbage, firstEvent.garbageStart, firstEvent.garbageEnd)
            maxGarbage = math.max(maxGarbage, firstEvent.garbageStart, firstEvent.garbageEnd)
        else
            invalidGarbage = true
        end

        if lastEvent.garbageStart > 0 and lastEvent.garbageEnd > 0 then
            minGarbage = math.min(minGarbage, lastEvent.garbageStart, lastEvent.garbageEnd)
            maxGarbage = math.max(maxGarbage, lastEvent.garbageStart, lastEvent.garbageEnd)
        else
            invalidGarbage = true
        end

        local info = {
            eventCount = #frame,
            duration = duration,
            garbageAtEnd = lastEvent.garbageEnd,
            minGarbage = minGarbage,
            maxGarbage = maxGarbage,
            validGarbage = not invalidGarbage,
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

    local minGarbage = math.huge
    local maxGarbage = -math.huge
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

        local duration = info.duration

        if info.validGarbage then
            minGarbage = math.min(minGarbage, info.minGarbage)
            maxGarbage = math.max(maxGarbage, info.maxGarbage)
        end

        if hovered then
            if love.mouse.isDown(1) then
                viewingFrame = i
            end
            tooltipItem = "Frame " .. i .. " (" .. #Frames[i] .. " events)\n" ..
                "Duration: " .. Stringh.formatTime(info.duration) .. "\n" ..
                "Garbage: " .. Stringh.formatBytes(info.garbageAtEnd * 1024, false)
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

    return minGarbage, maxGarbage
end

local function drawFrameGraph(minGarbage, maxGarbage, width, height)
    local time = love.timer.getTime()

    local itemWidth = (width / #Frames)

    if not frameGraphCanvas
        or frameGraphCanvas:getWidth() ~= width
        or frameGraphCanvas:getHeight() ~= height then
        frameGraphCanvas = love.graphics.newCanvas(width, height)
    end

    love.graphics.setCanvas(frameGraphCanvas)
    love.graphics.clear(0, 0, 0, 0)

    local garbageOffset = -minGarbage
    local garbageScale = height / (maxGarbage - minGarbage)

    local timeOffset = -GraphTimeMin
    local timeScale = height / (GraphTimeMax - GraphTimeMin)

    local lastGarbage = -1
    local lastTime = -1

    frametimeInfo.drawFrameList = love.timer.getTime() - time
    time = love.timer.getTime()

    for i = 0, #Frames - 1, FrameIterationStep do
        local x = itemWidth * i

        local firstEvent = Frames[i][1]
        local lastEvent = Frames[i][#Frames[i]]
        local garbage = lastEvent.garbageEnd

        local startTime = firstEvent.start
        local stopTime = lastEvent.stop
        local duration = stopTime - startTime

        if garbage <= 0 or lastGarbage <= 0 then
            goto continue
        end

        do
            local y = (garbage + garbageOffset) * garbageScale
            local x2 = x - itemWidth * FrameIterationStep
            local y2 = (lastGarbage + garbageOffset) * garbageScale

            love.graphics.setColor(0.2, 0.6, 0.9, 0.6)
            love.graphics.line(x, height - y, x2, height - y2)

            love.graphics.setColor(0.9, 0.6, 0.1, 0.6)

            y = (clamp(duration, GraphTimeMin, GraphTimeMax) + timeOffset) * timeScale
            x2 = x - itemWidth * FrameIterationStep
            y2 = (clamp(lastTime, GraphTimeMin, GraphTimeMax) + timeOffset) * timeScale

            love.graphics.line(x, height - y, x2, height - y2)
        end

        ::continue::

        lastGarbage = garbage
        lastTime = duration
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
            tooltipItem = string.format(
                "Frame %d (%d events)\nDuration: %s\nGarbage: %s",
                frameIndexAtCursor,
                info.eventCount,
                Stringh.formatTime(info.duration),
                (info.validGarbage and (Stringh.formatBytes(info.garbageAtEnd, false)) or "N/A")
            )

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

local function drawEventTimingInfo()
    if selectedFrameRange[2] <= 0 then
        Imgui.Text("Total events: " .. #Events)
        Imgui.Text("Total frames: " .. #Frames)
        Imgui.SeparatorText("Event times:")

        for i, eventInfo in ipairs(SortedEventTimes) do
            Imgui.Text(string.format("%d. %s - %s (%d calls)", i, eventInfo.name, Stringh.formatTime(eventInfo.total),
                eventInfo.count))
        end
    else
        local from = selectedFrameRange[1]
        local to = selectedFrameRange[2]
        local count = to - from + 1
        local name = count == 1 and "frame" or "frames"

        Imgui.Text(string.format("Selected frames: %d - %d (%d %s)", from, to, count, name))
        Imgui.Text(string.format("Total events in selection: %d", selectionTotalEventCount))
        Imgui.SeparatorText("Event times in selection:")
        for i, eventInfo in ipairs(selectedSortedEventTimes) do
            Imgui.Text(string.format("%d. %s - %s (%d calls)", i, eventInfo.name, Stringh.formatTime(eventInfo.total),
                eventInfo.count))
        end
    end
end

local function drawEventGarbageInfo()
    if selectedFrameRange[2] <= 0 then
        Imgui.SeparatorText("Event garbage:")

        for i, eventInfo in ipairs(SortedEventGarbages) do
            Imgui.Text(string.format("%d. %s - %s (%d calls)", i, eventInfo.name,
                Stringh.formatBytes(eventInfo.total * 1024, false),
                eventInfo.count))
        end
    else
        Imgui.SeparatorText("Event garbage in selection:")
        for i, eventInfo in ipairs(selectedSortedEventGarbages) do
            Imgui.Text(string.format("%d. %s - %s (%d calls)", i, eventInfo.name,
                Stringh.formatBytes(eventInfo.total * 1024, false),
                eventInfo.count))
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

        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.rectangle("fill", mx + offsetX, my + offsetY, width, height, 6, 6, 8)

        love.graphics.setColor(0.05, 0.05, 0.05, 1)
        love.graphics.print(tooltipItem, mx + offsetX + padding, my + offsetY + padding)
    end
end

local function drawProfilerDebugInfo()
    love.graphics.setColor(0.9, 0.9, 0.9)
    do -- frametime info of the profiler itself
        local w, h = love.graphics.getDimensions()
        local height = 100
        local width = 200

        love.graphics.rectangle("fill", 5, h - 5 - height, width, height, 6, 6, 8)
        love.graphics.setColor(0.05, 0.05, 0.05, 1)
        love.graphics.print(
            string.format(
                "Profiler timings:\n" ..
                " drawFrameGraph: %s\n" ..
                " drawFrameList: %s\n" ..
                " drawFrameInfo: %s\n" ..
                " FPS: %.1f",
                Stringh.formatTime(frametimeInfo.drawFrameGraph),
                Stringh.formatTime(frametimeInfo.drawFrameList),
                Stringh.formatTime(frametimeInfo.drawFrameInfo),
                love.timer.getFPS()
            ),
            10, h - 5 - height + 10
        )
    end
end

local flags = Imgui.love.WindowFlags("NoTitleBar", "NoMove", "NoResize",
    "NoCollapse", "NoSavedSettings", "NoFocusOnAppearing", "NoBringToFrontOnFocus", "NoScrollbar")

local regionAvailable = Imgui.ImVec2_Float(0, 0)
local minGarbage, maxGarbage

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

    if Imgui.Begin("Frame Timeline") then
        Imgui.GetContentRegionAvail(regionAvailable)

        drawFrame(viewingFrame, regionAvailable.x, regionAvailable.y)

        Imgui.Image(frameTimelineCanvas, regionAvailable)
    end
    Imgui.End()

    if Imgui.Begin("Frame List") then
        local frameIndexAsInt = ffi.new("int[1]", viewingFrame)
        if Imgui.DragInt("Viewing Frame", frameIndexAsInt, 1) then
            viewingFrame = clamp(frameIndexAsInt[0], 0, #Frames - 1)
        end

        if Imgui.BeginChild_Str("Frame list") then
            Imgui.GetContentRegionAvail(regionAvailable)

            minGarbage, maxGarbage = drawFrameList(regionAvailable.x, regionAvailable.y)

            Imgui.Image(frameListCanvas, regionAvailable)
        end
        Imgui.EndChild()
    end
    Imgui.End()

    if Imgui.Begin("Frame Graph") then
        Imgui.GetContentRegionAvail(regionAvailable)

        drawFrameGraph(minGarbage, maxGarbage, regionAvailable.x, regionAvailable.y)

        Imgui.Image(frameGraphCanvas, regionAvailable)
    end
    Imgui.End()

    if Imgui.Begin("Event Timing Summary") then
        drawEventTimingInfo()
    end
    Imgui.End()

    if Imgui.Begin("Event Garbage Summary") then
        drawEventGarbageInfo()
    end
    Imgui.End()

    love.graphics.setColor(1, 1, 1)

    Imgui.Render()
    Imgui.love.RenderDrawLists()

    drawTooltipItem()
    drawProfilerDebugInfo()
end

love.keyboard.setTextInput(true)

function love.textinput(text)
    Imgui.love.TextInput(text)
end

function love.resize()
end

function love.mousepressed(x, y, button)
    selectedFrameRange[1] = -1
    selectedFrameRange[2] = -1
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
