#!/bin/bash
################################################################################
#                                                                              #
# archinstall - Arch Install                                                   #
#                                                                              #
# FILE                                                                         #
# archinstall.sh                                                               #
#                                                                              #
# DATE                                                                         #
# 2021-12-21                                                                   #
#                                                                              #
# DESCRIPTION                                                                  #
# Script for easy install                                                      #
#                                                                              #
# AUTHOR                                                                       #
# omkaryash123@gmail.com                                                       #
#                                                                              #
################################################################################

# SECURITY VAR - this version can rm -rf /* your hard drive
SEC_ENABLE="false"


# root variable
ROOT="/mnt/arch"

# Defaults Partitioning
HD="/dev/sda"
boot_part="${HD}"
boot_type="ext2"
boot_size="100MB"
root_part="${HD}"
root_type="ext4"
root_size="10GB"
swap_part="${HD}"
swap_size="1024MB"

# Partition CONST
PART_AUTO="1"
PART_MANUAL="2"

# Menu CONST
MENU_LIVE="1"
MENU_REPO="2"
MENU_BLACKMAN="3"

# archinstall version
VERSION="v1"

# true / false
FALSE="0"
TRUE="1"

# return codes
SUCCESS="1337"
FAILURE="31337"

# verbose mode - default: quiet
VERBOSE="/dev/null"

# colors
WHITE="$(tput bold ; tput setaf 7)"
GREEN="$(tput setaf 2)"
RED="$(tput bold; tput setaf 1)"
YELLOW="$(tput bold ; tput setaf 3)"
NC="$(tput sgr0)" # No Color


wprintf() {
    fmt=$1
    shift
    printf "%s${fmt}%s\n" "${WHITE}" "$@" "${NC}"

    return "${SUCCESS}"
}

# print warning
warn()
{
    fmt=${1}
    shift
    printf "%s[!] WARNING: ${fmt}%s\n" "${RED}" "${@}" "${NC}"

    return "${SUCCESS}"
}

# print error and exit
err()
{
    fmt=${1}
    shift
    printf "%s[-] ERROR: ${fmt}%s\n" "${RED}" "${@}" "${NC}"

    return "${FAILURE}"
}

# print error and exit
cri()
{
    fmt=${1}
    shift
    printf "%s[-] CRITICAL: ${fmt}%s\n" "${RED}" "${@}" "${NC}"

    exit "${FAILURE}"
}


# usage and help
usage()
{
cat <<EOF
Usage: $0 <arg> | <misc>
MISC:
    -V: print version and exit
    -H: print help and exit
EOF
    return "${SUCCESS}"
}

# leet banner, very important
banner()
{
    printf "%s--==[ Arch Install %s ]==--%s\n" "${YELLOW}" "${VERSION}" "${NC}"

    return "${SUCCESS}"
}

check_env()
{
    if [ -f /var/lib/pacman/db.lck ]; then
        cri "Pacman locked - rm /var/lib/pacman/db.lck"
    fi
}

# check argument count
check_argc()
{
    return "${SUCCESS}"
}

# check if required arguments were selected
check_args()
{
    return "${SUCCESS}"
}


update_system()
{
    if [ "$(uname -m)" == "x86_64" ]; then
        if grep -q "#\[multilib\]" /etc/pacman.conf; then
            # it exist but commented
            wprintf "[+] Uncommenting multilib in /etc/pacman.conf..."
            sed -i '/\[multilib\]/{ s/^#//; n; s/^#//; }' /etc/pacman.conf
        elif ! grep -q "\[multilib\]" /etc/pacman.conf; then
            # it does not exist at all
            wprintf "[+] Enabling multilib in /etc/pacman.conf..."
            printf "[multilib]\nInclude = /etc/pacman.d/mirrorlist\n" >> /etc/pacman.conf
        fi
    fi

    if [ -n "${LIVE}" ]; then
      wget http://blackarch.org/blackarch/blackarch/os/x86_64/blackarch-keyring-20140118-3-any.pkg.tar.xz{,.sig}
      gpg --keyserver hkp://pgp.mit.edu --recv-keys '4345771566D76038C7FEB43863EC0ADBEA87E4E3'
      gpg --with-fingerprint --verify blackarch-keyring-20140118-3-any.pkg.tar.xz.sig
      rm blackarch-keyring-20140118-3-any.pkg.tar.xz.sig
      pacman-key --init
      pacman -U blackarch-keyring-20140118-3-any.pkg.tar.xz --noconfirm
    fi
    pacman -Syy --noconfirm "${LIVE+-u}"

    return "${SUCCESS}"
}

# auto mode
setup_partition_values()
{
    part_opt=${1}

    # * BOOT
    printf "[+] Select partition size for /boot [%s]: " "${boot_size}"
    read a; [ "${a}" != "" ] && boot_size=${a}

    # * ROOT
    # Manual && Automatic
    printf "[+] Select partition size for / [%s]: " "${root_size}"
    read a; [ "${a}" != "" ] && root_size=${a}

    # * Swap
    printf "[+] Select partition size for swap [%s] : " "${swap_size}"
    read a; [ "${a}" != "" ] && swap_size=${a}

    return "${SUCCESS}"
}

check_parted_status()
{
    [ ${?} != "0" ] && cri "Something wrong with parted - If you plan to run install script again, delete first all partitions created before error"

    return "${SUCCESS}"
}

check_mkfs_status()
{
    [ ${?} != "0" ] && cri "Something wrong with mkfs"

    return "${SUCCESS}"
}


# auto mode
format_filesystem()
{
    # about to format
    printf "%s" "${RED}"
    printf "\n[!!] About to create and format partitions:\n"
    printf "    -> /boot %s - Size: %s\n" "${boot_part}" "${boot_size}"
    printf "    -> Swap  %s - Size: %s\n" "${swap_part}" "${swap_size}"
    printf "    -> /     %s - Size: %s\n" "${root_part}" "${root_size}"
    printf "Are you sure? [y/N]: "; read a
    [ "${a}" == "y" ] || [ "${a}" == "Y" ] && printf "   - R3ally? ;) \n[y/N]: "; read a
    printf "%s" "${WHITE}"

    if [ "${a}" == "y" ] || [ "${a}" == "Y" ]; then

        # check if Partition Table already set
        # parted "/dev/${HD}" print | grep -q "Partition Table"
        parted -s "${HD}" mklabel msdos
        check_parted_status

	(echo n; echo p; echo 1; echo ; echo +${boot_size}; echo w; echo q) | fdisk ${HD}
        check_parted_status
        # partition bootable
        parted "${boot_part}" set 1 boot on
        check_parted_status

	(echo n; echo p; echo 2; echo ; echo +${swap_size}; echo w; echo q) | fdisk ${HD}
	check_parted_status

	(echo n; echo p; echo 3; echo ; echo +${root_size}; echo w; echo q) | fdisk ${HD}
	check_parted_status


        boot_part="${boot_part}1"
        swap_part="${swap_part}2"
	root_part="${root_part}3"
	
	"mkfs.${boot_type}" -L boot "${boot_part}"; check_mkfs_status
	printf "[+] Created boot partition: %s - ext2\n" "${boot_part}"

	if [ $LUKS == "YES" ]; then	
		#Format and encrypt ROOT partition
		printf "[+] Formatting ROOT partiton, please type your passphrase for encryption : \n"
		cryptsetup -y -v luksFormat "${root_part}"
		printf "[+] Openning encrypted partition, re-enter your passphrase : \n"
		cryptsetup open "${root_part}" cryptroot
		"mkfs.${root_type}" -L root "/dev/mapper/cryptroot"; check_mkfs_status
		printf "[+] Created root encrypted partition: /dev/mapper/cryptroot - ext4\n"
	
	else
		"mkfs.${root_type}" -L root "${root_part}"; check_mkfs_status
		printf "[+] Created root partition: %s - ext4\n" "${root_part}"
	fi

	/usr/bin/mkswap ${swap_part}; check_mkfs_status
	printf "[+] Created Swap partition: %s - SWAP\n" "${swap_part}"

    else
        # go back to setup up filesystem
        setup_filesystem
        return "${SUCCESS}"
    fi

    return "${SUCCESS}"
}

# manual mode
manual_partition()
{
    # manual defaults
    boot_part="${HD}1"
    swap_part="${HD}2"
    root_part="${HD}3"

    printf "[+] Create new partitions with cfdisk [only boot and root]\n"
    sleep 2
    cfdisk "${HD}"
    printf "    -> Number of the Boot partition created [1]: "
    read a; [ "${a}" != "" ] && boot_part="${HD}${a}"
    printf "    -> Type of Boot partition [ext2]: "
    read a; [ "${a}" != "" ] && boot_type="${a}"
    printf "    -> Number of the Swap partition created [2]:"
    read a; [ "${a}" != "" ] && swap_part="${a}"
    printf "    -> Number of the Root partition created [3]: "
    read a; [ "${a}" != "" ] && root_part="${HD}${a}"
    printf "    -> Type of Root partition [ext4]: "
    read a; [ "${a}" != "" ] && boot_type="${a}"
    
    # about to format
    printf "%s" "${RED}"
    printf "\n[!!] About to create and format partitions:\n"
    printf "    -> /boot %s with type %s\n" "${boot_part}" "${boot_type}"i
    printf "    -> Swap  %s with type Swap\n" "${swap_part}"
    printf "    -> /     %s with type %s\n" "${root_part}" "${root_type}"
    printf "Are you sure? [y/N]: "; read a
    [ "${a}" == "y" ] || [ "${a}" == "Y" ] && printf "   - R3ally? ;) \n[y/N]: "; read a
    printf "%s" "${WHITE}"

    if [ "${a}" == "y" ] || [ "${a}" == "Y" ]; then
        "mkfs.${boot_type}" -L boot "${boot_part}"; check_mkfs_status

	if [ $LUKS == "YES" ]; then
		#Format and encrypt ROOT partition
		printf "[*] Formatting ROOT partition, please type your passphrase encryption : \n"
		cryptsetup -y -v luksFormat "${root_part}"
		printf "[*] Openning encrypted partition, re-enter your passphrase : \n"
		cryptsetup open "${root_part}" cryptroot
		"mkfs.${root_type}" -L root "/dev/mapper/cryptroot"; check_mkfs_status
		printf "[*] Created root encrypted partition: /dev/mapper/cryptroot - "${root_type}
	else
		"mkfs.${root_type}" -L root "${root_part}"; check_mkfs_status
		/usr/bin/mkswap ${swap_part}; check_mkfs_status
	fi

    else
        # go back to setup up filesystem
        setup_filesystem
        return "${SUCCESS}"
    fi

    return "${SUCCESS}"
}

ask_for_luks()
{
    printf "%s" "${WHITE}"
    # user input for luks
    printf "[+] Do you want full encrypted root? (YES in upper case) :\n"
    read LUKS;

    if [ $LUKS == "YES" ]; then
	    printf "[!] Root will be encrypted\n"
    else
	    printf "[!] Root will NOT be encrypted\n"
    fi

}

setup_filesystem()	    
{
    printf "%s" "${WHITE}"
    # user input settings
    printf "[+] Type the device for install [%s]: " "${HD}"
    read a; [ "${a}" != "" ] && HD=${a} # sanitize input

    printf "    -> Hard Drive Selected: %s\n" "${HD}"

    while ! [ "${part_opt}" == "${PART_AUTO}" -o "${part_opt}" == "${PART_MANUAL}" ]; do
        printf "[+] Partition mode:\n"
        printf "%s[WARNING] If this is a real env (not a Virtual Machine):\n" "${RED}"
        printf " * We recomend you to make partitioning by hand with option 2.\n"
        printf " * This comes with no guarantees after option 1. You had been warned. ;)\n%s" "${WHITE}"
        printf "    1. Automatic - only empty HD! new partitions will be created in %s1, %s2 ans %s3\n" "${HD}" "${HD}" "${HD}"
        printf "    2. Manual - set manual partitions with cfdisk and format them\n"
        printf "Make your choice: "; read part_opt
    done

    if [ "${part_opt}" == "${PART_AUTO}" ]; then
        setup_partition_values "${part_opt}"
        format_filesystem
    else
        manual_partition
    fi

    printf "%s" "${NC}"

    return "${SUCCESS}"
}

mount_filesystem()
{
    mkdir -p "${ROOT}"
    if [ $LUKS == "YES" ]; then
	    mount -t "${root_type}" /dev/mapper/cryptroot "${ROOT}"
    else
	    mount -t "${root_type}" "${root_part}" "${ROOT}"
    fi

    mkdir -p "${ROOT}/boot"
    mount -t "${boot_type}" "${boot_part}" "${ROOT}/boot"

    swapon ${swap_part}

    return "${SUCCESS}"
}

install_base_packages()
{
    wprintf "  --> ArchLinux Base"
    pacstrap -c "${ROOT}" base

    [ ${?} != "0" ] && cri "Failed to install ArchLinux base packages"

    return "${SUCCESS}"
}

install_chroot()
{
    mode=${1}

    # setup chroot-install path
    if [ -f chroot-install ]; then
        chroot_file="chroot-install"
    else
        # we are a blackarch package installed
        chroot_file="/usr/share/blackarch-install-scripts/chroot-install"
    fi

    cp "${chroot_file}" "${ROOT}/bin/"
    mkdir -p ${ROOT}/{proc,sys,dev}

    mount -t proc proc "${ROOT}/proc"
    mount --rbind /dev "${ROOT}/dev"
    mount --rbind /sys "${ROOT}/sys"

    chroot "${ROOT}" "/bin/chroot-install" "${mode}" -d "${HD}"

    # cleaning up
    rm -rf "${ROOT}/bin/${chroot_file}"

    return "${SUCCESS}"
}

# only LIVE mode
dump_live()
{
    t=7 remaining=7;
    SECONDS=0;
    while sleep .2; do
        printf '\r[+] Down the rabbit hole we go '"${RED}$remaining"${NC}' ';
        if (( (remaining=t-SECONDS) <=0 )); then
            printf '\rseconds remaining to proceed' 0;
            break;
        fi;
    done

    cp -Rpv /bin /etc /home /lib /lib64 /opt /root /srv /usr /var /tmp "${ROOT}"

    # cleaning files - it will be create later
    rm -rf "${ROOT}/etc/{group, passwd, shadow*, gshadow*}"

    wprintf "[+] Dump done!"

    return "${SUCCESS}"
}

install()
{
    menu_opt=${1}

    # live flag for update system
    [ "${menu_opt}" == "${MENU_LIVE}" ] && LIVE="true"

    wprintf "[+] Updating system..."
    update_system

    wprintf "[+] Hard drive configuration..."
    ask_for_luks
    setup_filesystem

    wprintf "[+] Mounting filesystem..."
    mount_filesystem

    # if live dump everything
    [ "${menu_opt}" == "${MENU_LIVE}" ] && dump_live

    wprintf "[+] Installing packages..."
    install_base_packages

    wprintf "[+] Generating fstab..."
    genfstab -p "${ROOT}" >> "${ROOT}/etc/fstab"

    # if live not need to do this
    if [ "${menu_opt}" != "${MENU_LIVE}" ]; then
        wprintf "[+] Generating pacman.conf"
        cp -Rf /etc/pacman* "${ROOT}/etc/"

        wprintf "[+] Generating resolv.conf"
        cp /etc/resolv.conf "${ROOT}/etc/"
    fi

    wprintf "[+] Setting up grub config..."
    if [ -d grub ]; then
        cp grub/splash.png "${ROOT}/boot/"
    else
        # we are a blackarch package installed
        cp /usr/share/blackarch-install-scripts/grub/splash.png "${ROOT}/boot/"
    fi

    wprintf "[+] Installing chroot system..."
    if [ -d shell ]; then
        cp -f shell/etc/issue "${ROOT}/etc/"
        cp -R shell/ "${ROOT}/mnt/"
    else
        cp -f /usr/share/blackarch-install-scripts/shell/etc/issue "${ROOT}/etc/"
        cp -R /usr/share/blackarch-install-scripts/shell "${ROOT}/mnt/"
    fi
    # setup hostname
    sed -i 's/localhost/blackarch/g' "${ROOT}/etc/hosts"

    case "${menu_opt}" in
        "${MENU_LIVE}")
            install_chroot "-l"
            ;;
        "${MENU_REPO}")
            install_chroot "-r"
            ;;
        "${MENU_BLACKMAN}")
            install_chroot "-b"
            ;;
    esac

    return "${SUCCESS}"
}

install_menu()
{
    printf "%s" "${WHITE}"
    while ! [ "${menu_opt}" == "${MENU_LIVE}" \
           -o "${menu_opt}" == "${MENU_REPO}" \
           -o "${menu_opt}" == "${MENU_BLACKMAN}" ]; do

        printf "[+] Select Install Mode:\n"
        printf "    1. Install from Live-ISO.\n"
        printf "    2. Install from Arch Official Repository.\n"
        printf "    3. Install from Blackman.\n"
        printf "Make a choice: "; read menu_opt
    done

    printf "%s" "${NC}"

    return "${SUCCESS}"
}


# parse command line options
get_opts()
{
    while getopts vVH flags
    do
        case "${flags}" in
            #i)
            #    #optarg=${OPTARG}
            #    opt="install"
            #    ;;
            v)
                VERBOSE="/dev/stdout"
                ;;
            V)
                printf "%s\n" "${VERSION}"
                exit "${SUCCESS}"
                ;;
            H)
                usage
                ;;
            *)
                err "WTF?! mount /dev/brain"
                ;;
        esac
    done

    return "${SUCCESS}"
}

# controller and program flow
main()
{
    banner
    check_argc ${*}
    get_opts ${*}
    check_args ${*}
    check_env

    # commented arg opt
    #if [ "${opt}" == "install" ]; then
        if [[ "${SEC_ENABLE}" == "false" ]]; then
            install_menu
            install "${menu_opt}"
        else
            cri "SEC_ENABLE var active - vim blackarch-install"
        fi
    #fi
    return "${SUCCESS}"
}


# program start
main ${*}

# EOF

