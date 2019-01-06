#!/bin/bash

set -x

# Shares
NFS_DATA=/share/home
mkdir -p $NFS_DATA
chmod 777 $NFS_DATA

BLACKLIST="/dev/sda|/dev/sdb"

scan_for_new_disks() {
    # Looks for unpartitioned disks
    declare -a RET
    DEVS=($(ls -1 /dev/sd*|egrep -v "${BLACKLIST}"|egrep -v "[0-9]$"))
    for DEV in "${DEVS[@]}";
    do
        # Check each device if there is a "1" partition.  If not,
        # "assume" it is not partitioned.
        if [ ! -b ${DEV}1 ];
        then
            RET+="${DEV} "
        fi
    done
    echo "${RET}"
}

get_disk_count() {
    DISKCOUNT=0
    for DISK in "${DISKS[@]}";
    do 
        DISKCOUNT+=1
    done;
    echo "$DISKCOUNT"
}


# Installs all required packages.
#
install_pkgs()
{
    rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    yum-config-manager --enable epel
    yum -y install epel-release
    yum -y install nfs-utils nfs-utils-lib rpcbind mdadm 
}


setup_raid()
{
	#Verify attached data disks
	ls -l /dev | grep sd
	
	DISKS=($(scan_for_new_disks))
    echo "Disks are ${DISKS[@]}"
    declare -i DISKCOUNT
    DISKCOUNT=$(get_disk_count) 
    echo "Disk count is $DISKCOUNT"
	
	#Create RAID md device
	mdadm -C /dev/md0 -l raid0 -n "$DISKCOUNT" "${DISKS[@]}"

    #Create File System
    mkfs -t xfs /dev/md0
    echo "/dev/md0 $NFS_DATA xfs rw,noatime,attr2,inode64,nobarrier,sunit=1024,swidth=4096,nofail 0 2" >> /etc/fstab
}

mount_nfs()
{

    echo "$NFS_DATA    *(rw,async)" >> /etc/exports
    systemctl enable rpcbind || echo "Already enabled"
    systemctl enable nfs-server || echo "Already enabled"
    systemctl start rpcbind || echo "Already enabled"
    systemctl start nfs-server || echo "Already enabled"
    
    exportfs
	exportfs -a
	exportfs 
}

systemctl stop firewalld
systemctl disable firewalld

# Disable SELinux
sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

install_pkgs
setup_raid
mount_nfs



# ###################################################setup PBS pro
# Set user args
MASTER_HOSTNAME=sigpmaster
QNAME=service
PBS_MANAGER=azure-user


enable_kernel_update()
{
	# enable kernel update
	sed -i.bak -e '28d' /etc/yum.conf 
	sed -i '28i#exclude=kernel*' /etc/yum.conf 

}
# Installs all required packages.
#
install_pkgs()
{
    yum -y install zlib zlib-devel bzip2 bzip2-devel bzip2-libs openssl openssl-devel openssl-libs gcc gcc-c++ nfs-utils rpcbind mdadm wget python-pip
}

# Downloads and installs PBS Pro OSS on the node.
# Starts the PBS Pro control daemon on the master node and
# the mom agent on worker nodes.
#
install_pbspro()
{
 
	yum install -y libXt-devel libXext
    wget -O /mnt/CentOS_7/pbspro-server-14.1.0-13.1.x86_64.rpm https://github.com/zhifaliu/Azure_HPC/blob/master/Compute-Grid-Infra/PBSPro/pbspro-execution-14.1.0-13.1.x86_64.rpm   


	enable_kernel_update
	install_pkgs

	yum install -y gcc make rpm-build libtool hwloc-devel libX11-devel libedit-devel libical-devel ncurses-devel perl postgresql-devel python-devel tcl-devel tk-devel swig expat-devel openssl-devel libXft autoconf automake expat libedit postgresql-server python sendmail tcl tk libical perl-Env perl-Switch
    
	# Required on 7.2 as the libical lib changed
	ln -s /usr/lib64/libical.so.1 /usr/lib64/libical.so.0

	rpm -ivh --nodeps /mnt/CentOS_7/pbspro-server-14.1.0-13.1.x86_64.rpm


        cat > /etc/pbs.conf << EOF
PBS_SERVER=$MASTER_HOSTNAME
PBS_START_SERVER=1
PBS_START_SCHED=1
PBS_START_COMM=1
PBS_START_MOM=0
PBS_EXEC=/opt/pbs
PBS_HOME=/var/spool/pbs
PBS_CORE_LIMIT=unlimited
PBS_SCP=/bin/scp
EOF
    
        /etc/init.d/pbs start
        
        # Enable job history
        /opt/pbs/bin/qmgr -c "s s job_history_enable = true"
        /opt/pbs/bin/qmgr -c "s s job_history_duration = 336:0:0"

		# change job scheduler iteration from 10 minutes to 2
        /opt/pbs/bin/qmgr -c "set server scheduler_iteration = 120"

		# add hpcuser as manager
        /opt/pbs/bin/qmgr -c "s s managers = $PBS_MANAGER@*"

		# list settings
		/opt/pbs/bin/qmgr -c 'list server'


    echo 'export PATH=/opt/pbs/bin:$PATH' >> /etc/profile.d/pbs.sh
    echo 'export PATH=/opt/pbs/sbin:$PATH' >> /etc/profile.d/pbs.sh

    cd ..
}

mkdir -p /var/local
SETUP_MARKER=/var/local/install_pbspro.marker
if [ -e "$SETUP_MARKER" ]; then
    echo "We're already configured, exiting..."
    exit 0
fi

install_pbspro

# Create marker file so we know we're configured
touch $SETUP_MARKER

exit 0
