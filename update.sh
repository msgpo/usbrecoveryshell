#!/bin/bash
#
# Original Author : Lu Ken (bluewish.ken.lu@****l.com)
# Modified by : Sam @ Hackers for Charity (hackersforcharity.org) 
#    and World Possible (worldpossible.org)
#
# RACHEL Recovery USB
# Description: This is the first script to run when the CAP starts up
# and boots from USB. It will set the LED lights and setup the emmc and hard drive.
#
# LED Status:
#    - During script:  Wireless breathe and 3G solid
#    - After success:  Wireless solid and 3G solid
#    - After fail:  Wireless fast blink and 3G solid
#
# Install Options:
#    - "Recovery" for end user CAP recovery (method 1)
#        Copy boot, efi, and rootfs partitions to emmc
#        Rewrite the hard drive partition table
#        DO NOT format any hard drive partitions (set format_option to 0)
#    - "Imager" for large installs when cloning the hard drive (method 2)
#        Copy boot, efi, and rootfs partitions to emmc
#        Don't touch the hard drive (since you will swap with a cloned one)
#    - "Format" for small installs and/or custom hard drive (method 3)
#        *WARNING* This will erase all partitions on the hard drive */WARNING*
#        Copy boot, efi, and rootfs partitions to emmc
#        Rewrite the hard drive partition table
#        Format hard drive partitions (set format_option to 1)
#        Copy content shell to /media/RACHEL/rachel
#
# Stage RACHEL files on USB using the following commands:
#	cd <USB-Drive-Root>/rachel-files/staging
#	Copy any files/folders you want on the CAP after imaging to this folder.
#   Files will be on the CAP post recovery in the /media/RACHEL/staging folder.
#
method="1" # 1=Recovery (DEFAULT), 2=Imager, 3=Format
firmwareVersion="1.2.16-rooted"
usbCreated="20170613.2237"
usbVersion="20170613"
timestamp=$(date +"%b-%d-%Y-%H%M%Z")
scriptRoot="/boot/efi"
rachelPartition="/media/RACHEL"

commandStatus(){
	export exitCode="$?"
	if [[ $exitCode == 0 ]]; then
		echo "Command status:  OK"
		$scriptRoot/led_control.sh breath off &> /dev/null
		$scriptRoot/led_control.sh issue off &> /dev/null
		$scriptRoot/led_control.sh normal on &> /dev/null
	else
		echo "Command status:  FAIL"
		$scriptRoot/led_control.sh breath off &> /dev/null
		$scriptRoot/led_control.sh issue on &> /dev/null
	fi
}

backupGPT(){
	echo; echo "[*] Current GUID Partition Table (GPT) for the hard disk /dev/sda:"
	sgdisk -p /dev/sda
	echo; echo "[*] Backing up GPT to $scriptRoot/sda-backup-$timestamp.gpt"
	sgdisk -b $scriptRoot/rachel-files/gpt/sda-backup-$timestamp.gpt /dev/sda
	echo; echo "[*] Removing all but the last three backup files"
	cd $scriptRoot/rachel-files/gpt; ls -tp | grep -v '/$' | tail -n +4 | tr '\n' '\0' | xargs -0 rm --
	echo "[+] Backup complete."
}

updateCore(){
	echo "[*] Mounting /dev/sda3"
	mkdir -p $rachelPartition
	mount /dev/sda3 $rachelPartition
	echo "[*] Copying RACHEL contentshell files to /dev/sda3 (RACHEL web root)"
	cp -r $scriptRoot/rachel-files/contentshell $rachelPartition/rachel
	chmod +x $rachelPartition/rachel/*.shtml
	echo "[*] Copying RACHEL contentshell files to /dev/sda3 (backup)"
	cp -r $scriptRoot/rachel-files/contentshell $rachelPartition/
	chmod +x $rachelPartition/contentshell/*.shtml
	# echo "[*] Copying KA Lite admin directory to /dev/sda3."
	# cp -r $scriptRoot/rachel-files/kalite-admin-directory $rachelPartition/.kalite
	echo "[*] Copying RACHEL packages for offline update to /dev/sda3"
	cp -r $scriptRoot/rachel-files/offlinepkgs $rachelPartition/
	echo "[*] Running phase 1 updates"
	echo "[+] Staging updated cap-rachel-configure.sh script"
	cp $scriptRoot/rachel-files/cap-rachel-configure.sh $rachelPartition/cap-rachel-configure.sh
	chmod +x $rachelPartition/cap-rachel-configure.sh
	echo "[+] Running cap-rachel-configure.sh --usbrecovery"
	bash $rachelPartition/cap-rachel-configure.sh --usbrecovery &> /dev/null
	# Copy rachelinstaller version to disk
	echo $usbCreated > $rachelPartition/rachelbuilddate
	echo $usbVersion > $rachelPartition/rachelinstaller-version
	echo; echo "[+] Core update complete"
}

checkForStagedFiles(){
	mkdir -p $scriptRoot/rachel-files/staging $rachelPartition/staging
	if [[ $(ls -A $scriptRoot/rachel-files/staging 2>/dev/null) ]]; then
		cp -r $scriptRoot/rachel-files/staging/* $rachelPartition/staging/
	fi
	echo "[+] Done."
}

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1> $scriptRoot/update.log 2>&1

echo; echo ">>>>>>>>>>>>>>> RACHEL Recovery USB - Version $usbVersion - Started $(date) <<<<<<<<<<<<<<<"
echo "RACHEL/CAP Firmware Build:  $firmwareVersion"
echo "RACHEL Recovery USB Build Date:  $usbCreated"
echo "Bash Version:  $(echo $BASH_VERSION)"
echo "Recovery USB configured to run method:  $method"
echo " -- 1=Recovery (DEFAULT), 2=Imager, 3=Format"

echo; echo "[*] Updating LEDs."
$scriptRoot/led_control.sh normal off &> /dev/null
$scriptRoot/led_control.sh breath on &> /dev/null
#$scriptRoot/led_control.sh issue on &> /dev/null
$scriptRoot/led_control.sh 3g on &> /dev/null
echo "[+] Done."

echo; echo "[*] Method $method will now execute"
if [[ $method != 4 ]]; then
	echo; echo "[*] Executing script:  $scriptRoot/copy_partitions_to_emmc.sh"
	$scriptRoot/copy_partitions_to_emmc.sh $scriptRoot
	# Backing up GPT
	backupGPT
	if [[ $method == 1 ]]; then
		echo; echo "[*] Executing script:  $scriptRoot/init_content_hdd.sh, format option 0"
		$scriptRoot/init_content_hdd.sh /dev/sda 0
		commandStatus
		echo; echo "[+] Ran method 1"
	elif [[ $method == 2 ]]; then
		commandStatus
		echo; echo "[+] Ran method 2"
	elif [[ $method == 3 ]]; then
		echo; echo "[*] Executing script:  $scriptRoot/init_content_hdd.sh, format option 1"
		$scriptRoot/init_content_hdd.sh /dev/sda 1
		commandStatus
		echo; echo "[+] Ran method 3"
	fi

	# Copying contentshell and other package files to the CAP
	echo; echo "[*] Updating core files/folders"
	updateCore
	commandStatus
	echo; echo "[*] If needed, copying staged files from USB to CAP"
	checkForStagedFiles
	commandStatus
else
	echo; echo "[*] Mounting /dev/mmcblk0p4 to /tmp/cap"
	mkdir -p /tmp/cap
	mount /dev/mmcblk0p4 /tmp/cap
	echo; echo "[*] Mounting /dev/sda3"
	mkdir -p $rachelPartition
	mount /dev/sda3 $rachelPartition
	echo; echo "[*] Before copying KA Lite folder - $rachelPartition"
	ls -la $rachelPartition
	echo; echo "[*] Copying .kalite dir to /media/RACHEL"
	cp -r /tmp/cap/root/.kalite $rachelPartition/.kalite-backup
	mv /tmp/cap/root/.kalite $rachelPartition/
	echo; echo "[*] After copying KA Lite folder - $rachelPartition (should be .kalite and .kalite-backup"
	ls -la $rachelPartition
	echo; echo "[*] Symlinking /root/.kalite to /media/RACHEL/.kalite"
	ln -s $rachelPartition/.kalite /tmp/cap/root/.kalite
	echo; echo "[*] Symlinking complete - /root"
	ls -la /tmp/cap/root
	sleep 2
	umount /tmp/cap
	sleep 2
	rmdir /tmp/cap
	echo; echo "[*] Updating LEDs."
	$scriptRoot/led_control.sh breath off &> /dev/null
	$scriptRoot/led_control.sh normal on &> /dev/null
	$scriptRoot/led_control.sh 3g off &> /dev/null
	echo "[+] Completed KA Lite folder move, shutting down."
	shutdown -h now
fi

# Disabled copy of logs; not used
#echo; echo "[*] Copying log files to root of USB"
#cp -rf /var/log $scriptRoot/
sync
echo; echo "[*] Updating LEDs."
$scriptRoot/led_control.sh 3g off &> /dev/null
echo "[+] Done."

echo; echo ">>>>>>>>>>>>>>> RACHEL Recovery USB - Completed $(date) <<<<<<<<<<<<<<<"