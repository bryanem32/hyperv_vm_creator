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

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#### FUNCTIONS ####
# Logging
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp $Message"
    Write-Output $line
    if ($LogBox -ne $null) {
        $LogBox.AppendText($line + [Environment]::NewLine)
        $LogBox.ScrollToCaret()
    }
}

# Cleanup
function Cleanup-Mounts {
    Write-Log "Running cleanup..."
    try {
        $vhdPaths = Get-VM | ForEach-Object {
            Get-VMHardDiskDrive -VMName $_.Name | Select-Object -ExpandProperty Path
        }

        foreach ($vhdPath in $vhdPaths) {
            try {
                $vhd = Get-DiskImage -ImagePath $vhdPath -ErrorAction SilentlyContinue
                if ($vhd -and $vhd.Attached) {
                    Write-Log ("Dismounting lingering VHD: $($vhdPath)")
                    Dismount-DiskImage -ImagePath $vhdPath -ErrorAction SilentlyContinue
                }
            } catch {}
        }

        Write-Log "Cleanup complete."
    } catch {
        Write-Log ("Cleanup error: $($_.Exception.Message)")
    }
}

# Inject Drivers
function Copy-Drivers {
    param(
        [string]$VMName,
        [string]$MountLetter,
        [string]$Source,
        [string]$Destination,
        [string]$FileMask = "*"
    )

    $target = Join-Path "$($MountLetter)\" $Destination
    if (-not (Test-Path $target)) {
        Write-Log ("[$($VMName)] Creating missing directory $target")
        New-Item -Path $target -ItemType Directory -Force | Out-Null
    }

    Write-Log ("[$($VMName)] Copying $($Source) -> $($target) ($($FileMask))")
    try {
        Copy-Item -Path (Join-Path $Source $FileMask) -Destination $target -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Log ("[$($VMName)] ERROR copying files: $($_.Exception.Message)")
    }
}

# Check nVIDIA GPU
function Host-HasNvidiaGPU {
    $gpus = Get-CimInstance Win32_VideoController
    $nvidiaGpus = $gpus | Where-Object { $_.Name -match "NVIDIA" }
    if ($nvidiaGpus) {
        Write-Log ("Host NVIDIA GPU(s) detected: $(( $nvidiaGpus | ForEach-Object { $_.Name } ) -join ', ')")
        return $true
    }
    return $false
}

$HasNvidiaGPU = Host-HasNvidiaGPU

# MAIN UPDATE SCRIPT
function Update-GPUDrivers {
    foreach ($item in $VMCheckboxes) {
        if ($item.Checked) {
            $VMName = $item.Text
            try {
                $vm = Get-VM -Name $VMName -ErrorAction Stop
                Write-Log ("Processing VM: $($VMName)")

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
                Write-Log "[$($VMName)] Original AutoPlay setting (0=Enabled, 1=Disabled): $originalValue"

                # If AutoPlay was enabled, disable it temporarily
                if ($originalValue -eq 0) {
                    Write-Log "[$($VMName)] AutoPlay is currently ENABLED. Disabling..."
                    Set-ItemProperty -Path $regPath -Name $regName -Value 1
                } else {
                    Write-Log "[$($VMName)] AutoPlay is already disabled."
                }
                
                # Shutdown VM if running and verify
                if ($vm.State -eq 'Running') {
                    Write-Log ("[$($VMName)] Shutting down VM...")
                    Stop-VM -Name $VMName -Force -ErrorAction Stop

                    # Wait until VM state is 'Off'
                    $maxWaitShutdown = 60
                    $waited = 0
                    while (($vm.State -ne 'Off') -and ($waited -lt $maxWaitShutdown)) {
                        Start-Sleep -Seconds 1
                        $vm = Get-VM -Name $VMName
                        $waited++
                    }

                    if ($vm.State -ne 'Off') {
                        Write-Log ("[$($VMName)] ERROR: VM did not shutdown within $maxWaitShutdown seconds. Skipping...")
                        continue
                    }
                    Write-Log ("[$($VMName)] VM is fully stopped.")
                }

                # VM GPU Partition Adapter Check
                try {
                    $existingAdapter = Get-VMGpuPartitionAdapter -VMName $VMName -ErrorAction SilentlyContinue
                    if (-not $existingAdapter) {
                        Write-Log ("[$($VMName)] No GPU Partition Adapter found. Creating one...")

                        Add-VMGpuPartitionAdapter -VMName $VMName

                        Set-VMGpuPartitionAdapter -VMName $VMName `
                            -MinPartitionVRAM 80000000 -MaxPartitionVRAM 100000000 -OptimalPartitionVRAM 100000000 `
                            -MinPartitionEncode 80000000 -MaxPartitionEncode 100000000 -OptimalPartitionEncode 100000000 `
                            -MinPartitionDecode 80000000 -MaxPartitionDecode 100000000 -OptimalPartitionDecode 100000000 `
                            -MinPartitionCompute 80000000 -MaxPartitionCompute 100000000 -OptimalPartitionCompute 100000000

                        Set-VM -VMName $VMName -GuestControlledCacheTypes $true
                        Set-VM -VMName $VMName -LowMemoryMappedIoSpace 1Gb
                        Set-VM -VMName $VMName -HighMemoryMappedIoSpace 32GB

                        Write-Log ("[$($VMName)] GPU Partition Adapter added and configured.")
                    } else {
                        Write-Log ("[$($VMName)] GPU Partition Adapter already exists. Skipping creation.")
                    }
                } catch {
                    Write-Log ("[$($VMName)] ERROR managing GPU Partition Adapter: $($_.Exception.Message)")
                }

                # Get VHD path
                $vhdPath = (Get-VMHardDiskDrive -VMName $VMName | Select-Object -First 1).Path
                if (-not $vhdPath) {
                    Write-Log ("[$($VMName)] ERROR: Could not find VHDX")
                    continue
                }
                Write-Log ("[$($VMName)] Found VHDX: $($vhdPath)")

                # Mount VHD
                try {
                    Mount-DiskImage -ImagePath $vhdPath -ErrorAction Stop
                } catch {
                    Write-Log ("[$($VMName)] ERROR mounting $($vhdPath): $($_.Exception.Message)")
                    continue
                }

                # Wait for NTFS volume with a drive letter on the mounted VHD only
                $disk = Get-DiskImage -ImagePath $vhdPath | Get-Disk
                $maxWait = 20
                $waited = 0
                $mountLetter = $null

                while (-not $mountLetter -and $waited -lt $maxWait) {
                    Start-Sleep -Seconds 1
                    $partitions = Get-Partition -DiskNumber $disk.Number | Where-Object { $_.Type -ne 'EFI' }
                    foreach ($part in $partitions) {
                        $vol = Get-Volume -Partition $part -ErrorAction SilentlyContinue
                        if ($vol -and $vol.FileSystem -eq 'NTFS' -and $vol.DriveLetter) {
                            $mountLetter = "$($vol.DriveLetter):"
                            break
                        }
                    }
                    $waited++
                }

                if (-not $mountLetter) {
                    Write-Log ("[$($VMName)] ERROR: Could not find NTFS volume with drive letter on VHD after $($maxWait) seconds.")
                    Dismount-DiskImage -ImagePath $vhdPath -ErrorAction SilentlyContinue
                    continue
                }

                Write-Log ("[$($VMName)] Using NTFS partition $($mountLetter) as target for driver injection.")

                # Inject drivers
                $HostDriverStore = "C:\Windows\System32\DriverStore\FileRepository"
                $VMDriverStore = "Windows\System32\HostDriverStore\FileRepository"
                Copy-Drivers -VMName $VMName -MountLetter $mountLetter -Source $HostDriverStore -Destination $VMDriverStore

                # Extra step for NVIDIA GPU if host has any
                if ($HasNvidiaGPU) {
                    Write-Log ("[$($VMName)] Host has NVIDIA GPU, copying nv* files...")
                    Copy-Drivers -VMName $VMName -MountLetter $mountLetter -Source "C:\Windows\System32" -Destination "Windows\System32" -FileMask "nv*"
                }

                # Dismount VHD
                Dismount-DiskImage -ImagePath $vhdPath -ErrorAction SilentlyContinue
                Write-Log ("[$($VMName)] GPU drivers injected and VHD dismounted.")

                # Autoplay re-enable if it was originally enabled
                if ($originalValue -eq 0) {
                    Write-Log "[$($VMName)] Restoring AutoPlay to ENABLED state..."
                    Set-ItemProperty -Path $regPath -Name $regName -Value 0
                } else {
                    Write-Log "[$($VMName)] AutoPlay was originally disabled. Leaving it disabled."
                }
                
                # Option to start VM again
                if ($StartVMCheckbox.Checked) {
                    try {
                        Write-Log ("[$($VMName)] Starting VM as requested...")
                        Start-VM -Name $VMName -ErrorAction Stop
                        
                        # Get VM ID
                        $vm = Get-VM -Name $VMName -ErrorAction Stop
                        $vmId = $vm.Id.Guid

                        # Look for existing vmconnect.exe processes for this VM
                        $existing = Get-CimInstance Win32_Process -Filter "Name = 'vmconnect.exe'" |
                        Where-Object { $_.CommandLine -match $vm.Name }

                        if ($existing) {
                            Write-Log ("[$($VMName)] A console for $($vm.VMName) is already open. Skipping...")
                        } else {
                            Write-Log ("[$($VMName)] Opening console for $($vm.VMName)...")
                            vmconnect.exe localhost $($vm.VMName)
                        }
                        
                        Write-Log ("[$($VMName)] VM started successfully.")
                    } catch {
                        Write-Log ("[$($VMName)] ERROR starting VM: $($_.Exception.Message)")
                    }
                }

                # DONE Message
                Write-Log "[$($VMName)] Done..."

            } catch {
                Write-Log ("[$($VMName)] ERROR: $($_.Exception.Message)")
            }
        }
    }
}

# GUI
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "GPU Driver Injector for Hyper-V"
$Form.Size = New-Object System.Drawing.Size(700,650)
$form.FormBorderStyle = 'Fixed3D'
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$Form.StartPosition = "CenterScreen"

$label = New-Object System.Windows.Forms.Label
$label.Text = "Select VMs to update GPU drivers:"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(10,10)
$Form.Controls.Add($label)

$VMCheckboxes = @()
$vms = Get-VM
$y = 40
foreach ($vm in $vms) {
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = $vm.Name
    $checkbox.AutoSize = $true
    $checkbox.Location = New-Object System.Drawing.Point(20,[int]$y)
    $Form.Controls.Add($checkbox)
    $VMCheckboxes += $checkbox
    $y += 25
}

# Start VM option
$StartVMCheckbox = New-Object System.Windows.Forms.CheckBox
$StartVMCheckbox.Text = "Start VM after update"
$StartVMCheckbox.AutoSize = $true
$StartVMCheckbox.Location = New-Object System.Drawing.Point(20,[int]($y + 10))
$Form.Controls.Add($StartVMCheckbox)

# Status log box
$LogBox = New-Object System.Windows.Forms.TextBox
$LogBox.Multiline = $true
$LogBox.ScrollBars = "Vertical"
$LogBox.WordWrap = $true
$LogBox.ReadOnly = $true
$LogBox.Location = New-Object System.Drawing.Point(20,[int]($y + 40))
$LogBox.Size = New-Object System.Drawing.Size(640,220)
$Form.Controls.Add($LogBox)

# Update button
$UpdateButton = New-Object System.Windows.Forms.Button
$UpdateButton.Text = "Update GPU"
$UpdateButton.Location = New-Object System.Drawing.Point(180,520)
$UpdateButton.Size = New-Object System.Drawing.Size(120,30)
$UpdateButton.Add_Click({ Update-GPUDrivers })
$Form.Controls.Add($UpdateButton)

# Exit button
$ExitButton = New-Object System.Windows.Forms.Button
$ExitButton.Text = "Exit"
$ExitButton.Location = New-Object System.Drawing.Point(380,520)
$ExitButton.Size = New-Object System.Drawing.Size(120,30)
$ExitButton.Add_Click({
    Write-Log "Exit requested."
    Cleanup-Mounts
    $Form.Close()
})
$Form.Controls.Add($ExitButton)

# Cleanup on [X]
$Form.Add_FormClosing({
    Write-Log "Form closing triggered."
    Cleanup-Mounts
})

# Show GUI
[void]$Form.ShowDialog()
