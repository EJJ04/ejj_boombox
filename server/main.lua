local boomboxes = {}
local placedBoomboxes = {}

local function soundIdFor(netId)
    return ('%s:%s'):format(Config.SoundPrefix, netId)
end

local function broadcastSound(state, soundId, data)
    data.soundId = soundId
    TriggerClientEvent('xsound:stateSound', -1, state, data)
end

local function isYouTubeUrl(url)
    return url:find('youtube%.com', 1, false) ~= nil or url:find('youtu%.be', 1, false) ~= nil
end

local function urlEncode(value)
    local encoded = tostring(value):gsub('\n', '\r\n')

    encoded = encoded:gsub('([^%w%-_%.~])', function(char)
        return ('%%%02X'):format(string.byte(char))
    end)

    return encoded
end

local function resolveTrackTitle(url, cb)
    if not isYouTubeUrl(url) then
        cb(nil)
        return
    end

    local endpoint = ('https://www.youtube.com/oembed?format=json&url=%s'):format(urlEncode(url))

    PerformHttpRequest(endpoint, function(status, body)
        if status < 200 or status >= 300 or type(body) ~= 'string' or body == '' then
            cb(nil)
            return
        end

        local ok, decoded = pcall(json.decode, body)

        if not ok or type(decoded) ~= 'table' or type(decoded.title) ~= 'string' or decoded.title == '' then
            cb(nil)
            return
        end

        cb(decoded.title)
    end, 'GET')
end

local function positionForNetId(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)

    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return nil
    end

    local coords = GetEntityCoords(entity)

    return vector3(coords.x, coords.y, coords.z)
end

local function isPlayerNearNetId(source, netId, extraDistance)
    local entity = NetworkGetEntityFromNetworkId(netId)
    local ped = GetPlayerPed(source)

    if not entity or entity == 0 or not DoesEntityExist(entity) or not ped or ped == 0 then
        return false
    end

    local entityCoords = GetEntityCoords(entity)
    local playerCoords = GetEntityCoords(ped)
    local distance = (Config.TargetDistance or 2.0) + (extraDistance or 1.5)
    local dx = entityCoords.x - playerCoords.x
    local dy = entityCoords.y - playerCoords.y
    local dz = entityCoords.z - playerCoords.z

    return (dx * dx + dy * dy + dz * dz) <= (distance * distance)
end

local function queueForNui(queue)
    local items = {}

    for index, item in ipairs(queue or {}) do
        items[index] = {
            url = item.url,
            title = item.title,
        }
    end

    return items
end

local function getState(source, netId)
    netId = tonumber(netId)

    if not netId then
        return nil, nil
    end

    local position = positionForNetId(netId)

    if not position then
        return nil, nil
    end

    local state = boomboxes[netId]

    if not state then
        state = {
            owner = source,
            volume = Config.DefaultVolume,
            distance = Config.DefaultDistance,
            position = position,
            playing = false,
            paused = false,
            timestamp = 0,
            queue = {},
        }

        boomboxes[netId] = state
    else
        state.position = position
    end

    return state, netId
end

local function updatePlaybackTimestamp(state)
    if state.playing and not state.paused and state.startedAt then
        state.timestamp = math.max(0, os.time() - state.startedAt)
    end
end

local function sendState(source, netId, extra)
    local soundId = soundIdFor(netId)
    local state = boomboxes[netId] or {}

    for key, value in pairs(extra or {}) do
        state[key] = value
    end

    updatePlaybackTimestamp(state)

    state.soundId = soundId
    state.netId = netId
    state.queue = queueForNui(state.queue)
    TriggerClientEvent('ejj_boombox:client:state', source, state)
end

local function playState(source, netId, state, url, title)
    local soundId = soundIdFor(netId)

    broadcastSound('destroy', soundId, {})

    state.url = url
    state.title = title
    state.playing = true
    state.paused = false
    state.timestamp = 0
    state.startedAt = os.time()
    state.position = positionForNetId(netId) or state.position

    broadcastSound('playpos', soundId, {
        url = url,
        volume = state.volume or Config.DefaultVolume,
        position = state.position,
        loop = false,
    })

    broadcastSound('distance', soundId, {
        distance = state.distance or Config.DefaultDistance,
    })

    sendState(source, netId)
end

RegisterNetEvent('ejj_boombox:server:requestState', function(netId)
    local source = source
    local state, resolvedNetId = getState(source, netId)

    if not state then
        return
    end

    sendState(source, resolvedNetId)
end)

RegisterNetEvent('ejj_boombox:server:registerBoombox', function(netId)
    netId = tonumber(netId)

    if not netId then
        return
    end

    CreateThread(function()
        local attempts = 0

        while not positionForNetId(netId) and attempts < 50 do
            Wait(100)
            attempts = attempts + 1
        end

        if not positionForNetId(netId) then
            return
        end

        placedBoomboxes[netId] = true
        TriggerClientEvent('ejj_boombox:client:registerTarget', -1, netId)
    end)
end)

RegisterNetEvent('ejj_boombox:server:requestTargets', function()
    local source = source

    for netId in pairs(placedBoomboxes) do
        TriggerClientEvent('ejj_boombox:client:registerTarget', source, netId)
    end
end)

RegisterNetEvent('ejj_boombox:server:consumeBoomboxItem', function(netId)
    local source = source

    netId = tonumber(netId)

    if not netId then
        return
    end

    CreateThread(function()
        local attempts = 0

        while not positionForNetId(netId) and attempts < 50 do
            Wait(100)
            attempts = attempts + 1
        end

        if not positionForNetId(netId) or not isPlayerNearNetId(source, netId, 2.0) then
            return
        end

        exports.ox_inventory:RemoveItem(source, Config.ItemName, 1)
    end)
end)

RegisterNetEvent('ejj_boombox:server:pickupBoombox', function(netId)
    local source = source

    netId = tonumber(netId)

    if not netId or not placedBoomboxes[netId] or not isPlayerNearNetId(source, netId) then
        return
    end

    if not exports.ox_inventory:CanCarryItem(source, Config.ItemName, 1) then
        return
    end

    local added = exports.ox_inventory:AddItem(source, Config.ItemName, 1)

    if not added then
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)

    broadcastSound('destroy', soundIdFor(netId), {})
    boomboxes[netId] = nil
    placedBoomboxes[netId] = nil
    TriggerClientEvent('ejj_boombox:client:removeTarget', -1, netId)

    if entity and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end)

RegisterNetEvent('ejj_boombox:server:play', function(data)
    local source = source

    if type(data) ~= 'table' or type(data.url) ~= 'string' or data.url == '' then
        return
    end

    local state, netId = getState(source, data.netId)

    if not state then
        return
    end

    local volume = tonumber(data.volume) or Config.DefaultVolume
    volume = math.max(0.0, math.min(1.0, volume))

    state.volume = volume
    state.queue = state.queue or {}

    playState(source, netId, state, data.url)
end)

RegisterNetEvent('ejj_boombox:server:distance', function(data)
    local source = source

    if type(data) ~= 'table' then
        return
    end

    local state, netId = getState(source, data.netId)
    local value = tonumber(data.distance) or Config.DefaultDistance

    if not state then
        return
    end

    value = math.max(Config.MinDistance, math.min(Config.MaxDistance, value))
    state.distance = value

    broadcastSound('distance', soundIdFor(netId), {
        distance = value,
    })

    sendState(source, netId, {
        distance = value,
    })
end)

RegisterNetEvent('ejj_boombox:server:addQueue', function(data)
    local source = source

    if type(data) ~= 'table' or type(data.url) ~= 'string' or data.url == '' then
        return
    end

    local state, netId = getState(source, data.netId)

    if not state then
        return
    end

    resolveTrackTitle(data.url, function(title)
        if boomboxes[netId] ~= state then
            return
        end

        state.queue = state.queue or {}
        state.queue[#state.queue + 1] = {
            url = data.url,
            title = title,
        }

        sendState(source, netId)
    end)
end)

RegisterNetEvent('ejj_boombox:server:playQueueItem', function(data)
    local source = source

    if type(data) ~= 'table' then
        return
    end

    local state, netId = getState(source, data.netId)
    local queueIndex = tonumber(data.index)

    if not state or not queueIndex then
        return
    end

    state.queue = state.queue or {}

    local item = table.remove(state.queue, queueIndex)

    if not item or not item.url then
        sendState(source, netId)
        return
    end

    playState(source, netId, state, item.url, item.title)
end)

RegisterNetEvent('ejj_boombox:server:removeQueueItem', function(data)
    local source = source

    if type(data) ~= 'table' then
        return
    end

    local state, netId = getState(source, data.netId)
    local queueIndex = tonumber(data.index)

    if not state or not queueIndex then
        return
    end

    state.queue = state.queue or {}
    table.remove(state.queue, queueIndex)
    sendState(source, netId)
end)

RegisterNetEvent('ejj_boombox:server:pause', function(netId)
    local source = source
    local state, resolvedNetId = getState(source, netId)

    if not state then
        return
    end

    updatePlaybackTimestamp(state)
    broadcastSound('pause', soundIdFor(resolvedNetId), {})
    sendState(source, resolvedNetId, {
        playing = false,
        paused = true,
    })
end)

RegisterNetEvent('ejj_boombox:server:resume', function(netId)
    local source = source
    local state, resolvedNetId = getState(source, netId)

    if not state then
        return
    end

    state.startedAt = os.time() - (tonumber(state.timestamp) or 0)
    broadcastSound('resume', soundIdFor(resolvedNetId), {})
    sendState(source, resolvedNetId, {
        playing = true,
        paused = false,
    })
end)

RegisterNetEvent('ejj_boombox:server:stop', function(netId)
    local source = source
    local state, resolvedNetId = getState(source, netId)

    if not state then
        return
    end

    broadcastSound('destroy', soundIdFor(resolvedNetId), {})
    boomboxes[resolvedNetId] = nil
    sendState(source, resolvedNetId, {
        playing = false,
        paused = false,
        url = nil,
        timestamp = 0,
        startedAt = nil,
        volume = Config.DefaultVolume,
        queue = {},
    })
end)

RegisterNetEvent('ejj_boombox:server:volume', function(data)
    local source = source

    if type(data) ~= 'table' then
        return
    end

    local state, netId = getState(source, data.netId)
    local value = tonumber(data.volume) or Config.DefaultVolume

    if not state then
        return
    end

    value = math.max(0.0, math.min(1.0, value))
    state.volume = value

    broadcastSound('volume', soundIdFor(netId), {
        volume = value,
    })

    sendState(source, netId, {
        volume = value,
    })
end)

RegisterNetEvent('ejj_boombox:server:seek', function(data)
    local source = source

    if type(data) ~= 'table' then
        return
    end

    local state, netId = getState(source, data.netId)
    local value = tonumber(data.timestamp) or 0.0

    if not state then
        return
    end

    value = math.max(0.0, value)
    state.timestamp = value

    if state.playing and not state.paused then
        state.startedAt = os.time() - value
    end

    broadcastSound('timestamp', soundIdFor(netId), {
        time = value,
    })

    sendState(source, netId, {
        timestamp = value,
    })
end)

RegisterNetEvent('ejj_boombox:server:finished', function(data)
    local source = source

    if type(data) ~= 'table' then
        return
    end

    local netId = tonumber(data.netId)
    local soundId = data.soundId

    if not netId or soundId ~= soundIdFor(netId) then
        return
    end

    local state = boomboxes[netId]

    if not state then
        return
    end

    state.queue = state.queue or {}

    local nextItem = table.remove(state.queue, 1)

    if nextItem and nextItem.url then
        playState(source, netId, state, nextItem.url, nextItem.title)
        return
    end

    state.url = nil
    state.title = nil
    state.playing = false
    state.paused = false
    state.timestamp = 0
    state.startedAt = nil
    sendState(source, netId)
end)

AddEventHandler('playerDropped', function()
    local source = source

    for netId, state in pairs(boomboxes) do
        if state.owner == source then
            broadcastSound('destroy', soundIdFor(netId), {})
            boomboxes[netId] = nil
        end
    end
end)
