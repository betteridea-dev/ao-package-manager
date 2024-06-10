json = require("json")
base64 = require(".base64")
sqlite3 = require("lsqlite3")
bint = require('.bint')(256)

db = db or sqlite3.open_memory()

local utils = {
    add = function(a, b)
        return tostring(bint(a) + bint(b))
    end,
    subtract = function(a, b)
        return tostring(bint(a) - bint(b))
    end,
    toBalanceValue = function(a)
        return tostring(bint(a))
    end,
    toNumber = function(a)
        return tonumber(a)
    end
}

------------------------------------------------------ 101000000.0000000000
-- Load the token blueprint after apm.lua
Denomination = 10
Balances = Balances or { [ao.id] = utils.toBalanceValue(101000000 * 10 ^ Denomination) }
TotalSupply = TotalSupply or utils.toBalanceValue(101000000 * 10 ^ Denomination)
Name = "Test NEO"
Ticker = 'TNEO'
Logo = 'zExoVE0178jbyUg2MP-cK6SbBRFiNDynB5FRqeD0yJc'

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
        Items VARCHAR NOT NULL,
        Authors_ TEXT NOT NULL,
        Dependencies TEXT NOT NULL,
        Main TEXT NOT NULL,
        Description TEXT NOT NULL,
        RepositoryUrl TEXT NOT NULL,
        Updated INTEGER NOT NULL,
        Installs INTEGER DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS Vendors (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Name TEXT NOT NULL,
        Owner TEXT NOT NULL
    );
    -- TODO:
    CREATE TABLE IF NOT EXISTS Latest10 (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        PkgID TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS Featured (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        PkgID TEXT NOT NULL
    );
]])

------------------------------------------------------

function hexencode(str)
    return (str:gsub(".", function(char) return string.format("%02x", char:byte()) end))
end

function hexdecode(hex)
    return (hex:gsub("%x%x", function(digits) return string.char(tonumber(digits, 16)) end))
end

function isValidVersion(variant)
    return variant:match("^%d+%.%d+%.%d+$")
end

function isValidPackageName(name)
    return name:match("^[a-zA-Z0-9%-_]+$")
end

function isValidVendor(name)
    return name:match("^@%w+$")
end

function split_package_name(query)
    local vendor, pkgname, version

    -- if only vendor is given
    if query:find("^@%w+$") then
        return query, nil, nil
    end

    -- check if version is provided
    local version_index = query:find("@%d+.%d+.%d+$")
    if version_index then
        version = query:sub(version_index + 1)
        query = query:sub(1, version_index - 1)
    end

    -- check if vendor is provided
    vendor, pkgname = query:match("@(%w+)/([%w%-%_]+)")

    if not vendor then
        pkgname = query
    else
        vendor = "@" .. vendor
    end

    return vendor, pkgname, version
end

-- common error handler
function handle_run(func, msg)
    local ok, err = pcall(func, msg)
    if not ok then
        local clean_err = err:match(":%d+: (.+)") or err
        print(msg.Action .. " - " .. err)
        if not msg.Target == ao.id then
            ao.send({
                Target = msg.From,
                Data = clean_err,
                Result = "error"
            })
        end
    end
end

-- easily read from the database
function sql_run(query, ...)
    local m = {}
    local stmt = db:prepare(query)
    if stmt then
        local bind_res = stmt:bind_values(...)
        assert(bind_res, "❌[bind error] " .. db:errmsg())
        for row in stmt:nrows() do
            table.insert(m, row)
        end
        stmt:finalize()
    end
    return m
end

-- easily write to the database
function sql_write(query, ...)
    local stmt = db:prepare(query)
    if stmt then
        local bind_res = stmt:bind_values(...)
        assert(bind_res, "❌[bind error] " .. db:errmsg())
        local step = stmt:step()
        assert(step == sqlite3.DONE, "❌[write error] " .. db:errmsg())
        stmt:finalize()
    end
    return db:changes()
end

-- function to list all published packages
function ListPackages()
    local p_str = "\n"
    local p = sql_run([[WITH UniqueNames AS (
    SELECT
        MAX(Version) AS Version, *
    FROM
        Packages
    GROUP BY
        Name
)
SELECT
    Vendor,
    Name,
    Version,
    Owner,
    RepositoryUrl,
    Description,
    Installs,
    PkgID
FROM
    UniqueNames;]])

    if #p == 0 then
        return "No packages found"
    end

    for _, pkg in ipairs(p) do
        p_str = p_str ..
            pkg.Vendor ..
            "/" ..
            pkg.Name ..
            "@" ..
            pkg.Version ..
            " | " ..
            (pkg.Description or "no description") ..
            " | " ..
            pkg.Installs .. " installs" ..
            " | " ..
            (pkg.RepositoryUrl or "no url") ..
            "\n"
    end
    return p_str
end

-- Function to get latest apm client version
function GetLatestClientVersion()
    local version = sql_run(
        [[SELECT Version FROM Packages WHERE Name = "apm" AND Vendor = "@apm" ORDER BY Version DESC LIMIT 1]])
    if #version == 0 then
        return nil
    end
    return version[1].Version
end

-- Checker function to be added in every action to check for updates
function CheckForAvailableUpdate(msg)
    local client_version = msg.Version
    local latest_version
    if client_version then
        latest_version = GetLatestClientVersion()
    end
    if client_version and latest_version and client_version ~= latest_version then
        ao.send({
            Target = msg.From,
            Action = "APM.UpdateNotice",
            Data = string.format(
                Colors.red ..
                "📦 An APM client update %s -> %s is available. It is recommended to run APM.update()" .. Colors.reset,
                client_version, latest_version)
        })
    end
end

------------------------------------------------------

function RegisterVendor(msg)
    local cost = utils.toBalanceValue(10 * 10 ^ Denomination)
    local name = msg.Data
    local owner = msg.From

    assert(type(msg.Quantity) == 'string', 'Quantity is required!')
    assert(bint(msg.Quantity) <= bint(Balances[msg.From]), 'Quantity must be less than or equal to the current balance!')
    assert(msg.Quantity == cost, "10 NEO must be burnt to registering a new vendor")


    assert(name, "❌ vendor name is required")
    assert(isValidVendor(name), "❌ Invalid vendor name, must be in the format @vendor")
    assert(name ~= "@apm", "❌ @apm can't be registered as vendor")
    assert(name ~= "@registry", "❌ @registry can't be registered as vendor")
    -- size 3 to 20
    assert(#name > 3 and #name <= 20, "❌ Vendor name must be between 3 and 20 characters")

    -- check if vendor already exists
    for row in sql_run([[SELECT * FROM Vendors WHERE Name = ?]], name) do
        assert(nil, "❌ " .. name .. " already exists")
    end

    -- save vendor details
    local write_res = sql_write([[INSERT INTO Vendors (Name, Owner) VALUES (?, ?)]], name, owner)
    assert(write_res == 1, "❌[insert error] " .. db:errmsg())

    Balances[msg.From] = utils.subtract(Balances[msg.From], msg.Quantity)
    TotalSupply = utils.subtract(TotalSupply, msg.Quantity)

    print("APM>>> registerd vendor: " .. name .. " by " .. owner)

    ao.send({
        Target = msg.From,
        Data = "Successfully burned 10 $" .. Ticker
    })
    ao.send({
        Target = msg.From,
        Action = "APM.RegisterVendorResponse",
        Result = "success",
        Data = "🎉 " .. name .. " registered"
    })
    CheckForAvailableUpdate(msg)
end

Handlers.add(
    "APM.RegisterVendor",
    Handlers.utils.hasMatchingTag("Action", "APM.RegisterVendor"),
    function(msg)
        handle_run(RegisterVendor, msg)
    end
)

------------------------------------------------------

function Publish(msg)
    local cost_new = utils.toBalanceValue(10 * 10 ^ Denomination)
    local cost_update = utils.toBalanceValue(1 * 10 ^ Denomination)
    local data = json.decode(msg.Data)
    local name = data.Name
    local version = data.Version
    local vendor = data.Vendor or "@apm"
    local package_data = data.PackageData
    local owner = msg.From

    -- Prevent publishing from registry process coz assignments have the Tag Action:Publish, which could cause a race condition?
    if ao.id == msg.From then
        error("❌ Registry cannot publish packages to itself")
    end

    assert(type(msg.Quantity) == 'string', 'Quantity is required!')
    assert(Balances[msg.From], "❌ You don't have any $NEO balance")
    assert(bint(msg.Quantity) <= bint(Balances[msg.From]), 'Quantity must be less than or equal to the current balance!')


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

    package_data.Readme = hexencode(package_data.Readme)

    local existing = sql_run([[SELECT * FROM Packages WHERE Name = ? AND Vendor = ? ORDER BY Version DESC LIMIT 1]], name,
        vendor)

    if #existing > 0 then
        assert(existing[1].Owner == owner,
            "❌ You are not the owner of previously published " .. vendor .. "/" .. name .. "@" .. version)
        assert(msg.Quantity == cost_update,
            "1 $NEO must be burnt to update an existing package. You sent: " ..
            tostring(bint(msg.Quantity) / 10 ^ Denomination))
    else
        assert(
            msg.Quantity == cost_new,
            "10 $NEO must be burnt to publish a new package. You sent: " .. tostring(bint(msg.Quantity) / 10 ^
                Denomination)
        )
    end

    -- check validity of Items
    for _, item in ipairs(package_data.Items) do
        assert(type(item.meta) == "table", "❌ meta(table) is required in Items")
        assert(type(item.data) == "string", "❌ data(string) is required in Items")
        for key, value in pairs(item.meta) do
            assert(type(key) == "string", "❌ meta key must be a string")
            assert(type(value) == "string", "❌ meta value must be a string")
        end
    end
    package_data.Items = hexencode(json.encode(package_data.Items))

    -- check validity of Dependencies
    for _, dependency in ipairs(package_data.Dependencies) do
        assert(type(dependency) == "string", "❌ dependency must be a string")
    end
    package_data.Dependencies = json.encode(package_data.Dependencies)


    -- check validity of Authors
    for _, author in ipairs(package_data.Authors) do
        assert(type(author) == "string", "❌ author must be a string")
    end
    package_data.Authors = json.encode(package_data.Authors)

    if vendor ~= "@apm" then
        local v = sql_run([[SELECT * FROM Vendors WHERE Name = ?]], vendor)
        assert(#v > 0, "❌ " .. vendor .. " does not exist")
        assert(v[1].Owner == owner, "❌ You are not the owner of " .. vendor)
    end

    -- check if the package already exists with same version
    local existing = sql_run([[SELECT * FROM Packages WHERE Name = ? AND Version = ? AND Vendor = ?]], name, version,
        vendor)
    assert(#existing == 0, "❌ " .. vendor .. "/" .. name .. "@" .. version .. " already exists")

    -- insert the package
    local db_res = sql_write([[
        INSERT INTO Packages (
            Name, Version, Vendor, Owner, README, PkgID, Items, Authors_, Dependencies, Main, Description, RepositoryUrl, Updated
        ) VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        );
    ]], name, version, vendor, owner, package_data.Readme, msg.Id, package_data.Items, package_data.Authors,
        package_data.Dependencies, package_data.Main, package_data.Description, package_data.RepositoryUrl, msg
        .Timestamp)

    assert(db_res == 1, "❌[insert error] " .. db:errmsg())

    Balances[msg.From] = utils.subtract(Balances[msg.From], msg.Quantity)
    TotalSupply = utils.subtract(TotalSupply, msg.Quantity)

    print("APM>>> new package: " .. vendor .. "/" .. name .. "@" .. version .. " by " .. owner)

    ao.send({
        Target = msg.From,
        Data = "Successfully burned " .. msg.Quantity
    })
    ao.send({
        Target = msg.From,
        Action = "APM.PublishResponse",
        Result = "success",
        Data = "🎉 " .. vendor .. "/" .. name .. "@" .. version .. " published"
    })
    CheckForAvailableUpdate(msg)
end

Handlers.add(
    "APM.Publish",
    Handlers.utils.hasMatchingTag("Action", "APM.Publish"),
    function(msg)
        handle_run(Publish, msg)
    end
)

------------------------------------------------------

function Info(msg)
    local name = msg.Data

    local vendor, pkg_name, version = split_package_name(name)

    local is_package_id = #name == 43

    -- if pkgID is sent in data, ignore everything else and get package info
    if is_package_id then
        local package = sql_run([[SELECT * FROM Packages WHERE PkgID = ?]], name)
        assert(#package > 0, "❌ Package not found")

        -- Get available package versions
        local versions = sql_run([[SELECT Version, PkgID, Installs FROM Packages WHERE Name = ? AND Vendor = ?]],
            package[1].Name, package[1].Vendor)
        package[1].Versions = versions

        print("APM>>> info request for " .. package[1].Vendor .. "/" .. package[1].Name .. "@" .. package[1].Version ..
            " by " .. msg.From)
        ao.send({
            Target = msg.From,
            Action = "APM.InfoResponse",
            Status = "success",
            Data = json.encode(package[1])
        })
        CheckForAvailableUpdate(msg)
        return
    end


    assert(pkg_name, "Package name is required")
    assert(isValidPackageName(pkg_name), "Invalid package name, only alphanumeric characters are allowed")
    assert(isValidVendor(vendor), "Invalid vendor name, must be in the format @vendor")

    if not version then version = "latest" end
    if version ~= "latest" then
        assert(isValidVersion(version), "Invalid package version, must be in the format major.minor.patch")
    end

    local package
    if version == "latest" then
        package = sql_run([[SELECT * FROM Packages WHERE Name = ? AND Vendor = ? ORDER BY Version DESC LIMIT 1]],
            pkg_name,
            vendor)
    else
        package = sql_run([[SELECT * FROM Packages WHERE Name = ? AND Vendor = ? AND Version = ?]], pkg_name, vendor,
            version)
    end

    assert(#package > 0, "❌ @" .. vendor .. "/" .. pkg_name .. "@" .. version .. " not found")

    local versions = sql_run([[SELECT Version, PkgID, Installs FROM Packages WHERE Name = ? AND Vendor = ?]], pkg_name,
        vendor)
    package[1].Versions = versions

    print("APM>>> info request for " .. vendor .. "/" .. pkg_name .. "@" .. version .. " by " .. msg.From)

    ao.send({
        Target = msg.From,
        Action = "APM.InfoResponse",
        Data = json.encode(package[1])
    })
    CheckForAvailableUpdate(msg)
end

Handlers.add(
    "APM.Info",
    Handlers.utils.hasMatchingTag("Action", "APM.Info"),
    function(msg)
        handle_run(Info, msg)
    end
)

------------------------------------------------------

-- returns top 50 downloaded
function GetPopular(msg)
    local packages = sql_run([[
        WITH UniqueNames AS (
    SELECT
        MAX(Version) AS Version, *
    FROM
        Packages
    GROUP BY
        Name
    ORDER BY
        Installs DESC
    LIMIT 50
)
SELECT
    Vendor,
    Name,
    Version,
    Owner,
    RepositoryUrl,
    Description,
    Installs,
    Updated,
    PkgID
FROM
    UniqueNames;
    ]])
    print("APM>>> get popular request by " .. msg.From .. " found " .. #packages .. " packages")
    ao.send({
        Target = msg.From,
        Action = "APM.GetPopularResponse",
        Data = json.encode(packages)
    })
    CheckForAvailableUpdate(msg)
end

Handlers.add(
    "APM.GetPopular",
    Handlers.utils.hasMatchingTag("Action", "APM.GetPopular"),
    function(msg)
        handle_run(GetPopular, msg)
    end
)

------------------------------------------------------

function Download(msg)
    local vendor, name, version = split_package_name(msg.Data)
    if not version then version = "latest" end
    if not vendor then vendor = "@apm" end

    -- Prevent installation on registry process coz assignments have the Tag Action:Publish, which could cause a race condition?
    if msg.From == ao.id then
        error("❌ Cannot install pacakges on the registry process")
    end

    assert(name, "❌ Package name is required")

    local res
    if version == "latest" then
        res = sql_run([[SELECT * FROM Packages WHERE Name = ? AND Vendor = ? ORDER BY Version DESC LIMIT 1]], name,
            vendor)
    else
        res = sql_run([[SELECT * FROM Packages WHERE Name = ? AND Version = ? AND Vendor = ?]], name, version, vendor)
    end

    assert(#res > 0, "❌ " .. vendor .. "/" .. name .. "@" .. version .. " not found")

    --  increment installs count
    local inc_res = sql_write(
        [[UPDATE Packages SET Installs = Installs + 1 WHERE Name = ? AND Version = ? AND Vendor = ?]], name,
        res[1].Version,
        vendor)
    assert(inc_res == 1, "❌[update error] " .. db:errmsg())

    Assign({
        Processes = { msg.From },
        Message = res[1].PkgID
    })
    CheckForAvailableUpdate(msg)
    print("APM>>> download request for " .. vendor .. "/" .. name .. "@" .. res[1].Version .. " from " .. msg.From)
end

Handlers.add(
    "APM.Download",
    Handlers.utils.hasMatchingTag("Action", "APM.Download"),
    function(msg)
        handle_run(Download, msg)
    end
)

------------------------------------------------------

function Transfer(msg)
    local vendor, name, _ = split_package_name(msg.Data)
    if not vendor then vendor = "@apm" end
    local new_owner = msg.To

    assert(name, "❌ Package name is required")
    assert(new_owner, "❌ New owner is required")

    local res = sql_run([[SELECT * FROM Packages WHERE Name = ? AND Vendor = ? ORDER BY Version DESC LIMIT 1]], name,
        vendor)

    assert(#res > 0, "❌ " .. vendor .. "/" .. name .. " not found")

    -- user should be either be the owner of the package or the vendor
    assert(res[1].Owner == msg.From or res[1].Vendor == msg.From, "❌ You are not the owner of " .. vendor .. "/" .. name)

    -- Update owner of the latest version of the package
    local write_res = sql_write([[UPDATE Packages SET Owner = ? WHERE Name = ? AND Vendor = ? AND Version = ?]],
        new_owner, name, vendor, res[1].Version)
    assert(write_res == 1, "❌[update error] " .. db:errmsg())

    print("APM>>> transferred " .. vendor .. "/" .. name .. " to " .. new_owner .. " by " .. msg.From)
    ao.send({
        Target = msg.From,
        Action = "APM.TransferResponse",
        Result = "success",
        Data = "🎉 " .. vendor .. "/" .. name .. " transferred to " .. new_owner
    })
    CheckForAvailableUpdate(msg)
end

Handlers.add(
    "APM.Transfer",
    Handlers.utils.hasMatchingTag("Action", "APM.Transfer"),
    function(msg)
        handle_run(Transfer, msg)
    end
)

------------------------------------------------------


function Search(msg)
    local query = msg.Data

    assert(type(query) == "string", "❌ Search query is required in Data")

    local vendor, pkgname, _ = split_package_name(query)

    -- search db based on name if only pkgname is given, else use both vendor and pkgname
    local packages
    if not vendor then
        packages = sql_run(
            [[SELECT DISTINCT Name, Vendor, Description, PkgID, Version, Installs FROM Packages WHERE Name LIKE ?]],
            "%" .. (pkgname or "") .. "%")
    else
        packages = sql_run(
            [[SELECT DISTINCT Name, Vendor, Description, PkgID, Version, Installs FROM Packages WHERE Name LIKE ? AND Vendor LIKE ?]],
            "%" .. (pkgname or "") .. "%", "%" .. vendor .. "%")
    end

    print("APM>>> searched " ..
        ((vendor or "---") .. "/" .. (pkgname or "---")) .. " by " .. msg.From .. " found " .. #packages .. " packages")
    ao.send({
        Target = msg.From,
        Action = "APM.SearchResponse",
        Data = json.encode(packages)
    })
    CheckForAvailableUpdate(msg)
end

Handlers.add(
    "APM.Search",
    Handlers.utils.hasMatchingTag("Action", "APM.Search"),
    function(msg)
        handle_run(Search, msg)
    end
)

------------------------------------------------------

function UpdateClient(msg)
    local l = sql_run([[SELECT * FROM Packages WHERE Name = "apm" AND Vendor = "@apm" ORDER BY Version DESC LIMIT 1]])
    if #l > 0 then
        ao.send({
            Target = msg.From,
            Action = "APM.UpdateClientResponse",
            Data = json.encode(l[1])
        })
    else
        ao.send({
            Target = msg.From,
            Data = "No updates available"
        })
    end
end

Handlers.add(
    "APM.UpdateClient",
    Handlers.utils.hasMatchingTag("Action", "APM.UpdateClient"),
    function(msg)
        handle_run(UpdateClient, msg)
    end
)

------------------------------------------------------

return "📦 Loaded APM"
