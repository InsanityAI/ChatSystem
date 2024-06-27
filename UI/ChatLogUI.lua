if Debug then Debug.beginFile "ChatSystem/UI/ChatLogUI" end
OnInit.module("ChatSystem/UI/ChatLogUI", function(require)

    ---@class ChatLogUI: ChatServiceUIListener
    ChatLogUI = {}

    -- Note that this is called from a GetLocalPlayer() block, so be aware of what you're doing.
    ---@param timestamp string formatted time in represent [minutes: seconds]
    ---@param from ChatProfile sender of message
    ---@param message string message text
    ---@param messageType string formatted text that represent on which channel/group it was sent, or to which player if private chat.
    function ChatLogUI.newMessage(timestamp, from, message, messageType)
        -- to be implemented
    end

    -- In case someone gets around to implementing chat channel selection, make sure to use PlayerSelectedChatGroup
    -- That's where ChatSystem pulls to which channel a message should be sent
    -- care with Allies chat channel, as by default it's called "team1", "team2", ... for each allied group, so it's
    -- required to resolve that in here: perhaps with ChatGroups:contains(profile)?

    -- old code below, can be yeeted for all I care - Insanity_AI
    local frameChatHistory = nil ---@type framehandle

    ---@return framehandle
    local function safe_get_frame(name, pos)
        local frame = BlzGetFrameByName(name, pos)
        if frame == nil then
            Location(0, 0) --Intentionally leak a handle because someone does not have this frame
            --This should help prevent desyncs and replay errors
        end
        return frame --[[@as framehandle]]
    end

    OnInit.map(function()
        safe_get_frame("ChatHistoryDisplay", 0)
        frameChatHistory = safe_get_frame("ChatHistoryDisplay", 0) --[[@as framehandle]]
        if frameChatHistory then
            BlzFrameSetText(frameChatHistory, "")
            -- hide observer chat radio button cause it cause desyncs
            BlzFrameSetVisible(safe_get_frame("ChatObserversRadioButton", 0), false)
            BlzFrameSetEnable(safe_get_frame("ChatObserversRadioButton", 0), false)
            BlzFrameSetVisible(safe_get_frame("ChatObserversLabel", 0), false)
            -- move everyone button where observer chat would normally be
            BlzFrameSetPoint(safe_get_frame("ChatEveryoneRadioButton", 0), FRAMEPOINT_TOP,
                safe_get_frame("ChatAlliesRadioButton", 0), FRAMEPOINT_BOTTOM, 0., -0.002)
        end
    end)
end)
if Debug then Debug.endFile() end
