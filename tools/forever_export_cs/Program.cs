// ExportTool -- dump arbitrary client files (icons, models, textures) from
// the Forever beta CASC storage by FDID or by listfile path, using TACTSharp.
//
// usage (run with the working directory set to the DB2ToSqlite workspace so
// cache/ and listfile.csv resolve):
//   dotnet ExportTool.dll -s appsettings.forever_world.json \
//       --fdids icon_fdids.txt -o exported/icons --ext .blp
//   dotnet ExportTool.dll -s ... --paths files.txt -o exported/files
//
// Input line formats: "<fdid> [name]" (fdids file) or one path per line
// (paths file, resolved through the community listfile).

using System.Text.Json;
using TACTSharp;

string settingsFile = "appsettings.json";
string outDir = "exported";
string? fdidFile = null;
string? pathFile = null;
string defaultExt = ".bin";

for (var i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "-s":
        case "--settings":
            settingsFile = args[++i];
            break;
        case "-o":
        case "--out":
            outDir = args[++i];
            break;
        case "--fdids":
            fdidFile = args[++i];
            break;
        case "--paths":
            pathFile = args[++i];
            break;
        case "--ext":
            defaultExt = args[++i];
            break;
    }
}

var root = JsonDocument.Parse(File.ReadAllText(settingsFile)).RootElement;
var cfg = root.GetProperty("Settings");
var settings = new Settings
{
    BaseDir = cfg.GetProperty("BaseDir").GetString(),
    Product = cfg.GetProperty("Product").GetString(),
    Region = cfg.TryGetProperty("Region", out var reg) ? reg.GetString() : "us",
    CacheDir = "cache",
};

var cdn = new CDN(settings);
var listfile = new Listfile();
listfile.Initialize(cdn, settings);

var buildInfo = new BuildInfo(
    Path.Combine(settings.BaseDir!, ".build.info"), settings, cdn);
var entry = buildInfo.Entries.First(x => x.Product == settings.Product);

var build = new BuildInstance();
build.Settings.BuildConfig ??= entry.BuildConfig;
build.Settings.CDNConfig ??= entry.CDNConfig;
build.LoadConfigs(build.Settings.BuildConfig!, build.Settings.CDNConfig!);
build.Load();
Console.WriteLine($"build: {build.Settings.BuildConfig} root entries loaded");

Directory.CreateDirectory(outDir);

var jobs = new List<(uint Fdid, string Name)>();
if (fdidFile != null)
{
    foreach (var line in File.ReadLines(fdidFile))
    {
        var parts = line.Split(' ', 2, StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0)
            continue;
        if (uint.TryParse(parts[0], out var id))
            jobs.Add((id, parts.Length > 1 ? parts[1] : id + defaultExt));
    }
}
if (pathFile != null)
{
    foreach (var line in File.ReadLines(pathFile))
    {
        var p = line.Trim();
        if (p.Length == 0)
            continue;
        var id = listfile.GetFDID(p);
        if (id != 0)
            jobs.Add((id, Path.GetFileName(p)));
        else
            Console.WriteLine("no fdid for path: " + p);
    }
}

int ok = 0, fail = 0;
var seen = new HashSet<uint>();
foreach (var (fdid, name) in jobs)
{
    if (!seen.Add(fdid))
        continue;
    try
    {
        var bytes = build.OpenFileByFDID(fdid);
        File.WriteAllBytes(Path.Combine(outDir, name), bytes);
        ok++;
    }
    catch (Exception e)
    {
        fail++;
        if (fail <= 10)
            Console.WriteLine($"FAIL {fdid}: {e.Message}");
    }
    if ((ok + fail) % 250 == 0)
        Console.WriteLine($"... {ok} exported, {fail} failed");
}

Console.WriteLine($"done: {ok} exported, {fail} failed -> {outDir}");
