
local QBCore = nil
local Config = Config or {}
Config.Inventory = Config.Inventory or "ox_inventory"
Config.PoliceJob = Config.PoliceJob or "police"

local mincash = 5000 -- minimum amount of cash a pile holds
local maxcash = 10000 -- maximum amount of cash a pile can hold
local black = false -- enable this if you want blackmoney as a reward
local mincops = 0 -- minimum required cops to start mission
local enablesound = true -- enables bank alarm sound
local lastrobbed = 0 -- don't change this
local cooldown = 1800 -- amount of time to do the heist again in seconds (30min)
local info = {stage = 0, style = nil, locked = false}
local totalcash = 0
local PoliceDoors = {
    {loc = vector3(257.10, 220.30, 106.28), txtloc = vector3(257.10, 220.30, 106.28), model = "hei_v_ilev_bk_gate_pris", model2 = "hei_v_ilev_bk_gate_molten", obj = nil, obj2 = nil, locked = true},
    {loc = vector3(236.91, 227.50, 106.29), txtloc = vector3(236.91, 227.50, 106.29), model = "v_ilev_bk_door", model2 = "v_ilev_bk_door", obj = nil, obj2 = nil, locked = true},
    {loc = vector3(262.35, 223.00, 107.05), txtloc = vector3(262.35, 223.00, 107.05), model = "hei_v_ilev_bk_gate2_pris", model2 = "hei_v_ilev_bk_gate2_pris", obj = nil, obj2 = nil, locked = true},
    {loc = vector3(252.72, 220.95, 101.68), txtloc = vector3(252.72, 220.95, 101.68), model = "hei_v_ilev_bk_safegate_pris", model2 = "hei_v_ilev_bk_safegate_molten", obj = nil, obj2 = nil, locked = true},
    {loc = vector3(261.01, 215.01, 101.68), txtloc = vector3(261.01, 215.01, 101.68), model = "hei_v_ilev_bk_safegate_pris", model2 = "hei_v_ilev_bk_safegate_molten", obj = nil, obj2 = nil, locked = true},
    {loc = vector3(253.92, 224.56, 101.88), txtloc = vector3(253.92, 224.56, 101.88), model = "v_ilev_bk_vaultdoor", model2 = "v_ilev_bk_vaultdoor", obj = nil, obj2 = nil, locked = true}
}

local policeJob = Config.PoliceJob or "police"
local useOxInventory = Config.Inventory == "ox_inventory"

-- QBCore initialization
local success, result = pcall(function() return exports['qb-core']:GetCoreObject() end)
if success and result then
    QBCore = result
    print("^2[UTK Ornate Heist]^7 QBCore loaded successfully")
else
    print("^1[UTK Ornate Heist]^7 ERROR: Failed to load QBCore!")
    print("^1[UTK Ornate Heist]^7 Make sure qb-core is started BEFORE this resource in server.cfg!")
    print("^1[UTK Ornate Heist]^7 Example:")
    print("^1[UTK Ornate Heist]^7   ensure qb-core")
    print("^1[UTK Ornate Heist]^7   ensure utk_ornateheist")
end

-- Verify QBCore is loaded
if not QBCore then
    print("^1[UTK Ornate Heist]^7 CRITICAL ERROR: QBCore not loaded!")
    print("^1[UTK Ornate Heist]^7 Script will not work until QBCore is loaded.")
end

-- Inventory helpers
local function HasItem(source, itemName)
    if useOxInventory then
        local count = exports.ox_inventory:GetItemCount(source, itemName)
        print("^3[UTK Ornate Heist]^7 Checking item: " .. itemName .. " - Count: " .. tostring(count))
        return count and count >= 1
    else
        if not QBCore then
            print("^1[UTK Ornate Heist]^7 ERROR: QBCore not loaded in HasItem!")
            return false
        end
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        local item = Player.Functions.GetItemByName(itemName)
        return item and item.amount >= 1
    end
end

local function RemoveItem(source, itemName, count)
    count = count or 1
    if useOxInventory then
        return exports.ox_inventory:RemoveItem(source, itemName, count)
    else
        if not QBCore then
            print("^1[UTK Ornate Heist]^7 ERROR: QBCore not loaded in RemoveItem!")
            return false
        end
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        return Player.Functions.RemoveItem(itemName, count)
    end
end

local function AddItem(source, itemName, count)
    count = count or 1
    if useOxInventory then
        return exports.ox_inventory:AddItem(source, itemName, count)
    else
        if not QBCore then
            print("^1[UTK Ornate Heist]^7 ERROR: QBCore not loaded in AddItem!")
            return false
        end
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return false end
        return Player.Functions.AddItem(itemName, count)
    end
end

local function AddMoney(source, amount, account)
    if not QBCore then
        print("^1[UTK Ornate Heist]^7 ERROR: QBCore not loaded in AddMoney!")
        return false
    end
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    if (account == "black_money" or black) then
        if useOxInventory then
            return exports.ox_inventory:AddItem(source, "markedbills", 1, {worth = amount})
        else
            return Player.Functions.AddItem("markedbills", 1, nil, {worth = amount}) or Player.Functions.AddMoney("crypto", amount)
        end
    else
        return Player.Functions.AddMoney("cash", amount)
    end
end

local function GetPlayerIds()
    if not QBCore then
        print("^1[UTK Ornate Heist]^7 ERROR: QBCore not loaded in GetPlayerIds!")
        return {}
    end
    local players = QBCore.Functions.GetQBPlayers() or {}
    local ids = {}
    for id, _ in pairs(players) do
        ids[#ids + 1] = id
    end
    return ids
end

local function GetPlayer(source)
    if not QBCore then
        print("^1[UTK Ornate Heist]^7 ERROR: QBCore not loaded in GetPlayer!")
        return nil
    end
    return QBCore.Functions.GetPlayer(source)
end

local function IsPolice(player)
    return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name == policeJob
end

local function RegisterCallback(name, cb)
    if not QBCore then
        print("^1[UTK Ornate Heist]^7 ERROR: QBCore not loaded! Cannot register callback: " .. name)
        return
    end
    QBCore.Functions.CreateCallback(name, cb)
end

-- Register callbacks
RegisterCallback("utk_oh:GetData", function(source, cb)
    print("^3[UTK Ornate Heist]^7 GetData callback called from player " .. source)
    print("^3[UTK Ornate Heist]^7 Returning info: stage=" .. tostring(info.stage) .. ", style=" .. tostring(info.style) .. ", locked=" .. tostring(info.locked))
    cb(info)
end)

RegisterCallback("utk_oh:GetDoors", function(source, cb)
    cb(PoliceDoors)
end)

RegisterCallback("utk_oh:startevent", function(source, cb, method)
    print("^2[UTK Ornate Heist]^7 Start event called by player " .. source .. " method: " .. tostring(method))
    local playerIds = GetPlayerIds()
    local copcount = 0
    local yPlayer = GetPlayer(source)

    if not yPlayer then
        print("^1[UTK Ornate Heist]^7 ERROR: Player not found!")
        cb("Player not found.")
        return
    end

    if not info.locked then
        if (os.time() - cooldown) > lastrobbed then
            for _, playerId in ipairs(playerIds) do
                local xPlayer = GetPlayer(playerId)
                if xPlayer and IsPolice(xPlayer) then
                    copcount = copcount + 1
                end
            end
            if copcount >= mincops then
                if method == 1 then
                    print("^2[UTK Ornate Heist]^7 Checking for thermal_charge...")
                    if HasItem(source, "thermal_charge") then
                        print("^2[UTK Ornate Heist]^7 Thermal charge found, removing...")
                        RemoveItem(source, "thermal_charge", 1)
                        cb(true)
                        info.stage = 1
                        info.style = 1
                        info.locked = true
                        print("^2[UTK Ornate Heist]^7 Loud heist started!")
                    else
                        print("^1[UTK Ornate Heist]^7 Player doesn't have thermal_charge")
                        cb("You don't have any thermal charges.")
                    end
                elseif method == 2 then
                    print("^2[UTK Ornate Heist]^7 Checking for lockpick...")
                    if HasItem(source, "lockpick") then
                        print("^2[UTK Ornate Heist]^7 Lockpick found, removing...")
                        RemoveItem(source, "lockpick", 1)
                        info.stage = 1
                        info.style = 2
                        info.locked = true
                        cb(true)
                        print("^2[UTK Ornate Heist]^7 Silent heist started!")
                    else
                        print("^1[UTK Ornate Heist]^7 Player doesn't have lockpick")
                        cb("You don't have any lockpicks.")
                    end
                end
            else
                cb("There must be at least "..mincops.." police in the city.")
            end
        else
            cb(math.floor((cooldown - (os.time() - lastrobbed)) / 60)..":"..math.fmod((cooldown - (os.time() - lastrobbed)), 60).." left until the next robbery.")
        end
    else
        cb("Bank is currently being robbed.")
    end
end)

RegisterCallback("utk_oh:checkItem", function(source, cb, itemname)
    cb(HasItem(source, itemname))
end)

RegisterCallback("utk_oh:gettotalcash", function(source, cb)
    cb(totalcash)
end)

RegisterServerEvent("utk_oh:removeitem")
AddEventHandler("utk_oh:removeitem", function(itemname)
    RemoveItem(source, itemname, 1)
end)

RegisterServerEvent("utk_oh:updatecheck")
AddEventHandler("utk_oh:updatecheck", function(var, status)
    TriggerClientEvent("utk_oh:updatecheck_c", -1, var, status)
end)

RegisterServerEvent("utk_oh:policeDoor")
AddEventHandler("utk_oh:policeDoor", function(doornum, status)
    PoliceDoors[doornum].locked = status
    TriggerClientEvent("utk_oh:policeDoor_c", -1, doornum, status)
end)

RegisterServerEvent("utk_oh:moltgate")
AddEventHandler("utk_oh:moltgate", function(x, y, z, oldmodel, newmodel, method)
    TriggerClientEvent("utk_oh:moltgate_c", -1, x, y, z, oldmodel, newmodel, method)
end)

RegisterServerEvent("utk_oh:fixdoor")
AddEventHandler("utk_oh:fixdoor", function(hash, coords, heading)
    TriggerClientEvent("utk_oh:fixdoor_c", -1, hash, coords, heading)
end)

RegisterServerEvent("utk_oh:openvault")
AddEventHandler("utk_oh:openvault", function(method)
    TriggerClientEvent("utk_oh:openvault_c", -1, method)
end)

RegisterServerEvent("utk_oh:startloot")
AddEventHandler("utk_oh:startloot", function()
    TriggerClientEvent("utk_oh:startloot_c", -1)
end)

RegisterServerEvent("utk_oh:rewardCash")
AddEventHandler("utk_oh:rewardCash", function()
    local reward = math.random(mincash, maxcash)
    AddMoney(source, reward, black and "black_money" or "money")
    totalcash = totalcash + reward
end)

RegisterServerEvent("utk_oh:rewardGold")
AddEventHandler("utk_oh:rewardGold", function()
    AddItem(source, "gold_bar", 1)
end)

RegisterServerEvent("utk_oh:rewardDia")
AddEventHandler("utk_oh:rewardDia", function()
    AddItem(source, "dia_box", 1)
end)

RegisterServerEvent("utk_oh:giveidcard")
AddEventHandler("utk_oh:giveidcard", function()
    AddItem(source, "id_card", 1)
end)

RegisterServerEvent("utk_oh:ostimer")
AddEventHandler("utk_oh:ostimer", function()
    lastrobbed = os.time()
    info.stage, info.style, info.locked = 0, nil, false
    CreateThread(function()
        Wait(300000)
        for i = 1, #PoliceDoors, 1 do
            PoliceDoors[i].locked = true
            TriggerClientEvent("utk_oh:policeDoor_c", -1, i, true)
        end
        totalcash = 0
        TriggerClientEvent("utk_oh:reset", -1)
    end)
end)

RegisterServerEvent("utk_oh:gas")
AddEventHandler("utk_oh:gas", function()
    TriggerClientEvent("utk_oh:gas_c", -1)
end)

RegisterServerEvent("utk_oh:ptfx")
AddEventHandler("utk_oh:ptfx", function(method)
    TriggerClientEvent("utk_oh:ptfx_c", -1, method)
end)

RegisterServerEvent("utk_oh:alarm_s")
AddEventHandler("utk_oh:alarm_s", function(toggle)
    if enablesound then
        TriggerClientEvent("utk_oh:alarm", -1, toggle)
    end
    TriggerClientEvent("utk_oh:policenotify", -1, toggle)
    
    -- ps-dispatch integration
    if toggle == 1 then
        local player = GetPlayer(source)
        if player then
            local coords = GetEntityCoords(GetPlayerPed(source))
            TriggerClientEvent('ps-dispatch:client:notify', -1, {
                dispatchCode = "10-90",
                dispatchMessage = "Bank Robbery in Progress",
                location = coords,
                gender = player.PlayerData.charinfo.gender,
                street = player.PlayerData.charinfo.street,
                model = GetEntityModel(GetPlayerPed(source)),
                plate = "UNKNOWN",
                name = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname,
                priority = "high",
                job = policeJob,
            })
        end
    end
end)
