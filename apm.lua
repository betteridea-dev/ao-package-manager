json = require("json")
base64 = require(".base64")
sqlite3 = require("lsqlite3")
bint = require('.bint')(256)

db = db or sqlite3.open_memory()


db:exec([[
    CREATE TABLE IF NOT EXISTS Packages (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Vendor TEXT DEFAULT "@apm",
        Name TEXT NOT NULL,
        Version TEXT NOT NULL,
        Description TEXT NOT NULL,
        Owner TEXT NOT NULL,
        README TEXT NOT NULL,
        PkgID TEXT NOT NULL,
        Source TEXT NOT NULL,
        Authors_ TEXT NOT NULL,
        Dependencies TEXT NOT NULL,
        Repository TEXT NOT NULL,
        Timestamp INTEGER NOT NULL,
        Installs INTEGER DEFAULT 0,
        TotalInstalls INTEGER DEFAULT 0,
        Keywords TEXT DEFAULT "[]",
        IsFeatured BOOLEAN DEFAULT 0,
        Warnings TEXT DEFAULT "{}",
        License TEXT DEFAULT ""
    );
    CREATE TABLE IF NOT EXISTS Vendors (
        ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Name TEXT NOT NULL,
        Owner TEXT NOT NULL
    );
]])

function Set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

function Hexencode(str)
    return (str:gsub(".", function(char) return string.format("%02x", char:byte()) end))
end

function Hexdecode(hex)
    return (hex:gsub("%x%x", function(digits) return string.char(tonumber(digits, 16)) end))
end

function IsValidVersion(variant)
    -- version string or 43 char message_id
    return variant:match("^%d+%.%d+%.%d+$") or (variant:match("^[a-zA-Z0-9%-%_]+$") and #variant == 43)
end

function IsValidPackageName(name)
    return name:match("^[a-zA-Z0-9%-_]+$")
end

function IsValidVendor(name)
    -- check not nil and matches /^[a-z0-9-]+$/
    -- local blocklist = { "apm", "ao", "admin", "root", "system", "vendor", "vendors", "package", "packages" }
    -- return name and name:match("^[a-z0-9-]+$") and not blocklist[name]
    -- if name doesnot start with @ then add it
    return name and name:match("^@[a-z0-9-]+$")
end

function SplitPackageName(query)
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
function HandleRun(func, msg)
    local ok, err = pcall(func, msg)
    if not ok then
        local clean_err = err:match(":%d+: (.+)") or err
        print(msg.Action .. " - " .. err)
        -- if not msg.From == ao.id then
        ao.send({
            Target = msg.From,
            Data = clean_err,
            Result = "error"
        })
        -- end
    end
end

-- easily read from the database
function SQLRun(query, ...)
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
function SQLWrite(query, ...)
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
    local p = SQLRun([[WITH UniqueNames AS (
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
            pkg.Installs .. " installs" ..
            " | " ..
            pkg.PkgID ..
            "\n"
    end
    return p_str
end

-- Function to get latest apm client version
function GetLatestClientVersion()
    local version = SQLRun(
        [[SELECT Version FROM Packages WHERE Name = "apm" AND Vendor = "@apm" ORDER BY Version DESC LIMIT 1]])
    if #version == 0 then
        return ""
    end
    return version[1].Version
end

-- Logs = Logs or {}
function Print(text)
    print("[APM] " .. text)
end

function UpdateTotal()
    -- sum total installs of all versions and update for all packages
    local p = SQLRun([[SELECT DISTINCT Name, Vendor FROM Packages]])
    for _, pkg in ipairs(p) do
        local total_installs = SQLRun([[SELECT SUM(Installs) AS Total FROM Packages WHERE Name = ? AND Vendor = ?]],
            pkg.Name, pkg.Vendor)
        local res = SQLWrite([[UPDATE Packages SET TotalInstalls = ? WHERE Name = ? AND Vendor = ?]],
            total_installs[1].Total,
            pkg.Name, pkg.Vendor)
    end

    return "Total installs updated"
end

--------------------------------------------------------

-- function to Register Vendor
function RegisterVendor(msg)
    local name = msg.Data
    local owner = msg.From

    if not name:match("^@") then
        name = "@" .. name
    end
    assert(IsValidVendor(name), "Invalid vendor name")

    local vendor = SQLRun([[SELECT * FROM Vendors WHERE Name = ? AND Owner = ?]], name, owner)
    assert(#vendor == 0, "Vendor already exists")

    local res = SQLWrite([[INSERT INTO Vendors (Name, Owner) VALUES (?, ?)]], name, owner)
    assert(res == 1, db:errmsg())

    Print(msg.Action .. " - " .. name)
    Send {
        Target = msg.From,
        Result = "success",
        Data = "🎉 Registered " .. name,
        LatestClientVersion = GetLatestClientVersion()
    }
    -- CheckForAvailableUpdate(msg)
end

Handlers.add(
    "APM.RegisterVendor",
    Handlers.utils.hasMatchingTag("Action", "APM.RegisterVendor"),
    function(msg)
        HandleRun(RegisterVendor, msg)
    end
)

--

function Publish(msg)
    local name = msg.Name
    local description = msg.Description
    local vendor = msg.Vendor
    local version = msg.Version
    local owner = msg.Owner
    local pkgid = msg.Id

    local keywords = msg.Keywords
    local repo_url = msg.Repository
    local dependencies = msg.Dependencies

    local data = msg.Data -- {source, readme} in hex
    data = json.decode(data)
    print(data)
    local source = data.source
    local readme = data.readme


    local warnings = msg.Warnings -- {ModifiesGlobalState:boolean, Message:boolean}

    local authors = msg.Authors   -- {address, name, email, url}[]
    local license = msg.License

    Print("Publishing " .. vendor .. "/" .. name .. "@" .. version .. " by " .. owner)


    if (keywords) then
        local keywords_t = json.decode(keywords)
        assert(type(keywords_t) == "table", "Invalid keywords")
        for _, keyword in ipairs(keywords_t) do
            assert(type(keyword) == "string", "Invalid keyword")
        end
    end

    if (warnings) then
        local warnings_t = json.decode(warnings)
        assert(type(warnings_t.modifiesGlobalState) == "boolean", "Invalid modifiesGlobalState")
        assert(type(warnings_t.installMessage) == "string", "Invalid warning")
    end

    if (authors) then
        local authors_t = json.decode(authors)
        for _, author in ipairs(authors_t) do
            if (author.address) then
                assert(type(author.address) == "string", "Invalid author address")
            end
            if (author.name) then
                assert(type(author.name) == "string", "Invalid author name")
            end
            if (author.email) then
                assert(type(author.email) == "string", "Invalid author email")
            end
            if (author.url) then
                assert(type(author.url) == "string", "Invalid author url")
            end
        end
    end

    local source_str = Hexencode(source)
    local readme_str = Hexencode(readme)

    assert(IsValidPackageName(name), "Invalid package name")
    assert(IsValidVendor(vendor), "Invalid vendor name")
    assert(IsValidVersion(version), "Invalid version")

    -- check if user owns vendor


    -- latest 1 package
    -- local pkg = SQLRun([[SELECT * FROM Packages WHERE Name = ? AND Vendor = ?]], name, vendor)
    local pkg = SQLRun([[SELECT * FROM Packages WHERE Name = ? AND Vendor = ? ORDER BY Version DESC LIMIT 1]], name,
        vendor)

    -- if package exists check if version is greater than the existing one
    -- if version is greater check if the owner is the same
    -- if owner is the same then add the new version of the package
    local total_installs = 0
    if #pkg > 0 then
        assert(pkg[1].Owner == owner, "You are not the owner of this package")
        assert(pkg[1].Version < version, "Version should be greater than the existing one")
        total_installs = pkg[1].TotalInstalls
    else
        if vendor ~= "@apm" then
            -- check if the vendor exists and owner is the same
            local vendor_ = SQLRun([[SELECT * FROM Vendors WHERE Name = ? AND Owner = ?]], vendor, owner)
            assert(#vendor_ > 0, "You are not the owner of this vendor")
        end
    end

    local res = SQLWrite(
        [[INSERT INTO Packages (
            Vendor,
            Name,
            Version,
            Description,
            Owner,
            README,
            PkgID,
            Source,
            Authors_,
            Dependencies,
            Repository,
            Timestamp,
            Keywords,
            Warnings,
            License,
            TotalInstalls
        ) VALUES (
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?
        )]],
        vendor,
        name,
        version,
        description,
        owner,
        readme_str,
        pkgid,
        source_str,
        authors,
        dependencies,
        repo_url,
        msg.Timestamp,
        keywords,
        warnings,
        license,
        total_installs
    )

    assert(res == 1, db:errmsg())

    Print(msg.Action .. " - " .. vendor .. "/" .. name .. "@" .. version)
    Send {
        Target = msg.From,
        Result = "success",
        Data = "🎉 Published " .. name .. "@" .. version,
        LatestClientVersion = GetLatestClientVersion()
    }
    -- CheckForAvailableUpdate(msg)
end

Handlers.add(
    "APM.Publish",
    Handlers.utils.hasMatchingTag("Action", "APM.Publish"),
    function(msg)
        HandleRun(Publish, msg)
    end
)

---------------------------------------------

function Transfer(msg)
    local name = msg.Name
    local vendor = msg.Vendor
    local new_owner = msg.Recipient
    local owner = msg.From

    assert(IsValidPackageName(name), "Invalid package name")
    assert(IsValidVendor(vendor), "Invalid vendor name")

    local pkg = SQLRun([[SELECT * FROM Packages WHERE Name = ? AND Vendor = ?
        ORDER BY Version DESC LIMIT 1
    ]], name, vendor)
    assert(#pkg > 0, "Package not found")
    assert(pkg[1].Owner == owner, "You are not the owner of this package")

    local res = SQLWrite([[UPDATE Packages SET Owner = ? WHERE ID = ?]], new_owner, pkg[1].ID)
    assert(res == 1, db:errmsg())

    Print(msg.Action .. " - " .. vendor .. "/" .. name .. " to " .. new_owner)
    Send {
        Target = msg.From,
        Result = "success",
        Data = "🎉 Transferred " .. vendor .. "/" .. name .. " to " .. new_owner,
        LatestClientVersion = GetLatestClientVersion()
    }
    -- CheckForAvailableUpdate(msg)
end

Handlers.add(
    "APM.Transfer",
    Handlers.utils.hasMatchingTag("Action", "APM.Transfer"),
    function(msg)
        HandleRun(Transfer, msg)
    end
)

---------------------------------------------

function Download(msg)
    print(msg.Data)
    local vendor, name, version = SplitPackageName(msg.Data)
    assert(IsValidVendor(vendor), "Invalid vendor name")
    assert(IsValidPackageName(name), "Invalid package name")
    if version then
        assert(IsValidVersion(version), "Invalid version")
    end

    local pkg
    if version then
        pkg = SQLRun([[(SELECT * FROM Packages WHERE Name = ? AND Vendor = ? AND Version = ?) OR PkgID = ?]], name,
            vendor, version, version)
    else
        pkg = SQLRun([[SELECT * FROM Packages WHERE Name = ? AND Vendor = ? ORDER BY Version DESC LIMIT 1]], name,
            vendor)
    end

    assert(#pkg > 0, "Package not found")

    local source = pkg[1].Source
    local pkgid = pkg[1].PkgID

    local res = SQLWrite([[UPDATE Packages SET Installs = Installs + 1 WHERE ID = ?]],
        pkg[1].ID)
    assert(res == 1, db:errmsg())
    res = SQLWrite([[UPDATE Packages SET TotalInstalls = TotalInstalls + 1 WHERE Vendor = ? AND Name = ?]],
        vendor, name)
    assert(res > 0, db:errmsg())


    Print(msg.Action .. " - " .. vendor .. "/" .. name .. "@" .. pkg[1].Version .. " by " .. msg.From)
    Send({
        Target = msg.From,
        Result = "success",
        PkgID = pkgid,
        Name = vendor .. "/" .. name,
        Version = pkg[1].Version,
        Data = source,
        Warnings = pkg[1].Warnings,
        Dependencies = pkg[1].Dependencies,
        Action = "APM.DownloadResponse",
        LatestClientVersion = GetLatestClientVersion()
    })
    -- CheckForAvailableUpdate(msg)
end

Handlers.add(
    "APM.Download",
    Handlers.utils.hasMatchingTag("Action", "APM.Download"),
    function(msg)
        HandleRun(Download, msg)
    end
)


---------------------------------------------


function Search(msg)
    local query = msg.Data

    assert(type(query) == "string", "❌ Search query is required in Data")

    local vendor, pkgname, _ = SplitPackageName(query)

    local res = {}

    local p = {}
    if not vendor then
        p = SQLRun(
            [[
        WITH UniqueNames AS (
    SELECT
        MAX(Version) AS Version, *
    FROM
        Packages
    GROUP BY
        Name, Vendor
    ORDER BY
        Installs DESC
)
        SELECT DISTINCT * FROM UniqueNames WHERE Name LIKE ? OR Vendor LIKE ?
            ]],
            "%" .. (pkgname or "") .. "%", "%" .. (pkgname or "") .. "%")
    else
        p = SQLRun(
            [[
        WITH UniqueNames AS (
    SELECT
        MAX(Version) AS Version, *
    FROM
        Packages
    GROUP BY
        Name, Vendor
    ORDER BY
        TotalInstalls DESC
)
        SELECT DISTINCT * FROM UniqueNames WHERE Name LIKE ? AND Vendor LIKE ?
            ]],
            "%" .. (pkgname or "") .. "%", "%" .. vendor .. "%")
    end

    for _, pkg in ipairs(p) do
        table.insert(res, {
            Vendor = pkg.Vendor,
            Name = pkg.Name,
            Version = pkg.Version,
            Owner = pkg.Owner,
            Installs = pkg.Installs,
            TotalInstalls = pkg.TotalInstalls,
            Description = pkg.Description,
            Readme = pkg.README,
            PkgID = pkg.PkgID
        })
    end

    Print(msg.Action .. " - " .. query .. " | " .. #p .. " results")
    Send {
        Target = msg.From,
        Result = "success",
        Data = json.encode(res),
        Action = "APM.SearchResponse",
        LatestClientVersion = GetLatestClientVersion()
    }
    -- CheckForAvailableUpdate(msg)
end

Handlers.add(
    "APM.Search",
    Handlers.utils.hasMatchingTag("Action", "APM.Search"),
    function(msg)
        HandleRun(Search, msg)
    end
)

---------------------------------------------

function Popular(msg)
    local res = {}

    local p = SQLRun([[WITH UniqueNames AS (
    SELECT
        MAX(Version) AS Version, *
    FROM
        Packages
    GROUP BY
        Name
)
SELECT
    *
FROM
    UniqueNames
ORDER BY
    TotalInstalls DESC
LIMIT 50;]])

    for _, pkg in ipairs(p) do
        table.insert(res, {
            Vendor = pkg.Vendor,
            Name = pkg.Name,
            Version = pkg.Version,
            Owner = pkg.Owner,
            Installs = pkg.Installs,
            TotalInstalls = pkg.TotalInstalls,
            Description = pkg.Description,
            -- Readme = pkg.README,
            PkgID = pkg.PkgID,
            Repository = pkg.Repository
        })
    end

    Print(msg.Action .. " - " .. #p .. " results")
    Send {
        Target = msg.From,
        Result = "success",
        Data = json.encode(res),
        Action = "APM.PopularResponse",
        LatestClientVersion = GetLatestClientVersion()
    }
    -- CheckForAvailableUpdate(msg)
end

Handlers.add(
    "APM.Popular",
    Handlers.utils.hasMatchingTag("Action", "APM.Popular"),
    function(msg)
        HandleRun(Popular, msg)
    end
)

---------------------------------------------

function Info(msg)
    local vendor, name, version = SplitPackageName(msg.Data)

    if not vendor then
        vendor = "@apm"
    end
    assert(IsValidVendor(vendor), "Invalid vendor name")
    assert(IsValidPackageName(name), "Invalid package name")
    if version then
        assert(IsValidVersion(version), "Invalid version")
    end

    local pkg

    if version then
        pkg = SQLRun([[SELECT * FROM Packages WHERE Name = ? AND Vendor = ? AND Version = ?]], name, vendor, version)
    else
        pkg = SQLRun([[SELECT * FROM Packages WHERE Name = ? AND Vendor = ? ORDER BY Version DESC LIMIT 1]], name, vendor)
    end

    assert(#pkg > 0, "Package not found")

    local res = {
        ID = pkg[1].ID,
        Vendor = pkg[1].Vendor,
        Name = pkg[1].Name,
        Version = pkg[1].Version,
        Owner = pkg[1].Owner,
        Installs = pkg[1].Installs,
        TotalInstalls = pkg[1].TotalInstalls,
        Description = pkg[1].Description,
        PkgID = pkg[1].PkgID,
        Source = pkg[1].Source,
        Readme = pkg[1].README,
        Authors = pkg[1].Authors_,
        Dependencies = pkg[1].Dependencies,
        Repository = pkg[1].Repository,
        Keywords = pkg[1].Keywords,
        Warnings = pkg[1].Warnings,
        License = pkg[1].License,
        Timestamp = pkg[1].Timestamp
    }

    local versions = SQLRun([[SELECT Version, PkgID, Installs FROM Packages WHERE Name = ? AND Vendor = ?]], name, vendor)
    res.Versions = versions

    Print(msg.Action .. " - " .. vendor .. "/" .. name .. "@" .. pkg[1].Version)
    Send {
        Target = msg.From,
        Result = "success",
        Data = json.encode(res),
        Action = "APM.InfoResponse",
        LatestClientVersion = GetLatestClientVersion()
    }
    -- CheckForAvailableUpdate(msg)
end

Handlers.add(
    "APM.Info",
    Handlers.utils.hasMatchingTag("Action", "APM.Info"),
    function(msg)
        HandleRun(Info, msg)
    end
)

---------------------------------------------

function VendorOrAddressPackages(msg)
    local vendor_or_address = msg.Data

    local search_address = (#vendor_or_address == 43)

    if not search_address then
        assert(IsValidVendor(vendor_or_address), "Invalid vendor name")
    end

    local res = {}
    local p
    if search_address then
        p = SQLRun([[WITH UniqueNames AS (
        SELECT
            MAX(Version) AS Version, *
        FROM
            Packages
        WHERE
            Owner = ?
        GROUP BY
            Name
    )
    SELECT
        *
    FROM
        UniqueNames
    ORDER BY
        Timestamp DESC;]], vendor_or_address)
    else
        p = SQLRun([[WITH UniqueNames AS (
        SELECT
            MAX(Version) AS Version, *
        FROM
            Packages
        WHERE
            Vendor = ?
        GROUP BY
            Name
    )
    SELECT
        *
    FROM
        UniqueNames
    ORDER BY
        Timestamp DESC;]], vendor_or_address)
    end

    for _, pkg in ipairs(p) do
        table.insert(res, {
            Vendor = pkg.Vendor,
            Name = pkg.Name,
            Version = pkg.Version,
            Owner = pkg.Owner,
            Installs = pkg.Installs,
            TotalInstalls = pkg.TotalInstalls,
            Description = pkg.Description,
            Readme = pkg.README,
            PkgID = pkg.PkgID
        })
    end

    Print(msg.Action .. " - " .. vendor_or_address .. " | " .. #p .. " results")
    Send {
        Target = msg.From,
        Result = "success",
        Data = json.encode(res),
        Action = "APM.VendorPackagesResponse",
        LatestClientVersion = GetLatestClientVersion()
    }
    -- CheckForAvailableUpdate(msg)
end

Handlers.add(
    "APM.VendorOrAddressPackages",
    Handlers.utils.hasMatchingTag("Action", "APM.VendorOrAddressPackages"),
    function(msg)
        HandleRun(VendorOrAddressPackages, msg)
    end
)

---------------------------------------------

function Update(msg)
    print("Update requested")
    local pkg = SQLRun([[SELECT * FROM Packages WHERE Name = "apm" AND Vendor = "@apm" ORDER BY Version DESC LIMIT 1]])
    assert(#pkg > 0, "APM package not found")

    local source = pkg[1].Source
    local pkgid = pkg[1].PkgID
    local version = pkg[1].Version

    Send({
        Target = msg.From,
        Result = "success",
        PkgID = pkgid or "",
        Name = "@apm/apm",
        Version = version or "",
        Data = source or "",
        Action = "APM.UpdateResponse",
        LatestClientVersion = GetLatestClientVersion() or ""
    })
end

Handlers.add(
    "APM.Update",
    Handlers.utils.hasMatchingTag("Action", "APM.Update"),
    function(msg)
        HandleRun(Update, msg)
    end
)

--------------------------------------------------------------------------
--------------------------------------------------------------------------
--------------------------------------------------------------------------
--------------------------------------------------------------------------

-- PORT FROM PREVIOUS REGISTRY

-- function Port(msg)
--     if msg.From == Owner then
--         local pkgid = msg.Id
--         local sql_query = msg.Data
--         -- from sql_query replace <MID> with pkgid
--         sql_query = sql_query:gsub("<MID>", pkgid)
--         -- print(sql_query)
--         local res = SQLWrite(sql_query)

--         print(msg.Action .. " - " .. res .. " - " .. db:errmsg())
--     end
-- end

-- Handlers.add(
--     "APM.Port",
--     Handlers.utils.hasMatchingTag("Action", "APM.Port"),
--     function(msg)
--         HandleRun(Port, msg)
--     end
-- )


--------------------------------------------------------------------------
--------------------------------------------------------------------------
--------------------------------------------------------------------------
--------------------------------------------------------------------------


return "📦 APM Loaded"
