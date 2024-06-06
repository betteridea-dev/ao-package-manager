json = require("json")
base64 = require(".base64")

-- common error handler
function handle_run(func, msg)
    local ok, err = pcall(func, msg)
    if not ok then
        local clean_err = err:match(":%d+: (.+)") or err
        print(msg.Action .. " - " .. err)
        -- Handlers.utils.reply(clean_err)(msg)
        if not msg.Target == ao.id then
            ao.send({
                Target = msg.From,
                Data = clean_err
            })
        end
    end
end

-- function to generate package data
-- @param name: Name of the package
-- @param Vendor: Vender under which package is published (leave nil for default @apm)
-- @param version: Version of the package (default 1.0.0)
-- @param readme: Readme content
-- @param description: Brief description of the package
-- @param main: Name of the main file (default main.lua)
-- @param dependencies: List of dependencies
-- @param repo_url: URL of the repository
-- @param items: List of files in the package
-- @param authors: List of authors
function generate_package_data(name, Vendor, version, readme, description, main, dependencies, repo_url, items,
                               authors)
    assert(type(name) == "string", "Name must be a string")
    assert(type(Vendor) == "string" or Vendor == nil, "Vendor must be a string or nil")
    assert(type(version) == "string" or version == nil, "Version must be a string or nil")

    -- validate items
    if items then
        assert(type(items) == "table", "Items must be a table")
        for _, item in ipairs(items) do
            assert(type(item) == "table", "Each item must be a table")
            assert(type(item.meta) == "table", "Each item must have a meta table")
            assert(type(item.meta.name) == "string", "Each item.meta must have a name")
            assert(type(item.data) == "string", "Each item must have data string")
            -- verify if item.data is a working module
            local func, err = load(item.data)
            if not func then
                error("Error compiling item data: " .. err)
            end
        end
    end


    return {
        Name = name or "",
        Version = version or "1.0.0",
        Vendor = Vendor or "@apm",
        PackageData = {
            Readme = readme or "# New Package",
            Description = description or "",
            Main = main or "main.lua",
            Dependencies = dependencies or {},
            RepositoryUrl = repo_url or "",
            Items = items or {
                {
                    meta = { name = "main.lua" },
                    data = [[
                        local M = {}
                        function M.hello()
                            return "Hello from main.lua"
                        end
                        return M
                    ]]
                }
            },
            Authors = authors or {}
        }
    }
end

----------------------------------------

-- variant of the download response handler that supports assign()

function PublishAssignDownloadResponseHandler(msg)
    -- print(msg)
    local data = json.decode(msg.Data)
    print(data)
    local vendor = data.Vendor
    local version = data.Version
    local PkgData = data.PackageData
    -- local items = json.decode(base64.decode(data.Items))
    local items = PkgData.Items
    local name = data.Name
    if vendor ~= "@apm" then
        name = vendor .. "/" .. name
    end
    local main = PkgData.Main

    local main_src
    for _, item in ipairs(items) do
        -- item.data = base64.decode(item.data)
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
    print("📦 Package has been loaded, you can now import it using require function")
    APM.installed[name] = version
end

Handlers.add(
    "PublishAssignDownloadResponseHandler",
    Handlers.utils.hasMatchingTag("Action", "APM.Publish"),
    function(msg)
        print("Assignment ran")
        handle_run(PublishAssignDownloadResponseHandler, msg)
    end
)

----------------------------------------

function RegisterVendorResponseHandler(msg)
    print(msg.Data)
end

Handlers.add(
    "RegisterVendorResponse",
    Handlers.utils.hasMatchingTag("Action", "APM.RegisterVendorResponse"),
    function(msg)
        handle_run(RegisterVendorResponseHandler, msg)
    end
)
----------------------------------------

function PublishResponseHandler(msg)
    print(msg.Data)
end

Handlers.add(
    "PublishResponse",
    Handlers.utils.hasMatchingTag("Action", "APM.PublishResponse"),
    function(msg)
        handle_run(PublishResponseHandler, msg)
    end
)

----------------------------------------

function InfoResponseHandler(msg)
    print(msg.Data)
end

Handlers.add(
    "InfoResponse",
    Handlers.utils.hasMatchingTag("Action", "APM.InfoResponse"),
    function(msg)
        handle_run(InfoResponseHandler, msg)
    end
)

----------------------------------------

function SearchResponseHandler(msg)
    local data = json.decode(msg.Data)

    local p = "\n"
    for _, pkg in ipairs(data) do
        p = p .. pkg.Vendor .. "/" .. pkg.Name .. " - " .. pkg.Description .. "\n"
    end
    print(p)
end

Handlers.add(
    "SearchResponse",
    Handlers.utils.hasMatchingTag("Action", "APM.SearchResponse"),
    function(msg)
        handle_run(SearchResponseHandler, msg)
    end
)

----------------------------------------

function GetAllPackagesResponseHandler(msg)
    local data = json.decode(msg.Data)

    local p = "\n"
    for _, pkg in ipairs(data) do
        -- p = p .. pkg.Vendor .. "/" .. pkg.Name .. " - " .. (pkg.Description or pkg.Owner) .. "  " .. pkg.RepositoryUrl .. "\n"
        p = p .. pkg.Vendor .. "/" .. pkg.Name .. " - "
        if pkg.Description then
            p = p .. pkg.Description .. "  "
        else
            p = p .. pkg.Owner .. "  "
        end
        if pkg.RepositoryUrl then
            p = p .. pkg.RepositoryUrl .. "\n"
        else
            p = p .. "No Repo Url" .. "\n"
        end
    end
    print(p)
end

Handlers.add(
    "GetAllPackagesResponse",
    Handlers.utils.hasMatchingTag("Action", "APM.GetAllPackagesResponse"),
    function(msg)
        handle_run(GetAllPackagesResponseHandler, msg)
    end
)

----------------------------------------

APM = {}

APM.ID = "wvWJYLcPcAgSZ4DM2xZaeSAhDKVrJmUNULP54LrTk3Q"
APM.installed = {}

function APM.registerVendor(name)
    local data = json.encode({
        Name = name
    })
    Send({
        Target = APM.ID,
        Action = "APM.RegisterVendor",
        Data = data
    })
    return "📤 Vendor registration request sent"
end

function APM.publish(package_data)
    assert(type(package_data) == "table", "Package data must be a table")
    local data = json.encode(package_data)
    Send({
        Target = APM.ID,
        Action = "APM.Publish",
        Data = data
    })
    return "📤 Publish request sent"
end

function APM.list()
    Send({
        Target = APM.ID,
        Action = "APM.GetAllPackages"
    })
    return "📤 Fetching all packages"
end

function APM.search(query)
    assert(type(query) == "string", "Query must be a string")

    Send({
        Target = APM.ID,
        Action = "APM.Search",
        Data = query
    })

    return "📤 Searching for packages"
end

function APM.install(name, version)
    assert(type(name) == "string", "Name must be a string")
    if version then
        assert(type(version) == "string", "Version must be a string")
    end

    local vendor, package = name:match("@(%w+)/(%w+)")

    if vendor then
        vendor = "@" .. vendor
        name = package
    else
        vendor = "@apm"
    end

    if not version then
        version = "latest"
    end


    local data = {
        Vendor = vendor,
        Name = name,
        Version = version
    }

    Send({
        Target = APM.ID,
        Action = "APM.Download",
        Data = json.encode(data)
    })

    return "📤 Download request sent"
end

function APM.uninstall(name)
    assert(type(name) == "string", "Name must be a string")

    if not APM.installed[name] then
        return "❌ Package is not installed"
    end

    _G.package.loaded[name] = nil
    APM.installed[name] = nil

    return "📦 Package has been uninstalled"
end

return "📦 Loaded APM Client"
