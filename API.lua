if Debug then Debug.beginFile "ChatSystem/API" end
OnInit.module("ChatSystem/API", function(require)
    --[[
    API:
        ChatProfiles:get(identifier)
            * Fetches the profile of desired recepient, can be a real recepient or a virtual one
            - identifer: player | string (any string that represents a virtual recepient)
            -> ChatProfile
        ChatProfiles:exists(identifier)
            * Checks if profile with the specified identifier exists or not
            - identifer: player | string (any string that represents a virtual recepient)
            -> boolean
        ChatProfiles:invalidate(identifier)
            * Removes profile from this registry. Note that profile is only truly deleted when all references to it are lost.
            * This just makes that reference no longer attainable via ChatProfiles.
            * :exists will return false and :get will return a new profile after this method call
            - identifer: player | string (any string that represents a virtual recepient)

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
            -> ChatGroup
        ChatGroups:exists(name)
            * Checks if group with the specified name exists or not
            - name: string (unique identifier for this ChatGroup)
            -> boolean
        ChatGroups:invalidate(name)
            * Removes profile from this registry. Note that group is only truly deleted when all references to it are lost.
            * This just makes that reference no longer attainable via ChatGroups.
            * :exists will return false and :get will return a new empty group after this method call
            - name: string (unique identifier for this ChatGroup)

        ChatGroup instances:
            * These represent only a group of recepients for text messages.
            * Technically only profiles are allowed to send to any group, but only those in that group will see the message (and the sender itself, ofc)
            .name: string - display name how it's gonna look like on the UI
                * Note: changing this name only affects UI look, the ChatGroups methods still operate
                        with the previous name, as that one is immutable
            .owner: ChatProfile - profile which has ownership over the group, on it's own it does nothing, but some chat extensions may use this property.
            .members: table<ChatProfile, true> - SyncedTable so it's pairs-safe
            :add(profile)
                - profile: ChatProfile
            :remove(profile)
                - profile: ChatProfile
            :contains(profile)
                - profile: ChatProfile
                -> boolean

        ChatService.sendMessage(from, message, recepient)
            - from and recepient: ChatProfile | player | string (any string that represents a virtual recepient)
            - message: string

        ChatService.sendMessageToGroup(from, message, chatGroup)
            - from: ChatProfile | player | string (any string that represents a virtual recepient)
            - message: string
            - chatGroup: ChatGroup | string (group identifier with which the group was created)

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

        ChatService.disableUI -> setting this to anything but nil or false will cause the ChatService not to notify UIListeners (messages won't be visible)
        ChatService.disableAll -> setting this to anything but nil or false will cause the ChatService to ignore any upcoming sendMessage (and derivative) calls

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

    ---@enum ChatDisplaySetting
    ChatDisplaySetting = {
        DEFAULT = 1,     --Default chat behavior, if private message, both sender and recepient will see it, if it's a group message, everyone in group will see it
        NONE = 2,        --Message is hidden from everyone, including the sender
        SENDER_ONLY = 3, --Only the sender will see this message
        FORCE_ALL = 4    --Everyone will receive this message
    }

    -- Table which is provided to any chat event listener so you have more control over the chat system.
    -- Modifying these values changes the behavior and what the system will show as the final message to UIs (and to who)
    -- Nilling the properties causes them to revert to initial values.
    ---@class ChatEvent
    ---@field displaySetting ChatDisplaySetting who will see the message that was sent
    ---@field time integer message time
    ---@field timestamp string message time but in (hh:mm:ss) format (hours don't show unless game is over an hour long)
    ---@field from ChatProfile
    ---@field to ChatProfile|ChatGroup
    ---@field message string
    ---@field [string] any? Can be used to pass custom data between ChatServiceListeners

    -- Listener that can be used to check every message and to influence how chat service handles the chat event.
    ---@class ChatServiceListener
    ---@field newMessage fun(chatEvent: ChatEvent)

    -- UI listeners are expected to handle local code only, and only for purpose of showing these messages on the UI, no game logic should be done in these listeners.
    ---@class ChatServiceUIListener
    ---@field newPrivateMessage fun(timestamp: string, contact: ChatProfile, message: string, isForSender: boolean) isForSender refers if this message should be formatted to be shown to the sender of private messages (to [name] vs from [name])
    ---@field newMessage fun(timestamp: string, from: ChatProfile, message: string, groupName: string)
end)
if Debug then Debug.endFile() end
