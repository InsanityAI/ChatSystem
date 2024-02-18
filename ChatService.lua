if Debug then Debug.beginFile "ChatSystem/ChatService" end
OnInit.module("ChatSystem/ChatService", function(require)
    require "ChatSystem/Data/ChatProfiles"
    require "ChatSystem/Data/ChatGroups"
    require "TimerQueue"
    require "SetUtils"
    require "StringInterpolation"
    require "TableRecycler"

    ---@class ChatServiceListener
    ---@field newMessage fun(timestamp: string, from: ChatProfile, message: string, messagetype: string)

    local privateMessageFromPrefixPattern ---@type string
    local privateMessageToPrefixPattern ---@type string
    local stopwatch = Stopwatch.create(true)

    ---@class ChatService
    ---@field listeners ChatServiceListener[]
    ChatService = { listeners = {}}

    ---@param timeFormatted string
    ---@param from ChatProfile
    ---@param messageType string
    ---@param message string
    ---@param receiver player
    local function showMessageForPlayer(timeFormatted, from, messageType, message, receiver)
        if receiver == GetLocalPlayer() then
            for _, chatListener in ipairs(ChatService.listeners) do
                chatListener.newMessage(timeFormatted, from, message, messageType)
            end
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

    -- HELPER METHODS

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
        local time = convertTime(Stopwatch:getElapsed())
        from = type(from) ~= 'table' and ChatProfiles:get(from --[[@as player]]) or from --[[@as ChatProfile]]
        recepient = type(recepient) ~= 'table' and ChatProfiles:get(recepient --[[@as player]]) or recepient --[[@as ChatProfile]]
        local interpParams = TableRecycler.create()
        interpParams.fromPlayer = from.name
        interpParams.toPlayer = recepient.name
        showMessageForPlayer(time, from, interp(privateMessageFromPrefixPattern, interpParams), message, recepient.player)
        if recepient.player ~= from.player then -- avoid sending itself messages
            showMessageForPlayer(time, from, interp(privateMessageToPrefixPattern, interpParams), message, from.player)
        end
    end

    ---@param from ChatProfile|player|string
    ---@param message string
    ---@param group ChatGroup
    function ChatService.sendMessageToChatGroup(from, message, group)
        tempTime = convertTime(stopwatch:getElapsed())
        tempMessage = message
        tempSender = type(from) ~= 'table' and ChatProfiles:get(from --[[@as player|string]]) or from --[[@as ChatProfile]]
        tempGroup = group
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

    return ChatService
end)
if Debug then Debug.endFile() end
