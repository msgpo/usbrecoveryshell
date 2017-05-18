#!/bin/bash
# FILE: cap-rachel-configure.sh
# ONELINER Download/Install: sudo wget https://raw.githubusercontent.com/rachelproject/rachelplus/master/cap-rachel-configure.sh -O /root/cap-rachel-configure.sh; bash cap-rachel-configure.sh
# OFFLINE BUILDS:  Run the Download-Offline-Content script in the Utilities menu.

# COMMON VARIABLES - Change as needed
dirContentOffline="/media/usbhd-sdb1" # Enter directory of downloaded RACHEL content for offline install (e.g. I mounted my external USB on my CAP but plugging the external USB into and running the command 'fdisk -l' to find the right drive, then 'mkdir /media/RACHEL-Content' to create a folder to mount to, then 'mount /dev/sdb1 /media/RACHEL-Content' to mount the USB drive.)
rsyncOnline="rsync://dev.worldpossible.org" # The current RACHEL rsync repository
contentOnline="rsync://rachel.golearn.us/content" # Another RACHEL rsync repository
wgetOnline="http://rachelfriends.org" # RACHEL large file repo (ka-lite_content, etc)
gitESP="https://raw.githubusercontent.com/rachelproject/esp/master" # ESP GitHub Repo
gitRachelPlus="https://raw.githubusercontent.com/rachelproject/rachelplus/master" # RACHELPlus Scripts GitHub Repo
gitRachelPlusBeta="https://raw.githubusercontent.com/rachelproject/rachelplus/beta" # RACHELPlus Scripts GitHub Repo
gitContentShell="https://raw.githubusercontent.com/rachelproject/contentshell/master" # RACHELPlus ContentShell GitHub Repo
gitContentShellCommit="b5770d0"

# CORE RACHEL VARIABLES - Change **ONLY** if you know what you are doing
osID="$(awk -F '=' '/^ID=/ {print $2}' /etc/os-release 2>&-)"
osVersion=$(lsb_release -ds)
# osVersion=$(grep DISTRIB_RELEASE /etc/lsb-release | cut -d"=" -f2)
# osVersion=$(awk -F '=' '/^VERSION_ID=/ {print $2}' /etc/os-release 2>&-)
# To get current version - date +%Y%m%d.%H%M
scriptVersion=20170516.2339
timestamp=$(date +"%b-%d-%Y-%H%M%Z")
internet="1" # Enter 0 (Offline), 1 (Online - DEFAULT)
rachelLogDir="/var/log/rachel"
mkdir -p $rachelLogDir
rachelLogFile="rachel-install.log.tmp"
rachelLog="$rachelLogDir/$rachelLogFile"
rachelPartition="/media/RACHEL"
rachelWWW="$rachelPartition/rachel"
rachelScriptsDir="/root/rachel-scripts"
rachelScriptsFile="$rachelScriptsDir/rachelStartup.sh"
rachelScriptsLog="/var/log/rachel/rachel-scripts.log"
kaliteUser="root"
kaliteDir="/root/.kalite" # Installed as user 'root'
kaliteContentDir="$rachelPartition/kacontent"
kaliteMajorVersion="0.17"
kaliteCurrentVersion="$kaliteMajorVersion.1-0ubuntu1"
kaliteInstaller=ka-lite-bundle_"$kaliteCurrentVersion"_all.deb
kalitePrimaryDownload="http://pantry.learningequality.org/downloads/ka-lite/$kaliteMajorVersion/installers/debian/$kaliteInstaller"
kalitePrimaryContent="http://pantry.learningequality.org/downloads/ka-lite/$kaliteMajorVersion/content"
kaliteSettings="$kaliteDir/settings.py"
kiwixInstallerCAPv1="kiwix-0.9-linux-i686.tar.bz2"
kiwixInstallerCAPv2="kiwix-0.9-linux-x86_64.tar.bz2"
installTmpDir="/root/cap-rachel-install.tmp"
rachelTmpDir="/media/RACHEL/cap-rachel-install.tmp"
rachelRecoveryDir="/media/RACHEL/recovery"
stemPkg="stem-1.5.1.tgz"
stemURL="https://pecl.php.net/get/$stemPkg"
debPrecisePackageList="php5-cgi php5-common php5-mysql php5-sqlite php5-curl php5-dev php-pear pdftk make git git-core git-man liberror-perl python-m2crypto mysql-server mysql-client libapache2-mod-auth-mysql sqlite3 gcc-multilib gcj-4.6-base gcj-4.6-jre-lib libgcj12 libgcj-common libasound2 fuse-utils fuse-exfat exfat-utils"
debTrustyPackageList="php5-cgi php5-common php5-mysql php5-sqlite php5-curl php5-dev php-pear pdftk make git git-core git-man liberror-perl python-m2crypto mysql-server mysql-client libapache2-mod-auth-mysql sqlite3 gcc-multilib gcc-4.8-base gcj-4.8-jre-lib libgcj14 libgcj-common libasound2 exfat-fuse exfat-utils"
gpgKeys="40976EAF437D05B5 16126D3A3E5C1192 4DF9B28CA252A784 1655A0AB68576280 1397BC53640DB551 A040830F7FAC5991"
errorCode="0"

# MD5 hash list
buildHashList(){
    cat > $installTmpDir/hashes.md5 << 'EOF'
d17736647f2d94f7c7dd428d19a64237 ka-lite-bundle_0.17.1-0ubuntu1_all.deb
ef4e2741b145a21179eed83867cb531a ka-lite-bundle_0.17.0-0ubuntu1_all.deb
13c447a2e78ad67a06caaded00d01701 ka-lite-bundle_0.17.0-0ubuntu2_all.deb
34fb1b8df07db49de04bc5faaae6497d ka-lite-bundle_0.17.0-0ubuntu3_all.deb
b61fdc3937aa226f34f685ba0bc29db1 kiwix-0.9-linux-i686.tar.bz2
df6216ba851819d9c3d0208d3ea639df kiwix-0.9-linux-x86_64.tar.bz2
EOF
}

# Rsync Module Exclude List
buildRsyncModuleExcludeList(){
    cat > $rachelScriptsDir/rsyncExclude.list << 'EOF'
#*-kalite/content*
*.zip
en-afristory.old
KALite0.14_content
KALite0.15_content
rsync.sh
extra-build-files
.gitignore
README.txt
peewee.db
en-GCF2013
EOF
}

printGood(){
    echo -e "\x1B[01;32m[+]\x1B[0m $1"
}

printError(){
    echo -e "\x1B[01;31m[-]\x1B[0m $1"
}

printStatus(){
    echo -e "\x1B[01;35m[*]\x1B[0m $1"
}

printQuestion(){
    echo -e "\x1B[01;33m[?]\x1B[0m $1"
}

# Logging
loggingStart(){
    exec &> >(tee "$rachelLog")
}

cleanup(){
    # If requested, do not ask to cleanup
    if [[ $noCleanup == "1" ]]; then exit 0; fi
    # Continue, if cleanup required
    kill $!; trap 'kill $1' SIGTERM
    # Store log file
    mv $rachelLog $rachelLogDir/cap-rachel-configure-$timestamp.log
    echo; printGood "Log file saved to: $rachelLogDir/cap-rachel-configure-$timestamp.log"
    # Provide option to NOT clean up tmp files
    echo; printQuestion "Were there errors?"
    read -p "Enter 'y' to exit without cleaning up temporary folders/files. (y/N) " REPLY
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then exit 1; fi
    # Ensure the start script are executable
    chmod +x /etc/rc.local $rachelScriptsFile 2>/dev/null
    # Deleting the install script commands
    echo; printStatus "Cleaning up install scripts."
    rm -rf $installTmpDir $rachelTmpDir
    printGood "Done."
    stty sane
    noCleanup=1
    echo; exit 0
}

testingScript(){
    set -x

    repairRachelScripts

    set +x
    exit 1
}

opMode(){
    echo; printQuestion "Do you want to run in ONLINE (a network location) or OFFLINE (USB drive) mode?"
    select MODE in "ONLINE" "OFFLINE"; do
        case $MODE in
        # ONLINE
        ONLINE)
            echo; printGood "Script set for 'ONLINE' mode."
            internet="1"
            onlineVariables
            checkInternet
            break;
        ;;
        # OFFLINE
        OFFLINE)
            echo; printGood "Script set for 'OFFLINE' mode."
            internet="0"
            offlineVariables
            echo; printStatus "Here is list of your current partitions and their mountpoints (if applicable):"
            lsblk|grep -v mmc|grep -v sda
            echo; printQuestion "What is the location of your content folder (for example, /media/usb)? "; read dirContentOffline
            grep -qs " $dirContentOffline " /proc/mounts
            if [[ $? != 0 ]]; then
                echo; printError "The folder location does not exist!  Do you want to continue?"
                read -p "    Enter (y/N) " REPLY
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    echo; printStatus "CAUTION:  Any action that requires USB content will not function as expected."
                    dirContentOffline="/dev/null"
                    offlineVariables
                else
                    printError "Exiting on user request."
                    rm -rf $installTmpDir $rachelTmpDir
                    exit 1
                fi
            fi
            offlineVariables
            break;
        ;;
        # Catch all
        *)
            echo; printQuestion "Do you want to run in ONLINE (a network location) or OFFLINE (USB drive) mode?";
        ;;
        esac
    done
}

osCheck(){
    if [[ -z "$osID" ]] || [[ -z "$osVersion" ]]; then
        printError "Internal issue. Couldn't detect OS information."
        # Default to precise
        osName="precise"
    elif [[ "$osID" == "ubuntu" ]]; then
        # osVersion=$(awk -F '["=]' '/^VERSION_ID=/ {print $3}' /etc/os-release 2>&- | cut -d'.' -f1)
        printGood "${osVersion} $(uname -m) Detected."
        osName=$(lsb_release -cs)
        # osName=$(grep DISTRIB_CODENAME /etc/lsb-release | cut -d"=" -f2)
    elif [[ "$osID" == "debian" ]]; then
        printGood "${osVersion} $(uname -m) Detected."
        debianVersion=$(cat /etc/debian_version | cut -d"." -f1)
        if [[ $debianVersion="7" ]]; then
            osName="wheezy"
        else
            osName="jessie"
        fi
    fi
}

capCheck(){
    if [[ $(cat /etc/hostname) == "WRTD-303N-Server" ]]; then
        os=cap_v1
        osName="precise"
        KiwixInstaller="$kiwixInstallerCAPv1"
    elif [[ $(cat /etc/hostname) == "WAPD-235N-Server" ]]; then
        os=cap_v2
        osName="trusty"
        KiwixInstaller="$kiwixInstallerCAPv2"
    else
        echo; printError "This isn't a CAP; sorry, I can not continue."
        echo; exit 1
    fi
}


onlineVariables(){
    GPGKEY="apt-key adv --keyserver keyserver.ubuntu.com --recv-keys "
    SOURCEUS="wget -r $gitRachelPlus/sources.list/$osName/sources-us.list -O /etc/apt/sources.list"
    SOURCEUK="wget -r $gitRachelPlus/sources.list/$osName/sources-uk.list -O /etc/apt/sources.list"
    SOURCESG="wget -r $gitRachelPlus/sources.list/$osName/sources-sg.list -O /etc/apt/sources.list"
    SOURCECN="wget -r $gitRachelPlus/sources.list/$osName/sources-sohu.list -O /etc/apt/sources.list" 
    CAPRACHELFIRSTINSTALL2="wget -r $gitRachelPlus/install/cap-rachel-first-install-2.sh -O cap-rachel-first-install-2.sh"
    CAPRACHELFIRSTINSTALL3="wget -r $gitRachelPlus/install/cap-rachel-first-install-3.sh -O cap-rachel-first-install-3.sh"
    LIGHTTPDFILE="wget -r $gitRachelPlus/scripts/lighttpd.conf -O lighttpd.conf"
    CAPTIVEPORTALREDIRECT="wget -r $gitContentShell/captiveportal-redirect.php -O captiveportal-redirect.php"
    PASSTICKETSHTML="wget -r $gitContentShell/pass_ticket.shtml -O pass_ticket.shtml"
    REDIRECTSHTML="wget -r $gitContentShell/redirect.shtml -O redirect.shtml"
    RACHELBRANDLOGOCAPTIVE="wget -r $gitContentShell/art/RACHELbrandLogo-captive.png -O RACHELbrandLogo-captive.png"
    HFCBRANDLOGOCAPTIVE="wget -r $gitContentShell/art/HFCbrandLogo-captive.jpg -O HFCbrandLogo-captive.jpg"
    WORLDPOSSIBLEBRANDLOGOCAPTIVE="wget -r $gitContentShell/art/World-Possible-Logo-300x120.png -O World-Possible-Logo-300x120.png"
    GITCLONERACHELCONTENTSHELL="git clone https://github.com/rachelproject/contentshell contentshell"
    RSYNCDIR="$rsyncOnline"
    KALITEINSTALL="wget -c $kalitePrimaryDownload -O $installTmpDir/$kaliteInstaller"
    KIWIXINSTALL="wget -c $wgetOnline/downloads/public_ftp/old/z-holding/$KiwixInstaller -O $rachelTmpDir/$KiwixInstaller"
    DOWNLOADCONTENTSCRIPT="wget -c $gitRachelPlus/scripts"
    CONTENTWIKI="wget -c http://download.kiwix.org/portable/wikipedia/$FILENAME -O $rachelTmpDir/$FILENAME"
    DOWNLOADSCRIPT="wget $gitRachelPlus/cap-rachel-configure.sh -O $installTmpDir/cap-rachel-configure.sh"
    DOWNLOADBETASCRIPT="wget $gitRachelPlusBeta/cap-rachel-configure.sh -O $installTmpDir/cap-rachel-configure.sh"    
}

offlineVariables(){
    GPGKEY="apt-key add $dirContentOffline/rachelplus/gpg-keys/"
    SOURCEUS="rsync -avhz --progress $dirContentOffline/rachelplus/sources.list/$osName/sources-us.list /etc/apt/sources.list"
    SOURCEUK="rsync -avhz --progress $dirContentOffline/rachelplus/sources.list/$osName/sources-uk.list /etc/apt/sources.list"
    SOURCESG="rsync -avhz --progress $dirContentOffline/rachelplus/sources.list/$osName/sources-sg.list /etc/apt/sources.list"
    SOURCECN="rsync -avhz --progress $dirContentOffline/rachelplus/sources.list/$osName/sources-cn.list /etc/apt/sources.list"
    CAPRACHELFIRSTINSTALL2="rsync -avhz --progress $dirContentOffline/rachelplus/install/cap-rachel-first-install-2.sh ."
    CAPRACHELFIRSTINSTALL3="rsync -avhz --progress $dirContentOffline/rachelplus/install/cap-rachel-first-install-3.sh ."
    LIGHTTPDFILE="rsync -avhz --progress $dirContentOffline/rachelplus/scripts/lighttpd.conf ."
    CAPTIVEPORTALREDIRECT="rsync -avhz --progress $dirContentOffline/contentshell/captiveportal-redirect.php ."
    PASSTICKETSHTML="rsync -avhz --progress $dirContentOffline/contentshell/pass_ticket.shtml ."
    REDIRECTSHTML="rsync -avhz --progress $dirContentOffline/contentshell/redirect.shtml ."
    RACHELBRANDLOGOCAPTIVE="rsync -avhz --progress $dirContentOffline/contentshell/art/RACHELbrandLogo-captive.png ."
    HFCBRANDLOGOCAPTIVE="rsync -avhz --progress $dirContentOffline/contentshell/art/HFCbrandLogo-captive.jpg ."
    WORLDPOSSIBLEBRANDLOGOCAPTIVE="rsync -avhz --progress $dirContentOffline/contentshell/art/World-Possible-Logo-300x120.png ."
    GITCLONERACHELCONTENTSHELL=""
    RSYNCDIR="$dirContentOffline"
    KALITEINSTALL="rsync -avhz --progress $dirContentOffline/$kaliteInstaller $installTmpDir/$kaliteInstaller"
    KIWIXINSTALL=""
    DOWNLOADCONTENTSCRIPT="rsync -avhz --progress $dirContentOffline/rachelplus/scripts"
    CONTENTWIKIALL=""
    DOWNLOADSCRIPT="rsync -avhz --progress $dirContentOffline/cap-rachel-configure.sh /root/cap-rachel-configure.sh"
    DOWNLOADBETASCRIPT=""
}

printHeader(){
    # Add header/date/time to install log file
    echo; printGood "RACHEL CAP Configuration Script - Version $scriptVersion"
    printGood "Script started: $(date)"
}

checkInternet(){
    if [[ $internet == "1" || -z $internet ]]; then
        # Check internet connecivity
        WGET=`which wget`
        $WGET -q --tries=10 --timeout=5 --spider http://google.com
        if [[ $? -eq 0 ]]; then
            echo; printGood "Internet connection confirmed...continuing install."
            internet=1
        else
            echo; printError "No internet connectivity; waiting 10 seconds and then I will try again."
            # Progress bar to visualize wait period
            while true;do echo -n .;sleep 1;done & 
            sleep 10
            kill $!; trap 'kill $!' SIGTERM
            $WGET -q --tries=10 --timeout=5 --spider http://google.com
            if [[ $? -eq 0 ]]; then
                echo; printGood "Internet connected confirmed...continuing install."
                internet=1
            else
                echo; printError "No internet connectivity; entering 'OFFLINE' mode."
                offlineVariables
                internet=0
            fi
        fi
    fi
}

commandStatus(){
    export EXITCODE="$?"
    if [[ $EXITCODE != 0 ]]; then
        printError "Command failed.  Exit code: $EXITCODE"
        export errorCode="1"
    else
        printGood "Command successful."
    fi
}

checkSHA1(){
    calculatedHash=$(openssl sha1 $1)
    knownHash=$(cat $installTmpDir/rachelplus/hashes.txt | grep $1 | cut -f1 -d" ") 
    if [[ "SHA1(${1})= $2" == "${calculatedHash}" ]]; then printGood "Good hash!" && export goodHash=1; else printError "Bad hash!"  && export goodHash=0; fi
}

checkMD5(){
    echo; printStatus "Checking MD5 of: $1"
    MD5_1=$(cat $installTmpDir/hashes.md5 | grep $(basename $1) | awk '{print $1}')
    if [[ -z $MD5_1 ]]; then 
        printError "Sorry, we do not have a hash for that file in our database."
    else
        printStatus "NOTE:  This process may take a minute on larger files...be patient."
        MD5_2=$(md5sum $1 | awk '{print $1}')
        if [[ $MD5_1 != $MD5_2 ]]; then
          printError "MD5 check failed.  Please check your file and the RACHEL log ($rachelLog) for errors."
          md5Status=0
        else
          printGood "Yeah...MD5's match; your file is okay."
          md5Status=1
        fi
    fi
}

rebootCAP(){
    # No log as it won't clean up the tmp file
    echo; printStatus "I need to reboot; new installs will reboot twice more automatically."
    echo; printStatus "The file, $rachelLog, will be renamed to a dated log file when the script is complete."
    printStatus "Rebooting in 10 seconds...Ctrl-C to cancel reboot."
    # Progress bar to visualize wait period
    # trap ctrl-c and call ctrlC()
    while true; do
        echo -n .; sleep 1
    done & 
    sleep 10
    kill $!; trap 'kill $!' SIGTERM   
    reboot
}

sanitize(){
    # Remove history, clean logs
    echo; printStatus "Sanitizing log files."
    # Clean log files and possible test scripts
    rm -rf /var/log/rachel-install* /var/log/rachel/* /root/test.sh
    # Clean previous cached logins from ssh
    rm -f /root/.ssh/known_hosts
    # Clean off ka-lite_content.zip (if exists)
    rm -f /media/RACHEL/ka-lite_content.zip
    # Clean previous files from running the generate_recovery.sh script 
    rm -rf /recovery/20* $rachelRecoveryDir/20*
    # Clean bash history
    echo "" > /root/.bash_history
    echo; printQuestion "Do you want to remove any currently activated Weaved services and run the ESP installer?"
    read -p "    Enter (y/N) " REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove previous Weaved installs
        rm -rf /usr/bin/notify_Weaved*.sh /usr/bin/Weaved*.sh /etc/weaved/services/Weaved*.conf /root/Weaved*.log
        # Install ESP
        installESP
    fi
    echo; printGood "All cleaned up for the customer."
}

installKiwix(){
    echo; printStatus "Installing kiwix."
    $KIWIXINSTALL
    if [[ $internet == "0" ]]; then cd $dirContentOffline; else cd $rachelTmpDir; fi
    tar -C /var -xjvf $KiwixInstaller
    chown -fR root:root /var/kiwix
    # Make content directory
    mkdir -p /media/RACHEL/kiwix
    # Start up Kiwix
    echo; printStatus "Setting Kiwix to start on boot."
    # Remove old kiwix boot lines from /etc/rc.local
    sed -i '/kiwix/d' /etc/rc.local
    # Clean up current rachel-scripts.sh file
    sed -i '/kiwix/d' $rachelScriptsFile
    # Add lines to $rachelScriptsFile that will start kiwix on boot
    sed -i '$e echo "\# Start kiwix on boot"' $rachelScriptsFile
    sed -i '$e echo "\/var\/kiwix\/bin\/kiwix-serve --daemon --port=81 --library \/media\/RACHEL\/kiwix\/data\/library\/library.xml"' $rachelScriptsFile
    # Update Kiwix version
    cat /var/kiwix/application.ini | grep ^Version | cut -d= -f2 > /etc/kiwix-version
}

createKiwixRepairScript(){
    echo; printStatus "Creating the Kiwix library rebuild/repair script."
    # Create rachelKiwixStart script
    cat > $rachelScriptsDir/rachelKiwixStart.sh << 'EOF'
#!/bin/bash
#-------------------------------------------
# This script is used to refresh the kiwix library upon restart to
# include everything in the rachel modules directory. It is used
# as part of the kiwix init.d script
#
# Author: Sam <sam@hackersforcharity.org>
# Based on perl version by Jonathan Field <jfield@worldpossible.org>
# Date: 2016-04-27
#-------------------------------------------

# Create tmp file (clean out new lines, etc)
tmp=`mktemp`
libraryPath="/media/RACHEL/kiwix/data/library"
library="$libraryPath/library.xml"

# Remove/recreate existing library
mkdir -p $libraryPath
rm -f $library; touch $library

# Find all the zim files in the modules directoy
ls /media/RACHEL/rachel/modules/*/data/content/*.zim* 2>/dev/null | sed 's/ /\n/g' > $tmp
ls /media/RACHEL/kiwix/data/content/*.zim* 2>/dev/null | sed 's/ /\n/g' >> $tmp

# Remove extra files - we only need the first (.zim or .zimaa)
sed -i '/zima[^a]/d' $tmp

# Find which db file we're using (it changed location in v2)
if [[ -f /media/RACHEL/rachel/admin/admin.sqlite ]]; then
    dbfile=/media/RACHEL/rachel/admin/admin.sqlite
else
    # old location
    dbfile=/media/RACHEL/rachel/admin.sqlite
fi

# Remove modules that are marked hidden on main menu
for d in $(sqlite3 $dbfile 'select moddir from modules where hidden = 1'); do
    sed -i '/\/'$d'\//d' $tmp
done

for i in $(cat $tmp); do
    if [[ $? -ge 1 ]]; then echo "No zims found."; fi
    cmd="/var/kiwix/bin/kiwix-manage $library add $i"
    moddir="$(echo $i | cut -d'/' -f1-6)"
    # we have to remove the extension because we need .zim but it might be .zimaa
    noext="$(echo ${i##*/} | cut -d'.' -f1)"
    if [[ -d "$moddir/data/index/$noext.zim.idx" ]]; then
        cmd="$cmd --indexPath=$moddir/data/index/$noext.zim.idx"
    elif [[ -d "/media/RACHEL/kiwix/data/index/$noext.zim.idx" ]]; then
        cmd="$cmd --indexPath=/media/RACHEL/kiwix/data/index/$noext.zim.idx"
    fi
    $cmd 2>/dev/null
    if [[ $? -ge 1 ]]; then echo "Couldn't add $zim to library"; fi
done

# Restart Kiwix
killall /var/kiwix/bin/kiwix-serve
/var/kiwix/bin/kiwix-serve --daemon --port=81 --library $library > /dev/null
# Update Kiwix version
cat /var/kiwix/application.ini | grep ^Version | cut -d= -f2 > /etc/kiwix-version
rm -f $tmp
EOF
    chmod +x $rachelScriptsDir/rachelKiwixStart.sh
    printGood "Done."
}

downloadOfflineContent(){
    # Check for internet
    if [[ $internet == 0 ]]; then echo; printError "You need to be online to download/update your OFFLINE content."; break; fi
    echo; printStatus "Here is list of your currently mounted USB drives:"
    lsblk|grep -v mmc|grep -v sda
    echo; printQuestion "What is the mountpoint name of your content folder (no trailing slash; example, /media/usb)? "; read dirContentOffline
    while :; do
        if [[ ! -d $dirContentOffline ]]; then
            printError "The folder location does not exist!  Please check the path to your OFFLINE content folder and try again."
            echo; printQuestion "What is the mountpoint name of your content folder (no trailing slash; example, /media/usb)? "; read dirContentOffline
        else
            break
        fi
    done

    # Check if USB is formatted with ext2, ext3 or ext4
    usbFileSystem=$(df -T|grep $dirContentOffline |awk '{ print $2 }')
    if [[ "$usbFileSystem" != "ext2" && "$usbFileSystem" != "ext3" && "$usbFileSystem" != "ext4" ]]; then
        echo; printError "ERROR:  USB is not formatted in ext2, ext3, or ext4.  For a successful offline update, your external USB must be formatted in one of those file systems or symbolic links will not work and your offline update will not correctly update RACHEL modules.  Sorry, I cannot continue; reformat your USB to one of those file systems and try again."
        break 
    fi

    # Download gpg keys
    for i in $(echo $gpgKeys); do apt-key export $i > $dirContentOffline/rachelplus/gpg-keys/$i; done

    # Download RACHEL script 
    echo; printStatus "Downloading/updating the latest RACHEL configure script:  cap-rachel-configure.sh"
    $DOWNLOADSCRIPT >&2
    commandStatus
    if [[ -s $installTmpDir/cap-rachel-configure.sh ]]; then
        mv $installTmpDir/cap-rachel-configure.sh $dirContentOffline/cap-rachel-configure.sh
        chmod +x $dirContentOffline/cap-rachel-configure.sh
        versionNum=$(cat $dirContentOffline/cap-rachel-configure.sh |grep ^scriptVersion|head -n 1|cut -d"=" -f2|cut -d" " -f1)
        printGood "Success! Your script was updated to $versionNum; RE-RUN the script to use the new version."
    else
        printStatus "Fail! Check the log file for more info on what happened:  $rachelLog"
        echo
    fi

    # Downloading Github repo:  rachelplus
    echo; printStatus "Downloading/updating the GitHub repo:  rachelplus"
    if [[ -d $dirContentOffline/rachelplus ]]; then 
        cd $dirContentOffline/rachelplus; git fetch; git reset --hard origin
    else
        git clone https://github.com/rachelproject/rachelplus $dirContentOffline/rachelplus
    fi
    commandStatus
    printGood "Done."

    # Downloading Github repo:  contentshell
    echo; printStatus "Downloading/updating the GitHub repo:  contentshell"
    if [[ -d $dirContentOffline/contentshell ]]; then 
        cd $dirContentOffline/contentshell; git fetch; git reset --hard origin
    else
        git clone https://github.com/rachelproject/contentshell $dirContentOffline/contentshell
    fi
    commandStatus
    printGood "Done."

    # Downloading Github repo:  kalite
    echo; printStatus "Checking/downloading:  KA Lite"
    if [[ -f $dirContentOffline/$kaliteInstaller ]]; then
        # Checking user provided file MD5 against known good version
        checkMD5 $dirContentOffline/$kaliteInstaller
        if [[ $md5Status == 0 ]]; then
            # Downloading current version of KA Lite
            echo; printStatus "Downloading KA Lite Version $kaliteCurrentVersion"
            $KALITEINSTALL
            commandStatus
            mv $installTmpDir/$kaliteInstaller $dirContentOffline/$kaliteInstaller
        fi
    fi
    commandStatus
    printGood "Done."

    # Downloading kiwix
    echo; printStatus "Downloading/updating kiwix."
    wget -c $wgetOnline/downloads/public_ftp/old/z-holding/$KiwixInstaller -O $dirContentOffline/$KiwixInstaller
    commandStatus
    printGood "Done."

    # Downloading Stem module
    echo; printStatus "Downloading stem module."
    cd $dirContentOffline/offlinepkgs
    wget -c $stemURL -O $stemPkg
    commandStatus
    printGood "Done."

    # Download RACHEL modules
    echo "" > $rachelScriptsDir/rsyncInclude.list
    ## Add user input to languages they want to support
    echo; printQuestion "What language content you would like to download for OFFLINE install:"
    echo "  - [Arabic] - Arabic content"
    echo "  - [Deutsch] - German content"
    echo "  - [English] - English content"
    echo "  - [Español] - Spanish content"
    echo "  - [Français] - French content"
    echo "  - [Português] - Portuguese content"
    echo "  - [Hindi] - Hindi content"
    echo "  - [None] - Continue without content"
    echo
    select menu in "Arabic" "Deutsch" "English" "Español" "Français" "Português" "Hindi" "None"; do
        case $menu in
            Arabic) echo "#Arabic" >> $rachelScriptsDir/rsyncInclude.list; echo "ar-*" >> $rachelScriptsDir/rsyncInclude.list ;;
            Deutsch) echo "#German" >> $rachelScriptsDir/rsyncInclude.list; echo "de-*" >> $rachelScriptsDir/rsyncInclude.list ;;
            English) echo "#English" >> $rachelScriptsDir/rsyncInclude.list; echo "en-*" >> $rachelScriptsDir/rsyncInclude.list ;;
            Español) echo "#Spanish" >> $rachelScriptsDir/rsyncInclude.list; echo "es-*" >> $rachelScriptsDir/rsyncInclude.list ;;
            Français) echo "#French" >> $rachelScriptsDir/rsyncInclude.list; echo "fr-*" >> $rachelScriptsDir/rsyncInclude.list ;;
            Kannada) echo "#Kannada" >> $rachelScriptsDir/rsyncInclude.list; echo "kn-*" >> $rachelScriptsDir/rsyncInclude.list ;;
            Português) echo "#Portuguese" >> $rachelScriptsDir/rsyncInclude.list; echo "pt-*" >> $rachelScriptsDir/rsyncInclude.list ;;
            Hindi) echo "#Hindi" >> $rachelScriptsDir/rsyncInclude.list; echo "hi-*" >> $rachelScriptsDir/rsyncInclude.list ;;
            None) sleep 0 ;;
            *) printError "That really isn't an answer I am looking for..." ;;
        esac
        echo; printStatus "Language modules included:"
        sed -i '/^\x*$/d' $rachelScriptsDir/rsyncInclude.list
        sort -u $rachelScriptsDir/rsyncInclude.list > $rachelScriptsDir/rsyncInclude.list.tmp; mv $rachelScriptsDir/rsyncInclude.list.tmp $rachelScriptsDir/rsyncInclude.list
        echo "$(cat $rachelScriptsDir/rsyncInclude.list | grep \# | cut -d"#" -f2)"
        echo; printQuestion "Do you wish to select another language? (Y/n)"; read REPLY
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            break
        fi
        echo; printQuestion "What additional language would you like to select?"
        echo "1)Arabic  2)Deutsch  3)English  4)Español  5)Français  6)Português  7)Hindi  8)None"
    done
    buildRsyncModuleExcludeList
    MODULELIST=$(rsync --list-only --exclude-from "$rachelScriptsDir/rsyncExclude.list" --include-from "$rachelScriptsDir/rsyncInclude.list" --exclude '*' $RSYNCDIR/rachelmods/ | awk '{print $5}' | tail -n +2)
    echo; printStatus "Rsyncing core RACHEL content from $RSYNCDIR"
    while IFS= read -r module; do
        echo; printStatus "Downloading $module"
        rsync -rltzuv --delete-after $RSYNCDIR/rachelmods/$module $dirContentOffline/rachelmods
        commandStatus
        printGood "Done."
    done <<< "$MODULELIST"

    echo; printStatus "This is your current offline directory listing:"
    echo "- - - - - - - - - - - -" 
    ls -l $dirContentOffline/ | awk '{ print $9 }'
    echo; echo "Modules downloaded:"
    echo "- - - - - - - - - - - -" 
    ls -l $dirContentOffline/rachelmods/ | awk '{ print $9 }'
}

changePackageRepo(){
    ## sources.list - replace the package repos for more reliable ones (/etc/apt/sources.list)
    # Backup current sources.list
    cp /etc/apt/sources.list /etc/apt/sources.list.bak

    # Change the source repositories
    echo; printStatus "Locations for downloading packages:"
    echo "    US) United States"
    echo "    UK) United Kingdom"
    echo "    SG) Singapore"
    echo "    CN) China (CAP Manufacturer's Site)"
    echo; printQuestion "For the package downloads, select the location nearest you? "
    select CLASS in "US" "UK" "SG" "CN"; do
        case $CLASS in
        # US
        US)
            echo; printStatus "Downloading packages from the United States."
            $SOURCEUS
            commandStatus
            break
        ;;

        # UK
        UK)
            echo; printStatus "Downloading packages from the United Kingdom."
            $SOURCEUK
            commandStatus
            break
        ;;

        # Singapore
        SG)
            echo; printStatus "Downloading packages from Singapore."
            $SOURCESG
            commandStatus
            break
        ;;

        # China (Original)
        CN)
            echo; printStatus "Downloading packages from the China - CAP manufacturer's website."
            $SOURCECN
            commandStatus
            break
        ;;
        esac
        printGood "Done."
        break
    done    
}

downloadPackages(){
    if [[ $osName == "precise" ]]; then
        cd precise; apt-get download $debPrecisePackageList
    elif [[ $osName == "trusty" ]]; then
        cd trusty; apt-get download $debTrustyPackageList
    else
        cd precise; apt-get download $debPrecisePackageList
    fi
}

newInstall(){
    if [[ $internet == "0" ]]; then printError "New installs only run when connected to the internet...exiting."; exit 1; fi
    printHeader
    echo; printStatus "Conducting a new install of RACHEL on a CAP."

    # Show location of the log file
    echo; printStatus "Directory of RACHEL install log files with date/time stamps:"
    echo "$rachelLogDir"

    # Ask if you are ready to install
    echo; printError "WARNING:  This will completely wipe your CAP and restore to RACHEL defaults."
    echo "Any downloaded modules WILL be erased during this process."

    echo; read -p "Are you ready to start the install? (y/N) " REPLY
    if [[ $REPLY =~ ^[yY][eE][sS]|[yY]$ ]]; then

        # Create RACHEL Scripts Directory
        mkdir -p $rachelScriptsDir

        # Create the shell of the rachel-scripts.sh script - because it doesn't exist
        sed "s,%rachelScriptsLog%,$rachelScriptsLog,g" > $rachelScriptsFile << 'EOF'
#!/bin/bash
# Send output to log file
rm -f %rachelScriptsLog%
exec 1>> %rachelScriptsLog% 2>&1
exit 0
EOF

        # Fix hostname issue in /etc/hosts on v1 CAPs
        if [[ $(grep ec-server /etc/hosts) ]]; then
            echo; printStatus "Fixing hostname in /etc/hosts"
            sed -i 's/ec-server/WRTD-303N-Server/g' /etc/hosts
            printGood "Done."
        fi

        # Update package repos
        changePackageRepo

        # Download/stage GitHub files to $installTmpDir
        echo; printStatus "Downloading RACHEL install scripts for CAP to the temp folder $installTmpDir."
        ## cap-rachel-first-install-2.sh
        echo; printStatus "Downloading cap-rachel-first-install-2.sh"
        $CAPRACHELFIRSTINSTALL2
        commandStatus
        ## cap-rachel-first-install-3.sh
        echo; printStatus "Downloading cap-rachel-first-install-3.sh"
        $CAPRACHELFIRSTINSTALL3
        commandStatus

        # Delete previous setup commands from the $rachelScriptsFile
        echo; printStatus "Delete previous RACHEL setup commands from $rachelScriptsFile"
        sed -i '/cap-rachel/d' $rachelScriptsFile
        printGood "Done."

        echo; printStatus "Starting first install script...please wait patiently (about 30 secs) for first reboot."
        printStatus "The entire script (with reboots) takes 2-5 minutes."

        cat > /etc/fstab << EOF
# <filesystem> <mountpoint> <type> <options> <dump> <pass>
proc    /proc   proc    nodev,noexec,nosuid     0       0
UUID=44444444-4444-4444-4444-444444444444       /       ext4    nobootwait,errors=remount-ro    0       1
UUID=33333333-3333-3333-3333-333333333333       /boot   ext4    defaults        0       2
UUID=DEAD-BEEF  /boot/efi       vfat    utf8,umask=007,gid=46   0       0
UUID=55555555-5555-5555-5555-555555555555       /recovery       ext4    defaults        0       0
UUID=66666666-6666-6666-6666-666666666666       none    swap    sw      0       0
EOF

        # Repartition external 500GB hard drive into 3 partitions
        echo; printStatus "Backup current partition table to $rachelScriptsDir/gpt.backup"
        sgdisk -b $rachelScriptsDir/gpt.backup /dev/sda
        echo; printStatus "Unmounting any mounted partitions."
        umount /dev/sda1 /dev/sda2
        echo; printStatus "Repartitioning hard drive"
        sgdisk -p /dev/sda
        sgdisk -o /dev/sda
        parted -s /dev/sda mklabel gpt
        ## Part1: 3G for preloaded content
        #sgdisk -n 1:2048:765460479 -c 1:"preloaded" -u 1:77777777-7777-7777-7777-777777777777 -t 1:8300 /dev/sda # original
        #sgdisk -n 1:2048:+20G -c 1:"preloaded" -u 1:77777777-7777-7777-7777-777777777777 -t 1:8300 /dev/sda # RACHEL 20GB
        sgdisk -n 1:2048:+3G -c 1:"preloaded" -u 1:77777777-7777-7777-7777-777777777777 -t 1:8300 /dev/sda
        ## Part2: 17G for teacher content
        #sgdisk -n 2:765460480:-1M -c 2:"uploaded" -u 2:88888888-8888-8888-8888-888888888888 -t 2:8300 /dev/sda # original
        #sgdisk -n 2:21G:+100G -c 2:"uploaded" -u 2:88888888-8888-8888-8888-888888888888 -t 2:8300 /dev/sda # RACHEL 100GB
        sgdisk -n 2:6293504:+17G -c 2:"uploaded" -u 2:88888888-8888-8888-8888-888888888888 -t 2:8300 /dev/sda
        ## Part3: Remaining for RACHEL content
        #sgdisk -n 3:+122G:-1M -c 3:"RACHEL" -u 3:99999999-9999-9999-9999-999999999999 -t 3:8300 /dev/sda # RACHEL 343.8GB
        #sgdisk -n 3:255852544:-1M -c 3:"RACHEL" -u 3:99999999-9999-9999-9999-999999999999 -t 3:8300 /dev/sda # RACHEL 343.8GB
        sgdisk -n 3:41945088:-1M -c 3:"RACHEL" -u 3:99999999-9999-9999-9999-999999999999 -t 3:8300 /dev/sda
        sgdisk -p /dev/sda
        printGood "Done."

        # Adding the partitions in /etc/fstab
        echo; printStatus "Adding /dev/sda partitions into /etc/fstab"
        sed -i '/\/dev\/sda/d' /etc/fstab
        echo -e "/dev/sda1\t/media/preloaded\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab
        echo -e "/dev/sda2\t/media/uploaded\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab
        echo -e "/dev/sda3\t/media/RACHEL\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab
        printGood "Done."

        # Add rachel-scripts.sh startup in /etc/rc.local
        sed -i '/rachel/d' /etc/rc.local
        sudo sed -i '$e echo "# Add rachel startup scripts"' /etc/rc.local
        sudo sed -i '$e echo "bash '$rachelScriptsDir'/rachelStartup.sh&"' /etc/rc.local

        # Add lines to /etc/rc.local that will start the next script to run on reboot
        sudo sed -i '$e echo "bash '$installTmpDir'\/cap-rachel-first-install-2.sh&"' /etc/rc.local

        # Script 1 end
        echo; printGood "RACHEL CAP Install - Script 1 of 3 ended at $(date)"
        echo; printStatus "I need to reboot; once rebooted, please run the next download/install command."
        printStatus "Rebooting in 5 seconds..."
        sleep 5
        noCleanup=1
        reboot
    else
        echo; printError "User requests not to continue...exiting at $(date)"
        # Deleting the install script commands
        cleanup
    fi
}

checkContentShell(){
    # Clone or update the RACHEL content shell from GitHub
    if [[ $internet == "0" ]]; then cd $dirContentOffline; else cd $installTmpDir; fi
    echo; printStatus "Checking for pre-existing RACHEL content shell."
    if [[ ! -d $rachelWWW ]]; then
        printStatus "RACHEL content shell does not exist at $rachelWWW."
        printStatus "Cloning the RACHEL content shell from GitHub into $(pwd)"
        rm -rf contentshell # in case of previous failed install
        $GITCLONERACHELCONTENTSHELL
        cd contentshell
        cp -rf ./* $rachelWWW/
        cp -rf ./.git $rachelWWW/
    else
        if [[ ! -d $rachelWWW/.git ]]; then
            echo; printStatus "$rachelWWW exists but it wasn't installed from git; installing RACHEL content shell from GitHub."
            rm -rf contentshell # in case of previous failed install
            $GITCLONERACHELCONTENTSHELL
            cd contentshell
            cp -rf ./* $rachelWWW/ # overwrite current content with contentshell
            cp -rf ./.git $rachelWWW/ # copy over GitHub files
        else
            echo; printStatus "$rachelWWW exists; updating RACHEL content shell from GitHub."
            if [[ $internet == "1" ]]; then
                cd $rachelWWW; git fetch --all; git reset --hard origin/master
            else
                cd contentshell
                cp -rf ./* $rachelWWW/ # overwrite current content with contentshell
                cp -rf ./.git $rachelWWW/ # copy over GitHub files
            fi
        fi
    fi
    # Check for stem module
    pear clear-cache 2>/dev/null
    pecl info stem > /dev/null
    if [[ $? -ge 1 ]]; then
        cd $rachelWWW
        git checkout $gitContentShellCommit
    fi
    # Restart web server
    printStatus "Restarting lighttpd web server to activate changes."
    killall lighttpd
    printGood "Done."
}

addModule(){
    if [[ -f /tmp/module.lst ]]; then
        echo; printStatus "Your selected module list:"
        # Sort/unique the module list
        cat /tmp/module.lst
        echo; printQuestion "Do you want to use this module list?"
        read -p "    Enter (Y/n) " REPLY
        if [[ $REPLY =~ ^[Nn]$ ]]; then rm -f /tmp/module.lst; fi
    fi
    SELECTMODULE=1
#    MODULELIST=$(rsync --list-only $RSYNCDIR/rachelmods/ | egrep '^d' | awk '{print $5}' | tail -n +2)
#    MODULELIST=$(rsync --list-only --exclude-from "$rachelScriptsDir/rsyncExclude.list" --include-from "$rachelScriptsDir/rsyncInclude.list" --exclude '*' $RSYNCDIR/rachelmods/ | awk '{print $5}' | tail -n +2)
    buildRsyncModuleExcludeList
    MODULELIST=$(rsync --list-only --exclude-from "$rachelScriptsDir/rsyncExclude.list" $RSYNCDIR/rachelmods/ | awk '{print $5}' | tail -n +2)
    while [[ $SELECTMODULE == 1 ]]; do
        echo; printStatus "What RACHEL module would you like to select for download or update?"
        echo "(Ctrl-C to cancel module install)"
        echo
        select module in $MODULELIST; do 
            echo "$module" >> /tmp/module.lst
            echo; printStatus "Added module $module to the install/update cue."
            break
        done
        echo; printStatus "Your selected module list:"
        sort -u /tmp/module.lst > /tmp/module.tmp; mv /tmp/module.tmp /tmp/module.lst
        cat /tmp/module.lst
        echo; printQuestion "Do you want to select another module?"
        read -p "    Enter (y/N) " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then SELECTMODULE=1; else SELECTMODULE=0; fi
    done
    echo; printQuestion "Are you ready to install your selected modules?"
    read -p "    Enter (y/N) " REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        while read m; do
            echo; printStatus "Downloading $m"
            rsync -avz --delete-after $RSYNCDIR/rachelmods/$m $rachelWWW/modules/
            commandStatus
            # If KA Lite module, than set the kaliteUpdate "flag" to install the contentpack
            if [[ $m == *-kalite ]]; then
                touch $rachelPartition/kaliteUpdate
            fi
            printGood "Done."
        done < /tmp/module.lst
    fi
    rm -f /tmp/module.lst
}

addMultipleModules(){
    ## Add user input to languages they want to support
    echo; printStatus "The language install will install essential modules from the language(s) you choose."
    echo; printQuestion "What language content you would like to install:"
    echo "  - [English] - English content"
    echo "  - [Español] - Spanish content"
    echo "  - [Français] - French content"
    echo "  - [Full-EN-ES-FR] - The core content in English, Español, and Français"
    echo "  - [Justice] - Justice default content"
    echo "  - [Justice-OYA] - Justice Oregon Youth Authority content"
    echo "  - [Custom] - Your own custom list of modules (1 module name/line)"
    echo "  - [Exit] Install"
    echo
    select menu in "English-Core" "Español-Core" "Français-Core" "Full-EN-ES-FR" "Justice" "Justice-OYA" "Custom" "Exit"; do
        case $menu in
        English-Core) option="en_plus.modules"; break ;;
        Español-Core)  option="es_plus.modules"; break ;;
        Français-Core) option="fr_plus.modules"; break ;;
        Full-EN-ES-FR) option="full.modules"; break ;;
        Justice) option="justice.modules"; break ;;
        Justice-OYA) option="justice-oya.modules"; break ;;
        Custom) option="custom"; break ;;
        Exit) option="exit"; break ;;
        esac
    done
    # get content
    if [[ $option == "exit" ]]; then printError "Exiting on user request."; fi
    if [[ $option == "custom" ]]; then
        echo; printStatus "Here is list of your current partitions and their mountpoints (if applicable):"
        lsblk|grep -v mmc|grep -v sda
        echo; printQuestion "What is the full path to your custom module list file (example: /media/usb/customList.modules)?"; read option
        grep -qs $option /proc/mounts
        if [[ $? != 0 ]]; then
            echo; printError "The folder location does not exist!  Try mounting a partition and trying again."
        else
            contentModuleListInstall $option
            # Since we are installing the entire language (which includes KA Lite); set the kaliteUpdate flag to install contentpack
            touch $rachelPartition/kaliteUpdate
            printGood "Done."
        fi
    else
        echo; printStatus "Installing/updating content from $option"
        contentModuleListInstall $rachelWWW/scripts/"$option"
        commandStatus
        # Since we are installing the entire language (which includes KA Lite); set the kaliteUpdate flag to install contentpack
        touch $rachelPartition/kaliteUpdate
        printGood "Done."
    fi
}

contentUpdate(){
    buildRsyncModuleExcludeList
    MODULELIST=$(rsync --list-only --exclude-from "$rachelScriptsDir/rsyncExclude.list" $rachelWWW/modules/ | awk '{print $5}' | tail -n +2)
    while IFS= read -r module; do
        echo; printStatus "Downloading $module"
        rsync -rltzuv --delete-after --exclude-from "$rachelScriptsDir/rsyncExclude.list" $RSYNCDIR/rachelmods/$module $rachelWWW/modules/
        commandStatus
        # If KA Lite module, than set the kaliteUpdate "flag" to install the contentpack
        if [[ $module == *-kalite ]]; then
            touch $rachelPartition/kaliteUpdate
        fi
        printGood "Done."
    done <<< "$MODULELIST"
}

removeKALite(){
    # Removing old version
    echo; printStatus "Cleaning any previous KA Lite installation files."
    if [[ $kaliteVersionDate == 1 ]]; then
        # Stop KA Lite
        /var/ka-lite/bin/kalite stop > /dev/null 2>&1
        # Remove old startup scripts
        rm -f /etc/rc0.d/K20kalite
        rm -f /etc/rc1.d/K20kalite
        rm -f /etc/rc2.d/K80kalite
        rm -f /etc/rc3.d/K80kalite
        rm -f /etc/rc4.d/K80kalite
        rm -f /etc/rc5.d/K80kalite
        rm -f /etc/rc6.d/K20kalite
        # Remove old folders
        rm -rf /var/ka-lite /etc/ka-lite
    elif [[ $kaliteVersionDate == 2 ]]; then
        # Stop KA Lite
        sudo -H -u $kaliteUser bash -c 'kalite stop'
        # Uninstall KA Lite
        apt-get -y remove ka-lite-bundle --purge
        # Remove old folders
        rm -rf ~/.kalite
        rm -rf /etc/ka-lite
        kaliteUser="root"
    fi
}

kaliteLocationUpdate(){
    # If /root/.kalite is not a symlink, move KA Lite database to hard drive for speed increase and to prevent filling up the eMMC with user data
    echo; printStatus "Checking that .kalite directory lives on hard disk"
    if [[ ! -L /root/.kalite ]]; then
        echo; printError "Need to move .kalite from eMMC to hard disk"
        kalite stop
        echo; printStatus "Before copying KA Lite folder - here is an 'ls' of $rachelPartition"
        ls -la $rachelPartition
        echo; printStatus "Copying primary (.kalite) and backup (.kalite-backup) directory to $rachelPartition"
        if [[ -d $rachelPartition/.kalite ]]; then
            rm -rf $rachelPartition/.kalite-backup
            mv $rachelPartition/.kalite $rachelPartition/.kalite-backup
        else
            rm -rf $rachelPartition/.kalite
            cp -r /root/.kalite $rachelPartition/.kalite-backup
        fi
        mv /root/.kalite $rachelPartition/
        echo; printStatus "After copying KA Lite folder - $rachelPartition (should list folders .kalite and .kalite-backup)"
        ls -la $rachelPartition
        echo; printStatus "Symlinking /root/.kalite to /media/RACHEL/.kalite"
        ln -s $rachelPartition/.kalite /root/.kalite
        echo; printGood "Symlinking complete - /root"
    else
        echo; printGood ".kalite directory is located on the hard disk"
    fi
}

installKALite(){
    # Downloading KA Lite
    echo; printStatus "Downloading KA Lite Version $kaliteCurrentVersion"
    $KALITEINSTALL
    # Checking user provided file MD5 against known good version
    checkMD5 $installTmpDir/$kaliteInstaller
    # !!! Need to add offline method
#    # Fix for 0.6.8-0.6.9v1 versions of KA Lite
#    apt-get install python-pip
#    pip install urllib3 --upgrade
#    pip install requests --upgrade
#    rm -rf /usr/share/kalite/dist-packages/requests 
    if [[ $md5Status == 1 ]]; then
        echo; printStatus "Installing KA Lite Version $kaliteCurrentVersion"
        echo; printError "CAUTION:  When prompted, enter 'Okay' for start on boot."
        echo; mkdir -p /etc/ka-lite
        echo "root" > /etc/ka-lite/username
        # Turn off logging b/c KA Lite using a couple graphical screens; if on, causes issues
        exec &>/dev/tty
        dpkg -i $installTmpDir/$kaliteInstaller
        commandStatus
        # Turn logging back on
        exec &> >(tee -a "$rachelLog")
        kaliteLocationUpdate
        # Complete installation
        if [[ $errorCode == 0 ]]; then
            echo; printGood "KA Lite $kaliteCurrentVersion installed."
        else
            echo; printError "Something went wrong, please check the log file ($rachelLog) and try again."
            break
        fi
        update-rc.d ka-lite disable
        dpkg -s ka-lite-bundle | grep ^Version | cut -d" " -f2 > /etc/kalite-version
    fi
}

kaliteSetup(){
    echo; printStatus "Setting up KA Lite."
    # Determine version of KA Lite --> kaliteVersionDate (0=No KA LITE, 1=Version prior to 0.15, 2=Version greater than/equal to 0.15)
    if [[ -f /var/ka-lite/kalite/local_settings.py ]]; then
        kaliteVersion=$(/var/ka-lite/bin/kalite manage --version)
        echo; printError "KA Lite Version $kaliteVersion is no longer supported and should be updated."
        kaliteVersionDate=1
        printQuestion "Do you want to update to KA Lite Version $kaliteCurrentVersion?"
        read -p "    Enter (y/N) " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Remove previous KA Lite
            removeKALite
            # Install KA Lite
            installKALite
        else
            printStatus "Skipping install."
        fi
    elif [[ -f /etc/ka-lite/username ]]; then
        kaliteUser=$(cat /etc/ka-lite/username)
        kaliteVersion=$(dpkg -s ka-lite-bundle | grep ^Version | cut -d" " -f2)
        if [[ -z $kaliteVersion ]]; then kaliteVersion="UNKNOWN"; fi
        printGood "KA Lite installed under user:  $kaliteUser"
        printGood "Current KA Lite Version Installed:  $kaliteVersion"
        printGood "Lastest KA Lite Version Available:  $kaliteCurrentVersion"
        kaliteVersionDate=2
        echo; printQuestion "Do you want to upgrade or re-install KA Lite?"
        read -p "Enter (y/N) " REPLY
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Install KA Lite
            installKALite
        fi
    else
        echo; printStatus "It doesn't look like KA Lite is installed; installing now."
#        kaliteUser="ka-lite"
        kaliteUser="root"
        kaliteVersionDate=0
        # Remove previous KA Lite
        removeKALite
        # Install KA Lite
        installKALite
    fi

    # Configure ka-lite
    echo; printStatus "KA Lite content settings file:  $kaliteSettings"
    printStatus "KA Lite content directory:  $kaliteContentDir"
    sed -i '/^CONTENT_ROOT/d' $kaliteSettings
    sed -i '/^DATABASES/d' $kaliteSettings
    echo 'CONTENT_ROOT = "/media/RACHEL/kacontent"' >> $kaliteSettings

    # Install module for RACHEL index.php
    echo; printStatus "Syncing English KA Lite RACHEL module"
    rsync -avz --delete-after $RSYNCDIR/rachelmods/en-kalite $rachelWWW/modules/

    # Download contentpacks
    downloadKAContentPacks

    # Symlink the KA Lite database and video files
    kaliteCheckFiles

    # Delete previous setup commands from /etc/rc.local (not used anymore)
    sudo sed -i '/ka-lite/d' /etc/rc.local
    sudo sed -i '/sleep 20/d' /etc/rc.local

    # Delete previous setup commands from the $rachelScriptsFile
#    echo; printStatus "Setting up KA Lite to start at boot..."
    sudo sed -i '/ka-lite/d' $rachelScriptsFile
    sudo sed -i '/kalite/d' $rachelScriptsFile
    sudo sed -i '/sleep/d' $rachelScriptsFile

    # Start KA Lite at boot time
    sudo sed -i '$e echo "# Start kalite at boot time"' $rachelScriptsFile
    sudo sed -i '$e echo "sleep 5 #kalite"' $rachelScriptsFile
    sudo sed -i '$e echo "sudo /usr/bin/kalite start"' $rachelScriptsFile
    printGood "Done."
}

kaliteCheckFiles(){
    # Stopping KA Lite
    echo; printStatus "Stopping kalite"
    sudo kalite stop
    # clear out possible old videos taking up space
    echo; printStatus "Clearing old video content"
    rm -rf /media/RACHEL/kacontent
    mkdir /media/RACHEL/kacontent
    # clear out old database files
    rm -rf /root/.kalite/database/content_khan_*.sqlite
    rm -rf /root/.kalite/content_khan_*.sqlite
    # check/install kalite content packs (this covers subtitles)
    if [[ -f $rachelPartition/kaliteUpdate ]]; then
        echo; printStatus "Installing content packs"
        # Install new format contentpacks
        for i in `ls -1 --hide=*-contentpack.zip $rachelWWW/modules/*-kalite/`; do
            if [[ $i =~ ([a-z]{2}).zip ]]; then
                lang=${BASH_REMATCH[1]}
                kalite manage retrievecontentpack local $lang $rachelWWW/modules/"$lang"-kalite/"$lang".zip
            fi
        done
        rm -f $rachelPartition/kaliteUpdate
    fi
    # Creating symlinks of all KA Lite video files in the KA Lite content folder  
    echo; printStatus "Creating symlinks of all KA Lite video files in the KA Lite content folder."
    find $rachelWWW/modules/*-kalite/content -name "*.mp4" -exec ln -sf {} $kaliteContentDir 2>/dev/null \;
    printGood "Done."
    # Copying KA database file to KA Lite database folder
    echo; printStatus "Symlinking all KA database module files to the actual KA Lite database folder."
    find $rachelWWW/modules/*-kalite -name "*.sqlite" -exec ln -sf {} /root/.kalite/database/ \;
    # Starting KA Lite
    echo; sudo kalite start
    # Update KA Lite version
    dpkg -s ka-lite-bundle | grep ^Version | cut -d" " -f2 > /etc/kalite-version
    printGood "Done."
}

kaliteDiagnostic(){
    kalite diagnose; echo
}

downloadKAContent(){
    # Downloading KA Lite content
    echo "" > $rachelScriptsDir/rsyncInclude.list
    ## Add user input to languages they want to support
    echo; printQuestion "What language content you would like to download for KA Lite:"
    echo "  - [English] - English content"
    echo "  - [Español] - Spanish content"
    echo "  - [Français] - French content"
    echo "  - [Skip] downloading language content"
    echo
    select menu in "English" "Español" "Français" "Skip"; do
        case $menu in
        English)
            lang="en"
            break
        ;;
        Español)
            lang="es"
            break
        ;;
        Français)
            lang="fr"
            break
        ;;
        Skip)
            lang=""
            break
        ;;
        esac
    done
    if [[ ! -z $lang ]]; then
        echo; printStatus "Downloading KA Lite content from $RSYNCDIR"
        rsync -Pavz --include *.mp4 --exclude assessment --exclude locale $RSYNCDIR/rachelmods/$lang-kalite/content/ /media/RACHEL/rachel/modules/$lang-kalite/content
        # echo; printStatus "Downloading KA Lite contentpack"
        # rsync -Pavz $RSYNCDIR/rachelmods/$lang-kalite/$lang.zip /media/RACHEL/rachel/modules/$lang-kalite/$lang.zip
    fi
    touch $rachelPartition/kaliteUpdate
    kaliteCheckFiles
    commandStatus
    printGood "Done."
}

downloadKAContentPacks(){
    for i in `ls $rachelWWW/modules/*-kalite/rachel-index.php`; do
        if [[ $i =~ ([a-z]{2})-kalite ]]; then
            lang=${BASH_REMATCH[1]}
            echo; printStatus "Downloading KA Lite contentpack: $lang"
            rsync -Pavz $RSYNCDIR/rachelmods/$lang-kalite/$lang.zip /media/RACHEL/rachel/modules/$lang-kalite/$lang.zip
        fi
        commandStatus
        # Soft link kalite sqlite language files
        rm -f $kaliteDir/content_khan_$lang.sqlite
        rm -f $kaliteDir/database/content_khan_$lang.sqlite
        ln -s $rachelWWW/modules/$lang-kalite/content_khan_$lang.sqlite $kaliteDir/database/content_khan_$lang.sqlite
        # Soft link old contentpack name to new
        rm -f $rachelWWW/modules/$lang-kalite/$lang-contentpack.zip 2>/dev/null
        ln -s $rachelWWW/modules/$lang-kalite/$lang.zip $rachelWWW/modules/$lang-kalite/$lang-contentpack.zip 2>/dev/null
    done
    touch $rachelPartition/kaliteUpdate
    printGood "Done."
}

checkCaptivePortal(){
    errorCode=0
    # Download RACHEL Captive Portal files
    echo; printStatus "Checking Captive Portal files."
    if [[ ! -f $rachelWWW/captiveportal-redirect.php ]]; then
        echo; printStatus "Downloading captiveportal-redirect.php."
        cd $rachelWWW
        $CAPTIVEPORTALREDIRECT
        commandStatus
    fi
    if [[ ! -f $rachelWWW/pass_ticket.shtml ]]; then
        echo; printStatus "Downloading pass_ticket.shtml."
        cd $rachelWWW
        $PASSTICKETSHTML
        commandStatus
    fi
    if [[ ! -f $rachelWWW/redirect.shtml ]]; then
        echo; printStatus "Downloading redirect.shtml."
        cd $rachelWWW
        $REDIRECTSHTML
        commandStatus
    fi
    if [[ ! -f $rachelWWW/art/RACHELbrandLogo-captive.png ]]; then
        cd $rachelWWW/art
        echo; printStatus "Downloading RACHELbrandLogo-captive.png."
        $RACHELBRANDLOGOCAPTIVE
        commandStatus
    fi
    if [[ ! -f $rachelWWW/art/HFCbrandLogo-captive.jpg ]]; then
        cd $rachelWWW/art
        echo; printStatus "Downloading HFCbrandLogo-captive.jpg."
        $HFCBRANDLOGOCAPTIVE
        commandStatus
    fi
    if [[ ! -f $rachelWWW/art/WorldPossiblebrandLogo-captive.png ]]; then
        cd $rachelWWW/art
        echo; printStatus "Downloading WorldPossiblebrandLogo-captive.png."
        $WORLDPOSSIBLEBRANDLOGOCAPTIVE
        commandStatus
    fi
    # Check executable settings
    chmod +x $rachelWWW/pass_ticket.shtml
    chmod +x $rachelWWW/redirect.shtml
    if [[ $errorCode == 1 ]]; then 
        printError "Something may have gone wrong; check $rachelLog for errors."
    else 
        printGood "Done."
    fi
}

updateModuleNames(){
    # Checking for old RACHEL file/folder structures
    cd $rachelWWW/modules
    mv ap_didact_es es-ap_didact 2>/dev/null
    mv ebooks-en en-ebooks 2>/dev/null
    mv guias_es es-guias 2>/dev/null
    mv kalite-es es-kalite 2>/dev/null
    mv musictheory en-musictheory 2>/dev/null
    mv scratch en-scratch 2>/dev/null
    mv asst_medical en-asst_medical 2>/dev/null
    mv ebooks-es es-ebooks 2>/dev/null
    mv hesperian_health en-hesperian_health 2>/dev/null
    mv local_content en-local_content 2>/dev/null
    mv olpc en-olpc 2>/dev/null
    mv soluciones_es es-soluciones 2>/dev/null
    mv wikisource-es es-wikisource 2>/dev/null
    mv bibliofilo-es es-bibliofilo 2>/dev/null
    mv edison en-edison 2>/dev/null
    mv hesperian_health-es es-hesperian_health 2>/dev/null
    mv local_content-es es-local_content 2>/dev/null
    mv understanding_algebra en-understanding_algebra 2>/dev/null
    mv wikiversity-es es-wikiversity 2>/dev/null
    mv biblioteca-es es-biblioteca 2>/dev/null
    mv GCF2015 en-GCF2015 2>/dev/null
    mv iicba en-iicba 2>/dev/null
    mv math_expression en-math_expression 2>/dev/null
    mv powertyping en-powertyping 2>/dev/null
    mv vedoque-es es-vedoque 2>/dev/null
    mv wikivoyage-es es-wikivoyage 2>/dev/null
    mv ck12 en-ck12 2>/dev/null
    mv GCF2015-es es-GCF2015 2>/dev/null
    mv infonet en-infonet 2>/dev/null
    mv medline_plus en-medline_plus 2>/dev/null
    mv practical_action en-practical_action 2>/dev/null
    mv wikibooks-es es-wikibooks 2>/dev/null
    mv wiktionary-es es-wiktionary 2>/dev/null
    mv cnbguatemala-es es-cnbguatemala 2>/dev/null
    mv guatemala-es es-guatemala 2>/dev/null
    mv ka-lite en-kalite 2>/dev/null
    mv medline_plus-es es-medline_plus 2>/dev/null
    mv windows_apps en-windows_apps 2>/dev/null
    mv afristory en-afristory 2>/dev/null
    mv fr_banner fr-banner 2>/dev/null
    mv fr_english fr-english 2>/dev/null
    mv wiki_en en-wikipedia 2>/dev/null
    mv fr_ka_lite fr-kalite 2>/dev/null
    mv fr_wiki fr-wikipedia 2>/dev/null
    mv fr_wikib fr-wikibooks 2>/dev/null
    mv fr_wikis fr-wikisource 2>/dev/null
    mv fr_wikiv fr-wikiversity 2>/dev/null
    mv fr_wikivoy fr-wikivoyage 2>/dev/null
    mv fr_wikt fr-wiktionary 2>/dev/null
    mv law_library en-law_library 2>/dev/null
    mv oya en-oya 2>/dev/null
    mv PhET en-PhET 2>/dev/null
    mv TED en-TED 2>/dev/null
    mv radiolab en-radiolab 2>/dev/null
    if [[ -d wikipedia_for_schools-es/wp ]]; then
        mv wikipedia_for_schools-es es-wikipedia_for_schools-nonzim
    else
        mv wikipedia_for_schools-es es-wikipedia_for_schools 2>/dev/null
    fi
    if [[ -d wikipedia_for_schools/wp ]]; then
        mv wikipedia_for_schools en-wikipedia_for_schools-nonzim
    else
        mv wikipedia_for_schools en-wikipedia_for_schools 2>/dev/null
    fi

    # Check for previous Kiwix zim installs
    mkdir -p $rachelPartition/kiwix/data/content/
    cd $rachelPartition/kiwix/data/content/
    ## Move these zim files
    for f in wikipedia_en_all_*; do
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/en-wikipedia/data/content/ && mv wikipedia_en_all_* $rachelWWW/modules/en-wikipedia/data/content/
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/en-wikipedia/data/index/ && mv $rachelPartition/kiwix/data/index/wikipedia_en_all_* $rachelWWW/modules/en-wikipedia/data/index/
        break
    done
    for f in wikipedia_en_for_schools_*; do
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/en-wikipedia_for_schools/data/content/ && mv wikipedia_en_for_schools_* $rachelWWW/modules/en-wikipedia_for_schools/data/content/
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/en-wikipedia_for_schools/data/index/ && mv $rachelPartition/kiwix/data/index/wikipedia_en_for_schools_* $rachelWWW/modules/en-wikipedia_for_schools/data/index/
        break
    done
    for f in wikibooks_fr_all_*; do
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/fr-wikibooks/data/content/ && mv wikibooks_fr_all_* $rachelWWW/modules/fr-wikibooks/data/content/
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/fr-wikibooks/data/index/ && mv $rachelPartition/kiwix/data/index/wikibooks_fr_all_* $rachelWWW/modules/fr-wikibooks/data/index/
        break
    done
    for f in wikipedia_fr_all_*; do
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/fr-wikipedia/data/content/ && mv wikipedia_fr_all_* $rachelWWW/modules/fr-wikipedia/data/content/
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/fr-wikipedia/data/index/ && mv $rachelPartition/kiwix/data/index/wikipedia_fr_all_* $rachelWWW/modules/fr-wikipedia/data/index/
        break
    done
    for f in wikisource_fr_all_*; do
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/fr-wikisource/data/content/ && mv wikisource_fr_all_* $rachelWWW/modules/fr-wikisource/data/content/
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/fr-wikisource/data/index/ && mv $rachelPartition/kiwix/data/index/wikisource_fr_all_* $rachelWWW/modules/fr-wikisource/data/index/
        break
    done
    for f in wikiversity_fr_all_*; do
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/fr-wikiversity/data/content/ && mv wikiversity_fr_all_* $rachelWWW/modules/fr-wikiversity/data/content/
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/fr-wikiversity/data/index/ && mv $rachelPartition/kiwix/data/index/wikiversity_fr_all_* $rachelWWW/modules/fr-wikiversity/data/index/
        break
    done
    for f in wikivoyage_fr_all_*; do
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/fr-wikivoyage/data/content/ && mv wikivoyage_fr_all_* $rachelWWW/modules/fr-wikivoyage/data/content/
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/fr-wikivoyage/data/index/ && mv $rachelPartition/kiwix/data/index/wikivoyage_fr_all_* $rachelWWW/modules/fr-wikivoyage/data/index/
        break
    done
    for f in wiktionary_fr_all_*; do
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/fr-wiktionary/data/content/ && mv wiktionary_fr_all_* $rachelWWW/modules/fr-wiktionary/data/content/
        [ -e "$f" ] && mkdir -p $rachelWWW/modules/fr-wiktionary/data/index/ && mv $rachelPartition/kiwix/data/index/wiktionary_fr_all_* $rachelWWW/modules/fr-wiktionary/data/index/
        break
    done
    ## Remove these
    rm -rf $rachelPartition/kiwix/data/content/wikipedia_en_ray_charles_2015-06.zim $rachelPartition/kiwix/data/index/wikipedia_en_ray_charles_2015-06.zim.idx
}

repairRachelScripts(){
    # Fixing $rachelScriptsFile
    echo; printStatus "Updating $rachelScriptsFile"
    mkdir -p $rachelScriptsDir
    # Add rachel-scripts.sh script
    sed "s,%rachelScriptsLog%,$rachelScriptsLog,g;s,%rachelPartition%,$rachelPartition,g" > $rachelScriptsFile << 'EOF'
#!/bin/bash
# Send output to log file
rm -f %rachelScriptsLog%
exec 1>> %rachelScriptsLog% 2>&1
echo $(date) - Starting RACHEL script
# Run once
if [[ -f %rachelPartition%/runonce.sh ]]; then
    echo $(date) - Running "runonce" script
    bash %rachelPartition%/runonce.sh
fi
exit 0
EOF

    # Add rachel-scripts.sh startup in /etc/rc.local
    sed -i '/RACHEL/d' /etc/rc.local
    sed -i '/rachel/d' /etc/rc.local
    sudo sed -i '$e echo "# Add rachel startup scripts"' /etc/rc.local
    sudo sed -i '$e echo "bash '$rachelScriptsFile'&"' /etc/rc.local

    # Check/re-add Kiwix
    if [[ -d /var/kiwix ]]; then
        echo; printStatus "Setting up Kiwix to start at boot..."
        # Remove old kiwix boot lines from /etc/rc.local
        sed -i '/kiwix/d' /etc/rc.local
        # Clean up current rachel-scripts.sh file
        sed -i '/kiwix/d' $rachelScriptsFile
        # Add lines to /etc/rc.local that will start kiwix on boot
        sed -i '$e echo "\# Start kiwix on boot"' $rachelScriptsFile
        sed -i '$e echo "echo \\$(date) - Starting kiwix"' $rachelScriptsFile
        sed -i '$e echo "\/var\/kiwix\/bin\/kiwix-serve --daemon --port=81 --library \/media\/RACHEL\/kiwix\/data\/library\/library.xml"' $rachelScriptsFile
        printGood "Done."
    fi

    # Add battery monitoring start line 
    if [[ -f $rachelScriptsDir/batteryWatcher.sh ]]; then
        # Clean rachel-scripts.sh
        sed -i '/battery/d' $rachelScriptsFile
        sed -i '$e echo "# Start battery monitoring"' $rachelScriptsFile
        sed -i '$e echo "echo \\$(date) - Starting battery monitor"' $rachelScriptsFile
        sed -i '$e echo "bash '$rachelScriptsDir'/batteryWatcher.sh&"' $rachelScriptsFile
    fi

    # Check for disable reset button flag
    echo; printStatus "Added check to disable the reset button"
    sed -i '$e echo "\# Check if we should disable reset button"' $rachelScriptsFile
    sed -i '$e echo "echo \\$(date) - Checking if we should disable reset button"' $rachelScriptsFile
    sed -i '$e echo "if [[ -f '$rachelScriptsDir'/disable_reset ]]; then killall reset_button; echo \\"Reset button disabled\\"; fi"' $rachelScriptsFile
    printGood "Done."

    # Check/enable/disable Kiwix library modules
    if [[ -f $rachelScriptsDir/rachelKiwixStart.sh ]]; then
        echo; printStatus "Updating the Kiwix library"
        sed -i '$e echo "\# Updating the Kiwix library"' $rachelScriptsFile
        sed -i '$e echo "echo \\$(date) - Updating the Kiwix Library"' $rachelScriptsFile
        sed -i '$e echo "bash '$rachelScriptsDir'/rachelKiwixStart.sh"' $rachelScriptsFile
        printGood "Done."
    fi

    # Check/enable ESP module
    if [[ -f $rachelScriptsDir/checker.php ]]; then
        echo; printStatus "Add ESP startup code"
        sed -i '$e echo "# start rachel-esp checker"' $rachelScriptsFile
        sed -i '$e echo "echo \\$(date) - Starting checker.php for rachel-esp"' $rachelScriptsFile
        sed -i '$e echo "service esp start"' $rachelScriptsFile
        printGood "Done."
    fi

    # Check for disable wifi flag
    echo; printStatus "Added check to disable wifi"
    sed -i '$e echo "\# Check if we should disable wifi"' $rachelScriptsFile
    sed -i '$e echo "echo \\$(date) - Checking if we should disable wifi"' $rachelScriptsFile
    sed -i '$e echo "if [[ -f '$rachelScriptsDir'/disable_wifi ]]; then sleep 5; ifconfig wlan0 down; echo \\"Wifi disabled\\"; fi"' $rachelScriptsFile
    printGood "Done."

    # Check for KA Lite module
    if [[ -d $kaliteDir ]]; then
        # Delete previous setup commands from /etc/rc.local (not used anymore)
        sudo sed -i '/ka-lite/d' /etc/rc.local
        sudo sed -i '/sleep/d' /etc/rc.local
        # Delete previous setup commands from the $rachelScriptsFile
        sudo sed -i '/ka-lite/d' $rachelScriptsFile
        sudo sed -i '/kalite/d' $rachelScriptsFile
        sudo sed -i '/sleep/d' $rachelScriptsFile
        echo; printStatus "Setting up KA Lite to start at boot..."
        # Start KA Lite at boot time
        sudo sed -i '$e echo "# Start kalite at boot time"' $rachelScriptsFile
        sed -i '$e echo "echo \\$(date) - Starting kalite"' $rachelScriptsFile
        sudo sed -i '$e echo "sleep 15 #kalite"' $rachelScriptsFile
        sudo sed -i '$e echo "service ka-lite start #kalite"' $rachelScriptsFile
        printGood "Done."
    fi

    # Add RACHEL script complete line
    sed -i '$e echo "echo \\$(date) - RACHEL startup completed"' $rachelScriptsFile
    echo; printGood "Rachel start script update complete."
}

repairFirmware(){
    printHeader
    echo; printStatus "Repairing your CAP after a firmware upgrade."
    cd $installTmpDir

    # Download/update to latest RACHEL lighttpd.conf
    echo; printStatus "Downloading latest lighttpd.conf"
    ## lighttpd.conf - RACHEL version (I don't overwrite at this time due to other dependencies and ensuring the file downloads correctly)
    $LIGHTTPDFILE
    commandStatus
    if [[ $errorCode == 1 ]]; then
        printError "The lighttpd.conf file did not download correctly; check log file (/var/log/rachel/rachel-install.tmp) and try again."
        echo; break
    else
        mv $installTmpDir/lighttpd.conf /usr/local/etc/lighttpd.conf
    fi
    printGood "Done."

    # Reapply /etc/fstab entry for /media/RACHEL
    echo; printStatus "Adding /dev/sda3 into /etc/fstab"
    sed -i '/\/dev\/sda3/d' /etc/fstab
    echo -e "/dev/sda3\t/media/RACHEL\t\text4\tauto,nobootwait 0\t0" >> /etc/fstab
    printGood "Done."

    # Fixing $rachelScriptsFile
    repairRachelScripts

    # Check captive portal files
    checkCaptivePortal

    # Remove outdated startup script
    rm -f /root/iptables-rachel.sh

    # Delete previous setwanip commands from /etc/rc.local - not used anymore
    echo; printStatus "Deleting previous setwanip.sh script from /etc/rc.local"
    sed -i '/setwanip/d' /etc/rc.local
    rm -f /root/setwanip.sh
    printGood "Done."

    # Delete previous iptables commands from /etc/rc.local
    echo; printStatus "Deleting previous iptables script from /etc/rc.local"
    sed -i '/iptables/d' /etc/rc.local
    printGood "Done."

    echo; printGood "RACHEL CAP Repair Complete."
    sudo mv $rachelLog $rachelLogDir/rachel-repair-$timestamp.log
    echo; printGood "Log file saved to: $rachelLogDir/rachel-repair-$timestamp.log"
    cleanup
    rebootCAP
}

repairKalite(){
    echo; printStatus "Fixing KA-Lite"
    # Fixing KA-Lite 
    cp -f /media/RACHEL/kacontent/assessmentitems.sqlite /usr/share/kalite/assessment/khan/.
    sed -i '/assessmentitems.sqlite/d' /root/.kalite/settings.py
    # Turn loggin off for compatibility
    exec &>/dev/tty
    # Restart kalite to use the new assessmentitems.sqlite location
    echo; kalite stop
    echo; kalite manage setup
    # Show diagnostic info
    echo; kalite diagnose
    # Turn logging back on
    loggingStart
    echo; printGood "Done."
}

repairBugs(){
    # Check/update package repo
    changePackageRepo
    
    # Update rachel folder structure
    updateRachelFolders

    # Update modules names to new structure
    updateModuleNames

    # Update to the latest contentshell
    # installPkgUpdates
    checkContentShell

    # Update KA Lite root directory location
    kaliteLocationUpdate

    # Check soft links for kalite content files
    rm -f $kaliteDir/content_khan_*.sqlite
    rm -f $kaliteDir/database/content_khan_*.sqlite
    ln -s $rachelWWW/modules/en-kalite/content_khan_en.sqlite $kaliteDir/database/content_khan_en.sqlite 2>/dev/null
    ln -s $rachelWWW/modules/es-kalite/content_khan_es.sqlite $kaliteDir/database/content_khan_es.sqlite 2>/dev/null
    ln -s $rachelWWW/modules/fr-kalite/content_khan_fr.sqlite $kaliteDir/database/content_khan_fr.sqlite 2>/dev/null
    touch $rachelPartition/kaliteUpdate
    kaliteCheckFiles

    # Add local content module
    echo; printStatus "Adding the local content module."
    rsync -avz $RSYNCDIR/rachelmods/en-local_content $rachelWWW/modules/
    printGood "Done."

    # Add battery monitor
    ## Check for old batteryWatcher processes
    batteryPID=$(ps aux |grep "/root/batteryWatcher.sh" | grep -v grep | awk '{ print $2 }')
    if [[ ! -z $batteryPID ]]; then kill -9 $batteryPID; fi
    installBatteryWatch

    # Add Kiwix repair library script
    createKiwixRepairScript
    # restart kiwix
    /root/rachel-scripts/rachelKiwixStart.sh

    # Rebuild rachelStartup.sh file
    repairRachelScripts

    # There is one miconfigured index.htmlf that needs to be fixed on the harddrive
    if [[ -d $rachelWWW/modules/fr_wiki/index.htmlf ]]; then
        sed -i 's/\-03/\-11/g' $rachelWWW/modules/fr_wiki/index.htmlf
    fi

    # Misconfiguration in "Soluciones Prácticas" module
    if [[ -d $rachelWWW/modules/es-soluciones ]]; then
        echo; printStatus "Fixing links in module:  Soluciones Prácticas"
        sed -i 's/soluciones\/index.html/index.html/g' $rachelWWW/modules/es-soluciones/index.htmlf
        sed -i 's/soluciones\/index.html/index.html/g' $rachelWWW/modules/es-soluciones/index.html
        printGood "Done."
    fi

    # Fix the multiple cgi.fix lines in php.ini
    grep -q '^cgi.fix_pathinfo = 1' /etc/php5/cgi/php.ini && sed -i '/^cgi.fix_pathinfo = 1/d' /etc/php5/cgi/php.ini; echo 'cgi.fix_pathinfo = 1' >> /etc/php5/cgi/php.ini

    # Fix GCF links
    if [[ -d $rachelWWW/modules/GCF2015 ]]; then
        echo; printStatus "Fixing GCF index.htmlf links"
        sed -i 's/digital_lifestyle.html/digitalskills.html/g' $rachelWWW/modules/GCF2015/index.htmlf
        sed -i 's/job.html/jobsearch.html/g' $rachelWWW/modules/GCF2015/index.htmlf
        printGood "Done."
    fi
}

installPkgUpdates(){
    pkgInstaller(){
        dpkg -i *.deb
        # apt-get -fy install
        pear clear-cache 2>/dev/null
        pecl info stem > /dev/null
        if [[ $? -ge 1 ]]; then 
            echo; printStatus "Installing the stem module."
            currentDir=$(pwd)
            if [[ internet="1" ]]; then
                echo; printStatus "Downloading stem module."
                cd $rachelPartition/offlinepkgs
                wget -c $stemURL -O $stemPkg
            fi
            echo "\n" | pecl install $stemPkg
            echo '; configuration for php stem module' > /etc/php5/conf.d/stem.ini
            echo 'extension=stem.so' >> /etc/php5/conf.d/stem.ini
        fi
    }
    mv /etc/init/procps.conf /etc/init/procps.conf.old 2>/dev/null # otherwise quite a lot of pkgs won't install
    echo; printStatus "Updating pgp keys."
    for i in $(echo $gpgKeys); do $GPGKEY$i 2>/dev/null; done
    echo; printStatus "Updating packages."
    if [[ $internet == 1 ]]; then
        if [[ $osName == "precise" ]]; then
            apt-get update; apt-get -y install python-software-properties; apt-add-repository -y ppa:relan/exfat
        fi
        if [[ -d $rachelPartition ]]; then
            mkdir -p $rachelPartition/offlinepkgs/precise $rachelPartition/offlinepkgs/trusty; cd $rachelPartition/offlinepkgs
        else
            mkdir -p $rachelPartition/offlinepkgs/precise $rachelPartition/offlinepkgs/trusty; cd $installTmpDir/offlinepkgs
        fi
        apt-get update
        downloadPackages
        pkgInstaller
    elif [[ -d $dirContentOffline/offlinepkgs ]]; then
        echo $osName
        if [[ $osName == "trusty" ]]; then cd $dirContentOffline/offlinepkgs/trusty; else cd $dirContentOffline/offlinepkgs/precise; fi
        pkgInstaller
    else
        printError "Packages not found for installation."
    fi
}

usbRecovery(){
    echo; printGood "Script set for 'OFFLINE' mode."
    internet="0"
    noCleanup="1"
    dirContentOffline="/media/RACHEL"
    offlineVariables
    # Update rachel folder structure
    updateRachelFolders
    # Update modules names to new structure
    updateModuleNames
    # Add runonce.sh script that will run on reboot
    sed "s,%dirContentOffline%,$dirContentOffline,g;s,%rachelWWW%,$rachelWWW,g;s,%stemPkg%,$stemPkg,g;s,%gitContentShellCommit%,$gitContentShellCommit,g;s,%rachelLogDir%,$rachelLogDir,g;s,%rachelLogFile%,$rachelLogFile,g;s,%rachelPartition%,$rachelPartition,g" > $rachelPartition/runonce.sh << 'EOF'
#!/bin/bash
. /media/RACHEL/cap-rachel-configure.sh --source-only
exec 1>> $rachelLog 2>&1
echo "[+] Starting USB Recovery runonce script - $(date)"
# Run rachel startup script repair
repairRachelScripts
# Run kalite check
kaliteCheckFiles
# Copy latest cap-rachel-configure.sh script to /root
echo; echo "[*] Copying USB version of cap-rachel-configure.sh to /root"
cp $rachelPartition/cap-rachel-configure.sh /root/
chmod +x /root/cap-rachel-configure.sh
# Add symlinks - when running the Recovery USB, symlinks are not permitted on FAT partitions, so we have to create them after recovery runs
echo; echo "[+] Add symlink for en-local_content."
ln -s $rachelWWW/modules/en-local_content/rachel-index.php $rachelWWW/modules/en-local_content/index.htmlf 2>/dev/null
# Update to the latest contentshell
echo; echo "[+] Updating to latest contentshell."
cd $rachelPartition/contentshell
cp -rf ./* $rachelWWW/ # overwrite current content with contentshell
cp -rf ./.git $rachelWWW/ # copy over GitHub files
mv /etc/init/procps.conf /etc/init/procps.conf.old 2>/dev/null # otherwise quite a pkgs won't install
rm -f $rachelWWW/en_all.sh $rachelWWW/en_justice.sh $rachelWWW/modules/ka-lite $rachelWWW/modules/local_content # clean up old files
pear clear-cache 2>/dev/null
pecl info stem 
if [[ $? == 0 ]]; then 
    echo; echo "[+] Installing the stem module."
    printf "\n" | pecl install $rachelPartition/offlinepkgs/$stemPkg
    # Add support for stem extension
    echo '; configuration for php stem module' > /etc/php5/conf.d/stem.ini
    echo 'extension=stem.so' >> /etc/php5/conf.d/stem.ini
else
    cd $rachelWWW
    git checkout $gitContentShellCommit
fi
# Check KA Lite admin directory location
# If /root/.kalite is not a symlink, move KA Lite database to hard drive for speed increase and to prevent filling up the eMMC with user data
echo; echo "[+] Checking that .kalite directory lives on hard disk"
if [[ ! -L /root/.kalite ]]; then
    echo; echo "[*] Need to move .kalite from eMMC to hard disk"
    sudo kalite stop
    echo; echo "[*] Before copying KA Lite folder - here is an 'ls' of $rachelPartition"
    ls -la $rachelPartition
    echo; echo "[+] Copying primary (.kalite) and backup (.kalite-backup) directory to $rachelPartition"
    if [[ -d $rachelPartition/.kalite ]]; then
        rm -rf $rachelPartition/.kalite-backup
        mv $rachelPartition/.kalite $rachelPartition/.kalite-backup
    else
        rm -rf $rachelPartition/.kalite
        cp -r /root/.kalite $rachelPartition/.kalite-backup
    fi
    mv /root/.kalite $rachelPartition/
    echo; echo "[*] After copying KA Lite folder - $rachelPartition (should list folders .kalite and .kalite-backup)"
    ls -la $rachelPartition
    echo; echo "[+] Symlinking /root/.kalite to /media/RACHEL/.kalite"
    ln -s $rachelPartition/.kalite /root/.kalite
    echo; echo "[+] Symlinking complete - /root"
else
    echo; echo "[+] .kalite directory is located on the hard disk"
fi
# Update Kiwix version
cat /var/kiwix/application.ini | grep ^Version | cut -d= -f2 > /etc/kiwix-version
# Update KA Lite version
dpkg -s ka-lite-bundle | grep ^Version | cut -d" " -f2 > /etc/kalite-version
# Update RACHEL installer version
mv $rachelPartition/rachelinstaller-version /etc/rachelinstaller-version
# FINISHED
echo "[+] Completed USB Recovery runonce script - $(date)"
# Add header/date/time to install log file
timestamp=$(date +"%b-%d-%Y-%H%M%Z")
mv $rachelLog $rachelLogDir/rachel-runonce-$timestamp.log
# Remove self; reboot
rm -- "$0"
sleep 5; shutdown -r now
EOF
}

installBatteryWatch(){
    echo; printStatus "Creating $rachelScriptsDir/batteryWatcher.sh"
    echo "This script will monitor the battery charge level and shutdown this device with less than 3% battery charge."
    # Create batteryWatcher script
    cat > $rachelScriptsDir/batteryWatcher.sh << 'EOF'
#!/bin/bash
while :; do
    if [[ $(cat /tmp/chargeStatus) -lt -200 ]]; then
        if [[ $(cat /tmp/batteryLastChargeLevel) -lt 3 ]]; then
            echo "$(date) - Low battery shutdown" >> /var/log/rachel/shutdown.log
            kalite stop
            shutdown -h now
            exit 0
        fi
    fi
    sleep 10
done
EOF
    chmod +x $rachelScriptsDir/batteryWatcher.sh
    # Check and kill other scripts running
    printStatus "Checking for and killing previously run battery monitoring scripts"
    pid=$(ps aux | grep -v grep | grep "/bin/bash $rachelScriptsDir/batteryWatcher.sh" | awk '{print $2}')
    if [[ ! -z $pid ]]; then kill $pid; fi
    # Start script
    $rachelScriptsDir/batteryWatcher.sh&
    printStatus "Logging shutdowns to /var/log/rachel/shutdown.log"
    printGood "Script started...monitoring battery."
}

disableResetButton(){
    echo; printStatus "Disabling the reset button"
    pid=$(ps aux | grep -v grep | grep "reset_button" | awk '{print $2}')
    if [[ ! -z $pid ]]; then 
        kill $pid
        echo; printGood "Reset button disabled; do not delete the file $rachelScriptsDir/disable_reset unless"
        echo "    you want to re-enable the reset button."
    else 
        echo; printGood "Reset button already disabled."
    fi
    echo "Reset button disabled.  Delete this file to re-enable." > $rachelScriptsDir/disable_reset
}

disableWifi(){
    echo; printStatus "Disabling wifi"
    ifconfig wlan0 down
    echo "Wifi disabled.  Delete this file to re-enable." > $rachelScriptsDir/disable_wifi
    # Check that the rachelScripts.sh file is updated
    repairRachelScripts    
}

enableWifi(){
    echo; printStatus "Enabling wifi"
    /etc/WiFi_Setting.sh
    rm -f $rachelScriptsDir/disable_wifi
}

updateRachelFolders(){
    mkdir -p $rachelScriptsDir
    # Move rachel log dir
    if [[ -d $rachelLogDir ]] && [[ -d /var/log/RACHEL ]]; then cp /var/log/RACHEL/* $rachelLogDir/; rm -rf /var/log/RACHEL; fi
    if [[ -d /var/log/RACHEL ]]; then mv /var/log/RACHEL $rachelLogDir; fi
    # Move rachel-scripts.sh
    if [[ -f /root/rachel-scripts.sh ]]; then mv /root/rachel-scripts.sh $rachelScriptsFile; fi
    # Move battery watcher
    if [[ -f /root/batteryWatcher.sh ]]; then mv /root/batteryWatcher.sh $rachelScriptsDir/; fi
    # Move createUSB
    if [[ -f /root/createUSB.sh ]]; then mv /root/createUSB.sh $rachelScriptsDir/; fi
    # Move gpt.backup
    if [[ -f /root/gpt.backup ]]; then mv /root/gpt.backup $rachelScriptsDir/; fi
    # Move rachelKiwixStart script
    if [[ -f /root/rachelKiwixStart.sh ]]; then mv /root/rachelKiwixStart.sh $rachelScriptsDir/; fi
    # Remove weaved folder
    rm -rf /root/weaved_software $rachelScriptsDir/weaved_software 
}

contentModuleListInstall(){
    while read m; do
        [[ $m =~ ^# ]] && continue # skip comments
        [[ -z $m ]] && continue    # skip blanks
        m=${m#"."}                 # remove leading dot (download but hidden (later))
        echo; printStatus "Downloading $m"
        # it is faster without zip unless we're going to dev
        # (i.e. LAN or USB)
        if [[ $RSYNCDIR == $rsyncOnline ]]; then
            rsync -avz --del $RSYNCDIR/rachelmods/$m $rachelWWW/modules/
        else
            rsync -av --del $RSYNCDIR/rachelmods/$m $rachelWWW/modules/
        fi
        commandStatus
        printGood "Done."
    done < $1
}

buildRACHEL(){
    # figure out which language we're doing
    case $1 in
        "" )
            echo "Usage: bash "`basename $0`" .modules_file [ rsync source ]"
            echo "       .modules files in $rachelWWW/scripts or current directory ("`pwd`")"
            echo "       rsync source: dev, jeremy, jfield, usb, OR actual hostname/ip"
            exit 1
            ;;
        * )
            # append .modules to the name
            modulesFile=$1.modules;
            shift
            ;;
    esac
    # figure out which server we're doing
    case $1 in
        dev | "" )
            onlineVariables
            ;;
        jeremy )
            offlineVariables
            RSYNCDIR="rsync://192.168.1.74"
            ;;
        jfield )
            offlineVariables
            RSYNCDIR="rsync://192.168.1.6"
            ;;
        usb )
            echo; printStatus "Here is list of your current partitions and their mountpoints (if applicable):"
            lsblk|grep -v mmc|grep -v sda
            echo; printQuestion "What is the location of your content folder (for example, /media/usb)? "; read dirContentOffline
            grep -qs " $dirContentOffline " /proc/mounts
            if [[ $? != 0 ]]; then
                echo; printError "The folder location does not exist!  Connect a USB drive and try again."
                rm -rf $installTmpDir $rachelTmpDir
                exit 1
            fi
            offlineVariables
            RSYNCDIR="$dirContentOffline"
            ;;
        * )
            offlineVariables
            RSYNCDIR="rsync://$1"
            ;;
    esac
    echo; printStatus "Starting RACHEL build script"
    echo "Building CAP with file: $modulesFile"
    echo "Using rsync source: $RSYNCDIR"

    # fix known RACHEL bugs
    # jfield checked - none of this is needed after a Recovery USB method 3 (format)
    # echo; repairBugs

    echo; printStatus "Installing fresh contentshell"
    freshContentShell

    # check if the .modules file specified exists - we have to do this
    # after we update contentshell because it may be there
    if [[ -f ./$modulesFile ]]; then
        modulesFile=./$modulesFile
    elif [[ -f $rachelWWW/scripts/$modulesFile ]]; then
        modulesFile=$rachelWWW/scripts/$modulesFile
    else
        echo; printError "No such .modules file: $modulesFile"
        printError "The file must appear in $rachelWWW/scripts or current directory ("`pwd`")"
        exit;
    fi

    # clear out old httpd logs, get updated config, restart
    # by killing it gracefully and letting sw_watchdog restart it
    echo; printStatus "Clearing httpd logs"
    rm -f /var/log/httpd/access_log
    rm -f /var/log/httpd/error_log
    echo Updating lighttpd.conf
    mv /usr/local/etc/lighttpd.conf /usr/local/etc/lighttpd.conf.last
    wget -q https://raw.githubusercontent.com/rachelproject/rachelplus/master/scripts/lighttpd.conf -O /usr/local/etc/lighttpd.conf
    echo Restarting lighttpd
    killall -INT lighttpd

    # get content - we checked earlier that file exists
    echo; printStatus "Installing/updating $modulesFile"
    contentModuleListInstall $modulesFile

    # bring in our multi-language patch (requires kalite restart)
    echo; printStatus "Patching kalite language code"
    kalite stop
    wget -q https://raw.githubusercontent.com/rachelproject/rachelplus/master/scripts/KALITE-MULTILINGUAL-api_views.py -O /usr/lib/python2.7/dist-packages/kalite/i18n/api_views.py
    kalite start
    # set the default language
    # NOTE: your session settings will override the default language
    # so to check this you have to open in an incognito window!
    lang=`basename $modulesFile | cut -c1-2`
    if [[ $lang == "es" || $lang == "fr" ]]; then
        echo; printStatus "Setting kalite language to $lang"
        wget -q -O - "http://localhost:8008/api/i18n/set_default_language/?lang=$lang&allUsers=1"
        echo
    fi

    # run our script against modulesFile for sort/show/hide
    echo; printStatus "Setting sort/visibility from $modulesFile"
    php $rachelWWW/sortmods.php $modulesFile

    # symlink KA Lite mp4s to /media/RACHEL/kacontent
    touch $rachelPartition/kaliteUpdate
    kaliteCheckFiles

    # update rachelKiwixStart.sh
    createKiwixRepairScript
    # restart kiwix
    /root/rachel-scripts/rachelKiwixStart.sh

    # install esp for remote service
    echo; printStatus "Installing RACHEL esp"
    installESP

    # ensure rachelStartup.sh is accurate
    repairRachelScripts

    # update RACHEL installer version
    echo $(cat /etc/rachelinstaller-version | cut -d_ -f1)-$(date +%Y%m%d.%H%M) > /etc/rachelinstaller-version
}

freshContentShell(){
    # preserve the modules directory in case someone
    # already put modules in there (partial or custom build)
    rm -rf $rachelPartition/modules.orig
    mv $rachelWWW/modules $rachelPartition/modules.orig
    # blow away the rachel directoy so we can start fresh
    rm -rf $rachelWWW
    # update contentshell to latest version
    git clone --depth=1 https://github.com/rachelproject/contentshell.git $rachelWWW
    rm -rf $rachelWWW/.git*
    # this is for the captive portal scripts
    chmod 775 $rachelWWW/*.shtml
    # admin directory needs to be writable so that web/sqlite can create files there
    chmod 777 /media/RACHEL/rachel/admin
    # modules directory needs to be writable so that updates can be web-downloaded
    chmod 777 /media/RACHEL/rachel/modules
    # restore the previous modules directory
    rm -rf  $rachelWWW/modules
    mv $rachelPartition/modules.orig $rachelWWW/modules
    # remove this unused directory
    rm -rf $rachelPartition/contentshell
}

installESP(){
    if [[ ! -d $rachelScriptsDir ]]; then echo; printError "Can not install; this is not a RACHEL CAP..exiting."; exit 1; fi
    mkdir -p $rachelScriptsDir
    echo; printStatus "Installing ESP."
    # download files and set permissions
    wget -q $gitESP/client/checker.php -O $rachelScriptsDir/checker.php
    rsync -av --del $RSYNCDIR/rachelmods/extra-build-files/esp.sshkey $rachelScriptsDir/
    chmod 600 $rachelScriptsDir/esp.sshkey
    # create startup process
    cat > /etc/init/esp.conf << 'EOF'
# Info
description "ESP"
author      "Jonathan Field <jfield@worldpossible.org>"

# Events
start on net-device-up IFACE=eth0
stop on shutdown

# Automatically restart process if crashed
respawn
respawn limit 20 5

# Run the script!
script
    exec /usr/bin/php -f /root/rachel-scripts/checker.php
end script
EOF
    printGood "Done."
    echo; printStatus "Starting ESP."
    # start the process
    service esp start
    printGood "Done."
    echo; printStatus "Checking status of running process:"
    # check the status
    service esp status
    # remove any existing weaved startup code
    sed -i '/Weaved/d' $rachelScriptsFile
    # remove any existing esp startup code
    sed -i '/esp/d' $rachelScriptsFile
    # add our esp startup code after Kiwix starts    
    sed -i '/rachelKiwixStart.sh/a # start rachel-esp checker\necho $(date) - Starting checker.php for rachel-esp\nservice esp start' $rachelScriptsFile
    printGood "ESP install completed."
}

uninstallESP(){
    echo; printStatus "Uninstalling ESP."
    # stop esp service
    service esp stop
    # remove esp files
    rm -f /etc/init/esp.conf $rachelScriptsDir/checker.php $rachelScriptsDir/esp.sshkey
    # remove any existing esp startup code
    sed -i '/esp/d' $rachelScriptsFile
    printGood "Done."
}

# Loop to redisplay main menu
whatToDo(){
    echo; printQuestion "What would you like to do next?"
    echo "1)Base Install  2)Install/Upgrade KALite  3)Install Kiwix  4)Install ESP  5)Add Module  6)Add Multiple Modules  7)Update Modules  8)Utilities  9)Exit"
}

# Interactive mode menu
interactiveMode(){
    echo; printQuestion "What you would like to do:"
    echo "  - [Base-Install] of RACHEL on a raw CAP (completely erases any content)"
    echo "  - [Install-Upgrade-KALite]"
    echo "  - [Install-Kiwix]"
    echo "  - [Install-ESP]"
    echo "  - [Add-Module] lists current available modules; installs one at a time"
    echo "  - [Add-Multiple-Modules] installs groups of modules"
    echo "  - [Update-Modules] updates the currently installed modules"
    echo "  - Other [Utilities]"
    echo "    - Install a battery monitor that cleanly shuts down this device with less than 3% battery"
    echo "    - Download RACHEL content to stage for OFFLINE installs"
    echo "    - Repair an install of a CAP after a firmware upgrade"
    echo "    - Repair a KA Lite assessment file location"
    echo "    - Repairs of general bug fixes"
    echo "    - Sanitize CAP"
    echo "    - Check a local file's MD5 against our database"
    echo "    - Testing script"
    echo "  - [Exit] the installation script"
    echo
    select menu in "Base-Install" "Install-Upgrade-KALite" "Install-Kiwix" "Install-ESP" "Add-Module" "Add-Multiple-Modules" "Update-Modules" "Utilities" "Exit"; do
            case $menu in
            Base-Install)
            newInstall
            ;;

            Install-Upgrade-KALite)
            kaliteSetup
            echo; printGood "Login using wifi at http://192.168.88.1:8008 and register device."
            echo "After you register, click the new tab called 'Manage', then 'Videos' and download all the missing videos."
            repairRachelScripts
            printGood "KA Lite Install Complete."
            whatToDo
            ;;

            Install-Kiwix)
            installKiwix
            # update rachelKiwixStart.sh
            createKiwixRepairScript
            # restart kiwix
            /root/rachel-scripts/rachelKiwixStart.sh
            repairRachelScripts
            whatToDo
            ;;

            Install-ESP)
            installESP
            repairRachelScripts
            whatToDo
            ;;

            Add-Module)
            updateModuleNames
            addModule
            kaliteCheckFiles
            # update rachelKiwixStart.sh
            createKiwixRepairScript
            # restart kiwix
            /root/rachel-scripts/rachelKiwixStart.sh
            whatToDo
            ;;

            Add-Multiple-Modules)
            updateModuleNames
            # installPkgUpdates
            checkContentShell
            addMultipleModules
            kaliteCheckFiles
            # update rachelKiwixStart.sh
            createKiwixRepairScript
            # restart kiwix
            /root/rachel-scripts/rachelKiwixStart.sh
            whatToDo
            ;;

            Update-Modules)
            updateModuleNames
            contentUpdate
            kaliteCheckFiles
            # update rachelKiwixStart.sh
            createKiwixRepairScript
            # restart kiwix
            /root/rachel-scripts/rachelKiwixStart.sh
            whatToDo
            ;;

            Utilities)
            echo; printQuestion "What utility would you like to use?"
            echo "  - [Install-Battery-Watcher] monitors battery and shutdowns the device with less than 3% battery"
            echo "  - [Enable-Wifi] enables the wifi access point (if disabled)"
            echo "  - [Disable-Wifi] disables the wifi instantly AND persistently on reboot"
            echo "  - [Disable-Reset-Button] removes the ability to reset the device by use of the reset button"
            echo "  - [Download-OFFLINE-Content] to stage for OFFLINE (i.e. local) RACHEL installs"
            echo "  - [Download-KA-Contentpacks] to download & install KA Lite contentpacks"
            echo "  - [Uninstall-ESP] removes ESP service"
            echo "  - [Update-Content-Shell] updates the RACHEL contentshell from GitHub"
            echo "  - [KA-Lite-Diagnostics] displays diangostic info on the KA Lite install"
            echo "  - [Repair-KA-Lite] repairs KA Lite's mislocation of the assessment file; runs 'kalite manage setup' as well"
            echo "  - [Repair-Kiwix-Library] rebuilds the Kiwix Library"
            echo "  - [Repair-Firmware] repairs an install of a CAP after a firmware upgrade"
            echo "  - [Repair-Bugs] provides general bug fixes (run when requested)"
            echo "  - [Sanitize] and prepare CAP for delivery to customer"
            echo "  - [Change-Package-Repo] allows you to change where in the world your packages are pulled from"
            echo "  - [Check-MD5] will check a file you provide against our hash database"
            echo "  - [Testing] script"
            echo "  - Return to [Main Menu]"
            echo
            select util in "Install-Battery-Watcher" "Enable-Wifi" "Disable-Wifi" "Disable-Reset-Button" "Download-OFFLINE-Content" "Download-KA-Contentpacks" "Uninstall-ESP" "Update-Content-Shell" "KA-Lite-Diagnostics" "Repair-KA-Lite" "Repair-Kiwix-Library" "Repair-Firmware" "Repair-Bugs" "Sanitize" "Change-Package-Repo" "Check-MD5" "Test" "Main-Menu"; do
                case $util in
                    Install-Battery-Watcher)
                    installBatteryWatch
                    repairRachelScripts
                    break
                    ;;

                    Enable-Wifi)
                    enableWifi
                    break
                    ;;

                    Disable-Wifi)
                    disableWifi
                    repairRachelScripts
                    break
                    ;;

                    Disable-Reset-Button)
                    disableResetButton
                    repairRachelScripts
                    break
                    ;;

                    Download-OFFLINE-Content)
                    downloadOfflineContent
                    break
                    ;;

                    Download-KA-Contentpacks)
                    downloadKAContentPacks
                    kaliteCheckFiles
                    break
                    ;;

                    Uninstall-ESP)
                    uninstallESP
                    break
                    ;;

                    Update-Content-Shell)
                    echo; printStatus "Updating the RACHEL content shell."
                    # installPkgUpdates
                    checkContentShell
                    break
                    ;;

                    KA-Lite-Diagnostics)
                    kaliteDiagnostic
                    break
                    ;;

                    Repair-KA-Lite)
                    repairKalite
                    break
                    ;;

                    Repair-Kiwix-Library)
                    # update rachelKiwixStart.sh
                    createKiwixRepairScript
                    # restart kiwix
                    /root/rachel-scripts/rachelKiwixStart.sh
                    break
                    ;;

                    Repair-Firmware)
                    repairFirmware
                    break
                    ;;

                    Repair-Bugs)
                    repairBugs
                    break
                    ;;

                    Sanitize)
                    sanitize
                    break
                    ;;

                    Change-Package-Repo)
                    changePackageRepo
                    break
                    ;;

                    Check-MD5)
                    echo; printStatus "This function will compare the MD5 of the file you provide against our list of known hashes."
                    printQuestion "What is the full path to the file you want to check?"; read MD5CHKFILE
                    checkMD5 $MD5CHKFILE
                    break
                    ;;

                    Test)
                    testingScript
                    break
                    ;;

                    Main-Menu )
                    break
                    ;;
                esac
            done
            whatToDo
            ;;

            Exit)
            echo; printStatus "User requested to exit."
            break
            ;;
            esac
    done
}

printHelp(){
    echo; echo "Usage:  cap-rachel-configure.sh [-b <lang> <source>] [-h] [-i] [-n] [-r] [-u] [-z]"
    echo; echo "Examples:"
    echo "./cap-rachel-configure.sh -b (en | es | fr) [dev | jeremy | jfield | host/ip | usb]"
    echo "Build a RACHEL-Plus after base RACHEL install."
    echo; echo "./cap-rachel-configure.sh -h"
    echo "Displays this help menu."
    echo; echo "./cap-rachel-configure.sh -i"
    echo "Interactive mode."
    echo; echo "./cap-rachel-configure.sh -n"
    echo "Base RACHEL Install on a raw Intel CAP."
    echo; echo "./cap-rachel-configure.sh -r"
    echo "Repair issues found in the RACHEL-Plus."
    echo; echo "./cap-rachel-configure.sh -u"
    echo "Update this script with the latest RELEASE version from GitHub."
    echo; echo "./cap-rachel-configure.sh -z"
    echo "Update this script with the latest BETA version from GitHub."
    echo; echo "To EXIT the interactive script at anytime, press Ctrl-C"
    echo; stty sane
}

loggingAndRachelStart(){
    # Logging
    loggingStart

    # Display current script version
    echo; echo "RACHEL CAP Configuration Script - Version $scriptVersion"
    printGood "Started:  $(date)"
    printGood "Log directory:  $rachelLogDir"
    printGood "Temporary file directory:  $installTmpDir"
}

#### MAIN MENU ####
# Check for bash
if [ -z $BASH_VERSION ]; then
    clear
    echo "[!] You didn't execute this script with bash!"
    echo "Unfortunately, not all shells are the same. \n"
    echo "Please execute \"bash "$0"\" \n"
    echo "Thank you! \n"
    exit 1
fi

# Check root
if [[ ! $(groups | grep root) ]]; then
    echo "[!] This script must be run as root; sudo password is 123lkj"
    exit 1
else
    if [ "$(id -u)" != "0" ]; then
        echo; printError "While you have root privileges, you are not root.  Adjusting sudo permissions."
        echo; echo "You MUST log out and back in for sudo permissions to update."
        echo; printStatus "After login, re-run this script using the following command:"
        echo "sudo ./cap-rachel-configure.sh -i <or -n for base RACHEL installs>"
        awk 'BEGIN{OFS=FS=":"} $1~/sudo/ {$4="cap";}1' /etc/group > tmp; mv tmp /etc/group
        noCleanup=1
        echo; exit 1
    fi
fi

# Reset terminal
stty sane
#reset

# In case you wish to kill it
#trap 'exit 3' 1 2 3 15
trap cleanup EXIT

# Menu
if [[ $1 == "" || $1 == "--help" || $1 == "-h" ]]; then
    printHelp
elif [[ $1 == "--version" ]]; then
    # Print version only, if requested
    echo $scriptVersion
    noCleanup=1
elif [[ $1 == "--usbrecovery" ]]; then
    loggingAndRachelStart
    usbRecovery
    noCleanup=1
elif [[ $1 == "--source-only" ]]; then
    printGood "Only importing source functions."
    noCleanup=1
else
    # Check for old folder structure
    if [[ -f /root/rachel-scripts.sh ]]; then 
        echo; printError "Your RACHEL folder structure is outdated!"
        echo "The configure script will still be located at /root/cap-rachel-configure.sh"
        echo "All other RACHEL scripts/files will be located in the folder called 'rachel-scripts'"
        echo "Updating your RACHEL install in 10 seconds."
        echo; sleep 10
        echo; printStatus "Beginning RACHEL update..."
        mkdir -p $installTmpDir $rachelTmpDir $rachelRecoveryDir
        opMode; repairBugs
        echo; printGood "Your RACHEL install was successfully updated."
        exit 1
    fi
    # Start logging and display RACHEL start info
    loggingAndRachelStart
    # MAIN MENU
    IAM=${0##*/} # Short basename
    while getopts ":b:inrtuz" opt
    do sc=0 #no option or 1 option arguments
        case $opt in
        (b) # Build - Quick build
            # Create temp directories
            mkdir -p $installTmpDir $rachelTmpDir $rachelRecoveryDir 2>/dev/null
            # Check OS and CAP version
            osCheck
            capCheck
            if [[ $# -lt $((OPTIND)) ]]; then
                echo; echo "$IAM -b argument(s) missing...needs 2!" >&2
                echo; echo "Usage: `basename $0` -b '(en | es | fr) [ rsync host ]'" >&2
                echo '       rsync hosts: dev, jeremy, jfield, or actual hostname/ip' >&2
                exit 2
            fi
            OPTINDplus1=$((OPTIND + 1))
            kaLanguage=$OPTARG
            eval rsyncHost=\$$OPTIND
            buildRACHEL $kaLanguage $rsyncHost
            echo; printGood "Build complete."
            exit
            sc=1 #2 args
            ;;
        (i) # Interactive mode
            # Create temp directories
            mkdir -p $installTmpDir $rachelTmpDir $rachelRecoveryDir 2>/dev/null
            # Check OS and CAP version
            osCheck
            capCheck
            # Determine the operational mode - ONLINE or OFFLINE
            opMode
            # Build the hash list 
            buildHashList
            # Change directory into $installTmpDir
            cd $installTmpDir
            echo; printStatus "If needed, you may EXIT the interactive script at anytime, press Ctrl-C"
            interactiveMode
            ;;
        (n) # Scratch install mode
            # Create temp directories
            mkdir -p $installTmpDir $rachelTmpDir $rachelRecoveryDir 2>/dev/null
            # Check OS and CAP version
            osCheck
            capCheck
            # Determine the operational mode - ONLINE or OFFLINE
            opMode
            # Build the hash list 
            buildHashList
            # Change directory into $installTmpDir
            cd $installTmpDir
            newInstall
            ;;
        (r) # REPAIR - quick repair; doesn't hurt if run multiple times.
            # Create temp directories
            mkdir -p $installTmpDir $rachelTmpDir $rachelRecoveryDir
            # Check OS and CAP version
            osCheck
            capCheck
            # Determine the operational mode - ONLINE or OFFLINE
            opMode
            repairBugs
            echo; printGood "Repair complete."
            exit
            ;;
        (t) # Testing script
            # Check OS and CAP version
            osCheck
            capCheck
            # Determine the operational mode - ONLINE or OFFLINE
            opMode
            testingScript
            ;;
        (u) # UPDATE - Update the RACHEL configure script to the latest master (release) build.
            # Create temp directories
            mkdir -p $installTmpDir $rachelTmpDir $rachelRecoveryDir
            # Check OS and CAP version
            osCheck
            capCheck
            # Determine the operational mode - ONLINE or OFFLINE
            opMode
            if [[ $internet == "1" ]]; then
                $DOWNLOADSCRIPT >&2
                commandStatus
                if [[ -s $installTmpDir/cap-rachel-configure.sh ]]; then
                    mv $installTmpDir/cap-rachel-configure.sh /root/cap-rachel-configure.sh
                    chmod +x /root/cap-rachel-configure.sh
                    versionNum=$(cat /root/cap-rachel-configure.sh |grep ^scriptVersion|head -n 1|cut -d"=" -f2|cut -d" " -f1)
                    printGood "Success! Your script was updated to $versionNum; RE-RUN the script to use the new version."
                else
                    printStatus "Fail! Check the log file for more info on what happened:  $rachelLog"
                    echo
                fi
            else
                if [[ ! -f $dirContentOffline/cap-rachel-configure.sh ]]; then
                    echo; printError "You don't have a copy of the rachel script in your offline content location."
                    echo; exit 1
                fi
                $DOWNLOADSCRIPT >&2
                commandStatus
                chmod +x /root/cap-rachel-configure.sh
                versionNum=$(cat /root/cap-rachel-configure.sh |grep ^scriptVersion|head -n 1|cut -d"=" -f2|cut -d" " -f1)
                printGood "Success! Your script was updated to $versionNum; RE-RUN the script to use the new version."
#                    echo; printError "You need to be connected to the internet to update this script."
            fi
            exit 1
            ;;
        (z) # UPDATE to BETA - Update the RACHEL configure script to the latest BETA build.
            # Create temp directories
            mkdir -p $installTmpDir $rachelTmpDir $rachelRecoveryDir
            # Check OS and CAP version
            osCheck
            capCheck
            # Determine the operational mode - ONLINE or OFFLINE
            opMode
            if [[ $internet == "1" ]]; then
                $DOWNLOADBETASCRIPT >&2
                commandStatus
                if [[ -s $installTmpDir/cap-rachel-configure.sh ]]; then
                    mv $installTmpDir/cap-rachel-configure.sh /root/cap-rachel-configure.sh
                    chmod +x /root/cap-rachel-configure.sh
                    versionNum=$(cat /root/cap-rachel-configure.sh |grep ^scriptVersion|head -n 1|cut -d"=" -f2|cut -d" " -f1)
                    printGood "Success! Your script was updated to $versionNum; RE-RUN the script to use the new version."
                else
                    printStatus "Fail! Check the log file for more info on what happened:  $rachelLog"
                    echo
                fi
            else
                echo; printError "You must be online to download the current BETA version of the configure script."
                echo; exit 1
            fi
            exit 1
            ;;
        (\?) #Invalid options
            echo "$IAM: Invalid option: -$OPTARG"
            printHelp
            exit 1
            ;;
        (:) #Missing arguments
            echo "$IAM: Option -$OPTARG argument(s) missing."
            printHelp
            exit 1
            ;;
        esac
        if [[ $OPTIND != 1 ]]; then #This test fails only if multiple options are stacked after a single "-"
            shift $((OPTIND - 1 + sc))
            OPTIND=1
        fi
    done
fi
