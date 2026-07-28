package("levilamina-lib")
    set_homepage("https://github.com/wed150/Levilamina-lib")
    set_description("LeviLamina prebuilt SDK")

    add_defines("ENTT_PACKED_PAGE=128", "ENTT_SPARSE_PAGE=2048", "ENTT_NO_MIXIN")

    add_configs("target_type", {default = "server", values = {"server", "client"}})
    add_configs("mode", {default = "release", values = {"debug", "release"}})

    -- ============================================================
    -- 下载源（按优先级排列）
    -- ============================================================
    -- 优先：你的仓库里的预编译 SDK
    -- 用 version 目录文件管理版本号
    add_urls("https://github.com/wed150/Levilamina-lib/releases/download/v$(version)/levilamina-v$(version)-$(mode)-$(target_type)-windows-x64.zip",
             {alias = "prebuilt"})
    -- 注：$(mode) 和 $(target_type) 需要 xmake >= 2.8 支持在 url 里展开 config 值
    -- 如果展开不生效，退回到固定写法见下方 fallback

    -- 版本文件（你的仓库有预编译的版本列在这里）
    -- 格式：每行 "版本号 sha256" 或 "版本号 源码commit"
    -- 预编译 zip 的 sha256 填这里
    add_versionfiles("versions/prebuilt_versions.txt")

    -- fallback：原作者源码仓库（没有预编译时走这里）
    add_urls("https://github.com/LiteLDev/LeviLamina.git", {alias = "source"})
    add_versionfiles("versions/versions.txt")  -- 原作者那份

    -- ============================================================
    -- on_load：读版本模块决定 deps/defines（原样照抄原作者）
    -- ============================================================
    on_load(function (package)
        import("core.base.semver")
        local version = package:version_str()
        local sem = semver.try_parse(version)
        if sem and sem:le("0.12.4") then
            version = "old"
        end
        version = string.gsub(version, "%.", "_")

        try {
            function ()
                import("versions." .. version).load(package)
            end,
            catch {
                function (e)
                    cprint(
                        "${bright yellow}warning: ${clear}Unknown version: ${bright cyan}"
                        .. version .. "${clear}, will use main branch dependencies."
                    )
                    import("versions.main").load(package)
                end
            }
        }

        if package:config("target_type") == "server" then
            package:add("defines", "LL_PLAT_S")
        else
            package:add("defines", "LL_PLAT_C")
        end
    end)

    -- ============================================================
    -- on_install：判断走预编译还是源码编译
    -- ============================================================
    on_install(function (package)
        local version = package:version_str()

        -- 检查当前版本是否有预编译可用
        -- 通过读 prebuilt_versions.txt 判断
        local prebuilt_versions = import("versions.prebuilt_list")()
        local has_prebuilt = false
        for _, v in ipairs(prebuilt_versions) do
            if v == version then
                has_prebuilt = true
                break
            end
        end

        if has_prebuilt then
            -- ===== 走预编译路径 =====
            -- 此时 xmake 已经根据 add_urls 的 alias 优先级
            -- 自动下载了预编译 zip（alias = prebuilt）
            -- 解压后根目录有 bin/ include/ lib/
            if os.isdir("include") then
                os.cp("include/*", package:installdir("include"))
            end
            if os.isdir("lib") then
                os.cp("lib/*", package:installdir("lib"))
            end
            if os.isdir("bin") then
                os.cp("bin/*", package:installdir("bin"))
            end
        else
            -- ===== fallback：拉源码编译（原作者的路径）=====
            -- 此时 xmake 走了 alias = source，已经 git clone 好源码
            cprint(
                "${bright yellow}warning: ${clear}No precompiled version: ${bright cyan}"
                .. version .. "${clear}, will compile using the source code."
            )
            if package:config("target_type") == "server" then
                import("package.tools.xmake").install(package)
            else
                import("package.tools.xmake").install(package, {"--target_type=client"})
            end
        end
    end)
