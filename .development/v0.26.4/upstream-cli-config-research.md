# v0.26.4 upstream CLI/config research

Generated from current upstream primary-source repositories. Snippets are intentionally bounded and are used to drive Huymaier integration, not redistributed runtime code.

## shadPS4

Upstream commit: `11aaefe2171ae28199317bc1a07f9bb4e35437a6`

### CLI / launch / content symbols
```text
/home/runner/work/_temp/hc-upstream/shadPS4/documents/Debugging/Debugging.md:41:   List your game path as an argument, as if you were launching the non-GUI emulator from the command line.
/home/runner/work/_temp/hc-upstream/shadPS4/documents/building-macos.md:59:./shadps4 /"PATH"/"TO"/"GAME"/"FOLDER"/eboot.bin
/home/runner/work/_temp/hc-upstream/shadPS4/.github/workflows/build.yml:302:    - name: Run AppImage packaging script
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:29028:STUB("8lq3HM5y55s", monoeg_g_shell_parse_argv)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:45488:STUB("F-7nYSizbvc", g_shell_parse_argv)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:46437:STUB("FJmglmTMdr4", getargv)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:62765:    "LarGcv2d+lU",
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:73911:STUB("PaG1xovlZvk", _ZN3JSC14ProtoCallFrame17setPaddedArgCountEj)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:104335:STUB("b-i3JSeZ12E", il2cpp_set_commandline_arguments_utf16)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:124239:STUB("iKJMWrAumPE", getargc)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:170576:STUB("zccQaiAKfeI", il2cpp_set_commandline_arguments)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/ps4_names.txt:7583:_ZN3JSC14ProtoCallFrame17setPaddedArgCountEj
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/ps4_names.txt:74841:g_shell_parse_argv
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/ps4_names.txt:74960:getargc
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/ps4_names.txt:74961:getargv
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/ps4_names.txt:75519:il2cpp_set_commandline_arguments
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/ps4_names.txt:75520:il2cpp_set_commandline_arguments_utf16
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/ps4_names.txt:79163:monoeg_g_shell_parse_argv
/home/runner/work/_temp/hc-upstream/shadPS4/src/shadnet/shadnet.proto:22:    string title_id    = 4;  
/home/runner/work/_temp/hc-upstream/shadPS4/src/shadnet/client.cpp:201:    req.set_title_id(std::string(Common::ElfInfo::Instance().GameSerial()));
/home/runner/work/_temp/hc-upstream/shadPS4/src/common/ntapi.h:182:    UNICODE_STRING CommandLine;
/home/runner/work/_temp/hc-upstream/shadPS4/src/common/path_util.cpp:207:        auto eboot_path = dir / "eboot.bin";
/home/runner/work/_temp/hc-upstream/shadPS4/src/common/scope_exit.h:66: * Example usage:
/home/runner/work/_temp/hc-upstream/shadPS4/src/common/bit_field.h:24: * General usage:
/home/runner/work/_temp/hc-upstream/shadPS4/src/common/bit_field.h:35: * Sample usage:
/home/runner/work/_temp/hc-upstream/shadPS4/src/common/logging/classes.h:14:constexpr auto Config = "Config";                                   ///< Emulator configuration (including commandline)
/home/runner/work/_temp/hc-upstream/shadPS4/src/common/path_util.h:116: * @returns Path to eboot.bin if found, std::nullopt otherwise
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:18:    case MemoryUsage::Upload:
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:20:    case MemoryUsage::Download:
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:22:    case MemoryUsage::Stream:
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:24:    case MemoryUsage::DeviceLocal:
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:32:    return usage != MemoryUsage::DeviceLocal ? VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:38:    case MemoryUsage::Upload:
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:39:    case MemoryUsage::Stream:
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:42:    case MemoryUsage::Download:
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:44:    case MemoryUsage::DeviceLocal:
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:52:    case MemoryUsage::DeviceLocal:
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:53:    case MemoryUsage::Stream:
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:55:    case MemoryUsage::Upload:
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:56:    case MemoryUsage::Download:
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:177:    if (!is_coherent && usage == MemoryUsage::Stream) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer.cpp:213:        if (usage == MemoryUsage::Download) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer_cache.cpp:31:      staging_buffer{instance, scheduler, MemoryUsage::Upload, StagingBufferSize},
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer_cache.cpp:32:      stream_buffer{instance, scheduler, MemoryUsage::Stream, UboStreamBufferSize},
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer_cache.cpp:33:      download_buffer{instance, scheduler, MemoryUsage::Download, DownloadBufferSize},
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer_cache.cpp:34:      device_buffer{instance, scheduler, MemoryUsage::DeviceLocal, DeviceBufferSize},
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer_cache.cpp:35:      gds_buffer{instance, scheduler, MemoryUsage::Stream, 0, AllFlags, DataShareBufferSize},
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer_cache.cpp:36:      bda_pagetable_buffer{instance, scheduler, MemoryUsage::DeviceLocal,
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer_cache.cpp:583:        slot_buffers.insert(instance, scheduler, MemoryUsage::DeviceLocal, overlap.begin,
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer_cache.cpp:717:            std::make_unique<Buffer>(instance, scheduler, MemoryUsage::Upload, 0,
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer_cache.cpp:801:            instance, scheduler, MemoryUsage::Upload, 0, vk::BufferUsageFlagBits::eTransferSrc,
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer_cache.h:95:        if (usage == MemoryUsage::Stream) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer_cache.h:97:        } else if (usage == MemoryUsage::Download) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/buffer_cache.h:99:        } else if (usage == MemoryUsage::DeviceLocal) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/fault_manager.cpp:24:      fault_buffer{instance, scheduler, MemoryUsage::DeviceLocal, 0, AllFlags, fault_buffer_size},
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/buffer_cache/fault_manager.cpp:25:      download_buffer{instance, scheduler, MemoryUsage::Download,
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/texture_cache/texture_cache.cpp:30:      tile_manager{instance, scheduler, buffer_cache.GetUtilityBuffer(MemoryUsage::Stream)},
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/texture_cache/texture_cache.cpp:76:    auto& download_buffer = buffer_cache.GetUtilityBuffer(MemoryUsage::Download);
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/texture_cache/texture_cache.cpp:245:                const auto& copy_buffer = buffer_cache.GetUtilityBuffer(MemoryUsage::DeviceLocal);
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/host_shaders/StringShaderHeader.cmake:4:set(SOURCE_FILE ${CMAKE_ARGV3})
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/host_shaders/StringShaderHeader.cmake:5:set(HEADER_FILE ${CMAKE_ARGV4})
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/host_shaders/StringShaderHeader.cmake:6:set(INPUT_FILE ${CMAKE_ARGV5})
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/renderer_vulkan/vk_rasterizer.cpp:536:            buffer_cache.GetUtilityBuffer(VideoCore::MemoryUsage::DeviceLocal);
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/renderer_vulkan/vk_rasterizer.cpp:632:                auto& vk_buffer = buffer_cache.GetUtilityBuffer(VideoCore::MemoryUsage::Stream);
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/renderer_vulkan/vk_rasterizer.cpp:643:                    auto& vk_buffer = buffer_cache.GetUtilityBuffer(VideoCore::MemoryUsage::Stream);
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/renderer_vulkan/vk_rasterizer.cpp:663:                auto& lds_buffer = buffer_cache.GetUtilityBuffer(VideoCore::MemoryUsage::Stream);
/home/runner/work/_temp/hc-upstream/shadPS4/src/video_core/renderer_vulkan/vk_presenter.cpp:152:                 VideoCore::MemoryUsage::Download,
/home/runner/work/_temp/hc-upstream/shadPS4/src/imgui/big_picture/big_picture.cpp:195:                    if (const auto title_id = psf.GetString("TITLE_ID"); title_id.has_value()) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/imgui/big_picture/big_picture.cpp:196:                        icon.serial = *title_id;
/home/runner/work/_temp/hc-upstream/shadPS4/src/imgui/big_picture/big_picture.cpp:208:                icon.ebootPath = entry.path() / "eboot.bin";
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:277:        file /= "eboot.bin";
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:304:            archive_inner = "eboot.bin";
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:388:            const auto title_id = param_sfo->GetString("TITLE_ID");
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:391:            } else if (title_id.has_value()) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:392:                id = *title_id;
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:464:        LOG_CRITICAL(Loader, "eboot.bin does not exist: {}", guest_eboot_path);
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:527:        const auto argc = std::min<size_t>(args.size(), 32);
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:528:        for (auto i = 0; i < argc; i++) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:660:        LOG_CRITICAL(Loader, "Failed to load game's eboot.bin: {}", guest_eboot_path);
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:721:        if (!guest.empty() && guest != "eboot.bin") {
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:729:        auto game_path = mnt->GetHostPath("/app0");
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:735:        args.push_back(Common::FS::PathToUTF8String(game_path));
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:805:    std::vector<char*> argv;
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:808:    argv.push_back(const_cast<char*>(executableName));
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:811:        argv.push_back(const_cast<char*>(arg.c_str()));
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:813:    argv.push_back(nullptr);
/home/runner/work/_temp/hc-upstream/shadPS4/src/emulator.cpp:818:        execvp(executableName, argv.data());
/home/runner/work/_temp/hc-upstream/shadPS4/src/main.cpp:32:int main(int argc, char* argv[]) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/main.cpp:74:    app.add_option("guest_arg", gamePath, "Game path or ID"); // positional
/home/runner/work/_temp/hc-upstream/shadPS4/src/main.cpp:75:    app.add_option("-g,--game", gamePath, "Game path or ID");
/home/runner/work/_temp/hc-upstream/shadPS4/src/main.cpp:104:    if (argc == 1) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/main.cpp:117:        for (int i = 0; i < argc; i++) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/main.cpp:119:                gameArgs.emplace_back(argv[i]);
/home/runner/work/_temp/hc-upstream/shadPS4/src/main.cpp:121:            if (!double_dash_found && std::string(argv[i]) == "--") {
/home/runner/work/_temp/hc-upstream/shadPS4/src/main.cpp:128:        app.parse(double_dash_index, argv);
/home/runner/work/_temp/hc-upstream/shadPS4/src/main.cpp:139:    LOG_INFO(Debug, "Run: {}", std::span(argv, argc));
/home/runner/work/_temp/hc-upstream/shadPS4/src/main.cpp:160:        BigPictureMode::Launch(argv[0], sameProcess);
/home/runner/work/_temp/hc-upstream/shadPS4/src/main.cpp:184:            LOG_ERROR(Debug, "Please provide a game path or ID.");
/home/runner/work/_temp/hc-upstream/shadPS4/src/main.cpp:216:    // ---- Resolve game path or ID ----
/home/runner/work/_temp/hc-upstream/shadPS4/src/main.cpp:245:    emulator->executableName = argv[0];
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/linker.cpp:206:        // Add all guest arguments, we will always have the executable path in argv[0]
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/linker.cpp:208:        constexpr int MaxArgs = sizeof(params.argv) / sizeof(params.argv[0]);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/linker.cpp:209:        params.argc = std::min<int>(args.size(), MaxArgs);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/linker.cpp:210:        for (int i = 0; i < params.argc; i++) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/linker.cpp:211:            params.argv[i] = args[i].c_str();
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/linker.h:50:    int argc;
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/linker.h:52:    const char* argv[33];
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/devtools/widget/module_list.h:48:        if (name == "eboot.bin") {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/devtools/widget/imgui_memory_editor.h:14:// Usage:
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/devtools/widget/imgui_memory_editor.h:21:// Usage:
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/aerolib/aerolib.inl:29028:STUB("8lq3HM5y55s", monoeg_g_shell_parse_argv)
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/aerolib/aerolib.inl:45488:STUB("F-7nYSizbvc", g_shell_parse_argv)
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/aerolib/aerolib.inl:46437:STUB("FJmglmTMdr4", getargv)
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/aerolib/aerolib.inl:62765:    "LarGcv2d+lU",
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/aerolib/aerolib.inl:73911:STUB("PaG1xovlZvk", _ZN3JSC14ProtoCallFrame17setPaddedArgCountEj)
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/aerolib/aerolib.inl:104335:STUB("b-i3JSeZ12E", il2cpp_set_commandline_arguments_utf16)
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/aerolib/aerolib.inl:124239:STUB("iKJMWrAumPE", getargc)
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/aerolib/aerolib.inl:170576:STUB("zccQaiAKfeI", il2cpp_set_commandline_arguments)
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/module.cpp:342:        if (name == "eboot.bin") {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/dialog/savedatadialog_ui.h:263:    std::string title_id{};
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/dialog/savedatadialog_ui.cpp:78:        this->title_id = game_serial;
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/dialog/savedatadialog_ui.cpp:80:        this->title_id = item->titleId->data.to_string();
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/dialog/savedatadialog_ui.cpp:91:            auto dir_path = SaveInstance::MakeDirSavePath(user_id, title_id, dir_name);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/save_backup.h:35:    std::string title_id{};
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/save_backup.h:47:bool NewRequest(Libraries::UserService::OrbisUserServiceUserId user_id, std::string_view title_id,
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/save_backup.cpp:208:bool NewRequest(Libraries::UserService::OrbisUserServiceUserId user_id, std::string_view title_id,
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/save_backup.cpp:210:    auto save_path = SaveInstance::MakeDirSavePath(user_id, title_id, dir_name);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/save_backup.cpp:227:            .title_id = std::string{title_id},
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/save_instance.cpp:88:    P(String, SaveParams::TITLE_ID, std::move(game_serial));
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/save_instance.h:31:constexpr std::string_view TITLE_ID = "TITLE_ID";
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/savedata.cpp:370:                           std::string_view title_id = g_game_serial) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/savedata.cpp:383:            SaveInstance::MakeDirSavePath(mount_info->userId, title_id, mount_info->dirName->data);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/savedata.cpp:422:    SaveInstance save_instance{slot_num, mount_info->userId, std::string{title_id}, dir_name,
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/savedata.cpp:791:    const std::string_view title_id{cond->titleId == nullptr
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/savedata.cpp:794:    const auto save_path = SaveInstance::MakeTitleSavePath(cond->userId, title_id);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/savedata.cpp:829:        const auto dir_path = SaveInstance::MakeDirSavePath(cond->userId, title_id, dir_name);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/save_data/savedata.cpp:979:    event->titleId.data.FromString(last_event->title_id);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/system/systemservice.h:505:int PS4_SYSV_ABI sceSystemServiceLoadExec(const char* path, const char* argv[]);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/system/systemservice.cpp:1875:int PS4_SYSV_ABI sceSystemServiceLoadExec(const char* path, const char* argv[]) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/system/systemservice.cpp:1895:    if (argv != nullptr) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/system/systemservice.cpp:1896:        for (const char** ptr = argv; *ptr != nullptr; ptr++) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/np/np_error.h:32:constexpr int ORBIS_NP_ERROR_INCONSISTENT_NP_TITLE_ID = 0x80550017;
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/np/np_error.h:36:constexpr int ORBIS_NP_ERROR_TITLE_ID_IN_PARAM_SFO_NOT_MATCHED_TO_NP_TITLE_ID = 0x8055001B;
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/np/np_error.h:37:constexpr int ORBIS_NP_ERROR_TITLE_ID_IN_PARAM_SFO_NOT_EXIST = 0x8055001C;
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/np/np_error.h:39:constexpr int ORBIS_NP_ERROR_INVALID_NP_TITLE_ID = 0x8055001E;
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/np/np_error.h:373:constexpr int ORBIS_NP_TROPHY_ERROR_INVALID_NP_TITLE_ID = 0x80551620;
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/np/np_manager.cpp:765:s32 PS4_SYSV_ABI sceNpSetNpTitleId(const OrbisNpTitleId* title_id,
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/np/np_manager.cpp:767:    if (title_id == nullptr || title_secret == nullptr) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/np/np_manager.cpp:771:    LOG_ERROR(Lib_NpManager, "(STUBBED) called, title_id = {}", title_id->id);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule_internal.h:15:s32 loadModuleInternal(s32 index, s32 argc, const void* argv, s32* res_out);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule_internal.h:16:s32 loadModule(s32 id, s32 argc, const void* argv, s32* res_out);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule_internal.h:17:s32 unloadModule(s32 id, s32 argc, const void* argv, s32* res_out, bool is_internal);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule.cpp:121:s32 PS4_SYSV_ABI sceSysmoduleLoadModuleInternalWithArg(OrbisSysModuleInternal id, s32 argc,
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule.cpp:122:                                                       const void* argv, u64 unk, s32* res_out) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule.cpp:134:    return loadModule(id, argc, argv, res_out);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule_internal.cpp:120:s32 loadModuleInternal(s32 index, s32 argc, const void* argv, s32* res_out) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule_internal.cpp:137:        s32 result = linker->LoadAndStartModule(guest_path, argc, argv, &start_result);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule_internal.cpp:197:                s32 handle = linker->LoadAndStartModule(game_specific_module_path, argc, argv,
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule_internal.cpp:257:            s32 handle = linker->LoadAndStartModule(module_path, argc, argv, &start_result);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule_internal.cpp:288:s32 loadModule(s32 id, s32 argc, const void* argv, s32* res_out) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule_internal.cpp:324:            result = loadModuleInternal(mod_index, argc, argv, res_out);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule_internal.cpp:335:s32 unloadModule(s32 id, s32 argc, const void* argv, s32* res_out, bool is_internal) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule.h:28:s32 PS4_SYSV_ABI sceSysmoduleLoadModuleInternalWithArg(OrbisSysModuleInternal id, s32 argc,
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/sysmodule/sysmodule.h:29:                                                       const void* argv, u64 unk, s32* res_out);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/kernel/kernel.cpp:47:static const char* g_progname = "eboot.bin";
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/kernel/kernel.cpp:250:s32 PS4_SYSV_ABI getargc() {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/kernel/kernel.cpp:251:    return entry_params.argc;
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/kernel/kernel.cpp:254:const char** PS4_SYSV_ABI getargv() {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/kernel/kernel.cpp:255:    return entry_params.argv;
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/kernel/kernel.cpp:521:    LIB_FUNCTION("iKJMWrAumPE", "libkernel", 1, "libkernel", getargc);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/kernel/kernel.cpp:522:    LIB_FUNCTION("FJmglmTMdr4", "libkernel", 1, "libkernel", getargv);
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/app_content/app_content.cpp:36:static std::string title_id;
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/app_content/app_content.cpp:64:    const auto& addon_path = EmulatorSettings.GetAddonInstallDir() / title_id;
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/app_content/app_content.cpp:296:    if (const auto value = param_sfo->GetString("TITLE_ID"); value.has_value()) {
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/app_content/app_content.cpp:297:        title_id = *value;
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/app_content/app_content.cpp:299:        UNREACHABLE_MSG("Failed to get TITLE_ID");
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/libraries/app_content/app_content.cpp:301:    const auto addon_path = addons_dir / title_id;
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/ipc/ipc.cpp:65: *   - RESTART(argn: number, argv: ...string): Request restart of the emulator, must call STOP
/home/runner/work/_temp/hc-upstream/shadPS4/src/core/file_format/psf.cpp:16:    {"SUBTITLE", 128},  {"TITLE_ID", 12},
/home/runner/work/_temp/hc-upstream/shadPS4/src/shader_recompiler/ir/ir_emitter.cpp:2152:// Example usage:
```

### Config / preferences symbols
```text
/home/runner/work/_temp/hc-upstream/shadPS4/documents/Debugging/Debugging.md:56:You can configure the emulator by editing the `config.json` file found in the `user` folder created after starting the application.
/home/runner/work/_temp/hc-upstream/shadPS4/documents/building-linux.md:118:You can also specify the Game ID as an argument for which game to boot, as long as the folder containing the games is specified in config.toml (example: Bloodborne (US) is CUSA00900).
/home/runner/work/_temp/hc-upstream/shadPS4/documents/patching-shader.md:8:1. Enable `dumpShaders` in config.toml
/home/runner/work/_temp/hc-upstream/shadPS4/documents/patching-shader.md:19:6. Enable `patchShaders` in config.toml
/home/runner/work/_temp/hc-upstream/shadPS4/tests/test_emulator_settings.cpp:115:        return temp_dir->path() / "config.json";
/home/runner/work/_temp/hc-upstream/shadPS4/tests/test_emulator_settings.cpp:286:// tests for global config.json file
/home/runner/work/_temp/hc-upstream/shadPS4/tests/test_emulator_settings.cpp:824:    EXPECT_EQ(t0, t1) << "Destructor wrote config.json without a prior Load()";
/home/runner/work/_temp/hc-upstream/shadPS4/tests/test_windows_guest_red_zone_protection_settings.cpp:128:    std::ofstream output(root / "config.json");
/home/runner/work/_temp/hc-upstream/shadPS4/CMakeLists.txt:1273:target_compile_definitions(shadps4 PRIVATE IMGUI_USER_CONFIG="imgui/imgui_config.h")
/home/runner/work/_temp/hc-upstream/shadPS4/CMakeLists.txt:1274:target_compile_definitions(Dear_ImGui PRIVATE IMGUI_USER_CONFIG="${PROJECT_SOURCE_DIR}/src/imgui/imgui_config.h")
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:60:STUB("+-wmVyLhgm0", WKPreferencesSetStandardFontFamily)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:91:STUB("+0rdnkSicqk", WKPreferencesGetApplicationChromeModeEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:130:STUB("+1n+h4FUu9E", WKPreferencesSetAutostartOriginPlugInSnapshottingEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:192:STUB("+31dbB3S-6Y", WKPreferencesResetTestRunnerOverrides)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:286:STUB("+5E2YZZIstM", WKPreferencesSetContentChangeObserverEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:726:STUB("+FvUhrQaiJQ", WKPreferencesSetCanvasUsesAcceleratedDrawing)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:900:STUB("+Kx-IV+21hk", WKPreferencesGetCaptureVideoInUIProcessEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:2003:STUB("+mEF2auHNt4", WKPreferencesGetDoNotTrack)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:2107:STUB("+oJHrfcyJJM", WKPreferencesGetLocalFileContentSniffingEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:2590:STUB("+ysk-pa6aOA", _ZN12video_parser5vpcom3rtc20FormatSQLiteDateTimeEPcmPKmc)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:2834:STUB("-2HpFPXUzqw", WKPreferencesGetForceSoftwareWebGLRendering)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:3293:STUB("-CdmI7pz6Uk", WKPreferencesSetFullScreenEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:3304:STUB("-D-Dsk4CZXA", _ZN7WebCore29SQLiteStatementAutoResetScopeD1Ev)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:3779:STUB("-OrgQoBbx8M", _ZN7WebCore14SQLiteDatabase29setIsDatabaseOpeningForbiddenEb)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:3957:STUB("-RWsM4pVi0E", WKPreferencesSetNewBlockInsideInlineModelEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:4869:STUB("-n7NBjjuabo", sqlite3_column_text)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:4925:STUB("-pAtC74McJ8", WKPreferencesSetIntersectionObserverEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:5348:STUB("-yzOAodX+nQ", mono_aot_Sce_Vsh_SQLiteunbox_trampolines)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:5445:STUB("0-24WRoyyAg", sqlite3_extended_result_codes)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:5468:STUB("0-ZdVDOV+Yc", _ZN7WebCore15SQLiteStatement8finalizeEv)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:5649:STUB("03w8Wi7eD-A", sqlite3_step)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:5818:    _ZN7WebCore15SQLiteStatement21getColumnBlobAsVectorEiRN3WTF6VectorIcLm0ENS1_15CrashOnOverflowELm16ENS1_10FastMallocEEE)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:5894:STUB("0Aqqie4gXEY", WKPreferencesGetHiddenPageCSSAnimationSuspensionEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:6078:STUB("0FK6kbZvcvA", WKPreferencesGetSnapshotAllPlugIns)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:6463:STUB("0OQm7EIMZUs", WKPreferencesSetMediaControlsScaleWithPageZoom)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:6474:STUB("0OeraXVXfzM", sqlite3_sql)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:6587:STUB("0RY1ClbavWY", WKPreferencesSetCaptureAudioInUIProcessEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:6720:STUB("0Uek9fMv9z4", sqlite3_result_error)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:6757:STUB("0W5pY+f2e8M", _ZN7WebCore16SQLiteFileSystem28deleteEmptyDatabaseDirectoryERKN3WTF6StringE)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:7000:STUB("0bkH4IQFtTc", WKPreferencesSetSimpleLineLayoutDebugBordersEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:7035:STUB("0cPhfQ0yQfo", WKPreferencesGetHiddenPageDOMTimerThrottlingAutoIncreases)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:7150:STUB("0ezpnHVyg+s", WKPreferencesGetImageControlsEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:7293:STUB("0iEGz7pB0ZI", WKPreferencesGetFrameFlatteningEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:7815:STUB("0vAS7bEXO7k", WKPreferencesGetShowsToolTipOverTruncatedText)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:7949:STUB("0y370-q87ug", sqlite3_column_type)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:8049:STUB("1+FCJWJHZCU", WKPreferencesGetShouldRespectImageOrientation)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:8184:STUB("11VA62-jFjU", WKPreferencesSetCompositingRepaintCountersVisible)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:8386:STUB("15rPAIJU2YE", WKPreferencesGetStorageAccessAPIEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:8579:STUB("1B8WzbZ9TiA", WKPreferencesGetInactiveMediaCaptureSteamRepromptIntervalInMinutes)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:8817:STUB("1HJmJsAhIVU", _ZN7WebCore15SQLiteStatement8bindNullEi)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:9182:STUB("1Q-ExO66G94", WKPreferencesSetEncryptedMediaAPIEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:9296:STUB("1TOp3pCsV7A", WKPreferencesSetImageControlsEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:9633:STUB("1bGjhJ77Y-s", WKPreferencesGetPrivateBrowsingEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:9665:STUB("1c-lvc-RwAQ", WKPreferencesGetMinimumFontSize)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:10787:STUB("20ncFey1XAg", mono_aot_Sce_Vsh_SQLiteAuxmethod_addresses)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:11860:STUB("2QhFHIOZPNM", WKPreferencesSetWebAuthenticationLocalAuthenticatorEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:12200:STUB("2Yc8JPHyUSY", _ZN7WebCore15SQLiteStatementC1ERNS_14SQLiteDatabaseERKN3WTF6StringE)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:12813:STUB("2lbt196v3R8", WKPreferencesSetStorageAccessPromptsEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:13342:STUB("2y+gxwVZqtA", mono_aot_Sce_Vsh_SQLiteAuxjit_code_end)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:13381:STUB("2yorpzmHA-w", _ZN7WebCore17SQLiteTransactionC1ERNS_14SQLiteDatabaseEb)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:15375:STUB("3hRFngR3flU", _ZN7WebCore15SQLiteStatement9bindInt64Eil)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:15825:STUB("3sTGJxsk2tM", WKPreferencesSetTelephoneNumberParsingEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:15891:STUB("3uGJ6hKMv6Y", WKPreferencesGetSmartInsertDeleteEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:15994:STUB("3wxAGOWA5rw", WKPreferencesSetSimpleLineLayoutEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:16009:STUB("3xgqVi8Gd4g", WKPreferencesSetAsynchronousPluginInitializationEnabledForAllPlugins)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:16170:STUB("4-30FU3BDs0", WKPreferencesGetFetchAPIEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:17023:STUB("4JiFsEs9Yyw", WKPreferencesSetFetchAPIEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:17539:STUB("4WLw+JZeJLA", WKPreferencesSetMediaPlayable)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:17797:STUB("4cWxMuvkAVE", WKPreferencesGetCanvasUsesAcceleratedDrawing)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:18323:STUB("4oRem-AuOiA", _ZN7WebCore14SQLiteDatabase4openERKN3WTF6StringENS0_8OpenModeE)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:18372:STUB("4qCJAabaQ6A", WKPreferencesGetIntersectionObserverEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:18465:STUB("4rxJYR2IbIU", WKPreferencesSetMediaStreamEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:18502:STUB("4tMXLC7QwyM", WKPreferencesGetUserTimingEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:18865:STUB("5-ulmjWNkbQ", WKPreferencesSetShouldRespectImageOrientation)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:20306:STUB("5Xbk73Dvu8E", WKPreferencesGetWebAnimationsEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:20322:STUB("5XzzJSlUM8w", WKPreferencesGetDefaultFixedFontSize)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:20384:STUB("5Z7z4XjqxcA", _ZN7WebCore29SQLiteStatementAutoResetScopeaSEOS0_)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:20809:STUB("5i4G0Dch02o", mono_aot_Sce_Vsh_SQLiteunbox_trampolines_end)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:20851:STUB("5iypqrWVS40", _ZN12video_parser5vpcom3rtc19ParseSQLiteDateTimeEPmPKc)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:20928:STUB("5kt-2P9eBgc", _ZN7WebCore14SQLiteDatabase22disableThreadingChecksEv)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:21369:STUB("5xDT5s6gCgg", sqlite3_column_name16)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:22059:STUB("6BA6o6hUoTI", WKPreferencesGetJavaScriptMarkupEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:22933:STUB("6W+ovJY9kVo", _ZN7WebCore15SQLiteStatementD2Ev)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:23258:STUB("6dlDe+C9aGk", WKPreferencesSetCSSOMViewScrollingAPIEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:23296:STUB("6ebqMkrKndk", WKPreferencesSetTextAutosizingUsesIdempotentMode)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:23435:STUB("6hfyVLzdy9I", WKPreferencesSetShouldDisplaySubtitles)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:23502:STUB("6jAtbdWXPBw", WKPreferencesGetMediaDevicesEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:23534:STUB("6jkxaKVf01A", WKPreferencesSetQTKitEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:23972:STUB("6sI08fxTRDQ", WKPreferencesSetFrameFlatteningEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:24042:STUB("6u-wDQcw7aM", WKPreferencesSetDefaultFontSize)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:24140:STUB("6x-luKeSQNg", WKPreferencesGetAsynchronousPluginInitializationEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:24201:STUB("6yMnkmRUIKA", WKPreferencesSetMediaDevicesEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:24262:STUB("6zJNbo2nyk4", mono_aot_Sce_Vsh_SQLiteAuxjit_got)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:24424:STUB("71eCBabjnWU", sqlite3_value_type)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:24482:STUB("72wZB0MqDcg", sqlite3_wal_hook)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:24955:STUB("7EAqBtDmsgw", mono_aot_Sce_Vsh_SQLiteAuxunbox_trampoline_addresses)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:25713:STUB("7Wb0Jv2wCO0", sqlite3_bind_int)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:26072:STUB("7dqSnW4K+ok", WKPreferencesSetSubpixelCSSOMElementMetricsEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:26452:STUB("7lu35eETqeQ", WKPreferencesSetWebShareEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:26596:STUB("7pEKaQB9TYI", WKPreferencesSetAntialiasedFontDilationEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:26759:     _ZN7WebCore14SQLiteDatabase20setCollationFunctionERKN3WTF6StringEONS1_8FunctionIFiiPKviS7_EEE)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:27113:STUB("812ErfQJ70Q", WKPreferencesGetLargeImageAsyncDecodingEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:27122:STUB("81MD+QADYBA", _ZN7WebCore17SQLiteTransactionC2ERNS_14SQLiteDatabaseEb)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:27539:STUB("8AgQaMFPjgk", WKPreferencesSetIsNSURLSessionWebSocketEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:27675:STUB("8EQ1k-45LF0", WKPreferencesSetCaptureAudioInGPUProcessEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:28017:STUB("8N-4nYLwXak", WKPreferencesGetQTKitEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:28765:STUB("8eYzxmkntIw", WKPreferencesGetShouldUseServiceWorkerShortTimeout)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:29004:STUB("8lA9lXh0Jfk", WKPreferencesGetAutostartOriginPlugInSnapshottingEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:29032:STUB("8m8-UQTKyUc", _ZN7WebCore14SQLiteDatabase9interruptEv)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:29057:STUB("8miuoqRKhec", mono_aot_Sce_Vsh_SQLitemethod_addresses)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:29147:STUB("8ozlDe1o-ok", WKPreferencesGetIsAccessibilityIsolatedTreeEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:29323:STUB("8sN4TdPfvNI", WKPreferencesGetAntialiasedFontDilationEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:29375:STUB("8tE06sxxee8", _ZNK7WebCore15SQLiteStatement18bindParameterCountEv)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:29521:STUB("8xcXCQYNlCQ", WKPreferencesGetUserInterfaceDirectionPolicy)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:29534:STUB("8y1Cv7BS6dg", sqlite3_data_count)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:29572:STUB("8z5gjWiHnvA", WKPreferencesGetWebRTCLegacyAPIEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:29812:STUB("92RMcC5IfeE", sqlite3_bind_parameter_count)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:29977:STUB("96iwUEq1jKY", _ZN7WebCore14SQLiteDatabase9lastErrorEv)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:30921:STUB("9SRRU8yTt04", sqlite3_user_data)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:31215:STUB("9ZqL5WUiiXw", WKPreferencesSetInteractiveFormValidationEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:31425:STUB("9ej2hBD+fc0", WKPreferencesGetSelectionPaintingWithoutSelectionGapsEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:31703:STUB("9ltF1xBh8u0", WKPreferencesSetJavaEnabledForLocalFiles)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:33981:STUB("AcgrOfh90VA", WKPreferencesGetCrossOriginWindowPolicyEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:34199:STUB("AiXfM7pAAgo", WKPreferencesSetFantasyFontFamily)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:34245:STUB("Ak7b6A9cJvc", WKPreferencesSetShouldDisplayCaptions)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:34410:STUB("AnQQM55IXDQ", sqlite3_column_int)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:34741:STUB("Aw2xTP5uAG0", WKPreferencesSetWebArchiveDebugModeEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:35100:STUB("B35ZcgDNE60", WKPreferencesGetMediaPlayable)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:35168:STUB("B5Z6xoZd+YY", WKPreferencesSetMultithreadedWebGLEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:35216:STUB("B6gqPm8EtR8", _ZN7WebCore14SQLiteDatabaseC2Ev)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:35256:STUB("B7ciVXz8B14", WKPreferencesSetInlineMediaPlaybackRequiresPlaysInlineAttribute)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:35277:STUB("B8-G2Ok8Wrk", WKPreferencesGetSubpixelAntialiasedLayerTextEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:35406:STUB("BBJoU2m+U88", WKPreferencesGetDiagnosticLoggingEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:35467:STUB("BCcUsMKVXRA", WKPreferencesSetIsAccessibilityIsolatedTreeEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:35868:STUB("BMP8b5t9wPM", WKPreferencesSetCookieEnabled)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:35994:STUB("BPidIRvnZRQ", WKPreferencesSetResourceUsageOverlayVisible)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:36853:STUB("Bkpc599WnwA", sqlite3_value_bytes)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:37093:STUB("BqfBIchFGgY", _ZN7WebCore15SQLiteStatement12isColumnNullEi)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:37109:STUB("BquE5qCYVGw", WKPreferencesSetMediaContentTypesRequiringHardwareSupport)
/home/runner/work/_temp/hc-upstream/shadPS4/scripts/aerolib.inl:37180:STUB("BtHxQ6Pv6fk", _ZN7WebCore16SQLiteFileSystem24databaseModificationTimeERKN3WTF6StringE)
```

## Vita3K

Upstream commit: `496939b602703951277263c7b3e60a9ae36879c1`

### CLI / launch / content symbols
```text
/home/runner/work/_temp/hc-upstream/Vita3K/CMakeLists.txt:39:	string(APPEND CMAKE_CXX_FLAGS " -Wl,-Bsymbolic -Wno-unused-command-line-argument")
/home/runner/work/_temp/hc-upstream/Vita3K/CMakeLists.txt:40:	string(APPEND CMAKE_C_FLAGS " -Wl,-Bsymbolic -Wno-unused-command-line-argument")
/home/runner/work/_temp/hc-upstream/Vita3K/building.md:5:The project provides [CMake presets](https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html) to allow configuring and building Vita3K without having to deal with adding the needed arguments through a command-line interface or using the user interface of your IDE. As long as your IDE or code editor supports CMake, the software should immediately detect the presets and let you choose which configuration settings you want to use to generate the program. Reference on how to use CMake presets with various IDEs and code editors can be found here:
/home/runner/work/_temp/hc-upstream/Vita3K/building.md:11:All presets are named after `<target_os>-<project_generator>-<compiler>`, are automatically hidden and shown depending on your host OS and generate a binary folder of path `<source_directory>/build/<preset_name>`. For command-line users, run `cmake --list-presets` on the top directory of the repository to see which presets are available to you. For presets without `<project_generator>` and/or `<compiler>`, the project generator and/or the compiler haven't been explicitly specified in the preset to let CMake fallback to the platform defaults.
/home/runner/work/_temp/hc-upstream/Vita3K/building.md:162:- Building can be done with Android studio: select the Vita3K Android folder and click on the build icon or by command line:
/home/runner/work/_temp/hc-upstream/Vita3K/android/gradlew.bat:68:@rem Setup the command line
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/Emulator.java:71:    public static final String EXTRA_TITLE_ID = "title_id";
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/Emulator.java:108:            intent.putExtra(EXTRA_TITLE_ID, titleId);
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/Emulator.java:178:        // Check for title_id from MainActivity launch
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/Emulator.java:179:        String titleId = intent.getStringExtra(EXTRA_TITLE_ID);
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/Emulator.java:1172:        String titleId = intent.getStringExtra(EXTRA_TITLE_ID);
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/ui/navigation/AppNavigation.kt:56:private const val ARG_TITLE_ID = "titleId"
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/ui/navigation/AppNavigation.kt:352:                navArgument(ARG_TITLE_ID) { type = NavType.StringType },
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/ui/navigation/AppNavigation.kt:359:            val titleId = backStackEntry.arguments?.getString(ARG_TITLE_ID).orEmpty()
/home/runner/work/_temp/hc-upstream/Vita3K/android/gradlew:28:#       command line, like:
/home/runner/work/_temp/hc-upstream/Vita3K/android/gradlew:158:#   * args from the command line
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/emuenv/include/emuenv/app_launch_request.h:32:    std::vector<std::string> argv{};
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/emuenv/include/emuenv/state.h:125:    std::string license_title_id{};
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/io/include/io/functions.h:53: * @param app_title_id App title ID (`PCSXXXXXX`)
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/io/include/io/functions.h:58:bool copy_path(const fs::path &src_path, const fs::path &vita_fs_path, const std::string &app_title_id, const std::string &app_category);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/io/include/io/state.h:111:    std::string title_id;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/io/src/io.cpp:147:    io.title_id.clear();
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/io/src/io.cpp:168:    const fs::path savedata_game_path{ savedata_path / io.savedata };
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/io/src/io.cpp:172:    fs::create_directories(savedata_game_path);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/io/src/io.cpp:232:    case VitaIoDevice::savedata0: // Redirect savedata0: to ux0:user/00/savedata/<title_id>
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/io/src/io.cpp:238:    case VitaIoDevice::app0: { // Redirect app0: to ux0:app/<title_id>
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/io/src/io.cpp:243:    case VitaIoDevice::addcont0: { // Redirect addcont0: to ux0:addcont/<title_id>
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/io/src/io.cpp:785:bool copy_path(const fs::path &src_path, const fs::path &vita_fs_path, const std::string &app_title_id, const std::string &app_category) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/io/src/io.cpp:788:        const auto app_path{ vita_fs_path / "ux0/app" / app_title_id };
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceProcessmgr/SceProcessmgr.cpp:145:EXPORT(int, sceKernelGetProcessTitleId, char *title_id, uint32_t len) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceProcessmgr/SceProcessmgr.cpp:146:    TRACY_FUNC(sceKernelGetProcessTitleId, title_id, len);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceProcessmgr/SceProcessmgr.cpp:147:    if (!title_id || len > 32 || len == 0)
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceProcessmgr/SceProcessmgr.cpp:149:    strncpy(title_id, emuenv.io.title_id.c_str(), len);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/module_parent.cpp:233:        SceUID module_id = load_self(emuenv.kernel, emuenv.mem, module_data, module_path, emuenv.log_path / "elfdumps" / emuenv.io.title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/module_parent.cpp:300:    module_buffer = decrypt_fself(module_buffer, emuenv.license.rif[emuenv.io.title_id].key);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceAppUtil/SceAppUtil.cpp:154:    *value = emuenv.license.rif[emuenv.io.title_id].sku_flag;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceDisplay/SceDisplay.cpp:96:        auto &title_id = emuenv.io.title_id;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceDisplay/SceDisplay.cpp:97:        bool cond = (title_id == "PCSG80001")
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceDisplay/SceDisplay.cpp:98:            || (title_id == "PCSG80007")
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceDisplay/SceDisplay.cpp:99:            || (title_id == "PCSG00318")
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceDisplay/SceDisplay.cpp:100:            || (title_id == "PCSG00319")
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceDisplay/SceDisplay.cpp:101:            || (title_id == "PCSG00320")
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceDisplay/SceDisplay.cpp:102:            || (title_id == "PCSG00321")
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceDisplay/SceDisplay.cpp:103:            || (title_id == "PCSH00059");
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/taiHEN/taiHEN.cpp:1370:    // Note: we only load_module here. start_module is called by run_app()
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceDriverUser/SceAppMgrUser.cpp:461:EXPORT(SceInt32, sceAppMgrLoadExec, const char *appPath, Ptr<char> const argv[], const SceAppMgrLoadExecOptParam *optParam) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceDriverUser/SceAppMgrUser.cpp:462:    TRACY_FUNC(sceAppMgrLoadExec, appPath, argv, optParam);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceDriverUser/SceAppMgrUser.cpp:463:    return CALL_EXPORT(_sceAppMgrLoadExec, appPath, argv, optParam);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceDriverUser/SceAppMgrUser.h:25:SceInt32 sceAppMgrLoadExec(const char *appPath, char *const argv[], const SceAppMgrLoadExecOptParam *optParam);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceAppMgr/SceAppMgr.cpp:407:EXPORT(SceInt32, _sceAppMgrLoadExec, const char *appPath, Ptr<char> const argv[], const SceAppMgrLoadExecOptParam *optParam) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceAppMgr/SceAppMgr.cpp:408:    TRACY_FUNC(_sceAppMgrLoadExec, appPath, argv, optParam);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceAppMgr/SceAppMgr.cpp:424:        std::vector<std::string> exec_argv;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceAppMgr/SceAppMgr.cpp:425:        if (argv && argv->get(emuenv.mem)) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceAppMgr/SceAppMgr.cpp:427:            for (auto i = 0; argv[i]; i++) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceAppMgr/SceAppMgr.cpp:428:                const char *arg = argv[i].get(emuenv.mem);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceAppMgr/SceAppMgr.cpp:431:                exec_argv.emplace_back(arg);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceAppMgr/SceAppMgr.cpp:435:                return RET_ERROR(SCE_APPMGR_ERROR_TOO_LONG_ARGV);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceAppMgr/SceAppMgr.cpp:438:        emuenv.kernel.request_process_exit(0, AppLaunchRequest{ .app_path = emuenv.io.app_path, .self_path = std::move(exec_path), .argv = std::move(exec_argv), .reason = AppLaunchReason::LoadExec });
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceAppMgr/SceAppMgr.h:29:    SCE_APPMGR_ERROR_TOO_LONG_ARGV = 0x8080201D, //!< argv is too long
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceAppMgr/SceAppMgr.h:66:DECL_EXPORT(SceInt32, _sceAppMgrLoadExec, const char *appPath, Ptr<char> const argv[], const SceAppMgrLoadExecOptParam *optParam);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceAppMgr/SceAppMgr.h:70:SceInt32 _sceAppMgrLoadExec(const char *appPath, char *const argv[], const SceAppMgrLoadExecOptParam *optParam);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/vkutil/include/vkutil/vkutil.h:168:    .usage = vma::MemoryUsage::eAuto
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/vkutil/include/vkutil/vkutil.h:173:    .usage = vma::MemoryUsage::eAuto,
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/vkutil/include/vkutil/vkutil.h:179:    .usage = vma::MemoryUsage::eAuto,
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/patch/src/patch.cpp:42:                "eboot.bin"
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/CMakeLists.txt:184:			"libboost_program_options.a"
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/include/gui-qt/main_window.h:101:    void show_live_area(const std::string &title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/include/gui-qt/main_window.h:126:    void boot_game(const std::string &title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/include/gui-qt/main_window.h:196:    std::string m_live_area_title_id;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/include/gui-qt/archive_install_dialog.h:32:    QString title_id;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/include/gui-qt/pkg_install_dialog.h:64:    void install_complete(const QString &title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/include/gui-qt/apps_list_columns.h:65:    case AppsListColumn::TitleId: return QStringLiteral("title_id");
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:582:    if (emuenv.cfg.run_app_path.has_value()) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:584:            const std::string title_id = *emuenv.cfg.run_app_path;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:585:            emuenv.cfg.run_app_path.reset();
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:586:            boot_game(title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:870:        show_live_area(app.title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:872:        boot_game(app.title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:875:void MainWindow::boot_game(const std::string &title_id) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:877:        .app_path = title_id,
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:941:                QString::fromStdString(emuenv.io.title_id)));
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:998:                QString::fromStdString(emuenv.io.title_id)));
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1007:                QString::fromStdString(emuenv.io.title_id)));
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1042:                QString::fromStdString(emuenv.io.title_id)));
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1181:void MainWindow::show_live_area(const std::string &title_id) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1185:    if (!app::set_app_info(emuenv, title_id)) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1187:            tr("Could not find app '%1' in apps list.").arg(QString::fromStdString(title_id)));
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1191:    app::set_current_config(emuenv, title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1192:    get_license(emuenv, emuenv.io.title_id, emuenv.io.content_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1193:    app::update_last_time_app_used(emuenv, title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1194:    m_live_area_title_id = title_id;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1202:                QString::fromStdString(emuenv.io.title_id)));
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1219:    const auto title_id = m_live_area_title_id;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1220:    m_live_area_title_id.clear();
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1221:    boot_game(title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1230:    m_live_area_title_id.clear();
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1718:        if (app && !app->title_id.empty()) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1720:                show_live_area(app->title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1722:                boot_game(app->title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1728:    m_app_selected = app && !app->title_id.empty();
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1737:            boot_game(app.title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:1741:            show_live_area(app.title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/main_window.cpp:2139:        discordrpc::update_presence(emuenv.io.title_id, emuenv.current_app_title);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/pkg_install_dialog.cpp:305:            const QString title_id = QString::fromStdString(m_emuenv.app_info.app_title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/pkg_install_dialog.cpp:308:                tr("Installation complete!\n\n%1 [%2]").arg(app_title, title_id),
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/pkg_install_dialog.cpp:324:                [this, del_pkg, del_bin, pkg_path, title_id]() {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/pkg_install_dialog.cpp:345:                    Q_EMIT install_complete(title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/license_install_dialog.cpp:77:                QString::fromStdString(m_emuenv.license_title_id)));
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/license_install_dialog.cpp:108:                QString::fromStdString(m_emuenv.license_title_id)));
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/archive_install_dialog.cpp:99:    if (!result.title_id.isEmpty())
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/archive_install_dialog.cpp:100:        meta_parts.push_back(result.title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/archive_install_dialog.cpp:150:                r.title_id = QString::fromStdString(info.title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/archive_install_dialog.cpp:311:    const ReinstallCallback reinstall_cb = [this](const std::string &title, const std::string &title_id) -> bool {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/archive_install_dialog.cpp:314:        const QString title_id_qt = QString::fromStdString(title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/archive_install_dialog.cpp:316:            ? title_id_qt
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/archive_install_dialog.cpp:317:            : tr("%1 [%2]").arg(title_qt, title_id_qt);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_table.cpp:383:            new SortableItem(QString::fromStdString(app.title_id)));
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_table.cpp:390:        if (const auto it = compat.app_compat_db.find(app.title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/game_window.cpp:544:        m_emuenv.current_app_title, m_emuenv.io.title_id,
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:133:    const auto &title_id = app.title_id;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:137:        .patch = m_emuenv.shared_path / "patch" / title_id,
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:139:        .license = m_emuenv.vita_fs_path / "ux0/license" / title_id,
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:140:        .shader_cache = m_emuenv.cache_path / "shaders" / title_id,
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:141:        .shader_log = m_emuenv.cache_path / "shaderlog" / title_id,
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:142:        .shader_log_alt = m_emuenv.log_path / "shaderlog" / title_id,
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:143:        .export_textures = m_emuenv.shared_path / "textures/export" / title_id,
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:144:        .import_textures = m_emuenv.shared_path / "textures/import" / title_id,
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:172:            const auto path = m_emuenv.cache_path / "shaders" / app->title_id;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:200:    const auto &title_id = app.title_id;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:201:    const bool is_commercial = title_id.starts_with("PCS") || (title_id == "NPXS10007");
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:203:        && m_emuenv.compat.app_compat_db.contains(title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:205:        ? m_emuenv.compat.app_compat_db.at(title_id).state
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:212:        connect(check, &QAction::triggered, this, [title_id, &app] {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:213:            const std::string url = title_id.starts_with("PCS")
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:214:                ? "https://vita3k.org/compatibility?g=" + title_id
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:225:            const auto &compat_entry = m_emuenv.compat.app_compat_db.at(title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:273:            connect(create_report, &QAction::triggered, this, [this, &app, title_id] {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:281:                    app.title, title_id, app.app_ver);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:323:                    ISSUES_URL, title.toStdString(), title_id,
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:347:            QString::fromStdString(fmt::format("{} [{}]", app.title, app.title_id)));
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:357:        QApplication::clipboard()->setText(QString::fromStdString(app.title_id));
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:364:            app.title, app.title_id, app.app_ver);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:472:                    QString::fromStdString(app.title_id)),
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:594:    const auto &title_id = app.title_id;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:599:    connect(decrypt, &QAction::triggered, this, [this, &app, title_id] {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:600:        if (!m_emuenv.license.rif.contains(title_id))
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:601:            get_license(m_emuenv, title_id, app.content_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:602:        decrypt_selfs(m_paths.app, m_emuenv.cache_path, m_emuenv.license.rif[title_id].key);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:693:            && m_emuenv.compat.app_compat_db.contains(app.title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:695:            ? m_emuenv.compat.app_compat_db.at(app.title_id).state
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/apps_list_context_menu.cpp:718:        add_row(tr("Serial"), QString::fromStdString(app.title_id));
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/gui-qt/src/settings_dialog.cpp:144:            if (app.title_id == m_app_path) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/renderer/include/renderer/state.h:233:    void set_app(const char *title_id, const char *self_name) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/renderer/include/renderer/state.h:234:        shaders_path = cache_path / "shaders" / title_id / self_name;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/renderer/include/renderer/state.h:235:        shaders_log_path = log_path / "shaderlog" / title_id / self_name;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/renderer/src/vulkan/renderer.cpp:1403:            .usage = vma::MemoryUsage::eAutoPreferHost,
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/main_android.cpp:236:// argv is populated from Emulator.getArguments(), e.g. {"-r", "PCSE00000"}.
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/main_android.cpp:237:SDLMAIN_DECLSPEC int SDL_main(int argc, char *argv[]) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/main_android.cpp:238:    std::string title_id;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/main_android.cpp:239:    for (int i = 0; i < argc; i++) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/main_android.cpp:240:        if (std::string(argv[i]) == "-r" && i + 1 < argc) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/main_android.cpp:241:            title_id = argv[i + 1];
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/main_android.cpp:246:    if (title_id.empty()) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/main_android.cpp:296:        .app_path = title_id,
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/native_config.cpp:675:Java_org_vita3k_emulator_NativeLib_saveSettings(JNIEnv *env, jclass, jstring title_id_str, jobject config_obj) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/native_config.cpp:684:    const std::string title_id = title_id_str ? jstring_to_string(env, title_id_str) : std::string();
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/native_config.cpp:690:    const auto result = app::commit_settings(*emuenv, desired_cfg, title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/native_config.cpp:692:    if (title_id.empty()) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/native_config.cpp:705:Java_org_vita3k_emulator_NativeLib_hasCustomConfig(JNIEnv *env, jclass, jstring title_id_str) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/native_config.cpp:710:    const std::string title_id = jstring_to_string(env, title_id_str);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/native_config.cpp:711:    return config::has_custom_config(emuenv->config_path, title_id) ? JNI_TRUE : JNI_FALSE;
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/native_config.cpp:715:Java_org_vita3k_emulator_NativeLib_getCustomConfig(JNIEnv *env, jclass, jstring title_id_str) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/native_config.cpp:720:    const std::string title_id = jstring_to_string(env, title_id_str);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/native_config.cpp:721:    if (!config::has_custom_config(emuenv->config_path, title_id))
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/native_config.cpp:726:    config::set_current_config(cfg_copy, emuenv->config_path, title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/native_config.cpp:739:Java_org_vita3k_emulator_NativeLib_deleteCustomConfig(JNIEnv *env, jclass, jstring title_id_str) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/native_config.cpp:744:    const std::string title_id = jstring_to_string(env, title_id_str);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/native_config.cpp:745:    const auto result = app::delete_custom_settings(*emuenv, title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/android_state.h:66:std::optional<app::AppEntry> find_app_by_title_id(const std::string &title_id);
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/android/jni/android_state.h:84:uint32_t get_app_action_availability_mask(const std::string &title_id);
```

### Config / preferences symbols
```text
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:5:import android.content.SharedPreferences
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:17:    private const val LEGACY_PREFS_SUFFIX = "_preferences"
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:66:        return preferences(context).getBoolean(overrideEnabledKey(normalizedScopeId), false)
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:71:        val prefs = preferences(context)
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:82:        return loadScopeState(preferences(context), normalizedScopeId, loadGlobalState(context))
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:92:        return loadScopeState(preferences(context), normalizedScopeId, globalState)
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:117:        preferences(context).edit().apply {
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:126:        val prefs = preferences(context)
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:184:        prefs: SharedPreferences,
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:203:        preferences(context).edit().apply {
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:220:        prefs: SharedPreferences,
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:242:        prefs: SharedPreferences,
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:272:        val legacyConfigPrefs = context.applicationContext.getSharedPreferences("emulation_session", Context.MODE_PRIVATE)
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:295:        val legacyPrefs = context.applicationContext.getSharedPreferences("${context.packageName}$LEGACY_PREFS_SUFFIX", Context.MODE_PRIVATE)
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:318:        editor: SharedPreferences.Editor,
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:331:    private fun removeScopePayload(editor: SharedPreferences.Editor, scopeId: String) {
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:344:    private fun preferences(context: Context): SharedPreferences =
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/overlay/OverlayStore.kt:345:        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/data/AppStorage.kt:21:        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/data/AppStorage.kt:25:        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/data/UiLanguages.kt:22:        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
/home/runner/work/_temp/hc-upstream/Vita3K/android/app/src/main/java/org/vita3k/emulator/data/UiLanguages.kt:30:        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/cpu/src/dynarmic_cpu.cpp:336:    Dynarmic::A32::UserConfig config{};
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/io/src/io.cpp:788:        const auto app_path{ vita_fs_path / "ux0/app" / app_title_id };
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/CMakeLists.txt:178:	SceSqlite/SceSqlite.cpp
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSysmodule/SceSysmodule.cpp:62:    case SCE_SYSMODULE_SQLITE: return "SCE_SYSMODULE_SQLITE";
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSysmodule/SceSysmodule.cpp:132:    case SCE_SYSMODULE_INTERNAL_SQLITE_VSH: return "SCE_SYSMODULE_INTERNAL_SQLITE_VSH";
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:20:EXPORT(int, sceSqliteConfigMallocMethods) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:24:EXPORT(int, sqlite3_aggregate_context) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:28:EXPORT(int, sqlite3_aggregate_count) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:32:EXPORT(int, sqlite3_auto_extension) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:36:EXPORT(int, sqlite3_backup_finish) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:40:EXPORT(int, sqlite3_backup_init) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:44:EXPORT(int, sqlite3_backup_pagecount) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:48:EXPORT(int, sqlite3_backup_remaining) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:52:EXPORT(int, sqlite3_backup_step) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:56:EXPORT(int, sqlite3_bind_blob) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:60:EXPORT(int, sqlite3_bind_double) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:64:EXPORT(int, sqlite3_bind_int) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:68:EXPORT(int, sqlite3_bind_int64) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:72:EXPORT(int, sqlite3_bind_null) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:76:EXPORT(int, sqlite3_bind_parameter_count) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:80:EXPORT(int, sqlite3_bind_parameter_index) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:84:EXPORT(int, sqlite3_bind_parameter_name) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:88:EXPORT(int, sqlite3_bind_text) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:92:EXPORT(int, sqlite3_bind_text16) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:96:EXPORT(int, sqlite3_bind_value) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:100:EXPORT(int, sqlite3_bind_zeroblob) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:104:EXPORT(int, sqlite3_blob_bytes) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:108:EXPORT(int, sqlite3_blob_close) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:112:EXPORT(int, sqlite3_blob_open) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:116:EXPORT(int, sqlite3_blob_read) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:120:EXPORT(int, sqlite3_blob_write) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:124:EXPORT(int, sqlite3_busy_handler) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:128:EXPORT(int, sqlite3_busy_timeout) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:132:EXPORT(int, sqlite3_changes) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:136:EXPORT(int, sqlite3_clear_bindings) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:140:EXPORT(int, sqlite3_close) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:144:EXPORT(int, sqlite3_collation_needed) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:148:EXPORT(int, sqlite3_collation_needed16) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:152:EXPORT(int, sqlite3_column_blob) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:156:EXPORT(int, sqlite3_column_bytes) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:160:EXPORT(int, sqlite3_column_bytes16) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:164:EXPORT(int, sqlite3_column_count) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:168:EXPORT(int, sqlite3_column_decltype) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:172:EXPORT(int, sqlite3_column_decltype16) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:176:EXPORT(int, sqlite3_column_double) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:180:EXPORT(int, sqlite3_column_int) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:184:EXPORT(int, sqlite3_column_int64) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:188:EXPORT(int, sqlite3_column_name) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:192:EXPORT(int, sqlite3_column_name16) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:196:EXPORT(int, sqlite3_column_text) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:200:EXPORT(int, sqlite3_column_text16) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:204:EXPORT(int, sqlite3_column_type) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:208:EXPORT(int, sqlite3_column_value) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:212:EXPORT(int, sqlite3_commit_hook) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:216:EXPORT(int, sqlite3_complete) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:220:EXPORT(int, sqlite3_complete16) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:224:EXPORT(int, sqlite3_config) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:228:EXPORT(int, sqlite3_context_db_handle) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:232:EXPORT(int, sqlite3_create_collation) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:236:EXPORT(int, sqlite3_create_collation16) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:240:EXPORT(int, sqlite3_create_collation_v2) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:244:EXPORT(int, sqlite3_create_function) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:248:EXPORT(int, sqlite3_create_function16) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:252:EXPORT(int, sqlite3_create_module) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:256:EXPORT(int, sqlite3_create_module_v2) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:260:EXPORT(int, sqlite3_data_count) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:264:EXPORT(int, sqlite3_db_config) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:268:EXPORT(int, sqlite3_db_handle) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:272:EXPORT(int, sqlite3_db_mutex) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:276:EXPORT(int, sqlite3_db_status) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:280:EXPORT(int, sqlite3_declare_vtab) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:284:EXPORT(int, sqlite3_enable_load_extension) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:288:EXPORT(int, sqlite3_enable_shared_cache) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:292:EXPORT(int, sqlite3_errcode) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:296:EXPORT(int, sqlite3_errmsg) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:300:EXPORT(int, sqlite3_errmsg16) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:304:EXPORT(int, sqlite3_exec) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:308:EXPORT(int, sqlite3_expired) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:312:EXPORT(int, sqlite3_extended_errcode) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:316:EXPORT(int, sqlite3_extended_result_codes) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:320:EXPORT(int, sqlite3_file_control) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:324:EXPORT(int, sqlite3_finalize) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:328:EXPORT(int, sqlite3_free) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:332:EXPORT(int, sqlite3_free_table) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:336:EXPORT(int, sqlite3_get_autocommit) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:340:EXPORT(int, sqlite3_get_auxdata) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:344:EXPORT(int, sqlite3_get_table) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:348:EXPORT(int, sqlite3_global_recover) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:352:EXPORT(int, sqlite3_initialize) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:356:EXPORT(int, sqlite3_interrupt) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:360:EXPORT(int, sqlite3_last_insert_rowid) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:364:EXPORT(int, sqlite3_libversion) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:368:EXPORT(int, sqlite3_libversion_number) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:372:EXPORT(int, sqlite3_limit) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:376:EXPORT(int, sqlite3_load_extension) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:380:EXPORT(int, sqlite3_malloc) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:384:EXPORT(int, sqlite3_memory_alarm) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:388:EXPORT(int, sqlite3_memory_highwater) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:392:EXPORT(int, sqlite3_memory_used) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:396:EXPORT(int, sqlite3_mprintf) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:400:EXPORT(int, sqlite3_mutex_alloc) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:404:EXPORT(int, sqlite3_mutex_enter) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:408:EXPORT(int, sqlite3_mutex_free) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:412:EXPORT(int, sqlite3_mutex_leave) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:416:EXPORT(int, sqlite3_mutex_try) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:420:EXPORT(int, sqlite3_next_stmt) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:424:EXPORT(int, sqlite3_open) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:428:EXPORT(int, sqlite3_open16) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:432:EXPORT(int, sqlite3_open_v2) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:436:EXPORT(int, sqlite3_os_end) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:440:EXPORT(int, sqlite3_os_init) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:444:EXPORT(int, sqlite3_overload_function) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:448:EXPORT(int, sqlite3_prepare) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:452:EXPORT(int, sqlite3_prepare16) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:456:EXPORT(int, sqlite3_prepare16_v2) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:460:EXPORT(int, sqlite3_prepare_v2) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:464:EXPORT(int, sqlite3_profile) {
/home/runner/work/_temp/hc-upstream/Vita3K/vita3k/modules/SceSqlite/SceSqlite.cpp:468:EXPORT(int, sqlite3_progress_handler) {
```

## SameBoy

Upstream commit: `213a12ce93d66b105a113debd9396306066a7cfc`

### CLI / launch / content symbols
```text
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:516:    char *argv[arguments.count + 1];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:517:    argv[arguments.count] = NULL;
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:519:        argv[i] = (char *)arguments[i].UTF8String;
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:522:    return AuthorizationExecuteWithPrivileges(_auth, path.UTF8String, kAuthorizationFlagDefaults, argv, NULL) == errAuthorizationSuccess;
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/main.m:3:int main(int argc, const char * argv[])
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/main.m:5:    return NSApplicationMain(argc, argv);
/home/runner/work/_temp/hc-upstream/SameBoy/Windows/crt.c:54:errno_t _configure_narrow_argv(unsigned mode)
/home/runner/work/_temp/hc-upstream/SameBoy/Windows/crt.c:59:char *_get_narrow_winmain_command_line(void)
/home/runner/work/_temp/hc-upstream/SameBoy/Windows/msvcrt.def:71:__argc
/home/runner/work/_temp/hc-upstream/SameBoy/Windows/msvcrt.def:72:__argv
/home/runner/work/_temp/hc-upstream/SameBoy/Windows/msvcrt.def:110:__wargv
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/open_dialog/gtk.c:21:bool _gtk_init_check (int *argc, char ***argv);
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1317:static bool get_arg_flag(const char *flag, int *argc, char **argv)
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1319:    for (unsigned i = 1; i < *argc; i++) {
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1320:        if (strcmp(argv[i], flag) == 0) {
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1321:            (*argc)--;
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1322:            argv[i] = argv[*argc];
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1329:static const char *get_arg_option(const char *option, int *argc, char **argv)
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1331:    for (unsigned i = 1; i < *argc - 1; i++) {
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1332:        if (strcmp(argv[i], option) == 0) {
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1333:            const char *ret = argv[i + 1];
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1334:            memmove(argv + i, argv + i + 2, (*argc - i - 2) * sizeof(argv[0]));
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1335:            (*argc) -= 2;
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1443:int main(int argc, char **argv)
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1452:    const char *model_string = get_arg_option("--model", &argc, argv);
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1453:    bool fullscreen = get_arg_flag("--fullscreen", &argc, argv) || get_arg_flag("-f", &argc, argv);
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1454:    bool nogl = get_arg_flag("--nogl", &argc, argv);
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1455:    stop_on_start = get_arg_flag("--stop-debugger", &argc, argv) || get_arg_flag("-s", &argc, argv);
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1458:    if (argc > 2 || (argc == 2 && argv[1][0] == '-')) {
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1460:        fprintf(stderr, "Usage: %s [--fullscreen|-f] [--nogl] [--stop-debugger|-s] [--model <model>] <rom>\n", argv[0]);
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1464:    if (argc == 2) {
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1465:        filename = argv[1];
/home/runner/work/_temp/hc-upstream/SameBoy/libretro/libretro.h:2240:    * This identifier can be used for command-line interfaces, etc.
/home/runner/work/_temp/hc-upstream/SameBoy/BootROMs/hardware.inc:62:; Usage: rev_Check_hardware_inc <min_ver>
/home/runner/work/_temp/hc-upstream/SameBoy/Makefile:330:SYSROOT := /Library/Developer/CommandLineTools/SDKs/$(shell ls /Library/Developer/CommandLineTools/SDKs/ | grep "[0-9]\." | tail -n 1)
/home/runner/work/_temp/hc-upstream/SameBoy/Makefile:332:ifeq ($(SYSROOT),/Library/Developer/CommandLineTools/SDKs/)
/home/runner/work/_temp/hc-upstream/SameBoy/XdgThumbnailer/main.c:100:int main(int argc, char *argv[])
/home/runner/work/_temp/hc-upstream/SameBoy/XdgThumbnailer/main.c:102:    if (argc != 3 && argc != 4) {
/home/runner/work/_temp/hc-upstream/SameBoy/XdgThumbnailer/main.c:103:        g_error("Usage: %s <input path> <output path> [<size>]", argv[0] ? argv[0] : "sameboy-thumbnailer");
/home/runner/work/_temp/hc-upstream/SameBoy/XdgThumbnailer/main.c:106:    const char *input_path = argv[1];
/home/runner/work/_temp/hc-upstream/SameBoy/XdgThumbnailer/main.c:107:    char *output_path = argv[2];    // Gets mutated in-place.
/home/runner/work/_temp/hc-upstream/SameBoy/XdgThumbnailer/main.c:108:    const char *max_size = argv[3]; // May be NULL.
/home/runner/work/_temp/hc-upstream/SameBoy/iOS/installer.m:27:int main(int argc, char **argv)
/home/runner/work/_temp/hc-upstream/SameBoy/iOS/installer.m:29:    if (argc != 2) return 1;
/home/runner/work/_temp/hc-upstream/SameBoy/iOS/installer.m:34:    if (strcmp(argv[1], "uninstall") == 0) {
/home/runner/work/_temp/hc-upstream/SameBoy/iOS/installer.m:37:    else if (strcmp(argv[1], "install") != 0) {
/home/runner/work/_temp/hc-upstream/SameBoy/iOS/GBViewController.m:655:                    [self controller:weakController buttonChanged:button usage:usage.unsignedIntValue];
/home/runner/work/_temp/hc-upstream/SameBoy/iOS/GBViewController.m:666:                    [self controller:weakController axisChanged:dpad usage:usage.unsignedIntValue childrenUsages:childrenUsages];
/home/runner/work/_temp/hc-upstream/SameBoy/iOS/GBViewController.m:686:- (void)controller:(GCController *)controller buttonChanged:(GCControllerButtonInput *)button usage:(GBControllerUsage)usage
/home/runner/work/_temp/hc-upstream/SameBoy/iOS/GBViewController.m:793:- (void)controller:(GCController *)controller axisChanged:(GCControllerDirectionPad *)axis usage:(GBControllerUsage)usage childrenUsages:(NSSet *)childrenUsages
/home/runner/work/_temp/hc-upstream/SameBoy/iOS/main.m:14:int main(int argc, char * argv[])
/home/runner/work/_temp/hc-upstream/SameBoy/iOS/main.m:176:    return UIApplicationMain(argc, argv, nil, NSStringFromClass([GBViewController class]));
/home/runner/work/_temp/hc-upstream/SameBoy/build-faq.md:27:After downloading [rgbds](https://github.com/gbdev/rgbds/releases/), ensure that it is added to the `%PATH%`. This may be done by adding it to the user's or SYSTEM's Environment Variables, or may be added to the command line at compilation time via `set path=%path%;C:\path\to\rgbds`.  
/home/runner/work/_temp/hc-upstream/SameBoy/build-faq.md:31:Ensure that the `Git\usr\bin` directory is included in `%PATH%`. Like rgbds above, this may instead be manually included on the command line before installation: `set path=%path%;C:\path\to\Git\usr\bin`. Similarly, make sure that the directory containing `make.exe` is also included.
/home/runner/work/_temp/hc-upstream/SameBoy/Core/debugger.c:749:    GB_log(gb, "Usage: %s", command->command);
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:289:int main(int argc, char **argv)
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:293:    if (argc == 1) {
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:294:        fprintf(stderr, "Usage: %s [--dmg] [--sgb] [--cgb] [--start] [--length seconds] [--sav] [--boot path to boot ROM]"
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:298:                        " rom ...\n", argv[0]);
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:314:    for (unsigned i = 1; i < argc; i++) {
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:315:        if (strcmp(argv[i], "--dmg") == 0) {
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:322:        if (strcmp(argv[i], "--sgb") == 0) {
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:329:        if (strcmp(argv[i], "--cgb") == 0) {
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:336:        if (strcmp(argv[i], "--tga") == 0) {
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:342:        if (strcmp(argv[i], "--start") == 0) {
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:348:        if (strcmp(argv[i], "--length") == 0 && i != argc - 1) {
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:349:            test_length = atoi(argv[++i]) * 60;
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:354:        if (strcmp(argv[i], "--boot") == 0 && i != argc - 1) {
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:355:            fprintf(stderr, "Using boot ROM %s\n", argv[i + 1]);
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:356:            boot_rom_path = argv[++i];
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:360:        if (strcmp(argv[i], "--sav") == 0) {
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:367:        if (strcmp(argv[i], "--jobs") == 0 && i != argc - 1) {
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:368:            max_forks = atoi(argv[++i]);
/home/runner/work/_temp/hc-upstream/SameBoy/Tester/main.c:387:        filename = argv[i];
/home/runner/work/_temp/hc-upstream/SameBoy/README.md:43: * macOS Cocoa frontend: macOS SDK and Xcode (For command line tools and ibtool)
/home/runner/work/_temp/hc-upstream/SameBoy/README.md:69:Linux, BSD, and other FreeDesktop users can run `sudo make install` to install SameBoy as both a GUI app and a command line tool.
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/ControllerConfiguration.inc:169:        JOYRumbleUsage: @1,
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/ControllerConfiguration.inc:172:        JOYConnectedUsage: @2,
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/ControllerConfiguration.inc:345:        JOYRumbleUsage: @1,
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYEmulatedButton.m:16:- (instancetype)initWithUsage:(JOYButtonUsage)usage type:(JOYButtonType)type uniqueID:(uint64_t)uniqueID;
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYSubElement.m:26:                              usage:(uint16_t)usage
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYEmulatedButton.h:7:- (instancetype)initWithUsage:(JOYButtonUsage)usage type:(JOYButtonType)type uniqueID:(uint64_t)uniqueID;
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYController.m:393:                        [[JOYEmulatedButton alloc] initWithUsage:JOYButtonUsageDPadLeft type:JOYButtonTypeAxes2DEmulated uniqueID:axes.uniqueID | 0x100000000L],
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYController.m:394:                        [[JOYEmulatedButton alloc] initWithUsage:JOYButtonUsageDPadRight type:JOYButtonTypeAxes2DEmulated uniqueID:axes.uniqueID | 0x200000000L],
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYController.m:395:                        [[JOYEmulatedButton alloc] initWithUsage:JOYButtonUsageDPadUp type:JOYButtonTypeAxes2DEmulated  uniqueID:axes.uniqueID | 0x300000000L],
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYController.m:396:                        [[JOYEmulatedButton alloc] initWithUsage:JOYButtonUsageDPadDown type:JOYButtonTypeAxes2DEmulated uniqueID:axes.uniqueID | 0x400000000L],
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYController.m:415:                    [[JOYEmulatedButton alloc] initWithUsage:axis.equivalentButtonUsage type:JOYButtonTypeAxisEmulated uniqueID:axis.uniqueID];
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYController.m:435:                        [[JOYEmulatedButton alloc] initWithUsage:JOYButtonUsageDPadLeft type:JOYButtonTypeHatEmulated  uniqueID:hat.uniqueID | 0x100000000L],
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYController.m:436:                        [[JOYEmulatedButton alloc] initWithUsage:JOYButtonUsageDPadRight type:JOYButtonTypeHatEmulated uniqueID:hat.uniqueID | 0x200000000L],
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYController.m:437:                        [[JOYEmulatedButton alloc] initWithUsage:JOYButtonUsageDPadUp type:JOYButtonTypeHatEmulated  uniqueID:hat.uniqueID | 0x300000000L],
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYController.m:438:                        [[JOYEmulatedButton alloc] initWithUsage:JOYButtonUsageDPadDown type:JOYButtonTypeHatEmulated uniqueID:hat.uniqueID | 0x400000000L],
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYController.m:511:                                                                                 usage:subElementDef[@"usage"].unsignedLongValue
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYController.m:747:        //NSLog(@"Unhandled usage %x (Cookie: %x, Usage: %x)", IOHIDElementGetUsage(element), IOHIDElementGetCookie(element), IOHIDElementGetUsage(element));
/home/runner/work/_temp/hc-upstream/SameBoy/JoyKit/JOYSubElement.h:8:                              usage:(uint16_t)usage
```

### Config / preferences symbols
```text
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/MainMenu.xib:39:                            <menuItem title="Preferences…" keyEquivalent="," id="BOF-NM-1cW">
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/MainMenu.xib:41:                                    <action selector="showPreferences:" target="-3" id="RcX-51-nzq"/>
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBPreferencesSlider.h:3:@interface GBPreferencesSlider : NSSlider
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:30:    NSArray<NSView *> *_preferencesTabs;
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:288:- (IBAction)switchPreferencesTab:(id)sender
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:290:    for (NSView *view in _preferencesTabs) {
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:293:    NSView *tab = _preferencesTabs[[sender tag]];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:294:    NSRect old = [_preferencesWindow frame];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:295:    NSRect new = [_preferencesWindow frameRectForContentRect:tab.frame];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:298:    [_preferencesWindow setFrame:new display:true animate:_preferencesWindow.visible];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:299:    [_preferencesWindow.contentView addSubview:tab];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:333:- (IBAction) showPreferences: (id) sender
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:336:    if (!_preferencesWindow) {
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:337:        [[NSBundle mainBundle] loadNibNamed:@"Preferences" owner:self topLevelObjects:&objects];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:338:        NSToolbarItem *first_toolbar_item = [_preferencesWindow.toolbar.items firstObject];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:339:        _preferencesWindow.toolbar.selectedItemIdentifier = [first_toolbar_item itemIdentifier];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:340:        _preferencesTabs = @[self.emulationTab, self.graphicsTab, self.audioTab, self.controlsTab, self.updatesTab];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:341:        [self switchPreferencesTab:first_toolbar_item];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:342:        [_preferencesWindow center];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:344:        [_preferencesWindow.toolbar removeItemAtIndex:4];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:346:        for (unsigned i = _preferencesWindow.toolbar.items.count; i--;) {
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:347:            [_preferencesWindow.toolbar.items[i] _view].imageScaling = NSImageScaleNone;
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:350:    [_preferencesWindow makeKeyAndOrderFront:self];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:399:                    self.updateChanges.preferences.standardFontFamily = @"-apple-system";
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:402:                    self.updateChanges.preferences.standardFontFamily = @"Helvetica Neue";
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:405:                    self.updateChanges.preferences.standardFontFamily = @"Lucida Grande";
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:408:                    self.updateChanges.preferences.fixedFontFamily = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular].displayName;
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:411:                    self.updateChanges.preferences.fixedFontFamily = @"Menlo";
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:489:        alert.informativeText = @"SameBoy is frequently updated with new features, accuracy improvements, and bug fixes. This setting can always be changed in the preferences window.";
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.m:729:        if (_preferencesWindow && self.keyWindow == _preferencesWindow) {
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/UpdateWindow.xib:86:                        <webPreferences key="preferences" defaultFontSize="13" defaultFixedFontSize="13" minimumFontSize="0" plugInsEnabled="NO" javaEnabled="NO" javaScriptEnabled="NO" javaScriptCanOpenWindowsAutomatically="NO" loadsImagesAutomatically="NO" allowsAnimatedImages="NO" allowsAnimatedImageLooping="NO">
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/UpdateWindow.xib:88:                        </webPreferences>
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBPreferencesWindow.m:1:#import "GBPreferencesWindow.h"
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBPreferencesWindow.m:10:@implementation GBPreferencesWindow
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBPreferencesSlider.m:1:#import "GBPreferencesSlider.h"
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBPreferencesSlider.m:4:@implementation GBPreferencesSlider
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/Document.m:1416:            [GBWarningPopover popoverWithContents:@"Warning: Volume is set to to zero in the preferences panel" onWindow:self.mainWindow];
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/KeyboardShortcutPrivateAPIs.h:6:+ (id)shortcutWithPreferencesEncoding:(NSString *)encoding;
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/KeyboardShortcutPrivateAPIs.h:12:@property(readonly) NSString *preferencesEncoding;
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBPreferencesWindow.h:6:@interface GBPreferencesWindow : NSWindow <NSTableViewDelegate, NSTableViewDataSource, JOYListener>
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.h:7:@property (nonatomic, strong) IBOutlet NSWindow *preferencesWindow;
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.h:13:- (IBAction)showPreferences: (id) sender;
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/GBApp.h:15:- (IBAction)switchPreferencesTab:(id)sender;
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/Preferences.xib:15:                <outlet property="preferencesWindow" destination="QvC-M9-y7g" id="kBg-fq-rZh"/>
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/Preferences.xib:23:        <window title="Preferences" allowsToolTipsWhenApplicationIsInactive="NO" autorecalculatesKeyViewLoop="NO" releasedWhenClosed="NO" visibleAtLaunch="NO" animationBehavior="default" toolbarStyle="preference" id="QvC-M9-y7g" customClass="GBPreferencesWindow">
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/Preferences.xib:38:                            <action selector="switchPreferencesTab:" target="-2" id="AK1-Qj-JOU"/>
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/Preferences.xib:45:                            <action selector="switchPreferencesTab:" target="-2" id="wck-Sv-EsJ"/>
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/Preferences.xib:52:                            <action selector="switchPreferencesTab:" target="-2" id="UrT-PP-tQV"/>
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/Preferences.xib:59:                            <action selector="switchPreferencesTab:" target="-2" id="Tio-D7-PaA"/>
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/Preferences.xib:66:                            <action selector="switchPreferencesTab:" target="-2" id="bfU-hc-FnN"/>
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/Preferences.xib:256:                <slider verticalHuggingPriority="750" fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="NuA-mL-AJZ" customClass="GBPreferencesSlider">
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/Preferences.xib:724:                <slider verticalHuggingPriority="750" fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="LNs-v1-Eki" customClass="GBPreferencesSlider">
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/Preferences.xib:773:                <slider verticalHuggingPriority="750" fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="FpE-5i-j5L" customClass="GBPreferencesSlider">
/home/runner/work/_temp/hc-upstream/SameBoy/Cocoa/Preferences.xib:1199:                <slider verticalHuggingPriority="750" fixedFrame="YES" translatesAutoresizingMaskIntoConstraints="NO" id="HD1-qj-kiI" customClass="GBPreferencesSlider">
/home/runner/work/_temp/hc-upstream/SameBoy/SDL/main.c:1346:    CFPreferencesSetAppValue(CFSTR("AppleMomentumScrollSupported"), kCFBooleanTrue, kCFPreferencesCurrentApplication);
/home/runner/work/_temp/hc-upstream/SameBoy/libretro/libretro.h:3091: * This string can be used to better let a user configure input. */
/home/runner/work/_temp/hc-upstream/SameBoy/iOS/GBViewController.m:600:- (void)orderFrontPreferencesPanel:(id)sender
```

