-- Path of Building
-- Module: LLMDriver External Cache
-- SQLite cache with TTL support

local LoadModule = LoadModule
local require = require

local cache = {}

-- Try to load lsqlite3
local sqlite3 = nil
local ok, err = pcall(function() sqlite3 = require("lsqlite3") end)
if not ok then
    ok, err = pcall(function() sqlite3 = require("sqlite3") end)
end

if not sqlite3 then
    ConPrintf("^1LLMDriver: lsqlite3 not available, using in-memory cache^0")
end

-- In-memory fallback cache
local memoryCache = {}

-- Database path
local dbPath = GetUserPath() .. "/Path of Building/llm_cache.db"

-- Initialize database
function cache.Init()
    if not sqlite3 then return true end

    local db, err = sqlite3.open(dbPath)
    if not db then
        ConPrintf("^1Cache: Failed to open database: %s^0", err)
        return false
    end

    -- Create tables
    local schema = [[
        CREATE TABLE IF NOT EXISTS kv_store (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            expires_at INTEGER,
            created_at INTEGER DEFAULT (strftime('%s', 'now'))
        );
        CREATE INDEX IF NOT EXISTS idx_expires ON kv_store(expires_at);

        CREATE TABLE IF NOT EXISTS experiments (
            id TEXT PRIMARY KEY,
            spec TEXT NOT NULL,
            result TEXT NOT NULL,
            passed INTEGER NOT NULL,
            failures TEXT,
            timestamp INTEGER NOT NULL,
            test_loadout_index INTEGER
        );
        CREATE INDEX IF NOT EXISTS idx_exp_timestamp ON experiments(timestamp);
    ]]

    local ok, err = db:exec(schema)
    if not ok then
        ConPrintf("^1Cache: Failed to create schema: %s^0", err)
        db:close()
        return false
    end

    db:close()
    return true
end

-- Get database connection
function cache.GetDB()
    if not sqlite3 then return nil end
    local db, err = sqlite3.open(dbPath)
    if not db then
        ConPrintf("^1Cache: Failed to open database: %s^0", err)
        return nil
    end
    return db
end

-- Set key with TTL (seconds)
function cache.Set(key, value, ttl)
    local json = require("dkjson")
    local serialized = json.encode(value)
    local expires = ttl and (os.time() + ttl) or nil

    if not sqlite3 then
        memoryCache[key] = { value = value, expires = expires }
        return true
    end

    local db = cache.GetDB()
    if not db then return false end

    local stmt = db:prepare("INSERT OR REPLACE INTO kv_store (key, value, expires_at) VALUES (?, ?, ?)")
    stmt:bind_values(key, serialized, expires)
    stmt:step()
    stmt:finalize()
    db:close()
    return true
end

-- Get key (returns nil if expired or not found)
function cache.Get(key)
    if not sqlite3 then
        local entry = memoryCache[key]
        if entry and (not entry.expires or entry.expires > os.time()) then
            return entry.value
        end
        return nil
    end

    local db = cache.GetDB()
    if not db then return nil end

    local stmt = db:prepare("SELECT value, expires_at FROM kv_store WHERE key = ?")
    stmt:bind_values(key)
    local row = stmt:first_row()
    stmt:finalize()
    db:close()

    if row then
        if row.expires_at and row.expires_at < os.time() then
            cache.Delete(key)
            return nil
        end
        local json = require("dkjson")
        return json.decode(row.value)
    end
    return nil
end

-- Delete key
function cache.Delete(key)
    if not sqlite3 then
        memoryCache[key] = nil
        return true
    end

    local db = cache.GetDB()
    if not db then return false end

    local stmt = db:prepare("DELETE FROM kv_store WHERE key = ?")
    stmt:bind_values(key)
    stmt:step()
    stmt:finalize()
    db:close()
    return true
end

-- Clean expired entries
function cache.CleanExpired()
    if not sqlite3 then
        local now = os.time()
        for k, v in pairs(memoryCache) do
            if v.expires and v.expires < now then
                memoryCache[k] = nil
            end
        end
        return true
    end

    local db = cache.GetDB()
    if not db then return false end

    local now = os.time()
    local stmt = db:prepare("DELETE FROM kv_store WHERE expires_at IS NOT NULL AND expires_at < ?")
    stmt:bind_values(now)
    stmt:step()
    stmt:finalize()
    db:close()
    return true
end

-- Store experiment record
function cache.StoreExperiment(record)
    local json = require("dkjson")
    local spec = json.encode(record.spec)
    local result = json.encode(record.result)
    local failures = record.failures and json.encode(record.failures) or nil

    if not sqlite3 then
        memoryCache["exp_" .. record.id] = record
        return true
    end

    local db = cache.GetDB()
    if not db then return false end

    local stmt = db:prepare([[
        INSERT OR REPLACE INTO experiments (id, spec, result, passed, failures, timestamp, test_loadout_index)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]])
    stmt:bind_values(
        record.id,
        spec,
        result,
        record.passed and 1 or 0,
        failures,
        record.timestamp,
        record.test_loadout_index
    )
    stmt:step()
    stmt:finalize()
    db:close()
    return true
end

-- Get experiment by ID
function cache.GetExperiment(id)
    local json = require("dkjson")

    if not sqlite3 then
        return memoryCache["exp_" .. id]
    end

    local db = cache.GetDB()
    if not db then return nil end

    local stmt = db:prepare("SELECT spec, result, passed, failures, timestamp, test_loadout_index FROM experiments WHERE id = ?")
    stmt:bind_values(id)
    local row = stmt:first_row()
    stmt:finalize()
    db:close()

    if row then
        return {
            id = id,
            spec = json.decode(row.spec),
            result = json.decode(row.result),
            passed = row.passed == 1,
            failures = row.failures and json.decode(row.failures) or nil,
            timestamp = row.timestamp,
            test_loadout_index = row.test_loadout_index,
        }
    end
    return nil
end

-- Get recent experiments
function cache.GetExperiments(limit)
    limit = limit or 50
    local json = require("dkjson")
    local results = {}

    if not sqlite3 then
        for k, v in pairs(memoryCache) do
            if k:match("^exp_") then
                table.insert(results, v)
            end
        end
        table.sort(results, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
        return { table.unpack(results, 1, limit) }
    end

    local db = cache.GetDB()
    if not db then return results end

    local stmt = db:prepare("SELECT id, spec, result, passed, failures, timestamp, test_loadout_index FROM experiments ORDER BY timestamp DESC LIMIT ?")
    stmt:bind_values(limit)
    for row in stmt:nrows() do
        table.insert(results, {
            id = row.id,
            spec = json.decode(row.spec),
            result = json.decode(row.result),
            passed = row.passed == 1,
            failures = row.failures and json.decode(row.failures) or nil,
            timestamp = row.timestamp,
            test_loadout_index = row.test_loadout_index,
        })
    end
    stmt:finalize()
    db:close()

    return results
end

-- Delete experiment
function cache.DeleteExperiment(id)
    if not sqlite3 then
        memoryCache["exp_" .. id] = nil
        return true
    end

    local db = cache.GetDB()
    if not db then return false end

    local stmt = db:prepare("DELETE FROM experiments WHERE id = ?")
    stmt:bind_values(id)
    stmt:step()
    stmt:finalize()
    db:close()
    return true
end

-- Initialize on load
cache.Init()

return cache