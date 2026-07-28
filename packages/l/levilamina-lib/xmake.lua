package("levilamina-lib")
    set_homepage("https://github.com/wed150/Levilamina-lib")
    set_description("LeviLamina prebuilt SDK")

    add_defines("ENTT_PACKED_PAGE=128", "ENTT_SPARSE_PAGE=2048", "ENTT_NO_MIXIN")
    add_configs("target_type", {default = "server", values = {"server", "client"}})
    add_configs("mode", {default = "release", values = {"debug", "release"}})

    add_urls("https://github.com/LiteLDev/LeviLamina.git")
    add_versionfiles("versions/versions.txt")

    on_load(function (package)
        local tt = package:config("target_type")
        package:add("defines", tt == "server" and "LL_PLAT_S" or "LL_PLAT_C")

        local v = package:version_str()
        import("core.base.semver")
        local sem = semver.try_parse(v)
        if sem and sem:le("0.12.4") then v = "old" end
        v = v:gsub("%.", "_")

        local mod = import("versions." .. v, {try = true})
        if mod then
            mod.load(package)
        else
            import("versions.main").load(package)
        end
    end)

    on_install(function (package)
        local tt = package:config("target_type")
        local mode = package:config("mode")
        local ver = package:version_str()
        local key = ver .. "-windows-" .. mode .. "-" .. tt

        local f = io.open(package:scriptdir() .. "/versions/prebuilt_versions.txt")
        local sha
        if f then
            for line in f:lines() do
                local k, s = line:match("^(%S+)%s+(%S+)$")
                if k == key then sha = s; break end
            end
            f:close()
        end

        if sha then
            local file = ("levilamina-sdk-v%s-%s-%s-windows-x64.zip"):format(ver, tt, mode)
            local url = ("https://github.com/wed150/Levilamina-lib/releases/download/v%s/%s"):format(ver, file)
            local zip = path.join(os.tmpdir(), file)

            import("net.http").download(url, zip, {sha256 = sha})
            import("utils.archive").extract(zip, package:installdir())
        else
            if tt == "client" then
                table.insert(configs, "--target_type=client")
            end
            import("package.tools.xmake").install(package)
        end
    end)
