local test = require("santoku.test")
local err = require("santoku.error")
local fs = require("santoku.fs")
local sqlite = require("santoku.sqlite.db")
local sql = require("santoku.sqlite")
local migrate = require("santoku.sqlite.migrate")

local migrations = {}
for fp in fs.files("res/client/migrations") do
  migrations[fs.basename(fp)] = fs.readfile(fp)
end

test("client schema and closures", function ()

  local db = sql(err.assert(sqlite.open_memory()))

  migrate(db, migrations)

  local add = db.getter([[
    insert into todos (id, body, done, deleted, updated_at)
    values (lower(hex(randomblob(8))), ?1, 0, 0, unixepoch('now', 'subsec'))
    returning id
  ]])
  local list = db.all("select id, body, done from todos where deleted = 0 order by rowid desc", true)
  local toggle = db.runner([[
    update todos set done = 1 - done, updated_at = unixepoch('now', 'subsec'), synced_at = null
    where id = ?
  ]])
  local remove = db.runner([[
    update todos set deleted = 1, updated_at = unixepoch('now', 'subsec'), synced_at = null
    where id = ?
  ]])

  test("create, list, toggle, delete", function ()
    local id = add("write docs #docs")
    err.assert(type(id) == "string" and #id == 16, "expected 16-char hex id")
    add("test docs")
    local rows = list()
    err.assert(#rows == 2, "expected 2 rows")
    err.assert(rows[2].body == "write docs #docs", "ordering")
    toggle(id)
    err.assert(db.getter("select done from todos where id = ?")(id) == 1, "toggle sets done")
    remove(id)
    err.assert(#list() == 1, "soft delete hides the row")
  end)

  test("dirty tracking for sync", function ()
    local dirty = db.getter("select count(*) from todos where synced_at is null")
    err.assert(dirty() == 2, "both writes should be dirty")
    db.runner("update todos set synced_at = unixepoch('now', 'subsec')")()
    err.assert(dirty() == 0, "mark synced clears dirty")
  end)

  db.close()

end)
