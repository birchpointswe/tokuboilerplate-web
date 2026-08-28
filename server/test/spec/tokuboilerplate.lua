local test = require("santoku.test")
local err = require("santoku.error")
local http = require("socket.http")
local ltn12 = require("ltn12")
local env = require("santoku.env")

local url = "http://localhost:" .. env.var("PORT", "8080") .. "/sync"
local run_id = "spec" .. tostring(os.time())

local function post (u, body)
  local chunks = {}
  local ok, code = http.request({
    url = u,
    method = "POST",
    headers = {
      ["content-type"] = "application/json",
      ["content-length"] = tostring(#body),
    },
    source = ltn12.source.string(body),
    sink = ltn12.sink.table(chunks),
  })
  err.assert(ok, "request failed: " .. tostring(code))
  return code, table.concat(chunks)
end

local function change (body, done, at)
  return "[{\"id\":\"" .. run_id .. "\",\"body\":\"" .. body
    .. "\",\"done\":" .. done .. ",\"deleted\":0,\"updated_at\":" .. at .. "}]"
end

test("sync endpoint", function ()

  test("accepts a change set and returns now + changes", function ()
    local code, body = post(url .. "?since=0", change("hello from " .. run_id, 0, 1.5))
    err.assert(code == 200, "expected 200, got " .. tostring(code))
    err.assert(string.find(body, "\"now\""), "response carries now")
    err.assert(string.find(body, "\"changes\""), "response carries changes")
  end)

  test("previously pushed rows come back for since=0", function ()
    local code, body = post(url .. "?since=0", "[]")
    err.assert(code == 200)
    err.assert(string.find(body, run_id, 1, true), "pushed row echoes back")
  end)

  test("newer client rows win and filter by since", function ()
    local code = post(url .. "?since=0", change("edited " .. run_id, 1, 2.5))
    err.assert(code == 200)
    local code2, body2 = post(url .. "?since=2", "[]")
    err.assert(code2 == 200)
    err.assert(string.find(body2, "edited " .. run_id, 1, true), "newer edit visible past since")
    local code3, body3 = post(url .. "?since=0", change("stale " .. run_id, 0, 0.5))
    err.assert(code3 == 200)
    err.assert(not string.find(body3, "stale " .. run_id, 1, true), "older write must lose")
    err.assert(string.find(body3, "edited " .. run_id, 1, true), "newer body survives")
  end)

  test("GET is rejected", function ()
    local chunks = {}
    local ok, code = http.request({
      url = url,
      method = "GET",
      sink = ltn12.sink.table(chunks),
    })
    err.assert(ok, "request failed")
    err.assert(code == 403, "expected 403, got " .. tostring(code))
  end)

end)
