local isOpen = false
local activeBoomboxNetId = nil
local currentSoundId = nil
local currentVolume = Config.DefaultVolume
local currentDistance = Config.DefaultDistance
local spawnedBoomboxes = {}
local targetedBoomboxes = {}
local useOxTarget = Config.UseOxTarget ~= false and GetResourceState('ox_target') == 'started'

lib.locale()

local function nui(data)
    SendNUIMessage(data)
end

local function nuiLocales()
    return {
        title = locale('ui_title'),
        status_playing = locale('ui_status_playing'),
        status_paused = locale('ui_status_paused'),
        status_inactive = locale('ui_status_inactive'),
        stream_url = locale('ui_stream_url'),
        playback = locale('ui_playback'),
        volume = locale('ui_volume'),
        distance = locale('ui_distance'),
        actions = locale('ui_actions'),
        play_url = locale('ui_play_url'),
        add_to_queue = locale('ui_add_to_queue'),
        pause_playback = locale('ui_pause_playback'),
        resume_playback = locale('ui_resume_playback'),
        stop_playback = locale('ui_stop_playback'),
        queue = locale('ui_queue'),
        queue_track_singular = locale('ui_queue_track_singular'),
        queue_track_plural = locale('ui_queue_track_plural'),
        queued_track = locale('ui_queued_track'),
        youtube_video = locale('ui_youtube_video'),
        play_now = locale('ui_play_now'),
        remove_from_queue = locale('ui_remove_from_queue'),
        close = locale('ui_close'),
    }
end

local function drawText3d(coords, text)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z + 0.35)

    if not onScreen then
        return
    end

    SetTextScale(0.30, 0.30)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(245, 245, 245, 230)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

local function getPlaybackTime()
    if not currentSoundId or not exports.xsound:soundExists(currentSoundId) then
        return 0, 0, false
    end

    local timestamp = exports.xsound:getTimeStamp(currentSoundId)
    local duration = exports.xsound:getMaxDuration(currentSoundId)

    if timestamp == nil or timestamp < 0 then
        timestamp = 0
    end

    if duration == nil or duration < 0 then
        duration = 0
    end

    return timestamp, duration, true
end

local function setOpen(state, netId)
    isOpen = state
    SetNuiFocus(state, state)

    if state then
        activeBoomboxNetId = netId
        nui({
            action = 'open',
            locales = nuiLocales(),
            volume = currentVolume,
            distance = currentDistance,
            soundId = currentSoundId,
            netId = activeBoomboxNetId,
        })
        TriggerServerEvent('ejj_boombox:server:requestState', activeBoomboxNetId)
        return
    end

    nui({
        action = 'close',
    })
end

local function openBoombox(netId)
    netId = tonumber(netId)

    if not netId then
        return
    end

    setOpen(true, netId)
end

local function targetOptionNames(netId)
    return {
        ('ejj_boombox:open:%s'):format(netId),
        ('ejj_boombox:pickup:%s'):format(netId),
    }
end

local function registerTarget(entity, netId)
    if targetedBoomboxes[netId] then
        return
    end

    targetedBoomboxes[netId] = true

    if not useOxTarget then
        return
    end

    exports.ox_target:addEntity(netId, {
        {
            name = ('ejj_boombox:open:%s'):format(netId),
            label = locale('target_open'),
            icon = 'fa-solid fa-radio',
            distance = Config.TargetDistance,
            onSelect = function(data)
                local selectedNetId = netId

                if data and data.entity and DoesEntityExist(data.entity) then
                    selectedNetId = NetworkGetNetworkIdFromEntity(data.entity)
                end

                openBoombox(selectedNetId)
            end,
        },
        {
            name = ('ejj_boombox:pickup:%s'):format(netId),
            label = locale('target_pickup'),
            icon = 'fa-solid fa-trash',
            distance = Config.TargetDistance,
            onSelect = function(data)
                local selectedNetId = netId

                if data and data.entity and DoesEntityExist(data.entity) then
                    selectedNetId = NetworkGetNetworkIdFromEntity(data.entity)
                end

                TriggerServerEvent('ejj_boombox:server:pickupBoombox', selectedNetId)
            end,
        },
    })
end

local function placeBoombox()
    local model = Config.Model
    local hash = joaat(model)

    lib.requestModel(model)

    local ped = cache.ped

    if not ped or ped == 0 then
        SetModelAsNoLongerNeeded(hash)
        return nil
    end

    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, Config.PlaceDistance, 0.0)
    local object = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)

    if not object or object == 0 then
        SetModelAsNoLongerNeeded(hash)
        return nil
    end

    SetEntityHeading(object, GetEntityHeading(ped))
    PlaceObjectOnGroundProperly(object)
    FreezeEntityPosition(object, true)
    SetEntityAsMissionEntity(object, true, true)

    local netId = NetworkGetNetworkIdFromEntity(object)

    SetNetworkIdCanMigrate(netId, true)
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetModelAsNoLongerNeeded(hash)

    spawnedBoomboxes[netId] = object
    registerTarget(object, netId)
    TriggerServerEvent('ejj_boombox:server:registerBoombox', netId)

    return netId
end

RegisterNetEvent('ejj_boombox:client:place', function()
    placeBoombox()
end)

exports('placeBoombox', function(data)
    exports.ox_inventory:useItem(data, function(used)
        if used then
            local netId = placeBoombox()

            if netId then
                TriggerServerEvent('ejj_boombox:server:consumeBoomboxItem', netId)
            end
        end
    end)
end)

RegisterNetEvent('ejj_boombox:client:removeTarget', function(netId)
    netId = tonumber(netId)

    if not netId then
        return
    end

    if useOxTarget then
        exports.ox_target:removeEntity(netId, targetOptionNames(netId))
    end

    targetedBoomboxes[netId] = nil

    if spawnedBoomboxes[netId] and DoesEntityExist(spawnedBoomboxes[netId]) then
        DeleteEntity(spawnedBoomboxes[netId])
    end

    spawnedBoomboxes[netId] = nil

    if activeBoomboxNetId == netId then
        setOpen(false)
        activeBoomboxNetId = nil
        currentSoundId = nil
    end
end)

RegisterNetEvent('ejj_boombox:client:registerTarget', function(netId)
    netId = tonumber(netId)

    if not netId or targetedBoomboxes[netId] then
        return
    end

    CreateThread(function()
        local entity = NetworkGetEntityFromNetworkId(netId)
        local attempts = 0

        while (not entity or entity == 0 or not DoesEntityExist(entity)) and attempts < 50 do
            Wait(100)
            entity = NetworkGetEntityFromNetworkId(netId)
            attempts = attempts + 1
        end

        if entity and entity ~= 0 and DoesEntityExist(entity) then
            registerTarget(entity, netId)
        end
    end)
end)

CreateThread(function()
    Wait(1000)
    TriggerServerEvent('ejj_boombox:server:requestTargets')
end)

local function getClosestKnownBoombox()
    local ped = cache.ped

    if not ped or ped == 0 then
        return nil, nil
    end

    local playerCoords = GetEntityCoords(ped)
    local closestObject = lib.getClosestObject(playerCoords, Config.TargetDistance)

    if closestObject and closestObject ~= 0 and DoesEntityExist(closestObject) and GetEntityModel(closestObject) == joaat(Config.Model) then
        local netId = NetworkGetNetworkIdFromEntity(closestObject)

        if targetedBoomboxes[netId] then
            return closestObject, netId
        end
    end

    local closestEntity = nil
    local closestNetId = nil
    local closestDistance = Config.TargetDistance or 2.0

    for netId in pairs(targetedBoomboxes) do
        local entity = NetworkGetEntityFromNetworkId(netId)

        if entity and entity ~= 0 and DoesEntityExist(entity) then
            local coords = GetEntityCoords(entity)
            local distance = #(playerCoords - coords)

            if distance <= closestDistance then
                closestEntity = entity
                closestNetId = netId
                closestDistance = distance
            end
        end
    end

    return closestEntity, closestNetId
end

if not useOxTarget then
    CreateThread(function()
        while true do
            local wait = 500
            local entity, netId = getClosestKnownBoombox()

            if entity and netId then
                wait = 0
                local coords = GetEntityCoords(entity)

                drawText3d(coords, locale('fallback_prompt'))

                if IsControlJustPressed(0, Config.OpenControl or 38) then
                    openBoombox(netId)
                elseif IsControlJustPressed(0, Config.PickupControl or 47) then
                    TriggerServerEvent('ejj_boombox:server:pickupBoombox', netId)
                end
            end

            Wait(wait)
        end
    end)
end

if Config.EnableCommand then
    RegisterCommand(Config.Command, function()
        placeBoombox()
    end, false)
end

RegisterNUICallback('close', function(_, cb)
    setOpen(false)
    cb({ ok = true })
end)

RegisterNUICallback('play', function(data, cb)
    local url = data and data.url
    local volume = tonumber(data and data.volume) or currentVolume

    if not activeBoomboxNetId then
        cb({ ok = false, error = 'missing_boombox' })
        return
    end

    if type(url) ~= 'string' or url == '' then
        cb({ ok = false, error = 'missing_url' })
        return
    end

    currentVolume = math.max(0.0, math.min(1.0, volume))

    TriggerServerEvent('ejj_boombox:server:play', {
        netId = activeBoomboxNetId,
        url = url,
        volume = currentVolume,
    })

    cb({ ok = true })
end)

RegisterNUICallback('addQueue', function(data, cb)
    local url = data and data.url

    if not activeBoomboxNetId then
        cb({ ok = false, error = 'missing_boombox' })
        return
    end

    if type(url) ~= 'string' or url == '' then
        cb({ ok = false, error = 'missing_url' })
        return
    end

    TriggerServerEvent('ejj_boombox:server:addQueue', {
        netId = activeBoomboxNetId,
        url = url,
    })

    cb({ ok = true })
end)

RegisterNUICallback('playQueueItem', function(data, cb)
    local index = tonumber(data and data.index)

    if not activeBoomboxNetId then
        cb({ ok = false, error = 'missing_boombox' })
        return
    end

    if index == nil then
        cb({ ok = false, error = 'missing_index' })
        return
    end

    TriggerServerEvent('ejj_boombox:server:playQueueItem', {
        netId = activeBoomboxNetId,
        index = math.floor(index),
    })

    cb({ ok = true })
end)

RegisterNUICallback('removeQueueItem', function(data, cb)
    local index = tonumber(data and data.index)

    if not activeBoomboxNetId then
        cb({ ok = false, error = 'missing_boombox' })
        return
    end

    if index == nil then
        cb({ ok = false, error = 'missing_index' })
        return
    end

    TriggerServerEvent('ejj_boombox:server:removeQueueItem', {
        netId = activeBoomboxNetId,
        index = math.floor(index),
    })

    cb({ ok = true })
end)

RegisterNUICallback('pause', function(_, cb)
    if activeBoomboxNetId then
        TriggerServerEvent('ejj_boombox:server:pause', activeBoomboxNetId)
    end

    cb({ ok = true })
end)

RegisterNUICallback('resume', function(_, cb)
    if activeBoomboxNetId then
        TriggerServerEvent('ejj_boombox:server:resume', activeBoomboxNetId)
    end

    cb({ ok = true })
end)

RegisterNUICallback('stop', function(_, cb)
    if activeBoomboxNetId then
        TriggerServerEvent('ejj_boombox:server:stop', activeBoomboxNetId)
    end

    cb({ ok = true })
end)

RegisterNUICallback('volume', function(data, cb)
    local volume = tonumber(data and data.volume) or currentVolume
    currentVolume = math.max(0.0, math.min(1.0, volume))

    if activeBoomboxNetId then
        TriggerServerEvent('ejj_boombox:server:volume', {
            netId = activeBoomboxNetId,
            volume = currentVolume,
        })
    end

    cb({ ok = true })
end)

RegisterNUICallback('distance', function(data, cb)
    local distance = tonumber(data and data.distance) or currentDistance
    currentDistance = math.max(Config.MinDistance, math.min(Config.MaxDistance, distance))

    if activeBoomboxNetId then
        TriggerServerEvent('ejj_boombox:server:distance', {
            netId = activeBoomboxNetId,
            distance = currentDistance,
        })
    end

    cb({ ok = true })
end)

RegisterNUICallback('seek', function(data, cb)
    local timestamp = tonumber(data and data.timestamp)

    if not activeBoomboxNetId then
        cb({ ok = false, error = 'missing_boombox' })
        return
    end

    if timestamp == nil then
        cb({ ok = false, error = 'missing_timestamp' })
        return
    end

    TriggerServerEvent('ejj_boombox:server:seek', {
        netId = activeBoomboxNetId,
        timestamp = math.max(0.0, timestamp),
    })

    cb({ ok = true })
end)

RegisterNetEvent('ejj_boombox:client:state', function(state)
    if type(state) ~= 'table' then
        return
    end

    activeBoomboxNetId = state.netId or activeBoomboxNetId
    currentSoundId = state.soundId or currentSoundId
    currentVolume = state.volume or currentVolume
    currentDistance = state.distance or currentDistance
    local timestamp, duration, hasSound = getPlaybackTime()

    if state.timestamp ~= nil and (not hasSound or not state.playing) then
        timestamp = state.timestamp
    end

    nui({
        action = 'state',
        locales = nuiLocales(),
        netId = activeBoomboxNetId,
        soundId = currentSoundId,
        volume = currentVolume,
        distance = currentDistance,
        playing = state.playing,
        paused = state.paused,
        url = state.url,
        title = state.title,
        queue = state.queue,
        timestamp = timestamp,
        duration = duration,
    })
end)

AddEventHandler('xSound:songStopPlaying', function(soundId)
    if soundId == currentSoundId and activeBoomboxNetId then
        CreateThread(function()
            Wait(250)
            TriggerServerEvent('ejj_boombox:server:finished', {
                netId = activeBoomboxNetId,
                soundId = soundId,
            })
        end)
    end
end)

CreateThread(function()
    while true do
        if isOpen and currentSoundId then
            local timestamp, duration = getPlaybackTime()

            nui({
                action = 'progress',
                timestamp = timestamp,
                duration = duration,
            })
        end

        Wait(isOpen and 1000 or 750)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for netId in pairs(targetedBoomboxes) do
        if useOxTarget then
            exports.ox_target:removeEntity(netId, targetOptionNames(netId))
        end
    end

    for _, entity in pairs(spawnedBoomboxes) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
end)
