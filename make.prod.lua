local fs = require("santoku.fs")
local tbl = require("santoku.table")

return tbl.merge(
  fs.runfile("make.common.lua"), {
    env = {
      client = {
        files = false,
        ldflags = {
          "-sWASM_BIGINT",
          "-sDEFAULT_LIBRARY_FUNCS_TO_INCLUDE='$stringToNewUTF8'",
          "-sEXPORTED_FUNCTIONS=_main,_malloc,_free",
          "-sEXPORTED_RUNTIME_METHODS=stringToUTF8,lengthBytesUTF8,UTF8ToString,stringToNewUTF8",
          "-flto",
          "-Oz",
          "-sASSERTIONS=0",
          "-sEVAL_CTORS",
          "-sMALLOC=emmalloc",
          "-sENVIRONMENT=web,worker",
          "-sTEXTDECODER=2",
          "-sABORT_ON_WASM_EXCEPTIONS=0",
          "-sNO_EXIT_RUNTIME",
        },
      }
    }
  })
