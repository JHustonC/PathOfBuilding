-- Path of Building
-- Module: LLMDriver Executor
-- Intent → PoB API calls

local LoadModule = LoadModule
local require = require
local pob_api = LoadModule("Modules/LLMDriver/compat/pob_api")
local loadout = LoadModule("Modules/LLMDriver/loadout")
local experiments = LoadModule("Modules/LLMDriver/experiments")
local crafting = LoadModule("Modules/LLMDriver/crafting")
local external = LoadModule("Modules/LLMDriver/external/trade_search")
local poe_ninja = LoadModule("Modules/LLMDriver/external/poe_ninja")
local cache = LoadModule("Modules/LLMDriver/external/cache")

local executor = {}

-- Execute an intent
function executor.Execute(intent, provider, lldriver)
    -- Build context for provider
    local context = {
        buildSnapshot = lldriver:GetBuildSnapshot(),
        conversationHistory = lldriver.state.conversation_history,
    }

    -- Handle dry-run
    if intent.dry_run then
        return executor.DryRun(intent)
    end

    -- Route to handler
    local handlers = {
        query_resistances = executor.HandleQueryResistances,
        scan_owned_items = executor.HandleScanOwnedItems,
        trade_search = executor.HandleTradeSearch,
        tree_search = executor.HandleTreeSearch,
        skill_swap = executor.HandleSkillSwap,
        craft_sim = executor.HandleCraftSim,
        promote_loadout = executor.HandlePromoteLoadout,
        discard_loadout = executor.HandleDiscardLoadout,
        update_poe_ninja = executor.HandleUpdatePoeNinja,
    }

    local handler = handlers[intent.type]
    if not handler then
        return nil, "No handler for intent type: " .. intent.type
    end

    return handler(intent, provider, lldriver, context)
end

-- Dry-run mode: show what would be done
function executor.DryRun(intent)
    local actions = {
        query_resistances = "Call pob_api.GetResistances()",
        scan_owned_items = "Load " .. intent.file .. " → For each item: CreateItemFromRaw() → Experiment.run({gear_swap, item, slot})",
        trade_search = "Call pob_api.BuildTradeSearchQuery() → Parse results → For each: Experiment.run({gear_swap, item, slot})",
        tree_search = "Search passive tree for path to " .. intent.target .. " → Experiment.run({tree_change, path})",
        skill_swap = "Enumerate supports for " .. intent.skill .. " → For each combo: Experiment.run({skill_swap, supports})",
        craft_sim = "ItemBuilder.apply_bench_recipe(item, " .. intent.recipe .. ") → Experiment.run({craft_sim, item, recipe})",
        promote_loadout = "loadout.Promote(" .. intent.test_loadout .. ")",
        discard_loadout = "loadout.Discard(" .. intent.test_loadout .. ")",
        update_poe_ninja = "poe_ninja.FetchAndCache()",
    }

    return {
        text = "Dry-run: " .. (actions[intent.type] or "Unknown intent"),
        dry_run = true,
        actions = { actions[intent.type] },
    }
end

-- Query resistances
function executor.HandleQueryResistances(intent, provider, lldriver, context)
    local resistances = pob_api.GetResistances()

    local lines = {"^7Elemental Resistances (Capped / Uncapped):^0"}
    for _, elem in ipairs({"fire", "cold", "lightning", "chaos"}) do
        local r = resistances[elem] or {capped = 0, uncapped = 0}
        local color = r.capped >= 75 and "^2" or "^1"
        table.insert(lines, string.format("  %s%s: %s%d%%^0 / %d%%", color, elem:upper(), color, r.capped, r.uncapped))
    end

    return {
        text = table.concat(lines, "\n"),
        data = resistances,
    }
end

-- Scan owned items for upgrades
function executor.HandleScanOwnedItems(intent, provider, lldriver, context)
    -- Load owned items JSON
    local file = io.open(intent.file, "r")
    if not file then
        return nil, "Cannot open file: " .. intent.file
    end
    local content = file:read("*a")
    file:close()

    local json = require("dkjson")
    local items, err = json.decode(content)
    if not items then
        return nil, "Failed to parse JSON: " .. err
    end

    if type(items) ~= "table" then
        return nil, "Expected array of items"
    end

    local results = {}
    for i, itemText in ipairs(items) do
        local item = pob_api.CreateItemFromRaw(itemText)
        if item then
            local slot = item.base and item.base.slot or "Unknown"
            local expResult, expErr = experiments.Run({
                variation = "gear_swap",
                item = item,
                slot = slot,
                constraints = { resist_caps = true, stat_reqs = true },
                name = "owned-scan-" .. i,
            })

            if expResult then
                table.insert(results, {
                    index = i,
                    name = item.name or "Unknown",
                    slot = slot,
                    passed = expResult.passed,
                    failures = expResult.failures,
                    dps_delta = expResult.result.dps.total - context.buildSnapshot.dps.total,
                    ehp_delta = expResult.result.ehp.total - context.buildSnapshot.ehp.total,
                })
            end
        end
    end

    -- Sort: PASS first, then by DPS delta
    table.sort(results, function(a, b)
        if a.passed ~= b.passed then return a.passed end
        return (a.dps_delta or 0) > (b.dps_delta or 0)
    end)

    local lines = {"^7Owned Items Upgrade Scan:^0"}
    for _, r in ipairs(results) do
        local status = r.passed and "^2PASS^0" or "^1FAIL^0"
        local dps = r.dps_delta and string.format("%+.1f%%", r.dps_delta) or "?"
        local ehp = r.ehp_delta and string.format("%+.1f%%", r.ehp_delta) or "?"
        table.insert(lines, string.format("  %s %s (%s): DPS %s, EHP %s", status, r.name, r.slot, dps, ehp))
        if not r.passed then
            for _, f in ipairs(r.failures) do
                table.insert(lines, "    ^1→ " .. f .. "^0")
            end
        end
    end

    return {
        text = table.concat(lines, "\n"),
        data = { results = results },
    }
end

-- Trade search for upgrades
function executor.HandleTradeSearch(intent, provider, lldriver, context)
    -- Get current item in slot
    local currentItem = pob_api.GetItemInSlot(intent.slot)
    if not currentItem then
        return nil, "No item equipped in slot: " .. intent.slot
    end

    -- Build trade search query
    local weighting = intent.weighting or "Default"
    local query, err = pob_api.BuildTradeSearchQuery(currentItem, weighting)
    if not query then
        return nil, "Failed to build trade search query: " .. err
    end

    -- This would invoke the actual trade search
    -- For now, return the query info
    return {
        text = string.format("^7Trade Search Query Built for %s^0\nWeighting: %s\nQuery: %s",
            intent.slot, weighting, query.url or "N/A"),
        data = { query = query, slot = intent.slot, max_price = intent.max_price },
    }
end

-- Tree search
function executor.HandleTreeSearch(intent, provider, lldriver, context)
    -- This would use the passive tree search algorithm
    return {
        text = "^7Tree search for " .. intent.target .. " (max " .. intent.max_nodes .. " nodes) - not fully implemented^0",
        data = { target = intent.target, max_nodes = intent.max_nodes },
    }
end

-- Skill swap
function executor.HandleSkillSwap(intent, provider, lldriver, context)
    return {
        text = "^7Skill gem swap test for " .. intent.skill .. " - not fully implemented^0",
        data = { skill = intent.skill },
    }
end

-- Crafting simulation
function executor.HandleCraftSim(intent, provider, lldriver, context)
    local item = pob_api.GetItemInSlot(intent.item_slot)
    if not item then
        return nil, "No item equipped in slot: " .. intent.item_slot
    end

    -- Apply crafting recipe
    local newItem, err = crafting.ApplyRecipe(item, intent.recipe)
    if not newItem then
        return nil, "Crafting simulation failed: " .. err
    end

    -- Run experiment to validate
    local expResult, expErr = experiments.Run({
        variation = "craft_sim",
        item = newItem,
        slot = intent.item_slot,
        constraints = { resist_caps = true, stat_reqs = true },
        name = "craft-sim-" .. os.time(),
    })

    if not expResult then
        return nil, "Experiment failed: " .. expErr
    end

    local status = expResult.passed and "^2PASS^0" or "^1FAIL^0"
    return {
        text = string.format("%s Crafting simulation: %s on %s\nDPS: %+.1f%%, EHP: %+.1f%%",
            status, intent.recipe, intent.item_slot,
            (expResult.result.dps.total - context.buildSnapshot.dps.total) / context.buildSnapshot.dps.total * 100,
            (expResult.result.ehp.total - context.buildSnapshot.ehp.total) / context.buildSnapshot.ehp.total * 100),
        data = { recipe = intent.recipe, passed = expResult.passed, failures = expResult.failures },
    }
end

-- Promote loadout
function executor.HandlePromoteLoadout(intent, provider, lldriver, context)
    local ok, err = loadout.Promote(intent.test_loadout)
    if not ok then
        return nil, "Promotion failed: " .. err
    end
    return { text = "^2Promoted " .. intent.test_loadout .. " to Live Loadout^0", data = { promoted = intent.test_loadout } }
end

-- Discard loadout
function executor.HandleDiscardLoadout(intent, provider, lldriver, context)
    local ok, err = loadout.Discard(intent.test_loadout)
    if not ok then
        return nil, "Discard failed: " .. err
    end
    return { text = "^2Discarded " .. intent.test_loadout .. "^0", data = { discarded = intent.test_loadout } }
end

-- Update poe.ninja
function executor.HandleUpdatePoeNinja(intent, provider, lldriver, context)
    local ok, err = poe_ninja.FetchAndCache()
    if not ok then
        return nil, "Update failed: " .. err
    end
    return { text = "^2poe.ninja cache updated^0", data = { updated = os.date() } }
end

return executor