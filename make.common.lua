local fs = require("santoku.fs")
local num = require("santoku.num")
local str = require("santoku.string")
local arr = require("santoku.array")
local sys = require("santoku.system")
local env = require("santoku.env")
local build = require("santoku.make.build")
local lp = require("santoku.lpeg")

local icon_sizes = { 192, 512 }
local apple_icon_size = 180
local roboto_weights = { "300", "400", "500", "700" }

local public_files = { "index.css", "favicon.svg", "apple-touch-icon.png" }
for _, weight in ipairs(roboto_weights) do
  arr.push(public_files, "roboto-" .. weight .. ".woff2")
end
for _, size in ipairs(icon_sizes) do
  arr.push(public_files, "icon-" .. size .. ".png")
end

return {
  env = {

    name = "tokuboilerplate",
    version = "0.0.1-1",
    dependencies = {
      "lua == 5.1",
      "santoku >= 2.0.0, < 3.0.0",
    },
    build = {
      dependencies = {
        "santoku-web >= 2.0.0, < 3.0.0",
      }
    },

    server = {
      dependencies = {
        "lua == 5.1",
        "santoku >= 2.0.0, < 3.0.0",
        "santoku-web >= 2.0.0, < 3.0.0",
        "santoku-mustache >= 2.0.0, < 3.0.0",
        "santoku-sqlite >= 2.0.0, < 3.0.0",
        "santoku-sqlite-migrate >= 2.0.0, < 3.0.0",
        "argparse >= 0.7.1-1",
      },
    },

    client = {
      files = true,
      public = public_files,
      dependencies = {
        "lua == 5.1",
        "santoku >= 2.0.0, < 3.0.0",
        "santoku-web >= 2.0.0, < 3.0.0",
        "santoku-http >= 2.0.0, < 3.0.0",
        "santoku-sqlite >= 2.0.0, < 3.0.0",
        "santoku-sqlite-migrate >= 2.0.0, < 3.0.0",
      },
      rules = {
        ["bundle$"] = {
          ldflags = {
            "--pre-js", "res/pre.js",
          }
        }
      },
      pwa = {
        title = "tokuboilerplate",
        name = "tokuboilerplate",
        description = "A web app built with santoku",
        theme_color = "#1e293b",
        background_color = "#f5f5f5",
        transforms = {
          js = build.minify_js,
          css = build.minify_css,
          html = lp.minify_html,
        },
      },
    },

    nginx = {
      ssl_self_signed = true,
      hsts = false,
      ssl_port = env.var("SSL_PORT", "8443"),
      domain = "localhost",
      port = env.var("PORT", "8080"),
      workers = "auto",
      modules = {
        "tokuboilerplate.web.init",
        "tokuboilerplate.web.sync",
      },
    },

    configure = function (submake, envs)
      local server_env = envs.server
      local nginx_cfg = envs.root.nginx
      if server_env then
        local env_cert = env.var("TOKUBOILERPLATE_SSL_CERT", nil)
        local env_key = env.var("TOKUBOILERPLATE_SSL_KEY", nil)
        if env_cert and env_key then
          nginx_cfg.ssl_cert = env_cert
          nginx_cfg.ssl_key = env_key
        elseif nginx_cfg.ssl_self_signed then
          local ssl_dir = fs.join(server_env.work_dir, "ssl")
          local ssl_cert = fs.join(ssl_dir, "localhost.crt")
          local ssl_key = fs.join(ssl_dir, "localhost.key")
          if not (fs.exists(ssl_cert) and fs.exists(ssl_key)) then
            fs.mkdirp(ssl_dir)
            sys.execute({
              "openssl", "req", "-x509", "-nodes", "-days", "365",
                "-newkey", "rsa:2048",
                "-keyout", ssl_key,
                "-out", ssl_cert,
                "-subj", "/CN=localhost/O=DEV ONLY - NOT FOR PRODUCTION",
                "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1"
            })
          end
          nginx_cfg.ssl_cert = ssl_cert
          nginx_cfg.ssl_key = ssl_key
        end
      end
      local client_env = envs.client
      if not client_env then return end
      local roboto_urls = {
        ["300"] = "https://fonts.gstatic.com/s/roboto/v32/KFOlCnqEu92Fr1MmSU5fCxc4EsA.woff2",
        ["400"] = "https://fonts.gstatic.com/s/roboto/v32/KFOmCnqEu92Fr1Mu7GxKOzY.woff2",
        ["500"] = "https://fonts.gstatic.com/s/roboto/v32/KFOlCnqEu92Fr1MmEU9fCxc4EsA.woff2",
        ["700"] = "https://fonts.gstatic.com/s/roboto/v32/KFOlCnqEu92Fr1MmWUlfCxc4EsA.woff2",
      }
      for _, weight in ipairs(roboto_weights) do
        local font_file = fs.join(client_env.public_dir, "roboto-" .. weight .. ".woff2")
        submake.target({ client_env.target }, { font_file })
        submake.target({ font_file }, {}, function ()
          sys.execute({
            "curl", "-sL", "-o", font_file, roboto_urls[weight]
          })
        end)
      end
      local css_out = fs.join(client_env.public_dir, "index.css")
      local css_in = fs.join(client_env.build_dir, "res/index.css")
      submake.target({ client_env.target }, { css_out })
      submake.target({ css_out }, { css_in }, function ()
        sys.execute({
          "tailwindcss",
          "--cwd", client_env.root_dir,
          "-i", css_in,
          "-o", css_out,
          "--minify"
        })
      end)
      local icon_svg_src = fs.join(client_env.work_dir, "res/icon.svg")
      local bg = envs.root.client.pwa.background_color
      local favicon_svg = fs.join(client_env.public_dir, "favicon.svg")
      submake.target({ client_env.target }, { favicon_svg })
      submake.target({ favicon_svg }, { icon_svg_src }, function ()
        fs.writefile(favicon_svg, fs.readfile(icon_svg_src))
      end)
      local manifest_icons = {}
      for _, size in ipairs(icon_sizes) do
        local icon_file = fs.join(client_env.public_dir, "icon-" .. size .. ".png")
        submake.target({ client_env.target }, { icon_file })
        submake.target({ icon_file }, { icon_svg_src }, function ()
          sys.execute({
            "rsvg-convert", "-w", tostring(size), "-h", tostring(size),
            "-o", icon_file, icon_svg_src
          })
        end)
        arr.push(manifest_icons, {
          src = "/icon-" .. size .. ".png",
          sizes = size .. "x" .. size,
          type = "image/png"
        })
      end
      local apple_icon = fs.join(client_env.public_dir, "apple-touch-icon.png")
      submake.target({ client_env.target }, { apple_icon })
      submake.target({ apple_icon }, { icon_svg_src }, function ()
        sys.execute({
          "rsvg-convert", "-w", tostring(apple_icon_size), "-h", tostring(apple_icon_size),
          "-o", apple_icon, icon_svg_src
        })
      end)
      envs.root.client.pwa.icons = manifest_icons
      envs.root.client.pwa.manifest = "/manifest.json"
      envs.root.client.pwa.favicon_svg = "/favicon.svg"
      envs.root.client.pwa.ios_icon = "/apple-touch-icon.png"
      if client_env.static_files_ok then
        local all_static_files = { css_out, favicon_svg, apple_icon }
        for _, weight in ipairs(roboto_weights) do
          arr.push(all_static_files, fs.join(client_env.public_dir, "roboto-" .. weight .. ".woff2"))
        end
        for _, size in ipairs(icon_sizes) do
          arr.push(all_static_files, fs.join(client_env.public_dir, "icon-" .. size .. ".png"))
        end
        submake.target({ client_env.static_files_ok }, all_static_files, function ()
          fs.touch(client_env.static_files_ok)
        end)
      end
    end,

  }
}
