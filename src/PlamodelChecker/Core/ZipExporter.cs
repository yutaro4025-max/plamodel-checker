using System.IO.Compression;

namespace PlamodelChecker.Core;

public static class ZipExporter
{
    public record Result(string ZipPath, int CopiedCount, IReadOnlyList<string> Errors);

    /// <summary>
    /// 検索結果のファイルを ZIP にまとめて指定パスに保存する。
    /// zipFilePath はフルパス（例: C:\Users\...\検索結果_20260603.zip）。
    /// </summary>
    public static Result Export(IEnumerable<IndexRecord> records, string zipFilePath)
    {
        string tempFolder = Path.Combine(
            Path.GetDirectoryName(zipFilePath) ?? Path.GetTempPath(),
            Path.GetFileNameWithoutExtension(zipFilePath) + "_tmp");

        var errors = new List<string>();
        int copiedCount = 0;

        Directory.CreateDirectory(tempFolder);

        try
        {
            foreach (var record in records)
            {
                if (!File.Exists(record.FilePath))
                {
                    errors.Add($"(パス不存在) {record.FilePath}");
                    continue;
                }

                string dest = BuildDestPath(tempFolder, record.FilePath);
                File.Copy(record.FilePath, dest);
                copiedCount++;
            }

            if (copiedCount == 0)
                return new Result("", 0, errors);

            if (File.Exists(zipFilePath))
                File.Delete(zipFilePath);

            ZipFile.CreateFromDirectory(tempFolder, zipFilePath);
        }
        finally
        {
            if (Directory.Exists(tempFolder))
            {
                try { Directory.Delete(tempFolder, true); } catch { }
            }
        }

        return new Result(zipFilePath, copiedCount, errors);
    }

    private static string BuildDestPath(string folder, string sourceFile)
    {
        string baseName = Path.GetFileNameWithoutExtension(sourceFile);
        string ext      = Path.GetExtension(sourceFile);
        string dest     = Path.Combine(folder, baseName + ext);

        int cnt = 1;
        while (File.Exists(dest))
        {
            dest = Path.Combine(folder, $"{baseName}_{cnt}{ext}");
            cnt++;
        }
        return dest;
    }
}
