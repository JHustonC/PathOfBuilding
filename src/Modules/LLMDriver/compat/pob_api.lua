-- Path of Building
-- Module: LLMDriver PoB API Abstraction
-- Facade wrapping all PoB internal APIs used by LLMDriver

local LoadModule = LoadModule
local require = require

local pob_api = {}

-- Get the current build object
function pob_api.GetBuild()
    if main and main.mode and main.mode.build then
        return main.mode.build
    end
    return nil
end

-- Get the main object
function pob_api.GetMain()
    return main
end

-- Trigger full build calculation
function pob_api.BuildCalcs()
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end
    if build.calcsTab and build.calcsTab.BuildCalcs then
        build.calcsTab:BuildCalcs()
        return true
    end
    error("BuildCalcs not available")
end

-- Parse item text into PoB item object
function pob_api.CreateItemFromRaw(text)
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end
    if build.itemsTab and build.itemsTab.CreateItemFromRaw then
        return build.itemsTab:CreateItemFromRaw(text)
    end
    error("CreateItemFromRaw not available")
end

-- Passive tree allocation
function pob_api.AllocNode(nodeId)
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end
    if build.spec and build.spec.AllocNode then
        return build.spec:AllocNode(nodeId)
    end
    error("AllocNode not available")
end

function pob_api.DeallocNode(nodeId)
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end
    if build.spec and build.spec.DeallocNode then
        return build.spec:DeallocNode(nodeId)
    end
    error("DeallocNode not available")
end

-- Loadout management
function pob_api.GetLoadouts()
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end
    return build.build.loadouts or {}
end

function pob_api.SetActiveLoadout(index)
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end
    if build.build and build.build.SetActiveLoadout then
        return build.build:SetActiveLoadout(index)
    end
    error("SetActiveLoadout not available")
end

function pob_api.GetActiveLoadoutIndex()
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end
    if build.build and build.build.activeLoadout then
        return build.build.activeLoadout
    end
    return 1
end

function pob_api.GetLoadoutName(index)
    local loadouts = pob_api.GetLoadouts()
    if loadouts[index] then
        return loadouts[index].title or ("Loadout " .. index)
    end
    return nil
end

-- PoB Trade Search
function pob_api.BuildTradeSearchQuery(item, weighting)
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end
    if build.itemsTab and build.itemsTab.BuildTradeSearchQuery then
        return build.itemsTab:BuildTradeSearchQuery(item, weighting)
    end
    error("BuildTradeSearchQuery not available")
end

-- Character import/export
function pob_api.ImportBuild(data)
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end
    if build.ImportBuild then
        return build:ImportBuild(data)
    end
    error("ImportBuild not available")
end

function pob_api.ExportBuild()
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end
    if build.ExportBuild then
        return build:ExportBuild()
    end
    error("ExportBuild not available")
end

-- Get resistances (capped and uncapped)
function pob_api.GetResistances()
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end

    local result = {
        fire = { capped = 0, uncapped = 0 },
        cold = { capped = 0, uncapped = 0 },
        lightning = { capped = 0, uncapped = 0 },
        chaos = { capped = 0, uncapped = 0 },
    }

    -- Try to get from calcs
    if build.calcsTab and build.calcsTab.mainOutput then
        local output = build.calcsTab.mainOutput
        if output.Resistances then
            for elem, _ in pairs(result) do
                local res = output.Resistances[elem:upper()] or output.Resistances[elem]
                if res then
                    result[elem].capped = res.Capped or res.Capped or res
                    result[elem].uncapped = res.Uncapped or res.Total or res
                end
            end
        end
    end

    -- Fallback: try defensive stats
    if build.calcsTab and build.calcsTab.mainEnv and build.calcsTab.mainEnv.playerResistances then
        local res = build.calcsTab.mainEnv.playerResistances
        for elem, _ in pairs(result) do
            local val = res[elem:upper()] or res[elem]
            if val then
                result[elem].capped = val.Capped or val.Capped or val
                result[elem].uncapped = val.Uncapped or val.Total or val
            end
        end
    end

    return result
end

-- Get DPS
function pob_api.GetDPS()
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end

    if build.calcsTab and build.calcsTab.mainOutput then
        local output = build.calcsTab.mainOutput
        return {
            total = output.TotalDPS or output.TotalDPS or 0,
            hit = output.HitDPS or 0,
            ailment = output.AilmentDPS or 0,
            breakdown = output.DPSBreakdown,
        }
    end
    return { total = 0, hit = 0, ailment = 0 }
end

-- Get EHP (Effective HP)
function pob_api.GetEHP()
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end

    if build.calcsTab and build.calcsTab.mainOutput then
        local output = build.calcsTab.mainOutput
        return {
            total = output.EffectiveHP or output.LifeEHP or 0,
            life = output.Life or 0,
            es = output.EnergyShield or 0,
            mana = output.Mana or 0,
            breakdown = output.EHPBreakdown,
        }
    end
    return { total = 0, life = 0, es = 0, mana = 0 }
end

-- Get attributes (Str/Dex/Int) and requirements
function pob_api.GetAttributes()
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end

    local result = {
        strength = 0,
        dexterity = 0,
        intelligence = 0,
        level = 1,
        requirements = {
            strength = 0,
            dexterity = 0,
            intelligence = 0,
            level = 1,
        },
    }

    if build.calcsTab and build.calcsTab.mainOutput then
        local output = build.calcsTab.mainOutput
        if output.Attributes then
            result.strength = output.Attributes.Strength or 0
            result.dexterity = output.Attributes.Dexterity or 0
            result.intelligence = output.Attributes.Intelligence or 0
        end
        if output.Requirements then
            result.requirements.strength = output.Requirements.Strength or 0
            result.requirements.dexterity = output.Requirements.Dexterity or 0
            result.requirements.intelligence = output.Requirements.Intelligence or 0
            result.requirements.level = output.Requirements.Level or 1
        end
    end

    return result
end

-- Get skill setup
function pob_api.GetSkills()
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end

    if build.skillsTab and build.skillsTab.skills then
        local skills = {}
        for i, skill in ipairs(build.skillsTab.skills) do
            table.insert(skills, {
                index = i,
                name = skill.name or skill.mainSkillName or "Unknown",
                mainSkill = skill.mainActiveSkill and skill.mainActiveSkill.name or nil,
                supports = skill.supports or {},
                enabled = skill.enabled ~= false,
            })
        end
        return skills
    end

    return {}
end

-- Get passive tree nodes
function pob_api.GetAllocatedNodes()
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end

    if build.spec and build.spec.allocNodes then
        local nodes = {}
        for nodeId, _ in pairs(build.spec.allocNodes) do
            table.insert(nodes, nodeId)
        end
        return nodes
    end

    return {}
end

-- Get node info
function pob_api.GetNodeInfo(nodeId)
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end

    if build.tree and build.tree.nodes and build.tree.nodes[nodeId] then
        local node = build.tree.nodes[nodeId]
        return {
            id = nodeId,
            name = node.name or node.dn,
            isNotable = node.notable or false,
            isKeystone = node.keystone or false,
            isMastery = node.mastery or false,
            x = node.x,
            y = node.y,
            sd = node.sd,
            stats = node.stats,
        }
    end

    return nil
end

-- Equip item in slot
function pob_api.EquipItem(item, slotName)
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end

    if build.itemsTab and build.itemsTab.EquipItem then
        return build.itemsTab:EquipItem(item, slotName)
    end
    error("EquipItem not available")
end

-- Unequip item from slot
function pob_api.UnequipItem(slotName)
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end

    if build.itemsTab and build.itemsTab.UnequipItem then
        return build.itemsTab:UnequipItem(slotName)
    end
    error("UnequipItem not available")
end

-- Get item in slot
function pob_api.GetItemInSlot(slotName)
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end

    if build.itemsTab and build.itemsTab.items and build.itemsTab.items[slotName] then
        return build.itemsTab.items[slotName]
    end
    return nil
end

-- Clone loadout (create test loadout from live)
function pob_api.CloneLoadout(sourceIndex, newTitle)
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end

    if build.build and build.build.CloneLoadout then
        return build.build:CloneLoadout(sourceIndex, newTitle)
    end

    -- Fallback: manual clone
    local loadouts = pob_api.GetLoadouts()
    local source = loadouts[sourceIndex]
    if not source then
        error("Source loadout not found")
    end

    -- Create new loadout by copying sets
    -- This is a simplified version; real implementation would use PoB's internal clone
    return nil
end

-- Delete loadout
function pob_api.DeleteLoadout(index)
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end

    if build.build and build.build.DeleteLoadout then
        return build.build:DeleteLoadout(index)
    end
    error("DeleteLoadout not available")
end

-- Check if loadout is protected (live)
function pob_api.IsLoadoutProtected(index, liveLoadoutName)
    local name = pob_api.GetLoadoutName(index)
    return name == liveLoadoutName
end

-- Run a function on a specific loadout (switch, run, switch back)
function pob_api.RunOnLoadout(index, fn)
    local build = pob_api.GetBuild()
    if not build then
        error("No active build")
    end

    local currentIndex = pob_api.GetActiveLoadoutIndex()
    local success, err = pcall(function()
        pob_api.SetActiveLoadout(index)
        pob_api.BuildCalcs()
        return fn()
    end)
    pob_api.SetActiveLoadout(currentIndex)
    pob_api.BuildCalcs()

    if not success then
        error("Error running on loadout " .. index .. ": " .. err)
    end
    return err
end

return pob_api