import { readFileSync } from "fs"
import { message, createDataItemSigner } from "@permaweb/aoconnect"

const dump = JSON.parse(readFileSync("./dump-1.json", "utf8"))
const jwk = JSON.parse(readFileSync("../new-new-wallet.json", "utf8")) // new apm wallet
const apm_id = "RLvG3tclmALLBCrwc17NqzNFqZCrUf3-RKZ5v8VRHiU" // new apm id

/*
// vendors structure
{
    ID: 2,
    Name: '@betteridea',
    Owner: '8iD-Gy_sKx98oth27JhjjP2V_xUSIGqs_8-skb63YHg'
}
*/

/*
// package structure (old)
{
    "ID": 1,
    "Name": "sample",
    "Owner": "8iD-Gy_sKx98oth27JhjjP2V_xUSIGqs_8-skb63YHg",
    "Main": "main.lua",
    "RepositoryUrl": "https://github.com/betteridea-dev/apm-web",
    "Updated": 0,
    "Vendor": "@apm",
    "Installs": 5,
    "Version": "1.0.0",
    "Authors_": "[]",
    "Dependencies": "[]",
    "Description": "sample package to test publishing",
    "PkgID": "6aIx6-jM4rxdyE1Hsvvy18sMvmp09wWDcaXbcxItTak",
    "Items": "5b7b226d657461223a7b226e616d65223a226d61696e2e6c7561227d2c2264617461223a226c6f63616c204d203d207b7d5c6e5c6e66756e6374696f6e204d2e68656c6c6f28295c6e202020207072696e74285c2248656c6c6f2c20414f215c22295c6e656e645c6e5c6e66756e6374696f6e204d2e676f6f6462796528295c6e202020207072696e74285c22596f752063616e6e6f742065736361706520746865204d6174726978215c22295c6e656e645c6e5c6e72657475726e204d227d5d",
    "README": "0a0a232053616d706c65205061636b6167650a0a5468697320697320612073616d706c65207061636b61676520666f72207468652041504d2028414f205061636b616765204d616e61676572290a0a232320496e7374616c6c6174696f6e0a0a606060626173680a41504d2e696e7374616c6c282273616d706c655f7061636b61676522290a6060600a0a23232055736167650a0a6060606c75610a6c6f63616c2073616d706c655f7061636b616765203d2072657175697265282273616d706c655f7061636b61676522290a0a73616d706c655f7061636b6167652e68656c6c6f28290a6060600a0a546f207075626c69736820796f7572206f776e207061636b6167652c20706c65617365207669736974205b61706d2e626574746572696465612e6465765d2868747470733a2f2f61706d2e626574746572696465612e646576290a0a4275696c74207769746820e29da4efb88f206279205b42657474657249444561205465616d5d2868747470733a2f2f626574746572696465612e646576290a"
}
// Packages table structure (new)
ID INTEGER PRIMARY KEY AUTOINCREMENT,
Vendor TEXT DEFAULT "@apm",
Name TEXT NOT NULL,
Version TEXT NOT NULL,
Description TEXT NOT NULL,
Owner TEXT NOT NULL,
README TEXT NOT NULL,
PkgID TEXT NOT NULL,
Source TEXT NOT NULL,
Authors_ TEXT NOT NULL,
Dependencies TEXT NOT NULL,
Repository TEXT NOT NULL,
Timestamp INTEGER NOT NULL,
Installs INTEGER DEFAULT 0,
TotalInstalls INTEGER DEFAULT 0,
Keywords TEXT DEFAULT "[]",
IsFeatured BOOLEAN DEFAULT 0,
Warnings TEXT DEFAULT "{}",
License TEXT DEFAULT ""
*/

const vendors = dump.Vendors
const packages = dump.Packages

function sqlEscape(value) {
    return String(value ?? "").replace(/'/g, "''")
}

async function main() {
    console.log(vendors.length, "vendors")
    console.log(packages.length, "packages")

    for (let i = 0; i < vendors.length; i++) {
        const element = vendors[i]
        const sql = `INSERT INTO Vendors (Name, Owner) VALUES ('${sqlEscape(element.Name)}', '${sqlEscape(element.Owner)}');`
        const mid = await message({
            process: apm_id,
            signer: createDataItemSigner(jwk),
            data: sql,
            tags: [{ name: "Action", value: "APM.Port" }]
        })
        console.log("vendor:", mid, element.ID, element.Name)
    }

    for (let i = 0; i < packages.length; i++) {
        const element = packages[i]
        try {
            const sourceHex = element.Source || ''
            const readmeHex = element.README || ''
            const repository = element.Repository || element.RepositoryUrl || ''
            const timestamp = (element.Timestamp ?? element.Updated ?? 0)

            const sql = `INSERT INTO Packages (
                Vendor,
                Name,
                Version,
                Description,
                Owner,
                README,
                Source,
                Authors_,
                Dependencies,
                Repository,
                Timestamp,
                PkgID,
                Installs,
                TotalInstalls
                ) VALUES (
                    '${sqlEscape(element.Vendor)}',
                    '${sqlEscape(element.Name)}',
                    '${sqlEscape(element.Version)}',
                    '${sqlEscape(element.Description)}',
                    '${sqlEscape(element.Owner)}',
                    '${readmeHex}',
                    '${sourceHex}',
                    '${element.Authors_ ?? '[]'}',
                    '${element.Dependencies ?? '{}'}',
                    '${sqlEscape(repository)}',
                    ${timestamp},
                    '<MID>',
                    ${element.Installs || 0},
                    ${element.TotalInstalls || 0}
                );`

            const mid = await message({
                process: apm_id,
                signer: createDataItemSigner(jwk),
                data: sql,
                tags: [{ name: "Action", value: "APM.Port" }]
            })
            console.log("package:", mid, element.Vendor, element.Name, element.Version)

        } catch (err) {
            console.error("failed to migrate package", element?.Name, err)
        }
    }

    console.log("done")
}

await main()