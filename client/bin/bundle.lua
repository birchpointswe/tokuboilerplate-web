-- SPDX-License-Identifier: MIT
-- SPDX-FileCopyrightText: 2025 Birch Point SWE
local js = require("santoku.web.js")
local global = js.self
if global.document ~= nil then
  return require("tokuboilerplate.main")
else
  return require("tokuboilerplate.db")
end
