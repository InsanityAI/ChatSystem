if Debug then Debug.beginFile "ChatSystem/Extensions/ChatMute" end
OnInit.module("ChatSystem/Extensions/ChatMute", function(require)
    require "SyncedTable"
    require "SetUtils"
    require "ChatSystem/ChatService"
    require "ChatSystem/API"
    require "ChatSystem/Extensions/ChatCommands"
    require "ChatSystem/Data/ChatProfiles"

    local globallyMutedProfiles = {} ---@type table<ChatProfile, boolean>
    local mutedProfileMap = SyncedTable.create() ---@type table<ChatProfile, table<ChatProfile, true>>

    ---@class ChatMute: ChatServiceListener
    ChatMute = {}

    ---@param whichProfile ChatProfile
    ---@param forWhichProfile ChatProfile? if nil, globally mute the ChatProfile
    function ChatMute.mute(whichProfile, forWhichProfile)
        if forWhichProfile then
            if not mutedProfileMap[forWhichProfile] then
                mutedProfileMap[forWhichProfile] = {}
            end
            mutedProfileMap[forWhichProfile][whichProfile] = true
        else
            globallyMutedProfiles[whichProfile] = true
        end
    end

    ---@param whichProfile ChatProfile
    ---@param forWhichProfile ChatProfile? if nil, remove ChatProfile from globally muted ChatProfiles, note that this doesn't unmute the ChatProfile for individual ChatProfiles that have them muted
    function ChatMute.unmute(whichProfile, forWhichProfile)
        if forWhichProfile then
            if not mutedProfileMap[forWhichProfile] then
                mutedProfileMap[forWhichProfile] = {}
            end
            mutedProfileMap[forWhichProfile][whichProfile] = nil
        else
            globallyMutedProfiles[whichProfile] = nil
        end
    end

    -- unmutes the ChatProfile both globally and for all ChatProfiles
    ---@param whichProfile ChatProfile
    function ChatMute.unmuteForAll(whichProfile)
        globallyMutedProfiles[whichProfile] = nil
        for _, mutedProfiles in pairs(mutedProfileMap) do
            mutedProfiles[whichProfile] = nil
        end
    end

    ---@param whichProfile ChatProfile
    ---@param forwhichProfile ChatProfile? if nil, checks if ChatProfile is globally muted
    ---@return boolean
    function ChatMute.isProfileMuted(whichProfile, forwhichProfile)
        if forwhichProfile then
            if mutedProfileMap[forwhichProfile] then
                return mutedProfileMap[forwhichProfile][whichProfile] == true -- make sure it returns a boolean and not true|nil
            else
                return false
            end
        else
            return globallyMutedProfiles[whichProfile] == true
        end
    end

    ---@param chatEvent ChatEvent
    function ChatMute.newMessage(chatEvent)
        if typeof(chatEvent.to) == 'ChatGroup' then
            if globallyMutedProfiles[chatEvent.from] then
                chatEvent.displaySetting = ChatDisplaySetting.SENDER_ONLY
            else
                for member, _ in pairs(chatEvent.to.members) do
                    local mutedProfiles = mutedProfileMap[member]
                    if mutedProfiles and mutedProfiles[chatEvent.from] then
                        chatEvent.displaySetting = ChatDisplaySetting.SENDER_ONLY
                    end
                end
            end
        elseif typeof(chatEvent.to) == 'ChatProfile' then
            local mutedProfiles = mutedProfileMap[chatEvent.to]
            if globallyMutedProfiles[chatEvent.from] or (mutedProfiles and mutedProfiles[chatEvent.from]) then
                chatEvent.displaySetting = ChatDisplaySetting.SENDER_ONLY
            end
        end
    end

    ---@param chatEvent ChatEvent
    ---@param profileName string
    ChatCommands.registerCommand("mute", 1, function(chatEvent, profileName)
        if ChatProfiles:exists(profileName) then
            local profile = ChatProfiles:get(profileName)
            ChatMute.mute(profile, chatEvent.from)
            ChatService.systemMessage("|cFF00FFFFInfo: Profile |r" .. profile.name .. "|cFF00FFFF has been muted!", chatEvent.from)
        else
            local found = false
            local profile ---@type ChatProfile
            for player in SetUtils.getPlayersAll():elements() do
                profile = ChatProfiles:get(player)
                if profile.name == profileName then
                    found = true
                end
            end
            if found then
                ChatMute.mute(profile, chatEvent.from)
                ChatService.systemMessage("|cFF00FFFFInfo: Profile |r" .. profile.name .. "|cFF00FFFF has been muted!", chatEvent.from)
            else
                ChatService.systemMessage("|cFFFF0000Error: Chat profile not found!", chatEvent.from)
            end
        end
    end, true, {"profileName - name of the profile you'd like to mute."}, "Mute a profile.")

    ---@param chatEvent ChatEvent
    ---@param profileName string
    ChatCommands.registerCommand("unmute", 1, function(chatEvent, profileName)
        if ChatProfiles:exists(profileName) then
            local profile = ChatProfiles:get(profileName)
            ChatMute.unmute(profile, chatEvent.from)
            ChatService.systemMessage("|cFF00FFFFInfo: Profile |r" .. profile.name .. "|cFF00FFFF has been unmuted!", chatEvent.from)
            ChatService.systemMessage("|cFF00FFFFInfo: |r" .. profile.name .. "|cFF00FFFF has unmuted you!", profile)
        else
            local found = false
            local profile ---@type ChatProfile
            for player in SetUtils.getPlayersAll() do
                profile = ChatProfiles:get(player)
                if profile.name == profileName then
                    found = true
                end
            end
            if found then
                ChatMute.unmute(profile, chatEvent.from)
                ChatService.systemMessage("|cFF00FFFFInfo: Profile |r" .. profile.name .. "|cFF00FFFF has been unmuted!", chatEvent.from)
                ChatService.systemMessage("|cFF00FFFFInfo: |r" .. profile.name .. "|cFF00FFFF has unmuted you!", profile)
            else
                ChatService.systemMessage("|cFFFF0000Error: Chat profile not found!", chatEvent.from)
            end
        end
    end, true, {"profileName - name of the profile you'd like to unmute."}, "Unmute a profile.")
end)
if Debug then Debug.endFile() end
