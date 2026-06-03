namespace PlamodelChecker.UI;

partial class MainForm
{
    private System.ComponentModel.IContainer components = null;

    private GroupBox grpKeyword = null!;
    private Label lblHakko = null!;
    private Label lblTorihiki = null!;
    private Label lblMainNo = null!;
    private TextBox txtKeyword1 = null!;
    private TextBox txtKeyword2 = null!;
    private TextBox txtKeyword3 = null!;
    private CheckBox chkFreeWord = null!;
    private Button btnZip = null!;
    private Button btnConfig = null!;
    private Button btnClear = null!;
    private Button btnSearch = null!;
    private Label lblSearchContent = null!;
    private ListBox listBox1 = null!;
    private Label lblResultCount = null!;
    private Label lblUpdateDate = null!;
    private LinkLabel lnkManual = null!;
    private Button btnClose = null!;

    protected override void Dispose(bool disposing)
    {
        if (disposing && (components != null))
            components.Dispose();
        base.Dispose(disposing);
    }

    private void InitializeComponent()
    {
        grpKeyword   = new GroupBox();
        lblHakko     = new Label();
        lblTorihiki  = new Label();
        lblMainNo    = new Label();
        txtKeyword1  = new TextBox();
        txtKeyword2  = new TextBox();
        txtKeyword3  = new TextBox();
        chkFreeWord  = new CheckBox();
        btnZip       = new Button();
        btnConfig    = new Button();
        btnClear     = new Button();
        btnSearch    = new Button();
        lblSearchContent = new Label();
        listBox1     = new ListBox();
        lblResultCount = new Label();
        lblUpdateDate = new Label();
        lnkManual    = new LinkLabel();
        btnClose     = new Button();

        grpKeyword.SuspendLayout();
        SuspendLayout();

        // ── フォーム ──────────────────────────────────────────────────────
        ClientSize      = new Size(462, 465);
        Text            = "荷姿設定書 検索ツール";
        Font            = new Font("Meiryo UI", 9F);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox     = false;
        StartPosition   = FormStartPosition.CenterScreen;

        // ── グループボックス「検索キーワード」 ────────────────────────────
        grpKeyword.Text     = "検索キーワード";
        grpKeyword.Location = new Point(5, 5);
        grpKeyword.Size     = new Size(452, 108);
        grpKeyword.Controls.AddRange([
            lblHakko, txtKeyword1,
            lblTorihiki, txtKeyword2,
            lblMainNo, txtKeyword3,
            chkFreeWord,
        ]);

        // 行1: 発行機種 / 取引先コード
        lblHakko.Text      = "発行機種";
        lblHakko.Location  = new Point(8, 24);
        lblHakko.Size      = new Size(60, 23);
        lblHakko.TextAlign = ContentAlignment.MiddleLeft;

        txtKeyword1.Location = new Point(70, 21);
        txtKeyword1.Size     = new Size(110, 23);
        txtKeyword1.KeyDown += txt_KeyDown;

        lblTorihiki.Text      = "取引先コード";
        lblTorihiki.Location  = new Point(192, 24);
        lblTorihiki.Size      = new Size(85, 23);
        lblTorihiki.TextAlign = ContentAlignment.MiddleLeft;

        txtKeyword2.Location = new Point(280, 21);
        txtKeyword2.Size     = new Size(162, 23);
        txtKeyword2.KeyDown += txt_KeyDown;

        // 行2: 主No ヒント / フリーワード
        lblMainNo.Text      = "主No.(5)  ─  類別No.(3)  ─  種別No.(2)";
        lblMainNo.Location  = new Point(8, 52);
        lblMainNo.Size      = new Size(255, 20);
        lblMainNo.TextAlign = ContentAlignment.MiddleLeft;
        lblMainNo.ForeColor = SystemColors.GrayText;

        chkFreeWord.Text            = "フリーワード検索";
        chkFreeWord.Location        = new Point(278, 50);
        chkFreeWord.Size            = new Size(165, 23);
        chkFreeWord.CheckedChanged += chkFreeWord_CheckedChanged;

        // 行3: TextBox3
        txtKeyword3.Location = new Point(8, 76);
        txtKeyword3.Size     = new Size(255, 23);
        txtKeyword3.KeyDown += txt_KeyDown;

        // ── ボタン行 ──────────────────────────────────────────────────────
        btnZip.Text    = "ZIP 保存";
        btnZip.Location = new Point(5, 120);
        btnZip.Size    = new Size(80, 28);
        btnZip.Click  += btnZip_Click;

        btnConfig.Text    = "設定";
        btnConfig.Location = new Point(92, 120);
        btnConfig.Size    = new Size(60, 28);
        btnConfig.Click  += btnConfig_Click;

        btnClear.Text    = "クリア";
        btnClear.Location = new Point(159, 120);
        btnClear.Size    = new Size(60, 28);
        btnClear.Click  += btnClear_Click;

        btnSearch.Text    = "主No.(5)  -  類別No.(3)  -  種別No.(2)　検索";
        btnSearch.Location = new Point(226, 120);
        btnSearch.Size    = new Size(231, 28);
        btnSearch.Click  += btnSearch_Click;

        // ── 検索内容ラベル ─────────────────────────────────────────────────
        lblSearchContent.Text      = "検索内容";
        lblSearchContent.Location  = new Point(5, 155);
        lblSearchContent.Size      = new Size(100, 20);
        lblSearchContent.TextAlign = ContentAlignment.MiddleLeft;

        // ── リストボックス ─────────────────────────────────────────────────
        listBox1.Location           = new Point(5, 175);
        listBox1.Size               = new Size(452, 185);
        listBox1.ScrollAlwaysVisible = true;
        listBox1.DoubleClick        += listBox1_DoubleClick;

        // ── 検索件数 ───────────────────────────────────────────────────────
        lblResultCount.Text      = "検索件数：";
        lblResultCount.Location  = new Point(5, 368);
        lblResultCount.Size      = new Size(230, 20);
        lblResultCount.TextAlign = ContentAlignment.MiddleLeft;

        // ── 更新日時 ───────────────────────────────────────────────────────
        lblUpdateDate.Text      = "更新日時：";
        lblUpdateDate.Location  = new Point(5, 390);
        lblUpdateDate.Size      = new Size(230, 20);
        lblUpdateDate.TextAlign = ContentAlignment.MiddleLeft;

        // ── 運用マニュアル ─────────────────────────────────────────────────
        lnkManual.Text        = "運用マニュアル";
        lnkManual.Location    = new Point(250, 375);
        lnkManual.Size        = new Size(110, 20);
        lnkManual.TextAlign   = ContentAlignment.MiddleLeft;
        lnkManual.LinkClicked += lnkManual_LinkClicked;

        // ── 終了ボタン ─────────────────────────────────────────────────────
        btnClose.Text    = "終了";
        btnClose.Location = new Point(372, 368);
        btnClose.Size    = new Size(85, 40);
        btnClose.Click  += btnClose_Click;

        // ── コントロール追加 ───────────────────────────────────────────────
        grpKeyword.ResumeLayout(false);
        Controls.AddRange([
            grpKeyword,
            btnZip, btnConfig, btnClear, btnSearch,
            lblSearchContent,
            listBox1,
            lblResultCount,
            lblUpdateDate,
            lnkManual,
            btnClose,
        ]);

        ResumeLayout(false);
        PerformLayout();
    }
}
