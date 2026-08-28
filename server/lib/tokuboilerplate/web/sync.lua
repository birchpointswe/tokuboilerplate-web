local db = require("tokuboilerplate.db.loaded")

local args = ngx.req.get_uri_args()
local since = tonumber(args.since) or 0

ngx.req.read_body()
local changes = ngx.req.get_body_data()

ngx.header.content_type = "application/json"
ngx.say(db.sync(changes, since))
