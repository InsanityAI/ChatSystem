if Debug then Debug.beginFile "ChatSystem/UI/ChatUI" end
OnInit.global("ChatSystem/UI/ChatUI", function(require)
    require "TimerQueue"
    require "ApplyOverTime"
    require "ChatSystem/UI/UIUtils"

    local localUITimer = TimerQueue.create()
    local localAOT = ApplyOverTime.create(localUITimer)

    -- Frame position (scales with resolution)
    local CHAT_REFPOINT = FRAMEPOINT_BOTTOMLEFT -- from which point of screen the X and Y calculate
    local CHAT_X = 0.0222
    local CHAT_Y = 0.2106
    local MAX_MESSAGES = 60

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

    ---@private
    ---@class ChatUIMessageFrame
    ---@field frame framehandle
    ---@field frameTimeStamp framehandle
    ---@field frameType framehandle
    ---@field frameIcon framehandle
    ---@field frameIconContainer framehandle
    ---@field frameText framehandle
    ---@field relativeFrame ChatUIMessageFrame?
    local ChatUIMessageFrame = {}
    ChatUIMessageFrame.__index = ChatUIMessageFrame
    ChatUIMessageFrame.__name = "ChatUIMessageFrame"

    ---@param createContext integer
    ---@return ChatUIMessageFrame
    function ChatUIMessageFrame.create(createContext)
        local o = setmetatable({
            frame = BlzCreateSimpleFrame("ChatSystem Message", frameMessagePanel, createContext),
            frameTimeStamp = BlzGetFrameByName("ChatSystem Message Timestamp", createContext),
            frameType = BlzGetFrameByName("ChatSystem Message Type", createContext),
            frameIconContainer = BlzGetFrameByName("ChatSystem Message Icon Container", createContext),
            frameIcon = BlzGetFrameByName("ChatSystem Message Icon", createContext),
            frameText = BlzGetFrameByName("ChatSystem Message Text", createContext)
        }, ChatUIMessageFrame)
        BlzFrameSetAlpha(o.frame, 0)
        return o
    end

    ---@param timestamp string
    ---@param msgType string
    ---@param text string
    ---@param icon string
    function ChatUIMessageFrame:setContent(timestamp, msgType, text, icon)
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
    function ChatUIMessageFrame:setVisibility(show)
        BlzFrameSetVisible(self.frame, show)
        if not show then
            BlzFrameSetAlpha(self.frame, 0)
        end
    end

    local newestFrame, oldestFrame ---@type ChatUIMessageFrame?, ChatUIMessageFrame?
    local framesUnused = {} ---@type table<ChatUIMessageFrame, boolean>

    ---@param frame ChatUIMessageFrame
    local function deallocateChatUIMessageFrame(frame)
        assert(frame ~= nil, "Cannot deallocate message frame nil!")
        frame:setVisibility(false)
        framesUnused[frame] = true
        if newestFrame == frame then
            newestFrame = nil
        end

        if oldestFrame == frame then
            oldestFrame = oldestFrame --[[@as ChatUIMessageFrame]].relativeFrame -- oldestFrame == frame therefore it cannot be nil
        end
        frame.relativeFrame = nil
        BlzFrameSetPoint(frame.frame, FRAMEPOINT_BOTTOMLEFT, frameMessagePanel, FRAMEPOINT_BOTTOMLEFT, 0, 0)
    end

    ---@return ChatUIMessageFrame
    local function allocateNewChatUIMessageFrame()
        local frame = next(framesUnused)
        if not frame then
            frame = oldestFrame --[[@as ChatUIMessageFrame]] -- if there's no unused frames, means they're all used, which means oldestFrame exists
            deallocateChatUIMessageFrame(oldestFrame --[[@as ChatUIMessageFrame]])
        end
        framesUnused[frame] = nil
        frame:setVisibility(true)
        newestFrame = frame
        if not oldestFrame then
            oldestFrame = frame
        end
        return frame
    end

    ---@param newChatUIMessageFrame ChatUIMessageFrame
    ---@param previousFrame ChatUIMessageFrame?
    local function renderNewMessage(newChatUIMessageFrame, previousFrame)
        if previousFrame then
            previousFrame.relativeFrame = newChatUIMessageFrame
            BlzFrameClearAllPoints(previousFrame.frame)
            localAOT:Builder()
                :addStaticParam(previousFrame.frame)
                :addStaticParam(FRAMEPOINT_BOTTOMLEFT)
                :addStaticParam(newChatUIMessageFrame.frame)
                :addStaticParam(FRAMEPOINT_TOPLEFT)
                :addStaticParam(0)
                :addVariable(-BlzFrameGetHeight(previousFrame.frame), 0, false, easeInOutSine)
                :execute(MESSAGE_ANIMATE_UP_DURATION, MESSAGE_RENDER_PERIOD, BlzFrameSetPoint)
        end

        localAOT:Builder()
            :addStaticParam(newChatUIMessageFrame.frame)
            :addVariable(0, 255, true)
            :execute(MESSAGE_FADE_DURATION, MESSAGE_RENDER_PERIOD, BlzFrameSetAlpha)

        localUITimer:callDelayed(MESSAGE_DURATION - MESSAGE_FADE_DURATION, function(frame)
            localAOT:Builder()
                :addStaticParam(frame.frame)
                :addVariable(255, 0, true)
                :execute(MESSAGE_FADE_DURATION, MESSAGE_RENDER_PERIOD, BlzFrameSetAlpha)
        end, newChatUIMessageFrame)

        localUITimer:callDelayed(MESSAGE_DURATION, deallocateChatUIMessageFrame, newChatUIMessageFrame)
    end

    ---@param timestamp string
    ---@param from ChatProfile
    ---@param message string
    ---@param groupName string
    function ChatUI.newMessage(timestamp, from, message, groupName)
        local previousFrame = newestFrame
        local newChatUIMessageFrame = allocateNewChatUIMessageFrame()

        newChatUIMessageFrame:setContent(timestamp, string.format(groupNameMessageFormat, groupName), string.format(groupMessageFormat, from.name, message), from.icon)
        renderNewMessage(newChatUIMessageFrame, previousFrame)
    end

    ---@param timestamp string
    ---@param contact ChatProfile
    ---@param message string
    ---@param isForSender boolean
    function ChatUI.newPrivateMessage(timestamp, contact, message, isForSender)
        local previousFrame = newestFrame
        local newChatUIMessageFrame = allocateNewChatUIMessageFrame()
        local msgType

        if isForSender then
            msgType = "[To "
        else
            msgType = "[From "
        end

        newChatUIMessageFrame:setContent(timestamp, msgType, contact.name .. "]: " .. message, contact.icon)
        renderNewMessage(newChatUIMessageFrame, previousFrame)
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

        frameMain = BlzCreateFrameByType("SIMPLEFRAME", "ChatSystemMain", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), "", 0)
        BlzFrameSetSize(frameMain, 0.8, 0.6)

        frameMessagePanel = BlzCreateFrameByType("SIMPLEFRAME", "ChatSystemMsgPanel", frameMain, "", 0)
        BlzFrameSetSize(frameMessagePanel, 0.8, 0.013)

        for i = 1, MAX_MESSAGES do
            deallocateChatUIMessageFrame(ChatUIMessageFrame.create(i))
        end

        ChatUI.refreshChat()
    end)
end)
if Debug then Debug.endFile() end
