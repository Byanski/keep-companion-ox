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
    local index = (#self.data + 1)
    
    print('[Keep-Companion] Creating new ActivePed | Index: ' .. index .. ' | Model: ' .. model .. ' | Hash: ' .. (item.metadata.hash or 'NO_HASH'))
    
    if self.data[index] == nil then
        self.data[index] = {}
        self.onControl = index
    else
        self.onControl = self.onControl + 1
    end

    self.data[index]['model'] = model
    self.data[index]['entity'] = ped
    self.data[index]['netId'] = netId
    self.data[index]['hostile'] = hostile
    self.data[index]['itemData'] = item
    self.data[index]['lastCoord'] = GetEntityCoords(ped)
    self.data[index]['variation'] = item.metadata.variation
    self.data[index]['health'] = item.metadata.health

    for key, information in pairs(Config.pets) do
        if information.name == item.name then
            self.data[index]['modelString'] = information.model
            self.data[index]['maxHealth'] = information.maxHealth
            for w in information.distinct:gmatch("%S+") do
                if w == 'yes' then
                    self.data[index]['canHunt'] = true
                elseif w == 'no' then
                    self.data[index]['canHunt'] = false
                end
            end
            print('[Keep-Companion] ActivePed created successfully | onControl: ' .. self.onControl)
            return
        end
    end
end

--- return current active pet
function ActivePed:read()
    local index = ActivePed.onControl
    if index == -1 or not self.data[index] then
        print('[Keep-Companion] No active pet | onControl: ' .. index)
        return nil
    end
    return ActivePed.data[index]
end

--- clean current ped data
function ActivePed:remove(index)
    local netId = NetworkGetNetworkIdFromEntity(self.data[index].entity)
    if not netId then return end
    TriggerServerEvent('keep-companion:server:ForceRemoveNetEntity', netId)
    self.data[index] = nil
    
    if #self.data == 0 then
        self.onControl = -1
        return
    end
    for key, value in pairs(self.data) do
        self.onControl = key
        return
    end
end

function ActivePed:removeAll()
    local tmpHash = {}
    for key, value in pairs(ActivePed:petsList()) do
        DeletePed(value.pedHandle)
        table.insert(tmpHash, value.itemData)
        local currentItem = {
            hash = value.itemData.metadata.hash or nil,
            slot = value.itemData.slot or nil
        }

        TriggerServerEvent('keep-companion:server:updateAllowedInfo', currentItem, {
            key = 'XP',
        })
    end
    TriggerServerEvent('keep-companion:server:onPlayerUnload', tmpHash)
    self.data = {}
    self.onControl = -1
end

function ActivePed:switchControl(to)
    if to > #self.data or to < 1 then
        return
    end
    self.onControl = to
end

function ActivePed:findByHash(hash)
    for key, data in pairs(self.data) do
        if data.itemData.metadata.hash == hash then
            return key, data
        end
    end
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

RegisterNetEvent('keep-companion:client:callCompanion', function(modelName, hostileTowardPlayer, item)
    local model = (tonumber(modelName) ~= nil and tonumber(modelName) or GetHashKey(modelName))
    local plyPed = PlayerPedId()
    local ped = nil
    SetCurrentPedWeapon(plyPed, 0xA2719263, true)
    ClearPedTasks(plyPed)

    whistleAnimation(plyPed, 1500)

    -- Use ox_lib progressbar instead of QBCore
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
        ped = CreateAPed(model, spawnCoord)
        local netId = NetworkGetNetworkIdFromEntity(ped)
        
        QBCore.Functions.TriggerCallback('keep-companion:server:updatePedData', function(result)
            if not result then
                exports.qbx_core:Notify('Failed to register pet', 'error', 5000)
                DeletePed(ped)
                return
            end
            
            if hostileTowardPlayer == true then
                exports.qbx_core:Notify(Lang:t('error.not_owner_of_pet'), 'error', 5000)
                return
            end
            ClearPedTasks(ped)
            TaskFollowTargetedPlayer(ped, plyPed, 3.0, true)

            if Config.Settings.PetMiniMap.showblip ~= nil and Config.Settings.PetMiniMap.showblip == true then
                createBlip({
                    entity = ped,
                    sprite = Config.Settings.PetMiniMap.sprite,
                    colour = Config.Settings.PetMiniMap.colour,
                    text = item.metadata.name,
                    shortRange = false
                })
            end

            ActivePed:new(modelName, hostileTowardPlayer, item, ped, netId)
            local index, petData = ActivePed:findByHash(item.metadata.hash)
            
            if not petData then
                exports.qbx_core:Notify('Failed to initialize pet data', 'error', 5000)
                DeletePed(ped)
                return
            end

            if petData.itemData.metadata.variation ~= nil then
                PetVariation:setPedVariation(ped, modelName, petData.itemData.metadata.variation)
            end
            SetEntityMaxHealth(ped, petData.maxHealth)
            SetEntityHealth(ped, math.floor(petData.itemData.metadata.health))
            local currentHealth = GetEntityHealth(ped)

            exports.ox_target:addLocalEntity(ped, {
                {
                    icon = "fas fa-sack-dollar",
                    label = "Pet",
                    canInteract = function(entity)
                        return (not IsEntityDead(entity) and ActivePed.read() ~= nil)
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
                        return true
                    end
                },
                {
                    icon = "fas fa-first-aid",
                    label = "Heal",
                    canInteract = function(entity)
                        return (not IsEntityDead(entity) and ActivePed.read() ~= nil)
                    end,
                    onSelect = function(data)
                        request_healing_process(ped, item, 'Heal')
                        return true
                    end
                },
                {
                    icon = "fas fa-first-aid",
                    label = "Revive pet",
                    canInteract = function(entity)
                        return (IsEntityDead(entity) and ActivePed.read() ~= nil)
                    end,
                    onSelect = function(data)
                        if not DoesEntityExist(data.entity) then
                            return false
                        end
                        request_healing_process(ped, item, 'revive')
                        return true
                    end
                },
                {
                    icon = "fa-solid fa-flask",
                    label = "Drink from water bottle",
                    canInteract = function(entity)
                        return (not IsEntityDead(entity) and ActivePed.read() ~= nil)
                    end,
                    onSelect = function(data)
                        if not DoesEntityExist(data.entity) then
                            return false
                        end
                        start_drinking_animation(item)
                        return true
                    end
                }
            })

            if petData.hostile == true then
                TriggerServerEvent('keep-companion:server:despwan_not_owned_pet', petData.itemData.metadata.hash)
                return
            end

            if currentHealth > 100 then
                creatActivePetThread(ped, item)
            end
        end, {
            item = item, model = model, entity = ped
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
    local current_pet = ActivePed.data[ActivePed:findByHash(item.metadata.hash)]

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
                if timeOut.lastAction == nil or (timeOut.lastAction ~= nil and timeOut.lastAction == 'animation') then
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
    local plyPed = PlayerPedId()
    CreateThread(function()
        local tmpcount = 0
        local savedData = ActivePed.data[ActivePed:findByHash(item.metadata.hash)]
        local finished = false
        local timeOut = {
            0,
            lastAction = nil
        }
        while DoesEntityExist(ped) and not finished do
            afkWandering(timeOut, afk, plyPed, ped)

            if tmpcount >= count then
                local activeped = savedData
                local currentItem = {
                    hash = activeped.itemData.metadata.hash,
                    slot = activeped.itemData.slot
                }

                TriggerServerEvent('keep-companion:server:updateAllowedInfo', currentItem, {
                    key = 'XP',
                })

                tmpcount = 0
            end
            tmpcount = tmpcount + 1

            local currentHealth = GetEntityHealth(savedData.entity)
            if not IsPedDeadOrDying(savedData.entity) and savedData.maxHealth ~= currentHealth and
                savedData.health ~= currentHealth then
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
    local c_health = GetEntityHealth(petData.entity)
    if c_health < 100 then
        return
    end
    petData.health = 0
    SetEntityHealth(petData.entity, 0)
    local msg = Lang:t('error.your_pet_died_by')
    msg = string.format(msg, reason)
    exports.qbx_core:Notify(msg, 'error', 5000)
end)

RegisterNetEvent('keep-companion:client:despawn', function(item, revive)
    if revive ~= nil and revive == true then
        local index, pedData = ActivePed:findByHash(item.metadata.hash)
        ActivePed:remove(index)
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
        local index, pedData = ActivePed:findByHash(item.metadata.hash)
        ActivePed:remove(index)
        TriggerServerEvent('keep-companion:server:setAsDespawned', item)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    ActivePed:removeAll()
end)

-- =========================================
--          Commands Client Events
-- =========================================

RegisterNetEvent('keep-companion:client:start_feeding_animation', function()
    local current_pet = ActivePed:read()

    if current_pet == nil then
        exports.qbx_core:Notify(Lang:t('error.no_pet_under_control'), 'error', 5000)
        return
    end

    local c_health = GetEntityHealth(current_pet.entity)
    if c_health <= 100.0 or current_pet.itemData.metadata.health <= 100.0 then
        exports.qbx_core:Notify(Lang:t('error.your_pet_is_dead'), 'error', 5000)
        return
    end

    if lib.progressBar({
        duration = Config.core_items.food.settings.duration * 1000,
        label = 'Feeding',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = false,
            car = false,
            mouse = false,
            combat = false
        }
    }) then
        TriggerServerEvent('keep-companion:server:increaseFood', current_pet.itemData)
    end
end)

function start_drinking_animation()
    local current_pet = ActivePed:read()

    if current_pet == nil then
        exports.qbx_core:Notify(Lang:t('error.no_pet_under_control'), 'error', 5000)
        return
    end

    local c_health = GetEntityHealth(current_pet.entity)
    if c_health <= 100.0 or current_pet.itemData.metadata.health <= 100.0 then
        exports.qbx_core:Notify(Lang:t('error.your_pet_is_dead'), 'error', 5000)
        return
    end

    if lib.progressBar({
        duration = Config.core_items.waterbottle.settings.duration * 1000,
        label = 'Drinking',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = false,
            car = false,
            mouse = false,
            combat = false
        }
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
        disable = {
            move = false,
            car = false,
            mouse = false,
            combat = false
        }
    }) then
        TriggerServerEvent('keep-companion:server:filling_event', item)
    end
end)

RegisterNetEvent('keep-companion:client:rename_name_tag', function(item)
    if ActivePed:read() == nil then
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
    local activePed = ActivePed:read() or nil
    local validation = ValidatePetName(name, 12)

    if activePed == nil then
        exports.qbx_core:Notify(Lang:t('error.no_pet_under_control'), 'error', 5000)
        return
    end

    if activePed.itemData.metadata.hash == nil or type(name) ~= "string" then
        exports.qbx_core:Notify(Lang:t('error.failed_to_start_procces'), 'error', 5000)
        return
    end

    if type(validation) == "table" and next(validation) ~= nil then
        exports.qbx_core:Notify(Lang:t('error.failed_to_validate_name'), 'error', 5000)
        if validation.reason == 'badword' then
            exports.qbx_core:Notify(Lang:t('error.badword_inside_pet_name'), 'error', 5000)
            return
        elseif validation.reason == 'maxCharacter' then
            exports.qbx_core:Notify(Lang:t('error.more_than_one_word_as_name'), 'error', 5000)
            return
        end
        return
    end

    if lib.progressBar({
        duration = Config.core_items.nametag.settings.duration * 1000,
        label = 'Waiting for Name',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = false,
            car = false,
            mouse = false,
            combat = true
        }
    }) then
        lib.callback('keep-companion:server:renamePet', false, function(result)
            if type(result) == "string" then
                exports.qbx_core:Notify(Lang:t('success.pet_rename_was_successful') .. result, 'success', 5000)
            end
        end, {
            hash = activePed.itemData.metadata.hash or nil,
            slot = activePed.itemData.slot or nil,
            name = name
        })
    end
end)

RegisterNetEvent('keep-companion:client:collar_process', function()
    local activePed = ActivePed:read() or nil

    if activePed == nil then
        exports.qbx_core:Notify(Lang:t('error.no_pet_under_control'), 'error', 5000)
        return
    end

    if activePed.itemData.metadata.hash == nil then
        exports.qbx_core:Notify(Lang:t('error.failed_to_find_pet'), 'error', 5000)
        return
    end

    local input = lib.inputDialog('New Owner ID', {
        {type = 'number', label = 'Owner ID', required = true}
    })

    if input then
        if lib.progressBar({
            duration = Config.core_items.collar.settings.duration * 1000,
            label = 'Waiting for new owner',
            useWhileDead = false,
            canCancel = false,
            disable = {
                move = false,
                car = false,
                mouse = false,
                combat = true
            }
        }) then
            local c_pet = ActivePed:read()
            if c_pet == nil then
                exports.qbx_core:Notify(Lang:t('error.no_pet_under_control'), 'error', 5000)
                return
            end
            
            lib.callback('keep-companion:server:collar_change_owenership', false, function(result)
                if result.state == false then
                    exports.qbx_core:Notify(result.msg, 'error', 5000)
                    return
                end
                exports.qbx_core:Notify(result.msg, 'success', 5000)
            end, {
                new_owner_cid = input[1],
                hash = ActivePed:read().itemData.metadata.hash,
            })
        end
    end
end)