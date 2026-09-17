local config = require("tokuboilerplate.config")
package.loaded["tokuboilerplate.db.loaded"] =
  require("tokuboilerplate.db")(config.db_file, { no_migrate = true })
