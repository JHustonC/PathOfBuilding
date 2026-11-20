-- Path of Building
-- Module: LLMDriver OpenAI Provider (Stub)
-- OpenAI HTTP adapter

local LoadModule = LoadModule
local require = require
local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("dkjson")

local openai = {}

function openai.New(config)
    local self = {}
    self.name = "openai"
    self.config = config or {}
    self.api_key = self.config.api_key or ""
    self.endpoint = self.config.endpoint or "https://api.openai.com/v1/chat/completions"
    self.model = self.config.model or "gpt-4o"

    function self:complete(prompt, context, schema)
        return nil, "OpenAI provider not fully implemented"
    end

    function self:test_connection()
        return false, "OpenAI provider not fully implemented"
    end

    return self
end

return openai