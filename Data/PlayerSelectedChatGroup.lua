if Debug then Debug.beginFile "ChatSystem/Data/PlayerSelectedChatGroup" end
OnInit.module("ChatSystem/Data/PlayerSelectedChatGroup", function(require)
    require "ChatSystem/Data/ChatProfiles"
    require "ChatSystem/Data/ChatGroups"

    local playerSelectedGroups = {} ---@type table<player, ChatGroup>
    local playerSelectedRecepient = {} ---@type table<player, ChatProfile>

    ---@class PlayerSelectedChatGroup
    PlayerSelectedChatGroup = {}

    ---@param player player
    ---@param chatGroup ChatGroup|string
    function PlayerSelectedChatGroup.setPlayerChatGroup(player, chatGroup)
        assert(player ~= nil, "player cannot be nil!")
        assert(chatGroup ~= nil, "chatGroup cannot be nil!")
        playerSelectedGroups[player] = type(chatGroup) == 'string' and ChatGroups:get(chatGroup) or chatGroup --[[@as ChatGroup]]
        playerSelectedRecepient[player] = nil
    end

    ---@param player player
    ---@param recepient ChatProfile|player|string
    function PlayerSelectedChatGroup.setPlayerRecepient(player, recepient)
        assert(player ~= nil, "player cannot be nil!")
        assert(recepient ~= nil, "recepient cannot be nil!")
        playerSelectedGroups[player] = nil
        playerSelectedRecepient[player] = type(recepient) ~= 'table' and ChatProfiles:get(recepient --[[@as player|string]]) or recepient --[[@as ChatProfile]]
    end

    ---@param player player
    ---@return ChatGroup?
    function PlayerSelectedChatGroup.getSelectedGroupForPlayer(player)
        return playerSelectedGroups[player]
    end

    ---@param player player
    ---@return ChatProfile?
    function PlayerSelectedChatGroup.getSelectedRecepientForPlayer(player)
        return playerSelectedRecepient[player]
    end
end)
if Debug then Debug.endFile() end
