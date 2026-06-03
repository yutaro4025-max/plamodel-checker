using PlamodelChecker.Config;

namespace PlamodelChecker.Core;

public class IndexLoader
{
    private readonly string _filePath;

    public IndexLoader(string filePath)
    {
        _filePath = filePath;
    }

    /// <summary>
    /// xlsm/xlsx をExcelプロセス不要で読み込む（NuGetパッケージ不使用）。
    /// </summary>
    public (List<IndexRecord> Records, string UpdateDate) Load()
    {
        var (rows, updateDate) = SimpleXlsxReader.Read(_filePath, AppConfig.DataSheetIndex);

        var records = rows
            .Select(r => new IndexRecord(
                Key: r.Length > 0 ? r[0] : "",
                FilePath: r.Length > 1 ? r[1] : ""))
            .Where(r => !string.IsNullOrEmpty(r.Key))
            .ToList();

        return (records, updateDate);
    }
}
