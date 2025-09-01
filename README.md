After extracting to your desired folder, both programs need to be ran as Administrator.  Right Click "Run As Administrator"
Parameter for Hyper-V VM Creator:
VM Name - The name of your virtual machine. This will be used as the hostname of the pc as well.
VM Location - This will be where the VM and all the required files will be created and stored.  (e.g. C:\MyVMs)  A subdirectory using the VM Name will be created.
ISO Location - This is the Installtion ISO for Windows.  Supports Windows 10 2004 or later and Windows 11
Local User - This the user that will be created for the Windows VM and will be logged in automatically
Local Password - Password for the local user
vCPUs - The number of CPUS allocated to the VM
Memory (GB) - The amount of memory in GB allocated to the VM
Disk Size (GG) - The size of the hard drive (C:\) of the main VM (recommend 60GB or more)
Virtual Switch - The program will detect all existing Virtual Switches in Hyper-V.  Typically it will be "Default Switch"
Enable Checkpoints - Keep this unchecked for GPU Passthrough to work
Enable Dynamic Memory - Keep this unchecked for GPU Passthrough to work
Enable Enhanced Session Mode - Keep this unchecked for GPU Passthrough to work
Start VM after creation - If checked, will launch a Hyper-V console for the VM (recommended)
Let the VM boot up and reboot a few times.  You may see drives being mounted and unmounted, this is normal.  This the disk creating the VHDX (VM Disk) and applying the Windows Images using DSIM
