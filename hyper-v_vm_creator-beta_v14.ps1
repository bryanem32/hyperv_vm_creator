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

        $servicevmms = Get-Service -Name vmms -ErrorAction Stop
        return ($servicevmms.Status -eq 'Running')

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
        [string]$Password,

        [Parameter(Mandatory = $true)]
        [int]$ResWidth,

        [Parameter(Mandatory = $true)]
        [int]$ResHeight
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

      <FirstLogonCommands>
       <SynchronousCommand wcm:action="add">
        <Order>1</Order>
        <CommandLine>cmd /c C:\Windows\Temp\QRes.exe /x:$ResWidth /y:$ResHeight</CommandLine>
        <Description>Set Display Resolution</Description>
       </SynchronousCommand>
      </FirstLogonCommands>

    </component>
  </settings>
</unattend>
"@
}

#### GUI Setup ####
# Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Hyper-V VM Creator"
$form.Size = New-Object System.Drawing.Size(600,1000)
$form.FormBorderStyle = 'Fixed3D'
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Regular)
$controls=@{}

# Helper function
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

# Controls
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
$comboEdition.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
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
$comboSwitch.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$form.Controls.Add($comboSwitch)
try { $switches=Get-VMSwitch|Select-Object -ExpandProperty Name
    foreach($s in $switches){
        [void]$comboSwitch.Items.Add($s)}
    if($comboSwitch.Items.Count -gt 0){$comboSwitch.SelectedIndex=0} } catch {}

# Display Resolution
$lblResolution = New-Object System.Windows.Forms.Label
$lblResolution.Text = "VM Resolution:"
$lblResolution.AutoSize = $true
$lblResolution.Location = New-Object System.Drawing.Point(20,420)
$form.Controls.Add($lblResolution)

$comboResolution = New-Object System.Windows.Forms.ComboBox
$comboResolution.Width = 300
$comboResolution.Location = New-Object System.Drawing.Point(150,415)
$comboResolution.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$form.Controls.Add($comboResolution)

# Resolutions supported with Hyper-v VMs
$resolutions = @(
    "800x600",
    "1024x768",
    "1152x864",
    "1280x720",
    "1280x800",
    "1280x1024",
    "1366x768",
    "1440x900",
    "1600x900",
    "1600x1200",
    "1680x1050",
    "1920x1080"
)
$comboResolution.Items.Clear()
$comboResolution.Items.AddRange($resolutions)
$comboResolution.SelectedItem = "800x600"

# Checkboxes
$chkCheckpoint = New-Object System.Windows.Forms.CheckBox
$chkCheckpoint.Text = "Enable Checkpoints"
$chkCheckpoint.AutoSize = $true
$chkCheckpoint.Location = New-Object System.Drawing.Point(20,470)
$form.Controls.Add($chkCheckpoint)

$chkDynamicMemory = New-Object System.Windows.Forms.CheckBox
$chkDynamicMemory.Text = "Enable Dynamic Memory"
$chkDynamicMemory.AutoSize = $true
$chkDynamicMemory.Location = New-Object System.Drawing.Point(300,470)
$form.Controls.Add($chkDynamicMemory)

$chkEnhancedSession = New-Object System.Windows.Forms.CheckBox
$chkEnhancedSession.Text = "Enable Enhanced Session Mode"
$chkEnhancedSession.AutoSize = $true
$chkEnhancedSession.Location = New-Object System.Drawing.Point(20,510)
$form.Controls.Add($chkEnhancedSession)

$chkStartVM = New-Object System.Windows.Forms.CheckBox
$chkStartVM.Text = "Start VM after creation"
$chkStartVM.AutoSize = $true
$chkStartVM.Location = New-Object System.Drawing.Point(300,510)
$form.Controls.Add($chkStartVM)

# Label - OPTIONAL SOFTWARE
$lblSoftware = New-Object System.Windows.Forms.Label
$lblSoftware.Text = "OPTIONAL SOFTWARE (Requires VM Internet Access)"
$lblSoftware.AutoSize = $true
$lblSoftware.Location = New-Object System.Drawing.Point(20,560)
$form.Controls.Add($lblSoftware)

# Create checkboxes Parsec, VBCable, USBMMIDD
$chkParsec = New-Object System.Windows.Forms.CheckBox
$chkParsec.Text = "Parsec (Per Computer)"
$chkParsec.AutoSize = $true
$chkParsec.Location = New-Object System.Drawing.Point(20,590)
$chkParsec.Checked = $false
$form.Controls.Add($chkParsec)

$chkVBCable = New-Object System.Windows.Forms.CheckBox
$chkVBCable.Text = "VB-Audio Cable"
$chkVBCable.AutoSize = $true
$chkVBCable.Location = New-Object System.Drawing.Point(300,590)
$chkVBCable.Checked = $false
$form.Controls.Add($chkVBCable)

$chkUSBMMIDD = New-Object System.Windows.Forms.CheckBox
$chkUSBMMIDD.Text = "Virtual Display Driver"
$chkUSBMMIDD.AutoSize = $true
$chkUSBMMIDD.Location = New-Object System.Drawing.Point(20,630)
$chkUSBMMIDD.Checked = $false
$form.Controls.Add($chkUSBMMIDD)

# Log Box
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline=$true; $logBox.ScrollBars="Vertical"; $logBox.ReadOnly=$true
$logBox.Width=540
$logBox.Height=150
$logBox.Location = New-Object System.Drawing.Point(20,680)
$form.Controls.Add($logBox)
$controls["LogBox"]=$logBox

# Buttons
$btnCreate = New-Object System.Windows.Forms.Button
$btnCreate.Text="Create VM"
$btnCreate.Size=New-Object System.Drawing.Size(100,30)
$btnCreate.Location = New-Object System.Drawing.Point(150,850)
$form.Controls.Add($btnCreate)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text="EXIT"; $btnCancel.Size=New-Object System.Drawing.Size(100,30)
$btnCancel.Location = New-Object System.Drawing.Point(300,850)
$form.Controls.Add($btnCancel)

#### BROWSE HANDLERS ####
$btnBrowseVM.Add_Click({
    $f = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $controls["VMLocation"].Text = $f.SelectedPath }
})

# Edition detection after ISO
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

            $wimInfo = dism /Get-WimInfo /WimFile:$Global:WimFile /English
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
        $controls["Resolution"] = $comboResolution
        
        # Capture resolution
        $ResWidth  = 800
        $ResHeight = 600

        if (-not $controls.ContainsKey("Resolution") -or $null -eq $controls["Resolution"]) {
            Write-Log "Resolution control not found. Defaulting to ${ResWidth}x${ResHeight}"
        } else {
            $resCtrl = $controls["Resolution"]
            # Prefer SelectedItem, fall back to Text (handles cases where DropDownStyle isn't DropDownList)
            $raw = if ($resCtrl.SelectedItem) { [string]$resCtrl.SelectedItem } elseif ($resCtrl.Text) { [string]$resCtrl.Text } else { "" }
            $raw = $raw.Trim()
            Write-Log "Resolution raw value: '$raw'"

            # Accept 1920x1080, 1920×1080, 1920 X 1080, etc.
            $m = [regex]::Match($raw, '^(?<w>\d{3,5})\s*[xX×]\s*(?<h>\d{3,5})$')
            if ($m.Success) {
                $ResWidth  = [int]$m.Groups['w'].Value
                $ResHeight = [int]$m.Groups['h'].Value
                Write-Log "Selected display resolution parsed: ${ResWidth}x${ResHeight}"
            } else {
                # Fallback: pull first two numeric groups
                $parts = ($raw -split '\D+') | Where-Object { $_ -match '^\d{3,5}$' }
                if ($parts.Count -ge 2) {
                    $ResWidth  = [int]$parts[0]
                    $ResHeight = [int]$parts[1]
                    Write-Log "Selected display resolution (fallback) parsed: ${ResWidth}x${ResHeight}"
                } else {
                    Write-Log "Could not parse resolution from '$raw'. Defaulting to ${ResWidth}x${ResHeight}"
                }
            }
        }

        # VM Location test path
        if (-not (Test-Path $VMLocBase)) { Write-Log "ERROR: VM Location does not exist."; return }
        if (-not $Global:WimFile) { Write-Log "ERROR: WIM/ESD path not found."; return }

        # Begin
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

        # VM Directory on Host
        $VMLoc = Join-Path $VMLocBase $VMName
        if (Test-Path $VMLoc) {Write-Log "ERROR: ${VMLoc} already exists!" } else { New-Item -Path "$VMLoc" -ItemType Directory -Force | Out-Null}
        
        # VM vhdx
        $VHDPath = Join-Path $VMLoc "$VMName.vhdx"
        
        # QRes Host Location
        $tempExe = Join-Path $VMLoc "QRes.exe"
        Write-Log "Creating QRes.exe..."
        # Base64-encoded QRes.exe (latest version 1.0.9.7)
        $base64 = @"
        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g338AXQGg338AnUNjUXYUOgs/P//WYlFvP916P8VABBAAOsCM/aNhUT///9WUOhr/P//WVlXVv8VbBBAAOlsAgAA9kX8Ag+FTgEAAIN9+ACLRfR1E4XAdQ85Rex1D4N98P4PhDIBAACD+AF9DotF+Jn3/40EQIlF9OsSg334AX0MweACagOZWff5iUX4aJQAAACNhUT///9qAFDoFgIAAItF9ItN+ItV8IlFtItF7IPEDIXAZseFaP///5QAiU2wiUWsiVW8fgqBhWz///8AAAQAhcl+CoGFbP///wAAGACD+v6+AABAAHU4gz2gHEAAAHQ1agD/FXgQQACL+IX/dBsBtWz///9qdFf/FRAQQABXagCJRbz/FWwQQACDffD+dAYBtWz///+LNXQQQACNhUT///9qAlD/1ov4hf91IItF/PfQwegDg+ABUI2FRP///1D/1mggFEAAi/j/0+sWi8dIdAdo/BNAAOsFaLATQADoj/r//4P//VkPhS8BAABoZBNAAOh7+v//WY2FRP///2oAUP/W6RQBAABoFBNAAP/TxwQkABNAAGj8EkAA6Gb6//9o6BJAAGjkEkAA6Ff6//9o1BJAAGjQEkAA6Ej6//+LdfyDxBgj93Q7aMASQADoS/r//8cEJLASQADoP/r//8cEJKASQADoM/r//8cEJJASQADoJ/r//8cEJIASQADoG/r//1locBJAAGhsEkAA6PT5//+DPaAcQAAAWVl1G4X2dBdoVBJAAOjy+f//xwQkRBJAAOjm+f//WWgkEkAAaCASQADov/n//2gIEkAAaAQSQADosPn//2jQEUAAaMwRQADoofn//2ikEUAAaKARQADokvn//2iEEUAAaIARQADog/n//2hsEUAAaGgRQADodPn//2gIEUAA/9ODxDRfXjPAW8nDzP8lQBBAAFWL7Gr/aIAUQABogBxAAGShAAAAAFBkiSUAAAAAg+wgU1ZXiWXog2X8AGoB/xVUEEAAWYMNpBxAAP+DDagcQAD//xVkEEAAiw2cHEAAiQj/FWAQQACLDZgcQACJCKFcEEAAiwCjrBxAAOjDAAAAgz14FEAAAHUMaHYcQAD/FVgQQABZ6JQAAABokBBAAGiMEEAA6H8AAAChlBxAAIlF2I1F2FD/NZAcQACNReBQjUXUUI1F5FD/FTAQQABoiBBAAGiEEEAA6EwAAAD/FVAQQACLTeCJCP914P911P915Oit+f//g8QwiUXcUP8VTBBAAItF7IsIiwmJTdBQUegPAAAAWVnDi2Xo/3XQ/xVEEEAA/yVIEEAA/yU0EEAAaAAAAwBoAAABAOgTAAAAWVnDM8DDw8zMzMzMzP8lPBBAAP8lOBBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAdAAAAAAAAAAAAAOQdAAAYEAAAlB0AAAAAAAAAAAAARB4AAGwQAAA4HQAAAAAAAAAAAABgHgAAEBAAACgdAAAAAAAAAAAAAJweAAAAEAAAVB0AAAAAAAAAAAAAvh4AACwQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGoeAAB4HgAAjB4AAAAAAABQHgAAAAAAANIdAADEHQAAuB0AAKwdAAAAAAAAqh4AAPgeAAAIHwAAfB8AAGgfAAC0HgAAyh4AANIeAADgHgAA6B4AAFYfAAAUHwAAKB8AADgfAABIHwAAAAAAABgeAADyHQAA/h0AACQeAAAsHgAAAAAAAAIDbHN0cmNweUEAAPkCbHN0cmNhdEEAAHQBR2V0VmVyc2lvbgAAygBHZXRDb21tYW5kTGluZUEAS0VSTkVMMzIuZGxsAACsAndzcHJpbnRmQQAbAENoYW5nZURpc3BsYXlTZXR0aW5nc0EAAAMCUmVsZWFzZURDAP0AR2V0REMAxQBFbnVtRGlzcGxheVNldHRpbmdzQQAAVVNFUjMyLmRsbAAAJQFHZXREZXZpY2VDYXBzAEdESTMyLmRsbABbAVJlZ0Nsb3NlS2V5AHsBUmVnUXVlcnlWYWx1ZUV4QQAAcgFSZWdPcGVuS2V5RXhBAEFEVkFQSTMyLmRsbAAAngJwcmludGYAAJkCbWVtc2V0AABNU1ZDUlQuZGxsAADTAF9leGl0AEgAX1hjcHRGaWx0ZXIASQJleGl0AABkAF9fcF9fX2luaXRlbnYAWABfX2dldG1haW5hcmdzAA8BX2luaXR0ZXJtAIMAX19zZXR1c2VybWF0aGVycgAAnQBfYWRqdXN0X2ZkaXYAAGoAX19wX19jb21tb2RlAABvAF9fcF9fZm1vZGUAAIEAX19zZXRfYXBwX3R5cGUAAMoAX2V4Y2VwdF9oYW5kbGVyMwAAtwBfY29udHJvbGZwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
"@
        # Decode the Base64 string and write to $tempExe
        [IO.File]::WriteAllBytes($tempExe, [Convert]::FromBase64String($base64))        

        # setupcomplete.cmd Host Location
        Write-Log "Creating SetupComplete.cmd file..."
        $cmdFile = Join-Path $VMLoc "SetupComplete.cmd"
        
        # setupcomplete.cmd contents based on selection
        $lines = @(
            '@echo off'
            ':: SetupComplete.cmd runs after Windows Setup, before first logon'
            ':: Installs selected software silently'
            ''
            'setlocal enableextensions'
            'set WORKDIR=C:\Windows\Temp'
            'set LOGFILE=%WORKDIR%\SetupComplete.log'
            ''
            'echo [%date% %time%] Starting SetupComplete.cmd >> %LOGFILE%'
            ''
        )
        if ($chkParsec.Checked) {
            $lines += @(
                ':: --- Install Parsec ---'
                'echo [%date% %time%] Downloading Parsec... >> %LOGFILE%'
                'bitsadmin /transfer "DownloadParsec" https://builds.parsecgaming.com/package/parsec-windows.exe %WORKDIR%\parsec.exe >> %LOGFILE% 2>&1'
                'echo [%date% %time%] Installing Parsec... >> %LOGFILE%'
                'start /wait %WORKDIR%\parsec.exe /silent /percomputer /norun /vdd'
                ''
            )
        }
        if ($chkVBCable.Checked) {
            $lines += @(
                ':: --- Install VB Cable ---'
                'echo [%date% %time%] Downloading VB Cable... >> %LOGFILE%'
                'bitsadmin /transfer "DownloadVBCable" https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack45.zip %WORKDIR%\vb.zip >> %LOGFILE% 2>&1'
                'echo [%date% %time%] Preparing extract folder... >> %LOGFILE%'
                'if not exist "%WORKDIR%\VB" mkdir "%WORKDIR%\VB"'
                'echo [%date% %time%] Extracting VB Cable... >> %LOGFILE%'
                'tar -xf %WORKDIR%\vb.zip -C %WORKDIR%\VB >> %LOGFILE% 2>&1'
                'echo [%date% %time%] Installing VB Cable... >> %LOGFILE%'
                'start /wait %WORKDIR%\VB\VBCABLE_Setup_x64 -h -i -H -n'
                ''
            )
        }
        if ($chkUSBMMIDD.Checked) {
            $lines += @(
                ':: --- Install USB MMIDD ---'
                'echo [%date% %time%] Downloading USB MMIDD... >> %LOGFILE%'
                'bitsadmin /transfer "DownloadUSBMMIDD" https://www.amyuni.com/downloads/usbmmidd_v2.zip %WORKDIR%\usbmmidd_v2.zip >> %LOGFILE% 2>&1'
                'echo [%date% %time%] Extracting USB MMID V2... >> %LOGFILE%'
                'if not exist "%WORKDIR%\usbmmidd_v2" mkdir "%WORKDIR%\usbmmidd_v2"'
                'tar -xf %WORKDIR%\usbmmidd_v2.zip -C %WORKDIR% >> %LOGFILE% 2>&1'
                'echo [%date% %time%] Installing USB MMIDD... >> %LOGFILE%'
                '::start /wait %WORKDIR%\usbmmidd_v2\deviceinstaller64 install %WORKDIR%\usbmmidd_v2\usbmmidd.inf %WORKDIR%\usbmmidd_v2\usbmmidd >> %LOGFILE% 2>&1'
                '::start /wait %WORKDIR%\usbmmidd_v2\deviceinstaller64 enableidd 1 >> %LOGFILE% 2>&1'
                '::start /wait %WORKDIR%\usbmmidd_v2\usbmmidd.bat'
                ''
                '@echo off'
                'setlocal DisableDelayedExpansion'
                'echo @cd /d "%%~dp0" > "%WORKDIR%\usbmmidd_v2\usbmmidd2.bat"'
                'echo @goto %%PROCESSOR_ARCHITECTURE%% >> "%WORKDIR%\usbmmidd_v2\usbmmidd2.bat"'
                'echo @exit >> "%WORKDIR%\usbmmidd_v2\usbmmidd2.bat"'
                'echo. >> "%WORKDIR%\usbmmidd_v2\usbmmidd2.bat"'
                'echo :AMD64 >> "%WORKDIR%\usbmmidd_v2\usbmmidd2.bat"'
                'echo @cmd /c deviceinstaller64.exe install usbmmidd.inf usbmmidd >> "%WORKDIR%\usbmmidd_v2\usbmmidd2.bat"'
                'echo deviceinstaller64.exe enableidd 1 ^&^& exit >> "%WORKDIR%\usbmmidd_v2\usbmmidd2.bat"'
                'echo @goto end >> "%WORKDIR%\usbmmidd_v2\usbmmidd2.bat"'
                'echo. >> "%WORKDIR%\usbmmidd_v2\usbmmidd2.bat"'
                'echo :x86 >> "%WORKDIR%\usbmmidd_v2\usbmmidd2.bat"'
                'echo @cmd /c deviceinstaller.exe install usbmmidd.inf usbmmidd >> "%WORKDIR%\usbmmidd_v2\usbmmidd2.bat"'
                'echo deviceinstaller.exe enableidd 1 ^&^& exit >> "%WORKDIR%\usbmmidd_v2\usbmmidd2.bat"'
                'echo. >> "%WORKDIR%\usbmmidd_v2\usbmmidd2.bat"'
                'echo :end >> "%WORKDIR%\usbmmidd_v2\usbmmidd2.bat"'
                'start /wait %WORKDIR%\usbmmidd_v2\usbmmidd2.bat'
                ''
            )
        }
        $lines += @(
            'echo [%date% %time%] SetupComplete.cmd finished >> %LOGFILE%'
            'endlocal'
            'exit /b 0'
        )        

        # Write the setupcomplete.cmd file
        $lines | Out-File -FilePath $cmdFile -Encoding ASCII -Force
        
        # VM autounattend.xml
        $UnattendXMLPath = Join-Path $VMLoc "Autounattend.xml"
        Generate-UnattendXml -Username $Username -Password $Password -VMName $VMName -ResWidth $ResWidth -ResHeight $ResHeight | Out-File -FilePath $UnattendXMLPath -Encoding UTF8

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

        # Inject QRes.exe to VM
        $QresPath = Join-Path "$driveletter\" "Windows\Temp\Qres.exe"
        Copy-Item -Path $tempEXE -Destination $QresPath -Force
        Write-Log "Qres.exe injected to $QresPath"

        # Inject SetupComplete.cmd to VM
        $VMSetupScriptsDir = Join-Path "$driveletter\" "Windows\Setup\Scripts"
        $cmdFilePath = Join-Path "$VMSetupScriptsDir\" "SetupComplete.cmd"
        New-Item -Path $VMSetupScriptsDir -ItemType Directory -Force | Out-Null
        Copy-Item -Path $cmdFile -Destination $cmdFilePath -Force
        Write-Log "SetupComplete.cmd injected to $cmdFilePath"

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
