namespace PlamodelChecker.Config;

public static class AppConfig
{
    public static string AppTitle { get; } = "使用設定書 検索ツール";

    // インデックスファイル（exeと同フォルダに配置）
    public static string IndexFileName { get; } = "使用設定書一覧.xlsm";

    // 操作マニュアル（exeの1つ上のフォルダに配置）
    public static string ManualFileName { get; } = "工場設備使用設定書操作マニュアル_1.pptx";

    // Sheet1 の列・行定義（1始まり）
    public static int DataSheetIndex { get; } = 1;
    public static int UpdateDateRow { get; } = 1;
    public static int UpdateDateCol { get; } = 1;
    public static int KeyColumn { get; } = 1;   // A列: 品番
    public static int PathColumn { get; } = 2;  // B列: ファイルパス
    public static int DataStartRow { get; } = 2;
}
