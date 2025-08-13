# AO Package Manager (APM)

The APM is a package manager for the AO the computer. It is designed to make it possible to easily install packages in processes.

Visit [apm.betteridea.dev](https://apm.betteridea.dev) for a graphical interface to view and publish packages.

<center>



</center>

<!-- APM ID `UdPDhw5S7pByV3pVqwyr1qzJ8mR8ktzi9olgsdsyZz4` -->

<!-- APM ID `DKF8oXtPvh3q8s0fJFIeHFyHNM6oKrwMCUrPxEMroak` -->

APM ID `RLvG3tclmALLBCrwc17NqzNFqZCrUf3-RKZ5v8VRHiU`


## Client Usage (For users wanting to install packages)

### Load client tool

Client tool: [client.lua](/client.lua)

Load `client.lua` file, this will load necessary handlers and functions to interact with the APM process.

```lua
.load client.lua
-- or you can also load the blueprint
.load-blueprint apm.lua
```

The APM process id is stored in the `apm.ID` variable.

Make sure to always use the latest APM process id

```
apm.ID = "RLvG3tclmALLBCrwc17NqzNFqZCrUf3-RKZ5v8VRHiU"
```

### Show installed pacakges

```lua
apm.installed
```

### Install a package

```lua
apm.install "package_name"
-- or
apm.install "@vendor/package_name"
-- or
apm.install "@vendor/package_name@version"
```

When you dont enter a vendor name, it will default to `@apm`

When you dont enter a version, it will default to the latest version.

### Uninstall a package

```lua
APM.uninstall "package_name"
-- or
APM.uninstall "@vendor/package_name"
```

When you dont enter a vendor name, it will default to `@apm`

### Publishing a package

Check the [guide](https://apm.betteridea.dev) at apm webapp

also useful: [apm cli tool](https://npmjs.com/package/apm-tool)