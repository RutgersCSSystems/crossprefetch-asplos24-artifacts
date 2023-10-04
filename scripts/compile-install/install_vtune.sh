#!/bin/bash

if [ -z "$NVMBASE" ]; then
    echo "NVMBASE environment variable not defined. Have you ran setvars?"
    exit 1
fi


VTUNE_DOWNLOAD_URL=https://registrationcenter-download.intel.com/akdlm/irc_nas/tec/17527/l_oneapi_vtune_p_2021.1.2.150_offline.sh
VTUNE_INSTALLER_PATH=l_oneapi_vtune_p_2021.1.2.150_offline.sh
VTUNE_DEFAULT_INSTALLATION_PATH=/opt/intel/oneapi/vtune/latest

vtune_debug () {
	echo "[VTUNE.sh] $1"
}

vtune_error () {
	echo "[VTUNE.sh] (ERROR) $1"
}


check_prerequisites () {

	# Check for xorg
	which Xorg
	if [ $? -eq 0 ]; then
		vtune_debug "Found Xorg prerequisite"
	else
		vtune_debug "Could not find xorg prequisite"
		
		vtune_debug "Trying to install xorg"
		sudo apt-get install xorg -y

		if [ $? -eq 0 ]; then
			vtune_debug "Sucessfully installed Xorg"
		else
			vtune_debug "Failed to install Xorg"
			exit 1
		fi
	fi

	sudo apt-get install -y libnss3 libcanberra-gtk3-module libcanberra-gtk-module gnome-keyring

}

check_previous_vtune () {
	# Check for signs of installation
	ls $VTUNE_DEFAULT_INSTALLATION_PATH &> /dev/null

	if [ $? -eq 0 ]; then
		vtune_debug "Previously installation of VTUNE detected."
		exit 1
	fi
}

download_vtune () {

	vtune_debug "Downloading VTUNE Installer"
	wget $VTUNE_DOWNLOAD_URL

	if [ $? -ne 0 ]; then
		vtune_debug "Failed to download VTUNE installer"
		exit 1
	fi
}

install_vtune () {
	# run installer 
	vtune_debug "Running Installer"
	sudo chmod +x $VTUNE_INSTALLER_PATH
	sudo ./$VTUNE_INSTALLER_PATH 

	if [ $? -ne 0 ]; then
		vtune_error "Failed to install VTUNE"
		exit 1
	fi
}

check_installation () {

	# Run installation self-checker
	vtune_debug "Checking VTUNE Installation. This will take a minute."
	cmdouput=$($VTUNE_DEFAULT_INSTALLATION_PATH/bin64/vtune-self-checker.sh)
	if [ $? -ne 0 ]; then
		vtune_error "VTUNE Installation seems to have failed"
		vtune_error "Rerun the VTUNE self checker manually for more information"
		exit 1
	else
		vtune_debug "VTUNE Installation seems to be good"
	fi

}

post_installation () {

	# Ensuring installation directory is writable so vtune can be run a non-root 
	#vtune_debug "Ensuring VTUNE installation directory permissions are set for non-root use"
	sudo chmod -R ug+rw /opt/intel

	if [ $? -ne  0 ]; then 
		echo "Could not set vtune installation directory permissions"
	fi

	# Set ptrace scope temporarily
	vtune_debug "Setting current ptrace scope to 0 for current session"
	sudo sh -c "echo 0 > /proc/sys/kernel/yama/ptrace_scope"

	if [ $? -ne 0 ]; then
		echo "Could not set the current ptrace scope"
	fi


	# Setting ptrace scope permenantly
	vtune_debug "Setting ptrace scope config to 0 permenantly"
	sudo sed -i "s/kernel.yama.ptrace_scope = 1/kernel.yama.ptrace_scope = 0/" /etc/sysctl.d/10-ptrace.conf
	#this needs a reboot to take effect
	if [ $? -ne 0 ]; then 
		echo "Could not set ptrace scope configuration"
	fi
	
	# Set kptr_restirct and perf_event_paranoid
	sudo sh -c "echo \"kernel.kptr_restrict=0\" >> /etc/sysctl.conf"
	sudo sh -c "echo \"kernel.perf_event_paranoid=-1\" >> /etc/sysctl.conf"
	sudo sysctl -p /etc/sysctl.conf
	sudo sysctl -w kernel.kptr_restrict=0
	sudo sysctl -w kernel.perf_event_paranoid=-1
	
}

#enables kernel instrumentation through sepdk
kernel_instrumentation () {
	cd $NVMBASE
	wget https://software.intel.com/content/dam/develop/external/us/en/documents/sepdk.tar.gz
	tar -xvf sepdk.tar.gz
	sudo cp -r sepdk/* $VTUNE_DEFAULT_INSTALLATION_PATH/sepdk
	cd $VTUNE_DEFAULT_INSTALLATION_PATH/sepdk/src
	sudo ./build-driver -ni -pu --kernel-src-dir=/lib/modules/$VER/source
	sudo sh -c "./insmod-sep -r -pu -g root"
	sudo sh -c "./boot-script -pu --install"
	./insmod-sep -q
}

vtune_install () {
	check_previous_vtune
	check_prerequisites
	download_vtune
	install_vtune
	cleanup_installer
	post_installation
	check_installation
	kernel_instrumentation
}

vtune_uninstall () {
	vtune_debug "Going to uninstall VTUNE"	
	sudo $VTUNE_DEFAULT_INSTALLATION_PATH/uninstall.sh	
	
	if [ $? -eq 0 ]; then 
		vtune_debug "Uninstalled VTUNE sucessfully"
	else
		vtune_error "Failed to uninstall VTUNE"
	fi
}

if [ $# -eq 1 ]; then
	if [ $1 == "install" ]; then
		vtune_install
	elif [ $1 == "uninstall" ]; then
		vtune_uninstall
	elif [ $1 == "run" ]; then
		vtune_run
	elif [ $1 == "enable_kernel" ]; then ##has to be done on reboot
		kernel_instrumentation
	else
		vtune_debug "Unknown Option"
		#vtune_print_usage
	fi	
else
	vtune_print_usage
fi
