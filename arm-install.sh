#!/bin/bash

# Check parameters
if [[ $1 == "--verbose" ]]; then
    VERBOSE=true
elif [[ $1 == "--noop" ]]; then
    NOOP=true
fi

#################
# Add some colour
#################
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    # Enables a Verbose Logging mode
    if [[ $NOOP ]]; then
        printf "\n${YELLOW}[WHATIF] I would have run ${NC}${@:1}\n"
    elif [[ $VERBOSE ]]; then
        "${@:1}" && printf "\n${GREEN}Step completed successfully\n" || printf "\n${RED}Step Failed\n"
    else 
        "${@:1}" >/dev/null 2>&1 && printf "${GREEN}Success\n" || printf "${RED}Failed\n"
    fi
}

stage1() {
    printf " - Adding ${BLUE}ppa:graphics-drivers/ppa${NC}... "
    log add-apt-repository ppa:graphics-drivers/ppa
    printf " - Updating packages... "
    log apt upgrade -y && apt update -y && \
        apt install avahi-daemon -y && systemctl restart avahi-daemon && \
        apt install ubuntu-drivers-common -y && ubuntu-drivers install 
    printf "\n${BLUE}Finished stage 1${NC}\n===============n"
    printf "Press ${YELLOW}ENTER${NC} to reboot or ${YELLOW}CTRL-C${NC} to cancel"
    read input
}

stage2() {
    printf "${BLUE}Continuing installation of arm...${NC}\n=================================\n\n"
    printf " - Disabling sleep and hibernation... "
    log systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
    printf " - Creating ${BLUE}arm${NC} user and group... "
    log groupadd arm && \
        usermod -aG arm $USER && \
        useradd -m arm -g arm -G cdrom
    printf " - Setting ${BLUE}arm${NC} user password... "
    ARM_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo '')
    log echo 'arm:${ARM_PASSWORD}' | chpasswd
    printf " - Set up repos and install git... "
    log apt-get install git -y && \
        add-apt-repository ppa:heyarje/makemkv-beta && \
        add-apt-repository ppa:stebbins/handbrake-releases
    printf " - Getting Debian Release and adding ${BLUE}mc3man${NC} repository... "
    case $(cut -f2 <<< $(lsb_release -r)) in 
        "16.04" ) 
            printf "${GREEN}Found '16.04' (xerus)\n"
            add-apt-repository ppa:mc3man/xerus-media
            ;; 
        "18.04" ) 
            printf "${GREEN}Found '18.04' (bionic)\n"
            add-apt-repository ppa:mc3man/bionic-prop
            ;; 
        "20.04" ) 
            printf "${GREEN}Found '16.04' (focal)\n"
            add-apt-repository ppa:mc3man/focal6
            ;; 
        *) printf "${RED}Failed to find Debian Release${NC}\n";; 
    esac
    printf " - Updating repositories... "
    log apt update -y
    printf " - Installing ${BLUE}MakeMKV Tools${NC}... "
    log apt install makemkv-bin makemkv-oss -y
    printf " - Installing ${BLUE}Handbrake Tools${NC}... "
    log apt install handbrake-cli libavcodec-extra -y
    printf " - Installing ${BLUE}Music CD Tools${NC}... "
    log apt install abcde flac imagemagick glyrc cdparanoia at -y
    printf " - Installing ${BLUE}Python Tools${NC}... "
    log apt install python3 python3-pip -y
    printf " - Installing ${BLUE}SSL Tools${NC}... "
    log apt-get install libcurl4-openssl-dev libssl-dev -y
    printf " - Installing ${BLUE}libdvd${NC}... "
    log apt-get install libdvd-pkg -y
    printf " - Reconfiguring ${BLUE}makemkv${NC}... "
    log dpkg-reconfigure libdvd-pkg
    printf " - Installing ${BLUE}Java Runtime Environment${NC}... "
    log apt install default-jre-headless -y

    # Install and setup ARM
    printf " - Creating ${BLUE}/var/lib/arm${NC}... "
    log mkdir -p /var/lib/arm/config && \
        mkdir -p /var/lib/arm/db && \
        mkdir -p /var/lib/arm/cache && \
        chown -R arm:arm /var/lib/arm

    printf " - Creating ${BLUE}/opt/arm${NC}... "
    log mkdir -p /opt/arm && \
        chown arm:arm /opt/arm
    printf " - Grabbing files from Github... "
    cd /opt/arm
    log git clone https://github.com/automatic-ripping-machine/automatic-ripping-machine.git /opt/arm && \
        chown -R arm:arm /opt/arm
    printf " - Installing python requirments... "
    log pip3 install -r requirements.txt 
    printf " - Configuring automedia rules... "
    log cp /opt/arm/setup/51-automedia.rules /etc/udev/rules.d/
    printf " - Copying ${BLUE}abcde${NC} config... "
    log ln -s /opt/arm/setup/abcde.conf /var/lib/arm/config
    printf " - Creating ${BLUE}/opt/arm/arm.yaml${NC}... "
    log cp docs/arm.yaml.sample /opt/arm/arm.yaml && \
        mkdir -p /etc/arm/ && \
        ln -s /opt/arm/arm.yaml /etc/arm/
    printf " - Creating control scripts... "
    log mkdir -p /usr/local/sbin/arm && \
        ln -s /opt/arm/scripts/arm-rebuildConfig.sh /usr/local/sbin/
    printf "${BLUE}Finished main instalation, locating CD/DVD Drives...${NC}\n====================================================\n"
    for DRIVE in $(more /proc/sys/dev/cdrom/info | awk '/drive name/ {print}' | cut -d ':' -f 2 | tr -d " \t")
    do
        printf "Found CD/DVD drive: ${BLUE}/dev/${DRIVE}${NC}... Rip from this drive? ${YELLOW}[y/n]${NC} "
        read INPUT
        if [[ $INPUT =~ [yY] ]]; then
            printf "\n - Creating Mountpoint for ${BLUE}${DRIVE}${NC}..."
            log mkdir -p /mnt/dev/$DRIVE && \
            echo "/dev/$DRIVE  /mnt/dev/$DRIVE  udf,iso9660  user,noauto,exec,utf8  0  0" | tee -a /etc/fstab
        else   
            printf "\n - Skipping drive $DRIVE\n"
        fi
    done

    printf "\n${BLUE}Finished installing arm${NC}\n=======================\n\n"
    printf "New user created (${BLUE}arm${NC}) with password (${RED}${ARM_PASSWORD}${NC})\n"
}

main() {

    if [ -f /var/run/rebooting-for-updates ]; then
        stage2
        rm /var/run/rebooting-for-updates
        update-rc.d arm-continueInstall remove
    else
        # Issue disclaimer - you really should read scripts from the Interwebs before running them!
        if [[ "$EUID" -ne 0 ]]; then 
            echo -e  "${YELLOW}This script requires elevated priviledges${NC}"
            exit
        else
            echo -e "${RED}This script will make changes to your system${NC}"
            echo -e "While this is probably what you want, please consider that running a script from the Internet can be a bad thing - especially as it requires elevation."
            printf "${YELLOW}Do you want to continue?${NC} [y/n] " && read INPUT
            if [[ $INPUT =~ [yY] ]]; then
                echo -e "${BLUE}Starting install....${NC}"
                echo -e "===================="
                stage1
            fi
        fi
        touch /var/run/rebooting-for-updates
        # Writing script to automatically restart this installation... Formatting intentional...
        echo "
#! /bin/sh

### BEGIN INIT INFO
# Provides:          arminstall
### END INIT INFO

PATH=/sbin:/bin:/usr/sbin:/usr/bin

case "\$1" in
    start)
        $BASH_SOURCE
        ;;
    stop|restart|reload)
        ;;
esac" | tee -a /etc/init.d/arm-continueInstall
        update-rc.d arm-continueInstall defaults
        reboot
    fi
}

main