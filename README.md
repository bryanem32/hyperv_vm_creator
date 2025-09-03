# Hyper-V VM Creator

After extracting to your desired folder, both programs **must be run as Administrator**.  
Right-click the program and select **Run As Administrator**.

## Parameters

| Parameter | Description | Notes / Recommendations |
|-----------|-------------|------------------------|
| **VM Name** | Name of the virtual machine | Also used as the hostname |
| **VM Location** | Folder where the VM and all files will be stored | Example: `C:\MyVMs`. A subdirectory with the VM Name is created automatically |
| **ISO Location** | Path to the Windows installation ISO | Supports **Windows 10 2004 or later** and **Windows 11** |
| **Local User** | User account created for the VM | Automatically logged in on first boot |
| **Local Password** | Password for the local user | — |
| **vCPUs** | Number of CPUs allocated to the VM | — |
| **Memory (GB)** | Amount of memory allocated to the VM | — |
| **Disk Size (GB)** | Size of the main VM hard drive (C:\) | Recommended **60GB or more** |
| **Virtual Switch** | Hyper-V virtual switch to use | Program detects existing switches; usually **Default Switch** |
| **Enable Checkpoints** | Enable VM checkpoints | Keep **unchecked** for GPU Passthrough |
| **Enable Dynamic Memory** | Allow dynamic memory allocation | Keep **unchecked** for GPU Passthrough |
| **Enable Enhanced Session Mode** | Enable enhanced session mode | Keep **unchecked** for GPU Passthrough |
| **Start VM after creation** | Launch VM immediately after creation | Recommended to check for convenience |

## Usage Notes

- Let the VM boot up and reboot a few times.  
- You may see drives being mounted and unmounted — this is normal.  
- The process:
  1. Creates the VHDX (VM disk)  
  2. Applies Windows images using **DISM**  
- **GPU Passthrough:** Do not enable Checkpoints, Dynamic Memory, or Enhanced Session Mode for proper GPU functionality.

