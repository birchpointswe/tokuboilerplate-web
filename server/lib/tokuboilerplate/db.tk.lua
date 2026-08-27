<%
  local fs = require("santoku.fs")
  local serialize = require("santoku.serialize")
  local migrations = {}
  for fp in fs.files("res/server/migrations") do
    migrations[fs.basename(fp)] = readfile(fp)
  end
  t_migrations = serialize(migrations, true)
%>

local err = require("santoku.error")
local db_mod = require("santoku.sqlite.db")
local sqlite = require("santoku.sqlite")
local migrate = require("santoku.sqlite.migrate")

return function (db_file)

  local M = {}
  local db = sqlite(err.assert(db_mod.open(db_file)))

  db.exec("pragma busy_timeout = 30000")
  db.exec("pragma journal_mode = WAL")
  db.exec("pragma synchronous = NORMAL")

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

  local clear_incoming = db.runner("delete from todos_incoming")

  local populate_incoming = db.runner([[
    insert into todos_incoming (id, body, done, deleted, updated_at)
    select
      json_extract(value, '$.id'),
      json_extract(value, '$.body'),
      json_extract(value, '$.done'),
      json_extract(value, '$.deleted'),
      json_extract(value, '$.updated_at')
    from json_each(?1)
  ]])

  local insert_from_incoming = db.runner([[
    insert or ignore into todos (id, body, done, deleted, updated_at)
    select id, body, done, deleted, updated_at
    from todos_incoming
  ]])

  local update_from_incoming = db.runner([[
    update todos set
      body = i.body,
      done = i.done,
      deleted = i.deleted,
      updated_at = i.updated_at
    from todos_incoming i
    where todos.id = i.id and i.updated_at > todos.updated_at
  ]])

  local get_response = db.getter([[
    select json_object(
      'now', unixepoch('now', 'subsec'),
      'changes', coalesce((
        select json_group_array(json_object(
          'id', id,
          'body', body,
          'done', done,
          'deleted', deleted,
          'updated_at', updated_at
        )) from todos where updated_at > ?1), json_array()))
  ]])

  M.db = db

  M.sync = function (changes_json, since)
    return db.transaction(function ()
      clear_incoming()
      populate_incoming(changes_json or "[]")
      insert_from_incoming()
      update_from_incoming()
      return get_response(since or 0)
    end)
  end

  return M

end
