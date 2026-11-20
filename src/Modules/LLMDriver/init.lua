-- Path of Building
-- Module: LLMDriver Init
-- Entry point for the LLM Driver module

local LoadModule = LoadModule
local require = require

local LLMDriver = {}

-- Module metadata
LLMDriver.version = "0.1.0"
LLMDriver.name = "LLMDriver"

-- Load submodules
local config = LoadModule("Modules/LLMDriver/config")
local pob_api = LoadModule("Modules/LLMDriver/compat/pob_api")
local providers = LoadModule("Modules/LLMDriver/providers/interface")
local loadout = LoadModule("Modules/LLMDriver/loadout")
local experiments = LoadModule("Modules/LLMDriver/experiments")
local parser = LoadModule("Modules/LLMDriver/parser")
local executor = LoadModule("Modules/LLMDriver/executor")
local crafting = LoadModule("Modules/LLMDriver/crafting")
local external = LoadModule("Modules/LLMDriver/external/trade_search")
local poe_ninja = LoadModule("Modules/LLMDriver/external/poe_ninja")
local cache = LoadModule("Modules/LLMDriver/external/cache")

-- Store references
LLMDriver.config = config
LLMDriver.pob_api = pob_api
LLMDriver.providers = providers
LLMDriver.loadout = loadout
LLMDriver.experiments = experiments
LLMDriver.parser = parser
LLMDriver.executor = executor
LLMDriver.crafting = crafting
LLMDriver.external = external
LLMDriver.poe_ninja = poe_ninja
LLMDriver.cache = cache

-- State
LLMDriver.state = {
    initialized = false,
    active_provider = nil,
    conversation_history = {},
    current_build_snapshot = nil,
}

-- Initialize the module
function LLMDriver:Init()
    if self.state.initialized then
        return true
    end

    local cfg = config.Load()
    if not cfg.enabled then
        ConPrintf("LLMDriver: Module disabled in config")
        return false
    end

    ConPrintf("LLMDriver: Initializing v%s", self.version)

    -- Initialize provider
    local providerName = cfg.provider or "nvidia"
    local provider = providers.GetProvider(providerName, cfg)
    if not provider then
        ConPrintf("^1LLMDriver: Failed to initialize provider: %s^0", providerName)
        return false
    end

    -- Test connection
    local ok, err = provider:test_connection()
    if not ok then
        ConPrintf("^1LLMDriver: Provider connection test failed: %s^0", err)
        -- Try fallback
        local fallback = cfg.fallback_provider or "ollama"
        if fallback ~= providerName then
            ConPrintf("LLMDriver: Trying fallback provider: %s", fallback)
            provider = providers.GetProvider(fallback, cfg)
            if provider then
                ok, err = provider:test_connection()
                if ok then
                    ConPrintf("LLMDriver: Fallback provider connected")
                else
                    ConPrintf("^1LLMDriver: Fallback also failed: %s^0", err)
                    return false
                end
            end
        else
            return false
        end
    end

    self.state.active_provider = provider
    self.state.initialized = true

    ConPrintf("LLMDriver: Initialized with provider %s", provider.name)

    -- Register chat command
    self:RegisterCommands()

    return true
end

-- Register /llm chat command
function LLMDriver:RegisterCommands()
    -- Add to console command registry
    if ConRegisterCommand then
        ConRegisterCommand("llm", function(args)
            return self:HandleCommand(args)
        end, "LLM Driver commands. Usage: /llm <command> [--dry-run] [--explain]")
        ConPrintf("LLMDriver: Registered /llm command")
    else
        ConPrintf("^1LLMDriver: ConRegisterCommand not available^0")
    end
end

-- Handle /llm command
function LLMDriver:HandleCommand(args)
    if not self.state.initialized then
        return "LLMDriver not initialized. Check config."
    end

    -- Parse flags
    local dryRun = false
    local explain = false
    local cmdArgs = {}

    for _, arg in ipairs(args) do
        if arg == "--dry-run" then
            dryRun = true
        elseif arg == "--explain" then
            explain = true
        else
            table.insert(cmdArgs, arg)
        end
    end

    if #cmdArgs == 0 then
        return self:GetHelpText()
    end

    local command = table.concat(cmdArgs, " ")

    -- Parse intent
    local intent, parseErr = parser.Parse(command)
    if not intent then
        return "Parse error: " .. (parseErr or "unknown")
    end

    -- Add flags to intent
    intent.dry_run = dryRun
    intent.explain = explain

    -- Execute
    local result, execErr = executor.Execute(intent, self.state.active_provider, self)
    if not result then
        return "Execution error: " .. (execErr or "unknown")
    end

    -- Format response
    return self:FormatResponse(result, intent)
end

-- Format response for user
function LLMDriver:FormatResponse(result, intent)
    if intent.explain and result.reasoning then
        return string.format("%s\n\n^8Reasoning: %s^0", result.text or "Done.", result.reasoning)
    end
    return result.text or "Done."
end

-- Get help text
function LLMDriver:GetHelpText()
    return [[LLMDriver Commands:
  /llm show my resistances          - Show capped/uncapped elemental resistances
  /llm scan owned_items.json        - Test owned items for upgrades
  /llm find helmet under 10ex       - Search trade for upgrades
  /llm path to Avatar of Fire       - Find optimal tree path
  /llm test supports for Lightning Strike - Test support gem combos
  /llm craft add fire res to gloves - Simulate deterministic craft
  /llm accept test-loadout-1        - Promote test loadout to live
  /llm discard test-loadout-1       - Discard test loadout
  /llm update poe.ninja             - Refresh poe.ninja cache

Flags:
  --dry-run    Preview actions without executing
  --explain    Show LLM reasoning
]]
end

-- Get current build snapshot
function LLMDriver:GetBuildSnapshot()
    local build = pob_api.GetBuild()
    if not build then return nil end

    return {
        resistances = pob_api.GetResistances(),
        dps = pob_api.GetDPS(),
        ehp = pob_api.GetEHP(),
        attributes = pob_api.GetAttributes(),
        loadout = loadout.GetActiveLoadoutName(),
    }
end

-- Shutdown
function LLMDriver:Shutdown()
    self.state.initialized = false
    self.state.active_provider = nil
    ConPrintf("LLMDriver: Shutdown")
end

-- Export for global access
_G.LLMDriver = LLMDriver

return LLMDriver