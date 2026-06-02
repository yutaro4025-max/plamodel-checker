namespace PlamodelChecker.UI;

partial class MainForm
{
    private System.ComponentModel.IContainer components = null;

    // Controls
    private Label lblKeyword1 = null!;
    private Label lblKeyword2 = null!;
    private Label lblKeyword3 = null!;
    private TextBox txtKeyword1 = null!;
    private TextBox txtKeyword2 = null!;
    private TextBox txtKeyword3 = null!;
    private CheckBox chkFreeWord = null!;
    private Button btnSearch = null!;
    private Button btnClear = null!;
    private Label lblResultCount = null!;
    private ListBox listBox1 = null!;
    private Button btnZip = null!;
    private Button btnClose = null!;
    private Label lblUpdateDate = null!;
    private LinkLabel lnkManual = null!;

    protected override void Dispose(bool disposing)
    {
        if (disposing && (components != null))
            components.Dispose();
        base.Dispose(disposing);
    }

    private void InitializeComponent()
    {
        lblKeyword1  = new Label();
        lblKeyword2  = new Label();
        lblKeyword3  = new Label();
        txtKeyword1  = new TextBox();
        txtKeyword2  = new TextBox();
        txtKeyword3  = new TextBox();
        chkFreeWord  = new CheckBox();
        btnSearch    = new Button();
        btnClear     = new Button();
        lblResultCount = new Label();
        listBox1     = new ListBox();
        btnZip       = new Button();
        btnClose     = new Button();
        lblUpdateDate = new Label();
        lnkManual    = new LinkLabel();

        SuspendLayout();

        // ── フォーム ──────────────────────────────────────────────────────
        ClientSize      = new Size(490, 495);
        Text            = "使用設定書 検索ツール";
        Font            = new Font("Meiryo UI", 9F);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox     = false;
        StartPosition   = FormStartPosition.CenterScreen;

        // ── キーワード1 ───────────────────────────────────────────────────
        lblKeyword1.Text      = "キーワード 1";
        lblKeyword1.Location  = new Point(10, 16);
        lblKeyword1.Size      = new Size(90, 23);
        lblKeyword1.TextAlign = ContentAlignment.MiddleLeft;

        txtKeyword1.Location = new Point(105, 13);
        txtKeyword1.Size     = new Size(270, 23);
        txtKeyword1.KeyDown += txt_KeyDown;

        // ── キーワード2 ───────────────────────────────────────────────────
        lblKeyword2.Text      = "キーワード 2";
        lblKeyword2.Location  = new Point(10, 46);
        lblKeyword2.Size      = new Size(90, 23);
        lblKeyword2.TextAlign = ContentAlignment.MiddleLeft;

        txtKeyword2.Location = new Point(105, 43);
        txtKeyword2.Size     = new Size(270, 23);
        txtKeyword2.KeyDown += txt_KeyDown;

        // ── キーワード3 ───────────────────────────────────────────────────
        lblKeyword3.Text      = "キーワード 3";
        lblKeyword3.Location  = new Point(10, 76);
        lblKeyword3.Size      = new Size(90, 23);
        lblKeyword3.TextAlign = ContentAlignment.MiddleLeft;

        txtKeyword3.Location = new Point(105, 73);
        txtKeyword3.Size     = new Size(155, 23);
        txtKeyword3.KeyDown += txt_KeyDown;

        // ── フリーワードチェックボックス ──────────────────────────────────
        chkFreeWord.Text             = "フリーワード検索（3）";
        chkFreeWord.Location         = new Point(268, 74);
        chkFreeWord.Size             = new Size(210, 23);
        chkFreeWord.CheckedChanged  += chkFreeWord_CheckedChanged;

        // ── 検索・クリアボタン ─────────────────────────────────────────────
        btnSearch.Text    = "検索（1）  -  （2）  -  （3）";
        btnSearch.Location = new Point(10, 108);
        btnSearch.Size    = new Size(230, 30);
        btnSearch.Click  += btnSearch_Click;

        btnClear.Text    = "クリア";
        btnClear.Location = new Point(250, 108);
        btnClear.Size    = new Size(80, 30);
        btnClear.Click  += btnClear_Click;

        // ── 検索結果件数 ───────────────────────────────────────────────────
        lblResultCount.Text      = "検索結果: 0 件";
        lblResultCount.Location  = new Point(10, 147);
        lblResultCount.Size      = new Size(470, 20);
        lblResultCount.TextAlign = ContentAlignment.MiddleLeft;

        // ── リストボックス ─────────────────────────────────────────────────
        listBox1.Location        = new Point(10, 170);
        listBox1.Size            = new Size(470, 200);
        listBox1.ScrollAlwaysVisible = true;
        listBox1.DoubleClick    += listBox1_DoubleClick;

        // ── ZIPボタン・閉じるボタン ────────────────────────────────────────
        btnZip.Text    = "ZIP 保存";
        btnZip.Location = new Point(10, 378);
        btnZip.Size    = new Size(100, 30);
        btnZip.Click  += btnZip_Click;

        btnClose.Text    = "閉じる";
        btnClose.Location = new Point(380, 378);
        btnClose.Size    = new Size(100, 30);
        btnClose.Click  += btnClose_Click;

        // ── 更新日 ─────────────────────────────────────────────────────────
        lblUpdateDate.Text      = "更新日: -";
        lblUpdateDate.Location  = new Point(10, 420);
        lblUpdateDate.Size      = new Size(350, 20);
        lblUpdateDate.TextAlign = ContentAlignment.MiddleLeft;

        // ── 操作マニュアルリンク ───────────────────────────────────────────
        lnkManual.Text        = "操作マニュアルを開く";
        lnkManual.Location    = new Point(10, 450);
        lnkManual.Size        = new Size(470, 20);
        lnkManual.TextAlign   = ContentAlignment.MiddleLeft;
        lnkManual.LinkClicked += lnkManual_LinkClicked;

        // ── コントロール追加 ───────────────────────────────────────────────
        Controls.AddRange([
            lblKeyword1, txtKeyword1,
            lblKeyword2, txtKeyword2,
            lblKeyword3, txtKeyword3,
            chkFreeWord,
            btnSearch, btnClear,
            lblResultCount,
            listBox1,
            btnZip, btnClose,
            lblUpdateDate,
            lnkManual,
        ]);

        ResumeLayout(false);
        PerformLayout();
    }
}
