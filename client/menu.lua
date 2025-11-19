QBCore = exports['qb-core']:GetCoreObject()

local isMenuOpen = false
local PlayerData = nil
local PlayerJob = nil

local alreadyHunting = {
    state = false
}

-- Get player data on resource start
CreateThread(function()
    PlayerData = QBCore.Functions.GetPlayerData()
    PlayerJob = PlayerData.job
end)

-- Update PlayerData when it changes
RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
    PlayerJob = val.job
end)

local function isModelK9(model)
    for key, k9 in pairs(Config.k9.models) do
        if model == k9 then
            return true
        end
    end
    return false
end

-- Forward declare menu functions
local showMainMenu
local showActionMenu
local showTricksMenu
local showSwitchControlMenu
local showCustomizationMenu
local showRenameMenu
local showVariationMenu

-- action menu
local menu = {
    [1] = {
        lable = Lang:t('menu.action_menu.follow'),
        TYPE = 'Follow',
        triggerNotification = { 'PETNAME is now following you!', 'PETNAME failed to follow you!' },
        action = function(plyped, activePed)
            doSomethingIfPedIsInsideVehicle(activePed.entity)
            return TaskFollowTargetedPlayer(activePed.entity, plyped, 3.0, false)
        end
    },
    [2] = {
        lable = Lang:t('menu.action_menu.hunt'),
        TYPE = 'Hunt',
        triggerNotification = { 'PETNAME is now hunting!', 'PETNAME can not do that!' },
        action = function(plyped, activePed)
            local min_lvl_to_hunt = Config.Settings.minHuntingAbilityLevel
            if activePed.canHunt ~= true then
                exports.qbx_core:Notify(Lang:t('menu.action_menu.error.pet_unable_to_hunt'), 'error', 5000)
                return false
            end

            if alreadyHunting.state ~= false then
                exports.qbx_core:Notify(Lang:t('menu.action_menu.error.already_hunting_something'), 'error', 5000)
                return
            end

            if activePed.itemData.metadata.level <= min_lvl_to_hunt then
                local msg = Lang:t('menu.action_menu.error.not_meet_min_requirement_to_hunt')
                msg = string.format(msg, min_lvl_to_hunt)
                exports.qbx_core:Notify(msg, 'error', 5000)
                return false
            end

            doSomethingIfPedIsInsideVehicle(activePed.entity)
            return attackLogic(alreadyHunting)
        end
    },
    [3] = {
        lable = Lang:t('menu.action_menu.hunt_and_grab'),
        TYPE = 'HuntandGrab',
        action = function(plyped, activePed)
            local min_lvl_to_hunt = Config.Settings.minHuntingAbilityLevel
            if activePed.canHunt ~= true then
                exports.qbx_core:Notify(Lang:t('menu.action_menu.error.pet_unable_to_hunt'), 'error', 5000)
                return false
            end

            if activePed.itemData.metadata.level <= min_lvl_to_hunt then
                local msg = Lang:t('menu.action_menu.error.not_meet_min_requirement_to_hunt')
                msg = string.format(msg, min_lvl_to_hunt)
                exports.qbx_core:Notify(msg, 'error', 5000)
                return false
            end

            doSomethingIfPedIsInsideVehicle(activePed.entity)
            HuntandGrab(plyped, activePed)
            return true
        end
    },
    [4] = {
        lable = Lang:t('menu.action_menu.go_there'),
        TYPE = 'There',
        action = function(plyped, activePed)
            doSomethingIfPedIsInsideVehicle(activePed.entity)
            goThere(activePed.entity)
        end
    },
    [5] = {
        lable = Lang:t('menu.action_menu.wait'),
        TYPE = 'Wait',
        action = function(plyped, activePed)
            doSomethingIfPedIsInsideVehicle(activePed.entity)
            ClearPedTasks(activePed.entity)
        end
    },
    [6] = {
        lable = Lang:t('menu.action_menu.get_in_car'),
        TYPE = 'GetinCar',
        show = function(activePet)
            return not activePet.inVehicle
        end,
        action = function(plyped, activePed)
            getIntoCar()
        end
    },
    [7] = {
        lable = 'Get Out of Car',
        TYPE = 'GetOutOfCar',
        show = function(activePet)
            return activePet.inVehicle == true
        end,
        action = function(plyped, activePed)
            getOutOfCar()
        end
    },
    [8] = {
        lable = 'Search Person',
        TYPE = 'SearchPerson',
        show = function(activePet)
            if not PlayerJob then return false end
            if not (PlayerJob.name == 'police') then return false end
            return isModelK9(activePed.model)
        end,
        action = function(plyped, activePed)
            SearchLogic(plyped, activePed)
        end
    },
    [9] = {
        lable = 'Search Car',
        TYPE = 'SearchCar',
        show = function(activePed)
            if not PlayerJob then return false end
            if not (PlayerJob.name == 'police') then return false end
            return isModelK9(activePed.model)
        end,
        action = function(plyped, activePed)
            local vehicle = QBCore.Functions.GetClosestVehicle()
            k9SearchVehicle(vehicle, activePed)
        end
    }
}

-- tricks menu
local menu2 = {
    [1] = {
        lable = Lang:t('menu.action_menu.beg'),
        TYPE = 'Beg',
        icon = 'fa-solid fa-arrows-rotate',
        action = function(plyped, activePed)
            Animator(activePed.entity, activePed.model, 'tricks', {
                animation = 'beg',
                sequentialTimings = {
                    [1] = 6,
                    [2] = 0,
                    [3] = 2,
                    step = 1,
                    Timeout = 6
                }
            })
        end
    },
    [2] = {
        lable = Lang:t('menu.action_menu.paw'),
        TYPE = 'Paw',
        icon = 'fa-solid fa-paw',
        action = function(plyped, activePed)
            Animator(activePed.entity, activePed.model, 'tricks', {
                animation = 'paw'
            })
        end
    },
    [3] = {
        lable = Lang:t('menu.action_menu.play_dead'),
        TYPE = 'Playdead',
        icon = 'fa-solid fa-face-dizzy',
        action = function(plyped, activePed)
            Animator(activePed.entity, activePed.model, 'misc', {
                animation = 'play_dead',
                c_timings = 'STOP_LAST_FRAME'
            })
        end
    },
}

local function replaceString(s)
    local x = s:gsub("PETNAME", ActivePed.read().itemData.metadata.name)
    return x
end

-- Command dispatcher
RegisterNetEvent('keep-companion:client:actionMenuDispatcher', function(option)
    local plyped = PlayerPedId()
    local activePed = ActivePed.read()
    if not activePed then return end
    
    activePed.entity = NetworkGetEntityFromNetworkId(activePed.netId)
    for key, values in pairs(option.menu) do
        if option.type == values.TYPE then
            if values.action(plyped, activePed) == true then
                if values.triggerNotification ~= nil then
                    exports.qbx_core:Notify(replaceString(values.triggerNotification[1]), 'success', 1500)
                end
            else
                if values.triggerNotification ~= nil then
                    exports.qbx_core:Notify(replaceString(values.triggerNotification[2]))
                end
            end
        end
    end
end)

function get_correct_icon(model)
    for key, value in pairs(Config.pets) do
        if model == value.model then
            for w in value.distinct:gmatch("%S+") do
                if w == 'dog' then
                    return 'dog'
                elseif w == 'rabbit' then
                    return 'paw'
                elseif w == 'hen' then
                    return 'dove'
                end
            end
        end
    end
    return 'cat'
end

-- Define menu functions
showRenameMenu = function(data)
    local input = lib.inputDialog('Rename Pet', {
        {type = 'input', label = 'Pet Name', required = true, max = 12, default = data.item.metadata.name}
    })
    
    if input and input[1] then
        local validation = ValidatePetName(input[1], 12)
        
        if type(validation) == "table" and next(validation) ~= nil then
            exports.qbx_core:Notify(Lang:t('error.failed_to_validate_name'), 'error', 5000)
            if validation.reason == 'badword' then
                exports.qbx_core:Notify(Lang:t('error.badword_inside_pet_name'), 'error', 5000)
            elseif validation.reason == 'maxCharacter' then
                exports.qbx_core:Notify(Lang:t('error.more_than_one_word_as_name'), 'error', 5000)
            end
            return
        end
        
        data.item.metadata.name = input[1]
        showCustomizationMenu(data)
    else
        showCustomizationMenu(data)
    end
end

showVariationMenu = function(data)
    local options = {}
    
    for key, value in pairs(data.pet_information.pet_variation_list) do
        table.insert(options, {
            title = 'Variation: ' .. value,
            icon = 'brush',
            onSelect = function()
                data.item.metadata.variation = value
                showCustomizationMenu(data)
            end
        })
    end
    
    lib.registerContext({
        id = 'pet_variation_menu',
        title = Lang:t('menu.variation_menu.header'),
        menu = 'pet_customization_menu',
        options = options
    })
    
    lib.showContext('pet_variation_menu')
end

showCustomizationMenu = function(data)
    local c_name = data.item.metadata.name
    local c_variation = data.item.metadata.variation
    
    local options = {}
    
    -- Only add rename option if not disabled
    if not data.pet_information.disable.rename then
        table.insert(options, {
            title = Lang:t('menu.customization_menu.btn_rename'),
            description = Lang:t('menu.customization_menu.btn_txt_btn_rename') .. c_name,
            icon = 'keyboard',
            onSelect = function()
                showRenameMenu(data)
            end
        })
    end
    
    table.insert(options, {
        title = Lang:t('menu.customization_menu.btn_select_variation'),
        description = Lang:t('menu.customization_menu.btn_txt_select_variation') .. c_variation,
        icon = 'brush',
        onSelect = function()
            showVariationMenu(data)
        end
    })
    
    table.insert(options, {
        title = Lang:t('menu.general_menu_items.confirm'),
        icon = 'circle-check',
        onSelect = function()
            TriggerServerEvent('keep-companion:server:compelete_initialization_process', data.item, data.pet_information.type)
        end
    })
    
    lib.registerContext({
        id = 'pet_customization_menu',
        title = Lang:t('menu.customization_menu.header'),
        options = options
    })
    
    lib.showContext('pet_customization_menu')
end

-- Main Menu using ox_lib
showMainMenu = function()
    local activePet = ActivePed.read()
    if not activePet then 
        exports.qbx_core:Notify(Lang:t('error.no_pet_under_control'), 'error', 5000)
        return 
    end
    
    local name = activePet.itemData.metadata.name
    local model = activePet.model
    
    lib.registerContext({
        id = 'pet_main_menu',
        title = string.format(Lang:t('menu.main_menu.header'), name),
        options = {
            {
                title = Lang:t('menu.main_menu.btn_actions'),
                description = Lang:t('menu.main_menu.sub_header'),
                icon = 'circle-play',
                onSelect = function()
                    showActionMenu()
                end
            },
            {
                title = Lang:t('menu.main_menu.btn_switchcontrol'),
                icon = 'repeat',
                onSelect = function()
                    showSwitchControlMenu()
                end
            }
        }
    })
    
    lib.showContext('pet_main_menu')
end

-- Action Menu
showActionMenu = function()
    local activePet = ActivePed.read()
    if not activePet then return end
    
    local name = activePet.itemData.metadata.name
    local options = {}
    
    for key, value in ipairs(menu) do
        if value.show then
            if not value.show(activePet) then
                goto continue
            end
        end
        
        table.insert(options, {
            title = value.lable,
            icon = tostring(key),
            onSelect = function()
                TriggerEvent('keep-companion:client:actionMenuDispatcher', {
                    type = value.TYPE,
                    menu = menu
                })
            end
        })
        ::continue::
    end
    
    -- Add tricks submenu
    table.insert(options, {
        title = Lang:t('menu.action_menu.tricks'),
        icon = 'wand-magic-sparkles',
        onSelect = function()
            showTricksMenu()
        end
    })
    
    lib.registerContext({
        id = 'pet_action_menu',
        title = string.format(Lang:t('menu.action_menu.header'), name),
        menu = 'pet_main_menu',
        options = options
    })
    
    lib.showContext('pet_action_menu')
end

-- Tricks Menu
showTricksMenu = function()
    local activePet = ActivePed.read()
    if not activePet then return end
    
    local name = activePet.itemData.metadata.name
    local options = {}
    
    for key, value in pairs(menu2) do
        table.insert(options, {
            title = value.lable,
            icon = value.icon or 'star',
            onSelect = function()
                TriggerEvent('keep-companion:client:actionMenuDispatcher', {
                    type = value.TYPE,
                    menu = menu2
                })
            end
        })
    end
    
    lib.registerContext({
        id = 'pet_tricks_menu',
        title = string.format(Lang:t('menu.tricks.header'), name),
        menu = 'pet_action_menu',
        options = options
    })
    
    lib.showContext('pet_tricks_menu')
end

-- Switch Control Menu
showSwitchControlMenu = function()
    local activePet = ActivePed.read()
    if not activePet then return end
    
    local options = {}
    
    for key, value in pairs(ActivePed:petsList()) do
        table.insert(options, {
            title = value.name,
            icon = 'paw',
            onSelect = function()
                ActivePed:switchControl(value.key)
                showActionMenu()
            end
        })
    end
    
    lib.registerContext({
        id = 'pet_switch_menu',
        title = Lang:t('menu.main_menu.btn_switchcontrol'),
        menu = 'pet_main_menu',
        options = options
    })
    
    lib.showContext('pet_switch_menu')
end

RegisterNetEvent('keep-companion:client:initialization_process', function(item, pet_information)
    if type(item) ~= "table" then
        exports.qbx_core:Notify(Lang:t('error.failed_to_start_procces'), 'error', 5000)
        return
    end
    
    if pet_information.type == 'init' then
        showCustomizationMenu({item = item, pet_information = pet_information})
        return
    end
    
    local hasitem = exports.ox_inventory:Search('count', Config.core_items.groomingkit.item_name)
    if hasitem < 1 then 
        exports.qbx_core:Notify('You need grooming kit', 'error', 5000) 
        return 
    end
    
    showCustomizationMenu({item = item, pet_information = pet_information})
end)

RegisterNetEvent('keep-companion:client:start_grooming_process', function()
    local activePed = ActivePed:read()
    if type(activePed) ~= "table" then
        exports.qbx_core:Notify(Lang:t('error.no_pet_under_control'), 'error', 5000)
        return
    end
    TriggerServerEvent('keep-companion:server:grooming_process', activePed.itemData)
end)

-- K9 Functions
function k9SearchVehicle(veh, activePed)
    if not isModelK9(activePed.model) then
        exports.qbx_core:Notify('This pet can not do that!', "error", 1500)
        return
    end
    if not PlayerJob then return end
    if not (PlayerJob.name == 'police') then
        exports.qbx_core:Notify('You are not allowed to do this action', "error", 1500)
        return
    end

    if not PlayerJob.onduty == true then
        exports.qbx_core:Notify('You Must be on duty to do this action', "error", 1500)
        return
    end

    local coo = {
        [1] = { offset = vector4(-1.5, 0.0, 0.0, -90.0) },
        [2] = { offset = vector4(0.0, -2.8, 0.0, 0.0) },
    }

    for key, value in pairs(coo) do
        local vehHead = GetEntityHeading(veh)
        local plate = GetVehicleNumberPlateText(veh)
        local pos = GetOffsetFromEntityInWorldCoords(veh, value.offset.x, value.offset.y, value.offset.z)
        TaskFollowNavMeshToCoord(activePed.entity, pos, 3.0, -1, 0.0, true, 0)
        Wait(4000)
        TaskAchieveHeading(activePed.entity, vehHead + value.offset.w, -1)
        Wait(2000)
        
        lib.callback('keep-companion:server:search_vehicle', false, function(result)
            if result then
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
                return
            end
            Animator(activePed.entity, activePed.model, 'siting', {
                animation = 'sit',
                sequentialTimings = {
                    [1] = 6,
                    [2] = 0,
                    [3] = 2,
                    step = 1,
                    Timeout = 6
                }
            })
        end, {
            key = key,
            plate = plate
        })
        Wait(3000)
    end
end

function SearchLogic(plyped, activePed)
    if not PlayerJob then return end
    if not (PlayerJob.name == 'police') then
        exports.qbx_core:Notify('You are not allowed to do this action', "error", 1500)
        return
    end

    if not PlayerJob.onduty == true then
        exports.qbx_core:Notify('You Must be on duty to do this action', "error", 1500)
        return
    end

    ClearPedTasks(ActivePed.read().entity)
    local pedCoord = GetEntityCoords(PlayerPedId())
    local closestPlayer = QBCore.Functions.GetClosestPlayer(pedCoord)
    if closestPlayer == -1 then
        return
    end
    local pedplayer = GetPlayerPed(closestPlayer)
    TaskGoToCoordAnyMeans(activePed.entity, GetEntityCoords(pedplayer), 10.0, 0, 0, 0, 0)

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
    lib.callback('keep-companion:server:search_inventory', false, function(result)
        Wait(5000)

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
        Wait(5000)
        if result == true then
            exports.qbx_core:Notify('K9 found something', 'success', 2500)
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
        end
        finished = true
    end, player_server_id)
end

-- Keybind
local function IsPoliceOrEMS()
    return PlayerJob and (PlayerJob.name == "police" or PlayerJob.name == "ambulance")
end

local function IsDowned()
    return PlayerData and (PlayerData.metadata["isdead"] or PlayerData.metadata["inlaststand"])
end

local function Ishandcuffed()
    return PlayerData and PlayerData.metadata["ishandcuffed"]
end

lib.addKeybind({
    name = 'petmenu',
    description = 'Show pet menu',
    defaultKey = Config.Settings.petMenuKeybind,
    onPressed = function()
        if ((IsDowned() and IsPoliceOrEMS()) or not IsDowned()) and not Ishandcuffed() and not IsPauseMenuActive() and not isMenuOpen then
            showMainMenu()
        end
    end,
})