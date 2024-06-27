if Debug then Debug.beginFile "ChatSystem" end
--[[
    API:
        ChatProfiles:get(identifier)
            * Fetches the profile of desired recepient, can be a real recepient or a virtual one
            - identifer: player | string (any string that represents a virtual recepient)
            -> ChatProfile

        ChatProfile instances:
            .name: string - display name how it's gonna look like on the UI
                * Note: changing this name only affects UI look, the ChatProfiles:get still operates 
                        with the previous name, as that one is immutable
            .icon: string - icon path that gets displayed next to the name on the UI
            .player: player? - if virtual ChatProfile this is nil.
                * Note: it's possible to have multiple virtual recepients be connected to a single player
                        by manually setting this field, but by default the player can only send from their
                        own original ChatProfile unless configured otherwise in this script.
                            (see playerMessageTrigger in this script)

        ChatGroups:get(name)
            * Fetches a ChatGroup with the given name.
            - name: string (unique identifier for this ChatGroup)

        ChatGroup instances:
            * These represent only a group of recepients for text messages, technically profiles 
            * are allowed to send to any group, but only those in that group will see the message 
            * (and the sender itself, ofc)
            .name: string - display name how it's gonna look like on the UI
                * Note: changing this name only affects UI look, the ChatGroups:get still operates 
                        with the previous name, as that one is immutable
            :add(profile)
                - profile: ChatProfile
            :remove(profile)
                - profile: ChatProfile
            :contains(profile)
                - profile: ChatProfile
                -> boolean
            :forEachMember(handler)
                * Convenience method to loop through group members
                - handler: fun(profile: ChatProfile)

        ChatService.sendMessageToPlayer(from, message, recepient)
            - from and recepient: ChatProfile | player | string (any string that represents a virtual recepient)
            - message: string

        ChatService.sendMessageToChatGroup(from, message, chatGroup)
            - from: ChatProfile | player | string (any string that represents a virtual recepient)
            - message: string
            - chatGroup: ChatGroup

        ChatService.setPrivateMessagePrefixPatterns(fromPattern, toPattern)
            * Used for setting up how the private message's type text looks like in UI.
            * Check ChatSystem to see how the default is setup.
            - fromPattern: string (pattern with 'fromPlayer' field for interp)
            - toPattern: string (pattern with 'toPlayer' field for interp)

        ChatService.registerUIListener(uiListener)
            * Attach a listener that will receive message traffic relevant to LocalPlayer
            - uiListener: ChatServiceUIListener (an interface that your UI should implement)
        
        ChatService.unregisterUIListener(uiListener)
            * Remove the listener from receiving notifications
            - uiListener: ChatServiceUIListener

        ChatService.registerListener(listener)
            * Attach a listener that will receive all message traffic
            - listener: ChatServiceListener (an interface that your class/table/system should implement)
        
        ChatService.unregisterListener(listener)
            * Remove the listener from receiving notifications
            - listener: ChatServiceListener

    Helper class/methods:
        PlayerSelectedChatGroup.setPlayerChatGroup(player, chatGroup)
            * Set the player's designated group for upcoming chat messages
            - player: player
            - chatGroup: ChatGroup|string (group identifier)

        PlayerSelectedChatGroup.setPlayerRecepient(player, recepient)
            * Set the player's designated recepient for private messaging for upcoming chat messages
            - player: player
            - recepient: ChatProfile|player|string (profile virtual identifier)
        
        PlayerSelectedChatGroup.getSelectedGroupForPlayer(player)
            - player: player
            -> ChatGroup? - nil in case private messaging is selected, or it was never setup.

        PlayerSelectedChatGroup.getSelectedRecepientForPlayer(player)
            - player: player
            -> ChatProfile - nil in case group chat is selected, or it was never setup.
]]
OnInit.main("ChatSystem", function(require)
    require "ChatSystem/Data/ChatProfiles"
    require "ChatSystem/Data/ChatGroups"
    require "ChatSystem/Data/PlayerSelectedChatGroup"
    require "ChatSystem/ChatService"
    require "ChatSystem/UI/ChatUI"
    require "ChatSystem/UI/ChatLogUI"

    --[[ Main configuration script ]]

    -- Hook up ChatUI to ChatService to display oncoming messages
    ChatService.registerUIListener(ChatUI)
    ChatService.registerUIListener(ChatLogUI)

    -- Create a ALL Group where every player can communicate
    local groupAll = ChatGroups:get('All')
    groupAll.name = "[|cff00e6e2Global|r]"

    -- Create Observers group with nobody there, therefore no player can send other player messages via this group.
    local groupObs = ChatGroups:get('Observers')
    groupObs.name = "[Observers]"

    -- Format for private chat messages where sending message to specific player, instead of a group
    ChatService.setPrivateMessagePrefixPatterns("From [\x25(fromPlayer)s]:", "To [\x25(toPlayer)s]:")

    OnInit.trig(function(require)
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
            else -- if Group is not selected but a profile might be which doesn't belong to a player, make sure to send the message to the sending player at least.
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

    -- let's assume map has fixed teams
    for i = 1, GetTeams() do
        ChatGroups:get("team" .. tostring(i)).name = "Allies"
    end

    OnInit.final(function(require)
        require "SetUtils"
        for player in SetUtils.getPlayersAll():elements() do
            PlayerSelectedChatGroup.setPlayerChatGroup(player, groupAll) -- make all players have "All" chat selected
            local playerProfile = ChatProfiles:get(player)
            playerProfile.icon = "ReplaceableTextures\\CommandButtons\\BTNPriest.blp"
            groupAll:add(playerProfile)                                                  -- make all players participants on All group
            groupSys:add(playerProfile)                                                  -- make all players participants on Sys group
            ChatGroups:get("team" .. tostring(GetPlayerTeam(player))):add(playerProfile) -- populate each team's "Allies" chat
            if IsPlayerObserver(player) then groupObs:add(playerProfile) end
        end

        ChatService.sendSystemMessage("UwU I'm your kawaii lil chat system. OwO") -- displays for all players
    end)

    --[[
        Additional info:

        Setting a destination group does not mean that the chat profile must be added to said group (Look at observers group init)
        If a group has a player profile as a participant, it may receive whatever message is sent to that group, but it sending a message
        in that group will not be received by other players because they're not in that group, regardless if they can send messages in the group
        or not.

        Switching of groups (All, Observers, Allies, etc..) has not been implemented. (There wasn't an implementation for JASS system to begin with)

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

    -- Setup a chat profile for system messages
    local system = ChatProfiles:get("System")
    system.icon = "ReplaceableTextures\\CommandButtons\\BTNSentinel.blp"

    -- Send a system message through provided API via ChatSystem
    ---@param message string
    function ChatService.sendSystemMessage(message)
        ChatService.sendMessageToChatGroup(system, message, groupSys)
    end
end)
if Debug then Debug.endFile() end
