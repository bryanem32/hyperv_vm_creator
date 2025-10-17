# Latest Release
https://github.com/bryanem32/hyperv_vm_creator/archive/refs/tags/beta-v18.zip
# YouTube Video of Programs in action
https://youtu.be/AJOiNEy4hVk
# Requirements
- Host PC that is capable of Virtualization
  1. Intel-based: Enable in the BIOS **Intel Virtualization Technology, Intel VT, VT-x, or Virtualization Extensions**
  2. AMD-based: Enable in the BIOS **AMD-V or AMD SVM**
- Host PC minimum has 8GB Memory (16GB or Higher Recommended)
- Windows 10 or 11 ISO Install. Save as an **".iso"** file
- Hyper-V Host (Main PC) needs to be Windows 10/11 **Pro Edition**
- VMs can be Windows 10/11 Home or Pro Edition
- GPU Partitioning require driver support for WDDM 2.5 (**NVIDIA GTX 10-Series or newer, AMD RX Vega or newer**)
- **IMPORTANT:** If using an AMD-based CPU, it is recommended to disable the integrated graphics adapter in the BIOS. GPU Partitioning might utilize the AMD Integrated GPU instead of the discreet GPU
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

# 2. Virtual Machine GPU Update
Right-click the program and select **Run As Administrator**.
## Parameters
- Click on the checkbox on the VM's for the GPU drivers to be updated
- Click on the checkbox "Start VM after update" to start the VMs selected after updating.
## Usage Notes
- Updating the GPU drivers requires for the VMs to shutdown.  The program will shutdown the VMs automatically
- This program is separate from the Hyper-V VM Creator because this can be used independently after the drivers are updated on the Main Host PC
- This program is only tested/verified to work on VMs created by the Hyper-V VM Creator.
- Microsoft Hyper-V limits Guest VM GPU Partitioning VRAM to 4GB, regardless of Host PC's GPU VRAM size
- **IMPORTANT:** Disable integrated graphics in the BIOS if using an AMD Ryzen CPU.  Intel-based integrated graphics are OK
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
