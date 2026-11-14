# Development runtime

Godot 4.7.2 stable, downloaded and SHA512 verified by the host coordinator.

- Console executable: `C:/Users/Lugia/DEV/All-Inclusive/.tools/godot/Godot_v4.7.2-stable_win64_console.exe`
- GUI executable is adjacent without `_console` in its name.
- Windows custom export templates: `.tools/godot/templates/windows_release_x86_64.exe` and `.tools/godot/templates/windows_debug_x86_64.exe` (host coordinator provisions).
- Python: `C:/Users/Lugia/AppData/Local/Python/bin/python.exe` (3.14.3).

Do not include `.tools/` in exported resources or source-control changes. Use absolute custom template paths for this workspace if necessary. Host coordinator owns runtime provisioning.

For sandboxed CLI tests, set process-local `APPDATA` to the workspace's `.tools/test-appdata` directory before launching Godot, and create that directory if absent. This keeps test logs and `user://` saves within writable workspace paths. Do not change the user's global environment; delivered builds use the normal Godot user-data path.

Include root-generated `THIRD_PARTY_NOTICES.txt` next to the exported executable and in the delivery archive.
