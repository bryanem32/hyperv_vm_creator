# YouTube Video of Programs in action
https://www.youtube.com/watch?v=MmZiHnfRjbc
# Requirements
Download a Windows 10 or 11 ISO Install. Save as an **".iso"** file
# 1. Hyper-V VM Creator
Right-click the program and select **Run As Administrator**.
## Parameters
| Parameter | Description | Notes / Recommendations |
|-----------|-------------|------------------------|
| **VM Name** | Name of the virtual machine | Also used as the hostname |
| **VM Location** | Folder where the VM and all files will be stored | Example: `C:\MyVMs`. A subdirectory with the VM Name is created automatically |
| **Intall ISO File** | Path to the Windows installation ISO | Supports **Windows 10 2004 or later** and **Windows 11** |
| **Win Edition** | Dropdown of detected Windows Editions | Recommend **PRO** Edition |
| **Local User** | User account created for the VM | Automatically logged in on first boot |
| **Local Password** | Password for the local user | Remember this! |
| **vCPUs** | Number of CPUs allocated to the VM | Recommend **4 vCPUs or more** |
| **Memory (GB)** | Amount of memory allocated to the VM | Recommend **8GB or more** |
| **Disk Size (GB)** | Size of the main VM hard drive (C:\) | Recommend **60GB or more** |
| **Virtual Switch** | Hyper-V virtual switch to use | Program detects existing switches; usually **Default Switch** |
| **VM Resolution** | VM Display Resolution | Display Resolution modified by QRes.exe |
| **Enable Checkpoints** | Enable VM checkpoints | Keep **unchecked** for GPU Passthrough |
| **Enable Dynamic Memory** | Allow dynamic memory allocation | Keep **unchecked** for GPU Passthrough |
| **Enable Enhanced Session Mode** | Enable enhanced session mode | Keep **unchecked** for GPU Passthrough |
| **Start VM after creation** | Launch VM immediately after creation | Recommended to check for convenience |
## Usage Notes
- Powershell Scripts are available to be ran directly. The binary *.exe files are compiled with ps2exe for convenience.
- If the program detects hyper-v is not running or installed, it will prompt to install hyper-v.  After enabling, it will prompt to restart the PC or not.
- PC needs to be restarted if hyper-v had to be enabled.
- Let the VM boot up and reboot a few times.  
- You may see drives being mounted and unmounted — this is normal.  
- The process:
  1. Creates the VHDX (VM disk)  
  2. Applies Windows images using **DISM**  
- **GPU Passthrough:** Do not enable Checkpoints, Dynamic Memory, or Enhanced Session Mode for proper GPU functionality.
- VM will inherit the Host PC's keyboard, language, locale and timezone settings
- Display Resolution on bootup uses QRes.exe Version 1.0.9.7 (https://sourceforge.net/projects/qres/)

# 2. Virtual Machine GPU Update
Right-click the program and select **Run As Administrator**.
## Parameters
- Click on the checkbox on the VM's for the GPU drivers to be updated
- Click on the checkbox "Start VM after update" to start the VMs selected after updating.
## Usage Notes
- Updating the GPU requires for the VMs to shutdown.  The program will shutdown the VMs automatically
- This program is separate from the Hyper-V VM Creator because this can be used independently after the drivers are updated on the Main Host PC
- This program is only tested/verified to work on VMs created by the Hyper-V VM Creator.
# Known Issues
- None
# What's New
- v4: Initial Release
- v5: Fixed Timezone issue
- v6: Fixed Host Autoplay issue | Hyper-V VM Creator program can only be ran once now
- v7: Changed Hyper-V running check to include non-english OS languages
- v8: Fixed Windows Edition detection to force DISM output to English
- v9: Added VM Resolution
