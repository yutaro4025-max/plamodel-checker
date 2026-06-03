using System.IO.Compression;
using System.Xml.Linq;

namespace PlamodelChecker.Core;

/// <summary>
/// NuGet不要。xlsx/xlsm は ZIP + XML なので標準ライブラリだけで読める。
/// </summary>
internal static class SimpleXlsxReader
{
    private static readonly XNamespace _ss =
        "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
    private static readonly XNamespace _r =
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
    private static readonly XNamespace _pkg =
        "http://schemas.openxmlformats.org/package/2006/relationships";

    /// <summary>
    /// 指定シート（1始まり）の全行を読む。
    /// 戻り値: (行リスト[col1, col2, ...], A1セルの文字列)
    /// </summary>
    public static (List<string[]> Rows, string A1Value) Read(string filePath, int sheetIndex)
    {
        using var zip = ZipFile.OpenRead(filePath);

        var shared = ReadSharedStrings(zip);
        string sheetPath = ResolveSheetPath(zip, sheetIndex);
        return ReadSheet(zip, sheetPath, shared);
    }

    // ── 共有文字列テーブル ────────────────────────────────────────────────

    private static List<string> ReadSharedStrings(ZipArchive zip)
    {
        var entry = zip.GetEntry("xl/sharedStrings.xml");
        if (entry == null) return [];

        using var stream = entry.Open();
        var doc = XDocument.Load(stream);
        return doc.Descendants(_ss + "si")
            .Select(si => string.Concat(si.Descendants(_ss + "t").Select(t => t.Value)))
            .ToList();
    }

    // ── シートファイルパスの解決 ──────────────────────────────────────────

    private static string ResolveSheetPath(ZipArchive zip, int sheetIndex)
    {
        string fallback = $"xl/worksheets/sheet{sheetIndex}.xml";

        var wbEntry = zip.GetEntry("xl/workbook.xml");
        if (wbEntry == null) return fallback;

        using var wbStream = wbEntry.Open();
        var wbDoc = XDocument.Load(wbStream);

        var sheets = wbDoc.Descendants(_ss + "sheet").ToList();
        if (sheets.Count < sheetIndex) return fallback;

        string? rId = sheets[sheetIndex - 1].Attribute(_r + "id")?.Value;
        if (rId == null) return fallback;

        var relsEntry = zip.GetEntry("xl/_rels/workbook.xml.rels");
        if (relsEntry == null) return fallback;

        using var relsStream = relsEntry.Open();
        var relsDoc = XDocument.Load(relsStream);

        string? target = relsDoc.Descendants(_pkg + "Relationship")
            .FirstOrDefault(rel => rel.Attribute("Id")?.Value == rId)
            ?.Attribute("Target")?.Value;

        if (target == null) return fallback;

        // target は xl/ からの相対パス (例: "worksheets/sheet1.xml")
        return target.StartsWith('/') ? target.TrimStart('/') : "xl/" + target;
    }

    // ── シートデータの読み込み ───────────────────────────────────────────

    private static (List<string[]>, string) ReadSheet(
        ZipArchive zip, string sheetPath, List<string> shared)
    {
        var entry = zip.GetEntry(sheetPath);
        if (entry == null) return ([], "");

        using var stream = entry.Open();
        var doc = XDocument.Load(stream);

        // rowNumber → {colNumber → value}
        var grid = new SortedDictionary<int, SortedDictionary<int, string>>();

        foreach (var rowEl in doc.Descendants(_ss + "row"))
        {
            if (!int.TryParse(rowEl.Attribute("r")?.Value, out int rowNum)) continue;
            var cols = new SortedDictionary<int, string>();

            foreach (var cellEl in rowEl.Elements(_ss + "c"))
            {
                string? cellRef = cellEl.Attribute("r")?.Value;
                if (cellRef == null) continue;

                int colNum = ParseColNumber(cellRef);
                string type = cellEl.Attribute("t")?.Value ?? "";
                string raw = cellEl.Element(_ss + "v")?.Value ?? "";

                string value = (type == "s" && int.TryParse(raw, out int idx) && idx < shared.Count)
                    ? shared[idx]
                    : raw;

                cols[colNum] = value;
            }

            grid[rowNum] = cols;
        }

        if (grid.Count == 0) return ([], "");

        // A1 = 更新日
        string a1 = grid.TryGetValue(1, out var r1) && r1.TryGetValue(1, out var v) ? v : "";

        var rows = new List<string[]>();
        foreach (var (rowNum, cols) in grid)
        {
            if (rowNum < 2) continue;
            string c1 = cols.TryGetValue(1, out var v1) ? v1 : "";
            string c2 = cols.TryGetValue(2, out var v2) ? v2 : "";
            if (!string.IsNullOrWhiteSpace(c1))
                rows.Add([c1, c2]);
        }

        return (rows, a1);
    }

    // ── セル参照 → 列番号 (A=1, B=2, AA=27 ...) ─────────────────────────

    private static int ParseColNumber(string cellRef)
    {
        int col = 0;
        foreach (char c in cellRef)
        {
            if (!char.IsAsciiLetter(c)) break;
            col = col * 26 + (char.ToUpper(c) - 'A' + 1);
        }
        return col;
    }
}
