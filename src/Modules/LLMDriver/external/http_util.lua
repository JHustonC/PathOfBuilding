-- Path of Building
-- Module: LLMDriver HTTP Utility
-- HTTP client using lcurl.safe (PoB's built-in libcurl)

local LoadModule = LoadModule
local require = require
local json = require("dkjson")

local http_util = {}

-- Make HTTP POST request using lcurl.safe
function http_util.Post(url, headers, body, timeout)
    local curl = require("lcurl.safe")
    local easy = curl.easy()
    
    local responseBody = {}
    local responseHeaders = {}
    
    easy:setopt(curl.OPT_URL, url)
    easy:setopt(curl.OPT_POST, true)
    easy:setopt(curl.OPT_POSTFIELDS, body)
    easy:setopt(curl.OPT_POSTFIELDSIZE, #body)
    easy:setopt(curl.OPT_WRITEFUNCTION, function(data)
        table.insert(responseBody, data)
        return #data
    end)
    easy:setopt(curl.OPT_HEADERFUNCTION, function(data)
        table.insert(responseHeaders, data)
        return #data
    end)
    easy:setopt(curl.OPT_USERAGENT, "Path of Building LLMDriver")
    easy:setopt(curl.OPT_FOLLOWLOCATION, 1)
    easy:setopt(curl.OPT_SSL_VERIFYPEER, 0)
    easy:setopt(curl.OPT_SSL_VERIFYHOST, 0)
    easy:setopt(curl.OPT_TIMEOUT, timeout or 30)
    easy:setopt(curl.OPT_CONNECTTIMEOUT, 10)
    
    -- Set headers
    local headerList = {}
    for k, v in pairs(headers or {}) do
        table.insert(headerList, k .. ": " .. v)
    end
    if #headerList > 0 then
        easy:setopt(curl.OPT_HTTPHEADER, headerList)
    end
    
    easy:setopt(curl.OPT_POSTFIELDS, body)
    
    local ok, err = pcall(function()
        easy:perform()
    end)
    
    local code = easy:getinfo(curl.INFO_RESPONSE_CODE)
    easy:close()
    
    if not ok then
        return nil, "Request failed: " .. tostring(err)
    end
    
    if code ~= 200 then
        local body = table.concat(responseBody)
        return nil, "HTTP " .. code .. ": " .. body
    end
    
    return table.concat(responseBody), nil
end

-- Make HTTP GET request using lcurl.safe
function http_util.Get(url, headers, timeout)
    local curl = require("lcurl.safe")
    local easy = curl.easy()
    
    local responseBody = {}
    local responseHeaders = {}
    
    easy:setopt(curl.OPT_URL, url)
    easy:setopt(curl.OPT_HTTPGET, true)
    easy:setopt(curl.OPT_WRITEFUNCTION, function(data)
        table.insert(responseBody, data)
        return #data
    end)
    easy:setopt(curl.OPT_HEADERFUNCTION, function(data)
        table.insert(responseHeaders, data)
        return #data
    end)
    easy:setopt(curl.OPT_USERAGENT, "Path of Building LLMDriver")
    easy:setopt(curl.OPT_FOLLOWLOCATION, 1)
    easy:setopt(curl.OPT_SSL_VERIFYPEER, 0)
    easy:setopt(curl.OPT_SSL_VERIFYHOST, 0)
    easy:setopt(curl.OPT_TIMEOUT, timeout or 30)
    easy:setopt(curl.OPT_CONNECTTIMEOUT, 10)
    
    -- Set headers
    local headerList = {}
    for k, v in pairs(headers or {}) do
        table.insert(headerList, k .. ": " .. v)
    end
    if #headerList > 0 then
        easy:setopt(curl.OPT_HTTPHEADER, headerList)
    end
    
    local ok, err = pcall(function()
        easy:perform()
    end)
    
    local code = easy:getinfo(curl.INFO_RESPONSE_CODE)
    easy:close()
    
    if not ok then
        return nil, "Request failed: " .. tostring(err)
    end
    
    if code ~= 200 then
        local body = table.concat(responseBody)
        return nil, "HTTP " .. code .. ": " .. body
    end
    
    return table.concat(responseBody), nil
end

return http_util