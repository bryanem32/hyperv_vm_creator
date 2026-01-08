# Latest Release
https://github.com/bryanem32/hyperv_vm_creator/archive/refs/tags/beta-v26.zip
# YouTube Video of Programs in action
https://youtu.be/AJOiNEy4hVk
# Requirements
- Host PC that is capable of Virtualization
  1. Intel-based: Enable in the BIOS **Intel Virtualization Technology, Intel VT, VT-x, or Virtualization Extensions**
  2. AMD-based: Enable in the BIOS **AMD-V or AMD SVM**
- Host PC minimum has 8GB Memory (16GB or Higher Recommended)
- For GPU-P Support, Hyper-V Virtual Machines need to be Windows 10 2004 or later, and Windows 11 23H2 or later
- ISO Download Links
  1. Windows 10 2004 (ARCHIVE): https://archive.org/download/win-10-2004-english-x-64_202010/Win10_2004_English_x64.iso
  2. Windows 10 22H2 (ARCHIVE): https://archive.org/download/win10_22h2/Win10_22H2_English_x64.iso
  3. Windows 11 23H2 (ARCHIVE): https://archive.org/download/win-11-23h2/Win11_23H2_English_x64.iso
  4. Windows 11 24H2 (ARCHIVE): https://archive.org/download/Win11_24H2_English_x64/Win11_24H2_English_x64.iso
  5. Windows 11 25H2 **(CURRENT)**: https://www.microsoft.com/en-us/software-download/windows11
- Hyper-V Host (Main PC) needs to be Windows 10/11 **Pro Edition**
- VMs can be Windows 10/11* Home or Pro Edition
- GPU Partitioning require driver support for WDDM 2.5 (**NVIDIA GTX 10-Series or newer, AMD RX Vega or newer**)
- **IMPORTANT:** On Windows 10 PRO Host (Main PC), Disable Integrated Graphics (iGPU) if using an AMD CPU
- **IMPORTANT:** On Windows 11 PRO Host (Main PC), Virtual Machine GPU Updater can pick between Integrated Graphics or Discreet GPU for the VM
- **IMPORTANT:** Enable "Full Windows Updates" if using Windows 11 25H2 ISO, otherwise Hyper-V Console will freeze after GPU-P update
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
| **VM Resolution** | VM Display Resolution | Display Resolution modified by QRes.exe on bootup|
| **Enable Checkpoints** | Enable VM checkpoints | Keep **unchecked** for GPU Partitioning |
| **Enable Dynamic Memory** | Allow dynamic memory allocation | Keep **unchecked** for GPU Partitioning |
| **Enable Enhanced Session Mode** | Enable enhanced session mode | Keep **unchecked** for GPU Partitioning |
| **Start VM after creation** | Launch VM immediately after creation | Recommended to check for convenience |
| **Parsec (Per Computer)** | Download and install latest Parsec with Per Computer option | Access the VM through Parsec |
| **VB-Audio Cable** | Download and install VBCABLE_Driver_Pack45.zip from vb-audio.com | Adds sound to the VM with Parsec |
| **Virtual Display Driver** | Download and install usbmmidd_v2.zip from amyuni.com | Creates a virtual display driver, allows Parsec to access the VM even if the console is not connected |
| **Remote Desktop** | Enable Remote Desktop | Enables Remote Desktop for Admin users, useful if Hyper-V Video Console Freezes due to Micrsoft Updates |
| **Share Folder** | Creates a Share Folder in the Desktop| Creates a Share Folder and can be accessed from the host PC as "\\\\vm-name\share" to copy files to the VM|
| **Pause Windows Updates** | Pauses Windows Updates | Pauses Windows Updates for a year.  Can be re-enabled from Windows Updates GUI|
| **Full Windows Updates** | Runs Windows Updates after user login | Recommended now that Microsoft has fixed the Hyper-V Video Adapter Issue |
## Usage Notes
- Powershell Scripts are available to be ran directly. The binary *.exe files are compiled with ps2exe for convenience.
- If the program detects hyper-v is not running or installed, it will prompt to install hyper-v.  After enabling, it will prompt to restart the PC or not.
- PC needs to be restarted if hyper-v had to be enabled.
- Let the VM boot up and reboot a few times.  
- You may see drives being mounted and unmounted — this is normal.  
- The process:
  1. Creates the VHDX (VM disk)  
  2. Applies Windows images using **DISM**  
- **GPU Partitioning:** Do not enable Checkpoints, Dynamic Memory, or Enhanced Session Mode for proper GPU functionality.
- VM will inherit the Host PC's keyboard, language, locale and timezone settings
- Display Resolution on bootup uses QRes.exe Version 1.0.9.7 (https://sourceforge.net/projects/qres/)
- Optional Software installation requires VM Internet Access
  1. Latest Parsec is downloaded and installed with the "Per Computer" option
  2. VB Audio Cable is downloaded from www.vb-cable.com
  3. Virtual Display Adapter is downloaded from www.amyuni.com
  4. Remote Desktop - Enable Remote Desktop (useful if Hyper-V Console Freezes due to Windows Updates)
  5. Share Folder - Creates a folder named "share" on the Desktop, and shared as "share"
  6. Pause Windows Updates - Pauses Windows Updates for a year.  Can be re-enabled from Windows Updates GUI
  7. Full Windows Updates - Runs Windows Updates after user login. Recommended now that Microsoft has fixed the Hyper-V Video Adapter Issue

# 2. Virtual Machine GPU Update
Right-click the program and select **Run As Administrator**.
## Parameters
- Click on the checkbox on the VM's for the GPU drivers to be updated
- Click on the checkbox "Start VM after update" to start the VMs selected after updating.
- On a **Windows 11 PRO** Host only: Select the GPU to be uses with the VM on the dropdown list
## Usage Notes
- Updating the GPU drivers requires for the VMs to shutdown.  The program will shutdown the VMs automatically
- This program is separate from the Hyper-V VM Creator because this can be used independently after the drivers are updated on the Main Host PC
- This program is only tested/verified to work on VMs created by the Hyper-V VM Creator.
- Microsoft Hyper-V limits Guest VM GPU Partitioning VRAM to 4GB, regardless of Host PC's GPU VRAM size
- **IMPORTANT:** On Windows 10 PRO Host (Main PC), Disable Integrated Graphics (iGPU) if using an AMD CPU
- **IMPORTANT:** On Windows 11 PRO Host (Main PC), Virtual Machine GPU Updater can pick between Integrated Graphics or Discreet GPU for the VM
# Known Issues
- None
# What's New
- v4: Initial Release
- v5: Fixed Timezone issue
- v6: Fixed Host Autoplay issue | Hyper-V VM Creator program can only be ran once now
- v7: Changed Hyper-V running check to include non-english OS languages
- v8: Fixed Windows Edition detection to force DISM output to English
- v9: Added VM Resolution
- v10: GUI Consoles cannot be resized anymore
- v11-13: Unreleased/unstable versions
- v14: Added Optional Software auto installation: Parsec, VB Audio Cable, and Virtual Display Adapter
- v15: Added enabling Remote Desktop (useful if Console freezes due to Windows Updates)
- v16: Local password can now be blank (as requested)
- v17: Added Share Folder - Creates a folder named "share" in the VM Desktop and shared as "share" (e.g. \\\vm-name\share\\)
- v18: Added Pause Windows Updates - Pauses Windows Updates to stop patches from breaking GPU-P
- v19: Fixed local user's password to never expire
- v20: Added Full Windows Updates - Runs Windows Updates after user login. Recommended now that Microsoft has fixed the Hyper-V Video Adapter Issue
- v21: Added all Windows Updates including Previews (required for GPU-P fix for Windows 1125H2)
- v22: Fixed Driver Updates now deletes VM FileRepository Folder if it exists first before updating
- v23: Added ability to select GPU-P enabled Video Card to assign to the VM; GPU Update script now deletes existing GPU-P Adapter before injecting drivers.
- v24: Updated GPU Update to check for Windows 11 PRO Host; Only Windows 11 PRO Host can enable iGPU for GPU-P in a VM
- v25: Fixed OS Detection bug
- v26: Fixed Windows 10 Host using Windows 11 GPU-P Adapter instance bug; For Windows 11 Hosts, option to remove GPU-P Adapter only
