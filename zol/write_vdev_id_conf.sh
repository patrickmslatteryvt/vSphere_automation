# Write out a simple /etc/zfs/vdev_id.conf file based on the disks we have attached in our VM using Solaris style aliases
# Please note that this script assumes a lot of things and SHOULD NEVER BE USED IN A PRODUCTION ENVIRONMENT!!!

TMP_DISKS=$(mktemp) || { echo "Failed to create temp file"; exit 1; }
# Create a header
echo "#     by-vdev">/etc/zfs/vdev_id.conf
echo "#     name     fully qualified or base name of device link">>/etc/zfs/vdev_id.conf

# Sort our disks on SCSI Controller #1 (HDDs) into the temp file
ls -la /dev/disk/by-path/|grep "pci-0000:0b"|awk '{print $9,$11}'|sed "s@../..@@g"|sort -k 2,2|awk '{print $1}'>${TMP_DISKS}
file=${TMP_DISKS}
t=0
while IFS= read -r line
do
  printf "alias c1t">>/etc/zfs/vdev_id.conf
  printf $t>>/etc/zfs/vdev_id.conf
  printf "d0 /dev/disk/by-path/">>/etc/zfs/vdev_id.conf
  printf "$line\n">>/etc/zfs/vdev_id.conf
  t=$[$t +1]
  # SCSI ID #7 is the HBA
  if test $t -eq 7
  then
      t=$[$t +1]
  fi
done <"$file"

# Sort our disks on SCSI Controller #2 (SSDs) into the temp file
ls -la /dev/disk/by-path/|grep "pci-0000:13"|awk '{print $9,$11}'|sed "s@../..@@g"|sort -k 2,2|awk '{print $1}'>${TMP_DISKS}
file=${TMP_DISKS}
t=0
while IFS= read -r line
do
  printf "alias c2t">>/etc/zfs/vdev_id.conf
  printf $t>>/etc/zfs/vdev_id.conf
  printf "d0 /dev/disk/by-path/">>/etc/zfs/vdev_id.conf
  printf "$line\n">>/etc/zfs/vdev_id.conf
  t=$[$t +1]
  # SCSI ID #7 is the HBA
  if test $t -eq 7
  then
      t=$[$t +1]
  fi
done <"$file"

# Delete temp file
rm -f ${TMP_LIST}

# Display our file
cat /etc/zfs/vdev_id.conf
