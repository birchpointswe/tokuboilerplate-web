local env = require("santoku.env")
local db_file = env.var("DB_FILE", "tokuboilerplate-server.db")
local migrator = require("tokuboilerplate.db")(db_file)
migrator.db.close()
package.loaded["tokuboilerplate.config"] = { db_file = db_file }
