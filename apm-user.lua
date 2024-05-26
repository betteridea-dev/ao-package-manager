json = require("json")

-- common error handler
function handle_run(func, msg)
    local ok, err = pcall(func, msg)
    if not ok then
        local clean_err = err:match(":%d+: (.+)") or err
        print(msg.Action .. " - " .. err)
        Handlers.utils.reply(clean_err)(msg)
    end
end

local json = require("json")
local base64 = require(".base64")

function DownloadResponseHandler(msg)
    local data = json.decode(msg.Data)
    local vendor = data.Vendor
    local version = data.Version
    local items = json.decode(base64.decode(data.Items))
    local name = data.Name
    if vendor ~= "@apm" then
        name = vendor .. "/" .. name
    end
    local main = data.Main

    local main_src
    for _, item in ipairs(items) do
        item.data = base64.decode(item.data)
        if item.meta.name == main then
            main_src = item.data
        end
    end

    assert(main_src, "❌ Unable to find " .. main .. " file to load")
    main_src = string.gsub(main_src, '^%s*(.-)%s*$', '%1') -- remove leading/trailing space

    print("ℹ️ Attempting to load " .. name .. "@" .. version .. " package")

    local func, err = load(string.format([[
        local function _load()
            %s
        end
        _G.package.loaded["%s"] = _load()
    ]], main_src, name))

    if not func then
        print(err)
        error("Error compiling load function: ")
    end
    func()
    print("✅ Package has been loaded, you can now import it using require function")
end

Handlers.add(
    "DownloadResponseHandler",
    Handlers.utils.hasMatchingTag("Action", "DownloadResponse"),
    function(msg)
        handle_run(DownloadResponseHandler, msg)
    end
)
