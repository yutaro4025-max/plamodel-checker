using ClosedXML.Excel;
using PlamodelChecker.Config;

namespace PlamodelChecker.Core;

public class IndexLoader
{
    private readonly string _filePath;

    public IndexLoader(string filePath)
    {
        _filePath = filePath;
    }

    public (List<IndexRecord> Records, string UpdateDate) Load()
    {
        var records = new List<IndexRecord>();

        // ClosedXML は読み取り専用で開くため Excel プロセスに依存しない
        using var workbook = new XLWorkbook(_filePath);
        var sheet = workbook.Worksheet(AppConfig.DataSheetIndex);

        string updateDate = sheet
            .Cell(AppConfig.UpdateDateRow, AppConfig.UpdateDateCol)
            .GetString();

        int lastRow = sheet.LastRowUsed()?.RowNumber() ?? AppConfig.DataStartRow - 1;

        for (int row = AppConfig.DataStartRow; row <= lastRow; row++)
        {
            string key = sheet.Cell(row, AppConfig.KeyColumn).GetString().Trim();
            if (string.IsNullOrEmpty(key)) continue;

            string path = sheet.Cell(row, AppConfig.PathColumn).GetString().Trim();
            records.Add(new IndexRecord(key, path));
        }

        return (records, updateDate);
    }
}
