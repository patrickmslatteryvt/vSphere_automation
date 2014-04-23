ZFS on Linux (ZOL)
==================

NOTE:
I absolutly do not recommend using ZFS as a guest filesystem inside a virtual infrastructure of any type for anything other than test purposes.
ZFS belongs running directly on the hardware at the host OS or hypervisor level.

Purpose:
Project to automate the deployment of a ZFS on Linux VM using CentOS v6.5 for testing purposes.

Step 1:
Create a vSphere VM to test our ZOL setup in.
Requires a vSphere infrastructure with PowerCLI installed on your client.
I tested with vSphere v5.5 on my server and with PowerCLI v5.5 and PowerGUI v3.8 on my client.

Copy contents of:
https://github.com/patrickmslatteryvt/vSphere_automation/tree/master/vsphere_functions
to:
%HOMEPATH%\Documents\WindowsPowerShell\Modules\vsphere_functions

This script will do this step:
https://raw.githubusercontent.com/patrickmslatteryvt/vSphere_automation/master/zol/download_functions.ps1
You can just copy and paste it into a PowerShell console.

Then get the PowerShell script:
https://github.com/patrickmslatteryvt/vSphere_automation/blob/master/zol/create_zol_vm.ps1
and edit the settings at the top of the file to reflect your vSphere environment.
Save and run the script.
Assuming you have no errors during the VM creation you will end up with a new vSphere VM ready to be booted up and have CentOS v6.5 installed on it.

![Provisioned VM in vSphere](images/01_VM_provisioned.png?raw=true)

Next we'll start the VM and disable the unnecessary components such as the floppy, serial and parallel ports and set the correct boot order.
I haven't figured out a way to do this programatically in vSphere so we'll have to do it manually. In a production environment you would have a template with these features disabled as your baseline.

![Inital VM BIOS screen](/images/02_BIOS.png)
![Disable floppy disk](/images/03_BIOS.png)
![Location of extra IO devices](/images/04_BIOS.png)
![Inital extra IO device screen](/images/05_BIOS.png)
![After disabling extra IO devices](/images/06_BIOS.png)
![Inital VM boot order screen](/images/07_BIOS.png)
![Reordered VM boot order screen](/images/08_BIOS.png)
![Save setup and exit](/images/09_BIOS.png)
![Kickstart settings](/images/10_kickstart.png)


### References:

ZOL FAQ
http://zfsonlinux.org/faq.html

A not so short guide to ZFS on Linux
http://unicolet.blogspot.com/2013/03/a-not-so-short-guide-to-zfs-on-linux.html

ZFS Cheatsheet
http://www.datadisk.co.uk/html_docs/sun/sun_zfs_cs.htm

ZFS Build: A friendly guide for building ZFS based SAN/NAS solutions
http://www.zfsbuild.com/
