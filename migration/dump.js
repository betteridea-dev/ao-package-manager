import fs from "fs"
import { createDataItemSigner, message, result } from "@permaweb/aoconnect";

const jwk = JSON.parse(fs.readFileSync("../wallet.json", "utf8")) // old apm wallet
const legacy_apm = "DKF8oXtPvh3q8s0fJFIeHFyHNM6oKrwMCUrPxEMroak" // old apm id

console.log("Sending message")
const m = await message({
    process: legacy_apm,
    signer: createDataItemSigner(jwk),
    data: `local vendors = SQLRun("SELECT * FROM Vendors")
local packages = SQLRun("SELECT * FROM Packages")

local r = {
    Vendors = vendors,
    Packages = packages    
}

return require("json").encode(r)
`,
    tags: [{ name: "Action", value: "Eval" }]
})
console.log(m)

console.log("Waiting for result")
const res = await result({
    process: legacy_apm,
    message: m
})

console.log(res)
fs.writeFileSync("./dump-1.json", res.Output.data.output, "utf8")