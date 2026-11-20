-- Path of Building
-- Module: LLMDriver Parser
-- Natural language → structured intent (using built-in string patterns, no lpeg)

local LoadModule = LoadModule
local require = require

local parser = {}

-- Intent schemas for validation
local INTENT_SCHEMAS = {
    query_resistances = {
        type = "object",
        properties = {
            type = { type = "string", const = "query_resistances" },
            explain = { type = "boolean" },
        },
        required = { "type" },
    },
    scan_owned_items = {
        type = "object",
        properties = {
            type = { type = "string", const = "scan_owned_items" },
            file = { type = "string" },
            explain = { type = "boolean" },
        },
        required = { "type", "file" },
    },
    trade_search = {
        type = "object",
        properties = {
            type = { type = "string", const = "trade_search" },
            slot = { type = "string" },
            max_price = { type = "number" },
            weighting = { type = "string" },
            explain = { type = "boolean" },
        },
        required = { "type", "slot" },
    },
    tree_search = {
        type = "object",
        properties = {
            type = { type = "string", const = "tree_search" },
            target = { type = "string" },
            max_nodes = { type = "number" },
            explain = { type = "boolean" },
        },
        required = { "type", "target" },
    },
    skill_swap = {
        type = "object",
        properties = {
            type = { type = "string", const = "skill_swap" },
            skill = { type = "string" },
            explain = { type = "boolean" },
        },
        required = { "type", "skill" },
    },
    craft_sim = {
        type = "object",
        properties = {
            type = { type = "string", const = "craft_sim" },
            item_slot = { type = "string" },
            recipe = { type = "string" },
            explain = { type = "boolean" },
        },
        required = { "type", "item_slot", "recipe" },
    },
    promote_loadout = {
        type = "object",
        properties = {
            type = { type = "string", const = "promote_loadout" },
            test_loadout = { type = "string" },
            explain = { type = "boolean" },
        },
        required = { "type", "test_loadout" },
    },
    discard_loadout = {
        type = "object",
        properties = {
            type = { type = "string", const = "discard_loadout" },
            test_loadout = { type = "string" },
        },
        required = { "type", "test_loadout" },
    },
    update_poe_ninja = {
        type = "object",
        properties = {
            type = { type = "string", const = "update_poe_ninja" },
        },
        required = { "type" },
    },
}

-- Simple keyword-based parser using string patterns
local function matchPattern(command, patterns)
    for _, pattern in ipairs(patterns) do
        if command:find(pattern) then
            return true
        end
    end
    return false
end

local function extractNumber(command, patterns)
    for _, pattern in ipairs(patterns) do
        local num = command:match(pattern)
        if num then
            return tonumber(num)
        end
    end
    return nil
end

local function extractSlot(command)
    local slots = {
        helmet = "Helmet",
        chest = "Body Armour",
        body = "Body Armour",
        gloves = "Gloves",
        boots = "Boots",
        weapon = "Weapon",
        shield = "Shield",
        amulet = "Amulet",
        ring = "Ring",
        belt = "Belt",
    }
    for key, value in pairs(slots) do
        if command:find(key) then
            return value
        end
    end
    return nil
end

local function extractRecipe(command)
    local recipes = {
        add_fire_res = "add_fire_res",
        add_cold_res = "add_cold_res",
        add_lightning_res = "add_lightning_res",
        add_chaos_res = "add_chaos_res",
        prefixes_cannot_change = "prefixes_cannot_change",
        suffixes_cannot_change = "suffixes_cannot_change",
        remove_crafted_mods = "remove_crafted_mods",
        add_quality = "add_quality",
    }
    for key, value in pairs(recipes) do
        if command:find(key:gsub("_", " ")) then
            return value
        end
    end
    return nil
end

local function extractTarget(command)
    local targets = {
        avatar_of_fire = "Avatar of Fire",
        avatar = "Avatar of Fire",
        keystone = "Keystone",
        notable = "Notable",
        mastery = "Mastery",
    }
    for key, value in pairs(targets) do
        if command:find(key) then
            return value
        end
    end
    return nil
end

local function extractSkill(command)
    local skills = {
        lightning_strike = "Lightning Strike",
        lightning = "Lightning Strike",
        fireball = "Fireball",
        ice_shot = "Ice Shot",
        tornado_shot = "Tornado Shot",
        toxic_rain = "Toxic Rain",
        cyclone = "Cyclone",
        molten_strike = "Molten Strike",
        spectral_throw = "Spectral Throw",
        toxic_rain = "Toxic Rain",
        blade_vortex = "Blade Vortex",
        blade_flurry = "Blade Flurry",
        spark = "Spark",
        arc = "Arc",
        frost_bolt = "Frost Bolt",
        glacial_cascade = "Glacial Cascade",
    }
    for key, value in pairs(skills) do
        if command:find(key) then
            return value
        end
    end
    return nil
end

local function extractLoadoutNum(command)
    local num = command:match("(%d+)")
    if num then return "test-loadout-" .. num end
    return nil
end

-- Parse command
function parser.Parse(command)
    command = command:lower():gsub("^/llm%s*", "")

    -- Check for flags
    local dryRun = command:find("%-%-dry%-run") ~= nil
    local explain = command:find("%-%-explain") ~= nil

    -- Remove flags from command
    command = command:gsub("%-%-dry%-run", ""):gsub("%-%-explain", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    local intent = nil

    -- Query resistances
    if matchPattern(command, {"resist", "cap", "elemental"}) then
        intent = { type = "query_resistances", explain = explain, dry_run = dryRun }
    -- Scan owned items
    elseif matchPattern(command, {"scan", "owned"}) then
        local file = "owned_items.json"
        intent = { type = "scan_owned_items", file = file, explain = explain, dry_run = dryRun }
    -- Trade search
    elseif matchPattern(command, {"find", "search", "trade"}) then
        local slot = extractSlot(command)
        local maxPrice = extractNumber(command, {"under%s+(%d+)%s*ex", "(%d+)%s*ex"}) or 10
        if slot then
            intent = { type = "trade_search", slot = slot, max_price = maxPrice, explain = explain, dry_run = dryRun }
        end
    -- Tree search
    elseif matchPattern(command, {"path", "tree", "nodes"}) then
        local target = extractTarget(command)
        local maxNodes = extractNumber(command, {"within%s+(%d+)%s*nodes?"}) or 5
        if target then
            intent = { type = "tree_search", target = target, max_nodes = maxNodes, explain = explain, dry_run = dryRun }
        end
    -- Skill swap
    elseif matchPattern(command, {"support", "gem", "skill"}) then
        local skill = extractSkill(command) or "Main Skill"
        intent = { type = "skill_swap", skill = skill, explain = explain, dry_run = dryRun }
    -- Craft sim
    elseif matchPattern(command, {"craft"}) then
        local slot = extractSlot(command)
        local recipe = extractRecipe(command)
        if slot and recipe then
            intent = { type = "craft_sim", item_slot = slot, recipe = recipe, explain = explain, dry_run = dryRun }
        end
    -- Promote loadout
    elseif matchPattern(command, {"accept", "promote"}) then
        local testLoadout = extractLoadoutNum(command)
        if testLoadout then
            intent = { type = "promote_loadout", test_loadout = testLoadout, explain = explain, dry_run = dryRun }
        end
    -- Discard loadout
    elseif matchPattern(command, {"discard"}) then
        local testLoadout = extractLoadoutNum(command)
        if testLoadout then
            intent = { type = "discard_loadout", test_loadout = testLoadout }
        end
    -- Update poe.ninja
    elseif matchPattern(command, {"poe%.ninja", "update", "ninja"}) then
        intent = { type = "update_poe_ninja" }
    end

    if not intent then
        return nil, "Could not parse command: " .. command
    end

    -- Validate against schema
    local schema = INTENT_SCHEMAS[intent.type]
    if schema then
        local ok, err = parser.ValidateAgainstSchema(intent, schema)
        if not ok then
            return nil, "Schema validation failed: " .. err
        end
    end

    return intent, nil
end

-- Simple JSON schema validation (subset)
function parser.ValidateAgainstSchema(data, schema)
    if schema.type == "object" then
        if type(data) ~= "table" then
            return false, "Expected object"
        end
        for _, req in ipairs(schema.required or {}) do
            if data[req] == nil then
                return false, "Missing required field: " .. req
            end
        end
        for key, propSchema in pairs(schema.properties or {}) do
            if data[key] ~= nil then
                if propSchema.type == "string" and type(data[key]) ~= "string" then
                    return false, "Field " .. key .. " must be string"
                elseif propSchema.type == "number" and type(data[key]) ~= "number" then
                    return false, "Field " .. key .. " must be number"
                elseif propSchema.type == "boolean" and type(data[key]) ~= "boolean" then
                    return false, "Field " .. key .. " must be boolean"
                end
                if propSchema.const and data[key] ~= propSchema.const then
                    return false, "Field " .. key .. " must be " .. tostring(propSchema.const)
                end
            end
        end
    end
    return true, nil
end

return parser