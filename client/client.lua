local utils = require 'modules.utils'

local function debugPrint(...)
    if Config and Config.Debug then
        print('[rm-billing]', ...)
    end
end

RegisterNuiCallback('hideApp', function(data, cb)
    utils.ShowNUI('UPDATE_VISIBILITY', false)
    cb(true)
end)

RegisterCommand('invoice', function()
    debugPrint('Invoice command triggered')
    SetNuiFocus(true, true)
    lib.callback('rm-billing:checkCreateInvoicePermission', false, function(allowed)
        SendNUIMessage({
            action = 'setCreateInvoicePermission',
            data = { allowed = allowed }
        })
    end)

    lib.callback('rm-billing:checkSearchInvoicePermission', false, function(allowed)
        SendNUIMessage({
            action = 'setSearchInvoicePermission',
            data = { allowed = allowed }
        })
    end)

    local playerCoords = GetEntityCoords(cache.ped)
    local nearbyPlayers = lib.getNearbyPlayers(playerCoords, 5.0, true)

    local formattedPlayers = {}
    for _, player in pairs(nearbyPlayers) do
        local serverId = GetPlayerServerId(player.id)
        if serverId then
            table.insert(formattedPlayers, {
                id = serverId,
                name = "Player ID: ",
                distance = math.floor(#(playerCoords - player.coords) * 100) / 100
            })
        end
    end

    debugPrint('Found nearby players:', json.encode(formattedPlayers))

    SendNUIMessage({
        action = 'showUI',
        data = { nearbyPlayers = formattedPlayers }
    })


    local plyInvoices = lib.callback.await('rm-billing:getPlayerInvoices')
    SendNUIMessage({
        action = 'setPlayerInvoices',
        data = { invoices = plyInvoices }
    })
end, false)

RegisterNUICallback('createInvoice', function(data, cb)
    debugPrint('Create invoice callback triggered with data:', json.encode(data))
    TriggerServerEvent('rm-billing:createInvoice', data)
    cb('ok')
end)

RegisterNUICallback('payInvoice', function(data, cb)
    debugPrint('Pay invoice callback triggered with data:', json.encode(data))
    local success = lib.callback.await('rm-billing:payInvoice', false, data.invoiceId)
    cb({ success = success })
end)

RegisterNUICallback('searchPlayerInvoices', function(data, cb)
    debugPrint('Search player invoices callback triggered with data:', json.encode(data))
    cb('ok')
    local invoiceData = lib.callback.await("rm-billing:server:searchPlyInvoices", false, data)
    SendNUIMessage({
        action = 'setSearchedPlayerInvoices',
        data = invoiceData
    })
end)

RegisterNUICallback('hideUI', function(data, cb)
    debugPrint('Hide UI callback triggered')
    SetNuiFocus(false, false)
    cb('ok')
end)