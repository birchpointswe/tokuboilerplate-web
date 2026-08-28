<%
  serialize = require("santoku.serialize")
  local arr = require("santoku.array")
  all_precache = {}
  for _, name in ipairs(public_files_static_for_precache) do
    arr.push(all_precache, name)
  end
  for name in pairs(registered_public_files) do
    arr.push(all_precache, name)
  end
%>

local sw = require("santoku.web.pwa.sw")
local routes = require("tokuboilerplate.routes")

return sw({
  nonce = "<% return tostring(os.time()) %>",
  version = "<% return version %>",
  sqlite = true,
  self_alias = <% return client.hash_public and '"bundle.js"' or 'nil' %>,
  precache = <% return serialize(all_precache), false %>,
  routes = routes,
})
