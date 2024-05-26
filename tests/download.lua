if not APM then
    error("APM is not available")
end

Send({
    Target = APM,
    Data = json.encode({
        Name = "newpkg",
        -- Version = "1.0.0", ()
    }),
    Action = "Download"
})
