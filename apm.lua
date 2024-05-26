json = require("json")
base64 = require(".base64")
sqlite3 = require("lsqlite3")
db = db or sqlite3.open_memory()

db:exec([[
    -- CREATE TABLE IF NOT EXISTS Versions (
    --     ID INTEGER PRIMARY KEY AUTOINCREMENT,
    --     Name TEXT NOT NULL,
    --     Version TEXT NOT NULL
    -- );
    CREATE TABLE IF NOT EXISTS Packages (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Name TEXT NOT NULL,
        Version TEXT NOT NULL,
        Vendor TEXT DEFAULT "apm",
        Owner TEXT NOT NULL,
        README TEXT NOT NULL,
        PkgID TEXT NOT NULL,
        Items TEXT NOT NULL,
        Authors_ TEXT NOT NULL,
        Dependencies TEXT NOT NULL,
        Main TEXT NOT NULL,
        Description TEXT NOT NULL,
        RepositoryUrl TEXT NOT NULL,
        Updated INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS Vendors (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Name TEXT NOT NULL,
        Owner TEXT NOT NULL
    );
]])


function isValidVersion(variant)
    return variant:match("^%d+%.%d+%.%d+$")
end

function isValidPackageName(name)
    return name:match("^%w+$")
end

function isValidOrganization(name)
    return name:match("^@%w+$")
end

-- common error handler
function handle_run(func, msg)
    local ok, err = pcall(func, msg)
    if not ok then
        local clean_err = err:match(":%d+: (.+)") or err
        print(msg.Action .. " - " .. err)
        Handlers.utils.reply(clean_err)(msg)
    end
end

-- easier query exec
function sql_run(query)
    local m = {}
    for row in db:nrows(query) do
        table.insert(m, row)
    end
    return m
end

function generate_package(name, organization, version, readme, description, main, dependencies, repo_url, items, authors)
    return {
        Name = name or "",
        Version = version or "1.0.0",
        Organization = organization or "@apm",
        PackageData = {
            Readme = readme or "# New Package",
            Description = description or "",
            Main = main or "main.lua",
            Dependencies = dependencies or {},
            RepositoryUrl = repo_url or "",
            Items = items or {
                {
                    meta = { name = "main.lua" },
                    data = [[--add source here]]
                }
            },
            Authors = authors or {}
        }
    }
end

function RegisterVendor(msg)
    local data = json.decode(msg.Data)
    local name = data.Name
    local owner = msg.From

    assert(name, "❌ Vendor name is required")
    assert(isValidOrganization(name), "❌ Invalid organization name, must be in the format @organization")
    assert(name ~= "@apm", "❌ @apm can't be registered")

    for row in db:nrows(string.format([[
        SELECT * FROM Vendors WHERE Name = "%s"
        ]], name)) do
        assert(nil, "❌ " .. name .. " already exists")
    end

    print("ℹ️ register requested for: " .. name .. " by " .. owner)

    db:exec(string.format([[
        INSERT INTO Vendors (Name, Owner) VALUES ("%s", '%s')
    ]], name, owner))

    Handlers.utils.reply("🎉 " .. name .. " registered")(msg)
end

Handlers.add(
    "RegisterVendor",
    Handlers.utils.hasMatchingTag("Action", "RegisterVendor"),
    function(msg)
        handle_run(RegisterVendor, msg)
    end
)


function Publish(msg)
    local data = json.decode(msg.Data)
    local name = data.Name
    local version = data.Version
    local org = data.Organization or "@apm"
    local package_data = data.PackageData
    local owner = msg.From

    assert(name, "❌ Package name is required")
    assert(version, "❌ Package version is required")
    assert(package_data, "❌ PackageData is required")


    assert(package_data.Readme, "❌ Readme is required in PackageData")
    assert(package_data.RepositoryUrl, "❌ RepositoryUrl is required in PackageData")
    assert(package_data.Items, "❌ Items is required in PackageData")
    assert(package_data.Description, "❌ Description is required in PackageData")
    assert(package_data.Authors, "❌ Authors is required in PackageData")
    assert(package_data.Dependencies, "❌ Dependencies is required in PackageData")
    assert(package_data.Main, "❌ Main is required in PackageData")

    -- check validity of Items
    for _, item in ipairs(package_data.Items) do
        assert(item.meta, "❌ meta is required in Items")
        assert(item.data, "❌ data is required in Items")
        for key, value in pairs(item.meta) do
            assert(type(key) == "string", "❌ meta key must be a string")
            assert(type(value) == "string", "❌ meta value must be a string")
        end
        assert(type(item.data) == "string", "❌ data must be a string")
        item.data = base64.encode(item.data)
    end
    package_data.Items = base64.encode(json.encode(package_data.Items))
    -- Items is valid

    -- check validity of Dependencies
    assert(type(package_data.Dependencies) == "table", "❌ Dependencies must be a table of strings")
    for _, dependency in ipairs(package_data.Dependencies) do
        assert(type(dependency) == "string", "❌ dependency must be a string")
    end
    package_data.Dependencies = json.encode(package_data.Dependencies)
    -- Dependencies is valid

    -- check validity of Authors
    assert(type(package_data.Authors) == "table", "❌ Authors must be a table of strings")
    for _, author in ipairs(package_data.Authors) do
        assert(type(author) == "string", "❌ author must be a string")
    end
    package_data.Authors = json.encode(package_data.Authors)
    -- Authors is valid


    assert(name, "Package name is required")
    assert(isValidPackageName(name), "Invalid package name, only alphanumeric characters are allowed")
    assert(version, "Package version is required")
    assert(isValidVersion(version), "Invalid package version, must be in the format major.minor.patch")
    assert(org, "Organization is required")
    assert(isValidOrganization(org), "Invalid organization name, must be in the format @organization")

    if org ~= "@apm" then
        local rows = {}
        for row in db:nrows(string.format([[
            SELECT * FROM Vendors WHERE Name = "%s"
            ]], org)) do
            table.insert(rows, row)
            assert(row.Owner == owner, "❌ You are not the owner of " .. org)
        end
        assert(#rows >= 0, "❌ " .. org .. " does not exist")
    end

    local existing = {}
    for row in db:nrows(string.format([[
        SELECT * FROM Packages WHERE Name = "%s" AND Version = "%s" AND Vendor = "%s"
        ]], name, version, org)) do
        table.insert(existing, row)
    end

    assert(#existing == 0, "❌ " .. org .. "/" .. name .. "@" .. version .. " already exists")

    local db_res = db:exec(string.format([[
        INSERT INTO Packages (
            Name, Version, Vendor, Owner, README, PkgID, Items, Authors_, Dependencies, Main, Description, RepositoryUrl, Updated
        ) VALUES (
            "%s", "%s", "%s", '%s', "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", %s
        );
    ]], name, version, org, owner, package_data.Readme, msg.Id, package_data.Items, package_data.Authors,
        package_data.Dependencies, package_data.Main, package_data.Description, package_data.RepositoryUrl, os.time()))

    assert(db_res == 0, "❌ " .. db:errmsg())

    print("ℹ️ publish requested for: " .. org .. "/" .. name .. "@" .. version .. " by " .. owner)
    Handlers.utils.reply("🎉 " .. name .. "@" .. version .. " published")(msg)
end

Handlers.add(
    "Publish",
    Handlers.utils.hasMatchingTag("Action", "Publish"),
    function(msg)
        handle_run(Publish, msg)
    end
)

function Info(msg)
    local data = json.decode(msg.Data)
    local name = data.Name
    local version = data.Version or "latest"

    assert(name, "Package name is required")
    assert(isValidPackageName(name), "Invalid package name, only alphanumeric characters are allowed")
    if version ~= "latest" then
        assert(isValidVersion(version), "Invalid package version, must be in the format major.minor.patch")
    end

    local package
    if version == "latest" then
        package = sql_run(string.format([[
            SELECT * FROM Packages WHERE Name = "%s" ORDER BY Version DESC LIMIT 1
        ]], name))
    else
        package = sql_run(string.format([[
            SELECT * FROM Packages WHERE Name = "%s" AND Version = "%s"
        ]], name, version))
    end

    assert(#package > 0, "❌ " .. name .. "@" .. version .. " not found")

    Handlers.utils.reply(json.encode(package[1]))(msg)
end

Handlers.add(
    "Info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        handle_run(Info, msg)
    end
)

function GetAllPackages(msg)
    local packages = sql_run([[
        SELECT DISTINCT Name, Vendor, RepositoryUrl, Description FROM Packages
    ]])
    Handlers.utils.reply(json.encode(packages))(msg)
end

Handlers.add(
    "GetAllPackages",
    Handlers.utils.hasMatchingTag("Action", "GetAllPackages"),
    function(msg)
        handle_run(GetAllPackages, msg)
    end
)

function Download(msg)
    local data = json.decode(msg.Data)
    local name = data.Name
    local version = data.Version or "latest"
    local org = data.Organization or "@apm"

    assert(name, "❌ Package name is required")

    local res
    if version == "latest" then
        res = sql_run(string.format([[
            SELECT * FROM Packages WHERE Name = "%s" AND Vendor = "%s" ORDER BY Version DESC LIMIT 1
        ]], name, org))
    else
        res = sql_run(string.format([[
            SELECT * FROM Packages WHERE Name = "%s" AND Version = "%s" AND Vendor = "%s"
        ]], name, version, org))
    end

    assert(#res > 0, "❌ " .. org .. "/" .. name .. "@" .. version .. " not found")

    print("ℹ️ Download request for " .. org .. "/" .. name .. "@" .. version .. " from " .. msg.From)

    ao.send({
        Target = msg.From,
        Action = "DownloadResponse",
        Data = json.encode(res[1])
    })
end

Handlers.add(
    "Download",
    Handlers.utils.hasMatchingTag("Action", "Download"),
    function(msg)
        handle_run(Download, msg)
    end
)

function ListPackages()
    local p_str = "\n"
    local p = sql_run([[SELECT Vendor,Name,Version,Owner FROM Packages]])
    for _, pkg in ipairs(p) do
        p_str = p_str .. pkg.Vendor .. "/" .. pkg.Name .. "@" .. pkg.Version .. " - " .. pkg.Owner .. "\n"
    end
    return p_str
end
