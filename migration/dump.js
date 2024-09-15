import fs from "fs"
import { createDataItemSigner, message, result } from "@permaweb/aoconnect";

const jwk = JSON.parse(fs.readFileSync("../old.wallet.json", "utf8")) // old apm wallet
const legacy_apm = "UdPDhw5S7pByV3pVqwyr1qzJ8mR8ktzi9olgsdsyZz4" // old apm id

const m = await message({
    process: legacy_apm,
    signer: createDataItemSigner(jwk),
    data: `local vendors = sql_run("SELECT * FROM Vendors")
local packages = sql_run("SELECT * FROM Packages")

local r = {
    Vendors = vendors,
    Packages = packages    
}

return require("json").encode(r)
`,
    tags: [{ name: "Action", value: "Eval" }]
})

const res = await result({
    process: legacy_apm,
    message: m
})

console.log(res)
fs.writeFileSync("./dump.json", res.Output.data.output, "utf8")