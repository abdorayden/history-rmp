local api = require("rmp.rmp")

if raymp.history_plugin == nil then
    raymp.history_plugin = {}
end

if raymp.history_plugin.enable == nil then
    raymp.history_plugin.enable = true
end

if raymp.history_plugin.max_history == nil then
    raymp.history_plugin.max_history = 200
end

local State = {
    history = {},
    cursor = 0,
    last_path = nil,
    last_index = nil,
    snd = nil,
}

local function resolve_key(key)
    if type(key) == "string" then
        return api.KeyMap:get(key)
    end
    return key
end

local function max_history()
    local max = tonumber(raymp.history_plugin.max_history) or 200
    if max < 1 then
        max = 1
    end
    return math.floor(max)
end

local function track_changed(path, index)
    return path ~= State.last_path or index ~= State.last_index
end

local function record(path, index)
    for i = #State.history, State.cursor + 1, -1 do
        State.history[i] = nil
    end

    local current = State.history[State.cursor]
    if not current or current.path ~= path or current.index ~= index then
        table.insert(State.history, { path = path, index = index })
        State.cursor = #State.history
    end

    local limit = max_history()
    while #State.history > limit do
        table.remove(State.history, 1)
        State.cursor = math.max(1, State.cursor - 1)
    end
end

local function find_playlist_index(snd, entry)
    if not snd or not entry or not entry.path then
        return nil
    end

    local playlist = snd:getPlaylist() or {}

    if entry.index and playlist[entry.index] == entry.path then
        return entry.index
    end

    for i = 1, #playlist do
        if playlist[i] == entry.path then
            return i
        end
    end

    return nil
end

local function restore(snd, entry)
    local index = find_playlist_index(snd, entry)
    if not index then
        return false
    end

    local ok = snd:playTrack(index)
    if not ok then
        return false
    end

    State.last_path = entry.path
    State.last_index = index
    return true
end

return function()
    if raymp.history_plugin.enable == false then
        return
    end

    raymp:onSound(function(snd)
        State.snd = snd
        if not snd then
            return
        end

        local path = snd:getCurrentTrack()
        local index = snd:getCurrentIndex()

        if not path then
            State.last_path = nil
            State.last_index = nil
            return
        end

        if track_changed(path, index) then
            record(path, index)
            State.last_path = path
            State.last_index = index
        end
    end)

    raymp:onKeyboard(function(key)
        local snd = State.snd
        if not snd or not State.last_index then
            return
        end

        local prev_key = resolve_key(raymp.engine.soundMap.prev_sound)
        local next_key = resolve_key(raymp.engine.soundMap.next_sound)

        if prev_key and key == prev_key then
            local target = State.cursor - 1

            while target >= 1 do
                if restore(snd, State.history[target]) then
                    State.cursor = target
                    return
                end
                target = target - 1
            end
        elseif next_key and key == next_key then
            local target = State.cursor + 1

            while target <= #State.history do
                if restore(snd, State.history[target]) then
                    State.cursor = target
                    return
                end
                target = target + 1
            end
        end
    end)
end
