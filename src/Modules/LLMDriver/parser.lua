-- Path of Building
-- Module: LLMDriver Parser
-- Natural language → structured intent

local LoadModule = LoadModule
local require = require
local lpeg = require("lpeg")

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

-- LPEG patterns for parsing
local P = lpeg.P
local R = lpeg.R
local S = lpeg.S
local C = lpeg.C
local Ct = lpeg.Ct
local Cg = lpeg.Cg
local Cs = lpeg.Cs

local space = S(" \t\n")^0
local word = (P(1) - S(" \t\n"))^1
local quoted = P('"') * C((1 - P('"'))^0) * P('"')

-- Parse command
function parser.Parse(command)
    command = command:lower():gsub("^/llm%s*", "")

    -- Check for flags
    local dryRun = command:find("%-%-dry%-run") ~= nil
    local explain = command:find("%-%-explain") ~= nil

    -- Remove flags from command
    command = command:gsub("%-%-dry%-run", ""):gsub("%-%-explain", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    -- Try each pattern
    local intent = nil

    -- Query resistances
    if command:match("resist") or command:match("cap") then
        intent = { type = "query_resistances", explain = explain, dry_run = dryRun }
    -- Scan owned items
    elseif command:match("scan") and command:match("owned") then
        local file = command:match("owned[%s_]*items?%.json") and "owned_items.json" or "owned_items.json"
        intent = { type = "scan_owned_items", file = file, explain = explain, dry_run = dryRun }
    -- Trade search
    elseif command:match("find") or command:match("search") or command:match("trade") then
        local slot = command:match("helmet") and "Helmet"
            or command:match("chest") and "Body Armour"
            or command:match("gloves") and "Gloves"
            or command:match("boots") and "Boots"
            or command:match("weapon") and "Weapon"
            or command:match("shield") and "Shield"
            or command:match("amulet") and "Amulet"
            or command:match("ring") and "Ring"
            or command:match("belt") and "Belt"
        local maxPrice = tonumber(command:match("under%s+(%d+)%s*ex")) or tonumber(command:match("(%d+)%s*ex")) or 10
        if slot then
            intent = { type = "trade_search", slot = slot, max_price = maxPrice, explain = explain, dry_run = dryRun }
        end
    -- Tree search
    elseif command:match("path") or command:match("tree") then
        local target = command:match("to%s+(%w+)")
            or command:match("avatar%s+of%s+fire")
            or command:match("keystone%s+(%w+)")
        local maxNodes = tonumber(command:match("within%s+(%d+)%s*nodes?")) or 5
        if target then
            intent = { type = "tree_search", target = target, max_nodes = maxNodes, explain = explain, dry_run = dryRun }
        end
    -- Skill swap
    elseif command:match("support") or command:match("gem") then
        local skill = command:match("for%s+(%w+)") or command:match("lightning%s+strike") or "Main Skill"
        intent = { type = "skill_swap", skill = skill, explain = explain, dry_run = dryRun }
    -- Craft sim
    elseif command:match("craft") then
        local slot = command:match("helmet") and "Helmet"
            or command:match("chest") and "Body Armour"
            or command:match("gloves") and "Gloves"
            or command:match("boots") and "Boots"
        local recipe = command:match("add%s+fire%s+res") and "add_fire_res"
            or command:match("add%s+cold%s+res") and "add_cold_res"
            or command:match("add%s+lightning%s+res") and "add_lightning_res"
            or command:match("add%s+chaos%s+res") and "add_chaos_res"
            or command:match("prefix") and "prefixes_cannot_change"
        if slot and recipe then
            intent = { type = "craft_sim", item_slot = slot, recipe = recipe, explain = explain, dry_run = dryRun }
        end
    -- Promote loadout
    elseif command:match("accept") or command:match("promote") then
        local testLoadout = command:match("test[%s-]loadout[%s-](%d+)") or command:match("loadout[%s-](%d+)")
        if testLoadout then
            intent = { type = "promote_loadout", test_loadout = "test-loadout-" .. testLoadout, explain = explain, dry_run = dryRun }
        end
    -- Discard loadout
    elseif command:match("discard") then
        local testLoadout = command:match("test[%s-]loadout[%s-](%d+)") or command:match("loadout[%s-](%d+)")
        if testLoadout then
            intent = { type = "discard_loadout", test_loadout = "test-loadout-" .. testLoadout }
        end
    -- Update poe.ninja
    elseif command:match("poe%.ninja") or command:match("update") then
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