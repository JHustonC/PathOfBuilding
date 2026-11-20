-- Path of Building
-- Module: LLMDriver Config
-- Configuration system for LLMDriver

local LoadModule = LoadModule
local require = require
local io = io
local json = require("dkjson")

local config = {}

-- Default configuration
local defaultConfig = {
    enabled = true,
    provider = "nvidia",
    model = "nemotron-3-ultra",
    api_key = "",
    endpoint = "https://integrate.api.nvidia.com/v1/chat/completions",
    timeout = 30,
    max_retries = 3,
    dry_run_default = false,
    live_loadout_name = "Default",
    fallback_provider = "ollama",
    fallback_model = "llama3.1:70b",
    fallback_endpoint = "http://localhost:11434/v1/chat/completions",
    log_level = "info",
}

-- Config file path
local configPath = GetUserPath() .. "/Path of Building/LLMDriverConfig.lua"

-- Deep merge tables
local function deepMerge(base, override)
    local result = {}
    for k, v in pairs(base) do
        result[k] = v
    end
    for k, v in pairs(override) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = deepMerge(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

-- Load config from file
function config.Load()
    local file = io.open(configPath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local ok, userConfig = pcall(load, content)
        if ok and userConfig then
            local ok2, parsed = pcall(userConfig)
            if ok2 and type(parsed) == "table" then
                return deepMerge(defaultConfig, parsed)
            else
                ConPrintf("^1LLMDriver: Failed to parse config file: %s^0", parsed or "unknown error")
            end
        else
            ConPrintf("^1LLMDriver: Failed to load config file: %s^0", userConfig or "unknown error")
        end
    end
    return deepMerge(defaultConfig, {})
end

-- Save config to file
function config.Save(cfg)
    local dir = GetUserPath() .. "/Path of Building"
    local ok, err = pcall(function()
        local file = io.open(configPath, "w")
        if not file then error("Cannot open config for writing") end
        file:write("-- LLMDriver Configuration\nreturn ")
        file:write(json.encode(cfg, { indent = true }))
        file:close()
    end)
    if not ok then
        ConPrintf("^1LLMDriver: Failed to save config: %s^0", err)
        return false
    end
    return true
end

-- Get config value with fallback
function config.Get(key, default)
    local cfg = config.Load()
    local keys = {}
    for k in string.gmatch(key, "[^.]+") do
        table.insert(keys, k)
    end
    local val = cfg
    for _, k in ipairs(keys) do
        if type(val) == "table" then
            val = val[k]
        else
            return default
        end
    end
    return val ~= nil and val or default
end

-- Set config value
function config.Set(key, value)
    local cfg = config.Load()
    local keys = {}
    for k in string.gmatch(key, "[^.]+") do
        table.insert(keys, k)
    end
    local parent = cfg
    for i = 1, #keys - 1 do
        local k = keys[i]
        if type(parent[k]) ~= "table" then
            parent[k] = {}
        end
        parent = parent[k]
    end
    parent[keys[#keys]] = value
    return config.Save(cfg)
end

-- Reset to defaults
function config.Reset()
    return config.Save(defaultConfig)
end

return config