local QBCore = nil
local ESX = nil

local function get_player_identifier(source)
    local bridge = exports['s6la_bridge']:ret_bridge_table()
    if bridge and bridge.framework == 'qb-core' and QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            return Player.PlayerData.citizenid
        end
    elseif bridge and bridge.framework == 'es_extended' and ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            return xPlayer.identifier
        end
    end
    return nil
end

local function pay_player(source, amount, payment_type)
    payment_type = payment_type or 'bank'
    local bridge = exports['s6la_bridge']:ret_bridge_table()
    
    if bridge and bridge.framework == 'qb-core' and QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            if payment_type == 'bank' then
                Player.Functions.AddMoney('bank', amount, 'starterpack')
            else
                Player.Functions.AddMoney('cash', amount, 'starterpack')
            end
            return true
        end
    elseif bridge and bridge.framework == 'es_extended' and ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            if payment_type == 'bank' then
                xPlayer.addAccountMoney('bank', amount)
            else
                xPlayer.addMoney(amount)
            end
            return true
        end
    end
    return false
end

CreateThread(function()
    Wait(1000)
    local bridge = exports['s6la_bridge']:ret_bridge_table()
    if bridge and bridge.framework == 'qb-core' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif bridge and bridge.framework == 'es_extended' then
        ESX = exports['es_extended']:getSharedObject()
    end
end)
RegisterCommand('starterpack', function(source, args, rawCommand)
    local source = source
    local citizenid = get_player_identifier(source)
    if not citizenid then
        exports['s6la_bridge']:notify(source, 'Unable to identify your character.', 'error', 5000)
        return
    end
    
    MySQL.Async.fetchAll('SELECT * FROM construction_starterpack WHERE citizenid = @citizenid', {
        ['@citizenid'] = citizenid
    }, function(result)
        if result and result[1] and result[1].claimed == 1 then
            exports['s6la_bridge']:notify(source, 'You have already claimed your starter pack!', 'error', 5000)
            return
        end
        
        if result and result[1] then
            MySQL.Async.execute('UPDATE construction_starterpack SET claimed = 1, claimed_at = NOW() WHERE citizenid = @citizenid', {
                ['@citizenid'] = citizenid
            }, function(rows_changed)
                if rows_changed > 0 then
                    give_starterpack(source, citizenid)
                end
            end)
        else
            MySQL.Async.insert('INSERT INTO construction_starterpack (citizenid, claimed, claimed_at) VALUES (@citizenid, 1, NOW())', {
                ['@citizenid'] = citizenid
            }, function(insert_id)
                if insert_id then
                    give_starterpack(source, citizenid)
                end
            end)
        end
    end)
end, false)

function give_starterpack(source, citizenid)
    pay_player(source, 2000, 'cash')
    
    exports['s6la_bridge']:add_item(source, 'sandwich', 5)
    exports['s6la_bridge']:add_item(source, 'beer', 5)
    
    TriggerClientEvent('s6la_construction:spawn_starterpack_vehicle', source)
    
    exports['s6la_bridge']:notify(source, 'Thank you for playing S6LA! This is a starter pack to get you started off in the city. We hope you enjoy!', 'success', 8000)
    
    if Config.debug then
        print(string.format('[Construction] Starter pack given to player %s (citizenid: %s)', source, citizenid))
    end
end

