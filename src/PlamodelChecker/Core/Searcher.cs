namespace PlamodelChecker.Core;

public static class Searcher
{
    /// <summary>
    /// フリーワードモード: text3 でキー列を部分一致検索。
    /// セグメントモード:   入力済みの全TextBoxが対応セグメントに前方一致する場合のみヒット。
    ///   - 空のTextBoxは無条件スルー
    ///   - 対応セグメントが存在しない場合は不一致（例: 2セグメント品番でTextBox2に値あり → 不一致）
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
            bool hit = freeWordMode
                ? record.Key.Contains(text3, StringComparison.OrdinalIgnoreCase)
                : MatchesSegments(record.Key, textB);

            if (hit) results.Add(record);
        }

        return results;
    }

    private static bool MatchesSegments(string key, string[] textB)
    {
        // "_" で最大3分割
        string[] parts = key.Split('_', 3);

        for (int j = 0; j < 3; j++)
        {
            if (textB[j] == "") continue; // 空TextBoxはチェックしない

            // 対応セグメントが存在しなければ不一致
            if (parts.Length <= j) return false;

            // 前方一致: セグメントをTextBox入力長に切り詰めて比較
            string segment = parts[j];
            string prefix  = segment.Length >= textB[j].Length
                ? segment[..textB[j].Length]
                : segment;

            if (!prefix.Equals(textB[j], StringComparison.OrdinalIgnoreCase))
                return false;
        }

        return true; // 入力済み全TextBoxが一致
    }
}
