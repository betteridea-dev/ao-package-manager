json = require("json")
base64 = require(".base64")
sqlite3 = require("lsqlite3")
db = db or sqlite3.open_memory()

------------------------------------------------------

db:exec([[
    CREATE TABLE IF NOT EXISTS Packages (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Name TEXT NOT NULL,
        Version TEXT NOT NULL,
        Vendor TEXT DEFAULT "@apm",
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

------------------------------------------------------

function isValidVersion(variant)
    return variant:match("^%d+%.%d+%.%d+$")
end

function isValidPackageName(name)
    return name:match("^%w+$")
end

function isValidVendor(name)
    return name:match("^@%w+$")
end

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

-- easier query exec
function sql_run(query)
    local m = {}
    for row in db:nrows(query) do
        table.insert(m, row)
    end
    return m
end

function ListPackages()
    local p_str = "\n"
    local p = sql_run([[WITH UniqueNames AS (
    SELECT
        Name,
        MAX(Vendor) AS Vendor,
        MAX(Version) AS Version,
        MAX(Owner) AS Owner
    FROM
        Packages
    GROUP BY
        Name
)
SELECT
    Vendor,
    Name,
    Version,
    Owner
FROM
    UniqueNames;]])

    if #p == 0 then
        return "No packages found"
    end

    for _, pkg in ipairs(p) do
        p_str = p_str .. pkg.Vendor .. "/" .. pkg.Name .. "@" .. pkg.Version .. " - " .. pkg.Owner .. "\n"
    end
    return p_str
end

------------------------------------------------------

function RegisterVendor(msg)
    local data = json.decode(msg.Data)
    local name = data.Name
    local owner = msg.From

    assert(name, "❌ vendor name is required")
    assert(isValidVendor(name), "❌ Invalid vendor name, must be in the format @vendor")
    assert(name ~= "@apm", "❌ @apm can't be registered as vendor")

    for row in db:nrows(string.format([[
        SELECT * FROM Vendors WHERE Name = "%s"
        ]], name)) do
        assert(nil, "❌ " .. name .. " already exists")
    end

    print("ℹ️ register requested for: " .. name .. " by " .. owner)

    db:exec(string.format([[
        INSERT INTO Vendors (Name, Owner) VALUES ("%s", '%s')
    ]], name, owner))

    -- Handlers.utils.reply("🎉 " .. name .. " registered")(msg)
    ao.send({
        Target = msg.From,
        Action = "RegisterVendorResponse",
        Data = "🎉 " .. name .. " registered"
    })
end

Handlers.add(
    "RegisterVendor",
    Handlers.utils.hasMatchingTag("Action", "RegisterVendor"),
    function(msg)
        handle_run(RegisterVendor, msg)
    end
)

------------------------------------------------------

function Publish(msg)
    local data = json.decode(msg.Data)
    local name = data.Name
    local version = data.Version
    local vendor = data.Vendor or "@apm"
    local package_data = data.PackageData
    local owner = msg.From

    -- Prevent publishing on registry process coz assignments have the Tag Action:Publish, which could cause a race condition?
    if ao.id == msg.From then
        error("❌ Registry cannot publish packages to itself")
    end

    assert(type(name) == "string", "❌ Package name is required")
    assert(type(version) == "string", "❌ Package version is required")
    assert(type(vendor) == "string", "❌ vendor is required")
    assert(type(package_data) == "table", "❌ PackageData is required")

    assert(isValidPackageName(name), "Invalid package name, only alphanumeric characters are allowed")
    assert(isValidVersion(version), "Invalid package version, must be in the format major.minor.patch")
    assert(isValidVendor(vendor), "Invalid vendor name, must be in the format @vendor")

    assert(type(package_data.Readme) == "string", "❌ Readme(string) is required in PackageData")
    assert(type(package_data.RepositoryUrl) == "string", "❌ RepositoryUrl(string) is required in PackageData")
    assert(type(package_data.Items) == "table", "❌ Items(table) is required in PackageData")
    assert(type(package_data.Description) == "string", "❌ Description(string) is required in PackageData")
    assert(type(package_data.Authors) == "table", "❌ Authors(table) is required in PackageData")
    assert(type(package_data.Dependencies) == "table", "❌ Dependencies(table) is required in PackageData")
    assert(type(package_data.Main) == "string", "❌ Main(string) is required in PackageData")

    print(vendor)
    -- if the package was published before, check the owner
    local existing = sql_run(string.format([[
        SELECT * FROM Packages WHERE Name = "%s" AND Vendor = "%s" ORDER BY Version DESC LIMIT 1
    ]], name, version, vendor))
    if #existing > 0 then
        assert(existing[1].Owner == owner,
            "❌ You are not the owner of previously published " .. vendor .. "/" .. name .. "@" .. version)
    end

    -- check validity of Items
    for _, item in ipairs(package_data.Items) do
        assert(type(item.meta) == "table", "❌ meta(table) is required in Items")
        assert(type(item.data) == "string", "❌ data(string) is required in Items")
        for key, value in pairs(item.meta) do
            assert(type(key) == "string", "❌ meta key must be a string")
            assert(type(value) == "string", "❌ meta value must be a string")
        end
        item.data = base64.encode(item.data)
    end
    package_data.Items = base64.encode(json.encode(package_data.Items))
    -- Items is valid

    -- check validity of Dependencies
    for _, dependency in ipairs(package_data.Dependencies) do
        assert(type(dependency) == "string", "❌ dependency must be a string")
    end
    package_data.Dependencies = json.encode(package_data.Dependencies)
    -- Dependencies is valid

    -- check validity of Authors
    for _, author in ipairs(package_data.Authors) do
        assert(type(author) == "string", "❌ author must be a string")
    end
    package_data.Authors = json.encode(package_data.Authors)
    -- Authors is valid

    if vendor ~= "@apm" then
        local v = sql_run(string.format([[
            SELECT * FROM Vendors WHERE Name = "%s"
        ]], vendor))
        assert(#v > 0, "❌ " .. vendor .. " does not exist")
        assert(v[1].Owner == owner, "❌ You are not the owner of " .. vendor)
    end

    -- check if the package already exists with same version
    local existing = sql_run(string.format([[
        SELECT * FROM Packages WHERE Name = "%s" AND Version = "%s" AND Vendor = "%s"
    ]], name, version, vendor))
    assert(#existing == 0, "❌ " .. vendor .. "/" .. name .. "@" .. version .. " already exists")

    -- insert the package
    local db_res = db:exec(string.format([[
        INSERT INTO Packages (
            Name, Version, Vendor, Owner, README, PkgID, Items, Authors_, Dependencies, Main, Description, RepositoryUrl, Updated
        ) VALUES (
            "%s", "%s", "%s", '%s', "%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s", %s
        );
    ]], name, version, vendor, owner, package_data.Readme, msg.Id, package_data.Items, package_data.Authors,
        package_data.Dependencies, package_data.Main, package_data.Description, package_data.RepositoryUrl, os.time()))

    assert(db_res == 0, "❌ " .. db:errmsg())

    print("ℹ️ publish requested for: " .. vendor .. "/" .. name .. "@" .. version .. " by " .. owner)
    -- Handlers.utils.reply("🎉 " .. name .. "@" .. version .. " published")(msg)
    ao.send({
        Target = msg.From,
        Action = "PublishResponse",
        Data = "🎉 " .. vendor .. "/" .. name .. "@" .. version .. " published"
    })
end

Handlers.add(
    "Publish",
    Handlers.utils.hasMatchingTag("Action", "Publish"),
    function(msg)
        handle_run(Publish, msg)
    end
)

------------------------------------------------------

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

    -- Handlers.utils.reply(json.encode(package[1]))(msg)
    ao.send({
        Target = msg.From,
        Action = "InfoResponse",
        Data = json.encode(package[1])
    })
end

Handlers.add(
    "Info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    function(msg)
        handle_run(Info, msg)
    end
)

------------------------------------------------------

function GetAllPackages(msg)
    local packages = sql_run([[
        WITH UniqueNames AS (
    SELECT
        Name,
        MIN(Vendor) AS Vendor,
        MAX(Version) AS Version,
        MIN(Owner) AS Owner
    FROM
        Packages
    GROUP BY
        Name
)
SELECT
    Vendor,
    Name,
    Version,
    Owner
FROM
    UniqueNames;
    ]])
    print(packages)
    -- Handlers.utils.reply(json.encode(packages))(msg)
    ao.send({
        Target = msg.From,
        Action = "GetAllPackagesResponse",
        Data = json.encode(packages)
    })
end

Handlers.add(
    "GetAllPackages",
    Handlers.utils.hasMatchingTag("Action", "GetAllPackages"),
    function(msg)
        handle_run(GetAllPackages, msg)
    end
)

------------------------------------------------------

function Download(msg)
    local data = json.decode(msg.Data)
    local name = data.Name
    local version = data.Version or "latest"
    local vendor = data.Vendor or "@apm"

    -- Prevent installation on registry process coz assignments have the Tag Action:Publish, which could cause a race condition?
    if msg.From == ao.id then
        error("❌ Cannot install pacakges on the registry process")
    end

    assert(name, "❌ Package name is required")

    local res
    if version == "latest" then
        res = sql_run(string.format([[
            SELECT * FROM Packages WHERE Name = "%s" AND Vendor = "%s" ORDER BY Version DESC LIMIT 1
        ]], name, vendor))
    else
        res = sql_run(string.format([[
            SELECT * FROM Packages WHERE Name = "%s" AND Version = "%s" AND Vendor = "%s"
        ]], name, version, vendor))
    end

    assert(#res > 0, "❌ " .. vendor .. "/" .. name .. "@" .. version .. " not found")


    Assign({
        Processes = { msg.From },
        Message = res[1].PkgID
    })

    print("ℹ️ Download request for " .. vendor .. "/" .. name .. "@" .. version .. " from " .. msg.From)
    -- ao.send({
    --     Target = msg.From,
    --     Action = "DownloadResponse",
    --     Data = json.encode(res[1])
    -- })
end

Handlers.add(
    "Download",
    Handlers.utils.hasMatchingTag("Action", "Download"),
    function(msg)
        handle_run(Download, msg)
    end
)

------------------------------------------------------

function Transfer(msg)
    local data = json.decode(msg.Data)
    local name = data.Name
    local vendor = data.Vendor or "@apm"
    local new_owner = msg.To

    assert(name, "❌ Package name is required")
    assert(new_owner, "❌ New owner is required")

    local res = sql_run(string.format([[
        SELECT * FROM Packages WHERE Name = "%s" AND Vendor = "%s" ORDER BY Version DESC LIMIT 1
    ]], name, vendor))

    assert(#res > 0, "❌ " .. vendor .. "/" .. name .. " not found")

    -- user should be either the owner of the package or the vendor
    assert(res[1].Owner == msg.From or res[1].Vendor == msg.From, "❌ You are not the owner of " .. vendor .. "/" .. name)

    -- Update owner of the latest version of the package
    db:exec(string.format([[
        UPDATE Packages SET Owner = '%s' WHERE Name = "%s" AND Vendor = "%s" AND Version = "%s"
    ]], new_owner, name, vendor, res[1].Version))

    print("ℹ️ Transfer requested for " .. vendor .. "/" .. name .. " to " .. new_owner)
    -- Handlers.utils.reply("🎉 " .. vendor .. "/" .. name .. " transferred to " .. new_owner)(msg)
    ao.send({
        Target = msg.From,
        Action = "TransferResponse",
        Data = "🎉 " .. vendor .. "/" .. name .. " transferred to " .. new_owner
    })
end

Handlers.add(
    "Transfer",
    Handlers.utils.hasMatchingTag("Action", "Transfer"),
    function(msg)
        handle_run(Transfer, msg)
    end
)

------------------------------------------------------


function Search(msg)
    local query = msg.Data

    assert(type(query) == "string", "❌ Search query is required in Data")

    local packages = sql_run(string.format([[
        SELECT DISTINCT Name, Vendor, Description FROM Packages WHERE Name LIKE "%%%s%%"
    ]], query))

    -- Handlers.utils.reply(json.encode(packages))(msg)
    ao.send({
        Target = msg.From,
        Action = "SearchResponse",
        Data = json.encode(packages)
    })
end

Handlers.add(
    "Search",
    Handlers.utils.hasMatchingTag("Action", "Search"),
    function(msg)
        handle_run(Search, msg)
    end
)

------------------------------------------------------

return "📦 Loaded APM"
