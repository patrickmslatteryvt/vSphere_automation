ZFS on Linux (ZOL)
==================

**NOTE:
I absolutely do not recommend using ZFS as a guest file-system inside a virtual infrastructure of any type for anything other than test purposes.
ZFS belongs running directly on the hardware at the host OS or hypervisor level.**

**Purpose:**

Project to automate the deployment of a ZFS on Linux VM using CentOS v6.5 for testing purposes.

##### Step 1:

Create a vSphere VM to test our ZOL setup in. Requires a vSphere infrastructure with PowerCLI installed on your client.
I tested with vSphere v5.5 on my server and with PowerCLI v5.5 and PowerGUI v3.8 on my client.

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

### Next steps:
* Install yum updates
```Shell
yum update -y
```
* Install the openssh client which is necessary for rsync (NOTE: Should add this to the kickstart file instead)
```Shell
yum install -y openssh-clients
```
* Install VMware Tools

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
* Take VM snapshot

Now that the VMware Tools are installed we can remotely power-off the VM via PowerCLI so that we can take an at-rest snapshot that we can use to quickly restore to during our testing.

```PowerShell
Snapshot-VM -VM "ZOL_CentOS"
```
   
* Install ZFS prerequisites

* Install ZFS

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
* Test
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

* Remove any unnecessary packages

Need to build RPMs at some point as if we remove gcc for instance, spl and zfs will go with it.

* Create vdev file

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

* Create main storage pool

At this point we can finally create our ZS file system and mount it.
Here I'm going to create RAID 10 set from the 8 disks on HBA #1 and mount it at /srv, by default there is nothing in the /srv directory on a RHEL or CentOS system.
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
If we don't use the -f (force) switch the operation will typically error out due to the disks not being completly blank, it would seem that CentOS writes some sort of marker bytes to the disk during install.

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
 
* Create the ZIL and L2ARC

For this test system I'm going to share a pair of virtual 8GB SSDs between the ZIL and the L2ARC. This isn't a configuration that you would ever want to use in a production environment as the ZIL and L2ARC have very different use cases.
Ideally you want a write intensive, very low latency device as the ZIL, the [ZeusRAM][5] drive is an ideal enterprise level production device for a ZIL.
For the L2ARC, a read intensive, high IOPS device such as one one of the Intel DC SSDs is ideal.
For our test purposes though a dedicated set of SSDs is unnecessary. ZFS will allow us to place the ZIL and L2ARC on different partitions of the same SSD devices. In this configuration we'll be mirroring the ZIL and striping the L2ARC. Again this isn't a configuration that you would ever want to use in a production environment. I've seen varying opinions on the benefit of mirroring the ZIL but the consensus seems to come down of the side of mirroring the ZIL is a best practice. The ZIL is essentially a 10 second write cache for all disk activity so that ZFS can delay and re-order writes to the hard disks to make any writes as fast as possible. AFAIK the contents of the ZIL are in RAM as well so losing the ZIL isn't critical unless you have a power failure as well. In that case you could possibly have a serious problem. 
The L2ARC is a read cache and if it goes offline it will simply be bypassed. Not having it available simply means having only the primary ARC cache in RAM to work from. Since an SSD is about two orders of magnitude faster than a hard disk (25µs SSD vs. 5ms HDD) you want to cache as much as possible on the SSD, particularly if you don't have vast amount of RAM to allocate to the ARC cache.
 
* Add pool scrub cron job
* ZFS tweaks
* Notes on what *not* to do.
* Future stuff
	* Make proper RPMs so we don't have to have the compilers etc. on each machine

### References:
* [ZOL FAQ][1]
* [A not so short guide to ZFS on Linux][2]
* [ZFS Cheatsheet][3]
* [ZFS Build][4]: A friendly guide for building ZFS based SAN/NAS solutions

[1]: http://zfsonlinux.org/faq.html "ZOL FAQ"
[2]: http://unicolet.blogspot.com/2013/03/a-not-so-short-guide-to-zfs-on-linux.html "A not so short guide to ZFS on Linux"
[3]: http://www.datadisk.co.uk/html_docs/sun/sun_zfs_cs.htm "ZFS Cheatsheet"
[4]: http://www.zfsbuild.com/  "ZFS Build: A friendly guide for building ZFS based SAN/NAS solutions"
[5]: http://www.stec-inc.com/wp-content/themes/twentytwelve/ajax/viewer.php?fid=50 "ZeusRAM"