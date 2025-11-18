local ox_inventory = exports.ox_inventory
Update = {}

--- get random pet name
---@param type 'species'
---@param gender integer
function NameGenerator(type, gender)
    local names = {
        dog = { 
            { "Max", "Buddy", "Charlie", "Jack", "Cooper", "Rocky", "Toby", "Tucker", "Jake", "Bear", "Duke", "Teddy",
                "Oliver", "Riley", "Bailey", "Bentley", "Milo", "Buster", "Cody", "Dexter", "Winston", "Murphy", "Leo",
                "Lucky", "Oscar", "Louie", "Zeus", "Henry", "Sam", "Harley", "Baxter", "Gus", "Sammy", "Jackson",
                "Bruno", "Diesel", "Jax", "Gizmo", "Bandit", "Rusty", "Marley", "Jasper", "Brody", "Roscoe", "Hank",
                "Otis", "Bo", "Joey", "Beau", "Ollie", "Tank", "Shadow", "Peanut", "Hunter", "Scout", "Blue", "Rocco",
                "Simba", "Tyson", "Ziggy", "Boomer", "Romeo", "Apollo", "Ace", "Luke", "Rex", "Finn", "Chance", "Rudy",
                "Loki", "Moose", "George", "Samson", "Coco", "Benny", "Thor", "Rufus", "Prince", "Chester", "Brutus",
                "Scooter", "Chico", "Spike", "Gunner", "Sparky", "Mickey", "Kobe", "Chase", "Oreo", "Frankie", "Mac",
                "Benji", "Bubba", "Champ", "Brady", "Elvis", "Copper", "Cash", "Archie", "Walter" },
            { "Bella", "Lucy", "Daisy", "Molly", "Lola", "Sophie", "Sadie", "Maggie", "Chloe", "Bailey", "Roxy",
                "Zoey", "Lily", "Luna", "Coco", "Stella", "Gracie", "Abby", "Penny", "Zoe", "Ginger", "Ruby", "Rosie",
                "Lilly", "Ellie", "Mia", "Sasha", "Lulu", "Pepper", "Nala", "Lexi", "Lady", "Emma", "Riley", "Dixie",
                "Annie", "Maddie", "Piper", "Princess", "Izzy", "Maya", "Olive", "Cookie", "Roxie", "Angel", "Belle",
                "Layla", "Missy", "Cali", "Honey", "Millie", "Harley", "Marley", "Holly", "Kona", "Shelby", "Jasmine",
                "Ella", "Charlie", "Minnie", "Willow", "Phoebe", "Callie", "Scout", "Katie", "Dakota", "Sugar", "Sandy",
                "Josie", "Macy", "Trixie", "Winnie", "Peanut", "Mimi", "Hazel", "Mocha", "Cleo", "Hannah", "Athena",
                "Lacey", "Sassy", "Lucky", "Bonnie", "Allie", "Brandy", "Sydney", "Casey", "Gigi", "Baby", "Madison",
                "Heidi", "Sally", "Shadow", "Cocoa", "Pebbles", "Misty", "Nikki", "Lexie", "Grace", "Sierra" } 
        }
    }
    local size = #names[type][gender]
    return names[type][gender][math.random(1, size)]
end

local function initmetadataHelper(Player, slot, data)
    local src = Player.PlayerData.source
    if ox_inventory:GetSlot(src, slot) then
        ox_inventory:SetMetadata(src, slot, data)
    end
end

--- initial pet data after player bought pet
---@param source any
---@param item any
function initItem(source, item)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    local pet_information = find_pet_model_by_item_name(item.name)
    local random = math.random(1, 2)
    local gender = { true, false }
    local maxHealth = 200
    item.metadata = {}

    item.metadata.hash = tostring(math.random(10, 99) ..
        lib.string.random('1111111') .. math.random(1, 9))
    item.metadata.name = NameGenerator('dog', random)
    item.metadata.gender = gender[random]
    item.metadata.age = 0
    item.metadata.food = 100
    item.metadata.thirst = 5
    item.metadata.owner = Player.PlayerData.charinfo
    item.metadata.level = 5
    item.metadata.XP = 0
    item.metadata.health = pet_information.maxHealth or maxHealth
    item.metadata.variation = PetVariation:getRandomPedVariationsName(pet_information.model, true)

    initmetadataHelper(Player, item.slot, item.metadata)

    if Config.Settings.let_players_cutomize_their_pet_after_purchase then
        local information = {
            pet_variation_list = PetVariation:getPedVariationsNameList(pet_information.model),
            pet_information = pet_information,
            disable = {
                rename = false
            },
            type = 'init'
        }
        TriggerClientEvent('keep-companion:client:initialization_process', src, item, information)
    end
end

function find_pet_model_by_item_name(item_name)
    for k, v in pairs(Config.pets) do
        if v.name == item_name then
            return v
        end
    end
end

RegisterNetEvent('keep-companion:server:compelete_initialization_process', function(item, process_type)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end

    TriggerEvent('keep-companion:server:keep-companion:server:compelete_initialization_process_last_step', 
        source, item, Player, process_type)
    
    if process_type == 'init' then return end
    ox_inventory:RemoveItem(src, Config.core_items.groomingkit.item_name, 1)
end)

RegisterNetEvent('keep-companion:server:keep-companion:server:compelete_initialization_process_last_step',
    function(src, item, Player, process_type)
        local pet_information = find_pet_model_by_item_name(item.name)
        if not pet_information then return end
        
        local items = ox_inventory:GetInventoryItems(src)
        if not items then return end

        if process_type == Config.core_items.groomingkit.item_name then
            local petData = Pet:findbyhash(src, item.metadata.hash)
            if Player.PlayerData.charinfo.phone ~= petData.metadata.owner.phone then
                exports.qbx_core:Notify(src, Lang:t('error.not_owner_of_pet'), 'error', 2500)
                return
            end
            -- force data that we don't want to get by client side
            item.metadata.age = petData.metadata.age
            item.metadata.food = petData.metadata.food
            item.metadata.thirst = petData.metadata.thirst
            item.metadata.owner = Player.PlayerData.charinfo
            item.metadata.level = petData.metadata.level
            item.metadata.XP = petData.metadata.XP
            item.metadata.health = petData.metadata.health
        else
            item.metadata.age = 0
            item.metadata.food = 100
            item.metadata.thirst = 0
            item.metadata.owner = Player.PlayerData.charinfo
            item.metadata.level = 5
            item.metadata.XP = 0
            item.metadata.health = pet_information.maxHealth
        end
        
        local sever_item = nil
        for key, value in pairs(items) do
            if value.metadata.hash == item.metadata.hash then
                sever_item = value
                break
            end
        end
        if not sever_item then return end

        initmetadataHelper(Player, sever_item.slot, item.metadata)
        if process_type == Config.core_items.groomingkit.item_name then
            exports.qbx_core:Notify(src, Lang:t('success.successful_grooming'), 'success', 2500)
            Pet:despawnPet(src, item, true)
        end
    end)

-- Calorie Calculation Data
CalorieCalData = {
    dog = {
        maximumCal = 2000,
        activity = {
            low = 1.6,
            high = 5.0
        },
        RER = function(lbs)
            return 70 * (lbs ^ (0.75))
        end
    },
    cat = {
        maximumCal = 1000,
        activity = {
            low = 1.2,
            high = 1.8
        },
        RER = function(lbs)
            return 40 * (lbs ^ (0.75))
        end
    }
}

function CalorieCalData:calRER(lbs, type)
    local res = 0
    res = math.floor(self[type]['RER'](lbs))
    return res
end

function CalorieCalData:convertWeightToLbs(weight)
    return (weight * 10) / 500
end

local function convert_xp_to_level(xp)
    if xp >= 0 and xp <= 75 then
        return 0
    end

    local maxExp = 0
    local minExp = 0

    for i = 1, 51, 1 do
        maxExp = math.floor(math.floor((i + 300) * (2 ^ (i / 7))) / 4)
        minExp = math.floor(math.floor(((i - 1) + 300) * (2 ^ ((i - 1) / 7))) / 4)
        if xp >= minExp and xp <= maxExp then
            return i
        end
    end
end

local function calculate_next_xp_value(level)
    local maxExp = math.floor(math.floor((level + 300) * (2 ^ (level / 7))) / 4)
    local minExp = math.floor(math.floor(((level - 1) + 300) * (2 ^ ((level - 1) / 7))) / 4)
    local dif = maxExp - minExp
    local pr = math.floor(maxExp / minExp)
    local multi = 1
    return math.floor(dif / (multi * (level + 1) * pr))
end

local function current_level_max_xp(level)
    return math.floor(math.floor((level + 300) * (2 ^ (level / 7))) / 4)
end

function Update:xp(source, current_pet_data)
    local level = convert_xp_to_level(math.floor(current_pet_data.metadata.XP))
    local pet_name = current_pet_data.metadata.name

    if level > Config.Balance.maximumLevel then
        return
    end

    if current_pet_data.metadata.XP == 0 then
        current_pet_data.metadata.XP = 75
    end

    current_pet_data.metadata.XP = current_pet_data.metadata.XP + calculate_next_xp_value(level)
    
    if current_pet_data.metadata.XP > current_level_max_xp(level) then
        current_pet_data.metadata.level = level + 1
        local msg = string.format(Lang:t('metadata.level_up'), pet_name, current_pet_data.metadata.level)
        exports.qbx_core:Notify(source, msg)
    end
end

function Update:health(source, data, current_pet_data)
    local pet_name = current_pet_data.metadata.name
    local net_pet = NetworkGetEntityFromNetworkId(data.netId)
    if net_pet == 0 then
        return
    end

    local c_health = GetEntityHealth(net_pet)
    if current_pet_data.metadata.health == c_health then
        return
    end

    if c_health <= 100 then
        local msg = string.format(Lang:t('error.pet_died'), pet_name)
        exports.qbx_core:Notify(source, msg, 'error')
        c_health = 0
    end
    current_pet_data.metadata.health = c_health
    Pet:save_all_metadata(source, current_pet_data.metadata.hash)
end

function Update:food(petData, process_type)
    if petData == nil or process_type == nil then return end
    if petData.metadata.food == 0 then
        if petData.metadata.health == 0 or petData.metadata.health <= 100 then
            petData.metadata.health = 0
            return
        end
        petData.metadata.health = petData.metadata.health - 0.2
        return
    end

    if petData.metadata.food > 0 then
        petData.metadata.food = petData.metadata.food - 1

        if petData.metadata.food < 0 then
            petData.metadata.food = 0
        end
        return
    end
end

local thirst_value_increase_per_tick = Config.core_items.waterbottle.settings.thirst_value_increase_per_tick
function Update:thirst(petData, process_type)
    if petData == nil or process_type == nil then return end
    if petData.metadata.thirst == nil then
        petData.metadata.thirst = 0.0
    end
    if petData.metadata.thirst >= 100.0 then
        if petData.metadata.health == 0 or petData.metadata.health <= 100 then
            petData.metadata.health = 0
            petData.metadata.thirst = 100
            return
        end
        petData.metadata.health = petData.metadata.health - 0.5
        return
    end

    if petData.metadata.thirst <= 100 then
        petData.metadata.thirst = petData.metadata.thirst + thirst_value_increase_per_tick

        if petData.metadata.thirst < 0 then
            petData.metadata.thirst = 0
        end
        return
    end
end

lib.callback.register('keep-companion:server:collar_change_owenership', function(source, data)
    if type(data.new_owner_cid) == "string" then 
        data.new_owner_cid = tonumber(data.new_owner_cid) 
    end
    
    local player_owner = QBCore.Functions.GetPlayer(source)
    if player_owner == nil then return end
    
    local player_new_owner = QBCore.Functions.GetPlayer(data.new_owner_cid)
    
    if data.new_owner_cid == source then
        return {
            state = false,
            msg = Lang:t('error.failed_to_transfer_ownership_same_owner')
        }
    end

    if player_new_owner == nil or next(data) == nil then
        return {
            state = false,
            msg = Lang:t('error.failed_to_transfer_ownership_could_not_find_new_owner_id')
        }
    end

    local hash = data.hash
    local current_pet_data = Pet:findbyhash(source, hash)

    if type(current_pet_data.metadata.owner) ~= "table" or next(current_pet_data.metadata.owner) == nil then
        return {
            state = false,
            msg = Lang:t('error.failed_to_transfer_ownership_missing_current_owner')
        }
    end

    if not ox_inventory:RemoveItem(source, 'collarpet', 1) then
        exports.qbx_core:Notify(source, Lang:t('error.failed_to_remove_item_from_inventory'), 'error', 2500)
        return
    end

    current_pet_data.metadata.owner = player_new_owner.PlayerData.charinfo
    Pet:save_all_metadata(source, hash)
    Pet:despawnPet(source, { metadata = { hash = hash } }, true)
    
    return {
        state = true,
        msg = Lang:t('success.successful_ownership_transfer')
    }
end)

-- ============================
--           Cooldown
-- ============================

local usageCooldown = Config.Settings.itemUsageCooldown * 1000
PlayersCooldown = {
    players = {}
}

function PlayersCooldown:initCooldown(player)
    self.players[player] = usageCooldown
end

function PlayersCooldown:cleanOflinePlayers()
    local onlinePlayers = exports.qbx_core:GetPlayersData()
    for ID, cooldown in pairs(self.players) do
        local found = false
        for _, playerData in pairs(onlinePlayers) do
            if ID == playerData.source then
                found = true
                break
            end
        end
        if not found then
            self.players[ID] = nil
        end
    end
end

function PlayersCooldown:updateCooldown(player)
    if self.players[player] > 0 then
        self.players[player] = self.players[player] - 1000
    end
    return 0
end

function PlayersCooldown:isOnCooldown(player)
    if self.players[player] == nil then
        PlayersCooldown:initCooldown(player)
        return 0
    elseif self.players[player] == 0 then
        PlayersCooldown:initCooldown(player)
        return 0
    elseif self.players[player] > 0 then
        return self.players[player]
    end
end

function PlayersCooldown:onlinePlayers()
    local count = 0
    for _ in pairs(self.players) do
        count = count + 1
    end
    return count
end