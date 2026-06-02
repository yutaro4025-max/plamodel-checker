namespace PlamodelChecker.Core;

public static class Searcher
{
    /// <summary>
    /// VBA CommandButton1_Click の検索ロジックを移植。
    ///
    /// フリーワードモード（chkFreeWord=ON）:
    ///   text3 でキー列を部分一致検索。
    ///
    /// セグメントモード（chkFreeWord=OFF）:
    ///   キーを "_" で最大3分割し、各セグメントの先頭 N 文字を
    ///   対応するテキストボックスと前方一致比較。
    ///   ・分割数が3未満の場合、入力済みテキストボックスと一致した時点でヒット
    ///   ・分割数が3以上の場合、3つ目のセグメントまで確認してヒット
    /// </summary>
    public static List<IndexRecord> Search(
        IEnumerable<IndexRecord> records,
        string text1, string text2, string text3,
        bool freeWordMode)
    {
        var results = new List<IndexRecord>();
        string[] textB = [text1, text2, text3];

        foreach (var record in records)
        {
            if (freeWordMode)
            {
                if (record.Key.Contains(text3, StringComparison.OrdinalIgnoreCase))
                    results.Add(record);
            }
            else
            {
                if (MatchesSegments(record.Key, textB))
                    results.Add(record);
            }
        }

        return results;
    }

    private static bool MatchesSegments(string key, string[] textB)
    {
        // VBA: Split(key, "_", 3, vbTextCompare) → 最大3要素
        string[] parts = key.Split('_', 3);

        // 各セグメントを対応するテキストボックスの長さに切り詰め（前方一致用）
        var search = new string[3];
        for (int j = 0; j < 3; j++)
        {
            if (parts.Length <= j)
            {
                search[j] = "";
            }
            else
            {
                search[j] = textB[j].Length > 0
                    ? parts[j][..Math.Min(parts[j].Length, textB[j].Length)]
                    : parts[j];
            }
        }

        for (int j = 0; j < 3; j++)
        {
            // セグメントにテキストボックスの文字列が含まれなければ不一致
            // VBA: InStr(Search(j), TextB(j)) = 0 → Exit For
            if (!search[j].Contains(textB[j], StringComparison.OrdinalIgnoreCase))
                return false;

            // ヒット条件:
            //   (入力あり AND 分割数<3) → このセグメントが品番の末尾
            //   OR j=2                  → 3つ目まで全てチェック済み
            // VBA: Not TextB(j)="" And UBound(strSplit)<2 Or j=2
            bool isLastSegment = (textB[j] != "" && parts.Length < 3) || j == 2;
            if (isLastSegment)
                return true;
        }

        return false;
    }
}
