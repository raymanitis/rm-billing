local function debugPrint(...)
    if Config.Debug then
        print('[rm-billing]', ...)
    end
end

local function getCharacterName(playerId)
    local isId = false
    if tonumber(playerId) then
        playerId = tonumber(playerId)
        isId = true
    end
    debugPrint('Getting character name for player ID:', playerId)

    local player
    if isId then
        player = exports.qbx_core:GetPlayer(playerId)
    else
        player = exports.qbx_core:GetPlayerByCitizenId(playerId)
    end
    if player then
        local charinfo = player.PlayerData.charinfo
        debugPrint('Using player data charinfo name:', charinfo.firstname .. ' ' .. charinfo.lastname)
        return charinfo.firstname .. ' ' .. charinfo.lastname
    end

    local db = MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', { playerId })
    if db then
        db = json.decode(db)
        return db.firstname .. " " .. db.lastname
    end

    local playerName = GetPlayerName(playerId) or 'Unknown Player'
    debugPrint('Using fallback player name:', playerName)
    return playerName
end

local function updateExistingInvoicesToCharacterNames()
    debugPrint('Updating existing invoices to use character names...')

    MySQL.query('SELECT DISTINCT from_player, to_player FROM rm_invoices', {}, function(result)
        if result then
            debugPrint('Found', #result, 'unique player combinations to update')

            for _, row in ipairs(result) do
                local fromPlayer = row.from_player
                local toPlayer = row.to_player

                local fromName = getCharacterName(fromPlayer)
                local toName = getCharacterName(toPlayer)

                MySQL.update('UPDATE rm_invoices SET from_name = ?, to_name = ? WHERE from_player = ? AND to_player = ?', {
                    fromName, toName, fromPlayer, toPlayer
                }, function(affectedRows)
                    if affectedRows and affectedRows > 0 then
                        debugPrint('Updated', affectedRows, 'invoices for players', fromPlayer, '->', toPlayer, 'with names:', fromName, '->', toName)
                    end
                end)
            end
        else
            debugPrint('No existing invoices found to update')
        end
    end)
end

CreateThread(function()
    local success = pcall(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `rm_invoices` (
                `id` int(11) NOT NULL AUTO_INCREMENT,
                `invoice_id` varchar(10) NOT NULL,
                `from_player` int(11) NOT NULL,
                `to_player` int(11) NOT NULL,
                `from_name` varchar(255) NOT NULL,
                `to_name` varchar(255) NOT NULL,
                `reason` text NOT NULL,
                `amount` int(11) NOT NULL,
                `status` enum('pending','paid','cancelled') NOT NULL DEFAULT 'pending',
                `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `paid_at` timestamp NULL DEFAULT NULL,
                PRIMARY KEY (`id`),
                UNIQUE KEY `invoice_id` (`invoice_id`),
                KEY `from_player` (`from_player`),
                KEY `to_player` (`to_player`),
                KEY `status` (`status`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]])
    end)

    if success then
        debugPrint('Database table setup completed successfully')
        Wait(2000)
        updateExistingInvoicesToCharacterNames()
    else
        print('[rm-billing] ERROR: Failed to setup database table')
    end
end)

if not Config or not Config.AllowedJobs then
    print('[rm-billing] ERROR: Config not loaded properly!')
    print('[rm-billing] Config type:', type(Config))
    print('[rm-billing] Config content:', json.encode(Config or {}))
    return
end

debugPrint('Config loaded successfully')
debugPrint('Allowed jobs:', json.encode(Config.AllowedJobs))

local function isJobInList(job, list)
    for _, v in ipairs(list) do
        if v == job then return true end
    end
    return false
end

local function generateInvoiceId()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    :: start ::
    local invoiceId = ""
    for i = 1, 7 do
        local rand = math.random(1, #chars)
        invoiceId = invoiceId .. string.sub(chars, rand, rand)
    end
    if MySQL.scalar.await("SELECT invoice_id FROM rm_invoices WHERE invoice_id = ?", { invoiceId }) then
        goto start
    end
    return invoiceId
end

local function getCommissionPercentForJob(jobName)
    if not jobName or not Config.EmployeeCommissionByJob then return 0 end
    local configured = Config.EmployeeCommissionByJob[jobName]
    if type(configured) ~= 'number' then return 0 end
    if configured < 0 then return 0 end
    if configured > 100 then return 100 end
    return math.floor(configured)
end

local function logInvoiceCreated(issuerPlayer, targetPlayer, invoiceData)
    if not Config.LogInvoices then return end
    
    exports['atleast_logs']:CreateLog({
        category = "invoice-logs",
        title = "Invoice Created - " .. invoiceData.invoice_id,
        action = "Amount: $" .. invoiceData.amount .. " | Status: " .. invoiceData.status,
        color = "blue",
        players = {
            { id = issuerPlayer.PlayerData.source, role = "Issuer" },
            { id = targetPlayer.PlayerData.source, role = "Target" },
        },
        info = {
            { name = "Invoice ID", value = invoiceData.invoice_id },
            { name = "Issuer", value = issuerPlayer.PlayerData.charinfo.firstname .. " " .. issuerPlayer.PlayerData.charinfo.lastname },
            { name = "Issuer Job", value = issuerPlayer.PlayerData.job.label .. " - " .. issuerPlayer.PlayerData.job.grade.name },
            { name = "Target", value = targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname },
            { name = "Target Job", value = targetPlayer.PlayerData.job.label .. " - " .. issuerPlayer.PlayerData.job.grade.name },
            { name = "Amount", value = "$" .. invoiceData.amount },
            { name = "Reason", value = invoiceData.reason },
            { name = "Status", value = invoiceData.status },
            { name = "Created At", value = os.date("%Y-%m-%d %H:%M:%S") },
        },
    })
end

local function logInvoicePaid(issuerPlayer, targetPlayer, invoiceData, splitResult)
    if not Config.LogInvoices then return end
    
    local splitInfo = ""
    if splitResult and splitResult.percent and splitResult.percent > 0 then
        splitInfo = string.format(" | Employee: $%d (%d%%) | Organization: $%d", 
            splitResult.playerShare, splitResult.percent, splitResult.orgShare)
    end
    
    exports['atleast_logs']:CreateLog({
        category = "invoice-logs",
        title = "Invoice Paid - " .. invoiceData.invoice_id,
        action = "Payment: $" .. invoiceData.amount .. splitInfo,
        color = "green",
        players = {
            { id = issuerPlayer.PlayerData.source, role = "Issuer" },
            { id = targetPlayer.PlayerData.source, role = "Payer" },
        },
        info = {
            { name = "Invoice ID", value = invoiceData.invoice_id },
            { name = "Issuer", value = issuerPlayer.PlayerData.charinfo.firstname .. " " .. issuerPlayer.PlayerData.charinfo.lastname },
            { name = "Issuer Job", value = issuerPlayer.PlayerData.job.label .. " - " .. issuerPlayer.PlayerData.job.grade.name },
            { name = "Payer", value = targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname },
            { name = "Payer Job", value = targetPlayer.PlayerData.job.label .. " - " .. targetPlayer.PlayerData.job.grade.name },
            { name = "Amount", value = "$" .. invoiceData.amount },
            { name = "Reason", value = invoiceData.reason },
            { name = "Paid At", value = os.date("%Y-%m-%d %H:%M:%S") },
        },
    })
end

local function distributeInvoiceFunds(issuerCitizenId, jobName, amount, invoiceId)
    local percent = getCommissionPercentForJob(jobName)
    local playerShare = 0
    local orgShare = amount

    if percent > 0 then
        playerShare = math.floor((amount * percent) / 100)
        if playerShare < 0 then playerShare = 0 end
        if playerShare > amount then playerShare = amount end
        orgShare = amount - playerShare
    end

    local issuer = exports.qbx_core:GetPlayerByCitizenId(issuerCitizenId)
    local issuerOnline = issuer ~= nil

    if playerShare > 0 and issuerOnline then
        exports.qbx_core:AddMoney(issuer.PlayerData.source, 'bank', playerShare, 'Invoice Commission (' .. (invoiceId or 'N/A') .. ')')
        debugPrint('Paid employee commission to', issuerCitizenId, 'amount:', playerShare, 'percent:', percent)
    end

    if orgShare > 0 then
        if jobName then
            exports['Renewed-Banking']:addAccountMoney(jobName, orgShare)
            debugPrint('Paid organization share to', jobName, 'amount:', orgShare)
        elseif issuerOnline then
            exports.qbx_core:AddMoney(issuer.PlayerData.source, 'bank', orgShare, 'Invoice Payment (' .. (invoiceId or 'N/A') .. ')')
            debugPrint('Fallback: sent organization share to issuer (no job account). Amount:', orgShare)
            playerShare = playerShare + orgShare
            orgShare = 0
        end
    end

    return { playerShare = playerShare, orgShare = orgShare, jobName = jobName, issuerOnline = issuerOnline, percent = percent }
end

lib.callback.register('rm-billing:checkCreateInvoicePermission', function(source)
    local src = source
    local allowed = exports.qbx_core:HasGroup(src, Config.AllowedJobs)
    debugPrint('Permission check for player', src, 'result:', allowed)
    return allowed
end)

lib.callback.register('rm-billing:checkSearchInvoicePermission', function(source)
    local src = source
    local allowed = exports.qbx_core:HasGroup(src, Config.CanCheckInvoices)
    debugPrint('Permission check for player', src, 'result:', allowed)
    return allowed
end)

lib.callback.register('rm-billing:getPlayerInvoices', function(source)
    local src = source
    debugPrint('Getting invoices for player:', src)

    local ply = exports.qbx_core:GetPlayer(src)
    local result = MySQL.query.await('SELECT * FROM rm_invoices WHERE to_player = ? ORDER BY created_at DESC', { ply.PlayerData.citizenid })
    if result then
        debugPrint('Found', #result, 'invoices for player', src)

        local processedInvoices = {}
        for _, invoice in ipairs(result) do
            local processedInvoice = {
                invoice_id = invoice.invoice_id,
                from_player = invoice.from_player,
                from_job = invoice.from_job,
                to_player = invoice.to_player,
                reason = invoice.reason,
                amount = invoice.amount,
                status = invoice.status,
                created_at = invoice.created_at,
                paid_at = invoice.paid_at
            }

            processedInvoice.from_name = getCharacterName(invoice.from_player)
            processedInvoice.to_name = getCharacterName(invoice.to_player)

            table.insert(processedInvoices, processedInvoice)
        end

        return processedInvoices
    else
        debugPrint('No invoices found for player', src)
        return {}
    end
end)

lib.callback.register("rm-billing:server:searchPlyInvoices", function(source, data)
    local src = source
    local playerId = data.playerId
    debugPrint('Searching invoices for player ID:', playerId, 'by:', src)

    if not exports.qbx_core:HasGroup(src, Config.CanCheckInvoices) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You do not have permission to search invoices.' })
        return
    end

    if not playerId then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Please provide a valid player ID.' })
        return
    end

    local result = MySQL.query.await('SELECT * FROM rm_invoices WHERE from_player = ? OR to_player = ? or invoice_id = ? ORDER BY created_at DESC LIMIT 50', { playerId, playerId, playerId })
    if result then
        debugPrint('Found', #result, 'invoices for player ID:', playerId)

        local processedInvoices = {}
        for i, invoice in ipairs(result) do
            local processedInvoice = {
                invoice_id = invoice.invoice_id,
                from_player = invoice.from_player,
                from_job = invoice.from_job,
                to_player = invoice.to_player,
                reason = invoice.reason,
                amount = invoice.amount,
                status = invoice.status,
                created_at = invoice.created_at,
                paid_at = invoice.paid_at
            }

            processedInvoice.from_name = getCharacterName(invoice.from_player)
            processedInvoice.to_name = getCharacterName(invoice.to_player)

            table.insert(processedInvoices, processedInvoice)
        end

        return { invoices = processedInvoices, playerId = playerId }
    else
        debugPrint('No invoices found for player ID:', playerId)
        return { invoices = {}, playerId = playerId }
    end
end)

lib.callback.register('rm-billing:payInvoice', function(source, invoiceId)
    local src = source
    debugPrint('Player', src, 'attempting to pay invoice:', invoiceId)

    local ply = exports.qbx_core:GetPlayer(src)
    local result = MySQL.query.await('SELECT * FROM rm_invoices WHERE invoice_id = ? AND to_player = ? AND status = "pending"', { invoiceId, ply.PlayerData.citizenid })
    if result and result[1] then
        local invoice = result[1]

        local playerMoney = exports.qbx_core:GetMoney(src, 'bank')
        if not playerMoney or playerMoney < invoice.amount then
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = 'You do not have enough money in your bank account. Required: $' .. invoice.amount
            })
            return false
        end

        local moneyRemoved = exports.qbx_core:RemoveMoney(src, 'bank', invoice.amount, 'Invoice Payment: ' .. invoiceId)
        if not moneyRemoved then
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = 'Failed to process payment. Please try again.'
            })
            return false
        end

        local splitResult = distributeInvoiceFunds(invoice.from_player, invoice.from_job, invoice.amount, invoiceId)

        MySQL.update('UPDATE rm_invoices SET status = "paid", paid_at = CURRENT_TIMESTAMP WHERE invoice_id = ?', {
            invoiceId
        }, function(affectedRows)
            if affectedRows > 0 then
                TriggerClientEvent('ox_lib:notify', src, {
                    type = 'success',
                    description = 'Invoice paid successfully! $' .. invoice.amount .. ' deducted from bank.'
                })

                local issuer = exports.qbx_core:GetPlayerByCitizenId(invoice.from_player)
                if issuer then
                    local details = 'Invoice paid by ID ' .. src .. ' for $' .. invoice.amount
                    if splitResult.percent and splitResult.percent > 0 then
                        details = details .. string.format(' | You received $%d (%d%%).', splitResult.playerShare, splitResult.percent)
                    end
                    if splitResult.orgShare and splitResult.orgShare > 0 then
                        if splitResult.jobName then
                            details = details .. string.format(' | %s account received $%d.', splitResult.jobName, splitResult.orgShare)
                        else
                            details = details .. string.format(' | Organization received $%d.', splitResult.orgShare)
                        end
                    end
                    TriggerClientEvent('ox_lib:notify', issuer.PlayerData.source, { type = 'inform', description = details })
                end
                
                if Config.LogInvoices then
                    local invoiceData = {
                        invoice_id = invoice.invoice_id,
                        amount = invoice.amount,
                        reason = invoice.reason,
                        status = 'paid'
                    }
                    logInvoicePaid(issuer, ply, invoiceData, splitResult)
                end

                debugPrint('Invoice', invoiceId, 'paid by player', src)
            else
                TriggerClientEvent('ox_lib:notify', src, {
                    type = 'error',
                    description = 'Failed to update invoice status. Please try again.'
                })
            end
        end)
        return true
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Invoice not found or already paid.'
        })
    end
end)

RegisterNetEvent('rm-billing:createInvoice', function(data)
    local src = source
    debugPrint('Create invoice request from player:', src, 'Data:', json.encode(data))

    if not exports.qbx_core:HasGroup(src, Config.AllowedJobs) then
        debugPrint('Player', src, 'does not have permission to create invoices')
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You do not have permission to create invoices.' })
        return
    end

    local targetPlayerId = tonumber(data.playerId)
    local amount = tonumber(data.amount)
    local reason = tostring(data.reason or '')

    debugPrint('Parsed data - Target ID:', targetPlayerId, 'Amount:', amount, 'Reason:', reason)
    debugPrint('Raw playerId type:', type(data.playerId), 'Value:', data.playerId)

    if not targetPlayerId or targetPlayerId <= 0 then
        debugPrint('Invalid target player ID:', targetPlayerId, 'Raw value:', data.playerId)
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid target player ID.' })
        return
    end

    if not amount or amount <= 0 then
        debugPrint('Invalid amount:', amount)
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid invoice amount.' })
        return
    end

    if reason == '' then
        debugPrint('Missing reason')
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invoice reason is required.' })
        return
    end

    if targetPlayerId == src then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'You cannot create an invoice for yourself.' })
        return
    end

    local issuerName = getCharacterName(src)

    local targetPlayerName = getCharacterName(targetPlayerId)

    local isAutoPayJob = false
    local issuerPlayer = exports.qbx_core:GetPlayer(src)
    local issuerJobNameForAutopay = issuerPlayer and issuerPlayer.PlayerData and issuerPlayer.PlayerData.job and issuerPlayer.PlayerData.job.name or nil
    debugPrint('Checking auto-pay jobs for player:', src, 'job:', issuerJobNameForAutopay)
    debugPrint('Auto-pay jobs config:', json.encode(Config.AutoPayJobs))

    if issuerJobNameForAutopay and isJobInList(issuerJobNameForAutopay, Config.AutoPayJobs) then
        isAutoPayJob = true
        debugPrint('Issuer job is in auto-pay list:', issuerJobNameForAutopay)
    end

    debugPrint('Final auto-pay result:', isAutoPayJob)

    local invoiceId = generateInvoiceId()
    local targetPly = exports.qbx_core:GetPlayer(targetPlayerId)
    MySQL.insert('INSERT INTO rm_invoices (invoice_id, from_player, from_job, to_player, from_name, to_name, reason, amount, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        invoiceId,
        issuerPlayer.PlayerData.citizenid,
        issuerPlayer.PlayerData.job.name,
        targetPly.PlayerData.citizenid,
        issuerName,
        targetPlayerName,
        reason,
        amount,
        isAutoPayJob and 'paid' or 'pending',
    }, function(insertId)
        if insertId then
            debugPrint('Invoice created in database with ID:', insertId)
            debugPrint('Auto-pay status:', isAutoPayJob)

            if isAutoPayJob then
                debugPrint('Starting auto-payment process...')
                local playerMoney = exports.qbx_core:GetMoney(targetPlayerId, 'bank')
                debugPrint('Target player money:', playerMoney, 'Required amount:', amount)

                local moneyRemoved = exports.qbx_core:RemoveMoney(targetPlayerId, 'bank', amount, 'Auto Invoice Payment: ' .. invoiceId)
                debugPrint('Money removal result:', moneyRemoved)

                if moneyRemoved then
                    local jobName = nil
                    if issuerPlayer and issuerPlayer.PlayerData and issuerPlayer.PlayerData.job then
                        jobName = issuerPlayer.PlayerData.job.name
                        debugPrint('Issuer job name:', jobName)
                    end

                    local splitResult = distributeInvoiceFunds(issuerPlayer.PlayerData.citizenid, jobName, amount, invoiceId)
                    
                if Config.LogInvoices then
                    local invoiceData = {
                        invoice_id = invoiceId,
                        amount = amount,
                        reason = reason,
                        status = 'paid'
                    }
                    logInvoicePaid(issuerPlayer, targetPly, invoiceData, splitResult)
                end

                    local notificationText = 'Auto-payment: Invoice for $' .. amount .. ' from ID: ' .. src .. ' - has been automatically deducted from your bank account.'

                    if playerMoney and playerMoney < amount then
                        notificationText = notificationText .. ' (Your bank account is now negative: $' .. (playerMoney - amount) .. ')'
                    end

                    TriggerClientEvent('ox_lib:notify', targetPlayerId, {
                        type = 'inform',
                        description = notificationText,
                        duration = 20000
                    })

                    local issuerNotification = 'Auto-payment: Invoice sent to ID: ' .. targetPlayerId .. ' has been automatically paid.'
                    if splitResult.percent and splitResult.percent > 0 then
                        issuerNotification = issuerNotification .. string.format(' You received $%d (%d%%).', splitResult.playerShare, splitResult.percent)
                    end
                    if splitResult.orgShare and splitResult.orgShare > 0 then
                        if splitResult.jobName then
                            issuerNotification = issuerNotification .. string.format(' %s account received $%d.', splitResult.jobName, splitResult.orgShare)
                        else
                            issuerNotification = issuerNotification .. string.format(' Organization received $%d.', splitResult.orgShare)
                        end
                    end

                    TriggerClientEvent('ox_lib:notify', src, {
                        type = 'success',
                        description = issuerNotification,
                        duration = 10000
                    })

                    MySQL.update.await('UPDATE rm_invoices SET status = "paid", paid_at = CURRENT_TIMESTAMP WHERE invoice_id = ?', { invoiceId })

                    debugPrint('Auto-payment successful for invoice:', invoiceId)
                else
                    debugPrint('Auto-payment failed, falling back to pending...')
                    MySQL.update('UPDATE rm_invoices SET status = "pending" WHERE invoice_id = ?', { invoiceId })
                    TriggerClientEvent('ox_lib:notify', targetPlayerId, {
                        type = 'inform',
                        description = 'You have received an invoice for $' .. amount .. ' from ID: ' .. src,
                        duration = 10000
                    })
                    TriggerClientEvent('ox_lib:notify', src, {
                        type = 'success',
                        description = 'Invoice created successfully for $' .. amount .. ' to ID: ' .. targetPlayerId,
                        duration = 10000
                    })
                end
            else
                debugPrint('Not an auto-pay job, creating regular invoice...')
                TriggerClientEvent('ox_lib:notify', targetPlayerId, {
                    type = 'inform',
                    description = 'You have received an invoice for $' .. amount .. ' from ID: ' .. src,
                    duration = 5000
                })

                TriggerClientEvent('ox_lib:notify', src, {
                    type = 'success',
                    description = 'Invoice created successfully for $' .. amount .. ' to ID: ' .. targetPlayerId,
                    duration = 5000
                })
            end

            if Config.LogInvoices then
                local invoiceData = {
                    invoice_id = invoiceId,
                    amount = amount,
                    reason = reason,
                    status = isAutoPayJob and 'paid' or 'pending'
                }
                
                if isAutoPayJob then
                    logInvoicePaid(issuerPlayer, targetPly, invoiceData, splitResult)
                else
                    logInvoiceCreated(issuerPlayer, targetPly, invoiceData)
                end
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {
                type = 'error',
                description = 'Failed to create invoice. Please try again.'
            })
        end
    end)
end)

local function deleteOldPaidInvoices()
    local hoursAgo = Config.DeletePaidInvoicesAfter
    MySQL.query('DELETE FROM rm_invoices WHERE status = "paid" AND paid_at < DATE_SUB(NOW(), INTERVAL ? HOUR)', {
        hoursAgo
    }, function(affectedRows)
        if affectedRows and type(affectedRows) == 'number' and affectedRows > 0 then
            debugPrint('Deleted', affectedRows, 'old paid invoices (older than', hoursAgo, 'hours)')
        end
    end)
end

lib.cron.new("0 0 * * 0", deleteOldPaidInvoices) -- “At 00:00 on Sunday.”
