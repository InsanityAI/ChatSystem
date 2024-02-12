if Debug then Debug.beginFile "ChatSystem.UI.ChatUI" end
OnInit.module("ChatSystem.UI.ChatUI", function(require)
    require "ChatSystem.ChatService"
    require "TimerQueue"

    local localUITimer = TimerQueue.create()

    local MAX_MESSAGES = 1000

    -- Frame position (scales with resolution)
    local CHAT_REFPOINT = FRAMEPOINT_BOTTOMLEFT -- from which point of screen the X and Y calculate
    local CHAT_X = 0.0222
    local CHAT_Y = 0.2106
    local CHAT_FONT = "Fonts\\BLQ55Web.ttf" -- font used by messages (default wc3 chat font is "Fonts\\BLQ55Web.ttf")
    local FONT_SIZE = 0.012                 -- font size of messages

    local MESSAGE_DURATION = 500            -- Message disappears after X ms

    local frameMain = nil ---@type framehandle
    local frameMessagePanel = nil ---@type framehandle
    local frameMessage = {} ---@type framehandle[]
    local frameMessageType = {} ---@type framehandle[]
    local frameMessageTimeStamp = {} ---@type framehandle[]
    local frameMessageIcon = {} ---@type framehandle[]
    local frameMessageText = {} ---@type framehandle[]

    local frameMessageTimeStampContainer = {} ---@type framehandle[]
    local frameMessageIconContainer = {} ---@type framehandle[]
    local frameMessageTextContainer = {} ---@type framehandle[]

    local startY = {} ---@type number[]
    local currentY = {} ---@type number[]
    local targetY = {} ---@type number[]
    local asyncVisibility = {} ---@type boolean[]
    local timeSinceStart = {} ---@type number[]
    local frameInUse = {} ---@type boolean[]
    local frameAlpha = {} ---@type number[]
    local previousFrame = {} ---@type number[]
    local messageDurations = {} ---@type number[]

    ---@class ChatUI: ChatServiceListener
    ---@field frames framehandle[]
    ChatUI = {}

    local iterator = 1


    ---@param t number
    ---@return number
    local function easeInOutSine(t)
        return -(Cos(bj_PI * t) - 1.) / 2.
    end

    ---@param current integer
    local function hideMessage(current)
        local prev = previousFrame[iterator] -- async
        local duration = messageDurations[iterator] + 1

        messageDurations[iterator] = duration
        if asyncVisibility[current] then -- following stuff is all async, and only happens if player was meant to see the message
            if (prev == 0 or not frameInUse[prev] or currentY[prev] >= FONT_SIZE + 0.005) and frameAlpha[current] < 0 then
                BlzFrameSetPoint(frameMessage[current], FRAMEPOINT_BOTTOMLEFT, frameMessagePanel, FRAMEPOINT_BOTTOMLEFT,
                    0., 0.)
                frameAlpha[current] = 0
            end
            if frameAlpha[current] >= 0 and frameAlpha[current] < 255 and duration < MESSAGE_DURATION then
                frameAlpha[current] = frameAlpha[current] + 3
                BlzFrameSetAlpha(frameMessage[current], frameAlpha[current])
            elseif duration > MESSAGE_DURATION and frameAlpha[current] > 0 then
                frameAlpha[current] = frameAlpha[current] - 3
                BlzFrameSetAlpha(frameMessage[current], frameAlpha[current])
            end
            if targetY[current] > currentY[current] and frameAlpha[current] >= 0 then
                timeSinceStart[current] = timeSinceStart[current] + 1
                if timeSinceStart[current] < 20 then
                    currentY[current] = startY[current] +
                        (targetY[current] - startY[current]) * easeInOutSine(timeSinceStart[current] / 20.)
                else
                    currentY[current] = targetY[current]
                end
                BlzFrameSetPoint(frameMessage[current], FRAMEPOINT_BOTTOMLEFT, frameMessagePanel, FRAMEPOINT_BOTTOMLEFT,
                    0., currentY[current])
            end
        end

        if duration > MESSAGE_DURATION + 100 then
            frameInUse[current] = false
            asyncVisibility[current] = false
            BlzFrameSetVisible(frameMessage[current], false)
            currentY[current] = 0.
            frameAlpha[current] = -1
            timeSinceStart[current] = 0
        end
    end

    local tempPrev = nil ---@type integer

    ---@param timestamp string
    ---@param from ChatProfile
    ---@param message string
    ---@param messagetype string
    function ChatUI.newMessage(timestamp, from, message, messagetype)
        while not frameInUse[iterator] do
            if iterator > MAX_MESSAGES then
                iterator = 1
            else
                iterator = iterator + 1
            end
        end

        --call BJDebugMsg("Expected Time: " + I2S(time))
        --call BJDebugMsg("Expected Type: " + messagetype)
        --call BJDebugMsg("Expected Icon: " + messageIcon)
        --call BJDebugMsg("Expected Content: " + message)
        --call BJDebugMsg("Expected Receivers: " + I2S(receivers))

        -- no reason to do these async, since only frameMessage visiblity matters
        BlzFrameSetText(frameMessageType[iterator], messagetype)
        BlzFrameSetText(frameMessageTimeStamp[iterator], timestamp)
        if from.name == nil then
            BlzFrameSetText(frameMessageText[iterator], message)
        else
            BlzFrameSetText(frameMessageText[iterator], from.name .. "|r:" .. message)
        end

        if from.icon ~= nil and from.icon ~= "" then
            BlzFrameSetTexture(frameMessageIcon[iterator], from.icon, 0, true)
            BlzFrameSetVisible(frameMessageIconContainer[iterator], true)
            BlzFrameSetPoint(frameMessageTextContainer[iterator], FRAMEPOINT_LEFT, frameMessageIconContainer[iterator],
                FRAMEPOINT_RIGHT, 0.003, 0.)
        else
            BlzFrameSetVisible(frameMessageIconContainer[iterator], false)
            BlzFrameSetPoint(frameMessageTextContainer[iterator], FRAMEPOINT_LEFT,
                frameMessageTimeStampContainer[iterator], FRAMEPOINT_RIGHT, 0.003, 0.)
        end

        BlzFrameSetVisible(frameMessage[iterator], true)
        asyncVisibility[iterator] = true   -- async
        previousFrame[iterator] = tempPrev -- async
        local prev = tempPrev                    -- local async
        tempPrev = iterator                -- async
        local current = iterator                 -- local async
        while prev ~= 0 do
            if prev == current then
                previousFrame[current] = 0                        -- async
                prev = 0                                          -- local async
            elseif frameInUse[prev] and asyncVisibility[prev] then
                targetY[prev] = targetY[prev] + FONT_SIZE + 0.005 -- async
                startY[prev] = currentY[prev]                     -- async
                timeSinceStart[prev] = 0                          -- async
                current = prev                                    -- local async
                prev = previousFrame[current]                     -- local async
            else
                prev = 0                                          -- local async
            end
        end


        frameInUse[iterator] = true
        messageDurations[iterator] = 0
        localUITimer:callDelayed(0.01, hideMessage, iterator)
    end

    ---@param createContext integer
    local function generateMessageFrame(createContext)
        frameMessage[createContext] = BlzCreateSimpleFrame("Message", frameMessagePanel, createContext)
        BlzFrameSetSize(frameMessage[createContext], 0.8, FONT_SIZE + 0.005)

        BlzFrameSetSize(BlzGetFrameByName("Message Type Container", createContext), 0.045, FONT_SIZE + 0.005)
        frameMessageType[createContext] = BlzGetFrameByName("Message Type", createContext)
        BlzFrameSetSize(frameMessageType[createContext], 0.045, FONT_SIZE + 0.005)
        BlzFrameSetFont(frameMessageType[createContext], CHAT_FONT, FONT_SIZE, 0)

        frameMessageTimeStampContainer[createContext] = BlzGetFrameByName("Message Timestamp Container", createContext)
        BlzFrameSetSize(frameMessageTimeStampContainer[createContext], 0.045, FONT_SIZE + 0.005)
        frameMessageTimeStamp[createContext] = BlzGetFrameByName("Message Timestamp", createContext)
        BlzFrameSetSize(frameMessageTimeStamp[createContext], 0.045, FONT_SIZE + 0.005)
        BlzFrameSetFont(frameMessageTimeStamp[createContext], CHAT_FONT, FONT_SIZE, 0)

        frameMessageIconContainer[createContext] = BlzGetFrameByName("Message Icon Container", createContext)
        BlzFrameSetSize(frameMessageIconContainer[createContext], FONT_SIZE + 0.005, FONT_SIZE + 0.005)
        frameMessageIcon[createContext] = BlzGetFrameByName("Message Icon", createContext)
        frameMessageTextContainer[createContext] = BlzGetFrameByName("Message Text Container", createContext)
        BlzFrameSetSize(frameMessageTextContainer[createContext], 0.675, FONT_SIZE + 0.005)
        frameMessageText[createContext] = BlzGetFrameByName("Message Text", createContext)
        BlzFrameSetSize(frameMessageText[createContext], 0.675, FONT_SIZE + 0.005)
        BlzFrameSetFont(frameMessageText[createContext], CHAT_FONT, FONT_SIZE, 0)

        BlzFrameSetVisible(frameMessage[createContext], false)
        BlzFrameSetAlpha(frameMessage[createContext], 0)

        frameInUse[createContext] = false
        startY[createContext] = 0.
        currentY[createContext] = 0.
        targetY[createContext] = 0.
        frameAlpha[createContext] = -1
        timeSinceStart[createContext] = 0
        asyncVisibility[createContext] = false
        previousFrame[createContext] = 0
    end

    ---@return framehandle?
    local function safe_get_frame(name, pos)
        local frame = BlzGetFrameByName(name, pos)
        if frame == nil then
            Location(0, 0) --Intentionally leak a handle because someone does not have this frame
            --This should help prevent desyncs and replay errors
        end
        return frame
    end

    OnInit.map(function()
        BlzLoadTOCFile("UI\\ChatSystem.toc")                                   -- Try to load ChatSystem.toc, otherwise don't init system
        BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_CHAT_MSG, 0), false) -- hides default chat

        frameMain = BlzCreateSimpleFrame("Main", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), 0)
        frameMessagePanel = safe_get_frame("Message Panel", 0) --[[@as framehandle]]
        for i = 1, MAX_MESSAGES do
            generateMessageFrame(i)
        end


        BlzFrameSetAbsPoint(frameMain, FRAMEPOINT_BOTTOM, 0.4, 0.)
        BlzFrameSetPoint(frameMessagePanel, CHAT_REFPOINT, frameMain, CHAT_REFPOINT, CHAT_X, CHAT_Y)
    end)
end)
if Debug then Debug.endFile() end
