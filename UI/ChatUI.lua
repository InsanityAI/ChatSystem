if Debug then Debug.beginFile "ChatSystem/UI/ChatUI" end
OnInit.global("ChatSystem/UI/ChatUI", function(require)
    require "TimerQueue"
    require "ApplyOverTime"

    local localUITimer = TimerQueue.create()
    local localAOT = ApplyOverTime.create(localUITimer)

    -- Frame position (scales with resolution)
    local CHAT_REFPOINT = FRAMEPOINT_BOTTOMLEFT -- from which point of screen the X and Y calculate
    local CHAT_X = 0.0222
    local CHAT_Y = 0.2106
    local MAX_MESSAGES = 60

    local privateMessageReceiverFormat = "[From \x25s]:"
    local privateMessageSenderFormat = "[To \x25s]:"
    local groupNameMessageFormat = "[\x25s]"
    local groupMessageFormat = "\x25s|r: \x25s"

    local MESSAGE_RENDER_PERIOD = 0.01      -- Period at which messages render
    local MESSAGE_DURATION = 8.00           -- Timed life for message frame
    local MESSAGE_FADE_DURATION = 0.85
    local MESSAGE_ANIMATE_UP_DURATION = 0.2 -- over which period does the message frame go up to make room for a new message

    local frameMain
    local frameMessagePanel
    local originalChat

    ---@class ChatUI: ChatServiceUIListener
    ---@field frames framehandle[]
    ChatUI = {}

    ---@param t number
    ---@return number
    local function easeInOutSine(t)
        return -(Cos(bj_PI * t) - 1.) / 2.
    end

    ---@class MessageFrame
    ---@field frame framehandle
    ---@field frameTimeStamp framehandle
    ---@field frameType framehandle
    ---@field frameIcon framehandle
    ---@field frameIconContainer framehandle
    ---@field frameText framehandle
    ---@field relativeFrame MessageFrame?
    MessageFrame = {}
    MessageFrame.__index = MessageFrame
    MessageFrame.__name = "MessageFrame"

    ---@param createContext integer
    ---@return MessageFrame
    function MessageFrame.create(createContext)
        local o = setmetatable({
            frame = BlzCreateSimpleFrame("Message", frameMessagePanel, createContext),
            frameTimeStamp = BlzGetFrameByName("Message Timestamp", createContext),
            frameType = BlzGetFrameByName("Message Type", createContext),
            frameIconContainer = BlzGetFrameByName("Message Icon Container", createContext),
            frameIcon = BlzGetFrameByName("Message Icon", createContext),
            frameText = BlzGetFrameByName("Message Text", createContext)
        }, MessageFrame)
        BlzFrameSetAlpha(o.frame, 0)
        return o
    end

    ---@param timestamp string
    ---@param msgType string
    ---@param text string
    ---@param icon string
    function MessageFrame:setContent(timestamp, msgType, text, icon)
        BlzFrameSetText(self.frameTimeStamp, timestamp)
        BlzFrameSetText(self.frameType, msgType)
        BlzFrameSetText(self.frameText, text)

        if icon ~= nil and icon ~= "" then
            BlzFrameSetTexture(self.frameIcon, icon, 0, true)
            BlzFrameSetVisible(self.frameIconContainer, true)
            BlzFrameSetPoint(self.frameText, FRAMEPOINT_LEFT, self.frameIconContainer, FRAMEPOINT_RIGHT, 0.003, 0.)
        else
            BlzFrameSetVisible(self.frameIconContainer, false)
            BlzFrameSetPoint(self.frameText, FRAMEPOINT_LEFT, self.frameTimeStamp, FRAMEPOINT_RIGHT, 0.003, 0.)
        end
    end

    ---@param show boolean
    function MessageFrame:setVisibility(show)
        BlzFrameSetVisible(self.frame, show)
        if not show then
            BlzFrameSetAlpha(self.frame, 0)
        end
    end

    local newestFrame, oldestFrame ---@type MessageFrame?, MessageFrame?
    local framesUnused = {} ---@type table<MessageFrame, boolean>

    ---@param frame MessageFrame
    local function deallocateMessageFrame(frame)
        assert(frame ~= nil, "Cannot deallocate message frame nil!")
        -- frame:setVisibility(false)
        framesUnused[frame] = true
        if newestFrame == frame then
            newestFrame = nil
        end

        if oldestFrame == frame then
            oldestFrame = oldestFrame --[[@as MessageFrame]].relativeFrame -- oldestFrame == frame therefore it cannot be nil
        end
        frame.relativeFrame = nil
        BlzFrameSetPoint(frame.frame, FRAMEPOINT_BOTTOMLEFT, frameMessagePanel, FRAMEPOINT_BOTTOMLEFT, 0, 0)
    end

    ---@return MessageFrame
    local function allocateNewMessageFrame()
        local frame = next(framesUnused)
        if not frame then
            frame = oldestFrame --[[@as MessageFrame]] -- if there's no unused frames, means they're all used, which means oldestFrame exists
            deallocateMessageFrame(oldestFrame --[[@as MessageFrame]])
        end
        framesUnused[frame] = nil
        frame:setVisibility(true)
        newestFrame = frame
        if not oldestFrame then
            oldestFrame = frame
        end
        return frame
    end

    ---@param newMessageFrame MessageFrame
    ---@param previousFrame MessageFrame?
    local function renderNewMessage(newMessageFrame, previousFrame)
        if previousFrame then
            previousFrame.relativeFrame = newMessageFrame
            BlzFrameClearAllPoints(previousFrame.frame)
            localAOT:Builder()
                :addStaticParam(previousFrame.frame)
                :addStaticParam(FRAMEPOINT_BOTTOMLEFT)
                :addStaticParam(newMessageFrame.frame)
                :addStaticParam(FRAMEPOINT_TOPLEFT)
                :addStaticParam(0)
                :addVariable(-BlzFrameGetHeight(previousFrame.frame), 0, false, easeInOutSine)
                :execute(MESSAGE_ANIMATE_UP_DURATION, MESSAGE_RENDER_PERIOD, BlzFrameSetPoint)
        end

        localAOT:Builder()
            :addStaticParam(newMessageFrame.frame)
            :addVariable(0, 255, true)
            :execute(MESSAGE_FADE_DURATION, MESSAGE_RENDER_PERIOD, BlzFrameSetAlpha)

        localUITimer:callDelayed(MESSAGE_DURATION - MESSAGE_FADE_DURATION, function(frame)
            localAOT:Builder()
                :addStaticParam(frame.frame)
                :addVariable(255, 0, true)
                :execute(MESSAGE_FADE_DURATION, MESSAGE_RENDER_PERIOD, BlzFrameSetAlpha)
        end, newMessageFrame)

        localUITimer:callDelayed(MESSAGE_DURATION, deallocateMessageFrame, newMessageFrame)
    end

    ---@param timestamp string
    ---@param from ChatProfile
    ---@param message string
    ---@param groupName string
    function ChatUI.newMessage(timestamp, from, message, groupName)
        local previousFrame = newestFrame
        local newMessageFrame = allocateNewMessageFrame()

        newMessageFrame:setContent(timestamp, string.format(groupNameMessageFormat, groupName), string.format(groupMessageFormat, from.name, message), from.icon)
        renderNewMessage(newMessageFrame, previousFrame)
    end

    ---@param timestamp string
    ---@param contact ChatProfile
    ---@param message string
    ---@param isForSender boolean
    function ChatUI.newPrivateMessage(timestamp, contact, message, isForSender)
        local previousFrame = newestFrame
        local newMessageFrame = allocateNewMessageFrame()
        local pmFormat

        if isForSender then
            pmFormat = privateMessageSenderFormat
        else
            pmFormat = privateMessageReceiverFormat
        end

        newMessageFrame:setContent(timestamp, string.format(pmFormat, contact.name), message, contact.icon)
        renderNewMessage(newMessageFrame, previousFrame)
    end

    ---@param name string
    ---@param pos integer
    ---@return framehandle
    local function safe_get_frame(name, pos)
        local frame = BlzGetFrameByName(name, pos)
        if frame == nil then
            Location(0, 0) --Intentionally leak a handle because someone does not have this frame
            --This should help prevent desyncs and replay errors
        end
        return frame --[[@as framehandle]]
    end

    function ChatUI.refreshChat()
        BlzFrameSetVisible(originalChat, false) --hides default chat
        BlzFrameSetAbsPoint(frameMain, FRAMEPOINT_BOTTOM, 0.4, 0.)
        BlzFrameSetPoint(frameMessagePanel, CHAT_REFPOINT, frameMain, CHAT_REFPOINT, CHAT_X, CHAT_Y)
        BlzFrameSetSize(frameMain, 0.6 * BlzGetLocalClientWidth() / BlzGetLocalClientHeight(), 0.6)
    end

    OnInit.final(function()
        BlzLoadTOCFile("UI\\ChatSystem.toc")
        originalChat = BlzGetOriginFrame(ORIGIN_FRAME_CHAT_MSG, 0)

        frameMain = BlzCreateSimpleFrame("Main", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), 0)
        frameMessagePanel = safe_get_frame("Message Panel", 0)

        for i = 1, MAX_MESSAGES do
            deallocateMessageFrame(MessageFrame.create(i))
        end

        ChatUI.refreshChat()
    end)
end)
if Debug then Debug.endFile() end
