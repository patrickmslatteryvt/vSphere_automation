ZFS on Linux (ZOL)
==================

**NOTE:
I absolutely do not recommend using ZFS as a guest file-system inside a virtual infrastructure of any type for anything other than test purposes.
ZFS belongs running directly on the hardware at the host OS or hypervisor level.**

**Purpose:**

Project to automate the deployment of a ZFS on Linux VM using CentOS v6.5 for testing purposes.

* [Provision VM using PowerCLI](#provisionvm)
* [Configure BIOS settings](#configurebios)
* [Kickstart the OS install](#kickstart)
* [Install yum updates](#yumupdate)
* [Install yum updates](#install-yum-updates)
* [Install htop](#htop)
* [Install VMware Tools](#vmtools)
* [Take VM snapshot](#vmsnapshot)
* [Install ZFS prerequisites](#zfsprereq)
* [Install ZFS](#installzfs)
* [Test](#test)
* [Remove any unnecessary packages](#unnecessary)
* [Create vdev file](#vdev)
* [Create main storage pool](#create-main-storage-pool)
    * [Mirrored](#mirrored)
    * [RAIDZ1](#raidz1)
    * [RAIDZ2](#raidz2)
* [Create the ZIL and L2ARC](#createzil)
* [Add a zpool scrub cron job](#scrub)
* [ZFS tweaks](#tweaks)
* [Some throughput testing](#throughput)
* [Create additional file-systems and share them](#file-systems)
* [Automatic ZFS snapshots](#autosnapshots)
* [Notes on what not to do.](#not)
* [Future work](#future)
* [References](#references)


Create a vSphere VM to test our ZOL setup in. Requires a vSphere infrastructure with PowerCLI installed on your client.
I tested with vSphere v5.5 on my server and with PowerCLI v5.5 and PowerGUI v3.8 on my client.

<h3 id="provisionvm">Provision VM using PowerCLI</h3>

Copy the contents of:

    https://github.com/patrickmslatteryvt/vSphere_automation/tree/master/vsphere_functions
to:

    %HOMEPATH%\Documents\WindowsPowerShell\Modules\vsphere_functions

The following script will do the step above:

    https://raw.githubusercontent.com/patrickmslatteryvt/vSphere_automation/master/zol/download_functions.ps1
You can just copy and paste its contents into a PowerShell console and it will download the PowerShell module into the correct place on your system.

Then get the PowerShell script:

    https://github.com/patrickmslatteryvt/vSphere_automation/blob/master/zol/create_zol_vm.ps1
and edit the settings at the top of the file to reflect your vSphere environment.
Save and run the script.

Assuming you have no errors during the VM creation you will end up with a new vSphere VM ready to be booted up and have CentOS v6.5 installed on it.

<h3 id="configurebios">Configure BIOS settings</h3>

![Provisioned VM in vSphere](images/01_VM_provisioned.png?raw=true "Provisioned VM in vSphere")
![Provisioned VM properties](images/01_VM_properties.png?raw=true "Provisioned VM properties")

Next we'll start the VM and disable the unnecessary components such as the floppy, serial and parallel ports and set the correct boot order.
I haven't figured out a way to do this programatically in vSphere so we'll have to do it manually. In a production environment you would have a template with these features disabled as your baseline.

This is the initial VM BIOS screen that we get dumped into when the VM boots.

![Inital VM BIOS screen](images/02_BIOS.png?raw=true "Inital VM BIOS screen")

First we need to disable the floppy disk.

![Disable floppy disk](images/03_BIOS.png?raw=true "Disable floppy disk")

Next we need to go to the location of the extra IO devices. Press ENTER to go to the sub-menu.

![Location of extra IO devices](images/04_BIOS.png?raw=true "Location of extra IO devices")

Here we see that the serial ports, parallel port and floppy controller are all enabled by default. We have little use for these devices in a modern VM.

![Initial extra IO device screen](images/05_BIOS.png?raw=true "Initial extra IO device screen")

After disabling extra IO devices.

![After disabling extra IO devices](images/06_BIOS.png?raw=true "After disabling extra IO devices")

Next we move on the the VM boot order screen, the defaults won't allow us to install Linux without some rapid button presses during the VM boot process.

![Initial VM boot order screen](images/07_BIOS.png?raw=true "Initial VM boot order screen")

After reordering it will be much easier to install an OS from an ISO.

![Reordered VM boot order screen](images/08_BIOS.png?raw=true "Reordered VM boot order screen")

Save all of our BIOS changes and exit.

![Save setup and exit](images/09_BIOS.png?raw=true "Save setup and exit")

<h3 id="kickstart">Kickstart the OS install</h3>

Since the CentOS v6.5 ISO is already attached the VM will now boot to the CentOS install screen.

Press **TAB** to edit the default install switches.

Here we'll point the VM at a web server that hosts the file https://github.com/patrickmslatteryvt/vSphere_automation/blob/master/zol/zol.ks to use as the kickstart file. I used an Nginx instance running on my DHCP server. Almost any HTTP server will work though, just make sure that you can download the .ks file without any errors. A default IIS 7 instance won't allow this for instance.

![Kickstart settings](images/10_kickstart.png?raw=true "Kickstart settings")

*Note that my DHCP/HTTP server is called "kicker" and the kickstart file is in a sub-directory named "/ks"*

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

<h3 id="yumupdate">Install yum updates</h3>

```Shell
yum update -y
```
* Install the openssh client which is necessary for rsync (NOTE: Should add this to the kickstart file instead)
```Shell
yum install -y openssh-clients
```

<h3 id="htop">Install htop</h3>

```Shell
rpm -Uhv http://pkgs.repoforge.org/htop/htop-1.0.2-1.el6.rf.x86_64.rpm 
```

<h3 id="vmtools">Install VMware Tools</h3>

```Shell
rpm --import http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-DSA-KEY.pub
rpm --import http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub
echo "[vmware-tools]">/etc/yum.repos.d/vmware-tools.repo
echo "name=VMware Tools">>/etc/yum.repos.d/vmware-tools.repo
echo "baseurl=http://packages.vmware.com/tools/esx/latest/rhel6/x86_64">>/etc/yum.repos.d/vmware-tools.repo
echo "enabled=1">>/etc/yum.repos.d/vmware-tools.repo
echo "gpgcheck=1">>/etc/yum.repos.d/vmware-tools.repo
yum install -y vmware-tools-esx-kmods.x86_64 vmware-tools-esx-nox.x86_64
```

Please note that installing the VMware Tools can take several minutes.

<h3 id="vmsnapshot">Take VM snapshot</h3> 

Now that the VMware Tools are installed we can remotely power-off the VM via PowerCLI so that we can take an at-rest snapshot that we can use to quickly restore to during our testing.

```PowerShell
Snapshot-VM -VM "ZOL_CentOS"
```
   
<h3 id="zfsprereq">Install ZFS prerequisites</h3>

Nothing to do at this time.

<h3 id="installzfs">Install ZFS</h3>

From: http://zfsonlinux.org/epel.html
```Shell
yum localinstall -y --nogpgcheck http://archive.zfsonlinux.org/epel/zfs-release-1-3.el6.noarch.rpm
yum install -y zfs
```
I've found this install errors out on not finding a kernel at times. You should get output something like this:
```Shell
[root@localhost ~]# yum install -y zfs
Loaded plugins: fastestmirror, priorities
Loading mirror speeds from cached hostfile
 * base: mirrors.einstein.yu.edu
 * extras: mirror.trouble-free.net
 * updates: mirrors.advancedhosters.com
zfs                                                                                                                  | 2.9 kB     00:00     
zfs/primary_db                                                                                                       |  26 kB     00:00     
Setting up Install Process
Resolving Dependencies
--> Running transaction check
---> Package zfs.x86_64 0:0.6.2-1.el6 will be installed
--> Processing Dependency: spl = 0.6.2 for package: zfs-0.6.2-1.el6.x86_64
--> Processing Dependency: zfs-kmod >= 0.6.2 for package: zfs-0.6.2-1.el6.x86_64
--> Running transaction check
---> Package spl.x86_64 0:0.6.2-1.el6 will be installed
--> Processing Dependency: spl-kmod >= 0.6.2 for package: spl-0.6.2-1.el6.x86_64
---> Package zfs-dkms.noarch 0:0.6.2-1.el6 will be installed
--> Processing Dependency: dkms = 2.2.0.3-14.zfs1.el6 for package: zfs-dkms-0.6.2-1.el6.noarch
--> Processing Dependency: kernel-devel for package: zfs-dkms-0.6.2-1.el6.noarch
--> Processing Dependency: gcc for package: zfs-dkms-0.6.2-1.el6.noarch
--> Running transaction check
---> Package dkms.noarch 0:2.2.0.3-14.zfs1.el6 will be installed
---> Package gcc.x86_64 0:4.4.7-4.el6 will be installed
--> Processing Dependency: libgomp = 4.4.7-4.el6 for package: gcc-4.4.7-4.el6.x86_64
--> Processing Dependency: cpp = 4.4.7-4.el6 for package: gcc-4.4.7-4.el6.x86_64
--> Processing Dependency: glibc-devel >= 2.2.90-12 for package: gcc-4.4.7-4.el6.x86_64
--> Processing Dependency: cloog-ppl >= 0.15 for package: gcc-4.4.7-4.el6.x86_64
--> Processing Dependency: libgomp.so.1()(64bit) for package: gcc-4.4.7-4.el6.x86_64
---> Package kernel-devel.x86_64 0:2.6.32-431.11.2.el6 will be installed
---> Package spl-dkms.noarch 0:0.6.2-1.el6 will be installed
--> Running transaction check
---> Package cloog-ppl.x86_64 0:0.15.7-1.2.el6 will be installed
--> Processing Dependency: libppl_c.so.2()(64bit) for package: cloog-ppl-0.15.7-1.2.el6.x86_64
--> Processing Dependency: libppl.so.7()(64bit) for package: cloog-ppl-0.15.7-1.2.el6.x86_64
---> Package cpp.x86_64 0:4.4.7-4.el6 will be installed
--> Processing Dependency: libmpfr.so.1()(64bit) for package: cpp-4.4.7-4.el6.x86_64
---> Package glibc-devel.x86_64 0:2.12-1.132.el6 will be installed
--> Processing Dependency: glibc-headers = 2.12-1.132.el6 for package: glibc-devel-2.12-1.132.el6.x86_64
--> Processing Dependency: glibc-headers for package: glibc-devel-2.12-1.132.el6.x86_64
---> Package libgomp.x86_64 0:4.4.7-4.el6 will be installed
--> Running transaction check
---> Package glibc-headers.x86_64 0:2.12-1.132.el6 will be installed
--> Processing Dependency: kernel-headers >= 2.2.1 for package: glibc-headers-2.12-1.132.el6.x86_64
--> Processing Dependency: kernel-headers for package: glibc-headers-2.12-1.132.el6.x86_64
---> Package mpfr.x86_64 0:2.4.1-6.el6 will be installed
---> Package ppl.x86_64 0:0.10.2-11.el6 will be installed
--> Running transaction check
---> Package kernel-headers.x86_64 0:2.6.32-431.11.2.el6 will be installed
--> Finished Dependency Resolution

Dependencies Resolved

============================================================================================================================================
 Package                            Arch                       Version                                    Repository                   Size
============================================================================================================================================
Installing:
 zfs                                x86_64                     0.6.2-1.el6                                zfs                         758 k
Installing for dependencies:
 cloog-ppl                          x86_64                     0.15.7-1.2.el6                             base                         93 k
 cpp                                x86_64                     4.4.7-4.el6                                base                        3.7 M
 dkms                               noarch                     2.2.0.3-14.zfs1.el6                        zfs                          74 k
 gcc                                x86_64                     4.4.7-4.el6                                base                         10 M
 glibc-devel                        x86_64                     2.12-1.132.el6                             base                        978 k
 glibc-headers                      x86_64                     2.12-1.132.el6                             base                        608 k
 kernel-devel                       x86_64                     2.6.32-431.11.2.el6                        updates                     8.8 M
 kernel-headers                     x86_64                     2.6.32-431.11.2.el6                        updates                     2.8 M
 libgomp                            x86_64                     4.4.7-4.el6                                base                        118 k
 mpfr                               x86_64                     2.4.1-6.el6                                base                        157 k
 ppl                                x86_64                     0.10.2-11.el6                              base                        1.3 M
 spl                                x86_64                     0.6.2-1.el6                                zfs                          21 k
 spl-dkms                           noarch                     0.6.2-1.el6                                zfs                         499 k
 zfs-dkms                           noarch                     0.6.2-1.el6                                zfs                         1.7 M

Transaction Summary
============================================================================================================================================
Install      15 Package(s)

Total download size: 32 M
Installed size: 78 M
Downloading Packages:
(1/15): cloog-ppl-0.15.7-1.2.el6.x86_64.rpm                                                                          |  93 kB     00:00     
(2/15): cpp-4.4.7-4.el6.x86_64.rpm                                                                                   | 3.7 MB     00:00     
(3/15): dkms-2.2.0.3-14.zfs1.el6.noarch.rpm                                                                          |  74 kB     00:00     
(4/15): gcc-4.4.7-4.el6.x86_64.rpm                                                                                   |  10 MB     00:01     
(5/15): glibc-devel-2.12-1.132.el6.x86_64.rpm                                                                        | 978 kB     00:00     
(6/15): glibc-headers-2.12-1.132.el6.x86_64.rpm                                                                      | 608 kB     00:00     
(7/15): kernel-devel-2.6.32-431.11.2.el6.x86_64.rpm                                                                  | 8.8 MB     00:00     
(8/15): kernel-headers-2.6.32-431.11.2.el6.x86_64.rpm                                                                | 2.8 MB     00:00     
(9/15): libgomp-4.4.7-4.el6.x86_64.rpm                                                                               | 118 kB     00:00     
(10/15): mpfr-2.4.1-6.el6.x86_64.rpm                                                                                 | 157 kB     00:00     
(11/15): ppl-0.10.2-11.el6.x86_64.rpm                                                                                | 1.3 MB     00:00     
(12/15): spl-0.6.2-1.el6.x86_64.rpm                                                                                  |  21 kB     00:00     
(13/15): spl-dkms-0.6.2-1.el6.noarch.rpm                                                                             | 499 kB     00:00     
(14/15): zfs-0.6.2-1.el6.x86_64.rpm                                                                                  | 758 kB     00:00     
(15/15): zfs-dkms-0.6.2-1.el6.noarch.rpm                                                                             | 1.7 MB     00:00     
--------------------------------------------------------------------------------------------------------------------------------------------
Total                                                                                                       3.6 MB/s |  32 MB     00:08     
Running rpm_check_debug
Running Transaction Test
Transaction Test Succeeded
Running Transaction
  Installing : kernel-devel-2.6.32-431.11.2.el6.x86_64                                                                                 1/15 
  Installing : ppl-0.10.2-11.el6.x86_64                                                                                                2/15 
  Installing : cloog-ppl-0.15.7-1.2.el6.x86_64                                                                                         3/15 
  Installing : mpfr-2.4.1-6.el6.x86_64                                                                                                 4/15 
  Installing : cpp-4.4.7-4.el6.x86_64                                                                                                  5/15 
  Installing : libgomp-4.4.7-4.el6.x86_64                                                                                              6/15 
  Installing : kernel-headers-2.6.32-431.11.2.el6.x86_64                                                                               7/15 
  Installing : glibc-headers-2.12-1.132.el6.x86_64                                                                                     8/15 
  Installing : glibc-devel-2.12-1.132.el6.x86_64                                                                                       9/15 
  Installing : gcc-4.4.7-4.el6.x86_64                                                                                                 10/15 
  Installing : dkms-2.2.0.3-14.zfs1.el6.noarch                                                                                        11/15 
  Installing : spl-dkms-0.6.2-1.el6.noarch                                                                                            12/15 
Loading new spl-0.6.2 DKMS files...
First Installation: checking all kernels...
Building only for 2.6.32-431.11.2.el6.x86_64
Building initial module for 2.6.32-431.11.2.el6.x86_64
Done.

spl:
Running module version sanity check.
 - Original module
   - No original module exists within this kernel
 - Installation
   - Installing to /lib/modules/2.6.32-431.11.2.el6.x86_64/extra/

splat.ko:
Running module version sanity check.
 - Original module
   - No original module exists within this kernel
 - Installation
   - Installing to /lib/modules/2.6.32-431.11.2.el6.x86_64/extra/
Adding any weak-modules

Running the post_install script:

depmod...

DKMS: install completed.
  Installing : zfs-dkms-0.6.2-1.el6.noarch                                                                                            13/15 
Loading new zfs-0.6.2 DKMS files...
First Installation: checking all kernels...
Building only for 2.6.32-431.11.2.el6.x86_64
Building initial module for 2.6.32-431.11.2.el6.x86_64
Done.

zavl:
Running module version sanity check.
 - Original module
   - No original module exists within this kernel
 - Installation
   - Installing to /lib/modules/2.6.32-431.11.2.el6.x86_64/extra/

znvpair.ko:
Running module version sanity check.
 - Original module
   - No original module exists within this kernel
 - Installation
   - Installing to /lib/modules/2.6.32-431.11.2.el6.x86_64/extra/

zunicode.ko:
Running module version sanity check.
 - Original module
   - No original module exists within this kernel
 - Installation
   - Installing to /lib/modules/2.6.32-431.11.2.el6.x86_64/extra/

zcommon.ko:
Running module version sanity check.
 - Original module
   - No original module exists within this kernel
 - Installation
   - Installing to /lib/modules/2.6.32-431.11.2.el6.x86_64/extra/

zfs.ko:
Running module version sanity check.
 - Original module
   - No original module exists within this kernel
 - Installation
   - Installing to /lib/modules/2.6.32-431.11.2.el6.x86_64/extra/

zpios.ko:
Running module version sanity check.
 - Original module
   - No original module exists within this kernel
 - Installation
   - Installing to /lib/modules/2.6.32-431.11.2.el6.x86_64/extra/
Adding any weak-modules

Running the post_install script:

depmod...

DKMS: install completed.
  Installing : spl-0.6.2-1.el6.x86_64                                                                                                 14/15 
  Installing : zfs-0.6.2-1.el6.x86_64                                                                                                 15/15 
  Verifying  : zfs-dkms-0.6.2-1.el6.noarch                                                                                             1/15 
  Verifying  : kernel-headers-2.6.32-431.11.2.el6.x86_64                                                                               2/15 
  Verifying  : spl-0.6.2-1.el6.x86_64                                                                                                  3/15 
  Verifying  : cpp-4.4.7-4.el6.x86_64                                                                                                  4/15 
  Verifying  : glibc-devel-2.12-1.132.el6.x86_64                                                                                       5/15 
  Verifying  : zfs-0.6.2-1.el6.x86_64                                                                                                  6/15 
  Verifying  : kernel-devel-2.6.32-431.11.2.el6.x86_64                                                                                 7/15 
  Verifying  : libgomp-4.4.7-4.el6.x86_64                                                                                              8/15 
  Verifying  : mpfr-2.4.1-6.el6.x86_64                                                                                                 9/15 
  Verifying  : spl-dkms-0.6.2-1.el6.noarch                                                                                            10/15 
  Verifying  : dkms-2.2.0.3-14.zfs1.el6.noarch                                                                                        11/15 
  Verifying  : gcc-4.4.7-4.el6.x86_64                                                                                                 12/15 
  Verifying  : ppl-0.10.2-11.el6.x86_64                                                                                               13/15 
  Verifying  : cloog-ppl-0.15.7-1.2.el6.x86_64                                                                                        14/15 
  Verifying  : glibc-headers-2.12-1.132.el6.x86_64                                                                                    15/15 

Installed:
  zfs.x86_64 0:0.6.2-1.el6                                                                                                                  

Dependency Installed:
  cloog-ppl.x86_64 0:0.15.7-1.2.el6              cpp.x86_64 0:4.4.7-4.el6                         dkms.noarch 0:2.2.0.3-14.zfs1.el6         
  gcc.x86_64 0:4.4.7-4.el6                       glibc-devel.x86_64 0:2.12-1.132.el6              glibc-headers.x86_64 0:2.12-1.132.el6     
  kernel-devel.x86_64 0:2.6.32-431.11.2.el6      kernel-headers.x86_64 0:2.6.32-431.11.2.el6      libgomp.x86_64 0:4.4.7-4.el6              
  mpfr.x86_64 0:2.4.1-6.el6                      ppl.x86_64 0:0.10.2-11.el6                       spl.x86_64 0:0.6.2-1.el6                  
  spl-dkms.noarch 0:0.6.2-1.el6                  zfs-dkms.noarch 0:0.6.2-1.el6                   

Complete!
```

<h3 id="test">Test</h3>

To see if ZFS is working run:
```Shell
[root@localhost ~]# lsmod|grep zfs
zfs                  1152935  0 
zcommon                44698  1 zfs
znvpair                80460  2 zfs,zcommon
zavl                    6925  1 zfs
zunicode              323159  1 zfs
spl                   260832  5 zfs,zcommon,znvpair,zavl,zunicode

[root@localhost ~]# zpool status
no pools available
```
As long as you get some zfs modules listed then it's working.

<h3 id="unnecessary">Remove any unnecessary packages</h3>

Need to build RPMs at some point as if we remove gcc for instance, spl and zfs will go with it.

<h3 id="vdev">Create vdev file</h3>

If you more than a few (2?) disks allocated to your ZFS pool it's highly recommended to use a location to disk ID mapping file so that your ZFS pool will still work if you decide to pull out all the disks and put them back in again in a slightly different order.
There are some sample mapping files available in the /etc/zfs/ directory.
I wrote a quick and dirty Bash script that you can use to generate the vdev file.
```Shell
write_vdev_id_conf.sh
```
After the `/etc/zfs/vdev_id.conf` file is in place we need to run the command:
```Shell
udevadm trigger
```
to actually create the `/dev/disk/by-vdev` directory: 
```Shell
[root@localhost ~]# ls -la /dev/disk/by-vdev/
lrwxrwxrwx. 1 root root   9 Apr 24 17:12 c1t0d0 -> ../../sdb
lrwxrwxrwx. 1 root root   9 Apr 24 17:12 c1t1d0 -> ../../sdc
lrwxrwxrwx. 1 root root   9 Apr 24 17:12 c1t2d0 -> ../../sdd
lrwxrwxrwx. 1 root root   9 Apr 24 17:12 c1t3d0 -> ../../sde
lrwxrwxrwx. 1 root root   9 Apr 24 17:12 c1t4d0 -> ../../sdf
lrwxrwxrwx. 1 root root   9 Apr 24 17:12 c1t5d0 -> ../../sdg
lrwxrwxrwx. 1 root root   9 Apr 24 17:12 c1t6d0 -> ../../sdh
lrwxrwxrwx. 1 root root   9 Apr 24 17:12 c1t8d0 -> ../../sdi
lrwxrwxrwx. 1 root root   9 Apr 24 17:12 c2t0d0 -> ../../sdj
lrwxrwxrwx. 1 root root   9 Apr 24 17:12 c2t1d0 -> ../../sdk
```
If you don't use a vdev file you will almost certainly run into this error sooner or later:
```Shell
[root@localhost ~]# zpool status -x
  pool: mypool
 state: UNAVAIL
status: One or more devices could not be used because the label is missing 
        or invalid.  There are insufficient replicas for the pool to continue
        functioning.
action: Destroy and re-create the pool from
        a backup source.
   see: http://zfsonlinux.org/msg/ZFS-8000-5E
  scan: none requested
config:
        NAME        STATE     READ WRITE CKSUM
        mypool      UNAVAIL      0     0     0  insufficient replicas
          mirror-0  UNAVAIL      0     0     0  insufficient replicas
            sda     UNAVAIL      0     0     0
            sdb     FAULTED      0     0     0  corrupted data
            sdc     FAULTED      0     0     0  corrupted data
            sdd     FAULTED      0     0     0  corrupted data
            sde     FAULTED      0     0     0  corrupted data
            sdf     FAULTED      0     0     0  corrupted data
            sdg     FAULTED      0     0     0  corrupted data
            sdh     FAULTED      0     0     0  corrupted data
        logs
          mirror-1  UNAVAIL      0     0     0  insufficient replicas
            sdi1    FAULTED      0     0     0  corrupted data
            sdj1    FAULTED      0     0     0  corrupted data
```

<h3 id="zpool">Create main storage pool</h3>

<h4 id="mirrored">Mirrored</h4>

At this point we can finally create our ZS file system and mount it.
Here I'm going to create a RAID 10 set from the 8 disks on HBA #1 and mount it at /srv, by default there is nothing in the /srv directory on a RHEL or CentOS system.
```Shell 
zpool create -f mypool mirror c1t0d0 c1t1d0 mirror c1t2d0 c1t3d0 mirror c1t4d0 c1t5d0 mirror c1t6d0 c1t8d0 -m /srv

[root@localhost ~]# zpool status           
  pool: mypool
 state: ONLINE
  scan: none requested
config:
        NAME        STATE     READ WRITE CKSUM
        mypool      ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            c1t0d0  ONLINE       0     0     0
            c1t1d0  ONLINE       0     0     0
          mirror-1  ONLINE       0     0     0
            c1t2d0  ONLINE       0     0     0
            c1t3d0  ONLINE       0     0     0
          mirror-2  ONLINE       0     0     0
            c1t4d0  ONLINE       0     0     0
            c1t5d0  ONLINE       0     0     0
          mirror-3  ONLINE       0     0     0
            c1t6d0  ONLINE       0     0     0
            c1t8d0  ONLINE       0     0     0
errors: No known data errors

[root@localhost ~]# zpool iostat           
               capacity     operations    bandwidth
pool        alloc   free   read  write   read  write
----------  -----  -----  -----  -----  -----  -----
mypool       166K  39.7G      1     33  1.69K  34.8K
```
If we don't use the -f (force) switch the operation will typically error out due to the disks not being completely blank, it would seem that CentOS writes some sort of marker bytes to the disk during install.

<h4 id="raidz1">RAIDZ1</h4>

If I wanted a RAIDZ (RAID5 - single parity disk) array instead I'd run:
```Shell
zpool create -f mypool raidz c1t0d0 c1t1d0 c1t2d0 c1t3d0 c1t4d0 c1t5d0 c1t6d0 c1t8d0 -m /srv

[root@localhost ~]# zpool status
  pool: mypool
 state: ONLINE
  scan: none requested
config:
        NAME        STATE     READ WRITE CKSUM
        mypool      ONLINE       0     0     0
          raidz1-0  ONLINE       0     0     0
            c1t0d0  ONLINE       0     0     0
            c1t1d0  ONLINE       0     0     0
            c1t2d0  ONLINE       0     0     0
            c1t3d0  ONLINE       0     0     0
            c1t4d0  ONLINE       0     0     0
            c1t5d0  ONLINE       0     0     0
            c1t6d0  ONLINE       0     0     0
            c1t8d0  ONLINE       0     0     0
errors: No known data errors

[root@localhost ~]# zpool iostat
               capacity     operations    bandwidth
pool        alloc   free   read  write   read  write
----------  -----  -----  -----  -----  -----  -----
mypool       225K  79.5G      0      4    237  3.92K
```

<h4 id="raidz2">RAIDZ2</h4>

If I wanted a RAIDZ2 (RAID6 - dual parity disks) array I'd run:
```Shell
zpool create -f mypool raidz2 c1t0d0 c1t1d0 c1t2d0 c1t3d0 c1t4d0 c1t5d0 c1t6d0 c1t8d0 -m /srv

[root@localhost ~]# zpool status           
  pool: mypool
 state: ONLINE
  scan: none requested
config:
        NAME        STATE     READ WRITE CKSUM
        mypool      ONLINE       0     0     0
          raidz2-0  ONLINE       0     0     0
            c1t0d0  ONLINE       0     0     0
            c1t1d0  ONLINE       0     0     0
            c1t2d0  ONLINE       0     0     0
            c1t3d0  ONLINE       0     0     0
            c1t4d0  ONLINE       0     0     0
            c1t5d0  ONLINE       0     0     0
            c1t6d0  ONLINE       0     0     0
            c1t8d0  ONLINE       0     0     0
errors: No known data errors

[root@localhost ~]# zpool iostat           
               capacity     operations    bandwidth
pool        alloc   free   read  write   read  write
----------  -----  -----  -----  -----  -----  -----
mypool       346K  79.5G      2     41  2.38K  40.3K
```
I'm not sure why a RAIDZ2 pool has the same amount of free space listed as a RAIDZ pool. As I understood it the RAIDZ2 pool should have been at least one disks worth of space less.

Hint: To completely remove a pool use the command:
```Shell
zpool destroy -f mypool
```
 
<h3 id="createzil">Create the ZIL and L2ARC</h3>

For this test system I'm going to share a pair of virtual 8GB SSDs between the ZIL and the L2ARC. This isn't a configuration that you would ever want to use in a production environment as the ZIL and L2ARC have very different use cases.

Ideally you want a small capacity, write intensive, very low latency device as the ZIL, the [ZeusRAM][5] drive is an ideal enterprise level production device for a ZIL.

For the L2ARC, a large capacity, read intensive, low latency and high IOPS device such as one of the Intel DC series SSDs is ideal.

For our test purposes though a dedicated set of SSDs is unnecessary. ZFS will allow us to place the ZIL and L2ARC on different partitions of the same SSD devices. In this configuration we'll be mirroring the ZIL and striping the L2ARC. Again this isn't a configuration that you would ever want to use in a production environment. I've seen varying opinions on the benefit of mirroring the ZIL but the consensus seems to come down of the side of mirroring the ZIL is a best practice. The ZIL is essentially a 10 second write cache for all disk activity so that ZFS can delay and re-order writes to the hard disks to make any writes as fast as possible. AFAIK the contents of the ZIL are in RAM as well so losing the ZIL isn't critical unless you have a power failure as well. In that case you could possibly have a serious problem.
 
The L2ARC is a read cache and if it goes offline it will simply be bypassed. Not having it available simply means having only the primary ARC cache in RAM to work from. Since an SSD is about two orders of magnitude faster than a hard disk (25µs SSD vs. 5ms HDD) you want to cache as much as possible on the SSD, particularly if you don't have vast amount of RAM to allocate to the ARC cache.

First we'll set the SSDs to have a GPT partitioning scheme which is what ZFS uses.
```Shell
parted -s /dev/disk/by-vdev/c2t0d0 mklabel gpt
parted -s /dev/disk/by-vdev/c2t1d0 mklabel gpt
```

Next we'll carve up the disks into two partitions each, the first 15% going to the ZIL and the rest being allocated to the L2ARC. The ZIL only needs to be as big as 10 seconds of write throughput on your system so it can be pretty small. In a production environment an 8GB ZIL is quite adequate for most cases.
```Shell
# ZIL
parted /dev/disk/by-vdev/c2t0d0 mkpart primary 0% 15%
parted /dev/disk/by-vdev/c2t1d0 mkpart primary 0% 15%
# L2ARC
parted /dev/disk/by-vdev/c2t0d0 mkpart primary 15% 100%
parted /dev/disk/by-vdev/c2t1d0 mkpart primary 15% 100%

[root@localhost ~]# parted -l
Model: VMware Virtual disk (scsi)
Disk /dev/sdj: 8590MB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Number  Start   End     Size    File system  Name     Flags
 1      1049kB  1289MB  1288MB               primary
 2      1289MB  8589MB  7300MB               primary

Model: VMware Virtual disk (scsi)
Disk /dev/sdk: 8590MB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Number  Start   End     Size    File system  Name     Flags
 1      1049kB  1289MB  1288MB               primary
 2      1289MB  8589MB  7300MB               primary
```

Now we can add the ZIL and L2ARC partitions to our pool
```Shell
# Add a mirrored ZIL
zpool add mypool log mirror c2t0d0-part1 c2t1d0-part1

# Add L2ARC devices (Does not need to be mirrored, L2ARC will be ignored if a device fails - at the cost of cache hits dropping to 0%)
zpool add mypool cache c2t0d0-part2
zpool add mypool cache c2t1d0-part2

[root@localhost ~]# zpool status
  pool: mypool
 state: ONLINE
  scan: none requested
config:
        NAME              STATE     READ WRITE CKSUM
        mypool            ONLINE       0     0     0
          mirror-0        ONLINE       0     0     0
            c1t0d0        ONLINE       0     0     0
            c1t1d0        ONLINE       0     0     0
          mirror-1        ONLINE       0     0     0
            c1t2d0        ONLINE       0     0     0
            c1t3d0        ONLINE       0     0     0
          mirror-2        ONLINE       0     0     0
            c1t4d0        ONLINE       0     0     0
            c1t5d0        ONLINE       0     0     0
          mirror-3        ONLINE       0     0     0
            c1t6d0        ONLINE       0     0     0
            c1t8d0        ONLINE       0     0     0
        logs
          mirror-4        ONLINE       0     0     0
            c2t0d0-part1  ONLINE       0     0     0
            c2t1d0-part1  ONLINE       0     0     0
        cache
          c2t0d0-part2    ONLINE       0     0     0
          c2t1d0-part2    ONLINE       0     0     0
errors: No known data errors
```


<h3 id="scrub">Add a zpool scrub cron job</h3>

The simplest way to check the data integrity of the ZFS filesystem is to initiate an explicit scrubbing of all data within the pool. This operation traverses all the data in the pool once and verifies that all blocks can be read.
Running a scrub weekly is highly recommended. Here is a simple Bash script to write a **new** crontab file for the root user. (It should go without saying that you should not use this on a production system!)

```Shell
TMP_CRONTAB=$(mktemp) || { echo "Failed to create temp file"; exit 1; }
echo  '# Example of job definition'>${TMP_CRONTAB}
echo  '# .---------------- minute (0 - 59)'>>${TMP_CRONTAB}
echo  '# |  .------------- hour (0 - 23)'>>${TMP_CRONTAB}
echo  '# |  |  .---------- day of month (1 - 31)'>>${TMP_CRONTAB}
echo  '# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...'>>${TMP_CRONTAB}
echo  '# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat'>>${TMP_CRONTAB}
echo  '# |  |  |  |  |'>>${TMP_CRONTAB}
echo  '# *  *  *  *  * user-name command to be executed'>>${TMP_CRONTAB}
echo  '#':>>${TMP_CRONTAB}
echo  '# Start ZFS scrub at 3AM every Saturday night':>>${TMP_CRONTAB}
echo  '0 3 * * sat /sbin/zpool scrub mypool':>>${TMP_CRONTAB}
crontab -u root ${TMP_CRONTAB}
rm -f ${TMP_CRONTAB}
```
For more information see: [Checking ZFS File System Integrity][6]

<h3 id="tweaks">ZFS tweaks</h3>

In ZFS data integrity comes first, speed is secondary. That said its speed in a properly designed system is very impressive. There just isn't much need to tweak it out of the box.
That said if you really want to tweak it you can get a list of the available properties by running:
```Shell
zfs get
```
One property that I typically turn off is file access update times.
```Shell 
zfs set atime=off mypool
```
For more information see: [ZFS Evil Tuning Guide][7]

<h3 id="throughput">Some throughput testing</h3>

Doing bench-marking in a VM is almost pointless if the VM being tested is sharing resources with other VMs. You can't expect to get consistent numbers in such a setup. In this case we will run some tests to see the difference between having/not having a ZIL or L2ARC. We'll also get a chance to see some of the ZFS admin tools.
```Shell
# Write a 2GB file of zeros to the ZFS pool
dd bs=1M count=2048 if=/dev/zero of=/srv/test_1.dd conv=fdatasync
2048+0 records in
2048+0 records out
2147483648 bytes (2.1 GB) copied, 17.642 s, 122 MB/s

# Write a 2GB file of pseudo-random data to the ZFS pool
dd bs=1M count=2048 if=/dev/urandom of=/srv/test_2.dd conv=fdatasync
2048+0 records in
2048+0 records out
2147483648 bytes (2.1 GB) copied, 261.021 s, 8.2 MB/s
```
If you open two additional ssh consoles to the VM you can watch the CPU and RAM activity with `htop` in one console window and the ZFS IO patterns with `zpool iostat -v 3` in the other console window.
Here we can see the system activity in htop before we start any tests, we can see that the system is idle and using a minimal amount of RAM (230MB of the 4GB allocated).

![htop before tests](images/14_htop_before.png?raw=true "htop before tests")

```Shell
                     capacity     operations    bandwidth
pool              alloc   free   read  write   read  write
----------------  -----  -----  -----  -----  -----  -----
mypool            3.86G  35.9G      0    925      0  73.0M
  mirror           986M  8.97G      0     76      0  7.63M
    c1t0d0            -      -      0     79      0  8.57M
    c1t1d0            -      -      0     72      0  7.67M
  mirror           987M  8.97G      0     63      0  7.82M
    c1t2d0            -      -      0     64      0  7.70M
    c1t3d0            -      -      0     65      0  7.82M
  mirror           988M  8.97G      0     90      0  9.03M
    c1t4d0            -      -      0     85      0  9.31M
    c1t5d0            -      -      0     83      0  9.03M
  mirror           991M  8.97G      0     81      0  7.80M
    c1t6d0            -      -      0     69      0  7.39M
    c1t8d0            -      -      0     73      0  7.88M
logs                  -      -      -      -      -      -
  mirror           128K  1.19G      0    613      0  40.7M
    c2t0d0-part1      -      -      0    613      0  40.7M
    c2t1d0-part1      -      -      0    659      0  43.8M
cache                 -      -      -      -      -      -
  c2t0d0-part2    1.55G  5.25G      2    127  1.31K  15.6M
  c2t1d0-part2    1.55G  5.25G      0    110    167  13.7M
----------------  -----  -----  -----  -----  -----  -----
```
Here we see a fairly typical zpool iostat trace during the write of the zeroed file. We can see that the ZIL (log) drives are adsorbing a 40MBps write rate and the 8 hard drives are taking on another 73MBps write rate. Below we can see the htop graph showing that the CPUs are being saturated and that the RAM is being used up for the ARC cache.

![htop during zero test](images/15_htop_zero.png?raw=true "htop during zero test")

```Shell
                     capacity     operations    bandwidth
pool              alloc   free   read  write   read  write
----------------  -----  -----  -----  -----  -----  -----
mypool            2.25G  37.5G      0    138    853  11.4M
  mirror           575M  9.38G      0     24      0  3.00M
    c1t0d0            -      -      0     25      0  3.00M
    c1t1d0            -      -      0     25      0  3.00M
  mirror           575M  9.38G      0     40    853  2.86M
    c1t2d0            -      -      0     32    853  2.86M
    c1t3d0            -      -      0     32      0  2.86M
  mirror           577M  9.37G      0     38      0  2.69M
    c1t4d0            -      -      0     29      0  2.69M
    c1t5d0            -      -      0     29      0  2.69M
  mirror           579M  9.37G      0     34      0  2.85M
    c1t6d0            -      -      0     30      0  2.85M
    c1t8d0            -      -      0     30      0  2.85M
logs                  -      -      -      -      -      -
  mirror           128K  1.19G      0      0      0      0
    c2t0d0-part1      -      -      0      0      0      0
    c2t1d0-part1      -      -      0      0      0      0
cache                 -      -      -      -      -      -
  c2t0d0-part2    1.72G  5.08G      0     49    170  6.04M
  c2t1d0-part2    1.74G  5.06G      2     44  2.17K  5.29M
----------------  -----  -----  -----  -----  -----  -----
```
Here we see a fairly typical zpool iostat trace during the write of the urandom file. We can see that the ZIL (log) drives don't appear to be doing anything (they almost certainly are doing something, we would just need a more frequent sampling rate to see it happening) and the 8 hard drives are taking on another 11MBps write rate. We can see the htop CPU graph below which shows us that the task is bound by the slow speed of the .dev/urandom device.
Below we can see the htop graph showing that the CPUs are not saturated and that about 2GB of RAM is being used up for the ARC cache.

![htop during urandom test](images/16_htop_urandom.png?raw=true "htop during urandom test")

After the tests have completed we see that the CPUs return to idle but that RAM is still in use for the ARC cache.

![htop after tests](images/17_htop_after.png?raw=true "htop after tests")

If we were to now [remove our ZIL and L2ARC][12] and rerun the same tests we should see very different results.

```Shell
zpool remove mypool mirror-4
zpool remove mypool c2t0d0-part2
zpool remove mypool c2t1d0-part2
[root@localhost ~]# zpool status
  pool: mypool
 state: ONLINE
  scan: scrub repaired 0 in 0h0m with 0 errors on Thu Apr 24 19:22:51 2014
config:
        NAME        STATE     READ WRITE CKSUM
        mypool      ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            c1t0d0  ONLINE       0     0     0
            c1t1d0  ONLINE       0     0     0
          mirror-1  ONLINE       0     0     0
            c1t2d0  ONLINE       0     0     0
            c1t3d0  ONLINE       0     0     0
          mirror-2  ONLINE       0     0     0
            c1t4d0  ONLINE       0     0     0
            c1t5d0  ONLINE       0     0     0
          mirror-3  ONLINE       0     0     0
            c1t6d0  ONLINE       0     0     0
            c1t8d0  ONLINE       0     0     0
errors: No known data errors

dd bs=1M count=2048 if=/dev/zero of=/srv/test_1.dd conv=fdatasync
2048+0 records in
2048+0 records out
2147483648 bytes (2.1 GB) copied, 53.0516 s, 40.5 MB/s
```
So without the SSD caches in places this test took about three times as long and used only about half the available CPU power.

![htop during zero test with no caches](images/18_htop_no_zil_l2arc.png?raw=true "htop during zero test with no caches")

For the urandom test (which I won't illustrate here) it takes about 10% longer but uses about the same amount of CPU power so the CPU based RNG is the real bottleneck in this case.


<h3 id="file-systems">Create additional file-systems and share them</h3>


<h3 id="autosnapshots">Automatic ZFS snapshots</h3>
 
https://github.com/zfsonlinux/zfs-auto-snapshot
See also:
https://github.com/mk01/zfs-auto-snapshot/tree/master

```Shell
wget -O /usr/local/sbin/zfs-auto-snapshot.sh https://raw.github.com/zfsonlinux/zfs-auto-snapshot/master/src/zfs-auto-snapshot.sh
chmod +x /usr/local/sbin/zfs-auto-snapshot.sh
```

<h3 id="not">Notes on what *not* to do.</h3>

  * Make sure not to use the standard /dev/sda /dev/sdb disk identifier convention if using more than 2 disks or you will almost certainly lose all your data.

  * Nothing else at this time...

<h3 id="future">Future work</h3>
	* Make RPMs so we don't have to have the compilers etc. on each machine



<h3 id="references">References</h3>
* [ZOL FAQ][1]
* [A not so short guide to ZFS on Linux][2]
* [ZFS Cheatsheet][3]
* [ZFS Build][4]: A friendly guide for building ZFS based SAN/NAS solutions
* [ZFS Evil Tuning Guide][7]
* [Oracle Solaris ZFS Administration Guide][8]

[1]: http://zfsonlinux.org/faq.html "ZOL FAQ"
[2]: http://unicolet.blogspot.com/2013/03/a-not-so-short-guide-to-zfs-on-linux.html "A not so short guide to ZFS on Linux"
[3]: http://www.datadisk.co.uk/html_docs/sun/sun_zfs_cs.htm "ZFS Cheatsheet"
[4]: http://www.zfsbuild.com/  "ZFS Build: A friendly guide for building ZFS based SAN/NAS solutions"
[5]: http://www.stec-inc.com/wp-content/themes/twentytwelve/ajax/viewer.php?fid=50 "ZeusRAM"
[6]: http://docs.oracle.com/cd/E23823_01/html/819-5461/gbbwa.html "Oracle Solaris ZFS Administration Guide - Checking ZFS File System Integrity"
[7]: http://www.solarisinternals.com/wiki/index.php/ZFS_Evil_Tuning_Guide "ZFS Evil Tuning Guide"
[8]: http://docs.oracle.com/cd/E23823_01/html/819-5461/preface-1.html#scrolltoc "Oracle Solaris ZFS Administration Guide"

[9]: http://constantin.glez.de/blog/2010/04/ten-ways-easily-improve-oracle-solaris-zfs-filesystem-performance
[10]: http://rudd-o.com/linux-and-free-software/tip-letting-your-zfs-pool-sleep
[11]: http://bernaerts.dyndns.org/linux/75-debian/279-debian-wheezy-zfs-raidz-pool
[12]: https://blogs.oracle.com/ds/entry/add_and_remove_zils_live "Add And Remove ZILs Live!"