local env = require("santoku.env")

return {
  env = {

    name = "tokuboilerplate",
    version = "0.0.1-1",
    license = "MIT",

    dependencies = {
      "lua == 5.1",
    },

    build = {
      dependencies = {
        "santoku-web >= 2.0.1, < 3.0.0",
      },
    },

    server = {
      dependencies = {
        "lua == 5.1",
        "santoku >= 2.0.0, < 3.0.0",
        "santoku-sqlite >= 2.2.0, < 3.0.0",
        "santoku-sqlite-migrate >= 2.0.0, < 3.0.0",
      },
      test = {
        dependencies = {
          "luasocket >= 3.0",
        },
      },
    },

    client = {
      files = false,
      dependencies = {
        "lua == 5.1",
        "santoku >= 2.0.0, < 3.0.0",
        "santoku-web >= 2.0.1, < 3.0.0",
        "santoku-sqlite >= 2.2.0, < 3.0.0",
        "santoku-sqlite-migrate >= 2.0.0, < 3.0.0",
      },
      test = {
        dependencies = {
          "santoku-fs >= 2.0.0, < 3.0.0",
        },
      },
      rules = {
        ["bundle$"] = {
          ldflags = { "--pre-js", "res/pre.js" },
        },
      },
    },

    nginx = {
      domain = env.var("DOMAIN", "localhost"),
      port = env.var("PORT", "8080"),
      workers = "1",
      modules = {
        "tokuboilerplate.web.init",
        "tokuboilerplate.web.sync",
      },
    },

  },
}
