local QBCore = exports["qb-core"]:GetCoreObject()

QBCore.Functions.CreateUseableItem('spikestrip', function(src)
    TriggerClientEvent("nx-spikes:client:usespikes", src)
end)

RegisterNetEvent('nx-spikes:server:removespikes', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    Player.Functions.RemoveItem('spikestrip', 1)
end)

RegisterNetEvent("nx-spikes:server:pickupspikes", function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.name == 'police' then 
        Player.Functions.AddItem('spikestrip', 1)
    end
end)