function makeEntityFaceEntity(entity1, entity2)
    local p1 = GetEntityCoords(entity1, true)
    local p2 = GetEntityCoords(entity2, true)

    local dx = p2.x - p1.x
    local dy = p2.y - p1.y

    local heading = GetHeadingFromVector_2d(dx, dy)
    SetEntityHeading(entity1, heading)
end

function TaskFollowTargetedPlayer(follower, targetPlayer, distanceToStopAt, skip)
    ClearPedTasks(follower)
    
    -- Enable AI and movement
    SetPedCanRagdoll(follower, false)
    SetBlockingOfNonTemporaryEvents(follower, false)  -- Changed to false to allow movement
    SetPedFleeAttributes(follower, 0, false)
    SetPedCombatAttributes(follower, 17, true)
    
    if skip == false then
        TaskGoToCoordAnyMeans(follower, GetEntityCoords(targetPlayer), 10.0, 0, 0, 0, 0)
        Wait(5000)
    end
    
    TaskFollowToOffsetOfEntity(follower, targetPlayer, 2.5, 2.5, 2.5, 5.0, -1, distanceToStopAt, true)
    return true
end

function wanderAroundWithDuration(ped, coord, radius, minimalLength, timeBetweenWalks)
    local duration = 10
    CreateThread(function()
        local count = 0
        local continue = true
        while continue and DoesEntityExist(ped) do
            Wait(1000)
            count = count + 1
            if not GetIsTaskActive(ped, 222) then
                TaskWanderInArea(ped, coord, radius, minimalLength, timeBetweenWalks)
            end
            if count >= duration then
                continue = false
                ClearPedTasks(ped)
            end
        end
    end)
end

--- remove Relationship againt player.
---@param ped 'ped'
function removeRelationship(ped)
    if not ped then
        return
    end
    RemovePedFromGroup(ped)
end

--- set relationship with ped againt player. and disable Friendly fire when fighting againt player.
---@param ped 'ped'
function SetRelationshipBetweenPed(ped)
    if not ped then
        return
    end
    -- note: if we don't do this they will star fighting among themselves!
    RemovePedFromGroup(ped)
    SetPedRelationshipGroupHash(ped, GetHashKey(ped))
    SetCanAttackFriendly(ped, false, false)
end

function whistleAnimation(ped, timeout)
    CreateThread(function()
        waitForAnimation('rcmnigel1c')
        TaskPlayAnim(ped, "rcmnigel1c", "hailing_whistle_waive_a", 2.7, 2.7, -1, 49, 0, 0, 0, 0)
        Wait(timeout)
        ClearPedTasks(ped)
    end)
end

--- wait until animation is loaded
---@param animation any
function waitForAnimation(animation)
    RequestAnimDict(animation)
    while not HasAnimDictLoaded(animation) do
        Citizen.Wait(100)
    end
    return true
end

--- wait until model loaded
---@param model 'model'
function waitForModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(1)
    end
    return true
end

--- make blip
---@param data table
function createBlip(data)
    local blip = nil
    if data.petShop ~= nil then
        -- make blip for shop
        blip = AddBlipForCoord(data.petShop.x, data.petShop.y, data.petShop.z)
    elseif data.entity ~= nil then
        -- make blip for entities
        blip = AddBlipForEntity(data.entity)
    end
    if data.shortRange ~= nil and data.shortRange == true then
        SetBlipAsShortRange(blip, true)
    elseif data.shortRange == false then
        SetBlipAsShortRange(blip, false)
    end

    SetBlipSprite(blip, data.sprite)
    SetBlipColour(blip, data.colour)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(data.text)
    EndTextCommandSetBlipName(blip)
    return blip
end

function DeletePed(ped)
    if DoesEntityExist(ped) then
        DeleteEntity(ped)
    end
end

function CreateAPed(hash, pos)
    local ped = nil
    waitForModel(hash)

    ped = CreatePed(5, hash, pos.x, pos.y, pos.z, 0.0, true, false)

    while not DoesEntityExist(ped) do
        Wait(10)
    end

    -- Enable AI properly
    SetBlockingOfNonTemporaryEvents(ped, false)  -- Allow ped to move
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)  -- Can fight
    SetPedCombatAttributes(ped, 0, true)   -- Can use cover
    SetPedCombatAttributes(ped, 5, true)   -- Can do drivebys
    SetPedCombatAttributes(ped, 17, true)  -- Always fight
    SetPedCombatAttributes(ped, 20, true)  -- Aggressive
    
    -- Give the pet a "weapon" (melee) to actually deal damage
    GiveWeaponToPed(ped, GetHashKey("WEAPON_ANIMAL"), 1, false, true)
    SetPedCurrentWeaponVisible(ped, false, false, false, false)
    
    SetModelAsNoLongerNeeded(ped)
    return ped
end

--- creates laser and force ped to move toward coord
---@param ped 'ped'
function goThere(ped)
    CreateThread(function()
        local active = true
        while active do
            local color = { r = 2, g = 241, b = 181, a = 200 }
            local plyped = PlayerPedId()
            local position = GetEntityCoords(plyped)
            local coords, entity = RayCastGamePlayCamera(1000.0)
            
            Draw2DText('Press ~g~E~w~ to send pet here | ~r~X~w~ to cancel', 4, { 255, 255, 255 }, 0.4, 0.43, 0.888 + 0.025)
            
            if IsControlJustReleased(0, 38) then -- E key
                ClearPedTasks(ped)
                SetBlockingOfNonTemporaryEvents(ped, false)
                SetPedKeepTask(ped, true)
                
                -- Ground check
                local groundZ = coords.z
                local foundGround, zPos = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 100.0, false)
                if foundGround then
                    groundZ = zPos
                end
                
                TaskGoToCoordAnyMeans(ped, coords.x, coords.y, groundZ, 5.0, 0, false, 1, 0xbf800000)
                exports.qbx_core:Notify('Pet is going to location', 'success', 2000)
                active = false
            end
            
            if IsControlJustReleased(0, 73) then -- X key
                exports.qbx_core:Notify('Command cancelled', 'error', 2000)
                active = false
            end
            
            DrawLine(position.x, position.y, position.z, coords.x, coords.y, coords.z, color.r, color.g, color.b, color.a)
            DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.5, 0.5, 0.5, color.r, color.g,
                color.b, color.a, false, true, 2, nil, nil, false)
            Wait(0)
        end
    end)
end

--- logic to warp peds inside vehicles
function getIntoCar()
    local plyped = PlayerPedId()
    local activePet = ActivePed:read()
    if not activePet then
        exports.qbx_core:Notify(Lang:t('error.no_pet_under_control'), "error", 1500)
        return
    end
    
    local ped = activePet.entity
    local player_coord = GetEntityCoords(plyped)
    local pet_coord = GetEntityCoords(ped)
    local distance = #(player_coord - pet_coord)
    
    if not IsPedSittingInAnyVehicle(plyped) then
        exports.qbx_core:Notify('You need to be inside a vehicle', "error", 1500)
        return
    end
    
    if distance > 10 then
        exports.qbx_core:Notify('Pet is too far away', "error", 1500)
        return
    end
    
    local vehicle = GetVehiclePedIsUsing(plyped)
    local seatEmpty = -1

    -- Check for empty seats (skip driver seat)
    for i = 0, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if IsVehicleSeatFree(vehicle, i) then
            seatEmpty = i
            break
        end
    end

    if seatEmpty == -1 then
        exports.qbx_core:Notify('No empty seats available', "error", 1500)
        return
    end
    
    -- Put pet in vehicle
    ClearPedTasks(ped)
    TaskEnterVehicle(ped, vehicle, -1, seatEmpty, 2.0, 1, 0)
    
    -- Wait for pet to enter, then adjust position
    CreateThread(function()
        local timeout = 0
        while not IsPedInVehicle(ped, vehicle, false) and timeout < 50 do
            Wait(100)
            timeout = timeout + 1
        end
        
        if IsPedInVehicle(ped, vehicle, false) then
            -- Fix clipping by adjusting Z offset
            local offset = GetOffsetFromEntityGivenWorldCoords(vehicle, pet_coord.x, pet_coord.y, pet_coord.z)
            SetPedIntoVehicle(ped, vehicle, seatEmpty)
            
            -- Store that this pet is in a vehicle
            activePet.inVehicle = true
            activePet.vehicle = vehicle
            
            exports.qbx_core:Notify('Pet is now in the vehicle', 'success', 2000)
        else
            exports.qbx_core:Notify('Pet failed to enter vehicle', 'error', 2000)
        end
    end)
end

--- Remove pet from vehicle
function getOutOfCar()
    local plyped = PlayerPedId()
    local activePet = ActivePed:read()
    if not activePet then
        exports.qbx_core:Notify('No active pet', "error", 1500)
        return
    end
    
    local ped = activePet.entity
    
    if not IsPedInAnyVehicle(ped, false) then
        exports.qbx_core:Notify('Pet is not in a vehicle', "error", 1500)
        return
    end
    
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    TaskLeaveVehicle(ped, vehicle, 0)
    
    CreateThread(function()
        Wait(2000)
        activePet.inVehicle = false
        activePet.vehicle = nil
        ClearPedTasks(ped)
        TaskFollowToOffsetOfEntity(ped, plyped, 2.5, 2.5, 2.5, 5.0, -1, 3.0, true)
        exports.qbx_core:Notify('Pet exited the vehicle', 'success', 2000)
    end)
end

function attackLogic(alreadyHunting)
    CreateThread(function()
        local active = true
        while active do
            local color = { r = 255, g = 0, b = 0, a = 200 }
            local plyped = PlayerPedId()
            local position = GetEntityCoords(plyped)
            local coords, entity = RayCastGamePlayCamera(1000.0)
            
            Draw2DText('PRESS ~g~E~w~ TO ATTACK TARGET | ~r~X~w~ TO CANCEL', 4, { 255, 255, 255 }, 0.4, 0.43, 0.888 + 0.025)
            
            if IsControlJustReleased(0, 38) then -- E key
                ClearPedTasks(ActivePed:read().entity)
                
                -- Check if target is valid
                if not DoesEntityExist(entity) then
                    exports.qbx_core:Notify('No valid target', 'error', 2000)
                    active = false
                    return
                end
                
                if not IsEntityAPed(entity) then
                    exports.qbx_core:Notify('Target must be a ped', 'error', 2000)
                    active = false
                    return
                end

                local pet = ActivePed:read().entity
                local chaseDistance = Config.Settings.chaseDistance
                
                exports.qbx_core:Notify('Pet is attacking target!', 'success', 2000)
                alreadyHunting.state = true
                active = false
                
                -- Attack the target
                AttackTargetedPed(pet, entity)
                
                -- Monitor the attack and add manual damage if needed
                CreateThread(function()
                    local damageTimer = 0
                    local attackStarted = GetGameTimer()
                    
                    while not IsPedDeadOrDying(entity, false) do
                        Wait(500)
                        local pedCoord = GetEntityCoords(entity)
                        local petCoord = GetEntityCoords(pet)
                        local distance = GetDistanceBetweenCoords(pedCoord, petCoord, true)

                        -- Check if too far
                        if distance >= chaseDistance then
                            exports.qbx_core:Notify('Target escaped', 'error', 2000)
                            alreadyHunting.state = false
                            ClearPedTasks(pet)
                            TaskFollowToOffsetOfEntity(pet, plyped, 2.5, 2.5, 2.5, 5.0, -1, 3.0, true)
                            return
                        end
                        
                        -- If pet is close enough and attacking, apply damage manually
                        if distance < 2.0 then
                            damageTimer = damageTimer + 500
                            
                            -- Apply damage every 2 seconds
                            if damageTimer >= 2000 then
                                local currentHealth = GetEntityHealth(entity)
                                local newHealth = currentHealth - 20 -- 20 damage every 2 seconds
                                
                                if newHealth <= 100 then
                                    newHealth = 0
                                end
                                
                                SetEntityHealth(entity, newHealth)
                                damageTimer = 0
                                
                                -- Play attack animation sound effect
                                PlayPain(entity, 7, 0)
                            end
                        end
                        
                        -- Timeout after 30 seconds
                        if GetGameTimer() - attackStarted > 30000 then
                            exports.qbx_core:Notify('Attack timed out', 'error', 2000)
                            alreadyHunting.state = false
                            ClearPedTasks(pet)
                            TaskFollowToOffsetOfEntity(pet, plyped, 2.5, 2.5, 2.5, 5.0, -1, 3.0, true)
                            return
                        end
                    end
                    
                    exports.qbx_core:Notify('Target eliminated', 'success', 2000)
                    alreadyHunting.state = false
                    Wait(1000)
                    ClearPedTasks(pet)
                    TaskFollowToOffsetOfEntity(pet, plyped, 2.5, 2.5, 2.5, 5.0, -1, 3.0, true)
                end)
            end
            
            if IsControlJustReleased(0, 73) then -- X key
                exports.qbx_core:Notify('Attack cancelled', 'error', 2000)
                active = false
            end
            
            -- Draw targeting line
            if DoesEntityExist(entity) and IsEntityAPed(entity) then
                local entCoords = GetEntityCoords(entity)
                DrawLine(position.x, position.y, position.z, entCoords.x, entCoords.y, entCoords.z, color.r, color.g, color.b, color.a)
                DrawMarker(28, entCoords.x, entCoords.y, entCoords.z + 1.0, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.3, 0.3, 0.3, color.r, color.g,
                    color.b, color.a, false, true, 2, nil, nil, false)
            end
            
            Wait(0)
        end
    end)
end

function HuntandGrab(plyped, activePed)
    while true do
        Wait(0)
        local color = { r = 2, g = 241, b = 181, a = 200 }
        local position = GetEntityCoords(plyped)
        local coords, entity = RayCastGamePlayCamera(1000.0)
        Draw2DText('Press ~g~E~w~ To go there', 4, { 255, 255, 255 }, 0.4, 0.43, 0.888 + 0.025)
        if IsControlJustReleased(0, 38) then
            local pet = activePed.entity
            if IsPedAPlayer(entity) == 1 or IsEntityAPed(entity) == false or entity == pet then
                exports.qbx_core:Notify(Lang:t('error.could_not_do_that'), "error", 1500)
                return
            end

            TaskFollowToOffsetOfEntity(pet, entity, 0.0, 0.0, 0.0, 5.0, 10.0, 1.0, 1)
            while true do
                local pedCoord = GetEntityCoords(entity)
                local petCoord = GetEntityCoords(pet)
                local distance = GetDistanceBetweenCoords(pedCoord, petCoord)
                if distance >= 50.0 then
                    -- skip when to much distance
                    break
                else
                    AttackTargetedPed(pet, entity)
                    -- wait until pet kills target
                    while IsPedDeadOrDying(entity) == false do
                        Wait(250)
                    end
                    -- drag dead body
                    SetEntityCoords(entity, GetOffsetFromEntityInWorldCoords(pet, 0.0, 0.25, 0.0))
                    AttachEntityToEntity(entity, pet, 11816, 0.05, 0.05, 0.5, 0.0, 0.0, 0.0, false, false,
                        false, false, 2, true)
                    -- finish loop
                    break
                end
                Wait(500)
            end
            -- Detach entity when it has to much distance or it's near player

            TaskFollowToOffsetOfEntity(pet, plyped, 2.0, 2.0, 2.0, 1.0, 10.0, 3.0, 1)
            while true do
                local pedCoord = GetEntityCoords(plyped)
                local petCoord = GetEntityCoords(pet)
                local distance = GetDistanceBetweenCoords(pedCoord, petCoord)
                if entity ~= nil and distance < 3.0 or distance > 50.0 then
                    DetachEntity(entity, true, false)
                    ClearPedSecondaryTask(pet)
                    return
                end
                Wait(1000)
            end
            return -- just incase
        end
        DrawLine(position.x, position.y, position.z, coords.x, coords.y, coords.z, color.r, color.g, color.b, color.a)
        DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.1, 0.1, 0.1, color.r, color.g,
            color.b, color.a, false, true, 2, nil, nil, false)
    end
end

function get_player_cid()
    local players = GetActivePlayers()

    for _, player in pairs(players) do
        if player == PlayerId() then
            return _
        end
    end
    return false
end

--- Check if model can detect drugs
local function canDetectDrugs(model)
    for key, drugDogModel in pairs(Config.k9.detection_models) do
        if model == drugDogModel then
            return true
        end
    end
    return false
end

--- Search nearby players for illegal items (police only)
function SearchLogic(plyped, activePed)
    if not PlayerJob then return end
    if not (PlayerJob.name == 'police') then
        exports.qbx_core:Notify('You are not allowed to do this action', "error", 1500)
        return
    end

    if not PlayerJob.onduty then
        exports.qbx_core:Notify('You must be on duty to do this action', "error", 1500)
        return
    end
    
    if not canDetectDrugs(activePed.model) then
        exports.qbx_core:Notify('This pet cannot detect drugs', "error", 1500)
        return
    end

    local pedCoord = GetEntityCoords(PlayerPedId())
    local closestPlayer = QBCore.Functions.GetClosestPlayer(pedCoord)
    
    if closestPlayer == -1 then
        exports.qbx_core:Notify('No players nearby', "error", 1500)
        return
    end
    
    local pedplayer = GetPlayerPed(closestPlayer)
    local targetCoords = GetEntityCoords(pedplayer)
    local distance = #(pedCoord - targetCoords)
    
    if distance > Config.k9.search_distance then
        exports.qbx_core:Notify('Target is too far away', "error", 1500)
        return
    end

    ClearPedTasks(activePed.entity)
    TaskGoToCoordAnyMeans(activePed.entity, targetCoords, 5.0, 0, 0, 0, 0)

    local finished = false
    CreateThread(function()
        while not finished do
            Wait(5)
            pedCoord = GetEntityCoords(GetPlayerPed(closestPlayer))
            DrawMarker(2, pedCoord.x, pedCoord.y, pedCoord.z + 2, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 1.0, 1.0,
                1.0, 255, 128, 0, 50, false, true, 2, nil, nil, false)
        end
    end)

    local player_server_id = GetPlayerServerId(closestPlayer)
    
    Wait(3000)  -- Wait for dog to reach target
    
    Animator(activePed.entity, activePed.model, 'misc', {
        animation = 'indicate_low',
        sequentialTimings = {
            [1] = 6,
            [2] = 0,
            [3] = 2,
            step = 1,
            Timeout = 6
        }
    })
    
    lib.callback('keep-companion:server:search_inventory', false, function(result)
        Wait(5000)

        if result == true then
            -- Dog found drugs!
            exports.qbx_core:Notify('K9 ALERT: Illegal substances detected!', 'error', Config.k9.alert_duration)
            SetAnimalMood(activePed.entity, 1)
            PlayAnimalVocalization(activePed.entity, 3, 'bark')
            
            Animator(activePed.entity, activePed.model, 'misc', {
                animation = 'indicate_high',
                sequentialTimings = {
                    [1] = 6,
                    [2] = 0,
                    [3] = 2,
                    step = 1,
                    Timeout = 6
                }
            })
            
            -- Alert screen notification
            CreateThread(function()
                local endTime = GetGameTimer() + Config.k9.alert_duration
                while GetGameTimer() < endTime do
                    SetTextFont(4)
                    SetTextScale(0.0, 0.7)
                    SetTextColour(255, 0, 0, 255)
                    SetTextDropshadow(0, 0, 0, 0, 255)
                    SetTextEdge(1, 0, 0, 0, 255)
                    SetTextDropShadow()
                    SetTextOutline()
                    SetTextCentre(true)
                    BeginTextCommandDisplayText("STRING")
                    AddTextComponentSubstringPlayerName("~r~K9 ALERT: ILLEGAL ITEMS DETECTED")
                    EndTextCommandDisplayText(0.5, 0.85)
                    Wait(0)
                end
            end)
        else
            exports.qbx_core:Notify('K9 found nothing suspicious', 'success', 2500)
        end
        finished = true
        
        -- Return dog to owner
        Wait(2000)
        ClearPedTasks(activePed.entity)
        TaskFollowToOffsetOfEntity(activePed.entity, plyped, 2.5, 2.5, 2.5, 5.0, -1, 3.0, true)
    end, player_server_id)
end

--- if player is inside a vehicle we need to relocate ped location so they won't sucide
---@param ped 'ped'
function doSomethingIfPedIsInsideVehicle(ped)
    local playerped = PlayerPedId()
    local coord = getSpawnLocation(playerped)
    if IsPedInAnyVehicle(ped, true) then
        SetEntityCoords(ped, coord, 1, 0, 0, 1)
    end
    Wait(75)
end

function getSpawnLocation(plyped)
    if IsPedInAnyVehicle(plyped, true) then
        return GetOffsetFromEntityInWorldCoords(plyped, -2.0, 1.0, 0.5)
    else
        return GetOffsetFromEntityInWorldCoords(plyped, 1.0, -1.0, 0.5)
    end
end

--- gives ped ability to follow and attack targeted ped
---@param AttackerPed 'ped'
---@param targetPed 'ped'
---@return 'void'
function AttackTargetedPed(AttackerPed, targetPed)
    if not AttackerPed or not targetPed then
        return false
    end
    
    if not DoesEntityExist(AttackerPed) or not DoesEntityExist(targetPed) then
        return false
    end
    
    -- Clear any existing tasks first
    ClearPedTasks(AttackerPed)
    ClearPedSecondaryTask(AttackerPed)
    
    -- Set up aggressive relationships
    local playerGroup = GetPedRelationshipGroupHash(PlayerPedId())
    local targetGroup = GetPedRelationshipGroupHash(targetPed)
    
    -- Make target an enemy
    SetRelationshipBetweenGroups(5, playerGroup, targetGroup)
    SetRelationshipBetweenGroups(5, targetGroup, playerGroup)
    
    -- Enable full AI and combat capabilities
    SetBlockingOfNonTemporaryEvents(AttackerPed, false)
    SetPedFleeAttributes(AttackerPed, 0, false)
    SetPedCombatAttributes(AttackerPed, 46, true)   -- Can use cover
    SetPedCombatAttributes(AttackerPed, 0, true)    -- Use cover
    SetPedCombatAttributes(AttackerPed, 2, true)    -- Can use vehicles
    SetPedCombatAttributes(AttackerPed, 3, true)    -- Can leave vehicle
    SetPedCombatAttributes(AttackerPed, 5, true)    -- Can fight armed peds when not armed
    SetPedCombatAttributes(AttackerPed, 17, true)   -- Always fight
    SetPedCombatAttributes(AttackerPed, 20, true)   -- Aggressive
    SetPedCombatAttributes(AttackerPed, 1424, true) -- Ignore all
    
    SetPedCombatMovement(AttackerPed, 3)  -- Aggressive movement
    SetPedCombatRange(AttackerPed, 2)      -- Medium range
    SetPedKeepTask(AttackerPed, true)
    SetPedAlertness(AttackerPed, 3)        -- Maximum alertness
    
    -- Make the target flee or fight back
    SetPedFleeAttributes(targetPed, 0, false)
    
    -- Register the target as a hated target
    RegisterHatedTargetsAroundPed(AttackerPed, 500.0)
    
    -- Give multiple combat tasks to ensure engagement
    TaskCombatPed(AttackerPed, targetPed, 0, 16)
    
    -- Also add a melee task as backup
    CreateThread(function()
        Wait(500)
        if DoesEntityExist(AttackerPed) and DoesEntityExist(targetPed) then
            TaskCombatPed(AttackerPed, targetPed, 0, 16)
        end
    end)
end