if Debug then Debug.beginFile "ChatSystem/ChatService" end
OnInit.module("ChatSystem/ChatService", function(require)
    require "ChatSystem/Data/ChatProfiles"
    require "ChatSystem/Data/ChatGroups"
    require "TimerQueue"
    require "SyncedTable"
    require "SetUtils"
    require "StringInterpolation"
    require "TableRecycler"

    ---@class ChatServiceUIListener
    ---@field newMessage fun(timestamp: string, from: ChatProfile, message: string, messagetype: string)

    ---@class ChatServiceListener
    ---@field newMessage fun(time: integer, from: ChatProfile, to: ChatProfile|ChatGroup, message: string)

    local privateMessageFromPrefixPattern ---@type string
    local privateMessageToPrefixPattern ---@type string
    local stopwatch = Stopwatch.create(true)

    ---@class ChatService
    ---@field package uiListeners table<ChatServiceUIListener, boolean>
    ---@field package listeners table<ChatServiceListener, boolean>
    ChatService = {
        uiListeners = SyncedTable.create(),
        listeners = SyncedTable.create()
    }

    ---@param timeFormatted string
    ---@param from ChatProfile
    ---@param messageType string
    ---@param message string
    ---@param receiver player
    local function showMessageForPlayer(timeFormatted, from, messageType, message, receiver)
        if receiver == GetLocalPlayer() then
            for chatListener, _ in pairs(ChatService.uiListeners) do
                chatListener.newMessage(timeFormatted, from, message, messageType)
            end
        end
    end

    ---@param time integer
    ---@param from ChatProfile
    ---@param receiver ChatProfile|ChatGroup
    ---@param message string
    local function notifyListeners(time, from, receiver, message)
        for chatListener, _ in pairs(ChatService.listeners) do
            chatListener.newMessage(time, from, receiver, message)
        end
    end

    ---@param time number
    ---@return string timeFormatted [mm:ss]
    local function convertTime(time)
        local minutes = math.modf(time / 60) ---@type integer|string
        local seconds = I2S(math.modf(time - minutes * 60))
        minutes = I2S(minutes --[[@as integer]])

        local stringBuilder = TableRecycler.create()
        table.insert(stringBuilder, '[')
        if StringLength(minutes) < 2 then
            table.insert(stringBuilder, '0')
        end
        table.insert(stringBuilder, minutes)

        table.insert(stringBuilder, ':')

        if StringLength(seconds) < 2 then
            table.insert(stringBuilder, '0')
        end
        table.insert(stringBuilder, seconds)
        table.insert(stringBuilder, ']')

        local result = table.concat(stringBuilder, '')
        TableRecycler.release(stringBuilder)
        return result
    end

    -- temp variables

    local time = nil ---@type number
    local tempTime = nil ---@type string
    local tempMessage = nil ---@type string
    local tempSender = nil ---@type ChatProfile
    local tempGroup = nil ---@type ChatGroup

    ---@param member ChatProfile
    local function sendMessageToMember(member)
        showMessageForPlayer(tempTime, tempSender, tempGroup.name, tempMessage, member.player)
    end

    ---@param from ChatProfile|player|string
    ---@param message string
    ---@param recepient ChatProfile|player|string
    function ChatService.sendMessageToPlayer(from, message, recepient)
        time = stopwatch:getElapsed()
        from = type(from) ~= 'table' and ChatProfiles:get(from --[[@as player]]) or from --[[@as ChatProfile]]
        recepient = type(recepient) ~= 'table' and ChatProfiles:get(recepient --[[@as player]]) or
            recepient --[[@as ChatProfile]]
        notifyListeners(time, from, recepient, message)
        local interpParams = TableRecycler.create()
        interpParams.fromPlayer = from.name
        interpParams.toPlayer = recepient.name

        tempTime = convertTime(time)
        showMessageForPlayer(tempTime, from, interp(privateMessageFromPrefixPattern, interpParams), message,
            recepient.player)
        if recepient.player ~= from.player then -- avoid sending itself messages
            showMessageForPlayer(tempTime, from, interp(privateMessageToPrefixPattern, interpParams), message,
                from.player)
        end
    end

    ---@param from ChatProfile|player|string
    ---@param message string
    ---@param group ChatGroup
    function ChatService.sendMessageToChatGroup(from, message, group)
        time = stopwatch:getElapsed()
        tempTime = convertTime(time)
        tempMessage = message
        tempSender = type(from) ~= 'table' and ChatProfiles:get(from --[[@as player|string]]) or
            from --[[@as ChatProfile]]
        tempGroup = group
        notifyListeners(time, tempSender, tempGroup, message)
        tempGroup:forEachMember(sendMessageToMember)
        if not tempGroup.members[tempSender] then -- don't duplicate self-message if sender is in the group
            showMessageForPlayer(tempTime, tempSender, tempGroup.name, tempMessage, tempSender.player)
        end
    end

    ---@param fromPattern string
    ---@param toPattern string
    function ChatService.setPrivateMessagePrefixPatterns(fromPattern, toPattern)
        privateMessageFromPrefixPattern = fromPattern
        privateMessageToPrefixPattern = toPattern
    end

    --- Register UI listener that will show only relevant messages to LocalPlayer
    ---@param listener ChatServiceUIListener
    function ChatService.registerUIListener(listener)
        ChatService.uiListeners[listener] = true
    end

    ---@param listener ChatServiceUIListener
    function ChatService.unregisterUIListener(listener)
        ChatService.uiListeners[listener] = nil
    end

    -- Register listener to listen to all message traffic
    ---@param listener ChatServiceListener
    function ChatService.registerListener(listener)
        ChatService.listeners[listener] = true
    end

    ---@param listener ChatServiceListener
    function ChatService.unregisterListener(listener)
        ChatService.listeners[listener] = nil
    end

    return ChatService
end)
if Debug then Debug.endFile() end
