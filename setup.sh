#!/bin/sh
clear

### SET GLOBAL VARIABLES ###

TEMPDIR="/tmp/pijarr"
APPLIST="jackett sonarr lidarr radarr readarr prowlarr bazarr qbittorrent-nox"

# Set terminal global variable for colors if supported.
if [ -t 1 ]; then
    RED=$(printf '\033[31m')
    GREEN=$(printf '\033[32m')
    YELLOW=$(printf '\033[33m')
    BLUE=$(printf '\033[34m')
    MAGENTA=$(printf '\033[35m')
    CYAN=$(printf '\033[36m')
    BOLD=$(printf '\033[1m')
    RESET=$(printf '\033[0m')
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    BOLD=""
    RESET=""
fi

# Temporary directory for application sources
make_temp_dir() {
    task_start "Creating temporary directory ${TEMPDIR}..."
    mkdir -p "${TEMPDIR}" 2>/dev/null
    check_result
}

remove_temp_dir() {
    task_start "Removing temporary directory and files ${TEMPDIR}..."
    rm -Rf "${TEMPDIR}" 2>/dev/null
    check_result
}

task_start() {
    printf "\r[TASK] ${1}$(tput el)"
}

task_fail() {
    printf "\r[${RED}FAIL${RESET}] ${1}\n"
}

task_pass() {
    printf "\r[${GREEN}PASS${RESET}] ${1}\n"
}

task_skip() {
    printf "\r[${BLUE}SKIP${RESET}] ${1}\n"
}

task_info() {
    printf "\r[${CYAN}INFO${RESET}] ${1}$(tput el)\n"
}

task_warn() {
    printf "\r[${CYAN}WARN${RESET}] ${1}$(tput el)\n"
}

task_dbug() {
    printf "\r[${YELLOW}DBUG${RESET}] ${1}$(tput el)\n"
}

title_case() {
    printf "%s" "${1}" | tr '[:upper:]' '[:lower:]' | awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1'
}

lower_case() {
    printf "%s" "${1}" | tr '[:upper:]' '[:lower:]'
}

upper_case() {
    printf "%s" "${1}" | tr '[:lower:]' '[:upper:]'
}

check_result() {
    if [ $? -eq 0 ]; then
        task_pass
    else
        task_fail
    fi
}

### START CHECK SYSTEM REQUIREMENTS AND ARCHITECTURE ###

if cat /proc/cpuinfo >/dev/null 2>&1; then
    check_cpu=$(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d':' -f2 | xargs)
    check_model=$(cat /proc/cpuinfo | grep Model | head -1 | cut -d':' -f2 | xargs)
    if [ -z "${check_cpu}" ]; then
        result="${check_model}"
    else
        result="${check_cpu}"
    fi
    if [ -n "${result}" ]; then
        cpuBoardInfo="${result}"
    fi
elif sysctl -a >/dev/null 2>&1; then
    result=$(sysctl -a | egrep -i 'hw.model' | sed 's/[^ ]* //')
    if [ -n "${result}" ]; then
        cpuBoardInfo="${result}"
    fi
fi

if command -v lsb_release >/dev/null 2>&1; then
    dist=$(lsb_release -d --short)
    osInfo="${dist}"
fi
if $(command -v uname) >/dev/null 2>&1; then
    arch=$(uname -m)
    kernel=$(uname -r)
    kname=$(uname -s)
    if [ -z "${dist}" ]; then
        osInfo="${kname}"
    fi
    kernelInfo="${kernel}"
    archInfo="${arch}"
fi

task_info "Checking hardware requirements..."
task_info "Detected: ${cpuBoardInfo}"
task_info "Detected: ${osInfo} ${kernelInfo}"

systemInfo="${cpuBoardInfo} ${kname} ${osInfo} ${kernelInfo} ${archInfo}"

case "${systemInfo}" in
*x86_64* | *X86_64* | *amd64* | *AMD64*)
    task_pass "Detected: x86 64-Bit Architecture$(tput el)"
    JACKETT_ARCH="AMDx64"
    SERVARR_ARCH="x64"
    ;;
esac

case "${systemInfo}" in
*aarch64* | *AARCH64* | *arm64* | *ARM64* | *armv8* | *ARMV8*)
    task_pass "Detected: ARM 64-Bit Architecture$(tput el)"
    JACKETT_ARCH="ARM64"
    SERVARR_ARCH="arm64"
    ;;
esac

case "${systemInfo}" in
*aarch32* | *AARCH32* | *arm32* | *ARM32* | *armv7l* | *ARMV7L*)
    task_pass "Detected: ARM 32-Bit Architecture$(tput el)"
    JACKETT_ARCH="ARM32"
    SERVARR_ARCH="arm"
    ;;
esac

case "${systemInfo}" in
*linux* | *Linux* | *LINUX*) task_pass "Detected: Linux based OS$(tput el)" ;;
*)
    task_fail "Linux required. Not detected. Exiting...$(tput el)"
    echo ""
    exit 1
    ;;
esac
### END CHECK SYSTEM REQUIREMENTS AND ARCHITECTURE ###

# Fetch latest jackett release from https://github.com/Jackett/Jackett/releases
if command -v curl >/dev/null 2>&1; then
    # Run the curl command
    jackett_latest=$(curl -s https://github.com/Jackett/Jackett/releases | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep Linux${JACKETT_ARCH}.tar.gz -A 0 | head -n 1)
    jackett_src_url="https://github.com${jackett_latest}"
else
    # Run the wget command
    jackett_latest=$(wget -qO- https://github.com/Jackett/Jackett/releases | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep Linux${JACKETT_ARCH}.tar.gz -A 0 | head -n 1)
    jackett_src_url="https://github.com${jackett_latest}"
fi

# Fetch latest radarr, lidarr and sonarr builds. Links below select latest release.
radarr_src_url="https://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=${SERVARR_ARCH}"
lidarr_src_url="https://lidarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=${SERVARR_ARCH}"
prowlarr_src_url="http://prowlarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=${SERVARR_ARCH}"
readarr_src_url="http://readarr.servarr.com/v1/update/develop/updatefile?os=linux&runtime=netcore&arch=${SERVARR_ARCH}"
sonarr_src_url="https://services.sonarr.tv/v1/download/main/latest?version=4&os=linux&arch=${SERVARR_ARCH}"
bazarr_src_url="https://github.com/morpheus65535/bazarr/releases/latest/download/bazarr.zip"
qbittorrent_nox_src_url="Not applicable. Installed via apt."

check_sources() {
    task_info "Application Installation Source URLs"
    for app in ${APPLIST}; do
        app_var_name=$(echo "${app}" | tr '-' '_')  # Replace hyphens with underscores
        src_url_var="${app_var_name}_src_url"
        src_url=$(eval echo \$"$src_url_var")
        task_info "${app} src: ${src_url}"
    done
}

# Function to pause script and check if the user wishes to continue.
check_continue() {
    local response
    while true; do
        read -r -p "[${GREEN}USER${RESET}] Do you wish to continue (y/N)? " response
        case "${response}" in
        [yY][eE][sS] | [yY])
            echo
            break
            ;;
        *)
            echo
            exit
            ;;
        esac
    done
}

press_any_key() {
    echo ""
    printf "%s " "[${GREEN}USER${RESET}] Press enter to continue..."
    read ans
}

# Function to check if superuser or running using sudo
check_superuser() {
    if [ "$(id -u)" -ne 0 ]; then
        task_fail "Script must be run by superuser or using sudo command\n"
        exit 1
    fi
}

pkg_updates() {
    task_info "Updating and upgrading packages using apt..."
    apt update
    apt upgrade -y
    apt --fix-broken install -y
    apt autoclean -y 2>/dev/null
    apt autoremove -y 2>/dev/null
}

# Function to check if packages are installed and install them if they are not found.
pkg_install() {
    for pkg in "${@}"; do
        task_start "Checking for required package > ${pkg}"
        pkgStatus=$(dpkg -s "${pkg}" 2>/dev/null)
        result=$?
        if [ "${result}" -ne 0 ]; then
            task_warn "Package ${pkg} not installed.$(tput el)"
            task_info "Installing ${pkg}..."
            apt install -y "${pkg}"
        else
            task_pass "Package ${pkg} already installed.$(tput el)"
        fi
    done
}

pkg_remove() {
    for pkg in "${@}"; do
        task_start "Checking for required package > ${pkg}"
        pkgStatus=$(dpkg -s "${pkg}" 2>/dev/null)
        result=$?
        if [ "${result}" -eq 0 ]; then
            task_warn "Package ${pkg} installed.$(tput el)"
            task_info "Removing ${pkg}..."
            apt remove -y "${pkg}"
        else
            task_pass "Package ${pkg} not installed.$(tput el)"
        fi
    done
}

pkg_purge() {
    apt-get -y --purge remove \"$@\"
}


# Function to install all the dependencies including packages and server keys.
setup_dependencies() {
    task_info "Installing required dependencies..."
    pkg_install curl unzip apt-transport-https dirmngr gnupg ca-certificates
    task_info "Installing mono, sqlite3 and supporting libraries..."
    pkg_install mono-complete mediainfo sqlite3 libmono-cil-dev libchromaprint-tools
}

setup_bazarr_dependencies() {
    task_info "Installing required Bazarr dependencies..."
    pkg_install python3-dev python3-pip python3-libxml2 python3-lxml unrar-free unar ffmpeg libxml2-dev libxslt1-dev libatlas-base-dev
    python_version=$(python3 -V 2>&1 | grep -Po '(?<=Python )\d+\.\d+')
    # Attempt to install specific python3-venv version
    if ! pkg_install python${python_version}-venv; then
        # If installation fails, install the default python3-venv
        pkg_install python3-venv
    fi
}

# Function to output PiJARR ascii and details of script.
banner_info() {
    printf '%s\n' "                                                               
    ${RED}▓▓▓▓▓▓▓▓▓▓▓▓ ${GREEN}▓▓▓▓${RESET}         ▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓
    ${RED}▓▓▓▓    ▓▓▓▓     ${RESET}         ▓▓▓▓ ▓▓▓▓    ▓▓▓▓ ▓▓▓▓    ▓▓▓▓ ▓▓▓▓    ▓▓▓▓
    ${RED}▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓${RESET} ▓▓▓▓    ▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓▓▓▓▓▓▓▓▓
    ${RED}▓▓▓▓         ▓▓▓▓${RESET} ▓▓▓▓    ▓▓▓▓ ▓▓▓▓    ▓▓▓▓ ▓▓▓▓  ▓▓▓▓   ▓▓▓▓  ▓▓▓▓
    ${RED}▓▓▓▓         ▓▓▓▓${RESET} ▓▓▓▓▓▓▓▓▓▓▓▓ ▓▓▓▓    ▓▓▓▓ ▓▓▓▓   ▓▓▓▓▓ ▓▓▓▓   ▓▓▓▓▓
    "
}

script_info() {
    banner_info
    printf '%s\n' "
    Description:    Installer for Jackett, Sonarr, Radarr, Lidarr, Readarr, Prowler, and *Bazarr
                    Tested with Raspberry Pi 3 & 4 running offical Raspberry Pi OS 64-Bit.
                    Compatibility with other Intel AMD x64 (64-bit only) Debian based Linux distros

    Author:         github.com/pijarr

    Notes:          Requiries sudo/root superuser permissions to run.

                    *Bazarr requires Python3 and additional packages to be downloaded. It will be run
                    in a Python virtual environment (venv) to avoid dependency issues.

                    Commands \"apt update upgrade autoclean autoremove\" will be run upon continue.
                    This is to ensure all packages are up to date and latest versions are used.

                    If they are not already installed the required dependencies including 
                    Mono (Cross platform, open source .NET framework) may take a while to 
                    download and install. 
                    
                    After initial setup the web interface for the application may need a short time 
                    to start before being available on the nominated host port.

"
}

# Primary function to install and configure the applications.
# Function can take one or more apps ie. setup_app jackett sonarr lidarr radarr
setup_app() {
    clear
    make_temp_dir
    setup_dependencies

    for app in "${@}"; do
        if [ $(systemctl is-active "${app}") = "active" ]; then
            task_skip "A service for ${app} is already exists."
            continue
        fi
        date_stamp="$(date '+%Y-%m-%d %H%M')"
        app_name="$(lower_case ${app})"
        app_opt_path="/opt/$(title_case ${app_name})"
        app_lib_path="/var/lib/${app}"
        app_config_path="/var/lib/${app_name}/.config/$(title_case ${app_name})"
        if [ "${app}" = "bazarr" ]; then
            setup_bazarr_dependencies
            file_extension="zip"
        else
            file_extension="tar.gz"
        fi
        app_user="${app_name}"
        app_group="media"
        src_url=${app_name}\_src_url
        src_url=$(eval echo \$"$src_url")
        new_file="${app_name}.${file_extension}"
        task_info "Commencing install for ${app_name}..."
        task_start "Adding ${app_user} service user..."
        if id "${app_user}" >/dev/null 2>&1; then
            task_pass "User account for ${app_user} already exists."
        else
            useradd -s /usr/sbin/nologin -d "/var/lib/${app_user}" -r -m -U "${app_user}" 2>/dev/null
            check_result
        fi
        task_start "Adding ${app_group} service group..."
        if getent group "${app_group}" >/dev/null 2>&1; then
            task_pass "Group ${app_group} already exists."
        else
            groupadd "${app_group}" 2>/dev/null
            check_result
        fi
        task_start "Adding ${app_user} to ${app_group} service group..."
        if id "$app_user" | grep -qE "\b${app_group}\b"; then
            task_pass "User $app_user is already a member of the ${app_group} group."
        else
            usermod -a -G "${app_group}" "$app_user"
            check_result
        fi
        # Determine the actual username (not sudo or root)
        actual_user="${SUDO_USER:-$USER}"
        task_start "Adding ${actual_user} to ${app_group} service group..."
        if id "$actual_user" | grep -qE "\b${app_group}\b"; then
            task_pass "User $actual_user is already a member of the ${app_group} group."
        else
            usermod -a -G "${app_group}" "$actual_user"
            check_result
        fi
        task_info "Download source URL: ${src_url}"
        wget -O "${temp_dir}"/"${new_file}" -q --show-progress --progress=bar:force "${src_url}" 2>&1 &&
            task_pass "Source file downloaded. SHA256: $(sha256sum ${temp_dir}/${new_file} | cut -d ' ' -f 1)$(tput el)"
        task_info "Extracting ${temp_dir}/${new_file} to ${app_opt_path}..."
        if [ "${app_name}" = "bazarr" ]; then
            unzip "${temp_dir}/${new_file}" -d "${app_opt_path}"
            task_info "Creating Python virtual environment (venv) for bazarr..."
            python3 -m venv "${app_opt_path}/venv"
            task_start "Activate Python venv for bazarr to install requirements..."
            # /bin/sh alternative for source command
            . "${app_opt_path}/venv/bin/activate"
            check_result
            task_info "Installing Bazarr Python import module requirements..."
            pip install -r "${app_opt_path}/requirements.txt"
            task_start "Deactivate Python venv..."
            deactivate
            check_result
        else
            tar -xf "${temp_dir}/${new_file}" -C "/opt/"
        fi
        task_start "Setting user permissions on ${app_opt_path}..."
        chown -R "${app_user}":"${app_group}" "${app_opt_path}"
        check_result
        # Just in case some apps have permission problems with their /var/lib config working directories.
        task_start "Creating /var/lib config files..."
        mkdir -p "${app_config_path}"
        check_result
        task_start "Setting user permissions on ${app_lib_path}..."
        chown -R "${app_user}":"${app_group}" "${app_lib_path}" &&
        chmod 775 "${app_lib_path}"
        check_result
        # Begin writting out the service configuration file. Minor change needed for Jackett.
        if [ "${app_name}" = "jackett" ]; then
            app_exec="${app_opt_path}/${app_name}_launcher.sh"
        elif [ "${app_name}" = "sonarr" ]; then
            app_exec="${app_opt_path}/$(title_case ${app_name}) -nobrowser -data=${app_lib_path}"
        elif [ "${app_name}" = "bazarr" ]; then
            app_exec="${app_opt_path}/venv/bin/python ${app_opt_path}/bazarr.py"
        else
            app_exec="${app_opt_path}/$(title_case ${app_name})"
        fi
        task_start "Writing service configuration file /etc/systemd/system/${app_name}.service..."

        tee /etc/systemd/system/"${app_name}".service 1>/dev/null <<EOF
# Generated by PiJARR ${date_stamp}
[Unit]
Description=$(title_case ${app_name}) Daemon
After=syslog.target network.target

[Service]
WorkingDirectory=${app_opt_path}
User=${app_user}
Group=${app_group}
UMask=0002
SyslogIdentifier=${app_name}
Restart=on-failure
RestartSec=5
Type=simple
ExecStart=${app_exec}
KillSignal=SIGINT
TimeoutStopSec=20
ExecStartPre=/bin/sleep 10

[Install]
WantedBy=multi-user.target
EOF
        check_result
        task_start "Reloading systemctl daemon..."
        systemctl daemon-reload 2>/dev/null
        check_result
        task_start "Enabling auto start for ${app_name} service..."
        systemctl enable "${app_name}" 2>/dev/null
        check_result
        task_start "Starting ${app_name} service..."
        systemctl start "${app_name}" 2>/dev/null
        check_result
        check_service ${app_name}
        task_info "Completed install for ${app_name}\n"
    done
    remove_temp_dir
}

# Function to assist in removing the applications and their configuration files
# Function can take one or more apps ie. remove_app jackett sonarr lidarr radarr
remove_app() {
    clear
    for app in "${@}"; do
        app=$(lower_case "${app}")
        app_opt_path="/opt/$(title_case "${app}")"
        app_lib_path="/var/lib/${app}"
        task_warn "You are about to delete all settings and files for ${app}..."
        check_continue
        task_info "Deleting existing settings or files for ${app}..."
        task_start "Stopping ${app} service..."
        systemctl stop "${app}" 2>/dev/null
        task_pass
        task_start "Removing ${app_opt_path}..."
        if [ "${app_opt_path}" != "/opt" ] && [ "${app_opt_path}" != "/opt/" ]; then
            rm -rf "${app_opt_path}" 2>/dev/null
            task_pass
        else
            task_skip "Skipping removal of default /opt/ directory."
        fi

        task_start "Removing ${app_lib_path}..."
        if [ "${app_lib_path}" != "/var/lib" ] && [ "${app_lib_path}" != "/var/lib/" ]; then
            rm -rf "${app_lib_path}" 2>/dev/null
            task_pass
        else
            task_skip "Skipping removal of default /var/lib/ directory."
        fi
        task_start "Removing service config /etc/systemd/system/${app}.service..."
        rm "/etc/systemd/system/${app}.service"* 2>/dev/null
        task_pass
        task_info "Removing ${app} service user account..."
        deluser "${app}" 2>/dev/null
        task_start "Reloading systemctl daemon..."
        systemctl daemon-reload 2>/dev/null
        task_pass
        task_info "${app} deleted.\n"
    done
}

setup_qbittorrent_nox() {
    date_stamp="$(date '+%Y-%m-%d %H%M')"
    app_name="qbittorrent-nox"
    app_user="${app_name}"
    app_lib_path="/var/lib/${app_name}"
    app_group="media"
    task_info "Commencing install for ${app_name}..."
    task_start "Adding ${app_user} service user..."
    if id "${app_user}" >/dev/null 2>&1; then
        task_pass "User account for ${app_user} already exists."
    else
        useradd -s /usr/sbin/nologin -d "/var/lib/${app_user}" -r -m -U "${app_user}" 2>/dev/null
        check_result
    fi
    task_start "Adding ${app_group} service group..."
    if getent group "${app_group}" >/dev/null 2>&1; then
        task_pass "Group ${app_group} already exists."
    else
        groupadd "${app_group}" 2>/dev/null
        check_result
    fi
    task_start "Adding ${app_user} to ${app_group} service group..."
    if id "$app_user" | grep -qE "\b${app_group}\b"; then
        task_pass "User $app_user is already a member of the ${app_group} group."
    else
        usermod -a -G "${app_group}" "$app_user"
        check_result
    fi
    # Determine the actual username (not sudo or root)
    actual_user="${SUDO_USER:-$USER}"
    task_start "Adding ${actual_user} to ${app_group} service group..."
    if id "$actual_user" | grep -qE "\b${app_group}\b"; then
        task_pass "User $actual_user is already a member of the ${app_group} group."
    else
        usermod -a -G "${app_group}" "$actual_user"
        check_result
    fi
    task_info "Installing ${app_name} package..."
    pkg_install qbittorrent-nox
    task_start "Setting user permissions on ${app_lib_path}..."
    chown -R "${app_user}":"${app_group}" "${app_lib_path}" &&
    chmod 775 "${app_lib_path}"
    check_result
    task_start "Writing service configuration file /etc/systemd/system/${app_name}.service..."
    tee /etc/systemd/system/"${app_name}".service 1>/dev/null <<EOF
# Generated by PiJARR ${date_stamp}
[Unit]
Description=$(title_case ${app_name}) Daemon
After=syslog.target network.target

[Service]
User=${app_user}
Group=${app_group}
UMask=0002
SyslogIdentifier=${app_name}
Restart=on-failure
RestartSec=5
Type=forking
ExecStart=/usr/bin/qbittorrent-nox -d --webui-port=8080
KillSignal=SIGINT
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF
    check_result
    task_start "Reloading systemctl daemon..."
    systemctl daemon-reload 2>/dev/null
    check_result
    task_start "Enabling auto start for ${app_name} service..."
    systemctl enable "${app_name}" 2>/dev/null
    check_result
    task_start "Starting ${app_name} service..."
    systemctl start "${app_name}" 2>/dev/null
    check_result
    check_service "${app_name}"
    task_info "Completed install for ${app_name}\n"
    task_info "Default qBittorrent username: admin password: adminadmin"
    task_info "Default qBittorrent save directory /var/lib/qbittorrent-nox/Downloads"
}

remove_qbittorrent_nox() {
    app_name="qbittorrent-nox"
    app_lib_path="/var/lib/${app_name}"
    task_warn "You are about to delete all settings and files for ${app_name}..."
    check_continue
    task_info "Deleting existing settings or files for ${app_name}..."
    task_start "Stopping ${app_name} service..."
    systemctl stop "${app_name}" 2>/dev/null
    task_pass
    task_start "Removing service config /etc/systemd/system/${app_name}.service..."
    rm "/etc/systemd/system/${app_name}.service"* 2>/dev/null
    task_pass
    pkg_remove qbittorrent-nox
    task_info "Removing ${app} service user account..."
    deluser "${app_name}" 2>/dev/null
    task_start "Removing ${app_lib_path}..."
    if [ "${app_lib_path}" != "/var/lib" ] && [ "${app_lib_path}" != "/var/lib/" ]; then
        rm -rf "${app_lib_path}" 2>/dev/null
        task_pass
    else
        task_skip "Skipping removal of default /var/lib/ directory."
    fi
    task_info "${app_name} deleted.\n"
}

###############################################################################
#  NZBGet – headless Usenet downloader (runs as a service like qBittorrent)  #
#########################setup_nzbget() {
    date_stamp="$(date '+%Y-%m-%d %H:%M')"
    app_name="nzbget"
    app_user="${app_name}"
    app_group="media"
    app_lib_path="/var/lib/${app_name}"

    task_info "Commencing install for ${app_name}…"

    # Create service user and ensure group memberships
    task_start "Adding ${app_user} service user…"
    if id "${app_user}" >/dev/null 2>&1; then
        task_pass "User account for ${app_user} already exists."
    else
        useradd -s /usr/sbin/nologin -d \"${app_lib_path}\" -r -m -U \"${app_user}\"
        check_result
    fi

    task_start \"Adding ${app_group} service group…\"
    getent group \"${app_group}\" >/dev/null 2>&1 || groupadd \"${app_group}\"
    check_result

    task_start \"Adding ${app_user} to ${app_group}…\"
    id \"${app_user}\" | grep -qE \"\\b${app_group}\\b\" || usermod -a -G \"${app_group}\" \"${app_user}\"
    check_result

    actual_user=\"${SUDO_USER:-$USER}\"
    task_start \"Adding ${actual_user} to ${app_group}…\"
    id \"${actual_user}\" | grep -qE \"\\b${app_group}\\b\" || usermod -a -G \"${app_group}\" \"${actual_user}\"
    check_result

    # Install package (or reinstall if binary missing)
    task_info \"Installing ${app_name} package…\"
    pkg_install nzbget
    if ! command -v nzbget >/dev/null 2>&1; then
        task_warn \"${app_name} binary missing — forcing reinstall…\"
        apt-get -y --reinstall install nzbget
    fi

    # Prepare configuration directory and default config
    mkdir -p \"${app_lib_path}\"
    if [ ! -f \"${app_lib_path}/nzbget.conf\" ]; then
        if [ -f /etc/nzbget.conf ]; then
            cp /etc/nzbget.conf \"${app_lib_path}/nzbget.conf\"
        else
            gunzip -c /usr/share/doc/nzbget/examples/nzbget.conf.gz > \"${app_lib_path}/nzbget.conf\"
        fi
    fi
    chown -R \"${app_user}:${app_group}\" \"${app_lib_path}\"

    # Discover binary path
    nzb_bin=\"$(command -v nzbget || echo /usr/bin/nzbget)\"

    # Systemd service
    task_start \"Writing /etc/systemd/system/${app_name}.service…\"
    tee /etc/systemd/system/\"${app_name}\".service >/dev/null <<EOF
# Generated by PiJARR ${date_stamp}
[Unit]
Description=NZBGet Daemon
After=network.target

[Service]
User=${app_user}
Group=${app_group}
UMask=0002
Type=forking
ExecStart=${nzb_bin} -D -c ${app_lib_path}/nzbget.conf
ExecStop=${nzb_bin} -Q
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    check_result

    systemctl daemon-reload
    systemctl enable \"${app_name}\"
    systemctl start \"${app_name}\"
    check_service \"${app_name}\"
    task_info \"Completed install for ${app_name}\"
    task_info \"Default NZBGet web UI → http://hostip:6789  (user: nzbget | pass: tegbzn6789)\"
}

remove_nzbget() {
    app_name=\"nzbget\"
    app_lib_path=\"/var/lib/${app_name}\"

    task_warn \"You are about to delete all settings and files for ${app_name}…\"
    check_continue

    systemctl stop \"${app_name}\" 2>/dev/null
    rm -f /etc/systemd/system/\"${app_name}\".service
    systemctl daemon-reload
    pkg_purge nzbget
    deluser --remove-home \"${app_name}\" 2>/dev/null
    rm -rf \"${app_lib_path}\"
    task_info \"${app_name} deleted.\"
}app_lib_path}"
    task_info "${app_name} deleted."
}

active_services() {
    task_info "Active Services"
    for app in ${APPLIST}; do
        if [ $(systemctl is-active "${app}") = "active" ]; then
            task_pass "${app} service is active and running."
        fi
    done
}

check_service() {
    task_start "Checking service status for ${1}..."
    if [ $(systemctl is-active "$1") = "active" ]; then
        task_pass
    else
        task_fail
    fi
}

default_ports() {
    task_info "Default Application Ports"
    task_info "Jackett:         http://hostip:9117"
    task_info "Sonarr:          http://hostip:8989"
    task_info "Lidarr:          http://hostip:8686"
    task_info "Radarr:          http://hostip:7878"
    task_info "Readarr:         http://hostip:8787"
    task_info "Prowlarr:        http://hostip:9696"
    task_info "Bazarr:          http://hostip:6767"
    task_info "qBittorrent-nox: http://hostip:8080"
    task_info "NZBGet:          http://hostip:6789"
}

# Display a list of menu items for selection
display_menu() {
    clear
    banner_info
    echo "=============="
    echo " Menu Options "
    echo "=============="
    echo
    printf "1.  Install ALL (jackett sonarr lidarr radarr readarr prowlarr bazarr)\n"
    printf "2.  Install jackett only\n"
    printf "3.  Install sonarr only\n"
    printf "4.  Install lidarr only\n"
    printf "5.  Install radarr only\n"
    printf "6.  Install readarr only\n"
    printf "7.  Install prowlarr only\n"
    printf "8.  Install bazarr only\n"
    printf "\n9.  Install qbittorrent-nox (headless BitTorrent client)\n"
    printf "10. Install nzbget (headless Usenet client)\n"
    printf "\n11. Remove ALL (jackett sonarr lidarr radarr readarr prowlarr bazarr)\n"
    printf "12. Remove jackett only\n"
    printf "13. Remove sonarr only\n"
    printf "14. Remove lidarr only\n"
    printf "15. Remove radarr only\n"
    printf "16. Remove readarr only\n"
    printf "17. Remove prowlarr only\n"
    printf "18. Remove bazarr only\n"
    printf "\n19. Remove qbittorrent-nox\n"
    printf "20. Remove nzbget\n"
    printf "\n21. Show active services\n"
    printf "22. Show application default ports\n"
    printf "23. Show application source urls\n"
    printf "\n24. Exit\n"
    echo
    printf "    Enter option [1-24]: "

    while :; do
        read choice
        case ${choice} in
        1)
            setup_app jackett sonarr lidarr radarr readarr prowlarr bazarr
            ;;
        2)
            setup_app jackett
            ;;
        3)
            setup_app sonarr
            ;;
        4)
            setup_app lidarr
            ;;
        5)
            setup_app radarr
            ;;
        6)
            setup_app readarr
            ;;
        7)
            setup_app prowlarr
            ;;
        8)
            setup_app bazarr
            ;;
        9)
            setup_qbittorrent_nox
            ;;
        10)
            setup_nzbget
            ;;
        11)
            remove_app jackett sonarr lidarr radarr readarr prowlarr bazarr
            ;;
        12)
            remove_app jackett
            ;;
        13)
            remove_app sonarr
            ;;
        14)
            remove_app lidarr
            ;;
        15)
            remove_app radarr
            ;;
        16)
            remove_app readarr
            ;;
        17)
            remove_app prowlarr
            ;;
        18)
            remove_app bazarr
            ;;
        19)
            remove_qbittorrent_nox
            ;;
        20)
            remove_nzbget
            ;;
        21)
            clear
            active_services
            ;;
        22)
            clear
            default_ports
            ;;
        23)
            clear
            check_sources
            ;;
        24)
            printf "\nExiting...\n"
            exit
            ;;
        *)
            clear
            display_menu
            ;;
        esac
        printf "\nSelection [${choice}] completed.\n"
        press_any_key
        clear
        display_menu
    done
}

main() {
    check_sources
    script_info
    check_superuser
    check_continue
    pkg_updates
    check_status
    display_menu
}

main
