-- Path of Building
-- Module: LLMDriver Ollama Provider
-- Local Ollama HTTP adapter (OpenAI-compatible API)

local LoadModule = LoadModule
local require = require
local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("dkjson")

local ollama = {}

function ollama.New(config)
    local self = {}

    self.name = "ollama"
    self.config = config or {}
    self.endpoint = self.config.fallback_endpoint or "http://localhost:11434/v1/chat/completions"
    self.model = self.config.fallback_model or "llama3.1:70b"
    self.timeout = self.config.timeout or 30
    self.max_retries = self.config.max_retries or 3

    -- Complete a prompt
    function self:complete(prompt, context, schema)
        local messages = self:BuildMessages(prompt, context)

        local body = {
            model = self.model,
            messages = messages,
            temperature = 0.1,
            max_tokens = 4096,
        }

        if schema then
            body.response_format = {
                type = "json_schema",
                json_schema = {
                    name = "response",
                    schema = schema,
                    strict = true,
                }
            }
        end

        local jsonBody = json.encode(body)

        for attempt = 1, self.max_retries do
            local response, err = self:MakeRequest(jsonBody)
            if response then
                return self:ParseResponse(response)
            end

            if attempt < self.max_retries then
                local waitTime = math.min(2 ^ attempt, 10)
                coroutine.yield(waitTime)
            end
        end

        return nil, "Max retries exceeded"
    end

    -- Test connection
    function self:test_connection()
        local testPrompt = "Say 'OK' if you can hear me."
        local messages = {
            { role = "user", content = testPrompt }
        }

        local body = {
            model = self.model,
            messages = messages,
            max_tokens = 10,
        }

        local jsonBody = json.encode(body)
        local response, err = self:MakeRequest(jsonBody)

        if response then
            return true, nil
        end
        return false, err
    end

    -- Make HTTP request
    function self:MakeRequest(jsonBody)
        local responseBody = {}
        local headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = string.len(jsonBody),
        }

        local request = {
            url = self.endpoint,
            method = "POST",
            headers = headers,
            source = ltn12.source.string(jsonBody),
            sink = ltn12.sink.table(responseBody),
        }

        local ok, code, respHeaders, status = pcall(function()
            return http.request(request)
        end)

        if not ok then
            return nil, "Request failed: " .. tostring(code)
        end

        if code ~= 200 then
            local body = table.concat(responseBody)
            return nil, "HTTP " .. code .. ": " .. body
        end

        return table.concat(responseBody), nil
    end

    -- Build messages array (same as NVIDIA)
    function self:BuildMessages(prompt, context)
        local messages = {}

        local systemPrompt = [[You are an AI assistant controlling Path of Building, an offline build planner for Path of Exile.
You translate user commands into structured intents that the system executes.
You have access to the current build state and can run experiments on isolated test loadouts.

Available actions:
- Query build stats (resistances, DPS, EHP, attributes)
- Swap gear on test loadouts
- Search passive tree paths
- Test skill gem combinations
- Simulate deterministic crafting bench recipes
- Invoke PoB's built-in Trade Search
- Promote/discard test loadouts

Always respond with structured JSON matching the provided schema.
Be concise and accurate.]]
        table.insert(messages, { role = "system", content = systemPrompt })

        if context and context.buildSnapshot then
            local snapshot = context.buildSnapshot
            local contextText = string.format(
                "Current Build: DPS=%.0f, EHP=%.0f, Resistances(Fire:%d/%d, Cold:%d/%d, Lightning:%d/%d, Chaos:%d/%d), Level=%d, Str/Dex/Int=%d/%d/%d",
                snapshot.dps.total or 0,
                snapshot.ehp.total or 0,
                snapshot.resistances.fire.capped or 0, snapshot.resistances.fire.uncapped or 0,
                snapshot.resistances.cold.capped or 0, snapshot.resistances.cold.uncapped or 0,
                snapshot.resistances.lightning.capped or 0, snapshot.resistances.lightning.uncapped or 0,
                snapshot.resistances.chaos.capped or 0, snapshot.resistances.chaos.uncapped or 0,
                snapshot.attributes.level or 1,
                snapshot.attributes.strength or 0, snapshot.attributes.dexterity or 0, snapshot.attributes.intelligence or 0
            )
            table.insert(messages, { role = "system", content = "Build Context: " .. contextText })
        end

        if context and context.conversationHistory then
            for i = math.max(1, #context.conversationHistory - 5), #context.conversationHistory do
                table.insert(messages, context.conversationHistory[i])
            end
        end

        table.insert(messages, { role = "user", content = prompt })

        return messages
    end

    -- Parse response
    function self:ParseResponse(responseBody)
        local ok, parsed = pcall(json.decode, responseBody)
        if not ok then
            return nil, "Failed to parse JSON response"
        end

        if parsed.choices and parsed.choices[1] and parsed.choices[1].message then
            local content = parsed.choices[1].message.content
            if content then
                local ok2, structured = pcall(json.decode, content)
                if ok2 then
                    return structured
                end
                return { text = content }
            end
        end

        return nil, "Unexpected response format"
    end

    return self
end

return ollama