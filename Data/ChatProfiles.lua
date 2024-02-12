if Debug then Debug.beginFile "ChatSystem.Data.DataProfiles" end
OnInit.module("ChatSystem.Data.DataProfiles", function (require)
    ---@class ChatProfile
    ---@field player player?
    ---@field name string
    ---@field icon string
    ChatProfile = {}
    ChatProfile.__index = ChatProfile

    ---@class ChatProfiles: Cache
    ---@field get fun(self: ChatProfiles, identifier: player|string): ChatProfile
    ---@field invalidate fun(self: ChatProfiles, identifier: player|string)
    ChatProfiles = Cache.create(function(identifier)
        local name = type(identifier) == 'string' and identifier or GetPlayerName(identifier)
        local player = type(identifier) == 'userdata' and identifier or nil
        return setmetatable({
            name = name,
            player = player,
            icon = "ReplaceableTextures\\CommandButtons\\BTNPeasant.blp"
        }, ChatProfile)
    end, 1)
end)
if Debug then Debug.endFile() end