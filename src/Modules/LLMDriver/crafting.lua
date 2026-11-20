-- Path of Building
-- Module: LLMDriver Crafting
-- Deterministic Crafting Bench recipe simulation

local LoadModule = LoadModule
local require = require
local pob_api = LoadModule("Modules/LLMDriver/compat/pob_api")

local crafting = {}

-- Known Crafting Bench recipes (deterministic only)
local RECIPES = {
    add_fire_res = {
        name = "Add Fire Resistance",
        mods = { { mod = "FireResist%", value = 24, tier = 1 } }, -- +24% Fire Res (T1)
        cost = { { type = "Orb of Alteration", count = 1 } },
    },
    add_cold_res = {
        name = "Add Cold Resistance",
        mods = { { mod = "ColdResist%", value = 24, tier = 1 } },
        cost = { { type = "Orb of Alteration", count = 1 } },
    },
    add_lightning_res = {
        name = "Add Lightning Resistance",
        mods = { { mod = "LightningResist%", value = 24, tier = 1 } },
        cost = { { type = "Orb of Alteration", count = 1 } },
    },
    add_chaos_res = {
        name = "Add Chaos Resistance",
        mods = { { mod = "ChaosResist%", value = 18, tier = 1 } }, -- +18% Chaos Res (T1)
        cost = { { type = "Orb of Alteration", count = 1 } },
    },
    prefixes_cannot_change = {
        name = "Prefixes Cannot Be Changed",
        mods = { { mod = "PrefixesCannotBeChanged", value = true } },
        cost = { { type = "Divine Orb", count = 2 } },
    },
    suffixes_cannot_change = {
        name = "Suffixes Cannot Be Changed",
        mods = { { mod = "SuffixesCannotBeChanged", value = true } },
        cost = { { type = "Divine Orb", count = 2 } },
    },
    remove_crafted_mods = {
        name = "Remove Crafted Modifiers",
        mods = { { mod = "RemoveCraftedMods", value = true } },
        cost = { { type = "Orb of Scouring", count = 1 } },
    },
    add_quality = {
        name = "Add Quality",
        mods = { { mod = "Quality", value = 20 } },
        cost = { { type = "Gemcutter's Prism", count = 1 } },
    },
}

-- Apply a crafting bench recipe to an item
function crafting.ApplyRecipe(item, recipeName)
    local recipe = RECIPES[recipeName]
    if not recipe then
        return nil, "Unknown recipe: " .. recipeName
    end

    -- Clone item (simplified - in reality would use PoB's item copy)
    local newItem = crafting.CloneItem(item)
    if not newItem then
        return nil, "Failed to clone item"
    end

    -- Apply recipe mods
    for _, mod in ipairs(recipe.mods) do
        if mod.mod == "PrefixesCannotBeChanged" then
            newItem.craftedPrefixesLocked = true
        elseif mod.mod == "SuffixesCannotBeChanged" then
            newItem.craftedSuffixesLocked = true
        elseif mod.mod == "RemoveCraftedMods" then
            newItem.craftedMods = {}
        else
            -- Add/replace mod
            crafting.AddMod(newItem, mod)
        end
    end

    -- Recalculate item stats
    crafting.RecalculateItem(newItem)

    return newItem, nil
end

-- Get recipe info
function crafting.GetRecipe(recipeName)
    return RECIPES[recipeName]
end

-- List all recipes
function crafting.ListRecipes()
    local list = {}
    for name, recipe in pairs(RECIPES) do
        table.insert(list, {
            name = name,
            display_name = recipe.name,
            cost = recipe.cost,
        })
    end
    return list
end

-- Clone item (simplified)
function crafting.CloneItem(item)
    -- In reality, this would use PoB's item copy mechanism
    -- For now, return a shallow copy with mod tracking
    local newItem = {}
    for k, v in pairs(item) do
        newItem[k] = v
    end
    newItem.modLines = {}
    if item.modLines then
        for _, line in ipairs(item.modLines) do
            table.insert(newItem.modLines, { line = line.line, modTags = line.modTags })
        end
    end
    newItem.craftedMods = {}
    if item.craftedMods then
        for _, mod in ipairs(item.craftedMods) do
            table.insert(newItem.craftedMods, mod)
        end
    end
    return newItem
end

-- Add mod to item
function crafting.AddMod(item, mod)
    -- Simplified: just add to crafted mods
    if not item.craftedMods then
        item.craftedMods = {}
    end
    table.insert(item.craftedMods, mod)
end

-- Recalculate item stats
function crafting.RecalculateItem(item)
    -- In reality, this would use PoB's item stat calculation
    -- For now, mark as needing recalc
    item.needsRecalc = true
end

-- Get applicable recipes for an item
function crafting.GetApplicableRecipes(item)
    local applicable = {}
    for name, recipe in pairs(RECIPES) do
        -- Check if recipe can apply to this item type
        local canApply = true
        if name:match("^add_") then
            -- Resistance recipes apply to armour/jewellery
            if item.base and item.base.itemTypes then
                local types = item.base.itemTypes
                canApply = types.Armour or types.Jewellery or types.Accessory
            end
        end
        if canApply then
            table.insert(applicable, name)
        end
    end
    return applicable
end

return crafting