# 🐾 [Qbyanski-Pets] (Keep Companion - Reworked)

A robust and fully functional companion/pet script for FiveM, originally by SWKeep, completely **re-engineered for full stability** and **Ox-Core compatibility**. This version addresses and resolves all known issues from the original codebase.

## ✨ Key Features

* **100% Functional Pet System:** All core features—food, water, health, leveling, and revival—are now stable and working as intended.
* **Full Ox Compatibility:** Seamless integration with **Ox Lib, Ox Inventory, and Ox Target.** *(Legacy QBCore dependencies are still required for the base framework.)*
* **Deep Companion Mechanics:**
    * **XP & Leveling System:** Pets gain experience and level up, unlocking their full abilities.
    * **Full Health Cycle:** Includes hunger, thirst, health, and a reliable revive/healing system.
    * **Customization:** Auto-naming, renaming via item (Collar/Name Tag), and pet variations.
    * **Pet Shop & Poacher Vendor:** Includes setups for both legal pet purchases and illegal animal acquisition.
* **Customizable Interaction:** Full control over pet actions via a dedicated in-game menu (default key is "O").

---

## 💻 Dependencies

This script requires the following resources to function properly:

* **Framework:** **QBCore** (Required for the base framework structure)
* **Core Systems:** **Ox Lib, Ox Inventory, Ox Target**
* **Map Resources (Optional but Recommended):**
    * Weazel News Pet Shop: [gta5-mods.com MLO](https://www.gta5-mods.com/maps/mlo-pet-shop)
    * Sandy Shores Pet Shop: [CFX Forum MLO](https://forum.cfx.re/t/release-sandy-pet-shop-mlo/2172530)
    * Illegal Poacher Store: Requires [CayoTwoIslands](https://github.com/TayMcKenzieNZ/CayoTwoIslands) for the location.

---

## 🛠️ Installation Guide

### Step 1: Resource Setup

1.  Clone or download this repository and place the folder into your server's resources directory.
2.  Ensure the folder is named `keep-companion` and is started in your `server.cfg` after all dependencies.

### Step 2: Item Setup (Ox Inventory)

The following items are required for the pets and pet management. Add the entire block below to your `ox_inventory/data/items.lua` file.

```lua
    -- ================ Keep-companion - Pets ================
    ['keepcompanionhusky'] = { label = 'Husky', weight = 5000, stack = false, close = true, description = "Also the nickname everyone calls you behind your back." },
    ['keepcompanionpoodle'] = { label = 'Poodle', weight = 5000, stack = false, close = true, description = "This dog's haircut is more expensive than your car." },
    ['keepcompanionrottweiler'] = { label = 'Rottweiler', weight = 5000, stack = false, close = true, description = "A butcher's best friend." },
    ['keepcompanionwesty'] = { label = 'Westie', weight = 5000, stack = false, close = true, description = "A great breed for hunting rats, and wearing cute sweaters." },
    ['keepcompanioncat'] = { label = 'Cat', weight = 5000, stack = false, close = true, description = "What's new pussycat?" },
    ['keepcompanionpug'] = { label = 'Pug', weight = 5000, stack = false, close = true, description = "The snorting haunts you in your sleep." },
    ['keepcompanionretriever'] = { label = 'Retriever', weight = 5000, stack = false, close = true, description = "America's favorite dog." },
    ['keepcompanionshepherd'] = { label = 'Border Collie', weight = 5000, stack = false, close = true, description = "Useful to heard your flock of sheep." },
    ['keepcompanionrabbit'] = { label = 'Rabbit', weight = 5000, stack = false, close = true, description = "Boing boing boing boing." },
    ['keepcompanionhen'] = { label = 'Hen', weight = 5000, stack = false, close = true, description = "A best friend AND lunch. Two for one!" },
    ['keepcompanionrat'] = { label = 'Rat', weight = 5000, stack = false, close = true, description = "Snitches get stiches, but rats get scritches." },
    ['keepcompanionk9unit'] = { label = 'K9 Unit Malinois', weight = 5000, stack = false, close = true, description = "LSPD exclusive K9." },
    -- illegal/poacher pets (Add these to Ox config if you use them)
    ['keepcompanionmtlion'] = { label = 'Mountain Lion', weight = 5000, stack = false, close = true, description = "Not street legal." },
    ['keepcompanionmtlion2'] = { label = 'Panther', weight = 5000, stack = false, close = true, description = "Definitely not street legal." },
    ['keepcompanioncoyote'] = { label = 'Coyote', weight = 5000, stack = false, close = true, description = "Wild but trainable." },

    -- ================ Keep-companion - Items ================
    ['petfood'] = { label = 'Pet Food', weight = 500, stack = true, close = true, description = "Nom nom for your pom pom." },
    ['collarpet'] = { label = 'Pet Collar', weight = 500, stack = false, close = true, description = "Rename your pet." },
    ['firstaidforpet'] = { label = 'Pet First-aid Kit', weight = 500, stack = true, close = true, description = "Bring your pet back from the dead again and again." },
    ['petnametag'] = { label = 'Pet Name Tag', weight = 500, stack = true, close = true, description = "Rename your pet." },
    ['petwaterbottleportable'] = { label = 'Pet Water Bottle', weight = 500, stack = false, close = true, description = "Water for your pet. Stop trying to drink this." },
    ['petgroomingkit'] = { label = 'Pet Grooming Kit', weight = 500, stack = false, close = true, description = "Now your pet can pass a wave check." },
```

### Step 3: shop Setup (Ox Inventory)
add the following shop definitions to your `ox_inventory/data/shops.lua`

    ```lua
    PetShop = {
        blip = { id = 463, colour = 31, scale = 1.1 },
        name = 'Pet Shop',
        inventory = {
            { name = 'petfood', price = 500 },
            { name = 'collarpet', price = 2000 },
            { name = 'firstaidforpet', price = 2000 },
            { name = 'petnametag', price = 2000 },
            { name = 'petwaterbottleportable', price = 500 },
            { name = 'petgroomingkit', price = 75000 },
            { name = 'keepcompanionhusky', price = 75000, count = 5 },
            { name = 'keepcompanionpoodle', price = 45000, count = 5 },
            { name = 'keepcompanionrottweiler', price = 75000, count = 5 },
            { name = 'keepcompanionwesty', price = 30000, count = 5 },
            { name = 'keepcompanioncat', price = 25000, count = 10 },
            { name = 'keepcompanionpug', price = 50000, count = 5 },
            { name = 'keepcompanionretriever', price = 50000, count = 5 },
            { name = 'keepcompanionshepherd', price = 50000, count = 5 },
            { name = 'keepcompanionhen', price = 25000, count = 10 },
            { name = 'keepcompanionrat', price = 25000, count = 10 },
            { name = 'keepcompanionrabbit', price = 25000, count = 20 },
        },
        locations = {}, 
        targets = {
            -- Pet Shop near Weazel News MLO (Recommended)
            { ped = `cs_guadalope`, scenario = 'WORLD_HUMAN_STAND_IMPATIENT', loc = vector3(563.64, 2753.1, 41.88), heading = 183.65, distance = 3.0 },
            -- Add other locations (like Sandy Shores MLO) here
        }
    },
```
### Step 4 : Setting up illegal poacher

```lua
Poacher = {
    name = 'Poacher',
    inventory = {
        { name = 'keepcompanionmtlion', price = 75000, count = 5, currency = 'black_money' },
        { name = 'keepcompanionmtlion2', price = 75000, count = 5, currency = 'black_money' },
        { name = 'keepcompanioncoyote', price = 75000, count = 5, currency = 'black_money' },
    },
    locations = {},
    targets = {
        -- Cayo Poacher (Requires CayoTwoIslands)
        { ped = `csb_cletus`, scenario = 'PROP_HUMAN_SEAT_BENCH', loc = vector3(4803.68, -4601.88, 17.31), heading = 178.26, distance = 3.0 },
    }
},
