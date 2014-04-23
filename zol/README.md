ZFS on Linux (ZOL)
==================

**NOTE:
I absolutly do not recommend using ZFS as a guest filesystem inside a virtual infrastructure of any type for anything other than test purposes.
ZFS belongs running directly on the hardware at the host OS or hypervisor level.**

Purpose:
Project to automate the deployment of a ZFS on Linux VM using CentOS v6.5 for testing purposes.

##### Step 1:

Create a vSphere VM to test our ZOL setup in. Requires a vSphere infrastructure with PowerCLI installed on your client.
I tested with vSphere v5.5 on my server and with PowerCLI v5.5 and PowerGUI v3.8 on my client.

Copy the contents of:
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
![Provisioned VM in vSphere](images/01_VM_provisioned.png?raw=true "Provisioned VM in vSphere")
![Provisioned VM properties](images/01_VM_properties.png?raw=true "Provisioned VM properties")

Next we'll start the VM and disable the unnecessary components such as the floppy, serial and parallel ports and set the correct boot order.
I haven't figured out a way to do this programatically in vSphere so we'll have to do it manually. In a production environment you would have a template with these features disabled as your baseline.

This is the initial VM BIOS screen that we get dumped into when the VM boots.

![Inital VM BIOS screen](images/02_BIOS.png?raw=true "Inital VM BIOS screen")

First we need to disable the floppy disk.

![Disable floppy disk](images/03_BIOS.png?raw=true "Disable floppy disk")

Next we need to go to the location of the extra IO devices. Press ENTER to go to the submenu.

![Location of extra IO devices](images/04_BIOS.png?raw=true "Location of extra IO devices")

Here we see that the serial ports, parallel port and floppy controller are all enabled by default. We have little use for these devices in a modern VM.

![Inital extra IO device screen](images/05_BIOS.png?raw=true "Inital extra IO device screen")

After disabling extra IO devices.

![After disabling extra IO devices](images/06_BIOS.png?raw=true "After disabling extra IO devices")

Next we move on the the VM boot order screen, the defaults won't allow us to install Linux without some rapid button presses during the VM boot process.

![Inital VM boot order screen](images/07_BIOS.png?raw=true "Inital VM boot order screen")

After reordering it will be much easier to install an OS from an ISO.

![Reordered VM boot order screen](images/08_BIOS.png?raw=true "Reordered VM boot order screen")

Save all of our BIOS changes and exit.

![Save setup and exit](images/09_BIOS.png?raw=true "Save setup and exit")


Since the CentOS v6.5 ISO is already attached the VM will now boot to the CentOS install screen.

Press TAB to edit the default install switches.

Here we'll point the VM at a web server that hosts the file https://github.com/patrickmslatteryvt/vSphere_automation/blob/master/zol/zol.ks to use as the kickstart file. I used an Nginx instance running on my DHCP server. Almost any HTTP server will work though, just make sure that you can download the .ks file without any errors. A default IIS 7 instance won't allow this for instance.

![Kickstart settings](images/10_kickstart.png?raw=true "Kickstart settings")

*Note that my DHCP/HTTP server is called "kicker" and the kickstart file is in a subdirectory named "/ks"*

OS install in progress, the install should take only 5 minutes or so.
**NEED: WHAT IF KICKSTART FILE CAN'T BE FOUND?**
![CentOS install progress](images/11_OS_install.png?raw=true "CentOS install progress")

Once the OS install process is complete the installer will halt and will ask the user to reboot.
Please detach the ISO at this point and then reboot the VM by pressing **ENTER**.

![CentOS install complete](images/12_OS_installed.png?raw=true "CentOS install complete")

After the VM has booted up fully login as user **root** with password **ZOL2014** (assuming you used the provided kickstart file).
Run **ifconfig** to determine your IP address and then use this IP to SSH into the VM.

![Initial login and get IP address of VM](images/13_ifconfig.png?raw=true "Initial login and get IP address of VM")

*Note that creating a DHCP reservation for your VM is the ideal way to set this up*

### References:

ZOL FAQ
http://zfsonlinux.org/faq.html

A not so short guide to ZFS on Linux
http://unicolet.blogspot.com/2013/03/a-not-so-short-guide-to-zfs-on-linux.html

ZFS Cheatsheet
http://www.datadisk.co.uk/html_docs/sun/sun_zfs_cs.htm

ZFS Build: A friendly guide for building ZFS based SAN/NAS solutions
http://www.zfsbuild.com/
