-- Path of Building
-- Module: LLMDriver External poe.ninja
-- Fetches and caches poe.ninja data using lcurl.safe

local LoadModule = LoadModule
local require = require
local json = require("dkjson")
local cache = LoadModule("Modules/LLMDriver/external/cache")
local http_util = LoadModule("Modules/LLMDriver/external/http_util")

local poe_ninja = {}

-- poe.ninja API endpoints
local ENDPOINTS = {
    builds = "https://poe.ninja/api/data/buildoverview",
    items = "https://poe.ninja/api/data/itemoverview",
    currency = "https://poe.ninja/api/data/currencyoverview",
}

-- Fetch data from poe.ninja
function poe_ninja.Fetch(category, league)
    league = league or "Standard"
    local url = ENDPOINTS[category]
    if not url then
        return nil, "Unknown category: " .. category
    end

    url = url .. "?league=" .. league .. "&type=" .. category

    local body, err = http_util.Get(url, nil, 30)
    if not body then
        return nil, err
    end

    local data, err = json.decode(body)
    if not data then
        return nil, "JSON parse failed: " .. err
    end

    return data, nil
end

-- Fetch and cache all data
function poe_ninja.FetchAndCache(league)
    league = league or "Standard"
    local allData = {}

    for category, _ in pairs(ENDPOINTS) do
        local data, err = poe_ninja.Fetch(category, league)
        if data then
            allData[category] = data
            cache.Set("poe_ninja_" .. category .. "_" .. league, data, 86400) -- 24h TTL
        else
            ConPrintf("^1poe.ninja: Failed to fetch %s: %s^0", category, err)
        end
    end

    cache.Set("poe_ninja_last_update", os.time(), 86400)
    return allData
end

-- Get cached data
function poe_ninja.GetCached(category, league)
    league = league or "Standard"
    return cache.Get("poe_ninja_" .. category .. "_" .. league)
end

-- Get popular items for a build archetype
function poe_ninja.GetPopularItems(archetype, league)
    local builds = poe_ninja.GetCached("builds", league)
    if not builds then return nil end

    local items = {}
    for _, build in ipairs(builds.lines or {}) do
        if build.skill and build.skill:lower():find(archetype:lower()) then
            for _, item in ipairs(build.items or {}) do
                local name = item.name or item.type
                items[name] = (items[name] or 0) + 1
            end
        end
    end

    -- Sort by popularity
    local sorted = {}
    for name, count in pairs(items) do
        table.insert(sorted, { name = name, count = count })
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    return sorted
end

-- Get item price
function poe_ninja.GetItemPrice(itemName, league)
    local items = poe_ninja.GetCached("items", league)
    if not items then return nil end

    for _, item in ipairs(items.lines or {}) do
        if item.name:lower() == itemName:lower() then
            return item.chaosValue or item.divineValue
        end
    end
    return nil
end

-- Check if cache is fresh
function poe_ninja.IsCacheFresh(league)
    league = league or "Standard"
    local lastUpdate = cache.Get("poe_ninja_last_update")
    if not lastUpdate then return false end
    return (os.time() - lastUpdate) < 86400 -- 24h
end

return poe_ninja