local fs = require("santoku.fs")
local tbl = require("santoku.table")

return tbl.merge(
  fs.runfile("make.common.lua"), {
    env = {
      client = {
        files = false,
        ldflags = {
          "-flto",
        },
      }
    }
  })
