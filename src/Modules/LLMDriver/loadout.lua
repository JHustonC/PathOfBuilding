-- Path of Building
-- Module: LLMDriver Loadout Management
-- Live/Test Loadout safety model using PoB's Sets/Loadouts feature

local LoadModule = LoadModule
local require = require
local pob_api = LoadModule("Modules/LLMDriver/compat/pob_api")

local loadout = {}

-- Clone the live loadout to create a test loadout
function loadout.CloneLive(name, liveLoadoutName)
    liveLoadoutName = liveLoadoutName or "Default"

    local liveIndex = nil
    local loadouts = pob_api.GetLoadouts()
    for i, lo in ipairs(loadouts) do
        if lo.title == liveLoadoutName then
            liveIndex = i
            break
        end
    end

    if not liveIndex then
        return nil, "Live loadout not found: " .. liveLoadoutName
    end

    -- Use PoB's internal clone if available
    local build = pob_api.GetBuild()
    if build and build.build and build.build.CloneLoadout then
        local newIndex = build.build:CloneLoadout(liveIndex, name)
        if newIndex then
            return newIndex, nil
        end
    end

    -- Fallback: manual clone via loadout creation
    -- This is a simplified version; real implementation would be more complex
    return nil, "Loadout cloning not fully implemented"
end

-- Protect a loadout (mark as live)
function loadout.Protect(index, liveLoadoutName)
    -- Protection is enforced by executor checking before writes
    -- Just returns the live loadout name for reference
    return liveLoadoutName
end

-- Promote a test loadout to live
function loadout.Promote(testIndex, liveLoadoutName)
    local build = pob_api.GetBuild()
    if not build then
        return false, "No active build"
    end

    local testName = pob_api.GetLoadoutName(testIndex)
    if not testName then
        return false, "Test loadout not found"
    end

    -- Find live loadout index
    local liveIndex = nil
    local loadouts = pob_api.GetLoadouts()
    for i, lo in ipairs(loadouts) do
        if lo.title == liveLoadoutName then
            liveIndex = i
            break
        end
    end

    if not liveIndex then
        return false, "Live loadout not found"
    end

    -- Copy test loadout data to live loadout
    -- This would use PoB's internal copy mechanism
    if build.build and build.build.CopyLoadout then
        local ok = build.build:CopyLoadout(testIndex, liveIndex)
        if ok then
            pob_api.BuildCalcs()
            return true, nil
        end
    end

    return false, "Loadout promotion not fully implemented"
end

-- Discard a test loadout
function loadout.Discard(testIndex)
    local ok, err = pob_api.DeleteLoadout(testIndex)
    return ok, err
end

-- List all loadouts with type
function loadout.List(liveLoadoutName)
    liveLoadoutName = liveLoadoutName or "Default"
    local loadouts = pob_api.GetLoadouts()
    local result = {}

    for i, lo in ipairs(loadouts) do
        table.insert(result, {
            index = i,
            name = lo.title or ("Loadout " .. i),
            type = (lo.title == liveLoadoutName) and "Live" or "Test",
            active = (i == pob_api.GetActiveLoadoutIndex()),
        })
    end

    return result
end

-- Get active loadout name
function loadout.GetActiveLoadoutName()
    return pob_api.GetLoadoutName(pob_api.GetActiveLoadoutIndex())
end

-- Check if loadout is protected (live)
function loadout.IsProtected(index, liveLoadoutName)
    return pob_api.IsLoadoutProtected(index, liveLoadoutName)
end

return loadout