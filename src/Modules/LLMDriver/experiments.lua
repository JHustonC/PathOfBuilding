-- Path of Building
-- Module: LLMDriver Experiments
-- Headless experiment runner on Test Loadouts

local LoadModule = LoadModule
local require = require
local pob_api = LoadModule("Modules/LLMDriver/compat/pob_api")
local loadout = LoadModule("Modules/LLMDriver/loadout")
local cache = LoadModule("Modules/LLMDriver/external/cache")

local experiments = {}

-- Default resistance caps
local DEFAULT_RESIST_CAPS = {
    fire = 75,
    cold = 75,
    lightning = 75,
    chaos = 75,
}

-- Run an experiment
function experiments.Run(spec)
    -- spec: {
    --   variation = "gear_swap" | "tree_change" | "skill_swap" | "craft_sim",
    --   item = item_object,           -- for gear_swap
    --   slot = "Helmet" | "Chest" | etc, -- for gear_swap
    --   path = {nodeId, ...},         -- for tree_change
    --   supports = {gem, ...},        -- for skill_swap
    --   recipe = "add_fire_res",      -- for craft_sim
    --   constraints = {               -- validation constraints
    --     resist_caps = true,
    --     stat_reqs = true,
    --     budget = 10,                -- for trade search
    --   },
    --   name = "test-loadout-1",      -- optional test loadout name
    -- }

    local liveLoadoutName = "Default"
    local testLoadoutName = spec.name or ("test-" .. os.time())

    -- Clone live to test loadout
    local testIndex, err = loadout.CloneLive(testLoadoutName, liveLoadoutName)
    if not testIndex then
        return nil, "Failed to create test loadout: " .. (err or "unknown")
    end

    -- Run experiment on test loadout
    local result, runErr = experiments.RunOnLoadout(testIndex, spec)

    if not result then
        -- Clean up on failure
        loadout.Discard(testIndex)
        return nil, runErr
    end

    -- Validate constraints
    local passed, failures = experiments.ValidateConstraints(result, spec.constraints or {})

    -- Store in experiment database
    local expRecord = {
        id = testLoadoutName,
        spec = spec,
        result = result,
        passed = passed,
        failures = failures,
        timestamp = os.time(),
        test_loadout_index = testIndex,
    }

    cache.StoreExperiment(expRecord)

    return {
        test_loadout = testLoadoutName,
        test_loadout_index = testIndex,
        result = result,
        passed = passed,
        failures = failures,
        record = expRecord,
    }, nil
end

-- Run experiment logic on a specific loadout
function experiments.RunOnLoadout(testIndex, spec)
    return pob_api.RunOnLoadout(testIndex, function()
        -- Apply variation
        local applyErr = experiments.ApplyVariation(spec)
        if applyErr then
            error("Failed to apply variation: " .. applyErr)
        end

        -- Recalculate
        pob_api.BuildCalcs()

        -- Capture results
        return experiments.CaptureResults()
    end)
end

-- Apply the specified variation
function experiments.ApplyVariation(spec)
    if spec.variation == "gear_swap" then
        return experiments.ApplyGearSwap(spec.item, spec.slot)
    elseif spec.variation == "tree_change" then
        return experiments.ApplyTreeChange(spec.path)
    elseif spec.variation == "skill_swap" then
        return experiments.ApplySkillSwap(spec.supports)
    elseif spec.variation == "craft_sim" then
        return experiments.ApplyCraftSim(spec.item, spec.recipe)
    else
        return "Unknown variation type: " .. tostring(spec.variation)
    end
end

-- Apply gear swap
function experiments.ApplyGearSwap(item, slotName)
    if not item then
        return "No item provided"
    end

    -- Equip the item on the test loadout
    local ok, err = pcall(pob_api.EquipItem, item, slotName)
    if not ok then
        return "Failed to equip item: " .. err
    end
    return nil
end

-- Apply tree change (allocate path)
function experiments.ApplyTreeChange(path)
    if not path or #path == 0 then
        return "No path provided"
    end

    for _, nodeId in ipairs(path) do
        local ok, err = pcall(pob_api.AllocNode, nodeId)
        if not ok then
            return "Failed to allocate node " .. nodeId .. ": " .. err
        end
    end
    return nil
end

-- Apply skill swap
function experiments.ApplySkillSwap(supports)
    if not supports or #supports == 0 then
        return "No supports provided"
    end

    -- This would modify the skill setup on the test loadout
    -- Simplified for now
    return "Skill swap not fully implemented"
end

-- Apply crafting simulation
function experiments.ApplyCraftSim(item, recipe)
    if not item or not recipe then
        return "Item and recipe required"
    end

    -- This would use the crafting module to simulate
    -- Simplified for now
    return "Crafting sim not fully implemented"
end

-- Capture current build state
function experiments.CaptureResults()
    local resistances = pob_api.GetResistances()
    local dps = pob_api.GetDPS()
    local ehp = pob_api.GetEHP()
    local attributes = pob_api.GetAttributes()
    local skills = pob_api.GetSkills()
    local nodes = pob_api.GetAllocatedNodes()

    return {
        resistances = resistances,
        dps = dps,
        ehp = ehp,
        attributes = attributes,
        skills = skills,
        allocated_nodes = nodes,
        timestamp = os.time(),
    }
end

-- Validate experiment results against constraints
function experiments.ValidateConstraints(result, constraints)
    local failures = {}
    local passed = true

    -- Resistance caps check
    if constraints.resist_caps and result.resistances then
        for elem, cap in pairs(DEFAULT_RESIST_CAPS) do
            local capped = result.resistances[elem] and result.resistances[elem].capped or 0
            if capped < cap then
                passed = false
                table.insert(failures, string.format("%s resistance %d%% below cap %d%%", elem:upper(), capped, cap))
            end
        end
    end

    -- Stat requirements check
    if constraints.stat_reqs and result.attributes then
        local req = result.attributes.requirements
        local attrs = result.attributes
        if attrs.strength < req.strength then
            passed = false
            table.insert(failures, string.format("Strength %d < required %d", attrs.strength, req.strength))
        end
        if attrs.dexterity < req.dexterity then
            passed = false
            table.insert(failures, string.format("Dexterity %d < required %d", attrs.dexterity, req.dexterity))
        end
        if attrs.intelligence < req.intelligence then
            passed = false
            table.insert(failures, string.format("Intelligence %d < required %d", attrs.intelligence, req.intelligence))
        end
        if attrs.level < req.level then
            passed = false
            table.insert(failures, string.format("Level %d < required %d", attrs.level, req.level))
        end
    end

    -- Budget check (for trade search)
    if constraints.budget then
        -- This would check item price against budget
        -- Not implemented yet
    end

    return passed, failures
end

-- Get experiment history
function experiments.GetHistory(limit)
    return cache.GetExperiments(limit or 50)
end

-- Get experiment by ID
function experiments.GetExperiment(id)
    return cache.GetExperiment(id)
end

-- Delete experiment
function experiments.DeleteExperiment(id)
    return cache.DeleteExperiment(id)
end

return experiments