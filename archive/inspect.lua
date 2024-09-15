-- extra utils for debugging

function InspectPackage(name, version)
    if not name then
        return "Please provide a package name"
    end
    if not version then
        version = "latest"
    end
    local vendor, package = name:match("@(%w+)/(%w+)")

    if vendor then
        vendor = "@" .. vendor
        name = package
    else
        vendor = "@apm"
    end

    --     return "vendor: " .. vendor .. " name: " .. name .. " version: " .. version
    -- end

    local packages
    if version == "latest" then
        packages = SQLRun(string.format(
            [[SELECT * FROM Packages WHERE Vendor = "%s" AND Name = "%s" ORDER BY Version DESC LIMIT 1]],
            vendor,
            name))
    else
        packages = SQLRun(string.format(
            [[SELECT * FROM Packages WHERE Vendor = "%s" AND Name = "%s" AND Version = "%s"]], vendor,
            name,
            version))
    end

    if #packages == 0 then
        return "Package not found"
    end

    local pkg = packages[1]

    local items = pkg.Items

    -- decode and set pkg.Items to the decoded values

    local decoded = json.decode(base64.decode(items))

    pkg.Items = decoded

    for _, itm in ipairs(pkg.Items) do
        itm.data = base64.decode(itm.data)
    end

    return pkg
end
