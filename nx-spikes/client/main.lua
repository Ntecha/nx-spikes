local QBCore = exports['qb-core']:GetCoreObject()

local allowed = false
local closestStinger = 0
local wheels = {
    ["wheel_lf"] = 0,
    ["wheel_rf"] = 1,
    ["wheel_lm"] = 2,
    ["wheel_rm"] = 3,
    ["wheel_lr"] = 4,
    ["wheel_rr"] = 5,
}

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    local Player = QBCore.Functions.GetPlayerData()
    local job = Player.job.name
    for k, v in pairs(Config.AllowedJobs) do
        if v == job then
            allowed = true
        end
    end
end)


-- functions
local function LoadDict(Dict)
    while not HasAnimDictLoaded(Dict) do
        Wait(0)
        RequestAnimDict(Dict)
    end
    return Dict
end

local function LoadModel(model)
    model = type(model) == "string" and GetHashKey(model) or model
    if not HasModelLoaded(model) and IsModelInCdimage(model) then
        local timer = GetGameTimer() + 20000 -- 20 seconds to load
        RequestModel(model)
        while not HasModelLoaded(model) and timer >= GetGameTimer() do -- wait for the model to load
            Wait(50)
        end
    end
    return { loaded = HasModelLoaded(model), model = model }
end

local function DeployStinger()
    local stinger = CreateObject(LoadModel("p_ld_stinger_s").model,
        GetOffsetFromEntityInWorldCoords(PlayerPedId(), -0.2, 2.0, 0.0), true, true, 0)
    SetEntityAsMissionEntity(stinger, true, true)
    SetEntityHeading(stinger, GetEntityHeading(PlayerPedId()))
    FreezeEntityPosition(stinger, true)
    PlaceObjectOnGroundProperly(stinger)
    SetEntityVisible(stinger, false)

    -- init scene
    local scene = NetworkCreateSynchronisedScene(GetEntityCoords(PlayerPedId()), GetEntityRotation(PlayerPedId(), 2), 2,
        false, false, 1065353216, 0, 1.0)
    NetworkAddPedToSynchronisedScene(PlayerPedId(), scene, LoadDict("amb@medic@standing@kneel@enter"), "enter", 8.0, -
        8.0, 3341, 16, 1148846080, 0)
    NetworkStartSynchronisedScene(scene)
    -- wait for the scene to start
    while not IsSynchronizedSceneRunning(NetworkConvertSynchronisedSceneToSynchronizedScene(scene)) do
        Wait(0)
    end
    -- make the scene faster (looks better)
    SetSynchronizedSceneRate(NetworkConvertSynchronisedSceneToSynchronizedScene(scene), 3.0)
    -- wait a bit
    while GetSynchronizedScenePhase(NetworkConvertSynchronisedSceneToSynchronizedScene(scene)) < 0.14 do
        Wait(0)
    end
    -- stop the scene early
    NetworkStopSynchronisedScene(scene)

    -- play deploy animation for stinger
    PlayEntityAnim(stinger, "P_Stinger_S_Deploy", LoadDict("p_ld_stinger_s"), 1000.0, false, true, 0, 0.0, 0)
    while not IsEntityPlayingAnim(stinger, "p_ld_stinger_s", "P_Stinger_S_Deploy", 3) do
        Wait(0)
    end
    SetEntityVisible(stinger, true)
    while IsEntityPlayingAnim(stinger, "p_ld_stinger_s", "P_Stinger_S_Deploy", 3) and
        GetEntityAnimCurrentTime(stinger, "p_ld_stinger_s", "P_Stinger_S_Deploy") <= 0.99 do
        Wait(0)
    end
    PlayEntityAnim(stinger, "p_stinger_s_idle_deployed", LoadDict("p_ld_stinger_s"), 1000.0, false, true, 0, 0.99, 0)

    return stinger
end

local function RemoveStinger()
    if DoesEntityExist(closestStinger) then
        NetworkRequestControlOfEntity(closestStinger)
        SetEntityAsMissionEntity(closestStinger, true, true)
        DeleteEntity(closestStinger)

        Wait(250)
        if not DoesEntityExist(closestStinger) then
            TriggerServerEvent("nx-spikes:server:pickupspikes")
        end
    end
end

local function TouchingStinger(coords, stinger)
    local min, max = GetModelDimensions(GetEntityModel(stinger))
    local size = max - min
    local w, l, h = size.x, size.y, size.z

    local offset1 = GetOffsetFromEntityInWorldCoords(stinger, 0.0, l / 2, h * -1)
    local offset2 = GetOffsetFromEntityInWorldCoords(stinger, 0.0, l / 2 * -1, h)

    return IsPointInAngledArea(coords, offset1, offset2, w * 2, 0, false)
end

-- events
RegisterNetEvent("nx-spikes:client:usespikes", function()
    local ped = PlayerPedId()
    local player = QBCore.Functions.GetPlayerData()
    if not IsPedInAnyVehicle(ped, false) then
        if allowed then
            DeployStinger()
            TriggerServerEvent('nx-spikes:server:removespikes')
        else
            QBCore.Functions.Notify('You are not trained to use this', 'error', 7500)
        end
    else
        QBCore.Functions.Notify('You can\'t use spikes while in a vehicle', 'error', 7500)
    end
end)

RegisterNetEvent("nx-spikes:client:removespikes", function()
    RemoveStinger()
end)


-- thread to find the closest stinger / spikestrip
Citizen.CreateThread(function()
    while true do
        local driving = DoesEntityExist(GetVehiclePedIsUsing(PlayerPedId()))
        Wait((driving and 50) or 1000)
        local coords = GetEntityCoords((driving and GetVehiclePedIsUsing(PlayerPedId())) or PlayerPedId())

        local stinger = GetClosestObjectOfType(coords, 10.0, GetHashKey("p_ld_stinger_s"), false, false, false)
        if DoesEntityExist(stinger) then
            closestStinger = stinger
            closestStingerDistance = #(coords - GetEntityCoords(stinger))
        end

        if not DoesEntityExist(closestStinger) or #(coords - GetEntityCoords(closestStinger)) > 10.0 then
            closestStinger = 0
        end
    end
end)

-- This while loop manages bursting tyres.
CreateThread(function()
    while true do
        Wait(1500)
        while DoesEntityExist(GetVehiclePedIsUsing(PlayerPedId())) do
            Wait(50)
            local vehicle = GetVehiclePedIsUsing(PlayerPedId())
            while DoesEntityExist(closestStinger) and closestStingerDistance <= 5.0 do
                Wait(5)
                if IsEntityTouchingEntity(vehicle, closestStinger) then
                    for boneName, wheelId in pairs(wheels) do
                        if not IsVehicleTyreBurst(vehicle, wheelId, false) then
                            if TouchingStinger(GetWorldPositionOfEntityBone(vehicle,
                                GetEntityBoneIndexByName(vehicle, boneName)), closestStinger) then
                                SetVehicleTyreBurst(vehicle, wheelId, 1, 1148846080)
                            end
                        end
                    end
                end
            end
        end
    end
end)


exports['qb-target']:AddTargetModel('p_ld_stinger_s', {
    options = {
        {
            num = 1,
            event = 'nx-spikes:client:removespikes',
            icon = "fa fa fa-circle",
            label = "Remove Spikes",
            canInteract = function()
                if allowed then return true end
            end
        },
    },
    distance = 2.0
})
