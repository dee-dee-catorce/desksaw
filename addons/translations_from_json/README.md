# Translations From JSON for Godot 4.x

A Godot plugin for importing JSON files for translations.

This is the Godot 4.x version of the plugin. If you want to use it on 3.x, head over to the [3.x branch](https://github.com/AliYil/TranslationsFromJson/tree/3.x).

## Usage

1. [Install the plugin into your project](https://docs.godotengine.org/en/4.0/tutorials/plugins/editor/installing_plugins.html) and activate it.
2. Add JSON translations files into your project in .json format.
3. Make sure the JSON files are imported as "JSON Translation".
4. Add your JSON files to translations using Project Settings > Localization > Translations > Add *(Change "All Recognized" to "All files (\*)" to see the JSON file)*

## JSON Format

The json data in file must be an object with locale and messages keys.

- "locale" field signify which locale the texts are in.
- "message" field must be an object that contains keys and corresponding text as string value.

### Example JSON

```json
{
    "locale": "en",
    "messages": {
        "HELLOWORLD": "Hello world!",
        "ANOTHERTEXT": "This is another text."
    }
}
```
