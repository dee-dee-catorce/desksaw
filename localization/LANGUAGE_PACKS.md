Language packs
==============

DeskSaw can load additional languages from external `.pck` files, so the base
game stays English and translations can be shipped separately.

Where to put packs
------------------

Create a `languages` folder next to the executable:

```
deskSaw030WIN.exe
deskSaw030WIN.pck
languages/
    zh.pck
```

Every `.pck` in that folder is detected at startup. Nothing is loaded
automatically — the player picks a language in
**Settings → General → Language**.

Pack contents
-------------

A language pack is a normal Godot PCK that overrides files of the base game:

| File inside the pack | Purpose |
|---|---|
| `res://lang.txt` | Required. First line = locale code (`zh`), second line (optional) = display name. |
| `res://localization/localization.<locale>.translation` | The translation resource for the UI. |
| `res://Scripts/singletons/TEMPDialogue.json` | Optional. Localized dialogue. |
| any other `res://` path | Optional. Replaces that file from the base game. |

The pack is mounted with `ProjectSettings.load_resource_pack(path, true)`, so
its files take precedence over the base game.

How it works
------------

Godot registers translations listed in `project.godot` at engine start, so a
pack mounted later is not picked up automatically. `LanguagePackLoader`
(`Scripts/preload/language_pack_loader.gd`) mounts the pack and then registers
the `Translation` resource with `TranslationServer.add_translation()`.
`LocalizationManager` uses it when the language setting changes.

Fonts
-----

The project font (`assets/fonts/UiFontWithCJK.tres`) has GNU Unifont as a
fallback, so CJK text renders without relying on system fonts.

Building a pack
---------------

Any Godot project (or a plain `PCKPacker` script) can produce one:

```gdscript
var pack := PCKPacker.new()
pack.pck_start("languages/zh.pck")
pack.add_file("res://lang.txt", "res://lang.txt")
pack.add_file("res://localization/localization.zh.translation",
        "res://localization/localization.zh.translation")
pack.flush()
```

Existing translations
---------------------

| Locale | File | Source |
|---|---|---|
| `en` | `localization.en.translation` | bundled |
| `cs` | `localization.cs.translation` | bundled |
| `zh` | `zh.pck` (external) | community |
