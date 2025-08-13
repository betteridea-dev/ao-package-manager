# AO Package Manager (APM)

The APM is a package manager for the AO the computer. It is designed to make it possible to easily install packages in processes.

Visit [apm.betteridea.dev](https://apm.betteridea.dev) for a graphical interface to view and publish packages.

<center>



</center>

<!-- APM ID `UdPDhw5S7pByV3pVqwyr1qzJ8mR8ktzi9olgsdsyZz4` -->

APM ID `RLvG3tclmALLBCrwc17NqzNFqZCrUf3-RKZ5v8VRHiU`

<!-- aos apm --wallet wallet.json -->

## Install APM Client 

Installer: [installer.lua](/installer.lua)

Client Source: [client.lua](/client/client.lua)

Load `installer.lua` file, this will send a request to the APM registry to install the latest published client. Or you can load the client source file directly, but this wont guarantee that you have the latest or stable version.

```lua
.load-blueprint apm
```

The APM process id is stored in the `apm.ID` variable.

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