if Debug then Debug.beginFile "ChatSystem" end
OnInit.main("ChatSystem", function (require)
    --[[
        Main configuration script
    ]]
    require "ChatSystem/Data/ChatProfiles"
    require "ChatSystem/Data/ChatGroups"
    require "ChatSystem/Data/PlayerSelectedChatGroup"
    require "ChatSystem/ChatService"
    require "ChatSystem/UI/ChatUI"
    require "ChatSystem/UI/ChatHistoryUI"

    -- Hook up ChatUI to ChatService to display oncoming messages
    table.insert(ChatService.listeners, ChatUI)

    -- Create a ALL Group where every player can communicate
    local groupAll = ChatGroups:get('All')
    groupAll.name = "[|cff00e6e2Global|r]"

    -- Create Observers group with nobody there, therefore no player can send other player messages via this group.
    ChatGroups:get('Observers').name = "[Observers]"

    -- Format for private chat messages where sending message to specific player, instead of a group
    ChatService.setPrivateMessagePrefixPatterns("From [\x25(fromPlayer)s]:", "To [\x25(toPlayer)s]:")

    OnInit.trig(function (require)
        require "SetUtils"
        -- Setup simple chat message event to show chat in new UI
        local playerMessageTrigger = CreateTrigger()
        for player in SetUtils.getPlayersAll():elements() do
            TriggerRegisterPlayerChatEvent(playerMessageTrigger, player, "", false)
        end
        TriggerAddAction(playerMessageTrigger, function()
            local player = GetTriggerPlayer()
            local group = PlayerSelectedChatGroup.getSelectedGroupForPlayer(player)
            if group then
                -- Send message depending on selected group
                ChatService.sendMessageToChatGroup(player, GetEventPlayerChatString(), group)
            else
                local recepient = PlayerSelectedChatGroup.getSelectedRecepientForPlayer(player).player or player
                -- Send message to specific player
                ChatService.sendMessageToPlayer(player, GetEventPlayerChatString(), recepient)
            end
            -- Note: switching chatting groups is not implemented, should be done by hooking up ChatHistoryUI's buttons to do something?
            -- Or a different Log frame alltogether 
        end)
    end)

    local groupSys = ChatGroups:get("sys")
    groupSys.name = "[|cff00e6e2SYS|r]"

    OnInit.final(function(require)
        require "SetUtils"
        for player in SetUtils.getPlayersAll():elements() do
            PlayerSelectedChatGroup.playerSelectedChatGroup(player, groupAll)  -- make all players have "All" chat selected
            local playerProfile = ChatProfiles:get(player)
            playerProfile.icon = "ReplaceableTextures\\CommandButtons\\BTNPriest.blp"
            groupAll:add(playerProfile) -- make all players participants on All group
            groupSys:add(playerProfile)-- make all players participants on Sys group
        end

        ChatSystem.sendSystemMessage("Successfully loaded Chat System v1") -- displays for all players
    end)

    --[[
        Additional info:

        Setting a destination group does not mean that the chat profile must be added to said group (Look at observers group init)
        If a group has a player profile as a participant, it may receive whatever message is sent to that group, but it sending a message
        in that group will not be received by other players because they're not in that group, regardless if they can send messages in the group
        or not.

        Switching of groups (All, Observers, Allies, etc..) has not been implemented. (There wasn't an implementation for JASS system to begin with)

        To define allies group it would have to be defined per teams. However, Lua has no method of hooking up into map config properties
        so those would have to be manually defined...

        By defined per teams, it is meant to have multiple "Allies" groups, one for each team.

        ChatGroups:get(identifier) will either fetch an existing group, or create a new one with given identifier.
        after doing that, you can edit the received ChatGroup's properties in order to customize it's display data. (Name for starters)

        Doing something like:

        ChatGroups:get("alliesTeam1").name = "Allies"
        ChatGroups:get("alliesTeam2").name = "Allies"
        ChatGroups:get("alliesTeam3").name = "Allies"

        Will create 3 different groups, which will all display as "Allies" in the UI, but they're still fetchable by their original identifier.
        (You still have to define which players (profiles) belong to which group)
    ]]

    local system = ChatProfiles:get("System")
    system.icon = "ReplaceableTextures\\CommandButtons\\BTNSentinel.blp"

    ---@class ChatSystem
    ChatSystem = {}

    ---@param message string
    function ChatSystem.sendSystemMessage(message)
        ChatService.sendMessageToChatGroup(system, message, groupSys)
    end
end)
if Debug then Debug.endFile() end