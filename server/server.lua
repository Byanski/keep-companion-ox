local QBCore = exports['qb-core']:GetCoreObject()
local maxLimit = Config.MaxActivePetsPetPlayer
local ox_inventory = exports.ox_inventory

-- ============================
--          Class
-- ============================

Pet = {
    players = {}
}

--- search for player(source) item's hash inside Pet list
function Pet:isSpawned(source, item)
    if self.players[source] ~= nil then
        for key, table in pairs(self.players[source]) do
            if item.metadata.hash == key then
                return true
            end
        end
    end
    return false
end

--- add pet to Pet table
function Pet:setAsSpawned(source, o)
    self.players[source] = self.players[source] or {}
    self.players[source][o.item.metadata.hash] = self.players[source][o.item.metadata.hash] or {}
    self.players[source][o.item.metadata.hash].model = o.model
    self.players[source][o.item.metadata.hash].entity = o.entity

    self.players[source][o.item.metadata.hash].name = o.item.name
    self.players[source][o.item.metadata.hash].metadata = o.item.metadata
    return true
end

--- removes pet from Pet table
function Pet:setAsDespawned(source, item)
    self.players[source] = self.players[source] or {}
    self.players[source][item.metadata.hash] = nil
end

--- start spawn chain
function Pet:spawnPet(source, model, item)
    local isSpawned = Pet:isSpawned(source, item)
    if isSpawned == true then
        Pet:despawnPet(source, item, nil)
        return
    end

    local limit = Pet:isMaxLimitPedReached(source)
    if limit == true then
        exports.qbx_core:Notify(source, string.format(Lang:t('error.reached_max_allowed_pet'), maxLimit), 'error', 2500)
        return
    end

    local Player = QBCore.Functions.GetPlayer(source)

    if item.metadata.health <= 100 and item.metadata.health ~= 0 then
        if ox_inventory:GetSlot(source, item.slot) then
            item.metadata.health = 0
            ox_inventory:SetMetadata(source, item.slot, item.metadata.health)
        end
        return
    end

    local owner = not (item.metadata.owner.phone == Player.PlayerData.charinfo.phone)
    TriggerClientEvent('keep-companion:client:callCompanion', source, model, owner, item)
end

RegisterNetEvent('keep-companion:server:despwan_not_owned_pet', function(hash)
    Pet:despawnPet(source, { metadata = {
        hash = hash
    } }, true)
end)

--- check if player reached maximum allowed pet
function Pet:isMaxLimitPedReached(source)
    local count = 0
    if self.players[source] == nil then
        return false
    else
        for _ in pairs(self.players[source]) do
            count = count + 1
        end
        if count == 0 then
            return false
        elseif count >= maxLimit then
            return true
        end
    end
end

--- despawn pet and remove it's data from server
function Pet:despawnPet(source, item, revive)
    TriggerClientEvent('keep-companion:client:despawn', source, item, revive)
end

function Pet:findbyhash(source, hash)
    for key, value in pairs(self.players[source]) do
        if key == hash then
            return value
        end
    end
    return false
end

local server_saving_interval = 5000
local server_saving_interval_sec = math.floor(server_saving_interval / 1000)
local day = 10
local max_age = 60 * 60 * 24 * day

function Pet:save_all_metadata(source, hash)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player == nil then return end
    local petData = Pet:findbyhash(source, hash)
    local items = ox_inventory:GetInventoryItems(source)
    local slot = nil
    
    for key, pet_item in pairs(items) do
        if pet_item.metadata then
            if pet_item.metadata.hash == hash then
                slot = pet_item.slot
                break
            end
        end
    end

    if slot == nil then return end
    if petData.metadata.health == 0 then return end
    
    if petData.metadata.health > 100 then
        if petData.metadata.age >= max_age then
            return
        end
        petData.metadata.age = petData.metadata.age + (server_saving_interval_sec)
        Update:food(petData, 'decrease')
        Update:thirst(petData, 'increase')
    else
        petData.metadata.health = 0
        TriggerClientEvent('keep-companion:client:forceKill', source, hash, 'hunger')
    end

    if ox_inventory:GetSlot(source, slot) then
        petData.metadata.health = Round(petData.metadata.health, 2)
        petData.metadata.thirst = Round(petData.metadata.thirst, 2)
        petData.metadata.food = Round(petData.metadata.food, 2)
        ox_inventory:SetMetadata(source, slot, petData.metadata)
    end
end

RegisterNetEvent('keep-companion:server:setAsDespawned', function(item)
    if item == nil then return end
    Pet:setAsDespawned(source, item)
end)

-- ============================
--          Items
-- ============================
local core_items = Config.core_items

local function remove_item(src, Player, name, amount)
    local res = ox_inventory:RemoveItem(src, name, amount)
    if res then
        TriggerClientEvent('ox_inventory:itemNotify', src, {name = name, action = 'remove'})
    end
    return res
end

-- Food
exports.qbx_core:CreateUseableItem(core_items.food.item_name, function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player == nil then return end
    TriggerClientEvent('keep-companion:client:start_feeding_animation', source)
end)

RegisterNetEvent('keep-companion:server:increaseFood', function(item)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player == nil or item == nil then return end
    if not remove_item(source, Player, Config.core_items.food.item_name, 1) then
        exports.qbx_core:Notify(source, 'Failed to remove from your inventory', 'error', 2500)
        return
    end
    local petData = Pet:findbyhash(source, item.metadata.hash)
    petData.metadata.food = petData.metadata.food + 50
    exports.qbx_core:Notify(source, 'Feeding was successful wait little bit to take effect!', 'success', 2500)
end)

-- Change ownership
exports.qbx_core:CreateUseableItem(core_items.collar.item_name, function(source, item)
    TriggerClientEvent('keep-companion:client:collar_process', source)
end)

-- Rename - name tag
exports.qbx_core:CreateUseableItem(core_items.nametag.item_name, function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player == nil or item == nil then return end
    TriggerClientEvent('keep-companion:client:rename_name_tag', source, item)
end)

RegisterNetEvent('keep-companion:server:rename_name_tag', function(name)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player == nil then return end

    if not remove_item(source, Player, Config.core_items.nametag.item_name, 1) then
        exports.qbx_core:Notify(source, Lang:t('error.failed_to_remove_item_from_inventory'), 'error', 2500)
        return
    end

    TriggerClientEvent("keep-companion:client:rename_name_tagAction", source, name)
end)

-- First aid - revive
exports.qbx_core:CreateUseableItem(core_items.firstaid.item_name, function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player == nil then return end
end)

exports.qbx_core:CreateUseableItem(core_items.groomingkit.item_name, function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player == nil then return end
    TriggerClientEvent('keep-companion:client:start_grooming_process', source)
end)

RegisterNetEvent('keep-companion:server:grooming_process', function(item)
    local pet_information = find_pet_model_by_item_name(item.name)

    local information = {
        pet_variation_list = PetVariation:getPedVariationsNameList(pet_information.model),
        pet_information = pet_information,
        disable = {
            rename = true
        },
        type = Config.core_items.groomingkit.item_name
    }

    TriggerClientEvent('keep-companion:client:initialization_process', source, item, information)
end)

local function save_metadata_waterbottle(Player, item, amount)
    local src = Player.PlayerData.source
    local itemx = ox_inventory:GetSlot(src, item.slot)
    if itemx then
        item.metadata.type = 'clean'
        item.metadata.liter = amount
        ox_inventory:SetMetadata(src, item.slot, item.metadata)
    end
end

local function initialize_metadata_waterbottle(Player, item)
    local src = Player.PlayerData.source
    if ox_inventory:GetSlot(src, item.slot) then
        item.metadata.type = 'clean'
        item.metadata.liter = 0
        ox_inventory:SetMetadata(src, item.slot, item.metadata)
    end
end

local function fillwater_bottle(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player == nil then return end
    local max_c = Config.core_items.waterbottle.settings.max_capacity
    local water_bottle_refill_value = Config.core_items.waterbottle.settings.water_bottle_refill_value
    local amount = 0
    
    if type(item.metadata) ~= "table" or (type(item.metadata) == "table" and item.metadata.liter == nil) then
        initialize_metadata_waterbottle(Player, item)
        exports.qbx_core:Notify(source, 'Washing water bottle!', 'primary', 2500)
        return
    end

    if item.metadata.liter == nil then
        initialize_metadata_waterbottle(Player, item)
        exports.qbx_core:Notify(source, 'Washing water bottle!', 'primary', 2500)
        return
    end

    if item.metadata.liter > max_c then
        exports.qbx_core:Notify(source, 'could not do that already reached max capacity', 'error', 2500)
        return
    elseif item.metadata.liter == max_c then
        amount = max_c
        exports.qbx_core:Notify(source, 'filling already filled bottle has no effect on capacity', 'error', 2500)
    else
        amount = item.metadata.liter + water_bottle_refill_value
        if amount >= max_c then
            amount = max_c
        end
    end
    
    if type(amount) ~= "number" then
        exports.qbx_core:Notify(source, 'Failed to get amount', 'error', 2500)
        return
    end
    
    save_metadata_waterbottle(Player, item, amount)
    exports.qbx_core:Notify(source, 'Filled bottle', 'success', 2500)
end

exports.qbx_core:CreateUseableItem(core_items.waterbottle.item_name, function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    local water_bottle_refill_value = Config.core_items.waterbottle.settings.water_bottle_refill_value
    if Player == nil then return end
    if not remove_item(source, Player, 'water_bottle', water_bottle_refill_value) then
        local msg = Lang:t('error.not_enough_water_bottles')
        msg = string.format(msg, water_bottle_refill_value)
        exports.qbx_core:Notify(source, msg, 'error', 2500)
        return
    end
    TriggerClientEvent('keep-companion:client:filling_animation', source, item)
end)

RegisterNetEvent('keep-companion:server:filling_event', function(item)
    fillwater_bottle(source, item)
end)

lib.callback.register('keep-companion:server:decrease_thirst', function(source, data)
    local pet_water_bottle = nil
    local inventory = ox_inventory:GetInventory(source)
    for k, v in pairs(inventory.items) do
        if v.name == Config.core_items.waterbottle.item_name then
            pet_water_bottle = v
        end
    end
    local player = QBCore.Functions.GetPlayer(source)
    
    if pet_water_bottle.metadata == nil then
        exports.qbx_core:Notify(source, 'You should wash water bottle first!', 'error', 2500)
        print('issue with nil metadata: https://github.com/swkeep/keep-companion/issues/25')
        return
    end

    if pet_water_bottle.metadata.liter == nil then
        exports.qbx_core:Notify(source, 'You should wash water bottle first!', 'error', 2500)
        print('maybe use your water bottle when there is some water_bottle s in your inventory')
        print('developer: issue with nil metadata -> liter: https://github.com/swkeep/keep-companion/issues/25')
        return
    end

    pet_water_bottle.metadata.liter = pet_water_bottle.metadata.liter - Config.core_items.waterbottle.settings.water_bottle_refill_value
    
    if pet_water_bottle.metadata.liter < 0 then
        exports.qbx_core:Notify(source, Lang:t('error.not_enough_water_in_your_bottle'), 'error', 2500)
        return
    end

    local petData = Pet:findbyhash(source, data.metadata.hash)
    local t_r_p_d = Config.core_items.waterbottle.settings.thirst_reduction_per_drinking

    if not pet_water_bottle then 
        return false 
    end

    if petData.metadata.thirst < 0 then
        petData.metadata.thirst = 0
    end

    if petData.metadata.thirst <= t_r_p_d then
        petData.metadata.thirst = 0
    else
        petData.metadata.thirst = petData.metadata.thirst - t_r_p_d
    end

    exports.qbx_core:Notify(source, Lang:t('success.successful_drinking'), 'success', 2500)
    save_metadata_waterbottle(player, pet_water_bottle, pet_water_bottle.metadata.liter)
end)

RegisterNetEvent('keep-companion:server:revivePet', function(item, process_type)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local petData = Pet:findbyhash(source, item.itemData.metadata.hash)
    local heal_amount = Config.core_items.firstaid.settings.heal_amount
    local revive_bonuses = Config.core_items.firstaid.settings.revive_heal_bonuses
    local pet_maxHealth = getMaxHealth(item.model)
    local potential_heal_amount = math.floor(pet_maxHealth * (heal_amount / 100))
    local msg = ''

    if not petData then
        exports.qbx_core:Notify(src, Lang:t('error.failed_to_start_procces') .. process_type, 'primary', 2500)
        return
    end

    if petData.metadata.health >= pet_maxHealth then
        petData.metadata.health = pet_maxHealth
        exports.qbx_core:Notify(src, Lang:t('metadata.full_life_pet'), 'primary', 2500)
        return
    end

    if not remove_item(source, Player, Config.core_items.firstaid.item_name, 1) then
        exports.qbx_core:Notify(src, 'Failed to remove from your inventory', 'error', 2500)
        return
    end

    if process_type and process_type == 'Heal' then
        local res = math.floor(petData.metadata.health + potential_heal_amount)
        petData.metadata.health = res
        if petData.metadata.health >= pet_maxHealth then
            petData.metadata.health = pet_maxHealth
        end

        Pet:save_all_metadata(src, item.itemData.metadata.hash)
        msg = Lang:t('success.healing_was_successful')
        msg = string.format(msg, petData.metadata.health, pet_maxHealth)
        TriggerClientEvent('keep-companion:client:update_health_value', src, item, petData.metadata.health)
        exports.qbx_core:Notify(src, msg, 'success', 2500)
        return
    end

    petData.metadata.health = 100 + revive_bonuses
    Pet:save_all_metadata(src, item.itemData.metadata.hash)
    Pet:despawnPet(src, petData, true)
    msg = Lang:t('success.successful_revive')
    msg = string.format(msg, item.itemData.metadata.name)
    exports.qbx_core:Notify(src, msg, 'success', 2500)
end)

--- get pet max health from config file by it's model
function getMaxHealth(model)
    for key, value in pairs(Config.pets) do
        if value.model == model then
            return value.maxHealth
        end
    end
end

-- all pets
for key, value in pairs(Config.pets) do
    exports.qbx_core:CreateUseableItem(value.name, function(source, item)
        if item.name ~= value.name then return end
        local model = value.model
        
        if type(item.metadata) ~= "table" or (type(item.metadata) == "table" and item.metadata.hash == nil) then
            initItem(source, item)
            exports.qbx_core:Notify(source, Lang:t('success.pet_initialization_was_successful'), 'success', 2500)
            return
        end

        local cooldown = PlayersCooldown:isOnCooldown(source)
        if cooldown > 0 then
            local msg = Lang:t('metadata.still_on_cooldown')
            msg = string.format(msg, (cooldown / 1000))
            exports.qbx_core:Notify(source, msg, 'primary', 2500)
            return
        end

        Pet:spawnPet(source, model, item)
    end)
end

local function search_inventory(cid)
    local Player = QBCore.Functions.GetPlayer(cid)
    local src = Player.PlayerData.source
    if not Player then return false end
    local count = 0
    for k, illegal_item in pairs(Config.k9.illegal_items) do
        local item = ox_inventory:GetItem(src, illegal_item, nil, false)
        if item then
            count = count + 1
            if count > 0 then
                return true
            end
        end
    end
    return false
end

lib.callback.register('keep-companion:server:search_inventory', function(source, cid)
    local res = search_inventory(cid)
    if not res then
        exports.qbx_core:Notify(source, 'K9 could not find anything!', 'error', 2500)
        return res
    end
    return res
end)

local function search_vehicle(Type, plate)
    local illegal_items = Config.k9.illegal_items
    local items_list = nil

    if Type == 1 then
        items_list = exports[Config.inventory_name]:getGloveboxes(plate)
    elseif Type == 2 then
        items_list = exports[Config.inventory_name]:getTruck(plate)
    end

    if items_list then
        for key, item in pairs(items_list.items) do
            for k, i_name in pairs(illegal_items) do
                if item.name == i_name then
                    return true
                end
            end
        end
    end
    return false
end

lib.callback.register('keep-companion:server:search_vehicle', function(source, data)
    local res = search_vehicle(data.key, data.plate)
    if not res then
        exports.qbx_core:Notify(source, 'K9 could not find anything!', 'error', 2500)
        return res
    end
    exports.qbx_core:Notify(source, 'K9 found something', 'success', 2500)
    return res
end)

-- ================================================
--          Item - Updating information
-- ================================================
function FindWhereIsItem(Player, item, source)
    local inv = ox_inventory:GetInventory(source)
    if inv == nil or next(inv) == nil then
        exports.qbx_core:Notify(source, "no items in inventory!")
        return false
    end
    for k, v in pairs(inv) do
        local slot = ox_inventory:GetSlot(source, k)
        if slot ~= nil then
            if slot.metadata.hash == item.hash then
                return slot
            end
        end
    end
    exports.qbx_core:Notify(source, "Could not find pet")
    return false
end

RegisterNetEvent('keep-companion:server:updateAllowedmetadata', function(item, data)
    if type(data) ~= "table" or next(data) == nil then return end
    local Player = QBCore.Functions.GetPlayer(source)
    local current_pet_data = Pet:findbyhash(source, item.hash)
    if current_pet_data == nil or current_pet_data == false then return end
    local requestedItem = ox_inventory:GetItem(source, current_pet_data.name, nil, false)

    if type(requestedItem) == "table" then
        for key, pet_item in pairs(requestedItem) do
            if pet_item.metadata.hash == item.hash then
                requestedItem = pet_item
            end
        end
        if requestedItem == false then return end
    end

    if data.key == 'XP' then
        Update:xp(source, current_pet_data)
        return
    end

    Update:health(source, data, current_pet_data)
end)

lib.callback.register('keep-companion:server:renamePet', function(source, item)
    local player = QBCore.Functions.GetPlayer(source)
    local current_pet_data = Pet:findbyhash(source, item.hash)

    if player == nil or current_pet_data == nil or current_pet_data == false or type(item.name) ~= "string" then
        local msg = Lang:t('error.failed_to_rename')
        msg = string.format(msg, item.name)
        exports.qbx_core:Notify(source, msg, 'error')
        return false
    end

    if current_pet_data.metadata.name == item.content then
        local msg = Lang:t('error.failed_to_rename_same_name')
        msg = string.format(msg, item.name)
        exports.qbx_core:Notify(source, msg, 'error')
        return false
    end

    current_pet_data.metadata.name = item.name
    Pet:save_all_metadata(source, item.hash)
    Pet:despawnPet(source, { metadata = { hash = item.hash } }, true)
    return item.name
end)

-- saving thread
CreateThread(function()
    while true do
        for source, activePets in pairs(Pet.players) do
            if next(activePets) ~= nil then
                for hash, petData in pairs(activePets) do
                    Pet:save_all_metadata(source, hash)
                end
            end
        end
        Wait(server_saving_interval)
    end
end)

lib.callback.register('keep-companion:server:updatePedData', function(source, clientRes)
    local player = QBCore.Functions.GetPlayer(source)
    if player == nil then
        print('[Keep-Companion] ERROR: Player is nil for source: ' .. source)
        return false
    end
    
    if not clientRes or not clientRes.item or not clientRes.item.metadata then
        print('[Keep-Companion] ERROR: Invalid client response data')
        return false
    end
    
    print('[Keep-Companion] Registering pet for player: ' .. source .. ' | Hash: ' .. (clientRes.item.metadata.hash or 'NO_HASH'))
    
    if Pet:setAsSpawned(source, clientRes) then
        print('[Keep-Companion] Pet successfully registered')
        return true
    end
    
    print('[Keep-Companion] ERROR: Failed to set pet as spawned')
    return false
end)

RegisterNetEvent('keep-companion:server:onPlayerUnload', function(items)
    for key, value in pairs(items) do
        Pet:setAsDespawned(source, value)
    end
end)

-- ============================
--          Commands
-- ============================

lib.addCommand('addpet', {
    help = 'Add a pet to player inventory (Admin Only)',
    params = {
        {name = 'petname', type = 'string', help = 'Pet item name'}
    },
    restricted = 'group.admin'
}, function(source, args)
    local PETname = args.petname
    local Player = QBCore.Functions.GetPlayer(source)
    
    Player.Functions.AddItem(PETname, 1)
    TriggerClientEvent('ox_inventory:itemNotify', source, {name = PETname, action = 'add'})
end)

lib.addCommand('addItem', {
    help = 'Add item to player inventory (Admin Only)',
    params = {
        {name = 'itemname', type = 'string', help = 'Item name'}
    },
    restricted = 'group.admin'
}, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    Player.Functions.AddItem(args.itemname, 1)
    TriggerClientEvent('ox_inventory:itemNotify', source, {name = args.itemname, action = 'add'})
end)

lib.addCommand('renamePet', {
    help = 'Rename pet',
    params = {
        {name = 'name', type = 'string', help = 'New pet name'}
    },
    restricted = 'group.admin'
}, function(source, args)
    TriggerClientEvent("keep-companion:client:rename_name_tag", source, args.name)
end)

-- ============================
--           Cooldown
-- ============================

CreateThread(function()
    local timeToClean = 600
    local count = 0
    while true do
        Wait(1000)
        count = count + 1
        local size = PlayersCooldown:onlinePlayers()
        if size > 0 then
            for ped, cooldown in pairs(PlayersCooldown.players) do
                PlayersCooldown:updateCooldown(ped)
            end
        end

        if count >= timeToClean and not count == 0 then
            PlayersCooldown:cleanOflinePlayers()
            count = 0
        end
    end
end)

RegisterNetEvent('keep-companion:server:ForceRemoveNetEntity', function(netId)
    local net = NetworkGetEntityFromNetworkId(netId)
    DeleteEntity(net)
end)