local utils = require 'modules.utils'

local function debugPrint(...)
    if Config and Config.Debug then
        print('[rm-billing]', ...)
    end
end

local function openInvoiceUI(preselectedServerId)
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
        data = { nearbyPlayers = formattedPlayers, preselectedPlayerId = preselectedServerId }
    })

    local plyInvoices = lib.callback.await('rm-billing:getPlayerInvoices')
    SendNUIMessage({
        action = 'setPlayerInvoices',
        data = { invoices = plyInvoices }
    })
end

RegisterNuiCallback('hideApp', function(data, cb)
    utils.ShowNUI('UPDATE_VISIBILITY', false)
    cb(true)
end)

-- Register command only if enabled
CreateThread(function()
    if Config and Config.Command and type(Config.Command) == 'string' and Config.Command ~= '' then
        RegisterCommand(Config.Command, function()
            debugPrint('Invoice command triggered')
            local allowed = lib.callback.await('rm-billing:checkCreateInvoicePermission', false)
            if not allowed then
                if lib and lib.notify then
                    lib.notify({ type = 'error', description = 'You do not have permission to create invoices.' })
                end
                return
            end
            openInvoiceUI(nil)
        end, false)
    end
end)

-- Target integration (ox_target)
CreateThread(function()
    if not (Config and Config.TargetInvoice) then return end
    local state = GetResourceState and GetResourceState('ox_target') or 'missing'
    if state ~= 'started' and state ~= 'starting' then
        debugPrint('ox_target not running; skipping target integration')
        return
    end

    if exports and exports.ox_target and exports.ox_target.addGlobalPlayer then
        exports.ox_target:addGlobalPlayer({
            {
                name = 'rm_billing_invoice_player',
                icon = 'fa-solid fa-file-invoice-dollar',
                label = 'Create Invoice',
                distance = 3.0,
                canInteract = function(entity, distance, coords, name, bone)
                    if not entity or not DoesEntityExist(entity) then return false end
                    return distance and distance <= 3.0
                end,
                onSelect = function(data)
                    local allowed = lib.callback.await('rm-billing:checkCreateInvoicePermission', false)
                    if not allowed then
                        if lib and lib.notify then
                            lib.notify({ type = 'error', description = 'You do not have permission to create invoices.' })
                        end
                        return
                    end

                    local targetEntity = data and data.entity
                    local serverId
                    if targetEntity and NetworkGetPlayerIndexFromPed then
                        local playerIdx = NetworkGetPlayerIndexFromPed(targetEntity)
                        if playerIdx ~= -1 then
                            serverId = GetPlayerServerId(playerIdx)
                        end
                    end
                    if not serverId and data and data.serverId then
                        serverId = data.serverId
                    end

                    -- Additional safety: verify distance at selection time (<= 5.0m)
                    if targetEntity and DoesEntityExist(targetEntity) then
                        local myCoords = GetEntityCoords(cache.ped)
                        local tgtCoords = GetEntityCoords(targetEntity)
                        local dist = #(myCoords - tgtCoords)
                        if dist > 5.0 then
                            if lib and lib.notify then
                                lib.notify({ type = 'error', description = 'Move closer to the player to issue an invoice.' })
                            end
                            return
                        end
                    end

                    openInvoiceUI(serverId)
                end
            }
        })
    else
        debugPrint('exports.ox_target.addGlobalPlayer unavailable; skipping target integration')
    end
end)

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