# AO Package Manager (APM)

The APM is a package manager for the AO the computer. It is designed to make it possible to easily install packages in processes.

<center>


[![built using betteridea](https://img.shields.io/badge/Built_using-BetterIDEa-lightgreen?logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAAZCAYAAAABmx/yAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAAGXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAf5JREFUOI2VkktrU1EURtc+9yZqG5UKJmlw2omlEymCf0AcOhERCtGKSS0UJVWCiIPitKlWpEkqFHwg4kD9A2IRdCQIVgvFUZWYlASh9qVN7t0OgjFX8+oHZ7bXOYt9Psl+u3zEUd24GLm9xA5iXOjHmPfpfCL7cOVqd8cggMAeMQxvqvM5kx+/0DEIgGIr9GJ0MlNIfMgWrhzuDPx7wT5gQHHmM4XEg7lScm9nYC1yEOFMuVJeaqTfAmytb7cE6/QVBsCdT+cTzwPGSrR+sV4cUOgR4eSaukeNYi0qfAV+tWGLIjwt+yt9o+HUK1FVZvPxLtd0Xwei6tIr4vmmLYScayQ6Gky9rRmoam3mbikZscvlGUSOgQaBosCchDduxMiWPer1IED6y7Ue8f18hpFBEXkhwfXhfyEPOMGEHcqvjoEmMBJC8YFsgeZ8Rs+eD9568x84U7x0wnKsaRUiKIEGiykJvN72V86NHbjzA8AKjaydslQeKUQAf5ONdoH0WY5E362/zA0Gjn+yRd3dKtKwj96oDRwS3PuZlfHNzpoDiLCqKssiOhQPTS20B4WKuFoQY92Mh1L3oLrNdpXLq8uT7V1Ofyw4OfsHgiYlr2qxbIShWHhqodGMF2yi1Sg1VYWiqj5upNXqxUUR5/RIaPpjq2FPst+T+1WrDdrJ+Q08kgLwyCsoJwAAAABJRU5ErkJggg==)](https://ide.betteridea.dev)
[![open with betteridea](https://img.shields.io/badge/Open_this_project-grey?logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAAZCAYAAAABmx/yAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAAGXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAf5JREFUOI2VkktrU1EURtc+9yZqG5UKJmlw2omlEymCf0AcOhERCtGKSS0UJVWCiIPitKlWpEkqFHwg4kD9A2IRdCQIVgvFUZWYlASh9qVN7t0OgjFX8+oHZ7bXOYt9Psl+u3zEUd24GLm9xA5iXOjHmPfpfCL7cOVqd8cggMAeMQxvqvM5kx+/0DEIgGIr9GJ0MlNIfMgWrhzuDPx7wT5gQHHmM4XEg7lScm9nYC1yEOFMuVJeaqTfAmytb7cE6/QVBsCdT+cTzwPGSrR+sV4cUOgR4eSaukeNYi0qfAV+tWGLIjwt+yt9o+HUK1FVZvPxLtd0Xwei6tIr4vmmLYScayQ6Gky9rRmoam3mbikZscvlGUSOgQaBosCchDduxMiWPer1IED6y7Ue8f18hpFBEXkhwfXhfyEPOMGEHcqvjoEmMBJC8YFsgeZ8Rs+eD9568x84U7x0wnKsaRUiKIEGiykJvN72V86NHbjzA8AKjaydslQeKUQAf5ONdoH0WY5E362/zA0Gjn+yRd3dKtKwj96oDRwS3PuZlfHNzpoDiLCqKssiOhQPTS20B4WKuFoQY92Mh1L3oLrNdpXLq8uT7V1Ofyw4OfsHgiYlr2qxbIShWHhqodGMF2yi1Sg1VYWiqj5upNXqxUUR5/RIaPpjq2FPst+T+1WrDdrJ+Q08kgLwyCsoJwAAAABJRU5ErkJggg==)](https://ide.betteridea.dev/import?id=ZHUZLCewiKWFZPlq6cAHgES0XZyZgvUUVaKPLEcTsA8)

</center>

APM ID `ZHUZLCewiKWFZPlq6cAHgES0XZyZgvUUVaKPLEcTsA8`

<details>

<summary> <strong>Guide</strong></summary>

1. clone the ao-package-manager repo and cd into it - https://github.com/ankushKun/ao-package-manager
2. spawn an sqlite process for the registry `AOS_MODULE=GYrbbe0VbHim_7Hi6zrOpHQXrSQz07XNtwCnfbFo2I0 aos apm`
3. `.load apm.lua`
4. try running `ListPackages()` it should say no packages
get its process id
---
5. spawn a separate process (this will publish a package) `aos publisher`
6. load the client tool `.load client-tool.lua` it should print APM client loaded
7. set `APM.ID = id of the earlier process`
8. use the [generate_package_data](https://github.com/ankushKun/ao-package-manager/blob/5fb309ff61bf68fd4940c95eed0ee92247097001/client-tool.lua#L31) function to pass the necessasary parameters and have it make a table that can be used to publish a package, it already sets some default sample code for testing. Store the result in a variable
9. try running `APM.list()` to get a list of installed packages, should return empty/none
10. run `APM.publish(package_data)` and wait for success message
---
11. run `ListPackages()` again in the registry process and check if the package is there.
---
12. spawn another process to test installation of package, repeat steps 5-7
13. use `APM.list()` and check available packages
14. Install the package you created earlier with `APM.install("package_name")`.
If package was published under @apm vendor, it is optional to pass the vendor name during install
15. Once installed try `pkg = require("package_name")` and perform package functions
16. have a look at `APM.installed` table

Here is a video that shows these steps: https://youtu.be/qZDtzOta4MM

</details>

## Client Usage (For users wanting to install packages)

### Load client tool

Client tool: [client-tool.lua](/client-tool.lua)

Load `client-tool.lua`, this will load necessary handlers to interact with the APM process.

```lua
.load client-tool.lua
```

The APM process id is stored in the `APM.ID` variable.

### Show all published pacakges

```lua
APM.list()
```

### Show installed pacakges

```lua
APM.installed
```

### Register a vendor name

```lua
APM.registerVendor("@name")
```

### Publish a package

look at the definition of the [`generate_package_data`](/client-tool.lua) function to see how to create a package data table.

Create a package data table and add your package data to it, before publishing.

```lua
local pkg = generate_package_data("pack_name", "@vendor_name")
APM.publish(pkg)
```

### Download a package

```lua
APM.install("package_name", "version (optional)")
```

### Uninstall a package

```lua
APM.uninstall("package_name")
```

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

