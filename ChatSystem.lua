if Debug then Debug.beginFile "ChatSystem" end
OnInit.main("ChatSystem", function (require)
    require "ChatSystem.Data.ChatProfiles"
    require "ChatSystem.Data.ChatGroups"
    require "ChatSystem.Data.PlayerSelectedChatGroup"
    require "ChatSystem.ChatService"
    require "ChatSystem.UI.ChatUI"
    require "ChatSystem.UI.ChatHistoryUI"

    -- Hook up ChatUI to ChatService to display oncoming messages
    table.insert(ChatService.listeners, ChatUI)

    local groupAll = ChatGroups:get('All')
    groupAll.name = "[|cff00e6e2Global|r]"
    ChatGroups:get('Observers').name = "[Observers]"
    ChatService.setPrivateMessagePrefixPatterns("From [\x25(fromPlayer)s]:", "To [\x25(toPlayer)s]:")

    OnInit.trig(function (require)
        require "SetUtils"
        local playerMessageTrigger = CreateTrigger()
        for player in SetUtils.getPlayersAll():elements() do
            TriggerRegisterPlayerChatEvent(playerMessageTrigger, player, "", false)
        end
        TriggerAddAction(playerMessageTrigger, function()
            local player = GetTriggerPlayer()
            local group = PlayerSelectedChatGroup.getSelectedGroupForPlayer(player)
            if group then
                ChatService.sendMessageToChatGroup(player, GetEventPlayerChatString(), group)
            else
                local recepient = PlayerSelectedChatGroup.getSelectedRecepientForPlayer(player).player or player
                ChatService.sendMessageToPlayer(player, GetEventPlayerChatString(), recepient)
            end
        end)
    end)

    OnInit.final(function(require)
        require "SetUtils"
        for player in SetUtils.getPlayersAll():elements() do
            PlayerSelectedChatGroup.playerSelectedChatGroup(player, groupAll)
            groupAll:add(ChatProfiles:get(player))
            -- make all players have "All" chat selected
        end
    end)
end)
if Debug then Debug.endFile() end