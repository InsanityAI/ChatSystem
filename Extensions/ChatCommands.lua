if Debug then Debug.beginFile "ChatSystem/Extensions/ChatCommands" end
OnInit.module("ChatSystem/Extensions/ChatCommands", function(require)
    require "SyncedTable"
    require "StringInterpolation"
    require "ChatSystem/ChatService"
    require "ChatSystem/API"

    COMMAND_PREFIX = "-"
    HELP_COMMAND_LINES = 4

    ---@class ChatCommand
    ---@field name string
    ---@field argC integer
    ---@field minimumArgC integer
    ---@field func fun(chatEvent: ChatEvent, ...: string)
    ---@field help string[]?
    ---@field helpN integer
    ---@field defaultValues string[]

    do -- code block to collapse this BS
        ---@class ChatCommandBuilder
        ---@field package name string
        ---@field package desc string
        ---@field package arguments ChatCommandArgumentBuilder[]
        ---@field package showHelp boolean
        ---@field package func fun(chatEvent: ChatEvent, ...: string)
        ---@field private hasOptional boolean
        ChatCommandBuilder = {}
        ChatCommandBuilder.__index = ChatCommandBuilder

        ---@param name string
        ---@return ChatCommandBuilder
        function ChatCommandBuilder.create(name, func)
            return setmetatable({
                name = name,
                showHelp = false,
                func = func,
                arguments = {},
                hasOptional = false
            }, ChatCommandBuilder)
        end

        ---@return ChatCommandBuilder
        function ChatCommandBuilder:showInHelp()
            self.showHelp = true
            return self
        end

        ---@param description string
        ---@return ChatCommandBuilder
        function ChatCommandBuilder:description(description)
            self.desc = description
            return self
        end

        function ChatCommandBuilder:register()
            ChatCommands.registerCommand(self)
        end

        ---@class ChatCommandArgumentBuilder
        ---@field package name string
        ---@field package desc string
        ---@field package defaultVal string?
        ---@field private parent ChatCommandBuilder
        ChatCommandArgumentBuilder = {}
        ChatCommandArgumentBuilder.__index = ChatCommandArgumentBuilder

        ---@param name string
        ---@param defaultValue string?
        ---@return ChatCommandArgumentBuilder
        function ChatCommandBuilder:argument(name, defaultValue)
            if defaultValue == nil and self.hasOptional then
                error("Chat command cannot have non-optional arguments after an optional argument!")
            end
            local arg = setmetatable({
                name = name,
                parent = self,
                defaultVal = defaultValue
            }, ChatCommandArgumentBuilder)
            table.insert(self.arguments, arg)
            if defaultValue ~= nil then
                self.hasOptional = true
            end
            return arg
        end

        ---@param description string
        ---@return ChatCommandArgumentBuilder
        function ChatCommandArgumentBuilder:description(description)
            self.desc = description
            return self
        end

        function ChatCommandArgumentBuilder:register()
            self.parent:register()
        end

        ---@param name string
        ---@return ChatCommandArgumentBuilder
        function ChatCommandArgumentBuilder:argument(name)
            return self.parent:argument(name)
        end
    end

    local commands = SyncedTable.create() ---@type table<string, ChatCommand>
    local commandPrefixLength = string.len(COMMAND_PREFIX)
    local helpLines ---@type integer
    local helpPages ---@type {n: integer}|string[][]
    local helpInitialized = false

    local function initHelp()
        helpLines = 0
        helpPages = { n = 1, {} }

        for _, command in pairs(commands) do
            if command.helpN > 0 then
                if helpLines >= HELP_COMMAND_LINES then
                    helpLines = 0
                    helpPages.n = helpPages.n + 1
                    helpPages[helpPages.n] = {}
                end

                for _, helpMsg in ipairs(command.help) do
                    table.insert(helpPages[helpPages.n], helpMsg)
                end
                helpLines = helpLines + command.helpN
            end
        end

        helpInitialized = true
    end

    ---@class ChatCommands: ChatServiceListener
    ChatCommands = {}

    local mandatoryArgC = 0
    local length = 0
    local argsString ---@type string
    local help ---@type string[]?
    local defaultValues ---@type string[]

    ---@param cmdBuilder ChatCommandBuilder
    function ChatCommands.registerCommand(cmdBuilder)
        length = #cmdBuilder.arguments
        mandatoryArgC = 0
        defaultValues = {}
        if cmdBuilder.showHelp then
            help = {}
            if length > 0 then
                argsString = ""
                for i = 1, length - 1 do
                    argsString = argsString .. cmdBuilder.arguments[i].name .. " "
                end
                help[1] = COMMAND_PREFIX .. cmdBuilder.name .. " " .. argsString .. cmdBuilder.arguments[length].name
            else
                help[1] = COMMAND_PREFIX .. cmdBuilder.name .. " "
            end

            if cmdBuilder.desc then
                help[1] = help[1] .. "    - " .. cmdBuilder.desc
            end

            for i = 1, length do
                if cmdBuilder.arguments[i].desc then
                    help[i + 1] = "      -> " .. cmdBuilder.arguments[i].name .. " - " .. cmdBuilder.arguments[i].desc
                end

                if cmdBuilder.arguments[i].defaultVal == nil then
                    mandatoryArgC = mandatoryArgC + 1
                else
                    table.insert(defaultValues, cmdBuilder.arguments[i].defaultVal)
                end
            end


            commands[cmdBuilder.name] = {
                name = cmdBuilder.name,
                argC = length,
                minimumArgC = mandatoryArgC,
                func = cmdBuilder.func,
                help = help,
                helpN = length + 1,
                defaultValues = defaultValues
            }
        else
            for i = 1, length do
                if cmdBuilder.arguments[i].defaultVal == nil then
                    mandatoryArgC = mandatoryArgC + 1
                else
                    table.insert(defaultValues, cmdBuilder.arguments[i].defaultVal)
                end
            end

            commands[cmdBuilder.name] = {
                name = cmdBuilder.name,
                argC = length,
                minimumArgC = mandatoryArgC,
                func = cmdBuilder.func,
                help = nil,
                helpN = 0,
                defaultValues = defaultValues
            }
        end

        helpInitialized = false -- reinitialize
    end

    ---@param name string
    function ChatCommands.unregisterCommand(name)
        commands[name] = nil
        helpInitialized = false -- reinitialize
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
            ChatService.errorMessage("Unknown command!", chatEvent.from)
            return
        end

        local params = {}
        local count = 0
        for param in commandParts do
            table.insert(params, param)
            count = count + 1
        end

        if count < chatCommand.minimumArgC then
            ChatService.errorMessage("Insufficient arguments for " .. chatCommand.name .. " command!", chatEvent.from)
            return
        end

        for i = count - chatCommand.minimumArgC + 1, chatCommand.argC - count + 1 do
            table.insert(params, chatCommand.defaultValues[i])
        end

        chatCommand.func(chatEvent, table.unpack(params))
    end

    ---@param chatEvent ChatEvent
    ---@param page string
    ChatCommandBuilder.create("help", function(chatEvent, page)
        local pageInt = math.tointeger(page)

        if not pageInt then
            ChatService.errorMessage("page has to be an integer!", chatEvent.from)
            return
        end

        if not helpInitialized then initHelp() end

        if pageInt < 1 or pageInt > helpPages.n then
            ChatService.errorMessage("page is out of bounds. Has to be between (inclusive) 1 and " .. helpPages.n .. "!", chatEvent.from)
            return
        end

        ChatService.systemMessage("Here's the list of chat commands you can use: [" .. page .. "/" .. helpPages.n .. "]", chatEvent.from)
        for _, helpMsg in ipairs(helpPages[pageInt]) do
            ChatService.systemMessage(helpMsg, chatEvent.from)
        end
    end):showInHelp()
        :argument("page", "1")
        :register()

    OnInit.final(initHelp)
end)
if Debug then Debug.endFile() end
