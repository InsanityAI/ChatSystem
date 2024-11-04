if Debug then Debug.beginFile "ChatSystem/UI/UIUtils" end
OnInit.module("ChatSystem/UI/UIUtils", function(require)
    ---@param name string
    ---@param pos integer
    ---@return framehandle
    function GetFrameSafe(name, pos)
        local frame = BlzGetFrameByName(name, pos)
        if frame == nil then
            --Intentionally leak a handle because someone does not have this frame
            --This should help prevent desyncs and replay errors
            Location(0, 0)
        end
        return frame --[[@as framehandle]]
    end
end)
if Debug then Debug.endFile() end
