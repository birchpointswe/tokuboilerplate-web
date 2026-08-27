local js = require("santoku.web.js")
local val = require("santoku.web.val")
local dom = require("santoku.web.dom")
local async = require("santoku.web.async")
local socket = require("santoku.web.socket")
local proxy = require("santoku.web.sqlite.proxy")

local bundle_js = js.document:querySelector('meta[name="bundle-js"]').content
local core, ready = proxy(bundle_js)

local function esc (s)
  s = string.gsub(s, "&", "&amp;")
  s = string.gsub(s, "<", "&lt;")
  s = string.gsub(s, ">", "&gt;")
  s = string.gsub(s, "\"", "&quot;")
  return s
end

local function tag_html (tags_json)
  if not tags_json or tags_json == "[]" then
    return ""
  end
  local parts = {}
  for tag in string.gmatch(tags_json, "\"([^\"]+)\"") do
    parts[#parts + 1] = "<em class=\"tag\">#" .. esc(tag) .. "</em>"
  end
  return table.concat(parts, " ")
end

local render

local function bind_item (id)
  dom.listen("t-" .. id, "click", function ()
    async(function ()
      core.toggle(id)
      render()
    end)
  end)
  dom.listen("d-" .. id, "click", function ()
    async(function ()
      core.remove(id)
      render()
    end)
  end)
end

render = function ()
  local rows = core.list()
  local parts = {}
  for i = 1, #rows do
    local r = rows[i]
    local done = r.done == 1
    parts[#parts + 1] = table.concat({
      "<li id=\"item-", r.id, "\"", done and " class=\"done\"" or "", ">",
      "<button id=\"t-", r.id, "\">", done and "undo" or "done", "</button>",
      "<span>", esc(r.body), " ", tag_html(r.tags), "</span>",
      "<button id=\"d-", r.id, "\">x</button>",
      "</li>",
    })
  end
  dom.html("todo-list", table.concat(parts))
  dom.text("status", #rows == 0 and "Nothing yet." or (#rows .. " item(s)"))
  dom.flush()
  for i = 1, #rows do
    bind_item(rows[i].id)
  end
end

local function add_current ()
  async(function ()
    local value = dom.read({ "prop", "new-todo", "value" })
    if value and value ~= "" then
      core.add(value)
      dom.prop("new-todo", "value", "")
      dom.flush()
      render()
    end
  end)
end

local function do_sync ()
  async(function ()
    dom.text("sync-status", "syncing...")
    dom.flush()
    local changes, since = core.changes_for_sync()
    local ok, resp = socket.fetch("/sync?since=" .. since, {
      method = "POST",
      headers = { ["Content-Type"] = "application/json" },
      body = changes,
    })
    if not ok then
      dom.text("sync-status", "sync failed (" .. tostring(resp and resp.status) .. ")")
      dom.flush()
      return
    end
    core.apply_server(resp.body())
    dom.text("sync-status", "synced")
    dom.flush()
    render()
  end)
end

local function do_export ()
  async(function ()
    local data = core.export()
    local blob = js.Blob:new(val({ data }, true), val({ type = "application/json" }, true))
    local url = js.URL:createObjectURL(blob)
    local a = js.document:createElement("a")
    a.href = url
    a.download = "tokuboilerplate-export.json"
    a:click()
    js.URL:revokeObjectURL(url)
  end)
end

async(function ()
  local ok = ready:await()
  if ok == false then
    dom.text("status", "Database failed to start.")
    dom.flush()
    return
  end
  dom.listen("add-btn", "click", function ()
    add_current()
  end)
  dom.listen("new-todo", "keydown", function (_, ev)
    if ev.key == "Enter" then
      add_current()
    end
  end)
  dom.listen("sync-btn", "click", function ()
    do_sync()
  end)
  dom.listen("export-btn", "click", function ()
    do_export()
  end)
  render()
end)
