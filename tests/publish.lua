local json = require("json")

-- we dont have to encode data aourselves, the Publish handler will take care of all encodings
local package_source = [[
local M={}

function M.run()
    return "WORKS!"
end

return M
]]

-- items list
local items = {
    {
        meta = { name = "main.lua" },
        data = package_source
    }
}

-- PackageData
local package = {
    Name = "testpack",
    Version = "1.0.0",
    PackageData = {
        Readme = "Sample test package",
        Description = "Just for testing",
        Main = "main.lua",
        Dependencies = {},
        RepositoryUrl = "#",
        Items = items,
        Authors = {}
    }
}

if not APM then
    error("APM is not available")
end

Send({
    Target = APM,
    Data = json.encode(package),
    Action = "Publish"
})
