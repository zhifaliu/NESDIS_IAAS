#!/bin/bash

MASTER_HOSTNAME=$1
MASTER_HOSTNAME=sigpmaster
QNAME=batch
PBS_MANAGER=azure-user
# Shares
SHARE_HOME=/share/home
SHARE_DATA=/share/data


# Hpc User
HPC_USER=$2
HPC_USER=hpc
HPC_UID=7007
HPC_GROUP=hpc
HPC_GID=7007


# Installs all required packages.
#
install_pkgs()
{
    yum -y install epel-release
    yum -y install nfs-utils nfs-utils-lib rpcbind
}


setup_shares()
{
    mkdir -p $SHARE_HOME
    mkdir -p $SHARE_DATA

   
        echo "$MASTER_HOSTNAME:$SHARE_HOME $SHARE_HOME    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab
        echo "$MASTER_HOSTNAME:$SHARE_DATA $SHARE_DATA    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab
        mount -a
        mount | grep "^$MASTER_HOSTNAME:$SHARE_HOME"
        mount | grep "^$MASTER_HOSTNAME:$SHARE_DATA"
        echo $MASTER_HOSTNAME >>/share/data/install.txt
}

# Adds a common HPC user to the node and configures public key SSh auth.
# The HPC user has a shared home directory (NFS share on master) and access
# to the data share.
#
setup_hpc_user()
{
    # disable selinux
    sed -i 's/enforcing/disabled/g' /etc/selinux/config
    setenforce permissive
    
    groupadd -g $HPC_GID $HPC_GROUP

    # Don't require password for HPC user sudo
    echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    
    # Disable tty requirement for sudo
    sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

    
    useradd -c "HPC User" -g $HPC_GROUP -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER
    
}

# Sets all common environment variables and system parameters.
#
setup_env()
{
    # Set unlimited mem lock
    echo "$HPC_USER hard memlock unlimited" >> /etc/security/limits.conf
    echo "$HPC_USER soft memlock unlimited" >> /etc/security/limits.conf

    # Intel MPI config for IB
    echo "# IB Config for MPI" > /etc/profile.d/hpc.sh
    echo "export I_MPI_FABRICS=shm:dapl" >> /etc/profile.d/hpc.sh
    echo "export I_MPI_DAPL_PROVIDER=ofa-v2-ib0" >> /etc/profile.d/hpc.sh
    echo "export I_MPI_DYNAMIC_CONNECTION=0" >> /etc/profile.d/hpc.sh
}


install_pkgs
setup_shares
setup_hpc_user
setup_env

##############################################
is_master()
{
    hostname | grep "$MASTER_HOSTNAME"
    return $?
}

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
    yum -y install epel-release
    yum -y install zlib zlib-devel bzip2 bzip2-devel bzip2-libs openssl openssl-devel openssl-libs gcc gcc-c++ nfs-utils rpcbind mdadm wget python-pip R
}

# Downloads and installs PBS Pro OSS on the node.
# Starts the PBS Pro control daemon on the master node and
# the mom agent on worker nodes.
#
install_pbspro()
{
 
	yum install -y libXt-devel libXext


    #wget -O /mnt/CentOS_7.zip  http://wpc.23a7.iotacdn.net/8023A7/origin2/rl/PBS-Open/CentOS_7.zip
    #unzip /mnt/CentOS_7.zip -d /mnt
	 wget -O /tmp/pbspro-server-14.1.0-13.1.x86_64.rpm https://s3.amazonaws.com/admin-sig-codebase/PBSPRO/pbspro-server-14.1.0-13.1.x86_64.rpm   
       
    if is_master; then

		enable_kernel_update
		install_pkgs

		yum install -y gcc make rpm-build libtool hwloc-devel libX11-devel libedit-devel libical-devel compat-libical1 ncurses-devel perl postgresql-devel python-devel tcl-devel tk-devel swig expat-devel openssl-devel libXft autoconf automake expat libedit postgresql-server python sendmail tcl tk libical perl-Env perl-Switch
    
		# Required on 7.2 as the libical lib changed
		ln -s /usr/lib64/libical.so.1 /usr/lib64/libical.so.0

	    rpm -ivh --nodeps /tmp/pbspro-server-14.1.0-13.1.x86_64.rpm


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
        /opt/pbs/bin/qmgr -c "set server managers = $PBS_MANAGER@*"

		# list settings
		/opt/pbs/bin/qmgr -c 'list server'
    else


		yum install -y hwloc-devel expat-devel tcl-devel expat

	    wget -O /tmp/pbspro-execution-14.1.0-13.1.x86_64.rpm https://s3.amazonaws.com/admin-sig-codebase/PBSPRO/pbspro-execution-14.1.0-13.1.x86_64.rpm
	    rpm -ivh --nodeps /tmp/pbspro-execution-14.1.0-13.1.x86_64.rpm

        cat > /etc/pbs.conf << EOF
PBS_SERVER=$MASTER_HOSTNAME
PBS_START_SERVER=0
PBS_START_SCHED=0
PBS_START_COMM=0
PBS_START_MOM=1
PBS_EXEC=/opt/pbs
PBS_HOME=/var/spool/pbs
PBS_CORE_LIMIT=unlimited
PBS_SCP=/bin/scp
EOF

		echo '$clienthost '$MASTER_HOSTNAME > /var/spool/pbs/mom_priv/config
        /etc/init.d/pbs start

		# setup the self register script
		wget -O /tmp/pbs_selfregister.sh https://raw.githubusercontent.com/zhifaliu/NESDIS_IAAS/master/pbs_selfregister.sh
		cp /tmp/pbs_selfregister.sh /etc/init.d/pbs_selfregister
		chmod +x /etc/init.d/pbs_selfregister
		chown root /etc/init.d/pbs_selfregister
		chkconfig --add pbs_selfregister

		# if queue name is set update the self register script
		if [ -n "$QNAME" ]; then
			sed -i '/qname=/ s/=.*/='$QNAME'/' /etc/init.d/pbs_selfregister
		fi

		# register node
		/etc/init.d/pbs_selfregister start

    fi

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

