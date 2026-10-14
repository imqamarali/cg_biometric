// CG Biometric setup / uninstaller (single exe, per-user, no admin rights).
// Built by build_installer.ps1 with the .NET Framework compiler (csc.exe) and
// the app packed as the embedded resource "app.zip".
//
//   Setup.exe              install (asks first)
//   Setup.exe /silent /password:XXXX   install without prompts
//
// The app payload (resource "app.enc") is AES-256 encrypted; the installer
// password is the only way to unpack it. Layout: salt(16) hmac(32) iv(16) data.
//   Uninstall.exe /uninstall   remove the app (this same exe is copied into the install folder)
using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Security.Cryptography;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

static class Program
{
    const string AppName = "CG Biometric";
    const string Publisher = "CG Biometric Solutions";
    const string LayersKey = @"Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers";
    const string UninstallKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\CGBiometric";

    static readonly string InstallDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        @"Programs\CG Biometric");
    static readonly string StartMenuDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.Programs), "CG Biometric");
    static readonly string DesktopLink = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "CG Biometric.lnk");

    [STAThread]
    static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        bool silent = Array.IndexOf(args, "/silent") >= 0;
        try
        {
            if (Array.IndexOf(args, "/uninstall") >= 0) return Uninstall(silent);
            return Install(silent, args);
        }
        catch (Exception ex)
        {
            if (!silent)
                MessageBox.Show(ex.Message, AppName + " Setup", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    static string ReadResourceText(string name)
    {
        using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
        using (StreamReader r = new StreamReader(s))
            return r.ReadToEnd().Trim();
    }

    static void KillRunning()
    {
        foreach (string n in new string[] { "cg_biometric", "FingerprintReaderApp" })
            foreach (Process p in Process.GetProcessesByName(n))
            {
                try { p.Kill(); p.WaitForExit(3000); } catch { }
            }
    }

    const int Iterations = 200000;

    /// Derives the 32-byte AES key and the 32-byte MAC key from the password.
    static void DeriveKeys(string password, byte[] salt, out byte[] encKey, out byte[] macKey)
    {
        using (Rfc2898DeriveBytes kdf = new Rfc2898DeriveBytes(password, salt, Iterations))
        {
            byte[] k = kdf.GetBytes(64);
            encKey = new byte[32]; macKey = new byte[32];
            Buffer.BlockCopy(k, 0, encKey, 0, 32);
            Buffer.BlockCopy(k, 32, macKey, 0, 32);
        }
    }

    static byte[] ReadPayload()
    {
        using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream("app.enc"))
        using (MemoryStream ms = new MemoryStream())
        {
            s.CopyTo(ms);
            return ms.ToArray();
        }
    }

    /// True when the password opens the payload (checked with the HMAC, nothing is written).
    static bool PasswordOk(byte[] blob, string password, out byte[] encKey)
    {
        byte[] salt = new byte[16];
        Buffer.BlockCopy(blob, 0, salt, 0, 16);
        byte[] macKey;
        DeriveKeys(password, salt, out encKey, out macKey);
        using (HMACSHA256 h = new HMACSHA256(macKey))
        {
            byte[] mac = h.ComputeHash(blob, 48, blob.Length - 48);
            int diff = 0;
            for (int i = 0; i < 32; i++) diff |= mac[i] ^ blob[16 + i];
            return diff == 0;
        }
    }

    static void DecryptToFile(byte[] blob, byte[] encKey, string outPath)
    {
        byte[] iv = new byte[16];
        Buffer.BlockCopy(blob, 48, iv, 0, 16);
        using (Aes aes = Aes.Create())
        {
            aes.Key = encKey; aes.IV = iv;
            aes.Mode = CipherMode.CBC; aes.Padding = PaddingMode.PKCS7;
            using (ICryptoTransform dec = aes.CreateDecryptor())
            using (FileStream fs = File.Create(outPath))
            using (CryptoStream cs = new CryptoStream(fs, dec, CryptoStreamMode.Write))
                cs.Write(blob, 64, blob.Length - 64);
        }
    }

    /// Shows the password box; returns null when cancelled.
    static string AskPassword(string error)
    {
        using (Form f = new Form())
        {
            f.Text = AppName + " Setup";
            f.FormBorderStyle = FormBorderStyle.FixedDialog;
            f.StartPosition = FormStartPosition.CenterScreen;
            f.MaximizeBox = false; f.MinimizeBox = false;
            f.ClientSize = new Size(380, 150);
            Label l = new Label();
            l.Text = "Enter the installation password:";
            l.AutoSize = true; l.Location = new Point(16, 16);
            TextBox tb = new TextBox();
            tb.UseSystemPasswordChar = true;
            tb.SetBounds(16, 40, 348, 24);
            Label e = new Label();
            e.Text = error ?? "";
            e.ForeColor = Color.Firebrick;
            e.AutoSize = true; e.Location = new Point(16, 72);
            Button ok = new Button();
            ok.Text = "Install"; ok.DialogResult = DialogResult.OK;
            ok.SetBounds(204, 108, 78, 28);
            Button cancel = new Button();
            cancel.Text = "Cancel"; cancel.DialogResult = DialogResult.Cancel;
            cancel.SetBounds(288, 108, 78, 28);
            f.Controls.AddRange(new Control[] { l, tb, e, ok, cancel });
            f.AcceptButton = ok; f.CancelButton = cancel;
            f.Shown += delegate { tb.Focus(); };
            return f.ShowDialog() == DialogResult.OK ? tb.Text : null;
        }
    }

    static string ArgValue(string[] args, string prefix)
    {
        foreach (string a in args)
            if (a.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) return a.Substring(prefix.Length);
        return null;
    }

    static int Install(bool silent, string[] args)
    {
        string version = ReadResourceText("version.txt");
        if (!silent)
        {
            DialogResult ask = MessageBox.Show(
                "Install " + AppName + " " + version + "?\n\nIt will be installed for your user account in:\n" + InstallDir,
                AppName + " Setup", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
            if (ask != DialogResult.Yes) return 2;
        }

        byte[] blob = ReadPayload();
        byte[] encKey = null;
        if (silent)
        {
            string pw = ArgValue(args, "/password:");
            if (pw == null || !PasswordOk(blob, pw, out encKey)) return 3;
        }
        else
        {
            string error = null;
            for (int attempt = 0; ; attempt++)
            {
                string pw = AskPassword(error);
                if (pw == null) return 2;
                if (PasswordOk(blob, pw, out encKey)) break;
                if (attempt >= 4)
                {
                    MessageBox.Show("Too many incorrect attempts.", AppName + " Setup",
                        MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return 3;
                }
                error = "Incorrect password. Try again.";
            }
        }

        Exception failure = null;
        Thread worker = new Thread(delegate ()
        {
            try { DoInstall(version, blob, encKey); } catch (Exception ex) { failure = ex; }
        });

        if (silent)
        {
            worker.Start();
            worker.Join();
        }
        else
        {
            using (Form f = new Form())
            {
                f.Text = AppName + " Setup";
                f.FormBorderStyle = FormBorderStyle.FixedDialog;
                f.StartPosition = FormStartPosition.CenterScreen;
                f.MaximizeBox = false; f.MinimizeBox = false; f.ControlBox = false;
                f.ClientSize = new Size(380, 90);
                Label l = new Label();
                l.Text = "Installing " + AppName + "...";
                l.AutoSize = true; l.Location = new Point(16, 14);
                ProgressBar pb = new ProgressBar();
                pb.Style = ProgressBarStyle.Marquee;
                pb.MarqueeAnimationSpeed = 30;
                pb.SetBounds(16, 44, 348, 22);
                f.Controls.Add(l); f.Controls.Add(pb);
                System.Windows.Forms.Timer t = new System.Windows.Forms.Timer();
                t.Interval = 200;
                t.Tick += delegate { if (!worker.IsAlive) { t.Stop(); f.Close(); } };
                f.Shown += delegate { worker.Start(); t.Start(); };
                f.ShowDialog();
            }
        }

        if (failure != null)
        {
            if (!silent)
                MessageBox.Show("Installation failed:\n\n" + failure.Message, AppName + " Setup",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }

        if (!silent)
        {
            DialogResult run = MessageBox.Show(
                AppName + " " + version + " was installed.\n\nStart it now?",
                AppName + " Setup", MessageBoxButtons.YesNo, MessageBoxIcon.Information);
            if (run == DialogResult.Yes)
            {
                ProcessStartInfo psi = new ProcessStartInfo(Path.Combine(InstallDir, "cg_biometric.exe"));
                psi.WorkingDirectory = InstallDir;
                Process.Start(psi);
            }
        }
        return 0;
    }

    static void DoInstall(string version, byte[] blob, byte[] encKey)
    {
        KillRunning();
        Thread.Sleep(400);

        string tmpZip = Path.Combine(Path.GetTempPath(), "cg_biometric_setup_" + Guid.NewGuid().ToString("N") + ".zip");
        DecryptToFile(blob, encKey, tmpZip);

        try
        {
            if (Directory.Exists(InstallDir)) Directory.Delete(InstallDir, true);
            Directory.CreateDirectory(InstallDir);
            ZipFile.ExtractToDirectory(tmpZip, InstallDir);
        }
        finally
        {
            try { File.Delete(tmpZip); } catch { }
        }

        // This exe doubles as the uninstaller.
        string uninstaller = Path.Combine(InstallDir, "Uninstall.exe");
        File.Copy(Assembly.GetExecutingAssembly().Location, uninstaller, true);

        string exe = Path.Combine(InstallDir, "cg_biometric.exe");
        Directory.CreateDirectory(StartMenuDir);
        MakeShortcut(Path.Combine(StartMenuDir, "CG Biometric.lnk"), exe, null);
        MakeShortcut(Path.Combine(StartMenuDir, "Uninstall CG Biometric.lnk"), uninstaller, "/uninstall");
        MakeShortcut(DesktopLink, exe, null);

        // Windows only hands out the raw fingerprint image to administrators, so the
        // app asks for elevation (one UAC prompt per launch). Per-user setting, no admin needed here.
        using (RegistryKey lk = Registry.CurrentUser.CreateSubKey(LayersKey))
            lk.SetValue(exe, "~ RUNASADMIN", RegistryValueKind.String);

        using (RegistryKey k = Registry.CurrentUser.CreateSubKey(UninstallKey))
        {
            k.SetValue("DisplayName", AppName);
            k.SetValue("DisplayVersion", version);
            k.SetValue("Publisher", Publisher);
            k.SetValue("InstallLocation", InstallDir);
            k.SetValue("DisplayIcon", exe);
            k.SetValue("UninstallString", "\"" + uninstaller + "\" /uninstall");
            k.SetValue("QuietUninstallString", "\"" + uninstaller + "\" /uninstall /silent");
            k.SetValue("NoModify", 1, RegistryValueKind.DWord);
            k.SetValue("NoRepair", 1, RegistryValueKind.DWord);
            long bytes = 0;
            foreach (string f in Directory.GetFiles(InstallDir, "*", SearchOption.AllDirectories))
                bytes += new FileInfo(f).Length;
            k.SetValue("EstimatedSize", (int)(bytes / 1024), RegistryValueKind.DWord);
        }
    }

    static void MakeShortcut(string linkPath, string target, string arguments)
    {
        Type t = Type.GetTypeFromProgID("WScript.Shell");
        dynamic shell = Activator.CreateInstance(t);
        dynamic link = shell.CreateShortcut(linkPath);
        link.TargetPath = target;
        if (arguments != null) link.Arguments = arguments;
        link.WorkingDirectory = Path.GetDirectoryName(target);
        link.IconLocation = Path.Combine(InstallDir, "cg_biometric.exe") + ",0";
        link.Description = AppName;
        link.Save();
    }

    static int Uninstall(bool silent)
    {
        if (!silent)
        {
            DialogResult ask = MessageBox.Show("Remove " + AppName + " from this computer?",
                AppName + " Uninstall", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
            if (ask != DialogResult.Yes) return 2;
        }
        KillRunning();
        Thread.Sleep(400);

        try { if (Directory.Exists(StartMenuDir)) Directory.Delete(StartMenuDir, true); } catch { }
        try { if (File.Exists(DesktopLink)) File.Delete(DesktopLink); } catch { }
        try { Registry.CurrentUser.DeleteSubKeyTree(UninstallKey, false); } catch { }
        try
        {
            using (RegistryKey lk = Registry.CurrentUser.OpenSubKey(LayersKey, true))
                if (lk != null) lk.DeleteValue(Path.Combine(InstallDir, "cg_biometric.exe"), false);
        }
        catch { }

        // The running exe lives in the install folder, so delete it from a helper after exit.
        ProcessStartInfo psi = new ProcessStartInfo("cmd.exe",
            "/c ping 127.0.0.1 -n 3 >nul & rmdir /s /q \"" + InstallDir + "\"");
        psi.WindowStyle = ProcessWindowStyle.Hidden;
        psi.CreateNoWindow = true;
        psi.UseShellExecute = false;
        Process.Start(psi);

        if (!silent)
            MessageBox.Show(AppName + " was removed.", AppName + " Uninstall",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
        return 0;
    }
}
