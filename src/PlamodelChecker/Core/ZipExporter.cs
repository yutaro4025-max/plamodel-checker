using System.IO.Compression;

namespace PlamodelChecker.Core;

public static class ZipExporter
{
    public record Result(string ZipPath, int CopiedCount, IReadOnlyList<string> Errors);

    /// <summary>
    /// 検索結果のファイルを一時フォルダにコピーし ZIP 化して保存する。
    /// System.IO.Compression を使用するため PowerShell 不要。
    /// </summary>
    public static Result Export(IEnumerable<IndexRecord> records, string saveFolder)
    {
        string zipName = $"検索結果_{DateTime.Now:yyyyMMdd_HHmmss}";
        string tempFolder = Path.Combine(saveFolder, zipName);
        string zipPath = tempFolder + ".zip";
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

            ZipFile.CreateFromDirectory(tempFolder, zipPath);
        }
        finally
        {
            if (Directory.Exists(tempFolder))
            {
                try { Directory.Delete(tempFolder, true); } catch { /* ベストエフォート */ }
            }
        }

        return new Result(zipPath, copiedCount, errors);
    }

    // 同名ファイルが存在する場合は _1, _2 ... でリネーム
    private static string BuildDestPath(string folder, string sourceFile)
    {
        string baseName = Path.GetFileNameWithoutExtension(sourceFile);
        string ext = Path.GetExtension(sourceFile);
        string dest = Path.Combine(folder, baseName + ext);

        int cnt = 1;
        while (File.Exists(dest))
        {
            dest = Path.Combine(folder, $"{baseName}_{cnt}{ext}");
            cnt++;
        }

        return dest;
    }
}
