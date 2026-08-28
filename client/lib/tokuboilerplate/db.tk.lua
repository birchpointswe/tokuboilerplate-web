<%
  local fs = require("santoku.fs")
  local serialize = require("santoku.serialize")
  local migrations = {}
  for fp in fs.files("res/client/migrations") do
    migrations[fs.basename(fp)] = readfile(fp)
  end
  t_migrations = serialize(migrations, true)
%>

local sqlite_worker = require("santoku.web.sqlite.worker")
local migrate = require("santoku.sqlite.migrate")

local function parse_tags (body)
  local tags = {}
  for tag in string.gmatch(body, "#([%w-]+)") do
    tags[string.lower(tag)] = true
  end
  return tags
end

return sqlite_worker("/tokuboilerplate.db", function (ok, db)

  if not ok then
    return false, db
  end

  db.exec("pragma journal_mode = TRUNCATE")
  db.exec("pragma synchronous = NORMAL")
  db.exec("pragma temp_store = MEMORY")

  migrate(db, <% return t_migrations %>) -- luacheck: ignore

  db.exec([[
    create temporary table if not exists todos_incoming (
      id text primary key,
      body text,
      done integer,
      deleted integer,
      updated_at real
    )
  ]])

  local M = {}

  local add = db.getter([[
    insert into todos (id, body, done, deleted, updated_at)
    values (lower(hex(randomblob(8))), ?1, 0, 0, unixepoch('now', 'subsec'))
    returning id
  ]])

  local list = db.all([[
    select
      t.id, t.body, t.done,
      (select json_group_array(tag) from todos_tags g where g.todo_id = t.id) as tags
    from todos t
    where t.deleted = 0
    order by t.rowid desc
  ]], true)

  local toggle = db.runner([[
    update todos set
      done = 1 - done,
      updated_at = unixepoch('now', 'subsec'),
      synced_at = null
    where id = ?
  ]])

  local remove = db.runner([[
    update todos set
      deleted = 1,
      updated_at = unixepoch('now', 'subsec'),
      synced_at = null
    where id = ?
  ]])

  local clear_tags = db.runner("delete from todos_tags where todo_id = ?")
  local add_tag = db.runner("insert or ignore into todos_tags (todo_id, tag) values (?, ?)")
  local clear_all_tags = db.runner("delete from todos_tags")
  local iter_live = db.iter("select id, body from todos where deleted = 0")

  local function retag (id, body)
    clear_tags(id)
    for tag in pairs(parse_tags(body)) do
      add_tag(id, tag)
    end
  end

  local function retag_all ()
    clear_all_tags()
    for id, body in iter_live() do
      retag(id, body)
    end
  end

  local get_changes = db.getter([[
    select coalesce(json_group_array(json_object(
      'id', id,
      'body', body,
      'done', done,
      'deleted', deleted,
      'updated_at', updated_at
    )), '[]') from todos where synced_at is null
  ]])

  local get_since = db.getter([[
    select coalesce((select value from settings where key = 'last_sync'), '0')
  ]])

  local clear_incoming = db.runner("delete from todos_incoming")

  local populate_incoming = db.runner([[
    insert into todos_incoming (id, body, done, deleted, updated_at)
    select
      json_extract(value, '$.id'),
      json_extract(value, '$.body'),
      json_extract(value, '$.done'),
      json_extract(value, '$.deleted'),
      json_extract(value, '$.updated_at')
    from json_each(json_extract(?1, '$.changes'))
  ]])

  local insert_from_incoming = db.runner([[
    insert or ignore into todos (id, body, done, deleted, updated_at, synced_at)
    select id, body, done, deleted, updated_at, unixepoch('now', 'subsec')
    from todos_incoming
  ]])

  local update_from_incoming = db.runner([[
    update todos set
      body = i.body,
      done = i.done,
      deleted = i.deleted,
      updated_at = i.updated_at,
      synced_at = unixepoch('now', 'subsec')
    from todos_incoming i
    where todos.id = i.id and i.updated_at > todos.updated_at
  ]])

  local mark_synced = db.runner([[
    update todos set synced_at = unixepoch('now', 'subsec')
    where synced_at is null
  ]])

  local set_last_sync = db.runner([[
    insert or replace into settings (key, value)
    values ('last_sync', json_extract(?1, '$.now'))
  ]])

  local export = db.getter([[
    select coalesce(json_group_array(json_object(
      'id', t.id,
      'body', t.body,
      'done', t.done,
      'tags', (select json_group_array(tag) from todos_tags g where g.todo_id = t.id)
    )), '[]') from todos t where t.deleted = 0
  ]])

  M.list = function ()
    return list()
  end

  M.add = function (body)
    return db.transaction(function ()
      local id = add(body)
      retag(id, body)
      return id
    end)
  end

  M.toggle = function (id)
    return toggle(id)
  end

  M.remove = function (id)
    return db.transaction(function ()
      remove(id)
      clear_tags(id)
    end)
  end

  M.changes_for_sync = function ()
    return get_changes(), get_since()
  end

  M.apply_server = function (response_json)
    return db.transaction(function ()
      clear_incoming()
      populate_incoming(response_json)
      insert_from_incoming()
      update_from_incoming()
      mark_synced()
      set_last_sync(response_json)
      retag_all()
    end)
  end

  M.export = function ()
    return export()
  end

  return true, M

end)
