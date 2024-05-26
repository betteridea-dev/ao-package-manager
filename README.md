# AO Package Manager (APM)

The APM is a package manager for the AO the computer. It is designed to make it possible to easily install packages in processes.

APM ID `wvWJYLcPcAgSZ4DM2xZaeSAhDKVrJmUNULP54LrTk3Q`

## APM Usage (For the process that is managing all the packages)

**NOTE: The AOS-SQLITE module tois needed to spawn the APM process, since it uses sqlite commands to store and fetch package data** More info at [permaweb/aos-sqlite](https://github.com/permaweb/aos-sqlite/blob/main/README.md)

### Load APM source

APM Source: [apm.lua](/apm.lua)

Load `apm.lua`, this will load necessary handlers to make it possible to let other processes interact with the APM process.

if you are using the aos cli

```lua
.load apm.lua
```

### View published packages

NOTE: Function only available in the APM process

ListPackages()

will print something like:

```

@apm/newpkg@1.0.0 - 2yxybrYxDiAo5b56-6naMjgDrmaoDmUwy1_j82cbdco
@apm/testpkg@1.0.0 - 2yxybrYxDiAo5b56-6naMjgDrmaoDmUwy1_j82cbdco

```

or will print blank space if there are no packages published.


## Client Usage (For users wanting to install packages)

Set the APM process id

```lua
APM = "<APM_PID>"
```

### Load client source

Client source: [apm-user.lua](/apm-user.lua)

Load `apm-user.lua`, this will load necessary handlers to interact with the APM process.

```lua
.load apm-user.lua
```

### Show all published pacakges

Send a message to the APM process with the Action `GetAllPackages`

```lua
Send({
    Target = APM,
    Action = "GetAllPackages"
})
```

Shortly you should receive a response with a json of all the published packages.

### Publish a new pacakge

Create a table containing data for your package

```lua
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
    Name = "testpackage",
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
```

Then publish it by sending a message to the APM process with the Action `Publish` and the package data as a json encoded `Data` field.

```lua
local json = require("json")

Send({
    Target = APM,
    Action = "Publish",
    Data = json.encode(package)
})
```

Shortly you should receive a response wether the package was published or not.

### Load a package

To install a package, send a message to the APM process with the Action `Download` and the package name, version and vendor as a json encoded `Data` field.

```lua
local json = require("json")

local package = {
    Name = "testpackage",
    -- Version = "1.0.0", -- Optional (will get the latest version)
    -- Vendor = "@org name" -- Optional
}

Send({
    Target = APM,
    Action = "Download",
    Data = json.encode(package)
})
```

Shortly you should receive a response wether the package was downloaded or not.

Then you can use the package by using the `require` function.

```lua
local testpackage = require("testpackage")

print(testpackage.run())
```
