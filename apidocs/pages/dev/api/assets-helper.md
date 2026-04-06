# Assets Helper | Project Sylvanas

Source: https://docs.project-sylvanas.net/dev/api/assets-helper

## Overview

📘 Libraries
Mini Libs
Assets Helper

### Overview​

The Assets Helper is a utility library that simplifies texture and data loading from both local files and remote URLs. It provides automatic caching, ZIP pack support for bundling assets, and seamless world-to-screen coordinate conversion.

Key Features:

Local Texture Loading - Load PNG/JPG textures from scripts_data/ folder

Remote Texture Loading - Download and cache textures from URLs

ZIP Pack Support - Bundle multiple assets in a ZIP file with auto-download

World Position Support - Pass vec3 world coordinates and get automatic world-to-screen conversion

Automatic Caching - Textures are cached after first load for performance

PS Short Links - Use ps/<file> shorthand for official Project Sylvanas downloads

Higher-Level Alternative
For the easiest experience, consider using the IZI SDK Graphics module which wraps this helper with additional convenience functions.

### Importing The Module​

```
---@type assets_helperlocal assets = require("common/utility/assets_helper")
```

Method Access
Access functions with : (colon), not . (dot). Static members like cache use . (dot).

#### assets:register_zip_pack​

Syntax

```
assets:register_zip_pack(folder_name: string, zip_url: string, zip_file_name?: string): nil
```

Parameters

ParameterTypeDefaultDescriptionfolder_namestringRequiredVirtual folder name to access files from the ZIPzip_urlstringRequiredURL to download the ZIP file (supports ps/ shorthand)zip_file_namestringnilOptional custom filename for the downloaded ZIP
Description
Registers a ZIP pack for automatic downloading and extraction. Once registered, files inside the ZIP can be accessed using draw_local_texture with the virtual folder path. If the ZIP is missing locally, it will be downloaded automatically on first access.

Example Usage

```
local assets = require("common/utility/assets_helper")-- Register a ZIP pack from Project Sylvanas CDNassets:register_zip_pack(    "my_icons",                              -- Virtual folder name    "ps/1768128082013OFT0-my_icons.zip"      -- PS short link)-- Files inside are now accessible as: my_icons\icon_name.png
```

#### assets:draw_local_texture​

Syntax

```
assets:draw_local_texture(    data_path: string,    top_left: vec2|vec3,    width: number,    height: number,    tint?: color,    is_for_window?: boolean): boolean
```

Parameters

ParameterTypeDefaultDescriptiondata_pathstringRequiredPath relative to scripts_data/ foldertop_leftvec2|vec3RequiredScreen position (vec2) or world position (vec3)widthnumberRequiredDraw width in pixelsheightnumberRequiredDraw height in pixelstintcolorWhiteOptional color tintis_for_windowbooleanfalseSet true if drawing inside a custom window
Returns

boolean - True if the texture was drawn successfully

Description
Draws a texture from the local scripts_data/ folder. The texture is loaded and cached on first use. Supports both screen coordinates (vec2) and world coordinates (vec3) - world positions are automatically converted to screen space.

Example Usage

```
local vec2 = require("common/geometry/vector_2")local assets = require("common/utility/assets_helper")local color = require("common/color")-- File location: <loader_path>/scripts_data/my_addon/icon.pnglocal function on_render()    assets:draw_local_texture(        "my_addon\\icon.png",    -- Path in scripts_data        vec2.new(100, 100),      -- Screen position        64, 64,                  -- Size        color.white(255),        -- Tint        false                    -- Not in a window    )endcore.register_on_render_callback(on_render)
```

World Position Example

```
local vec3 = require("common/geometry/vector_3")local assets = require("common/utility/assets_helper")local function on_render()    -- Draw at a world position (auto world-to-screen conversion)    local world_pos = vec3.new(1234.5, 5678.9, 100)    assets:draw_local_texture(        "my_addon\\marker.png",        world_pos,        32, 32    )endcore.register_on_render_callback(on_render)
```

#### assets:draw_http_texture​

Syntax

```
assets:draw_http_texture(    url: string,    top_left: vec2|vec3,    width: number,    height: number,    cache_path?: string,    headers?: table<string, string>,    tint?: color,    is_for_window?: boolean): boolean
```

Parameters

ParameterTypeDefaultDescriptionurlstringRequiredURL to download the texture fromtop_leftvec2|vec3RequiredScreen position (vec2) or world position (vec3)widthnumberRequiredDraw width in pixelsheightnumberRequiredDraw height in pixelscache_pathstringnilOptional local cache path in scripts_data/headerstable<string, string>nilOptional HTTP headerstintcolorWhiteOptional color tintis_for_windowbooleanfalseSet true if drawing inside a custom window
Returns

boolean - True if the texture was drawn successfully

Description
Downloads and draws a texture from a remote URL. The texture is cached in memory after download. Optionally specify a cache_path to persist the texture to disk for faster loading on subsequent sessions.

Example Usage

```
local vec2 = require("common/geometry/vector_2")local assets = require("common/utility/assets_helper")local function on_render()    assets:draw_http_texture(        "https://example.com/icon.png",        vec2.new(200, 200),        64, 64,        "cache\\remote_icon.png"  -- Cache to disk    )endcore.register_on_render_callback(on_render)
```

#### assets:load_local_data​

Syntax

```
assets:load_local_data(data_path: string, default_value?: string): string
```

Parameters

ParameterTypeDefaultDescriptiondata_pathstringRequiredPath relative to scripts_data/ folderdefault_valuestring""Value to return if file doesn't exist
Returns

string - File contents or default value

Description
Loads raw data from a local file. Useful for loading JSON configs, text files, or binary data.

Example Usage

```
local assets = require("common/utility/assets_helper")local config_json = assets:load_local_data("my_addon\\config.json", "{}")-- Parse JSON and use config...
```

#### assets:load_http_data​

Syntax

```
assets:load_http_data(    url: string,    callback: function,    headers?: table<string, string>): nil
```

Parameters

ParameterTypeDefaultDescriptionurlstringRequiredURL to download data fromcallbackfunctionRequiredCallback function when download completesheaderstable<string, string>nilOptional HTTP headers
Callback Parameters

```
function(ok: boolean, data: string, http_code: integer, content_type: string, response_headers: string)
```

ParameterTypeDescriptionokbooleanTrue if download succeededdatastringDownloaded data (or error message)http_codeintegerHTTP status codecontent_typestringResponse content typeresponse_headersstringRaw response headers
Description
Asynchronously downloads data from a remote URL. The callback is invoked when the download completes (or fails).

Example Usage

```
local assets = require("common/utility/assets_helper")assets:load_http_data(    "https://example.com/data.json",    function(ok, data, http_code, content_type, headers)        if ok then            core.log("Downloaded: " .. data)        else            core.log_error("Download failed: " .. data)        end    end)
```

### URL Formats​

The assets helper supports two URL formats:

FormatExampleDescriptionFull URLhttps://url.com/file.pngStandard HTTP URLPS Short Linkps/file.pngShorthand for PS CDN (you can ask silvi to host your stuff)
The ps/ prefix is automatically resolved to the official Project Sylvanas download host.

#### Example 1: Local Texture​

```
local vec2 = require("common/geometry/vector_2")local assets = require("common/utility/assets_helper")local color = require("common/color")-- Place file at: <loader_path>/scripts_data/test_assets/classicon_paladin.pnglocal function on_render()    assets:draw_local_texture(        "test_assets\\classicon_paladin.png",        vec2.new(30, 30),        64, 64,        color.white(255),        false    )endcore.register_on_render_callback(on_render)
```

#### Example 2: ZIP Pack Auto-Download​

```
local vec2 = require("common/geometry/vector_2")local assets = require("common/utility/assets_helper")local color = require("common/color")-- Register ZIP pack - will auto-download if missingassets:register_zip_pack(    "zip_test_assets",    "ps/1768128082013OFT0-zip_test_assets.zip")local function on_render()    -- Access files from inside the ZIP    assets:draw_local_texture(        "zip_test_assets\\classicon_paladin.png",        vec2.new(30, 110),        64, 64,        color.red(),        false    )endcore.register_on_render_callback(on_render)
```

#### Example 3: World-Space Drawing​

```
local vec3 = require("common/geometry/vector_3")local assets = require("common/utility/assets_helper")local function on_render()    -- Draw texture at a 3D world position    local world_pos = vec3.new(1234, 5678, 90)    assets:draw_local_texture(        "test_assets\\marker.png",        world_pos,  -- Automatic world-to-screen conversion        64, 64    )endcore.register_on_render_callback(on_render)
```

#### assets_helper_local_texture_entry​

Internal cache entry for local textures.

FieldTypeDescriptionpathstringFile pathtex_idinteger|nilGPU texture IDwinteger|nilTexture widthhinteger|nilTexture heightdeadbooleanTrue if loading failed permanentlydead_errorstring|nilError message if dead

#### assets_helper_remote_texture_entry​

Internal cache entry for remote textures.

FieldTypeDescriptionurlstringSource URLcache_pathstring|nilLocal disk cache pathtex_idinteger|nilGPU texture IDwinteger|nilTexture widthhinteger|nilTexture heightrequestedbooleanTrue if download has been initiatederrorstring|nilError message if failed

#### assets_helper_zip_pack​

ZIP pack registration entry.

FieldTypeDescriptionurlstringDownload URLzip_filestringLocal ZIP filename

Previous
Dungeons Helper
Next
Icons Helper

Overview
Importing The Module
Functionsassets:register_zip_pack
assets:draw_local_texture
assets:draw_http_texture
assets:load_local_data
assets:load_http_data

URL Formats
Complete ExamplesExample 1: Local Texture
Example 2: ZIP Pack Auto-Download
Example 3: World-Space Drawing

Typesassets_helper_local_texture_entry
assets_helper_remote_texture_entry
assets_helper_zip_pack
