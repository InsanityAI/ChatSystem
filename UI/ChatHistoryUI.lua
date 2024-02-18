if Debug then Debug.beginFile "ChatSystem/UI/ChatHistoryUI" end
OnInit.module("ChatSystem/UI/ChatHistoryUI", function(require)
    local frameChatHistory = nil ---@type framehandle

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
        safe_get_frame("ChatHistoryDisplay", 0)
        frameChatHistory = safe_get_frame("ChatHistoryDisplay", 0) --[[@as framehandle]]
        if frameChatHistory == nil then
            print("Singleplayer detected, normal chat messages are disabled. (Commands will remain working)")
        else
            print("Multiplayer detected, normal chat messages and commands will work as intended")
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
