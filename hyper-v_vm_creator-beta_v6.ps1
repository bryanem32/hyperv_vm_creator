#### POWERSHELL CHECK ####
# Check Powershell Execution Policy
$currentPolicy = Get-ExecutionPolicy -Scope Process
# If process scope is not set, fallback to effective machine policy
if (-not $currentPolicy) {
    $currentPolicy = Get-ExecutionPolicy
}
if ($currentPolicy -ne 'Unrestricted') {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force
}

#### HYPER-V CHECK ####
Add-Type -AssemblyName PresentationFramework

# Function Test-HyperVRunning
function Test-HyperVRunning {
    try {
        $sysInfo = systeminfo | Select-String "A hypervisor has been detected"
        return ($sysInfo -ne $null)
    }
    catch {
        return $false
    }
}

# Check if Hyper-V is installed
$feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue

if ($feature.State -eq "Enabled" -and (Test-HyperVRunning)) {
    # Hyper-V is installed and running -> silent exit
    
}
else {
    $installChoice = [System.Windows.MessageBox]::Show(
        "Hyper-V is not fully enabled or the hypervisor is not running.`n`nA system restart will be required after installation.`n`nDo you want to enable it now?",
        "Enable Hyper-V",
        "OKCancel",
        "Warning"
    )

    if ($installChoice -eq "OK") {
        try {
            # Suppress ALL output and DISM restart warning
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart -ErrorAction Stop *> $null

            # Ensure Hyper-V hypervisor starts on boot
            bcdedit /set hypervisorlaunchtype auto *> $null

            $restartChoice = [System.Windows.MessageBox]::Show(
                "Hyper-V has been enabled successfully.`n`nDo you want to restart now?",
                "Restart Required",
                "OKCancel",
                "Question"
            )

            if ($restartChoice -eq "OK") {
                Restart-Computer -Force
            }
            else {
                Write-Host "Please restart your PC and run the script again."
                exit 0
            }
        }
        catch {
            [System.Windows.MessageBox]::Show(
                "Failed to enable Hyper-V.`n`nError: $_",
                "Error",
                "OK",
                "Error"
            ) | Out-Null
            exit 1
        }
    }
    else {
        exit 0
    }
}

#### GLOBALS ####
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Globals
$Global:MountedISO = $null
$Global:WimFile = $null
$Global:EditionMap = @{}

#### FUNCTIONS ####
# Logging
function Write-Log { param([string]$Message)
    $controls["LogBox"].AppendText("$(Get-Date -Format 'HH:mm:ss') - $Message`r`n")
}

# Generate unattend.xml
function Generate-UnattendXml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VMName,

        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$Password
    )

    # --- Culture / Locale Detection ---
    if (Get-Command Get-Culture -ErrorAction SilentlyContinue) {
        $culture   = Get-Culture
        $uiLang    = (Get-Culture).Name
    } else {
        $culture   = [System.Globalization.CultureInfo]::CurrentCulture
        $uiLang    = [System.Globalization.CultureInfo]::CurrentUICulture.Name
    }

    $lang      = $culture.Name
    $systemLoc = $culture.Name
    $userLoc   = $culture.Name

    # --- Keyboard Detection ---
    try {
        $keyboard = (Get-WinUserLanguageList)[0].InputMethodTips[0]
    } catch {
        $keyboard = "0409:00000409"  # Default US keyboard
    }

    # --- Timezone Detection ---
    try {
        $timezone = (Get-TimeZone).Id
    } catch {
        $timezone = (Get-WmiObject Win32_TimeZone).StandardName
    }

    # --- Build XML ---
return @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="offlineServicing"></settings>

  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage>
        <UILanguage>$uiLang</UILanguage>
      </SetupUILanguage>
      <InputLocale>$keyboard</InputLocale>
      <SystemLocale>$systemLoc</SystemLocale>
      <UILanguage>$uiLang</UILanguage>
      <UserLocale>$userLoc</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <UserData>
        <AcceptEula>true</AcceptEula>
      </UserData>
      <UseConfigurationSet>false</UseConfigurationSet>
    </component>
  </settings>

  <settings pass="generalize"></settings>

  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>$VMName</ComputerName>
      <TimeZone>$timezone</TimeZone>
      <Display>
            <ColorDepth>32</ColorDepth>
            <HorizontalResolution>1920</HorizontalResolution>
            <VerticalResolution>1080</VerticalResolution>
            <RefreshRate>60</RefreshRate>
        </Display>

    </component>
  </settings>

  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>$keyboard</InputLocale>
      <SystemLocale>$systemLoc</SystemLocale>
      <UILanguage>$uiLang</UILanguage>
      <UserLocale>$userLoc</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name>$Username</Name>
            <DisplayName>$Username</DisplayName>
            <Group>Administrators</Group>
            <Password>
              <Value>$Password</Value>
              <PlainText>true</PlainText>
            </Password>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
      <AutoLogon>
        <Username>$Username</Username>
        <Enabled>true</Enabled>
        <LogonCount>9999</LogonCount>
        <Password>
          <Value>$Password</Value>
          <PlainText>true</PlainText>
        </Password>
      </AutoLogon>
      <OOBE>
        <ProtectYourPC>3</ProtectYourPC>
        <HideEULAPage>true</HideEULAPage>
        <HideLocalAccountScreen>true</HideLocalAccountScreen>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
      </OOBE>
    </component>
  </settings>
</unattend>
"@
}

#### GUI Setup ####
$form = New-Object System.Windows.Forms.Form
$form.Text = "Hyper-V VM Creator"
$form.Size = New-Object System.Drawing.Size(600,780)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Regular)
$controls=@{}

function Add-LabelTextbox { param([int]$y,[string]$labelText)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $labelText
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(20, $y)
    $form.Controls.Add($lbl)
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Width = 300
    $txt.Location = New-Object System.Drawing.Point(150, $y)
    $form.Controls.Add($txt)
    return $txt
}

$controls["VMName"] = Add-LabelTextbox 20 "VM Name:"
$controls["VMName"].Font = New-Object System.Drawing.Font("Segoe UI",11)
$controls["VMLocation"] = Add-LabelTextbox 60 "VM Location:"
$controls["VMLocation"].Font = New-Object System.Drawing.Font("Segoe UI",11)
$controls["ISOPath"] = Add-LabelTextbox 100 "Install ISO File:"
$controls["ISOPath"].Font = New-Object System.Drawing.Font("Segoe UI",11)
$controls["Username"] = Add-LabelTextbox 180 "Local User:"
$controls["Username"].Font = New-Object System.Drawing.Font("Segoe UI",11)
$controls["Username"].Text = "d2r"
$controls["Password"] = Add-LabelTextbox 220 "Local Password:"
$controls["Password"].Font = New-Object System.Drawing.Font("Segoe UI",11)
$controls["Password"].Text = "d2r"

# Edition Dropdown (after ISO)
$lblEdition = New-Object System.Windows.Forms.Label
$lblEdition.Text = "Win Edition:"
$lblEdition.AutoSize = $true
$lblEdition.Location = New-Object System.Drawing.Point(20,140)
$form.Controls.Add($lblEdition)
$comboEdition = New-Object System.Windows.Forms.ComboBox
$comboEdition.Width = 300
$comboEdition.Location = New-Object System.Drawing.Point(150,135)
$form.Controls.Add($comboEdition)

# Browse Buttons
$btnBrowseVM = New-Object System.Windows.Forms.Button
$btnBrowseVM.Text = "Browse"
$btnBrowseVM.Size = New-Object System.Drawing.Size(80,23)
$btnBrowseVM.Location = New-Object System.Drawing.Point(470,60)
$form.Controls.Add($btnBrowseVM)

$btnBrowseISO = New-Object System.Windows.Forms.Button
$btnBrowseISO.Text = "Browse"
$btnBrowseISO.Size = New-Object System.Drawing.Size(80,23)
$btnBrowseISO.Location = New-Object System.Drawing.Point(470,100)
$form.Controls.Add($btnBrowseISO)

# vCPU, Memory, Disk
$lblCPU = New-Object System.Windows.Forms.Label
$lblCPU.Text = "vCPUs:"
$lblCPU.AutoSize = $true
$lblCPU.Location = New-Object System.Drawing.Point(20,260)
$form.Controls.Add($lblCPU)

$cpuUpDown = New-Object System.Windows.Forms.NumericUpDown
$cpuUpDown.Minimum = 1
$cpuUpDown.Maximum = 64
$cpuUpDown.Value = 2
$cpuUpDown.Location = New-Object System.Drawing.Point(150,255)
$form.Controls.Add($cpuUpDown)

$lblMem = New-Object System.Windows.Forms.Label
$lblMem.Text = "Memory (GB):"
$lblMem.AutoSize = $true
$lblMem.Location = New-Object System.Drawing.Point(20,300)
$form.Controls.Add($lblMem)

$memUpDown = New-Object System.Windows.Forms.NumericUpDown
$memUpDown.Minimum = 1
$memUpDown.Maximum = 512
$memUpDown.Value = 4
$memUpDown.Location = New-Object System.Drawing.Point(150,295)
$form.Controls.Add($memUpDown)

$lblDisk = New-Object System.Windows.Forms.Label
$lblDisk.Text = "Disk Size (GB):"
$lblDisk.AutoSize = $true
$lblDisk.Location = New-Object System.Drawing.Point(20,340)
$form.Controls.Add($lblDisk)

$diskUpDown = New-Object System.Windows.Forms.NumericUpDown
$diskUpDown.Minimum = 10
$diskUpDown.Maximum = 2048
$diskUpDown.Value = 60
$diskUpDown.Location = New-Object System.Drawing.Point(150,335)
$form.Controls.Add($diskUpDown)

# Virtual Switch
$lblSwitch = New-Object System.Windows.Forms.Label
$lblSwitch.Text = "Virtual Switch:"
$lblSwitch.AutoSize = $true
$lblSwitch.Location = New-Object System.Drawing.Point(20,380)
$form.Controls.Add($lblSwitch)
$comboSwitch = New-Object System.Windows.Forms.ComboBox
$comboSwitch.Width = 300
$comboSwitch.Location = New-Object System.Drawing.Point(150,375)
$form.Controls.Add($comboSwitch)
try { $switches=Get-VMSwitch|Select-Object -ExpandProperty Name
    foreach($s in $switches){
        [void]$comboSwitch.Items.Add($s)}
    if($comboSwitch.Items.Count -gt 0){$comboSwitch.SelectedIndex=0} } catch {}

# Checkboxes
$chkCheckpoint = New-Object System.Windows.Forms.CheckBox
$chkCheckpoint.Text = "Enable Checkpoints"
$chkCheckpoint.AutoSize = $true
$chkCheckpoint.Location = New-Object System.Drawing.Point(20,420)
$form.Controls.Add($chkCheckpoint)

$chkDynamicMemory = New-Object System.Windows.Forms.CheckBox
$chkDynamicMemory.Text = "Enable Dynamic Memory"
$chkDynamicMemory.AutoSize = $true
$chkDynamicMemory.Location = New-Object System.Drawing.Point(300,420)
$form.Controls.Add($chkDynamicMemory)

$chkEnhancedSession = New-Object System.Windows.Forms.CheckBox
$chkEnhancedSession.Text = "Enable Enhanced Session Mode"
$chkEnhancedSession.AutoSize = $true
$chkEnhancedSession.Location = New-Object System.Drawing.Point(20,460)
$form.Controls.Add($chkEnhancedSession)

$chkStartVM = New-Object System.Windows.Forms.CheckBox
$chkStartVM.Text = "Start VM after creation"
$chkStartVM.AutoSize = $true
$chkStartVM.Location = New-Object System.Drawing.Point(300,460)
$form.Controls.Add($chkStartVM)

# Log Box
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline=$true; $logBox.ScrollBars="Vertical"; $logBox.ReadOnly=$true
$logBox.Width=540
$logBox.Height=150
$logBox.Location = New-Object System.Drawing.Point(20,500)
$form.Controls.Add($logBox)
$controls["LogBox"]=$logBox

# Buttons
$btnCreate = New-Object System.Windows.Forms.Button
$btnCreate.Text="Create VM"
$btnCreate.Size=New-Object System.Drawing.Size(100,30)
$btnCreate.Location = New-Object System.Drawing.Point(150,670)
$form.Controls.Add($btnCreate)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text="EXIT"; $btnCancel.Size=New-Object System.Drawing.Size(100,30)
$btnCancel.Location = New-Object System.Drawing.Point(300,670)
$form.Controls.Add($btnCancel)


#### BROWSE HANDLERS
$btnBrowseVM.Add_Click({
    $f = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $controls["VMLocation"].Text = $f.SelectedPath }
})

# Edition detection unchanged
$btnBrowseISO.Add_Click({
    $f = New-Object System.Windows.Forms.OpenFileDialog
    $f.Filter = "ISO Files|*.iso"
    if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { 
        $controls["ISOPath"].Text = $f.FileName
        try {
            $Global:MountedISO = Mount-DiskImage -ImagePath $f.FileName -PassThru
            Start-Sleep -Seconds 2
            $isoDrive = ($Global:MountedISO | Get-DiskImage | Get-Volume | Where-Object DriveLetter).DriveLetter + ":"

            $Global:WimFile = Join-Path "$isoDrive\sources" "install.wim"
            if (-not (Test-Path $Global:WimFile)) { $Global:WimFile = Join-Path "$isoDrive\sources" "install.esd" }
            if (-not (Test-Path $Global:WimFile)) { Write-Log "Cannot find install.wim or install.esd"; return }

            $wimInfo = dism /Get-WimInfo /WimFile:$Global:WimFile
            $editions = @()
            $Global:EditionMap.Clear()
            $currentIndex = $null
            foreach ($line in $wimInfo) {
                $line = $line.Trim()
                if ($line -match "^Index\s*:\s*(\d+)$") { $currentIndex = [int]$matches[1] }
                elseif ($line -match "^Name\s*:\s*(.+)$" -and $currentIndex) {
                    $name = $matches[1].Trim()
                    $editions += $name
                    $Global:EditionMap[$name] = $currentIndex
                    $currentIndex = $null
                }
            }

            $comboEdition.Items.Clear()
            $comboEdition.Items.AddRange($editions)
            if ($editions.Count -gt 0) { $comboEdition.SelectedIndex = 0 }
            Write-Log "Edition dropdown populated: $($editions -join ', ')"
        } catch { Write-Log "Failed to read editions: $_" }
    }
})

#### CANCEL & CLEANUP ####
$btnCancel.Add_Click({ $form.Close() })
$form.Add_FormClosing({
    if ($Global:MountedISO) { try { Dismount-DiskImage -ImagePath $Global:MountedISO.ImagePath -ErrorAction SilentlyContinue } catch {} }
})


#### MAIN SCRIPT ####
$btnCreate.Add_Click({
    try {
        $VMName = $controls["VMName"].Text
        $VMLocBase = $controls["VMLocation"].Text
        $Username = $controls["Username"].Text
        $Password = $controls["Password"].Text
        $vCPU = [int]$cpuUpDown.Value
        $MemGB = [int]$memUpDown.Value
        $DiskGB = [int]$diskUpDown.Value
        $VMSwitch = $comboSwitch.SelectedItem
        $EnableCheckpoint = $chkCheckpoint.Checked
        $EnableDynamicMemory = $chkDynamicMemory.Checked
        $EnableEnhancedSession = $chkEnhancedSession.Checked
        $StartVM = $chkStartVM.Checked
        $SelectedEditionName = $comboEdition.SelectedItem
        $SelectedIndex = $Global:EditionMap[$SelectedEditionName]

        if (-not (Test-Path $VMLocBase)) { Write-Log "ERROR: VM Location does not exist."; return }
        if (-not $Global:WimFile) { Write-Log "ERROR: WIM/ESD path not found."; return }

        Write-Log "Starting VM creation for $VMName"

        # Autoplay Original and disable temporarily
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers"
        $regName = "DisableAutoplay"

        # Get current AutoPlay setting (0 = enabled, 1 = disabled)
        try {
            $originalValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction Stop).$regName
        } catch {
            # If the value doesn't exist, assume AutoPlay is enabled
            $originalValue = 0
        }
        Write-Log "Original AutoPlay setting (0=Enabled, 1=Disabled): $originalValue"

        # If AutoPlay was enabled, disable it temporarily
        if ($originalValue -eq 0) {
            Write-Log "AutoPlay is currently ENABLED. Disabling..."
            Set-ItemProperty -Path $regPath -Name $regName -Value 1
        } else {
            Write-Log "AutoPlay is already disabled."
        }

        $VMLoc = Join-Path $VMLocBase $VMName
        if (Test-Path $VMLoc) {Write-Log "ERROR: ${VMLoc} already exists!" } else { New-Item -Path "$VMLoc" -ItemType Directory -Force | Out-Null}
        $VHDPath = Join-Path $VMLoc "$VMName.vhdx"
        $UnattendXMLPath = Join-Path $VMLoc "Autounattend.xml"
        Generate-UnattendXml -Username $Username -Password $Password -VMName $VMName | Out-File -FilePath $UnattendXMLPath -Encoding UTF8

        Write-Log "Creating VHDX..."
        New-VHD -Path $VHDPath -SizeBytes ($DiskGB*1GB) -Dynamic | Out-Null

        Write-Log "Mounting VHD and creating GPT/EFI/MSR/Windows partitions..."
        $mountedVHD = Mount-VHD -Path $VHDPath -Passthru
        $diskNumber = $mountedVHD.DiskNumber
        Initialize-Disk -Number $diskNumber -PartitionStyle GPT -PassThru

        # EFI Partition
        $efi = New-Partition -DiskNumber $diskNumber -Size 100MB -GptType "{C12A7328-F81F-11D2-BA4B-00A0C93EC93B}" -AssignDriveLetter
        Format-Volume -Partition $efi -FileSystem FAT32 -NewFileSystemLabel "System" -Confirm:$false

        # MSR Partition
        $msr = New-Partition -DiskNumber $diskNumber -Size 16MB -GptType "{E3C9E316-0B5C-4DB8-817D-F92DF00215AE}"

        # Windows Partition
        $winPart = New-Partition -DiskNumber $diskNumber -UseMaximumSize -AssignDriveLetter
        $driveLetter = $winPart.DriveLetter + ":"
        Format-Volume -Partition $winPart -FileSystem NTFS -NewFileSystemLabel $VMName -Confirm:$false
        Start-Sleep -Seconds 1 # ensure drive is ready

        # Apply Windows image
        Write-Log "Applying Windows image (Index $SelectedIndex)..."
        dism /Apply-Image /ImageFile:"$Global:WimFile" /Index:$SelectedIndex /ApplyDir:$driveLetter /Compact 2>&1 | ForEach-Object { Write-Log $_ }

        # Inject unattend.xml to root for first boot
        $RootUnattendPath = Join-Path "$driveLetter\" "Autounattend.xml"
        Copy-Item -Path $UnattendXMLPath -Destination $RootUnattendPath -Force
        Write-Log "Autounattend.xml copied to root of Windows partition: $RootUnattendPath"

        # Inject unattend.xml to Panther for logging
        $PantherDir = Join-Path "$driveLetter\Windows" "Panther\Unattend"
        New-Item -Path $PantherDir -ItemType Directory -Force | Out-Null
        Copy-Item -Path $UnattendXMLPath -Destination (Join-Path $PantherDir "Unattend.xml") -Force
        Write-Log "Autounattend.xml injected into Panther directory"

        # Create VM
        Write-Log "Creating VM..."
        New-VM -Name $VMName -MemoryStartupBytes ($MemGB*1GB) -Generation 2 -VHDPath $VHDPath -Path $VMLoc -SwitchName $VMSwitch | Out-Null
        Set-VM -Name $VMName -ProcessorCount $vCPU
        
        Write-Log "Applying Checkpoint settings..."
        if ($EnableCheckpoint) { Set-VM -Name $VMName -CheckpointType "Standard" } else { Set-VM -Name $VMName -CheckpointType "Disabled" }
        
        Write-Log "Applying Dynamic Memory settings..."
        if ($EnableDynamicMemory) { Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true -StartupBytes ($MemGB*1GB) -MinimumBytes 1GB -MaximumBytes ($MemGB*1GB) } else { Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false }

        Write-Log "Applying Enhanced Session Mode settings..."
        $esm = (Get-VMHost).EnableEnhancedSessionMode
        Write-Log "Current Enhanced Session Mode Enabled: ${esm}"
        if ($EnableEnhancedSession) { Set-VMhost -EnableEnhancedSessionMode $true } else { Set-VMhost -EnableEnhancedSessionMode $false }
        $esm = (Get-VMHost).EnableEnhancedSessionMode
        Write-Log "New Enhanced Session Mode Enabled: ${esm}"
        
        Write-Log "Creating boot files on EFI partition..."
        bcdboot "$driveLetter\Windows" /s $($efi.DriveLetter + ":") /f UEFI 2>&1 | ForEach-Object { Write-Log $_ }

        Dismount-VHD -Path $VHDPath
        if ($Global:MountedISO) { Dismount-DiskImage -ImagePath $Global:MountedISO.ImagePath -ErrorAction SilentlyContinue }

        # Autoplay re-enable if it was originally enabled
        if ($originalValue -eq 0) {
            Write-Log "Restoring AutoPlay to ENABLED state..."
            Set-ItemProperty -Path $regPath -Name $regName -Value 0
        } else {
            Write-Log "AutoPlay was originally disabled. Leaving it disabled."
        }

        if ($StartVM) { Start-VM -Name $VMName; Write-Log "VM started." }
        vmconnect.exe localhost $VMName
        Write-Log "VM creation completed."

        # Hide the Create VM Button
        $btnCreate.Visible = $false

    } catch { Write-Log "ERROR: $_" }
})

#---------------------------------------
# Show GUI
#---------------------------------------
[void]$form.ShowDialog()
