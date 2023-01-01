local QBCore = exports['qb-core']:GetCoreObject()

isPolice = false
closestStinger = 0

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
        event = 'loaf_spikestrips:removeSpikestrip',
        icon = "fa fa fa-circle",
        label = "Remove Spikes",
        job = Config.JobRemove,
      },
    },
    distance = 2.0
})