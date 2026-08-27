local fs = require("santoku.fs")
local tbl = require("santoku.table")

return tbl.merge(
  fs.runfile("make.common.lua"), {
  env = {
    client = {
      ldflags = {
        "-O0",
        "-g",
        "-sASSERTIONS=2",
      },
    }
  }
})
