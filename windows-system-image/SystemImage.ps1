#Requires -Version 5.1
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$wbadmin = Join-Path ([Environment]::SystemDirectory) 'wbadmin.exe'
$settings = 'HKCU:\Software\SystemImageBackup'
$logs = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'SystemImageBackup'
$script:job = $null

function Get-BackupTargets {
    $windowsLetter = [char]$env:SystemDrive[0]
    $windowsDisk = (Get-Partition -DriveLetter $windowsLetter).DiskNumber
    foreach ($volume in Get-Volume | Where-Object { $_.DriveLetter -and $_.UniqueId -and $_.FileSystem -eq 'NTFS' -and $_.HealthStatus -eq 'Healthy' }) {
        $partition = Get-Partition -DriveLetter $volume.DriveLetter -ErrorAction SilentlyContinue
        if (-not $partition -or $partition.DiskNumber -eq $windowsDisk -or $partition.IsBoot -or $partition.IsSystem) { continue }
        $disk = Get-Disk -Number $partition.DiskNumber
        if ($disk.IsBoot -or $disk.IsSystem -or $disk.IsReadOnly -or $disk.IsOffline) { continue }
        [pscustomobject]@{
            Id = $volume.UniqueId
            Target = "$($volume.DriveLetter):"
            Display = '{0}:  {1}  |  {2}  |  {3:N1} GB free' -f $volume.DriveLetter, $volume.FileSystemLabel, $disk.FriendlyName, ($volume.SizeRemaining / 1GB)
        }
    }
}

$form = New-Object Windows.Forms.Form
$form.Text = 'Windows System Image'
$form.ClientSize = New-Object Drawing.Size(700,420)
$form.MinimumSize = $form.Size
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 11)

$label = New-Object Windows.Forms.Label
$label.Text = 'Select your backup SSD. Windows and its critical volumes will be included.'
$label.SetBounds(20,18,660,30)
$form.Controls.Add($label)

$targetBox = New-Object Windows.Forms.ComboBox
$targetBox.DropDownStyle = 'DropDownList'
$targetBox.DisplayMember = 'Display'
$targetBox.SetBounds(20,58,540,35)
$form.Controls.Add($targetBox)

$refresh = New-Object Windows.Forms.Button
$refresh.Text = 'Refresh'
$refresh.SetBounds(570,56,110,36)
$form.Controls.Add($refresh)

$update = New-Object Windows.Forms.Button
$update.Text = 'Update backup'
$update.SetBounds(20,105,180,38)
$form.Controls.Add($update)

$check = New-Object Windows.Forms.Button
$check.Text = 'Check backup catalog'
$check.SetBounds(212,105,210,38)
$form.Controls.Add($check)

$status = New-Object Windows.Forms.TextBox
$status.Multiline = $true
$status.ReadOnly = $true
$status.ScrollBars = 'Vertical'
$status.SetBounds(20,158,660,242)
$status.Anchor = 'Top, Bottom, Left, Right'
$form.Controls.Add($status)

function Set-Targets {
    $targetBox.Items.Clear()
    $targetBox.SelectedIndex = -1
    $saved = (Get-ItemProperty -LiteralPath $settings -Name Target -ErrorAction SilentlyContinue).Target
    try {
        foreach ($target in Get-BackupTargets) {
            $index = $targetBox.Items.Add($target)
            if ($target.Id -eq $saved) { $targetBox.SelectedIndex = $index }
        }
        if ($targetBox.Items.Count -eq 0) { $status.Text = 'No eligible separate NTFS drive found. Connect your SSD and select Refresh.' }
        elseif ($targetBox.SelectedIndex -eq -1) { $status.Text = 'Choose the drive you want to use as your backup SSD.' }
        else { $status.Text = 'SSD selected. Select Update backup to make a new system image.' }
    } catch { $status.Text = $_.Exception.Message }
}

function Start-BackupProcess($action, $target) {
    [void][IO.Directory]::CreateDirectory($logs)
    $prefix = Join-Path $logs ([guid]::NewGuid().ToString())
    $arguments = @('get','versions',"-backupTarget:$target")
    if ($action -eq 'Backup') {
        $arguments = @('start','backup',"-backupTarget:$target","-include:$env:SystemDrive",'-allCritical','-vssCopy','-quiet')
    }
    $process = Start-Process -FilePath $wbadmin -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$prefix.txt" -RedirectStandardError "$prefix.err"
    $script:job = @{ Process = $process; Action = $action; Target = $target; Log = $prefix }
    $status.Text = if ($action -eq 'Backup') { "Updating the system image on $target. Keep the SSD connected." } else { "Reading the Windows backup catalog on $target..." }
    $form.UseWaitCursor = $true
    $targetBox.Enabled = $refresh.Enabled = $update.Enabled = $check.Enabled = $false
    $timer.Start()
}

function Invoke-Action($action) {
    try {
        if (-not $targetBox.SelectedItem) { throw 'Select your backup SSD first.' }
        $target = @(Get-BackupTargets | Where-Object Id -EQ $targetBox.SelectedItem.Id)
        if ($target.Count -ne 1) { throw 'The selected SSD is unavailable. Reconnect it and select Refresh.' }
        if ($action -eq 'Backup') {
            [void](New-Item -Path $settings -Force)
            Set-ItemProperty -LiteralPath $settings -Name Target -Value $target[0].Id
        }
        Start-BackupProcess $action $target[0].Target
    } catch { $status.Text = $_.Exception.Message }
}

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 750
$timer.Add_Tick({
    if (-not $script:job.Process.HasExited) { return }
    $timer.Stop()
    $finished = $script:job
    $script:job = $null
    try {
        $finished.Process.WaitForExit()
        $exitCode = $finished.Process.ExitCode
        if ($finished.Action -eq 'Backup' -and $exitCode -eq 0) {
            Start-BackupProcess 'Verify' $finished.Target
            return
        }
        $output = @(
            Get-Content -LiteralPath "$($finished.Log).txt" -Raw
            Get-Content -LiteralPath "$($finished.Log).err" -Raw
        ) -join [Environment]::NewLine
        $message = if ($exitCode -ne 0) { "Windows reported exit code $exitCode. $($finished.Action) could not be confirmed." }
        elseif ($output -match '(?im)^\s*Can recover:\s*[^\r\n]*\bBare Metal Recovery\b') {
            'Windows lists a bare-metal recovery image on this SSD. The catalog check confirms listing only. A test restore is needed to prove recovery.'
        } else { 'Bare-metal recovery could not be confirmed from the catalog. Review the Windows output below.' }
        $status.Text = "$message$([Environment]::NewLine)$([Environment]::NewLine)$output"
    } catch { $status.Text = $_.Exception.Message }
    finally {
        $finished.Process.Dispose()
        if (-not $script:job) {
            $form.UseWaitCursor = $false
            $targetBox.Enabled = $refresh.Enabled = $update.Enabled = $check.Enabled = $true
        }
    }
})
$form.Add_FormClosing({ param($sender, $eventArgs) if ($script:job) { $eventArgs.Cancel = $true } })
$refresh.Add_Click({ Set-Targets })
$update.Add_Click({ Invoke-Action 'Backup' })
$check.Add_Click({ Invoke-Action 'Check' })
$form.Add_Shown({ Set-Targets })
[void]$form.ShowDialog()
