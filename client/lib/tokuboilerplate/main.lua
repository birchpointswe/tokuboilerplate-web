local js = require("santoku.web.js")
local str = require("santoku.string")
local sqlite_proxy = require("santoku.web.sqlite.proxy")
local vue = require("santoku.web.vue")
local async = require("santoku.web.async")
local util = require("santoku.web.util")
local json = require("cjson")

local hash_manifest = js.self.HASH_MANIFEST
local function resolve_hashed (path)
  if hash_manifest then
    local name = str.stripprefix(path, "/")
    local hashed = hash_manifest[name]
    if hashed then
      return "/" .. hashed
    end
  end
  return path
end

local function fetch_json (url)
  local ok, response = js.self:fetch(url):await()
  if not ok or not response.ok then return nil end
  local ok2, text = response:text():await()
  if not ok2 then return nil end
  return json.decode(text)
end

local val = require("santoku.web.val")

local function apply_data (self, data)
  if not data then return end
  self.numbers = val(data.numbers, true)
  self.page = data.page
  self.total_pages = data.total_pages
  if data.sync_state then self.sync_state = data.sync_state end
  if data.auto_sync ~= nil then self.auto_sync = data.auto_sync end
  if self.auto_sync and (self.sync_state == "dirty" or self.sync_state == "pending") then
    self:doSync()
  end
end

local sync_fetch = util.atleast(function (page)
  return fetch_json("/sync?page=" .. page)
end, 300)

local bundle_js = resolve_hashed(js.document:querySelector('meta[name="bundle-js"]').content)
async(function ()
  sqlite_proxy(bundle_js):await()

  local debounced_sync = util.debounce(function (self)
    self.syncing = true
    local data = sync_fetch(self.page)
    self.syncing = false
    if data then
      apply_data(self, data)
    end
  end, 300)

  local scope = {

    numbers = {},
    page = 1,
    total_pages = 1,
    sync_state = "loading",
    auto_sync = false,
    has_session = false,
    loading = true,
    syncing = false,

    load = function (self)
      async(function ()
        apply_data(self, fetch_json("/numbers?page=" .. self.page))
        self.loading = false
      end)
    end,

    createNumber = function (self)
      async(function ()
        apply_data(self, fetch_json("/number/create?page=1"))
      end)
    end,

    updateNumber = function (self, id)
      async(function ()
        apply_data(self, fetch_json("/number/update?id=" .. id .. "&page=" .. self.page))
      end)
    end,

    deleteNumber = function (self, id)
      async(function ()
        apply_data(self, fetch_json("/number/delete?id=" .. id .. "&page=" .. self.page))
      end)
    end,

    goToPage = function (self, p)
      self.page = p
      self:load()
    end,

    prevPage = function (self)
      if self.page > 1 then
        self:goToPage(self.page - 1)
      end
    end,

    nextPage = function (self)
      if self.page < self.total_pages then
        self:goToPage(self.page + 1)
      end
    end,

    toggleAutoSync = function (self)
      async(function ()
        local data = fetch_json("/auto-sync/toggle")
        if data then
          self.sync_state = data.state
          self.auto_sync = data.auto_sync
          if data.trigger_sync then
            self:doSync()
          end
        end
      end)
    end,

    doSync = function (self)
      debounced_sync(self)
    end,

    loadSyncStatus = function (self)
      async(function ()
        local data = fetch_json("/sync/status")
        if data then
          self.sync_state = data.state
          self.auto_sync = data.auto_sync
        end
      end)
    end,

    deleteSession = function (self)
      async(function ()
        local data = fetch_json("/session/delete")
        if data then
          self.has_session = data.has_session
        end
      end)
    end,

  }

  vue.createApp(scope):mount("#app-content")

end)
