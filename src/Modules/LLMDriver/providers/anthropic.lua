-- Path of Building
-- Module: LLMDriver Anthropic Provider (Stub)

local anthropic = {}

function anthropic.New(config)
    local self = {}
    self.name = "anthropic"
    self.config = config or {}
    self.api_key = self.config.api_key or ""
    self.endpoint = self.config.endpoint or "https://api.anthropic.com/v1/messages"
    self.model = self.config.model or "claude-3-5-sonnet-20241022"

    function self:complete(prompt, context, schema)
        return nil, "Anthropic provider not fully implemented"
    end

    function self:test_connection()
        return false, "Anthropic provider not fully implemented"
    end

    return self
end

return anthropic