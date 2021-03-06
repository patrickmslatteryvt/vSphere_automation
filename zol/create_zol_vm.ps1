# PowerCLI script to create a ZFS on Linux (ZOL) VM for testing purposes with the following disk layout:
# SCSI 0:0 = 10GB HDD on paravirtual, this would be equivalent to a RAID1 mirror in a physical system (Booting ZFS on CentOS isn't very practical yet)
#   This will become:
#   /boot
#   swap
#   /
# 
# SCSI 1:0 = 10GB HDD on LSI SAS
# SCSI 1:1 = 10GB HDD on LSI SAS
# SCSI 1:2 = 10GB HDD on LSI SAS
# SCSI 1:3 = 10GB HDD on LSI SAS
# SCSI 1:4 = 10GB HDD on LSI SAS
# SCSI 1:5 = 10GB HDD on LSI SAS
# SCSI 1:6 = 10GB HDD on LSI SAS
# SCSI 1:8 = 10GB HDD on LSI SAS
#   This will become a mirrored vdev pool mounted at /srv
# 
# SCSI 2:0 = 8GB SSD on LSI SAS
# SCSI 2:1 = 8GB SSD on LSI SAS
#   This will become the ZIL (2GB) and L2ARC (12GB)
#   

# VM host we will create the VM on
$VS5_Host = "192.168.1.10"
# Name of VM we want to create
$vmName1 = "ZOL_CentOS"
# How many vCPUs in the VM
$vm_cpu = 2
# How much RAM in the VM (in GB)
$vmRAM = 8
# The public network the VM will talk on
$public_network_name = "VMs"
# The datastore name that the boot drive (EXT4) will reside on
$osstore = "RAID"
# Size of the boot drive (in GB)
$osstore_size_GB = 8
# The datastore name that the 8 HDDS will be created in
$hddstore = "RAID"
# Size of the HDDs (in GB)
$hddstore_size_GB = 10
# The datastore name that the 2 SSDs (for ZIL and L2ARC) will be created in
$ssdstore = "SSD"
# Size of the SSDs (in GB)
$ssdstore_size_GB = 8
# OS Install ISO - I'm using the CentOS network install ISO
$isofile = "[RAID] ISOs/CentOS-6.5-x86_64-netinstall.iso"
# Guest OS type in vSphere, this value works for RHEL/CentOS v6
$guestid = "rhel6_64Guest"
# The vSphere folder name (in the Inventory -> VMs and Templates view in vSphere) that the VM will be created in.
$location = "ZOL"

#===============================================================================

# Stops the client whining about certs
Set-PowerCLIConfiguration -InvalidCertificateAction ignore

# Edit these values to suit your environment
Connect-VIServer -server vcenter.dev.acme.com -User root -Password *******************


# Don't edit below this line
#===============================================================================

# Load our functions module
# PowerShell modules must reside in one of the paths listed in $env:PSModulePath
# By default for the current user that is: %HOMEPATH%\Documents\WindowsPowerShell\Modules
Import-Module vsphere_functions.psm1

# Create the basic VM
$VM1 = new-vm `
-Host "$VS5_Host" `
-Name $vmName1 `
-Datastore (get-datastore "$osstore") `
-Location $location `
-GuestID $guestid `
-CD `
-MemoryGB $vmRAM `
-DiskGB $osstore_size_GB `
-NetworkName "$public_network_name" `
-DiskStorageFormat "Thin" `
-Version "v8" `
-NumCpu $vm_cpu `
-Confirm:$false

# Create first HDD on HBA #2
$New_Disk1 = New-HardDisk -vm($VM1) -CapacityGB $hddstore_size_GB -StorageFormat Thin -datastore "$hddstore"
$New_SCSI_1_1 = $New_Disk1 | New-ScsiController -Type VirtualLsiLogicSAS -Confirm:$false

# Add 7 more HDDs on HBA #2
 foreach ($id in 1,2,3,4,5,6,8) {
	$New_Disk1 = New-HardDisk -vm($VM1) -CapacityGB $hddstore_size_GB -StorageFormat Thin -datastore "$hddstore"
	set-harddisk -Confirm:$false -harddisk $New_Disk1 -controller $New_SCSI_1_1
 }

# Create first SSD on HBA #3
$New_Disk1 = New-HardDisk -vm($VM1) -CapacityGB $ssdstore_size_GB -StorageFormat Thin -datastore "$ssdstore"
$New_SCSI_1_1 = $New_Disk1 | New-ScsiController -Type VirtualLsiLogicSAS -Confirm:$false

# Add one more SSD on HBA #3
$New_Disk1 = New-HardDisk -vm($VM1) -CapacityGB $ssdstore_size_GB -StorageFormat Thin -datastore "$ssdstore"
set-harddisk -Confirm:$false -harddisk $New_Disk1 -controller $New_SCSI_1_1

# Set VM to boot from BIOS on first boot so that we can disable the floppy/serial/parallel ports etc.
# Requires external modules
Get-VM $vmName1 | Set-VMBIOSSetup -PassThru

# Remove serial/parallel ports - Still needs disabling in the BIOS though...
# Requires external modules
# Get-VM $vmName1 | Get-SerialPort | Remove-SerialPort
# Get-VM $vmName1 | Get-ParallelPort | Remove-ParallelPort

# Set any additional VM params that are useful
# Based on: https://github.com/rabbitofdeath/vm-powershell/blob/master/vsphere5_hardening.ps1
$ExtraOptions = @{
	# Creates /dev/disk/by-id in Linux
	"disk.EnableUUID"="true";
	# Marks the virtual SSDs as SSD devices
	# See: http://www.virtuallyghetto.com/2013/07/emulating-ssd-virtual-disk-in-vmware.html
	"scsi2:0.virtualSSD"="1";
	"scsi2:1.virtualSSD"="1";
	# Disable virtual disk shrinking
	"isolation.tools.diskShrink.disable"="true";
	"isolation.tools.diskWiper.disable"="true";
	# 5.0 Prevent device removal-connection-modification of devices
	"isolation.tools.setOption.disable"="true";
	"isolation.device.connectable.disable"="true";
	"isolation.device.edit.disable"="true";
	# Disable copy/paste operations to/from VM
	"isolation.tools.copy.disable"="true";
	"isolation.tools.paste.disable"="true";
	"isolation.tools.dnd.disable"="false";
	"isolation.tools.setGUIOptions.enable"="false";
	# Disable VMCI
	"vmci0.unrestricted"="false";
	# Log Management
	"tools.setInfo.sizeLimit"="1048576";
	"log.keepOld"="10";
	"log.rotateSize"="100000";
	# Limit console connections - choose how many consoles are allowed
	#"RemoteDisplay.maxConnections"="1";
	"RemoteDisplay.maxConnections"="2";
	# 5.0 Disable serial port
	"serial0.present"="false";
	# 5.0 Disable parallel port
	"parallel0.present"="false";
	# 5.0 Disable USB
	"usb.present"="false";
	# Disable VIX Messaging from VM
	"isolation.tools.vixMessage.disable"="true"; # ESXi 5.x+
	"guest.command.enabled"="false"; # ESXi 4.x
	# Disable logging
	#"logging"="false";	
	# 5.0 Disable HGFS file transfers [automated VMTools Upgrade]
	"isolation.tools.hgfsServerSet.disable"="false";
	# Disable tools auto-install; must be manually initiated.
	"isolation.tools.autoInstall.disable"="false";
	# 5.0 Disable VM Monitor Control - VM not aware of hypervisor
	#"isolation.monitor.control.disable"="true";
	# 5.0 Do not send host information to guests
	"tools.guestlib.enableHostInfo"="false";
}

# Build our configspec using the hashtable from above.
$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec

# Note we have to call the GetEnumerator before we can iterate through
Foreach ($Option in $ExtraOptions.GetEnumerator()) {
    $OptionValue = New-Object VMware.Vim.optionvalue
    $OptionValue.Key = $Option.Key
    $OptionValue.Value = $Option.Value
    $vmConfigSpec.extraconfig += $OptionValue
}
# Change our VM settings
$vmview=get-vm $vmName1 | get-view
$vmview.ReconfigVM_Task($vmConfigSpec)

# Attach an OS install ISO
Get-CDDrive -VM $vmName1 | Set-CDDrive -IsoPath $isofile –StartConnected $True -confirm:$false

# Start the VM
# Start-VM $vmName1

# Eject the ISO when we are finished installing the OS
# Get-CDDrive -VM $vmName1 | Set-CDDrive -NoMedia -confirm:$false

# Stop the VM
$date = Get-Date -format "MMM-dd-yyyy"
$name = "$date - $env:USERNAME"
$desc = "Base OS only installed, no apps"
New-Snapshot -VM ZOL_CentOS -Name $name -Description $desc

