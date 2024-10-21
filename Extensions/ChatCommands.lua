if Debug then Debug.beginFile "ChatSystem/Extensions/ChatCommands" end
OnInit.module("ChatSystem/Extensions/ChatCommands", function(require)
    require "SyncedTable"
    require "StringInterpolation"
    require "ChatSystem/ChatService"
    require "ChatSystem/API"

    COMMAND_PREFIX = "-"

    ---@class ChatCommand
    ---@field name string
    ---@field minimumArgC integer
    ---@field func fun(chatEvent: ChatEvent, ...: string)
    ---@field showInHelp boolean?
    ---@field helpArgs string[]?
    ---@field helpDescription string?

    local commands = SyncedTable.create() ---@type table<string, ChatCommand>
    local commandPrefixLength = string.len(COMMAND_PREFIX)

    ---@class ChatCommands: ChatServiceListener
    ChatCommands = {}

    ---@param name string
    ---@param argC integer
    ---@param func fun(chatEvent: ChatEvent, ...: string)
    ---@param showInHelp boolean?
    ---@param helpArgs string[]?
    ---@param helpDescription string?
    function ChatCommands.registerCommand(name, argC, func, showInHelp, helpArgs, helpDescription)
        commands[name] = { name = name, minimumArgC = argC, func = func, showInHelp = showInHelp, helpArgs = helpArgs, helpDescription = helpDescription }
    end

    ---@param name string
    function ChatCommands.unregisterCommand(name)
        commands[name] = nil
    end

    local command ---@type string
    local commandParts ---@type fun():string
    local chatCommand ---@type ChatCommand

    ---@param chatEvent ChatEvent
    function ChatCommands.newMessage(chatEvent)
        if chatEvent.from == ChatService.getSystemProfile() then -- ignore system messages
            return
        end

        if string.sub(chatEvent.message, 1, commandPrefixLength) ~= COMMAND_PREFIX then
            return
        end

        commandParts = string.gmatch(string.sub(chatEvent.message, commandPrefixLength + 1), "\x25S+")
        command = commandParts()

        if not command then
            return
        end
        chatEvent.displaySetting = ChatDisplaySetting.SENDER_ONLY
        chatEvent.to = ChatService.getSystemProfile()

        chatCommand = commands[command]
        if not chatCommand then
            ChatService.systemMessage("|cFFFF0000Error: Unknown command!|r", chatEvent.from)
            return
        end

        local params = {}
        local count = 0
        for param in commandParts do
            table.insert(params, param)
            count = count + 1
        end

        if count < chatCommand.minimumArgC then
            ChatService.systemMessage("|cFFFF0000Error: Insufficient arguments for this|r " .. chatCommand.name .. "|cFFFF0000command!|r", chatEvent.from)
            return
        end

        chatCommand.func(chatEvent, table.unpack(params))
    end

    ---@param chatEvent ChatEvent
    ChatCommands.registerCommand("help", 0, function(chatEvent)
        ChatService.systemMessage("Here's the list of chat commands you can use:", chatEvent.from)
        for _, thisCommand in pairs(commands) do
            if thisCommand.showInHelp then
                ChatService.systemMessage(interp(COMMAND_PREFIX .. "\x25(name)s", thisCommand), chatEvent.from)
                if thisCommand.helpDescription then
                    ChatService.systemMessage("\t" .. thisCommand.helpDescription, chatEvent.from)
                end
                if thisCommand.helpArgs then
                    for _, arg in ipairs(thisCommand.helpArgs) do
                        ChatService.systemMessage("\t- " .. arg, chatEvent.from)
                    end
                end
            end
        end
    end)
end)
if Debug then Debug.endFile() end
