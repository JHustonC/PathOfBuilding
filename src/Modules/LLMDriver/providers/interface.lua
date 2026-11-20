-- Path of Building
-- Module: LLMDriver Provider Interface
-- Uniform interface for LLM providers

local LoadModule = LoadModule
local require = require

local providers = {}

-- Provider registry
local registry = {}

-- Register a provider
function providers.Register(name, providerModule)
    registry[name] = providerModule
end

-- Get provider by name
function providers.GetProvider(name, config)
    local module = registry[name]
    if not module then
        return nil, "Provider not found: " .. name
    end

    local instance = module.New(config)
    if not instance then
        return nil, "Provider failed to initialize: " .. name
    end

    return instance
end

-- List available providers
function providers.List()
    local list = {}
    for name, _ in pairs(registry) do
        table.insert(list, name)
    end
    return list
end

-- Load built-in providers
-- NVIDIA provider
local ok, nvidia = pcall(function() return LoadModule("Modules/LLMDriver/providers/nvidia") end)
if ok and nvidia then
    providers.Register("nvidia", nvidia)
end

-- Ollama provider
ok, ollama = pcall(function() return LoadModule("Modules/LLMDriver/providers/ollama") end)
if ok and ollama then
    providers.Register("ollama", ollama)
end

-- OpenAI provider (stub)
ok, openai = pcall(function() return LoadModule("Modules/LLMDriver/providers/openai") end)
if ok and openai then
    providers.Register("openai", openai)
end

-- Anthropic provider (stub)
ok, anthropic = pcall(function() return LoadModule("Modules/LLMDriver/providers/anthropic") end)
if ok and anthropic then
    providers.Register("anthropic", anthropic)
end

-- Custom provider (stub)
ok, custom = pcall(function() return LoadModule("Modules/LLMDriver/providers/custom") end)
if ok and custom then
    providers.Register("custom", custom)
end

return providers