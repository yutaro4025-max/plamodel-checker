using PlamodelChecker.Config;
using PlamodelChecker.Core;

namespace PlamodelChecker.UI;

public partial class MainForm : Form
{
    private List<IndexRecord> _records = [];
    private string _indexFilePath = "";

    public MainForm()
    {
        InitializeComponent();
        LoadIndex();
    }

    // ── 起動時インデックス読み込み ──────────────────────────────────────

    private void LoadIndex()
    {
        string exeFolder = AppDomain.CurrentDomain.BaseDirectory;
        _indexFilePath = Path.Combine(exeFolder, AppConfig.IndexFileName);

        if (!File.Exists(_indexFilePath))
        {
            MessageBox.Show(
                $"インデックスファイルが見つかりません:\n{_indexFilePath}\n\n" +
                $"exeと同じフォルダに「{AppConfig.IndexFileName}」を配置してください。",
                AppConfig.AppTitle, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        try
        {
            var loader = new IndexLoader(_indexFilePath);
            var (records, updateDate) = loader.Load();
            _records = records;
            lblUpdateDate.Text = $"更新日: {updateDate}";
        }
        catch (IOException ex)
        {
            MessageBox.Show(
                $"インデックスファイルの読み込みに失敗しました。\n" +
                $"他のアプリが排他ロック中の可能性があります。\n\n{ex.Message}",
                AppConfig.AppTitle, MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"インデックスファイルの読み込みに失敗しました:\n{ex.Message}",
                AppConfig.AppTitle, MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    // ── 検索 ────────────────────────────────────────────────────────────

    private void btnSearch_Click(object sender, EventArgs e)
    {
        string t1 = txtKeyword1.Text.Trim();
        string t2 = txtKeyword2.Text.Trim();
        string t3 = txtKeyword3.Text.Trim();

        if (t1 == "" && t2 == "" && t3 == "")
        {
            MessageBox.Show("少なくとも1つのキーワードを入力してください！",
                AppConfig.AppTitle, MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        var results = Searcher.Search(_records, t1, t2, t3, chkFreeWord.Checked);

        listBox1.Items.Clear();
        foreach (var r in results)
            listBox1.Items.Add(r.Key);

        lblResultCount.Text = $"検索結果: {listBox1.Items.Count} 件";

        if (listBox1.Items.Count > 0)
        {
            listBox1.Focus();
            listBox1.SelectedIndex = 0;
        }
        else
        {
            MessageBox.Show("データがありません！\nキーワードを変更して検索してください。",
                AppConfig.AppTitle, MessageBoxButtons.OK, MessageBoxIcon.Warning);
            txtKeyword1.Focus();
        }
    }

    // ── クリア ───────────────────────────────────────────────────────────

    private void btnClear_Click(object sender, EventArgs e)
    {
        txtKeyword1.Text = "";
        txtKeyword2.Text = "";
        txtKeyword3.Text = "";
        listBox1.Items.Clear();
        lblResultCount.Text = "検索結果: 0 件";
        txtKeyword1.Focus();
    }

    // ── 終了 ────────────────────────────────────────────────────────────

    private void btnClose_Click(object sender, EventArgs e) => Close();

    // ── リストボックス ダブルクリック → ファイルを開く ─────────────────────

    private void listBox1_DoubleClick(object sender, EventArgs e)
    {
        if (listBox1.SelectedIndex < 0) return;

        string key = listBox1.SelectedItem?.ToString() ?? "";
        var record = _records.FirstOrDefault(r => r.Key == key);

        if (record == null)
        {
            MessageBox.Show("データは削除・変更されています！\n検索をやり直してください。",
                AppConfig.AppTitle, MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        try
        {
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = record.FilePath,
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"ファイルを開けませんでした:\n{record.FilePath}\n\n{ex.Message}",
                AppConfig.AppTitle, MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    // ── フリーワードチェックボックス ────────────────────────────────────

    private void chkFreeWord_CheckedChanged(object sender, EventArgs e)
    {
        bool free = chkFreeWord.Checked;
        txtKeyword1.Enabled = !free;
        txtKeyword2.Enabled = !free;
        if (free)
        {
            txtKeyword1.Text = "";
            txtKeyword2.Text = "";
            txtKeyword1.BackColor = SystemColors.Control;
            txtKeyword2.BackColor = SystemColors.Control;
        }
        else
        {
            txtKeyword1.BackColor = SystemColors.Window;
            txtKeyword2.BackColor = SystemColors.Window;
        }
    }

    // ── ZIP保存 ──────────────────────────────────────────────────────────

    private void btnZip_Click(object sender, EventArgs e)
    {
        if (listBox1.Items.Count == 0)
        {
            MessageBox.Show("ZIPにまとめるファイルがありません。\n先に検索を行ってください。",
                "ZIP保存", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        using var dialog = new FolderBrowserDialog
        {
            Description = "ZIP保存先フォルダを選択してください",
            InitialDirectory = Path.GetDirectoryName(_indexFilePath) ?? ""
        };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;

        var targets = listBox1.Items
            .Cast<string>()
            .Select(key => _records.FirstOrDefault(r => r.Key == key))
            .OfType<IndexRecord>()
            .ToList();

        ZipExporter.Result result;
        try
        {
            result = ZipExporter.Export(targets, dialog.SelectedPath);
        }
        catch (Exception ex)
        {
            MessageBox.Show($"ZIP作成中にエラーが発生しました:\n{ex.Message}",
                "ZIP保存", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        if (result.CopiedCount == 0)
        {
            string errDetail = result.Errors.Count > 0
                ? "\n\n" + string.Join("\n", result.Errors) : "";
            MessageBox.Show("有効なファイルが1件もコピーできませんでした。" + errDetail,
                "ZIP保存", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        string msg = $"ZIP保存が完了しました！\n\n" +
                     $"保存先: {result.ZipPath}\n" +
                     $"ファイル数: {result.CopiedCount} 件";
        if (result.Errors.Count > 0)
            msg += $"\n\n【注意】スキップされたファイル:\n{string.Join("\n", result.Errors)}";

        if (MessageBox.Show(msg + "\n\n保存先フォルダを開きますか？",
                "ZIP保存完了", MessageBoxButtons.YesNo, MessageBoxIcon.Information) == DialogResult.Yes)
        {
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = dialog.SelectedPath,
                UseShellExecute = true
            });
        }
    }

    // ── 操作マニュアル（ダブルクリック）────────────────────────────────

    private void lnkManual_LinkClicked(object sender, LinkLabelLinkClickedEventArgs e)
    {
        string exeFolder = AppDomain.CurrentDomain.BaseDirectory;
        string parentFolder = Directory.GetParent(exeFolder.TrimEnd('\\', '/'))?.FullName ?? exeFolder;
        string pptPath = Path.Combine(parentFolder, AppConfig.ManualFileName);

        if (!File.Exists(pptPath))
        {
            MessageBox.Show(
                $"　{AppConfig.ManualFileName} が存在しません！\n　管理者に連絡してください。",
                AppConfig.AppTitle, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
        {
            FileName = pptPath,
            UseShellExecute = true
        });
    }

    // ── Enter キーで検索実行 ─────────────────────────────────────────────

    private void txt_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Enter)
        {
            e.SuppressKeyPress = true;
            btnSearch_Click(sender, EventArgs.Empty);
        }
    }
}
