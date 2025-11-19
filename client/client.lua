local QBCore = exports['qb-core']:GetCoreObject()

-- ============================
--         Pet Class
-- ============================
ActivePed = {
    data = {},
    onControl = -1
}

--- initial pet data
function ActivePed:new(model, hostile, item, ped, netId)
    print('[Keep-Companion] ===== ActivePed:new START =====')
    print('[Keep-Companion] Model: ' .. tostring(model))
    print('[Keep-Companion] Item name: ' .. tostring(item.name))
    print('[Keep-Companion] Hash: ' .. tostring(item.metadata.hash))
    
    -- Find next available index
    local index = 1
    for i = 1, 999 do
        if not self.data[i] then
            index = i
            break
        end
    end
    
    print('[Keep-Companion] Using index: ' .. index)
    
    -- Initialize the data table for this pet
    self.data[index] = {
        model = model,
        entity = ped,
        netId = netId,
        hostile = hostile,
        itemData = item,
        lastCoord = GetEntityCoords(ped),
        variation = item.metadata.variation,
        health = item.metadata.health
    }
    
    -- Find pet config
    local found = false
    for key, information in pairs(Config.pets) do
        if information.name == item.name then
            self.data[index].modelString = information.model
            self.data[index].maxHealth = information.maxHealth
            
            for w in information.distinct:gmatch("%S+") do
                if w == 'yes' then
                    self.data[index].canHunt = true
                elseif w == 'no' then
                    self.data[index].canHunt = false
                end
            end
            found = true
            break
        end
    end
    
    if not found then
        print('[Keep-Companion] ERROR: Pet config not found for: ' .. item.name)
        return false
    end
    
    -- Set this as the active pet
    self.onControl = index
    
    print('[Keep-Companion] Pet data stored at index: ' .. index)
    print('[Keep-Companion] onControl set to: ' .. self.onControl)
    print('[Keep-Companion] Total pets now: ' .. self:getTotalPets())
    print('[Keep-Companion] ===== ActivePed:new END =====')
    
    return true
end

--- return current active pet
function ActivePed:read()
    if self.onControl == -1 then
        print('[Keep-Companion] ActivePed:read - No active pet (onControl = -1)')
        return nil
    end
    
    if not self.data[self.onControl] then
        print('[Keep-Companion] ActivePed:read - No data at index: ' .. self.onControl)
        return nil
    end
    
    return self.data[self.onControl]
end

--- clean current ped data
function ActivePed:remove(index)
    if not self.data[index] then return end
    
    local netId = NetworkGetNetworkIdFromEntity(self.data[index].entity)
    if netId then
        TriggerServerEvent('keep-companion:server:ForceRemoveNetEntity', netId)
    end
    
    self.data[index] = nil
    
    -- Find new onControl or set to -1
    local foundNew = false
    for key, value in pairs(self.data) do
        self.onControl = key
        foundNew = true
        break
    end
    
    if not foundNew then
        self.onControl = -1
    end
end

function ActivePed:removeAll()
    for key, value in pairs(self.data) do
        if DoesEntityExist(value.entity) then
            DeletePed(value.entity)
        end
        TriggerServerEvent('keep-companion:server:updateAllowedInfo', {
            hash = value.itemData.metadata.hash,
            slot = value.itemData.slot
        }, { key = 'XP' })
    end
    
    TriggerServerEvent('keep-companion:server:onPlayerUnload', self.data)
    self.data = {}
    self.onControl = -1
end

function ActivePed:switchControl(to)
    if not self.data[to] then
        return false
    end
    self.onControl = to
    return true
end

function ActivePed:findByHash(hash)
    for key, data in pairs(self.data) do
        if data.itemData and data.itemData.metadata and data.itemData.metadata.hash == hash then
            return key, data
        end
    end
    return nil, nil
end

function ActivePed:petsList()
    local tmp = {}
    for key, data in pairs(self.data) do
        table.insert(tmp, {
            key = key,
            name = data.itemData.metadata.name,
            pedHandle = data.entity,
            itemData = {
                metadata = {
                    hash = data.itemData.metadata.hash
                }
            }
        })
    end
    return tmp
end

function ActivePed:getTotalPets()
    local count = 0
    for _ in pairs(self.data) do
        count = count + 1
    end
    return count
end

-- Debug command (define early)
RegisterCommand('petdebug', function()
    print('==========================================')
    print('===== PET DEBUG INFO =====')
    print('ActivePed.onControl: ' .. tostring(ActivePed.onControl))
    print('Total pets: ' .. ActivePed:getTotalPets())
    print('------------------------------------------')
    
    if ActivePed:getTotalPets() == 0 then
        print('>>> NO PETS IN DATA <<<')
    else
        for i, pet in pairs(ActivePed.data) do
            print('--- Pet Index: ' .. i .. ' ---')
            if pet.itemData and pet.itemData.metadata then
                print('  Name: ' .. tostring(pet.itemData.metadata.name))
                print('  Hash: ' .. tostring(pet.itemData.metadata.hash))
            else
                print('  ERROR: Missing itemData')
            end
            print('  Entity: ' .. tostring(pet.entity))
            print('  Entity Exists: ' .. tostring(DoesEntityExist(pet.entity)))
            print('  NetID: ' .. tostring(pet.netId))
            print('  Health: ' .. tostring(pet.health))
            print('  Model: ' .. tostring(pet.model))
        end
    end
    
    print('------------------------------------------')
    local currentPet = ActivePed:read()
    if currentPet then
        print('✓ ACTIVE PET: ' .. currentPet.itemData.metadata.name)
    else
        print('✗ NO ACTIVE PET')
    end
    print('==========================================')
    
    -- Also send notification
    exports.qbx_core:Notify('Pet Debug info printed to F8', 'info', 3000)
end, false)

-- Test command to verify script loaded
RegisterCommand('pettest', function()
    print('[Keep-Companion] Script is loaded!')
    print('[Keep-Companion] ActivePed exists: ' .. tostring(ActivePed ~= nil))
    print('[Keep-Companion] onControl: ' .. tostring(ActivePed.onControl))
    exports.qbx_core:Notify('Keep-Companion is loaded! Check F8', 'success', 3000)
end, false)

RegisterNetEvent('keep-companion:client:callCompanion', function(modelName, hostileTowardPlayer, item)
    print('[Keep-Companion] ===== SPAWN PET START =====')
    print('[Keep-Companion] Model: ' .. tostring(modelName))
    print('[Keep-Companion] Item name: ' .. tostring(item.name))
    print('[Keep-Companion] Item hash: ' .. tostring(item.metadata.hash))
    
    local model = (tonumber(modelName) ~= nil and tonumber(modelName) or GetHashKey(modelName))
    local plyPed = PlayerPedId()
    
    SetCurrentPedWeapon(plyPed, 0xA2719263, true)
    ClearPedTasks(plyPed)

    whistleAnimation(plyPed, 1500)

    if lib.progressBar({
        duration = Config.Settings.callCompanionDuration * 1000,
        label = 'Calling companion',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = false,
            car = false,
            mouse = false,
            combat = false
        }
    }) then
        ClearPedTasks(plyPed)

        local spawnCoord = getSpawnLocation(plyPed)
        print('[Keep-Companion] Creating ped at: ' .. tostring(spawnCoord))
        
        local ped = CreateAPed(model, spawnCoord)
        
        if not DoesEntityExist(ped) then
            print('[Keep-Companion] ERROR: Failed to create ped entity')
            exports.qbx_core:Notify('Failed to spawn pet', 'error', 5000)
            return
        end
        
        local netId = NetworkGetNetworkIdFromEntity(ped)
        print('[Keep-Companion] Ped created | Entity: ' .. ped .. ' | NetID: ' .. netId)
        
        QBCore.Functions.TriggerCallback('keep-companion:server:updatePedData', function(result)
            print('[Keep-Companion] Server callback result: ' .. tostring(result))
            
            if not result then
                exports.qbx_core:Notify('Failed to register pet on server', 'error', 5000)
                DeletePed(ped)
                return
            end
            
            ClearPedTasks(ped)
            TaskFollowTargetedPlayer(ped, plyPed, 3.0, true)

            if Config.Settings.PetMiniMap.showblip then
                createBlip({
                    entity = ped,
                    sprite = Config.Settings.PetMiniMap.sprite,
                    colour = Config.Settings.PetMiniMap.colour,
                    text = item.metadata.name,
                    shortRange = false
                })
            end

            print('[Keep-Companion] Calling ActivePed:new')
            local success = ActivePed:new(modelName, hostileTowardPlayer, item, ped, netId)
            
            if not success then
                print('[Keep-Companion] ERROR: ActivePed:new failed')
                exports.qbx_core:Notify('Failed to initialize pet', 'error', 5000)
                DeletePed(ped)
                return
            end
            
            print('[Keep-Companion] Looking for pet by hash: ' .. item.metadata.hash)
            local index, petData = ActivePed:findByHash(item.metadata.hash)
            
            if not petData then
                print('[Keep-Companion] ERROR: Could not find pet after creation')
                exports.qbx_core:Notify('Pet data lost after creation', 'error', 5000)
                DeletePed(ped)
                return
            end
            
            print('[Keep-Companion] Pet found at index: ' .. index)
            
            if hostileTowardPlayer == true then
                exports.qbx_core:Notify(Lang:t('error.not_owner_of_pet'), 'error', 5000)
                TriggerServerEvent('keep-companion:server:despwan_not_owned_pet', petData.itemData.metadata.hash)
                return
            end

            if petData.itemData.metadata.variation ~= nil then
                PetVariation:setPedVariation(ped, modelName, petData.itemData.metadata.variation)
            end
            
            SetEntityMaxHealth(ped, petData.maxHealth)
            SetEntityHealth(ped, math.floor(petData.itemData.metadata.health))
            
            print('[Keep-Companion] Setting up ox_target')
            exports.ox_target:addLocalEntity(ped, {
                {
                    icon = "fas fa-hand",
                    label = "Pet",
                    canInteract = function(entity)
                        return not IsEntityDead(entity)
                    end,
                    onSelect = function(data)
                        local entity = data.entity
                        makeEntityFaceEntity(PlayerPedId(), entity)
                        makeEntityFaceEntity(entity, PlayerPedId())

                        local playerPed = PlayerPedId()
                        local coords = GetEntityCoords(playerPed)
                        local forward = GetEntityForwardVector(playerPed)
                        local x, y, z = table.unpack(coords + forward * 1.0)

                        SetEntityCoords(entity, x, y, z, 0, 0, 0, 0)
                        TaskPause(entity, 5000)

                        Animator(entity, modelName, 'tricks', {
                            animation = 'petting_chop'
                        })
                        Animator(plyPed, 'A_C_Rottweiler', 'tricks', {
                            animation = 'petting_franklin'
                        })

                        TriggerServerEvent('hud:server:RelieveStress', Config.Balance.petting_stress_relief)
                    end
                },
                {
                    icon = "fas fa-first-aid",
                    label = "Heal",
                    canInteract = function(entity)
                        return not IsEntityDead(entity)
                    end,
                    onSelect = function(data)
                        request_healing_process(ped, item, 'Heal')
                    end
                },
                {
                    icon = "fas fa-heartbeat",
                    label = "Revive pet",
                    canInteract = function(entity)
                        return IsEntityDead(entity)
                    end,
                    onSelect = function(data)
                        request_healing_process(ped, item, 'revive')
                    end
                },
                {
                    icon = "fa-solid fa-flask",
                    label = "Drink water",
                    canInteract = function(entity)
                        return not IsEntityDead(entity)
                    end,
                    onSelect = function(data)
                        start_drinking_animation(item)
                    end
                }
            })

            local currentHealth = GetEntityHealth(ped)
            if currentHealth > 100 then
                print('[Keep-Companion] Starting pet thread')
                creatActivePetThread(ped, item)
            end
            
            print('[Keep-Companion] ===== SPAWN PET COMPLETE =====')
        end, {
            item = item, 
            model = model, 
            entity = ped
        })
    end
end)

function request_healing_process(ped, item, process_type)
    local hasitem = exports.ox_inventory:Search('count', Config.core_items.firstaid.item_name)
    if hasitem < 1 then 
        exports.qbx_core:Notify(Lang:t('error.not_enough_first_aid'), 'error', 5000)
        return 
    end

    local plyID = PlayerPedId()
    local timeout = Config.core_items.firstaid.settings.duration
    local index = ActivePed:findByHash(item.metadata.hash)
    
    if not index then
        exports.qbx_core:Notify('Pet not found', 'error', 5000)
        return
    end
    
    local current_pet = ActivePed.data[index]

    if process_type == 'Heal' then
        timeout = timeout * math.floor(Config.core_items.firstaid.settings.healing_duration_multiplier)
        makeEntityFaceEntity(ped, plyID)
        TaskPause(ped, 5000)
    else
        timeout = timeout * math.floor(Config.core_items.firstaid.settings.revive_duration_multiplier)
    end
    makeEntityFaceEntity(plyID, ped)

    Animator(plyID, "PLAYER", 'revive', {
        animation = 'tendtodead',
        sequentialTimings = {
            [1] = timeout,
            [2] = 0,
            [3] = 0,
            step = 1,
            Timeout = timeout
        }
    })

    if lib.progressBar({
        duration = timeout * 1000,
        label = 'Reviving',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            mouse = false,
            combat = true
        }
    }) then
        TriggerServerEvent('keep-companion:server:revivePet', current_pet, process_type)
        TaskFollowTargetedPlayer(ped, plyID, false)
    end
end

RegisterNetEvent('keep-companion:client:update_health_value', function(item, amount)
    SetEntityHealth(item.entity, math.floor(amount))
end)

local function afkWandering(timeOut, afk, plyPed, ped)
    local coord = GetEntityCoords(plyPed)
    if IsPedStopped(plyPed) and not IsPedInAnyVehicle(plyPed) then
        if timeOut[1] < afk.afkTimerRestAfter then
            timeOut[1] = timeOut[1] + 1
            
            if timeOut[1] == afk.wanderingInterval then
                if timeOut.lastAction == nil or timeOut.lastAction == 'animation' then
                    ClearPedTasks(ped)
                    TaskWanderInArea(ped, coord, 4.0, 2, 8.0)
                    timeOut.lastAction = 'wandering'
                end
            end
            if timeOut[1] == afk.animationInterval then
                ClearPedTasks(ped)
                Animator(ped, ActivePed:read().model, 'siting')
                timeOut.lastAction = 'animation'
            end
        else
            timeOut[1] = 0
        end
    else
        timeOut[1] = 0
    end
end

function creatActivePetThread(ped, item)
    local afk = Config.Balance.afk
    local count = Config.DataUpdateInterval
    
    CreateThread(function()
        local tmpcount = 0
        local index = ActivePed:findByHash(item.metadata.hash)
        
        if not index then
            print('[Keep-Companion] ERROR: Could not find pet for thread')
            return
        end
        
        local savedData = ActivePed.data[index]
        local finished = false
        local timeOut = { 0, lastAction = nil }
        
        while DoesEntityExist(ped) and not finished do
            local plyPed = PlayerPedId()
            afkWandering(timeOut, afk, plyPed, ped)

            if tmpcount >= count then
                TriggerServerEvent('keep-companion:server:updateAllowedInfo', {
                    hash = savedData.itemData.metadata.hash,
                    slot = savedData.itemData.slot
                }, { key = 'XP' })
                tmpcount = 0
            end
            tmpcount = tmpcount + 1

            local currentHealth = GetEntityHealth(savedData.entity)
            if not IsPedDeadOrDying(savedData.entity) and savedData.health ~= currentHealth then
                TriggerServerEvent('keep-companion:server:updateAllowedInfo', {
                    hash = savedData.itemData.metadata.hash,
                    slot = savedData.itemData.slot
                }, {
                    key = 'health',
                    netId = NetworkGetNetworkIdFromEntity(ped),
                })
                savedData.health = currentHealth
            end
            
            if IsPedDeadOrDying(savedData.entity) then
                local c_health = GetEntityHealth(savedData.entity)
                if c_health <= 100 then
                    TriggerServerEvent('keep-companion:server:updateAllowedInfo', {
                        hash = savedData.itemData.metadata.hash,
                        slot = savedData.itemData.slot
                    }, {
                        key = 'health',
                        netId = NetworkGetNetworkIdFromEntity(ped),
                    })
                    finished = true
                end
            end
            Wait(1000)
        end
    end)
end

RegisterNetEvent('keep-companion:client:forceKill', function(hash, reason)
    local index, petData = ActivePed:findByHash(hash)
    if not petData then return end
    
    local c_health = GetEntityHealth(petData.entity)
    if c_health < 100 then return end
    
    petData.health = 0
    SetEntityHealth(petData.entity, 0)
    local msg = string.format(Lang:t('error.your_pet_died_by'), reason)
    exports.qbx_core:Notify(msg, 'error', 5000)
end)

RegisterNetEvent('keep-companion:client:despawn', function(item, revive)
    if revive then
        local index = ActivePed:findByHash(item.metadata.hash)
        if index then
            ActivePed:remove(index)
        end
        TriggerServerEvent('keep-companion:server:setAsDespawned', item)
        return
    end
    
    local plyPed = PlayerPedId()
    SetCurrentPedWeapon(plyPed, 0xA2719263, true)
    ClearPedTasks(plyPed)
    whistleAnimation(plyPed, 1500)

    if lib.progressBar({
        duration = Config.Settings.despawnDuration * 1000,
        label = 'Despawning',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = false,
            car = false,
            mouse = false,
            combat = false
        }
    }) then
        ClearPedTasks(plyPed)
        local index = ActivePed:findByHash(item.metadata.hash)
        if index then
            ActivePed:remove(index)
        end
        TriggerServerEvent('keep-companion:server:setAsDespawned', item)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    ActivePed:removeAll()
end)

-- Feeding
RegisterNetEvent('keep-companion:client:start_feeding_animation', function()
    local current_pet = ActivePed:read()
    if not current_pet then
        exports.qbx_core:Notify(Lang:t('error.no_pet_under_control'), 'error', 5000)
        return
    end

    local c_health = GetEntityHealth(current_pet.entity)
    if c_health <= 100 then
        exports.qbx_core:Notify(Lang:t('error.your_pet_is_dead'), 'error', 5000)
        return
    end

    if lib.progressBar({
        duration = Config.core_items.food.settings.duration * 1000,
        label = 'Feeding',
        useWhileDead = false,
        canCancel = false,
        disable = { move = false, car = false, mouse = false, combat = false }
    }) then
        TriggerServerEvent('keep-companion:server:increaseFood', current_pet.itemData)
    end
end)

function start_drinking_animation()
    local current_pet = ActivePed:read()
    if not current_pet then
        exports.qbx_core:Notify(Lang:t('error.no_pet_under_control'), 'error', 5000)
        return
    end

    local c_health = GetEntityHealth(current_pet.entity)
    if c_health <= 100 then
        exports.qbx_core:Notify(Lang:t('error.your_pet_is_dead'), 'error', 5000)
        return
    end

    if lib.progressBar({
        duration = Config.core_items.waterbottle.settings.duration * 1000,
        label = 'Drinking',
        useWhileDead = false,
        canCancel = false,
        disable = { move = false, car = false, mouse = false, combat = false }
    }) then
        lib.callback('keep-companion:server:decrease_thirst', false, function(result)
        end, current_pet.itemData)
    end
end

RegisterNetEvent('keep-companion:client:filling_animation', function(item)
    if lib.progressBar({
        duration = Config.core_items.waterbottle.settings.duration * 1000,
        label = 'Filling bottle',
        useWhileDead = false,
        canCancel = false,
        disable = { move = false, car = false, mouse = false, combat = false }
    }) then
        TriggerServerEvent('keep-companion:server:filling_event', item)
    end
end)

RegisterNetEvent('keep-companion:client:rename_name_tag', function(item)
    if not ActivePed:read() then
        exports.qbx_core:Notify(Lang:t('error.no_pet_under_control'), 'error', 5000)
        return
    end

    local input = lib.inputDialog('Rename: ' .. ActivePed:read().itemData.metadata.name, {
        {type = 'input', label = 'Pet Name', required = true, max = 12}
    })

    if input then
        TriggerServerEvent('keep-companion:server:rename_name_tag', input[1])
    end
end)

RegisterNetEvent('keep-companion:client:rename_name_tagAction', function(name)
    local activePed = ActivePed:read()
    if not activePed then
        exports.qbx_core:Notify(Lang:t('error.no_pet_under_control'), 'error', 5000)
        return
    end

    local validation = ValidatePetName(name, 12)
    if type(validation) == "table" and next(validation) ~= nil then
        exports.qbx_core:Notify(Lang:t('error.failed_to_validate_name'), 'error', 5000)
        return
    end

    if lib.progressBar({
        duration = Config.core_items.nametag.settings.duration * 1000,
        label = 'Setting name',
        useWhileDead = false,
        canCancel = false,
        disable = { move = false, car = false, mouse = false, combat = true }
    }) then
        lib.callback('keep-companion:server:renamePet', false, function(result)
            if type(result) == "string" then
                exports.qbx_core:Notify(Lang:t('success.pet_rename_was_successful') .. result, 'success', 5000)
            end
        end, {
            hash = activePed.itemData.metadata.hash,
            slot = activePed.itemData.slot,
            name = name
        })
    end
end)

RegisterNetEvent('keep-companion:client:collar_process', function()
    local activePed = ActivePed:read()
    if not activePed then
        exports.qbx_core:Notify(Lang:t('error.no_pet_under_control'), 'error', 5000)
        return
    end

    local input = lib.inputDialog('New Owner ID', {
        {type = 'number', label = 'Owner ID', required = true}
    })

    if input then
        if lib.progressBar({
            duration = Config.core_items.collar.settings.duration * 1000,
            label = 'Transferring ownership',
            useWhileDead = false,
            canCancel = false,
            disable = { move = false, car = false, mouse = false, combat = true }
        }) then
            lib.callback('keep-companion:server:collar_change_owenership', false, function(result)
                exports.qbx_core:Notify(result.msg, result.state and 'success' or 'error', 5000)
            end, {
                new_owner_cid = input[1],
                hash = activePed.itemData.metadata.hash,
            })
        end
    end
end)