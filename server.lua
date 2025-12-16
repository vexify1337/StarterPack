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

