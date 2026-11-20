-- Path of Building
-- Module: LLMDriver Custom Provider (Stub)

local custom = {}

function custom.New(config)
    local self = {}
    self.name = "custom"
    self.config = config or {}
    self.api_key = self.config.api_key or ""
    self.endpoint = self.config.custom_endpoint or ""
    self.model = self.config.custom_model or "custom-model"

    function self:complete(prompt, context, schema)
        return nil, "Custom provider not configured"
    end

    function self:test_connection()
        if self.endpoint == "" then
            return false, "Custom endpoint not configured"
        end
        return false, "Custom provider not fully implemented"
    end

    return self
end

return custom