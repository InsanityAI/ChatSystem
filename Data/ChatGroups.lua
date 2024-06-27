if Debug then Debug.beginFile "ChatSystem/Data/ChatGroups" end
OnInit.module("ChatSystem/Data/ChatGroups", function (require)
    require "SyncedTable"
    require "Cache"

    ---@class ChatGroup
    ---@field members table<ChatProfile, true>
    ---@field name string
    ChatGroup = {}
    ChatGroup.__index = ChatGroup

    ---@class ChatGroups: Cache
    ---@field get fun(self: ChatGroups, name: string): ChatGroup
    ---@field invalidate fun(self: ChatGroups, name: string)
    ChatGroups = Cache.create(function(name)
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

    ---@param handler fun(member: ChatProfile)
    function ChatGroup:forEachMember(handler)
        for member, _ in pairs(self.members) do
            handler(member)
        end
    end

    return ChatGroup
end)
if Debug then Debug.endFile() end