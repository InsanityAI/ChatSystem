if Debug then Debug.beginFile "ChatSystem/Data/ChatGroups" end
OnInit.module("ChatSystem/Data/ChatGroups", function (require)
    require "SyncedTable"
    require "Cache"

    ---@class ChatGroup
    ---@field owner ChatProfile
    ---@field members table<ChatProfile, true>
    ---@field name string
    ChatGroup = {}
    ChatGroup.__index = ChatGroup
    ChatGroup.__name = "ChatGroup"

    ---@class ChatGroups: Cache
    ---@field get fun(self: ChatGroups, name: string): ChatGroup
    ---@field exists fun(self: ChatGroups, name: string): boolean
    ---@field invalidate fun(self: ChatGroups, name: string)
    ChatGroups = Cache.create(function(name, owner)
        return setmetatable({
            members = SyncedTable.create(),
            name = name
    }, ChatGroup)
    end, 1)

    ---@param profile ChatProfile
    function ChatGroup:add(profile)
        self.members[profile] = true
    end

    ---@param profile ChatProfile
    function ChatGroup:remove(profile)
        self.members[profile] = nil
    end

    ---@param profile ChatProfile
    ---@return boolean
    function ChatGroup:contains(profile)
        return self.members[profile] ~= nil
    end

    -- duplicate/rename for clearer API
    ChatGroups.exists = ChatGroups.hasCached

    return ChatGroup
end)
if Debug then Debug.endFile() end