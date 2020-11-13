#!/bin/bash
#Written by Brian Miller (brian@phospher.com) on 11/11/2020.
#Spaghetti to allow rapid testing of new releases of MBBSEmu.
#It's not perfect.

VERSION=1.00

TIME=$(date +%s)
TOOLS="cut tar wget curl netstat rev head grep tee echo ping chmod"

#Global function (used for tee/logging)
function DOIT {

########################
# Functions
########################
#Save all the things
function BACKUP {
	echo
	echo "########################"
	echo "# BEGIN: Backup"
	echo "########################"

	tar cvf /tmp/mbbsemu_backup_$TIME.tar .
	
	if [ ! $? = 0 ]; then
		echo "Backup failed, exiting..."
       		exit 1
	else
		echo "Backup saved to /tmp/mbbsemu_backup_$TIME.tar"
	fi

	echo "########################"
        echo "# END: Backup"
        echo "########################"
	echo
}


#Make it so
function INSTALL {
        echo
        echo "########################"
        echo "# BEGIN: Install"
        echo "########################"

	echo "Downloading $LATEST_BUILD_URL"
	LATEST_FILE=$(echo "$LATEST_BUILD_URL"| rev | cut -d "/" -f1  | rev)
 	wget -q $LATEST_BUILD_URL -P /tmp/
	if [ -f "/tmp/$LATEST_FILE" ]; then
		echo "Successfully downloaded $LATEST_FILE"
		#rm ./MBBSEmu
		unzip -o /tmp/$LATEST_FILE MBBSEmu
		chmod +x MBBSEmu
		INSTALLED_BUILD=$(./MBBSEmu|grep Version:|cut -d " " -f2)
		if [ "$INSTALLED_BUILD" = "$LATEST_BUILD" ]; then
			echo "MBBSEmu $LATEST_BUILD was successfully installed!"
			exit 0
		else
			echo "ERROR: $LATEST_BUILD was NOT successfully installed!"
			exit 1
		fi
	else
		echo "Error: Could not download $LATEST_FILE, exiting..."
		exit 1
	fi

	echo
        echo "########################"
        echo "# END: Install"
        echo "########################"
}


########################
# Main
########################
if [ ! "$USER" = "root" ]; then
	echo "ERROR: This script must be run as root, exiting..."
	exit 1
fi

echo "MBBSEmu updater script v$VERSION"
echo

if [ ! -f "./MBBSEmu" ]; then
	echo "Cannot find the MBBSEmu executable. This script must be executed from the same working directory as MBBSEmu. Exiting..."
	exit 1
fi


#Tool check (required nonsense because I'm better with interpreted than compiled languages) :/
for TOOL in $TOOLS; do
	which $TOOL > /dev/null 2>&1
        if [ ! $? = 0 ]; then
	        echo "Tool Error: $TOOL is missing, exitng..."
                exit 1
        fi
done


#Exit if MBBSEmu is running
netstat -ltnp | grep ':23'|grep -i mbbs > /dev/null 2>&1
if [ $? = 0 ]; then
	echo "MBBSEmu appears to be running, kill MBBSEmu and try again, exiting..."
        exit 1
fi


#Can we reach mbbsemu.com?
ping www.mbbsemu.com -c 2 -i 1 > /dev/null 2>&1
if [ ! $? = 0 ]; then
	echo "ERROR: Cannot reach www.mbbsemu.com, checking your connection. Exiting..."
	exit 1
else
	echo "www.mbbsemu.com is accessible, continuing..."
fi


#Get first level of lastest build number
echo "Retrieving available releases from mbbsemu.com..."
LATEST_BUILD=$(curl -s https://www.mbbsemu.com/Downloads/master |grep "<a href=\"/Downloads/master/"|head -1|grep "/master/"|cut -d "/" -f4|cut -d "\"" -f1)
if [ ! "$LATEST_BUILD" ]; then
	echo "Could not retrieve releases from mbbsemu.com, exting..."
	exit 1
fi


#Get installed build version number
if [ -x "./MBBSEmu" ]; then
	INSTALLED_BUILD=$(./MBBSEmu|grep Version:|cut -d " " -f2)
else
	echo "Error, could not execute MBBSEmu, check the file attributes to ensure it's executable."
	exit 1
fi

#Get download URL for latest build
LATEST_BUILD_URL=$(curl -s https://www.mbbsemu.com/Downloads/master/$LATEST_BUILD|grep "https://download.mbbsemu.com/builds/master/$LATEST_BUILD/mbbsemu-linux-x64-$LATEST_BUILD"|head -1|cut -d "\"" -f2)

#Extract build and release numbers of latest build
LATEST_BUILD=$(echo $LATEST_BUILD_URL|cut -d "-" -f4,5|cut -d "." -f1)

echo
echo "The lastest build available is: $LATEST_BUILD"
echo "The version of the installed build is: $INSTALLED_BUILD"
echo "Download URL for latest build: $LATEST_BUILD_URL"
echo

if [ "$LATEST_BUILD" = "$INSTALLED_BUILD" ]; then
	echo "You're already running the latest build..."
	echo -n "Would you like to re-install $LATEST_BUILD? (yes/no): "
	read INSTALL_QUESTION
	if [ "$INSTALL_QUESTION" = "yes" ]; then
		BACKUP
		INSTALL
	else
		echo "Exiting..."
		exit 0
	fi
else
	echo -n "Would you like to install $LATEST_BUILD? (yes/no): "
	read INSTALL_QUESTION
        if [ "$INSTALL_QUESTION" = "yes" ]; then
                BACKUP
		INSTALL
        else
                echo "Exiting..."
                exit 0
        fi
fi

}

#Log all the things
DOIT 2>&1 | tee /tmp/mbbsemu_upgrader_$TIME.log

echo
echo "Log written to /tmp/mbbsemu_upgrader_$TIME.log"
echo
