#!/bin/sh
# Update kernel and rootfs of iCS on Apalis iMX6 module
# by exchanging one of the redundant uImage, device tree and rootfs
# or reset user data to factory reset

# global pathes need while running subfunctions
CONFIG_XML_PATH="/mnt/user/data/config"
CONFIG_BAK_PATH="/opt/ics/backup"
USER_CONFIG_PATH="/mnt/user/data/config/"

Usage()
{
	echo ""
	echo "Update kernel and rootfs of iCS on Apalis iMX6 module"
	echo ""
	echo "Will require a running Linux on the target!"
	echo ""
	echo "-f             : filename of update zip package"
	echo "[-p]           : filepath of zip package, default is " "${ZIP_FILE_PATH}"
	echo "[-h]           : prints this message"
	echo "[-r]           : reset user data to factory reset"
	echo "[-R]           : reset user data to factory reset and configure connected devices"
	echo "[-g <serial>]  : get device_type through iseg serial number"
	echo "[-G]           : get the default device_type"
	echo "[-s <type>]    : set device configuration based on device type"
	echo "[-S]	       : filename of signature of update zip package"
	echo ""
	echo "Example \"./icsupdate.sh -f isegUpdate_20160104_system_iCS.zip\" "
	echo ""
}

FactoryReset()
{
	echo "Factory reset: copy backup data..."
	cp -prf /opt/ics/backup/*.xml $USER_CONFIG_PATH
	cp -prf /opt/epics/linux-arm/db/iseg_epics*.db $USER_CONFIG_PATH

	if [ "$1" = "full" ] ; then
		php /www/pages/iCSweb2/iCStool.php -c autoconfig
		php /www/pages/iCSweb2/iCStool.php -c generateEpicsConfig
		php /www/pages/iCSweb2/iCStool.php -c generateSnmpConfig
	fi
	echo "Factory reset: copy backup data finished."
}

CheckFile()
{
	echo "Update: going to test" "${ZIP_FILE_PATH}${ZIP_FILE}..."
	${UNZIP} -P ${PASSWD} -tq ${ZIP_FILE_PATH}${ZIP_FILE}
	RESULT=$?
	# Successfully tested?
	if [ "$RESULT" -gt 0 ] ; then
		echo >&2 "Update ERROR: File Test failed."; exit 1
	fi
}

GetPassword()
{
	echo "Update: going to analyse file name"
	TYPE=`echo $ZIP_FILE | ${AWK} -F_ '{ print $3 }'`
	DATE=`echo $ZIP_FILE | ${AWK} -F_ '{ print $2 }'`
	#type has to be "system"
	[ "${TYPE}" = "system" ] || { echo >&2 "Update ERROR: file name not valid. Type is $TYPE"; exit 1; }
	SUM=`echo $DATE | ${AWK} '	{
		n=split($1,array,"");
		sum=0;
		for (i=1;i<=n;i++) {
			sum+=array[i];
			#printf("Zahl[%d]=%d\n",i,array[i]);
		}
		printf("%d",sum);
	}'`
	PASSWD=`echo ${TYPE}${SUM}`
}

# versionGreaterEqual newVersion oldVersion
# exit with 0 if newVersion is greater or equal oldVersion
versionGreaterEqual()
{
	local newVersion=$1
	local oldVersion=$2

	while :
	do
		local newDigit=${newVersion%%.*}
		local oldDigit=${oldVersion%%.*}

		if [ ${newDigit} -gt ${oldDigit} ] ; then
			return 0 # true
		elif [ ${newDigit} -lt ${oldDigit} ] ; then
			return 1 # false
		fi

		local nextNewPart=${newVersion#*.}
		if [ $nextNewPart == $newVersion ]; then
			# no more parts, set to 0
			nextNewPart=0
		fi

		local nextOldPart=${oldVersion#*.}
		if [ $nextOldPart == $oldVersion ]; then
			# no more parts, set to 0
			nextOldPart=0
		fi

		if [ $nextNewPart == $nextOldPart ]; then
			return 0 # true
		fi

		newVersion=$nextNewPart
		oldVersion=$nextOldPart
	done
}

## boardRevisionBefore firstRev secondRev
## exit with 0 if firstRev is before secondRev
## revisions: 011a .. 011d
boardRevisionBefore()
{
	local firstRev=$1
	local secondRev=$2

	if [[ ${firstRev} < ${secondRev} ]] ; then
		return 0 # true
	else
		return 1 # false
	fi
}

GetDefaultDeviceType()
{
	echo "cc24-2"
}

GetDeviceType()
{
	if [[ $1 =~ ^23[0-9]+ ]] ; then
		echo "shr-1"
	elif [[ $1 =~ ^526[0-9]+ ]] ; then
		if [[ $1 < 5260020 ]]; then
			echo "mini-1"
		else
			echo "mini-2"
		fi
	else
		echo "cc24-2"
	fi
}

AddNodesToIcsConfigXml()
{
	local -r CONFIG_XML_PATH_LOCAL=$1
	local -r CONFIG_XML="icsConfig.xml"
	local -r ENTRY=icsConfig
	local -r XML=xml

	local -r NODE_AUTOCONFIG=autoConfig
	local -r VALUE=true
	local -r HAS_AUTOCONFIG=`${XML} sel -t -v "count(${ENTRY}/${NODE_AUTOCONFIG})" "${CONFIG_XML_PATH_LOCAL}/${CONFIG_XML}"`
	if [ ${HAS_AUTOCONFIG} -eq 0 ] ; then
		echo "${CONFIG_XML}: Setting node '${ENTRY}/${NODE_AUTOCONFIG}' to '${VALUE}'..."
		${XML} ed --inplace -s "${ENTRY}" -t elem -n "${NODE_AUTOCONFIG}" -s "${ENTRY}"/"${NODE_AUTOCONFIG}" \
			-t elem -n enable -v "${VALUE}" "${CONFIG_XML_PATH_LOCAL}/${CONFIG_XML}"
	fi

	local -r NODE_SCRIPTS=scripts
	local -r HAS_SCRIPTS=`${XML} sel -t -v "count(${ENTRY}/${NODE_SCRIPTS})" "${CONFIG_XML_PATH_LOCAL}/${CONFIG_XML}"`
	if [ ${HAS_SCRIPTS} -eq 0 ] ; then
		echo "${CONFIG_XML}: Creating node '${ENTRY}/${NODE_SCRIPTS}'..."
		${XML} ed --inplace -s "${ENTRY}" -t elem -n "${NODE_SCRIPTS}" "${CONFIG_XML_PATH_LOCAL}/${CONFIG_XML}"
	fi

	local -r NODE_SCPI=scpi
	local -r SUBNODE1_SCPI=enable
	local -r SUBNODE2_SCPI=suppressEmptyAnswer
	local -r SUBNODE3_SCPI=user
	local -r SUBNODE4_SCPI=password
	local -r HAS_SCPI=`${XML} sel -t -v "count(${ENTRY}/${NODE_SCPI})" "${CONFIG_XML_PATH_LOCAL}/${CONFIG_XML}"`
	if [ ${HAS_SCPI} -eq 0 ] ; then
		echo "${CONFIG_XML}: Creating node '${ENTRY}/${NODE_SCPI}' ..."
		${XML} ed --inplace -s "${ENTRY}" -t elem -n "${NODE_SCPI}" \
		       	-s "${ENTRY}"/"${NODE_SCPI}" -t elem -n "${SUBNODE1_SCPI}" -v "true" \
			-s "${ENTRY}"/"${NODE_SCPI}" -t elem -n "${SUBNODE2_SCPI}" -v "false" \
			-s "${ENTRY}"/"${NODE_SCPI}" -t elem -n "${SUBNODE3_SCPI}" \
			-s "${ENTRY}"/"${NODE_SCPI}" -t elem -n "${SUBNODE4_SCPI}" \
			"${CONFIG_XML_PATH_LOCAL}/${CONFIG_XML}"
	fi
}

SetConfiguration()
{
	local -r SYSTEMD_DIR="$1/lib/systemd/system/"
	local -r OPT_DIR="$1/opt/ics/"
	local -r CONFIG_BAK="/opt/ics/backup/icsConfig.xml"
	local -r CONFIG_BAK_NEW="$1/opt/ics/backup/icsConfig.xml"
	local -r CONFIG_BAK_NEW_PATH="$1/opt/ics/backup"
	local -r SNMPD_CONF="$1/usr/share/snmp/snmpd.conf"
	local -r AVAHI_DAEMON_CONF="$1/etc/avahi/avahi-daemon.conf"
	local -r HOST_NAME_CONF="$1/etc/hostname"
	local -r TIME_SYS_CONF_DIR="$1/etc/systemd"
	local -r ISEG_SN="$2"
	local -r DEVICE_TYPE=`GetDeviceType ${ISEG_SN}`

	# The variable content is patched during the image build process.
	IMAGE_VERSION="2.10.0B2"
	ISEGHAL_VERSION="1.7.2"
	ISEGSNMP_VERSION="2.2.2"

	if [ "${DEVICE_TYPE}" = "shr-1" ] ; then
		ICS_MODE="display"
		BIT_RATE="250"
		echo "Setting up shrcontrol systemd services for SHR"
		${SYSTEMCTL} --root=$1 enable shrcontrol.service

		rm ${TIME_SYS_CONF_DIR}/timesyncd.conf
		${SYSTEMCTL} --root=$1 disable systemd-timesyncd.service

		timedatectl set-ntp false \
			&& echo "NTP set to False" \
			|| { echo "ERROR: Could not set NTP to False"; exit 1; }
	elif [[ ${DEVICE_TYPE} =~ ^mini-[1-2] ]] ; then
		ICS_MODE="icsmini"
		BIT_RATE="250"
	else
		ICS_MODE="crate"
		BIT_RATE="1000"
	fi

	#set device type to u-boot environment
	${FWSETENV} device_type ${DEVICE_TYPE} \
		&& echo "Setting U-Boot device_type to ${DEVICE_TYPE} successful." \
		|| { echo -e >&2 "\033[1m\033[31mERROR: Could not set U-Boot device_type to ${DEVICE_TYPE}!\033[0m"; exit 1; }

	${FWSETENV} iseg_bitrate_can ${BIT_RATE} \
		&& echo "Setting CAN bitrate to ${BIT_RATE} successful!" \
		|| echo "ERROR: Could not set CAN bitrate to ${BIT_RATE}"

	if [ "/" = "$1" ] ; then
		# This if condition is to set configuration in icsConfig.xml file
		# when finish_initial_startup.sh is executed
		${SED} -ri "s/<iCSmode>.*<\/iCSmode>/<iCSmode>${ICS_MODE}<\/iCSmode>/" ${CONFIG_BAK} \
			&& echo "iCSmode set to ${ICS_MODE} in ${CONFIG_BAK}" \
			|| { echo "ERROR: Could not set iCSmode in ${CONFIG_BAK}!"; exit 1; }

		${SED} -ri "s/<bitrate line=\"0\">.*<\/bitrate>/<bitrate line=\"0\">${BIT_RATE}<\/bitrate>/" ${CONFIG_BAK} \
			&& echo "can0 bitrate set to ${BIT_RATE} in ${CONFIG_BAK}" \
			|| { echo "ERROR: Could not set can0 bitrate in ${CONFIG_BAK}!"; exit 1; }

		${SED} -ri "s/<bitrate line=\"1\">.*<\/bitrate>/<bitrate line=\"1\">${BIT_RATE}<\/bitrate>/" ${CONFIG_BAK} \
			&& echo "can1 bitrate set to ${BIT_RATE} in ${CONFIG_BAK}" \
			|| { echo "ERROR: Could not set can1 bitrate in ${CONFIG_BAK}!"; exit 1; }

		# Add iseg serial number to WiFi SSID in icsConfig.xml
		SSID=iseg-iCS2-${ISEG_SN}
		${SED} -ri "s/<ssid>.*<\/ssid>/<ssid>${SSID}<\/ssid>/" ${CONFIG_BAK} \
		&& echo "WiFi SSID set to ${SSID} in ${CONFIG_BAK}" \
		|| { echo "ERROR: Could not set WiFi SSID in ${CONFIG_BAK}!"; exit 1; }

		# create backup of icsConfig.xml
		cp -prf ${CONFIG_BAK} ${CONFIG_XML_PATH} \
			&& echo "${CONFIG_BAK} copied to ${CONFIG_XML_PATH}" \
			|| { echo "ERROR: Could not copy ${CONFIG_BAK} to ${CONFIG_XML_PATH}!"; exit 1; }

	else
		# This else condition Copies backup of icsConfig.xml from old partition
		# to new partition
		cp -prf ${CONFIG_BAK} ${CONFIG_BAK_NEW} \
			&& echo "${CONFIG_BAK} copied to new partition ${CONFIG_BAK_NEW}" \
			|| { echo "ERROR: Could not copy ${CONFIG_BAK} to new partition ${CONFIG_BAK_NEW}!"; exit 1; }
		AddNodesToIcsConfigXml ${CONFIG_BAK_NEW_PATH}
		# Create directory for samba privates
		mkdir -p /mnt/user/data/samba/private
	fi

	# Add iseg serial number to Avahi (Zeroconf/Bonjour) host name
	AVAHI_HOST_NAME=iseg-iCS2-${ISEG_SN}
	${SED} -ri "s/.?host-name.*/host-name=${AVAHI_HOST_NAME}/" ${AVAHI_DAEMON_CONF} \
		&& echo "Avahi host name set to ${AVAHI_HOST_NAME} in ${AVAHI_DAEMON_CONF}" \
		|| { echo "ERROR: Could not set host name in ${AVAHI_DAEMON_CONF}!"; exit 1; }

	# Add iseg serial number to snmpd.conf
	SYS_DESCR="sysDescr    iseg iCS (${ISEG_SN}, iCS ${IMAGE_VERSION}, isegHAL ${ISEGHAL_VERSION}, isegSNMP ${ISEGSNMP_VERSION})"
	if ${GREP} -q '^sysDescr' ${SNMPD_CONF} ; then
		${SED} -ri "s/sysDescr.*/${SYS_DESCR}/" ${SNMPD_CONF}
	else
		echo ${SYS_DESCR} >> ${SNMPD_CONF}
	fi
	[ $? ] && echo "SNMP sysDescr number set to ${ISEG_SN} in ${SNMPD_CONF}" \
	|| { echo "ERROR: Could not set SNMP sysDescr number in ${SNMPD_CONF}!"; exit 1; }

	echo ${AVAHI_HOST_NAME} > ${HOST_NAME_CONF} \
		&& echo "Host Name set to ${AVAHI_HOST_NAME} in ${HOST_NAME_CONF}" \
		|| { echo "ERROR: Could not set Host Name in ${HOST_NAME_CONF}!"; exit 1; }
}

CreateNewRootPartition()
{
	START=$1
	END=$2
	# Find unused rootfs partiton and delete, because partitiontable supports only 4 primary partitons.
	if [ "$NEWSYSNR" -eq 1 ] ; then
		ROOTFS_UNUSED=${ROOTFS1}
	elif [ "$NEWSYSNR" -eq 2 ] ; then
		ROOTFS_UNUSED=${ROOTFS2}
	else
		echo >&2 "Update ERROR: mmmh, something spooky is going on..."
		exit 1;
	fi
	${PARTED} ${MMCDEV} rm ${ROOTFS_UNUSED}

	# create new rootfs
	${PARTED} ${MMCDEV} mkpart primary ext3 ${START} ${END} -a none
}

# Create new partition scheme. Used for isegConsoleImage 2.6.0 and newer.
# Image 2.5.0 is required because it provides the tools for the first time.
RePartitioningStage0()
{
	echo "checking free memory in userfs"
	USERFS_FREE=`${DF} -m ${USERFS_PATH} | ${GREP} "${MMCDEV}p${USERFS}" | ${AWK} -F"[ ]+" '{print $4}'`
	if [ ${USERFS_FREE} -le ${ROOTFS_SIZE_NEW_MB} ]; then
		echo "There is not enough free space under ${USERFS_PATH}. Please delete unnecessary data e.g. old update files."
		echo "At least ${ROOTFS_SIZE_NEW_MB}MB must be free. The update will now be canceled."
		exit 1;
	fi

	echo "generating daemon to resize userpartition"
	echo "Please wait at least 20 seconds then reload the website and restart the update."

	DEVICETYPE=`${FWPRINTENV} -n device_type`
	ICSSERVICESRESTART="iseghal.socket iseghal.service icsservice.service lighttpd.service"
	if [ "${DEVICETYPE}" = "shr-1" ] ; then
		ICSSERVICESRESTART="${ICSSERVICESRESTART} shrcontrol.service"
	fi
	ICSSERVICES="icswatch.service isegremote.service iseghttp.service \
		 caRepeater.service isegioc.service isegscpi.service \
		 isegsnmp.service tty2snmp.service webcam.service"

	#print to file and run as systemd daemon
	mount -o remount,rw /
	REPART_FILE="/usr/bin/repart.sh"
	tee ${REPART_FILE} <<-EOF >/dev/null
	#!/bin/bash

	# shutdown ics-services
	${SYSTEMCTL} stop ${ICSSERVICESRESTART} ${ICSSERVICES}
	while (${SYSTEMCTL} -q is-active ${ICSSERVICESRESTART} ${ICSSERVICES}); do
		echo "Waiting for stopping services..."
		sleep 1
	done

	echo "Trying to resize filesystem on userfs to minimum..."
	RESIZEDONE=0
	RESIZEITERATIONS=0

	while [ \${RESIZEDONE} -ne 1 ] && [ \${RESIZEITERATIONS} -lt 3 ]; do
		((RESIZEITERATIONS++))
		${SYNC}
		${UMOUNT} -f -v ${USERFS_PATH}
		RET=\$?
		if [[ \${RET} -ne 0 ]]; then
			echo "Umount of userfs failed! Errorcode: \${RET}"
			lsof | ${GREP} ${USERFS_PATH}
			exit 1;
		else
			echo "The userfs was successfully unmounted."
		fi

		${E2FSCK} -f -y ${MMCDEV}p${USERFS}
		${RESIZE2FS} -M ${MMCDEV}p${USERFS} \
			&& { RESIZEDONE=1; } \
			|| { ${MOUNT} ${USERFS_PATH}; sleep 1; }
	done

	if [ \${RESIZEDONE} -ne 1 ]; then
		echo "Resize filesystem on userfs failed! Stop now."
		exit 1
	else
		echo "Resize filesystem on userfs to minimum completed. (on \${RESIZEITERATIONS}. try)"
	fi

	# shrink userfs to new size (=oldsize - 1048MB)
	## ---pretend-input-tty forces parted to accept input from the script.
	## Function is undocumented but necessary.
	${PARTED} ${MMCDEV} ---pretend-input-tty resizepart <<-FOE \
		&& echo "User partition is shrinked to new size." \
		|| { echo "Shrink user partition failed!"; exit 1; }
	${USERFS}
	-${ROOTFS_SIZE_NEW_MB}
	Yes
	FOE

	${E2FSCK} -f -y ${MMCDEV}p${USERFS}
	${RESIZE2FS} ${MMCDEV}p${USERFS} \
		&& echo "Resize filesystem on userfs to new partition size. Done." \
		|| { echo "Resize filesystem on userfs failed!"; exit 1; }
	${MOUNT} ${USERFS_PATH}

	# restart ics-service
	${SYSTEMCTL} start ${ICSSERVICESRESTART}
	EOF

	chmod u+x ${REPART_FILE}

	#generate systemd service-file
	REPART_SERVICE_FILE=isegrepart.service
	REPART_SERVICE=/lib/systemd/system/${REPART_SERVICE_FILE}
	tee ${REPART_SERVICE} <<-EOF >/dev/null
	[Unit]
	Description=iseg repartition daemon

	[Service]
	Type=oneshot
	ExecStart=${REPART_FILE}

	[Install]
	WantedBy=multi-user.target
	EOF

	systemctl daemon-reload
	systemctl start ${REPART_SERVICE_FILE}

	#endless loop, ics-server is stopped by systemd, script will crash
	x=1
	while true
	do
		if [ $x -ne 0 ]; then
			echo "Daemon is started, reload in 20 seconds."
			((x--))
		fi
	done
}

# Create the first rootfs with 1048MB.
# Let the other one for fall back, manipulate with the next update in stage2.
RePartitioningStage1()
{
	FREE_SPACE_START=`${PARTED} ${MMCDEV} print free -s | ${GREP} "Free Space" | ${TAIL} -n1 | ${AWK}  -F"[ ]+" '{print $2}' | ${GREP} "MB" | ${AWK}  -F"[MB]" '{print $1}'`
	FREE_SPACE_END=`${PARTED} ${MMCDEV} print free -s | ${GREP} "Free Space" | ${TAIL} -n1 | ${AWK}  -F"[ ]+" '{print $3}' | ${GREP} "MB" | ${AWK}  -F"[MB]" '{print $1}'`
	CreateNewRootPartition ${FREE_SPACE_START} ${FREE_SPACE_END}
}

# Repartition the second rootfs, which was used while the first stage.
RePartitioningStage2()
{
	KERNELFS_END=`${PARTED} ${MMCDEV} print free -s | ${GREP} "${KERNELFS}  " | ${AWK} -F"[ ]+" '{print $4}' | ${AWK} -F"MB" '{print $1}'`
	USERFS_START=`${PARTED} ${MMCDEV} print free -s | ${GREP} "${USERFS}  " | ${AWK} -F"[ ]+" '{print $3}' | ${AWK} -F"MB" '{print $1}'`
	CreateNewRootPartition ${KERNELFS_END} ${USERFS_START}
}

# Recognize the existing partition scheme.
CheckPartitioning()
{
	ROOTFS_PATH_NEW=$1
	MMCDEV="/dev/mmcblk0"
	KERNELFS=1
	ROOTFS1=2
	ROOTFS2=3
	USERFS=4

	PARTSTAGES_DONE=3
	ROOTFS_SIZE_NEW_MB=1048

	# calculation with 1000 and 1024, subtract some buffer resulted in 900
	ROOTFS_SIZE_NEW_B=$((${ROOTFS_SIZE_NEW_MB} * 900))
	echo "ROOTFS_MIN_S: ${ROOTFS_SIZE_NEW_B}B"
	ROOTFS1_SIZE_B=`${SFDISK} -n -q -s --byte ${MMCDEV}p${ROOTFS1}`
	if [ -z ${ROOTFS1_SIZE_B} ]; then
		ROOTFS1_SIZE_B=0
	fi
	echo "ROOTFS1_SIZE: ${ROOTFS1_SIZE_B}B"
	ROOTFS2_SIZE_B=`${SFDISK} -n -q -s --byte ${MMCDEV}p${ROOTFS2}`
	if [ -z ${ROOTFS2_SIZE_B} ]; then
		ROOTFS2_SIZE_B=0
	fi
	echo "ROOTFS2_SIZE: ${ROOTFS2_SIZE_B}B"
	FREE_SPACE_MB=`${PARTED} ${MMCDEV} print free -s | ${GREP} "Free Space" | ${TAIL} -n1 | ${AWK}  -F"[ ]+" '{print $4}' | ${GREP} "MB" | ${AWK}  -F"[MB]" '{print $1}'`
	if [ -z ${FREE_SPACE_MB} ]; then
		FREE_SPACE_MB=0
	fi
	echo "FREE_SPACE  : ${FREE_SPACE_MB}MB"

	if [ ${ROOTFS1_SIZE_B} -lt ${ROOTFS_SIZE_NEW_B} ] || [ ${ROOTFS2_SIZE_B} -lt ${ROOTFS_SIZE_NEW_B} ]; then
		((PARTSTAGES_DONE=2))
		if [ ${ROOTFS1_SIZE_B} -lt ${ROOTFS_SIZE_NEW_B} ] && [ ${ROOTFS2_SIZE_B} -lt ${ROOTFS_SIZE_NEW_B} ]; then
			((PARTSTAGES_DONE=1))
			if [ ${FREE_SPACE_MB} -lt ${ROOTFS_SIZE_NEW_MB} ]; then
				((PARTSTAGES_DONE=0))
			fi
		fi
	fi

	case ${PARTSTAGES_DONE} in
		0)
			echo "Checking userfs and adjusting it..."
			echo "Don't turn off or reboot!"
			RePartitioningStage0
			;;
		1)
			echo "Both root partition have the old scheme, adjusting the first one..."
			RePartitioningStage1 ${ROOTFS_PATH_NEW}
			;;
		2)
			echo "One root partition has already been adjusted by a previous update, adjusting the second one..."
			RePartitioningStage2
			;;
		*)
			echo "Partition scheme is already adjusted, nothing to do."
			;;
	esac
}

CopyDataToUserPartition()
{
	local -r ROOTFS=$1
	#isegioc, only copy if not existing
	if [ ! -e ${USER_CONFIG_PATH}/iseg_epics_crate.db ] ; then
		cp -prf ${ROOTFS}/opt/epics/linux-arm/db/iseg_epics_crate.db ${USER_CONFIG_PATH}
	fi
	if [ ! -e ${USER_CONFIG_PATH}/iseg_epics_module.db ] ; then
		cp -prf ${ROOTFS}/opt/epics/linux-arm/db/iseg_epics_module.db ${USER_CONFIG_PATH}
	fi
	if [ ! -e ${USER_CONFIG_PATH}/iseg_epics_system.db ] ; then
		cp -prf ${ROOTFS}/opt/epics/linux-arm/db/iseg_epics_system.db ${USER_CONFIG_PATH}
	fi
}

## This function writes the root file system to the new partition,
## and then sets the device type (cc24, mini2, SHR) and
## the device configuration such as serial number in
## (WiFi SSID, hostname, snmpd.conf) bitrate, ICSMODE, and
## also enables and disables systemd services
UpdateSystem()
{
	local -r ROOTFS=$1

	if [ ${PARTITION_PROFILE} -eq 2 ]; then
		echo "Update: check partition style..."
		CheckPartitioning ${ROOTFS}
	fi

	echo "Update: going to write filesystem..."
	${UNZIP} -oP ${PASSWD} -p ${ZIP_FILE_PATH}${ZIP_FILE} ${ROOT_FILE} | \
		dd of=${ROOTFS} || FAILURE=1

	ROOT_MOUNT="/tmp/icsupdate"
	mkdir ${ROOT_MOUNT}
	mount ${ROOTFS} ${ROOT_MOUNT}

	# Set device configuration
	SetConfiguration ${ROOT_MOUNT} ${ISEG_SN}
	# Add new nodes to configuration
	AddNodesToIcsConfigXml ${CONFIG_XML_PATH}
	CopyDataToUserPartition ${ROOT_MOUNT}

	umount ${ROOT_MOUNT}


	# resize rootfs to maximum filesystemsize
	# check if resize2fs is available, skip if not
	if [[ -n "${RESIZE2FS}" ]] ; then
		# e2fsck was requested in a test run, also use it
		if [[ -n "${E2FSCK}" ]] ; then
			${E2FSCK} -f -y ${ROOTFS}
		else
			echo >&2 "Program e2fsck is not available. Skipping file system check.";
		fi
		echo "resize new rootfs to maximum partition size"
		${RESIZE2FS} ${ROOTFS}
		if [[ -n "${E2FSCK}" ]] ; then
			${E2FSCK} -f -y ${ROOTFS}
		fi
	else
		echo >&2 "Program resize2fs is not available. Skip resizing of rootfs.";
	fi

}

# check the availability of required programs, cancel Update if necessary ##
source /etc/profile.d/fw_unlock_mmc.sh
FWSETENV=`command -v fw_setenv` || { echo >&2 "Update ERROR: Program fw_setenv not available.  Aborting."; exit 1; }
FWPRINTENV=`command -v fw_printenv` || { echo >&2 "Update ERROR: Program fw_printenv not available.  Aborting."; exit 1; }
RESIZE2FS=`command -v resize2fs` || { echo >&2 "Update WARNING: Program resize2fs is not available. Skip resizing of rootfs."; }
E2FSCK=`command -v e2fsck` || { echo >&2 "Update WARNING: Program e2fsck is not available. Skip file system check."; }
SYSTEMCTL=`command -v systemctl` || { echo >&2 "Update ERROR: Program systemctl is not available."; exit 1; }
GREP=`command -v grep` || { echo >&2 "Update ERROR: Program grep not available.  Aborting."; exit 1; }
SED=`command -v sed` || { echo >&2 "Update ERROR: Program sed not available.  Aborting."; exit 1; }
GPG=`command -v gpg` || { echo >&2 "Update ERROR: Program gpg not available.  Aborting."; exit 1; }

# START

ZIP_FILE_PATH="/mnt/user/data/updates/"
ZIP_FILE=""
GPG_SIG_FILE=""
C_SIG_FILE=""
C_VERIFY_FILE="verify_file_arm"
IS_VALID_SIGNATURE=""
while getopts "nrRhf:p:g:Gs:S:C:" Option ; do
	case $Option in
		n)	NO_RECURSE=1
			;;
		r) 	FactoryReset
			exit 0
			;;
		R) 	FactoryReset full
			exit 0
			;;
		h) 	Usage
			# Exit if only usage (-h) was specfied.
			if [ "$#" -eq 1 ] ; then
				exit 10
			fi
			exit 0
			;;
		f)	ZIP_FILE=$OPTARG
			;;
		p)	ZIP_FILE_PATH=$OPTARG
			;;
		g)	ISEG_SERIAL=$OPTARG
			GetDeviceType ${ISEG_SERIAL}
			exit 0
			;;
		G)	GetDefaultDeviceType
			exit 0
			;;
		s)	SET_CONFIGURATION=$OPTARG
			SetConfiguration "/" ${SET_CONFIGURATION}
			exit 0
			;;
		S)	GPG_SIG_FILE=$OPTARG
			;;
		C)	C_SIG_FILE=$OPTARG
			;;
	esac
done

if [ "$ZIP_FILE" = "" ] ; then
	Usage
	exit 0
fi

# is ZIP_FILE an existing file?
if [ ! -r "${ZIP_FILE_PATH}${ZIP_FILE}" ] ; then
	echo >&2 "Update ERROR: ${ZIP_FILE_PATH}${ZIP_FILE} does not exist or cannot be read, exiting"
	exit 1
fi

# is ZIP_FILE a signed GPG file (non detached signature)
if [ "${ZIP_FILE: -4}" == ".gpg" ] ; then

	echo "checking signature..."
	${GPG} --yes --output "${ZIP_FILE_PATH}${ZIP_FILE%.gpg}" --decrypt "${ZIP_FILE_PATH}${ZIP_FILE}" 2>/dev/null
	IS_VALID_SIGNATURE=$?

	if [ $IS_VALID_SIGNATURE -eq 1 ] ; then
		echo "incorrect GPG signature, check the signature file name for errors: ${ZIP_FILE_PATH}${ZIP_FILE}"
		exit 1
	elif [ $IS_VALID_SIGNATURE -eq 2 ] ; then
        	echo "invalid GPG signature, check the signature file name for errors: ${ZIP_FILE_PATH}${ZIP_FILE}"
        	exit 1
    	else
    		ZIP_FILE=${ZIP_FILE%.gpg}
    		echo "correct signature, resuming update..."
    	fi
fi

# if a GPG_SIG_FILE was provided, check if it is a valid GPG signature
if [ -f "${ZIP_FILE_PATH}${GPG_SIG_FILE}" ] ; then

	if [ "${GPG_SIG_FILE: -4}" == ".gpg" ] ; then
		echo "pass .gpg files only as argument to the -f parameter"
		exit 1
	fi

	echo "checking signature..."
	${GPG} --verify "${ZIP_FILE_PATH}${GPG_SIG_FILE}" "${ZIP_FILE_PATH}${ZIP_FILE}" 2>/dev/null
	IS_VALID_SIGNATURE=$?

	if [ $IS_VALID_SIGNATURE -eq 1 ] ; then
		echo "incorrect GPG signature, check the signature file name for errors: ${ZIP_FILE_PATH}${GPG_SIG_FILE}"
		exit 1

	elif [ $IS_VALID_SIGNATURE -eq 2 ] ; then
       		echo "invalid GPG signature, check the signature file name for errors: ${ZIP_FILE_PATH}${GPG_SIG_FILE}"
        	exit 1
    	else
		echo "correct signature, resuming update..."
	fi
fi

# if a C_SIG_FILE (signature generated by ed25519 c program) was provided, check if it is a valid signature
if [ -f "${ZIP_FILE_PATH}${C_SIG_FILE}" ] ; then

	echo "C checking signature..."
	${ZIP_FILE_PATH}${C_VERIFY_FILE} ${ZIP_FILE_PATH}${ZIP_FILE} ${ZIP_FILE_PATH}${C_SIG_FILE}
	IS_VALID_SIGNATURE=$?

	if [ $IS_VALID_SIGNATURE -eq 1 ] ; then
		echo "invalid signature, check the signature file name for errors: ${ZIP_FILE_PATH}${C_SIG_FILE}"
		exit 1
	else
		echo "correct signature, resuming update..."
	fi
fi
exit 0
# 1 Initialize Update #
## 1.1 check the availability of mandatory programs, cancel Update if necessary ##
UNZIP=`command -v unzip` || { echo >&2 "Update ERROR: Program unzip not available.  Aborting."; exit 1; }
AWK=`command -v awk` || { echo >&2 "Update ERROR: Program awk not available.  Aborting."; exit 1; }
TAIL=`command -v tail` || { echo >&2 "Update ERROR: Program tail not available.  Aborting."; exit 1; }
DF=`command -v df` || { echo >&2 "Update ERROR: Program df not available.  Aborting."; exit 1; }
MOUNT=`command -v mount` || { echo >&2 "Update ERROR: Program mount not available.  Aborting."; exit 1; }
UMOUNT=`command -v umount` || { echo >&2 "Update ERROR: Program umount not available.  Aborting."; exit 1; }
SYNC=`command -v sync` || { echo >&2 "Update ERROR: Program sync not available.  Aborting."; exit 1; }

## 1.2 test the zip file ##
PASSWD=""
GetPassword
CheckFile
# exit if error, handled by upper functions

## 1.3 check image versions, stage 1
VERSION_TXT="versions.txt"

${UNZIP} -oP ${PASSWD} ${ZIP_FILE_PATH}${ZIP_FILE} ${VERSION_TXT} -d /tmp

OLD_IMAGE_NAME="LinuxConsoleImage"
NEW_IMAGE_NAME="isegConsoleImage"
REG_EXP="Rootfs.*[vV]\([0-9]*\.[0-9]*\(\.[0-9]\)*\)"
NEW_VERSION_FILE_PATH="/tmp/${VERSION_TXT}"
NEW_FIRMWARE_VERSION_STR="`${GREP} "${REG_EXP}" "${NEW_VERSION_FILE_PATH}"`"
NEW_FIRMWARE_VERSION="`expr match "$NEW_FIRMWARE_VERSION_STR" "${REG_EXP}"`"
echo "NEW_FIRMWARE_VERSION='${NEW_FIRMWARE_VERSION}'"

OLD_FIRMWARE_FILE_PATH="/www/pages/iCSweb2/version.info"
OLD_FIRMWARE_VERSION_STR=`head -n1 ${OLD_FIRMWARE_FILE_PATH}`
OLD_FIRMWARE_VERSION=`echo ${OLD_FIRMWARE_VERSION_STR} | ${AWK} -F"[-. ]" '{ print $1 "." $2 "." $3 }'`
echo "OLD_FIRMWARE_VERSION='${OLD_FIRMWARE_VERSION}'"

BOARD_REVISION=`${FWPRINTENV} -n board_rev` || BOARD_REVISION="0000"

## Prevent firmware downgrades under v2.10 for boards with Rev. 1.1D and newer
## Revision | ident | min iCS | reason
## 1.1A     | 011a  | v2.4.0
## 1.1B     | 011b  | v2.4.0
## 1.1C     | 011c  | v2.10.0 | SOMs are deliveres with unsupported uboot and uboot_spl
## 1.1D     | 011d  | v2.10.0 | network drivers from TRDX-BSP v2.8.8
## 1.1Y     | 0112  | v2.10.0 | network drivers from TRDX-BSP v2.8.8
## 1.1Z     | 011c  | v2.10.0 | SOMs are deliveres with unsupported uboot and uboot_spl
if ! boardRevisionBefore ${BOARD_REVISION} 011d || boardRevisionBefore ${BOARD_REVISION} 011a ; then
	if ${GREP} -q "${NEW_IMAGE_NAME}" ${NEW_VERSION_FILE_PATH} ; then
		if ! versionGreaterEqual ${NEW_FIRMWARE_VERSION} "2.10.0" ; then
			echo "A firmware update from ${OLD_FIRMWARE_VERSION} down to version ${NEW_FIRMWARE_VERSION} is not possible!"
			exit 1
		fi
	else
		echo "The image name does not match the expected nomenclature \"${NEW_IMAGE_NAME}-VM.m.p\", installation is not possible!"
		exit 1
	fi
fi

## 1.4 does the archive contain a new icsupdate.sh? then extract it accordingly
UPDATE_FILE="icsupdate.sh"
CNT=`${UNZIP} -l ${ZIP_FILE_PATH}${ZIP_FILE} | ${GREP} -c ${UPDATE_FILE}`
if [ "$CNT" -gt 0 -a -z "${NO_RECURSE}" ] ; then
	echo "Update: new ${UPDATE_FILE} detected, so extract and run it."
	${UNZIP} -oP ${PASSWD} ${ZIP_FILE_PATH}${ZIP_FILE} ${UPDATE_FILE} -d /tmp || FAILURE=1
	/tmp/${UPDATE_FILE} -n $@
	exit 0
fi

## 1.5 set parameters
#initialise options
ROOTFS_SIZE="512M"
USERFS_PATH="/mnt/user"
# set profile with 512MB rootfs to default
PARTITION_PROFILE="1"

# 2 Get Information about the running system before start update #
### get uboot flags (sysnumbers can be "1" or "2") ###
FAILURE=0				#this is a failure flag
NEWSYSNR=0
NEWSYSNR_NAME="iseg_sys_new"
OLDSYSNR=0
OLDSYSNR_NAME="iseg_sys_old"

## 2.1 Get the root partition to install update ##
OLDSYSNR=`${FWPRINTENV} -n ${OLDSYSNR_NAME}` || OLDSYSNR=1
[ -n "${OLDSYSNR}" ] || OLDSYSNR=1
echo "Update: oldsysnr:" "${OLDSYSNR}"
NEWSYSNR=`${FWPRINTENV} -n ${NEWSYSNR_NAME}`
echo "Update: newsysnr:" "${NEWSYSNR}"

if [ "$OLDSYSNR" -eq 1 ] ; then
	NEWSYSNR=2
elif [ "$OLDSYSNR" -eq 2 ] ; then
	NEWSYSNR=1
else
	echo >&2 "Update ERROR: mmmh, something spooky is going on..."
	FAILURE=1
fi
echo "Update: going to try update system #" "${NEWSYSNR}"

## 2.2 Get device_type configuratione ##
ISEG_SN=`${FWPRINTENV} -n iseg_serial`
if [[ -z "${ISEG_SN}" ]] ; then
	echo "ERROR: no SerialNumber was set in system"
	exit 1;
fi

DEVICE_TYPE_SN=`GetDeviceType ${ISEG_SN}` \
	&& echo "device_type is ${DEVICE_TYPE_SN}" \
	|| { echo "ERROR: Could not find device_type for SerialNumber ${ISEG_SN}!"; exit 1; }

## 2.3 check image versions ##
MINIMUM_REQUIRED_VERSION="2.4.0"
# Check whether the new firmware name corresponds to the current naming convention. All other firmwares are too old.
if ${GREP} -q "${OLD_IMAGE_NAME}" ${NEW_VERSION_FILE_PATH} ; then
	echo "A firmware update down to old image ${OLD_IMAGE_NAME} with version ${NEW_FIRMWARE_VERSION} is not possible!"
	exit 1
fi

if ${GREP} -q "${NEW_IMAGE_NAME}" ${NEW_VERSION_FILE_PATH} ; then
	# Prevent some firmware downgrades
	## Check if the new firmware version is greater than or equal to v2.4.0. This is the first documented firmware.
	if ! versionGreaterEqual "${NEW_FIRMWARE_VERSION}" "${MINIMUM_REQUIRED_VERSION}" ; then
		echo "A firmware update down to version ${NEW_FIRMWARE_VERSION} is not possible!"
		exit 1
	fi
	# Adjustments for special version jumps.
	if versionGreaterEqual ${NEW_FIRMWARE_VERSION} "2.6.0" ; then
		echo "Do some specials for firmware 2.6.0 and higher."
		MINIMUM_REQUIRED_VERSION="2.5.0"
		if ! versionGreaterEqual ${OLD_FIRMWARE_VERSION} ${MINIMUM_REQUIRED_VERSION} ; then
			echo "A firmware update to version ${NEW_FIRMWARE_VERSION} requires ${MINIMUM_REQUIRED_VERSION} or higher!"
			exit 1
		fi

		PARTITION_PROFILE="2"
		### check required programs for image 2.6.0 and higher
		PARTED=`command -v parted` || { echo >&2 "Update ERROR: Program parted is not available."; exit 1; }
		SFDISK=`command -v sfdisk` || { echo >&2 "Update ERROR: Program sfdisk is not available."; exit 1; }

		# If change from 2.5 to 2.6 new kernel and devicetree is mandatory
		if ! versionGreaterEqual ${OLD_FIRMWARE_VERSION} "2.6.0" ; then
			MANDATORYKERNEL=1
		fi
	fi
	echo "Firmware Version check successful."
else
	### The image name does not start with ${NEW_IMAGE_NAME}
	echo "The image name does not match the expected nomenclature \"${NEW_IMAGE_NAME}-VM.m.p\", installation is not possible!"
	exit 1
fi

# 3 unpack kernel files #####################################
KERNEL_PATH="/mnt/kernel"
# No devicetree by default
KERNEL_FILE="uImage" 	#name of linux kernel file
DTB_NAMES="imx6-apalis-ics-cc24-2 \
		   imx6-apalis-ics-mini-1 imx6-apalis-ics-mini-2 \
		   imx6-apalis-ics-shr-1"

## 3.1 mount kernel partition ##
mount /dev/mmcblk0p1 ${KERNEL_PATH}

## 3.2 does the archive contain uImage? then extract it accordingly else copy the old one ##
CNT=`${UNZIP} -l ${ZIP_FILE_PATH}${ZIP_FILE} | ${GREP} -c ${KERNEL_FILE}`
if [ "$CNT" -gt 0 ] ; then
	echo "Update: ${KERNEL_FILE}" "detected, so extract it."
	${UNZIP} -oP ${PASSWD} ${ZIP_FILE_PATH}${ZIP_FILE} ${KERNEL_FILE} -d /tmp || FAILURE=1
	#overwrite existing file
	mv -f /tmp/${KERNEL_FILE} ${KERNEL_PATH}/uImage${NEWSYSNR}
else
	echo "Update: can not detect" "${KERNEL_FILE}" "in" ${ZIP_FILE}
	if [[ ${MANDATORYKERNEL} -eq 1 ]] ; then
		echo "ERROR: new Kernel is required for update from ${OLD_FIRMWARE_VERSION} \
			to ${NEW_FIRMWARE_VERSION}"
		exit 1;
	else
		echo "use the old Kernel"
		cp -f ${KERNEL_PATH}/uImage${OLDSNR} ${KERNEL_PATH}/uImage${NEWSYSNR} || FAILURE=1
	fi
fi

## 3.3 does the archive contain device tree? then extract it accordingly ##
#### if old u-Boot settings, use old dtb spelling format ###
FDT_FILE=`${FWPRINTENV} -n fdt_file`
if [[ "${FDT_FILE}" == *"iseg"* ]] || [[ "${FDT_FILE}" == *"eval"* ]] ; then
	DEVICETREEOLDFORMAT=1
fi

DEVICE_TREE=imx6-apalis-ics-${DEVICE_TYPE_SN} \
	&& echo "For new System the used device-tree is ${DEVICE_TREE}-${NEWSYSNR}.dtb" \
	|| { echo "ERROR: Could not find device-tree ${DEVICE_TREE}!"; exit 1; }

for DTB_NAME in ${DTB_NAMES}
do
CNT=`${UNZIP} -l ${ZIP_FILE_PATH}${ZIP_FILE} | ${GREP} -c ${DTB_NAME}`
if [ "$CNT" -gt 0 ] ; then
	echo "device tree ${DTB_NAME} detected, so extract it."
	${UNZIP} -oP ${PASSWD} ${ZIP_FILE_PATH}${ZIP_FILE} ${DTB_NAME}.dtb -d /tmp || FAILURE=1
	#overwrite existing file
	mv -f /tmp/${DTB_NAME}.dtb ${KERNEL_PATH}/${DTB_NAME}-${NEWSYSNR}.dtb
	if [[ "${DEVICE_TREE}" = "${DTB_NAME}" ]] ; then
		NEWDEVICETREEFOUND=1
	fi
else
	echo "Update: can not detect device tree ${DTB_NAME} in" ${ZIP_FILE}
	if [[ ${MANDATORYKERNEL} -eq 1 ]] ; then
		echo "ERROR: new DeviceTree is requried for update from ${OLD_FIRMWARE_VERSION} \
			to ${NEW_FIRMWARE_VERSION}"
		exit 1;
	else
		echo "use the old DeviceTree"
		if [[ ${DEVICETREEOLDFORMAT} -ne 1 ]] ; then
			cp -f ${KERNEL_PATH}/${DTB_NAME}-${OLDSYSNR}.dtb ${KERNEL_PATH}/${DTB_NAME}-${NEWSYSNR}.dtb || FAILURE=1
		else
			if [[ "${FDT_FILE}" == *"iseg"* ]] ; then
			cp -f ${KERNEL_PATH}/imx6q-apalis-iseg${OLDSYSNR}.dtb ${KERNEL_PATH}/imx6q-apalis-iseg${NEWSYSNR}.dtb || FAILURE=1
			fi
			if [[ "${FDT_FILE}" == *"eval"* ]] ; then
				cp -f ${KERNEL_PATH}/imx6q-apalis-eval${NEWSYSNR}.dtb ${KERNEL_PATH}/imx6q-apalis-eval${NEWSYSNR}.dtb || FAILURE=1
			fi
		fi
	fi
fi
done

### copy new DeviceTree to old spelling format ###
if [[ ${NEWDEVICETREEFOUND} -eq 1 ]] && [[ ${DEVICETREEOLDFORMAT} -eq 1 ]] ; then
	if [[ "${FDT_FILE}" == *"iseg"* ]] ; then
		cp -f ${KERNEL_PATH}/${DEVICE_TREE}-${NEWSYSNR}.dtb ${KERNEL_PATH}/imx6q-apalis-iseg${NEWSYSNR}.dtb \
			&& echo "For new System the used device-tree is imx6q-apalis-iseg${NEWSYSNR}.dtb" \
			|| FAILURE=1
	fi

	if [[ "${FDT_FILE}" == *"eval"* ]] ; then
		cp -f ${KERNEL_PATH}/${DEVICE_TREE}-${NEWSYSNR}.dtb ${KERNEL_PATH}/imx6q-apalis-eval${NEWSYSNR}.dtb  \
			&& echo "For new System the used device-tree is imx6q-apalis-iseg${NEWSYSNR}.dtb" \
			|| FAILURE=1
	fi
fi

## 3.4 unmount kernel partitition ##
umount ${KERNEL_PATH}

# 4 unpack rootfs ##########################################
ROOT_FILE="root.ext3"
## 4.1 does it contain root.ext3? then 'disk dump' it to corresponding partition ##
CNT=`${UNZIP} -l ${ZIP_FILE_PATH}${ZIP_FILE} | ${GREP} -c ${ROOT_FILE}`
if [ "$CNT" -gt 0 ] ; then
echo "Update: " "${ROOT_FILE}" "detected..."
if [ "$FAILURE" -eq 0 ] ; then
	if [ "$NEWSYSNR" -eq 1 ] ; then
		UpdateSystem /dev/mmcblk0p2
	elif [ "$NEWSYSNR" -eq 2 ] ; then
		UpdateSystem /dev/mmcblk0p3
	else
		echo >&2 "Update ERROR: mmmh, something spooky is going on..."
		FAILURE=1
	fi
fi
else
	echo "Update: can not detect" "${ROOT_FILE}" "in" ${ZIP_FILE}
fi

# 5 check failure, if none set uboot flag accordingly #
if [ "$FAILURE" -eq 0 ] ; then
	${FWSETENV} ${NEWSYSNR_NAME} ${NEWSYSNR} && echo "Update successful!" || { echo >&2 "Error: Update failed. Aborting."; exit 1; }
else
	echo >&2 "Update ERROR: Update failed."
	exit 1
fi

exit 0
