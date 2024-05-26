local json = require("json")

local pack_info = {
    Name = "newpkg",
    -- Organization = "@betteridea"
    Version = "latest" -- (optional)
}

if not APM then
    error("APM is not available")
end

Send({
    Target = APM,
    Action = "Info",
    Data = json.encode(pack_info)
})
