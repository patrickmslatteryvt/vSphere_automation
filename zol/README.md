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
