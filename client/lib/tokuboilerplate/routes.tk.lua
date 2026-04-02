<%
  local fs = require("santoku.fs")
  local tbl = require("santoku.table")
  local index = require("santoku.web.pwa.index")
  local partials = fs.runfile(fs.join(root_dir, "res/web/template-loader.lua"))(readfile, root_dir)
  bundle_js_hashed = "/" .. hashed("bundle.js")
  bundle_wasm_hashed = "/" .. hashed("bundle.wasm")
  index_html = index(tbl.merge({}, client.pwa, {
    sw = true,
    initial = false,
    head = [[
      <meta name="bundle-js" content="{{bundle\.js}}">
      <link rel="stylesheet" href="{{index\.css}}">
      <script src="{{bundle\.js}}"></script>
    ]],
    body = partials["body-app"](),
  }))
%>

local js = require("santoku.web.js")
local val = require("santoku.web.val")
local err = require("santoku.error")
local mch = require("santoku.mustache")
local rand = require("santoku.random")
local index_html = mch([[<% return index_html, false %>]])(val.lua(js.HASH_MANIFEST, true))

return function (db, http)

  local function do_sync (authorization, page)
    local since = db.get_last_sync() or "0"
    local changes = db.get_changes()
    local ok, response = http.post("/sync?since=" .. since .. "&page=" .. page, {
      headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = authorization,
      },
      body = changes,
    })
    if not ok or not response or not response.ok then
      return db.get_numbers_with_state(page)
    end
    local server_changes = response.body()
    if not server_changes then
      return db.get_numbers_with_state(page)
    end
    return db.complete_sync(server_changes, page)
  end

  return {

    ["^/$"] = function ()
      return index_html, "text/html"
    end,

    ["^/numbers$"] = function (_, _, params)
      local page = tonumber(params.page) or 1
      return db.get_numbers_with_state(page)
    end,

    ["^/number/create$"] = function (_, _, params)
      local page = tonumber(params.page) or 1
      return db.create_number_with_state(page)
    end,

    ["^/number/update$"] = function (_, _, params)
      err.assert(params.id, "missing id parameter")
      local page = tonumber(params.page) or 1
      return db.update_number_with_state(params.id, page)
    end,

    ["^/number/delete$"] = function (_, _, params)
      err.assert(params.id, "missing id parameter")
      local page = tonumber(params.page) or 1
      return db.delete_number_with_state(params.id, page)
    end,

    ["^/sync/status$"] = function ()
      return db.get_sync_state()
    end,

    ["^/auto%-sync/toggle$"] = function ()
      return db.toggle_auto_sync()
    end,

    ["^/auth/status$"] = function ()
      return db.get_auth_status()
    end,

    ["^/session/delete$"] = function ()
      return db.delete_session()
    end,

    ["^/sync$"] = function (_, _, params)
      local page = tonumber(params.page) or 1
      local auth = db.get_authorization()
      if not auth then
        auth = rand.alnum(32)
        db.set_authorization(auth)
      end
      return do_sync(auth, page)
    end,

  }

end
