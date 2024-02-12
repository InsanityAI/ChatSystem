if Debug then Debug.beginFile "ChatSystem.Data.ChatGroups" end
OnInit.module("ChatSystem.Data.ChatGroups", function (require)
    require "SyncedTable"

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
    function ChatGroup:removeProfile(profile)
        self.members[profile] = nil
    end

    ---@param handler fun(member: ChatProfile)
    function ChatGroup:forEachMember(handler)
        for member, _ in pairs(self.members) do
            handler(member)
        end
    end
end)
if Debug then Debug.endFile() end