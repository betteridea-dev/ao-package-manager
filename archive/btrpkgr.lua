Namespaces = Namespaces or {
    ["@ankush"] = {
        Owner = "wallet_address",
        Packages = {
            "btrpkgr"
        },
        Transfers = {
            ["btrpkgr"] = {
                To = "wallet_address2",
            }
        }
    }
}

Packages = Packages or {
    ["@ankush/btrpkgr"] = {
        Name = "@ankush/btrpkgr",
        Owner = "wallet_address2",
        Authors = { "Ankush" },
        Dependencies = {},
        RepositoryUrl = "https://github.com",
        Latest = "0.1.0",
        Variants = {
            ["0.1.0"] = {
                Code = [[
                    function main()
                        print("Hello from btrpkgr")
                    end
                    ]]
            }
        }
    },
    ["normal-package"] = {
        Owner = "another_wallet",
        Latest = "0.0.1",
        Variants = {
            ["0.0.1"] = {
                Code = [[
                    function main()
                        print("Hello from normal-pac")
                    end
                ]]
            }
        }
    }
}

-- Utility functions

local function isValidVariant(variant)
    return variant:match("^%d+%.%d+%.%d+$")
end

local function isValidNamespace(name)
    return name:match("^@%w+$")
end

local function isValidPackageName(name)
    return name:match("^%w+$") or name:match("^@%w+/%w+$")
end

local function isNamespaced(name)
    return name:match("^@%w+/%w+$")
end

local function getNamespaceOwner(name)
    local ns = Namespaces[name]
    if ns then
        return ns.Owner
    end
end

-- Handler Functions

function RegisterNamespace(msg)
    local name = msg.Name
    assert(name, "Name is required")
    assert(isValidNamespace(name), "Invalid namespace name")
    local ns = Namespaces[name]
    if not ns then
        ns = {
            Owner = msg.From,
            Packages = {},
            Transfers = {}
        }
        Namespaces[name] = ns
        Handlers.utils.reply("Namespace " .. name .. " registered 🎉")(msg)
    else
        Handlers.utils.reply("Namespace " .. name .. " already exists")(msg)
    end
end

function PublishPackage(msg)
    local name = msg.Name
    local variant = msg.Variant
    local code = msg.Code
    assert(name, "Name is required")
    assert(isValidPackageName(name), "Invalid package name")
    assert(variant, "Variant is required")
    assert(isValidVariant(variant), "Invalid variant string")
    assert(code, "Code is required")
    local namespace = isNamespaced(name) and name:match("^@(%w+)/") or nil
    local nsOwner = namespace and getNamespaceOwner("@" .. namespace)
    if namespace then
        local ns = Namespaces["@" .. namespace]
        assert(nsOwner, "Namespace not found")
        assert(nsOwner == msg.From or ns.Transfers[name].To == msg.From, "You are not the owner of the namespace/package")
    end

    local pkg = Packages[name]
    if not pkg then
        pkg = {
            Owner = msg.From,
            Latest = variant,
            Variants = {}
        }
        Packages[name] = pkg
    end
    local ver = pkg.Variants[variant]
    if not ver then
        pkg.Variants[variant] = {
            Code = code
        }
        pkg.Latest = variant
        Handlers.utils.reply("Package " .. name .. " registered 🎉")(msg)
    else
        Handlers.utils.reply("Package " .. name .. " variant " .. variant .. " already exists")(msg)
    end
end

function GetPackageVariant(msg)
    local name = msg.Name
    local variant = msg.Variant
    assert(name, "Name is required")
    assert(isValidPackageName(name), "Invalid package name")
    assert(variant, "Variant is required")
    assert(isValidVariant(variant), "Invalid variant string")
    local pkg = Packages[name]
    if not pkg then
        Handlers.utils.reply("Package " .. name .. " not found")(msg)
        return
    end
    local ver = pkg.Variants[variant]
    if not ver then
        Handlers.utils.reply("Package " .. name .. " variant " .. variant .. " not found")(msg)
        return
    end
    local json = require("json")
    Handlers.utils.reply(json.encode(ver))(msg)
end

function GetPackageAll(msg)
    local name = msg.Name
    assert(name, "Name is required")
    assert(isValidPackageName(name), "Invalid package name")
    local pkg = Packages[name]
    if not pkg then
        Handlers.utils.reply("Package " .. name .. " not found")(msg)
        return
    end
    local json = require("json")
    Handlers.utils.reply(json.encode(pkg))(msg)
end

function GetPackageLatest(msg)
    local name = msg.Name
    assert(name, "Name is required")
    assert(isValidPackageName(name), "Invalid package name")
    local pkg = Packages[name]
    if not pkg then
        Handlers.utils.reply("Package " .. name .. " not found")(msg)
        return
    end
    local ver = pkg.Variants[pkg.Latest]
    if not ver then
        Handlers.utils.reply("Package " .. name .. " latest variant not found")(msg)
        return
    end
    local json = require("json")
    Handlers.utils.reply(json.encode(ver))(msg)
end

function GetNamespaceAll(msg)
    local json = require("json")
    Handlers.utils.reply(json.encode(Namespaces))(msg)
end

function GetNamespace(msg)
    local name = msg.Name
    assert(name, "Name is required")
    assert(isValidNamespace(name), "Invalid namespace name")
    local ns = Namespaces[name]
    if not ns then
        Handlers.utils.reply("Namespace " .. name .. " not found")(msg)
        return
    end
    local json = require("json")
    Handlers.utils.reply(json.encode(ns))(msg)
end

function TransferPackageOwnership(msg)
    local name = msg.Name
    local to = msg.To
    assert(name, "Name is required")
    assert(isValidPackageName(name), "Invalid package name")
    assert(to, "To is required")
    local pkg = Packages[name]
    if not pkg then
        Handlers.utils.reply("Package " .. name .. " not found")(msg)
        return
    end
    local namespace = isNamespaced(name) and name:match("^@(%w+)/") or nil
    local nsOwner = namespace and getNamespaceOwner("@" .. namespace)
    if namespace then
        assert(nsOwner, "Namespace not found")
        assert(nsOwner == msg.From, "You are not the owner of the namespace")
    end
    pkg.Owner = to
    local ns = Namespaces["@" .. namespace]
    ns.Transfers[name] = {
        To = to
    }
end

function TransferNamespaceOwnership(msg)
    local name = msg.Name
    local to = msg.To
    assert(name, "Name is required")
    assert(isValidNamespace(name), "Invalid namespace name")
    assert(to, "To is required")
    local ns = Namespaces[name]
    if not ns then
        Handlers.utils.reply("Namespace " .. name .. " not found")(msg)
        return
    end
    ns.Owner = to

    for pkgName in pairs(ns.Packages) do
        local pkg = Packages[pkgName]
        local isTransferred = ns.Transfers[pkgName]
        if isTransferred then
            pkg.Owner = isTransferred.To
        end
    end
end

-- Register Handlers

Handlers.add(
    "RegisterNamespace",
    Handlers.utils.hasMatchingTag("Action", "RegisterNamespace"),
    RegisterNamespace
)

Handlers.add(
    "PublishPackage",
    Handlers.utils.hasMatchingTag("Action", "PublishPackage"),
    PublishPackage
)

Handlers.add(
    "GetPackageVariant",
    Handlers.utils.hasMatchingTag("Action", "GetPackageVariant"),
    GetPackageVariant
)

Handlers.add(
    "GetPackageAll",
    Handlers.utils.hasMatchingTag("Action", "GetPackageAll"),
    GetPackageAll
)

Handlers.add(
    "GetPackageLatest",
    Handlers.utils.hasMatchingTag("Action", "GetPackageLatest"),
    GetPackageLatest
)

Handlers.add(
    "GetNamespaceAll",
    Handlers.utils.hasMatchingTag("Action", "GetNamespaceAll"),
    GetNamespaceAll
)

Handlers.add(
    "GetNamespace",
    Handlers.utils.hasMatchingTag("Action", "GetNamespace"),
    GetNamespace
)

Handlers.add(
    "TransferPackageOwnership",
    Handlers.utils.hasMatchingTag("Action", "TransferPackageOwnership"),
    TransferPackageOwnership
)

Handlers.add(
    "TransferNamespaceOwnership",
    Handlers.utils.hasMatchingTag("Action", "TransferNamespaceOwnership"),
    TransferNamespaceOwnership
)

return "OK"
