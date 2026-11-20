-- Path of Building
-- Module: LLMDriver External Trade Search
-- Invokes PoB's built-in Trade Search feature

local LoadModule = LoadModule
local require = require
local pob_api = LoadModule("Modules/LLMDriver/compat/pob_api")

local trade_search = {}

-- Build and execute a trade search for an item
function trade_search.Search(item, weighting, maxPrice)
    local query, err = pob_api.BuildTradeSearchQuery(item, weighting or "Default")
    if not query then
        return nil, err
    end

    -- query contains the trade search URL and parameters
    -- In reality, this would open the browser or fetch results via API
    -- For now, return the query info

    return {
        url = query.url,
        query_id = query.query_id,
        weighting = weighting,
        max_price = maxPrice,
        item_name = item.name or "Unknown",
    }, nil
end

-- Parse trade search results (HTML or JSON from PoE Trade API)
function trade_search.ParseResults(htmlOrJson)
    -- This would parse the trade site results
    -- Returns array of { item_text, price, mods, stats, url }
    return {}, "Not implemented"
end

-- Filter results by constraints
function trade_search.FilterResults(results, constraints)
    local filtered = {}
    for _, result in ipairs(results) do
        local ok = true
        if constraints.max_price and result.price and result.price > constraints.max_price then
            ok = false
        end
        if ok then
            table.insert(filtered, result)
        end
    end
    return filtered
end

-- Get trade search URL for manual browsing
function trade_search.GetSearchURL(item, weighting)
    local query, err = pob_api.BuildTradeSearchQuery(item, weighting or "Default")
    if not query then
        return nil, err
    end
    return query.url, nil
end

return trade_search