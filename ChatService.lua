if Debug then Debug.beginFile "ChatSystem/ChatService" end
OnInit.module("ChatSystem/ChatService", function(require)
    require "ChatSystem/Data/ChatProfiles"
    require "ChatSystem/Data/ChatGroups"
    require "ChatSystem/API"
    require "TimerQueue"
    require "SyncedTable"
    require "SetUtils"
    require "StringInterpolation"
    require "TableRecycler"
    require "ProxyTable"

    local stopwatch = Stopwatch.create(true)

    local uiListeners = SyncedTable.create() ---@type table<ChatServiceUIListener, boolean>
    local listeners = SyncedTable.create() ---@type table<ChatServiceListener, boolean>

    ---@class ChatService
    ChatService = {
        disableUI = false,
        disableAll = false
    }

    local chatEventMetatable = {
        __name = "ChatEvent"
    }

    ---@param timeFormatted string
    ---@param contact ChatProfile
    ---@param message string
    ---@param isForSender boolean
    local function showPrivateMessageForLocalPlayer(timeFormatted, contact, message, isForSender)
        for chatListener, _ in pairs(uiListeners) do
            chatListener.newPrivateMessage(timeFormatted, contact, message, isForSender)
        end
    end

    ---@param timeFormatted string
    ---@param from ChatProfile
    ---@param groupName string
    ---@param message string
    local function showMessageForLocalPlayer(timeFormatted, from, groupName, message)
        for chatListener, _ in pairs(uiListeners) do
            chatListener.newMessage(timeFormatted, from, message, groupName)
        end
    end

    ---@param time number
    ---@return string "HH:MM:SS", where hours show only if a full hour has passed, otherwise it's "MM:SS" format
    local function convertTime(time)
        if (time / 3600) >= 1 then
            return os.date("!\x25H:\x25M:\x25S", time) --[[@as string]]
        else
            return os.date("!\x25M:\x25S", time) --[[@as string]]
        end
    end

    ---@param time integer
    ---@param from ChatProfile
    ---@param to ChatProfile|ChatGroup
    ---@param message string
    ---@return ChatEvent
    local function notifyListeners(time, from, to, message)
        time = math.modf(time)
        local event = ProxyTable(setmetatable({ ---@type ChatEvent
            displaySetting = ChatDisplaySetting.DEFAULT,
            time = time,
            timestamp = convertTime(time),
            from = from,
            to = to,
            message = message
        }, chatEventMetatable))
        for chatListener, _ in pairs(listeners) do
            chatListener.newMessage(event)
        end
        return event
    end

    -- temp variables
    local chatEvent = nil ---@type ChatEvent
    local localPlayer = nil ---@type player
    local showToLocal = nil ---@type boolean

    ---@param from ChatProfile|player|string
    ---@param message string
    ---@param recepient ChatGroup|ChatProfile|player|string
    function ChatService.sendMessage(from, message, recepient)
        if ChatService.disableAll then
            return
        end

        localPlayer = GetLocalPlayer()
        from = type(from) ~= 'table' and ChatProfiles:get(from --[[@as player]]) or from --[[@as ChatProfile]]
        recepient = type(recepient) ~= 'table' and ChatProfiles:get(recepient --[[@as player]]) or recepient --[[@as ChatProfile]]
        chatEvent = notifyListeners(stopwatch:getElapsed(), from, recepient, message)
        showToLocal = localPlayer == chatEvent.from.player

        if ChatService.disableUI then
            return
        end

        if chatEvent.displaySetting == ChatDisplaySetting.NONE then
            return
        elseif chatEvent.displaySetting == ChatDisplaySetting.DEFAULT then
            if chatEvent.to.members then
                for member, _ in pairs(chatEvent.to.members) do
                    showToLocal = showToLocal or member.player == localPlayer
                end
                if showToLocal then
                    showMessageForLocalPlayer(chatEvent.timestamp, chatEvent.from, chatEvent.to.name, chatEvent.message)
                end
            else
                if chatEvent.from.player == localPlayer then
                    showPrivateMessageForLocalPlayer(chatEvent.timestamp, chatEvent.to --[[@as ChatProfile]], chatEvent.message, true)
                elseif chatEvent.to.player == localPlayer then
                    showPrivateMessageForLocalPlayer(chatEvent.timestamp, chatEvent.from, chatEvent.message, false)
                end
            end
        elseif chatEvent.displaySetting == ChatDisplaySetting.SENDER_ONLY then
            if chatEvent.from.player == localPlayer then
                if chatEvent.to.members then
                    showMessageForLocalPlayer(chatEvent.timestamp, chatEvent.from, chatEvent.to.name, chatEvent.message)
                else
                    showPrivateMessageForLocalPlayer(chatEvent.timestamp, chatEvent.to --[[@as ChatProfile]], chatEvent.message, true)
                end
            end
        elseif chatEvent.displaySetting == ChatDisplaySetting.FORCE_ALL then
            showToLocal = true
            if chatEvent.to.members then
                showMessageForLocalPlayer(chatEvent.timestamp, chatEvent.from, chatEvent.to.name, chatEvent.message)
            else
                if chatEvent.from.player == localPlayer then
                    showPrivateMessageForLocalPlayer(chatEvent.timestamp, chatEvent.to --[[@as ChatProfile]], chatEvent.message, true)
                else
                    showPrivateMessageForLocalPlayer(chatEvent.timestamp, chatEvent.from, chatEvent.message, false)
                end
            end
        end
    end

    ---@param from ChatProfile|player|string
    ---@param message string
    ---@param group ChatGroup|string
    function ChatService.sendMessageToGroup(from, message, group)
        ChatService.sendMessage(from, message, type(group) ~= 'table' and ChatGroups:get(group --[[@as string]]) or group --[[@as ChatGroup]])
    end

    local system = ChatProfiles:get("System")
    local groupSys = ChatGroups:get("sys")
    groupSys.owner = system

    -- Send a system message through provided API via ChatSystem
    -- Has a 0-second delay in order to assure ChatListeners that may be using this don't send a system message before the message they're processing is shown
    ---@param message string
    ---@param recepient ChatGroup|ChatProfile|player|string? if nil, sends to system group, string type looks only through ChatProfiles, not ChatGroups
    function ChatService.systemMessage(message, recepient)
        TimerQueue:callDelayed(0.00, ChatService.sendMessage, system, message, recepient or groupSys)
    end

    function ChatService.errorMessage(message, recepient)
        ChatService.systemMessage("|cFFFF0000Error: " .. message .. "|r", recepient)
    end

    function ChatService.infoMessage(message, recepient)
        ChatService.systemMessage("|cFF00FFFFInfo: " .. message .. "|r", recepient)
    end

    function ChatService.getSystemProfile()
        return system
    end

    function ChatService.getSystemGroup()
        return groupSys
    end

    --- Register UI listener that will show only relevant messages to LocalPlayer
    ---@param listener ChatServiceUIListener
    function ChatService.registerUIListener(listener)
        uiListeners[listener] = true
    end

    ---@param listener ChatServiceUIListener
    function ChatService.unregisterUIListener(listener)
        uiListeners[listener] = nil
    end

    -- Register listener to listen to all message traffic
    ---@param listener ChatServiceListener
    function ChatService.registerListener(listener)
        listeners[listener] = true
    end

    ---@param listener ChatServiceListener
    function ChatService.unregisterListener(listener)
        listeners[listener] = nil
    end

    return ChatService
end)
if Debug then Debug.endFile() end
