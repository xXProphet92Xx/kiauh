#!/bin/bash

#=======================================================================#
# Copyright (C) 2020 - 2022 Dominik Willner <th33xitus@gmail.com>       #
#                                                                       #
# This file is part of KIAUH - Klipper Installation And Update Helper   #
# https://github.com/th33xitus/kiauh                                    #
#                                                                       #
# This file may be distributed under the terms of the GNU GPLv3 license #
#=======================================================================#

set -e

### global variables
SYSTEMD="/etc/systemd/system"
INI_FILE="${HOME}/.kiauh.ini"
LOGFILE="/tmp/kiauh.log"

#================================================#
#=================== STARTUP ====================#
#================================================#

function check_euid(){
  if [ "${EUID}" -eq 0 ]
  then
    echo -e "${red}"
    top_border
    echo -e "|       !!! THIS SCRIPT MUST NOT RAN AS ROOT !!!        |"
    bottom_border
    echo -e "${white}"
    exit 1
  fi
}

#================================================#
#============= MESSAGE FORMATTING ===============#
#================================================#
green=$(echo -en "\e[92m")
yellow=$(echo -en "\e[93m")
red=$(echo -en "\e[91m")
cyan=$(echo -en "\e[96m")
white=$(echo -en "\e[39m")

function select_msg() {
  echo -e "${white}>>>>>> $1"
}
function warn_msg(){
  echo -e "${red}>>>>>> $1${white}"
}
function status_msg(){
  echo; echo -e "${yellow}###### $1${white}"
}
function ok_msg(){
  echo -e "${green}>>>>>> $1${white}"
}
function error_msg(){
  echo -e "${red}>>>>>> $1${white}"
}
function abort_msg(){
  echo -e "${red}<<<<<< $1${white}"
}
function title_msg(){
  echo -e "${cyan}$1${white}"
}

function print_error(){
  [ -z "${1}" ] && return
  echo -e "${red}"
  echo -e "#########################################################"
  echo -e " ${1} "
  echo -e "#########################################################"
  echo -e "${white}"
}

function print_confirm(){
  [ -z "${1}" ] && return
  echo -e "${green}"
  echo -e "#########################################################"
  echo -e " ${1} "
  echo -e "#########################################################"
  echo -e "${white}"
}

#================================================#
#=================== LOGGING ====================#
#================================================#

function timestamp() {
  date +"[%F %T]"
}

function log_info() {
  local message="${1}"
  echo -e "$(timestamp) <INFO> ${message}" | tr -s " " >> "${LOGFILE}"
}

function log_warning() {
  local message="${1}"
  echo -e "$(timestamp) <WARN> ${message}" | tr -s " " >> "${LOGFILE}"
}

function log_error() {
  local message="${1}"
  echo -e "$(timestamp) <ERR> ${message}" | tr -s " " >> "${LOGFILE}"
}

#================================================#
#=============== KIAUH SETTINGS =================#
#================================================#

function read_kiauh_ini(){
  if [ ! -f "${INI_FILE}" ]; then
    log_error "Reading from .kiauh.ini failed! File not found!"
    return
  fi
  log_info "Reading from .kiauh.ini"
  source "${INI_FILE}"
}

function init_ini(){
  ### remove pre-version 4 ini files
  if [ -f "${INI_FILE}" ] && ! grep -Eq "^# KIAUH v4\.0\.0$" "${INI_FILE}"; then
    rm "${INI_FILE}"
  fi
  ### initialize ini file
  if [ ! -f "${INI_FILE}" ]; then
    {
      echo -e "# File creation date: $(date)"
      echo -e "#=================================================#"
      echo -e "# KIAUH - Klipper Installation And Update Helper  #"
      echo -e "#       https://github.com/th33xitus/kiauh        #"
      echo -e "#             DO NOT edit this file!              #"
      echo -e "#=================================================#"
      echo -e "# KIAUH v4.0.0"
    } >> "${INI_FILE}"
  fi
  if ! grep -Eq "^backup_before_update=." "${INI_FILE}"; then
    echo -e "\nbackup_before_update=false\c" >> "${INI_FILE}"
  fi
  if ! grep -Eq "^logupload_accepted=." "${INI_FILE}"; then
    echo -e "\nlogupload_accepted=false\c" >> "${INI_FILE}"
  fi
  if ! grep -Eq "^custom_klipper_cfg_loc=" "${INI_FILE}"; then
    echo -e "\ncustom_klipper_cfg_loc=\c" >> "${INI_FILE}"
  fi
  if ! grep -Eq "^mainsail_install_unstable=" "${INI_FILE}"; then
    echo -e "\nmainsail_install_unstable=false\c" >> "${INI_FILE}"
  fi
  if ! grep -Eq "^fluidd_install_unstable=" "${INI_FILE}"; then
    echo -e "\nfluidd_install_unstable=false\c" >> "${INI_FILE}"
  fi
  fetch_webui_ports
}

check_klipper_cfg_path(){
  source_kiauh_ini
  if [ -z "${klipper_cfg_loc}" ]; then
    echo
    top_border
    echo -e "|                    ${red}!!! WARNING !!!${white}                    |"
    echo -e "|        ${red}No Klipper configuration directory set!${white}        |"
    hr
    echo -e "|  Before we can continue, KIAUH needs to know where    |"
    echo -e "|  you want your printer configuration to be.           |"
    blank_line
    echo -e "|  Please specify a folder where your Klipper configu-  |"
    echo -e "|  ration is stored or, if you don't have one yet, in   |"
    echo -e "|  which it should be saved after the installation.     |"
    bottom_border
    change_klipper_cfg_path
  fi
}

change_klipper_cfg_path(){
  source_kiauh_ini
  old_klipper_cfg_loc="${klipper_cfg_loc}"
  EXAMPLE_FOLDER=$(printf "%s/your_config_folder" "${HOME}")
  while true; do
    top_border
    echo -e "|  ${red}IMPORTANT:${white}                                           |"
    echo -e "|  Please enter the new path in the following format:   |"
    printf "|  ${yellow}%-51s${white}  |\n" "${EXAMPLE_FOLDER}"
    blank_line
    echo -e "|  By default 'klipper_config' is recommended!          |"
    bottom_border
    echo
    echo -e "${cyan}###### Please set the Klipper config directory:${white} "
    if [ -z "${old_klipper_cfg_loc}" ]; then
      read -e -i "/home/${USER}/klipper_config" -e new_klipper_cfg_loc
    else
      read -e -i "${old_klipper_cfg_loc}" -e new_klipper_cfg_loc
    fi
    echo
    read -p "${cyan}###### Set config directory to '${yellow}${new_klipper_cfg_loc}${cyan}' ? (Y/n):${white} " yn
    case "${yn}" in
      Y|y|Yes|yes|"")
        echo -e "###### > Yes"

        ### backup the old config dir
        backup_klipper_config_dir

        ### write new location to kiauh.ini
        sed -i "s|klipper_cfg_loc=${old_klipper_cfg_loc}|klipper_cfg_loc=${new_klipper_cfg_loc}|" "${INI_FILE}"
        status_msg "Directory set to '${new_klipper_cfg_loc}'!"

        ### write new location to klipper and moonraker service
        set_klipper_cfg_path
        echo; ok_msg "Config directory changed!"
        break;;
      N|n|No|no)
        echo -e "###### > No"
        change_klipper_cfg_path
        break;;
      *)
        print_unkown_cmd
        print_msg && clear_msg;;
    esac
  done
}

set_klipper_cfg_path(){
  ### stop services
  do_action_service "stop" "klipper"
  do_action_service "stop" "moonraker"

  ### copy config files to new klipper config folder
  if [ -n "${old_klipper_cfg_loc}" ] && [ -d "${old_klipper_cfg_loc}" ]; then
    if [ ! -d "${new_klipper_cfg_loc}" ]; then
      status_msg "Copy config files to '${new_klipper_cfg_loc}' ..."
      mkdir -p "${new_klipper_cfg_loc}"
      cd "${old_klipper_cfg_loc}"
      cp -r -v ./* "${new_klipper_cfg_loc}"
      ok_msg "Done!"
    fi
  fi

  SERVICE_FILES=$(find "${SYSTEMD}" -regextype posix-extended -regex "${SYSTEMD}/klipper(-[^0])+[0-9]*.service")
  ### handle single klipper instance service file
  if [ -f "${SYSTEMD}/klipper.service" ]; then
    status_msg "Configuring Klipper for new path ..."
    sudo sed -i -r "/ExecStart=/ s|klippy.py (.+)\/printer.cfg|klippy.py ${new_klipper_cfg_loc}/printer.cfg|" "${SYSTEMD}/klipper.service"
    ok_msg "OK!"
  elif [ -n "${SERVICE_FILES}" ]; then
    ### handle multi klipper instance service file
    status_msg "Configuring Klipper for new path ..."
    for service in ${SERVICE_FILES}; do
      sudo sed -i -r "/ExecStart=/ s|klippy.py (.+)\/printer_|klippy.py ${new_klipper_cfg_loc}/printer_|" "${service}"
    done
    ok_msg "OK!"
  fi

  SERVICE_FILES=$(find "${SYSTEMD}" -regextype posix-extended -regex "${SYSTEMD}/moonraker(-[^0])+[0-9]*.service")
  ### handle single moonraker instance service and moonraker.conf file
  if [ -f "${SYSTEMD}/moonraker.service" ]; then
    status_msg "Configuring Moonraker for new path ..."
    sudo sed -i -r "/ExecStart=/ s|-c (.+)\/moonraker\.conf|-c ${new_klipper_cfg_loc}/moonraker.conf|" "${SYSTEMD}/moonraker.service"

    ### replace old file path with new one in moonraker.conf
    sed -i -r "/config_path:/ s|config_path:.*|config_path: ${new_klipper_cfg_loc}|" "${new_klipper_cfg_loc}/moonraker.conf"
    ok_msg "OK!"
  elif [ -n "${SERVICE_FILES}" ]; then
    ### handle multi moonraker instance service file
    status_msg "Configuring Moonraker for new path ..."
    for service in ${SERVICE_FILES}; do
      sudo sed -i -r "/ExecStart=/ s|-c (.+)\/printer_|-c ${new_klipper_cfg_loc}/printer_|" "${service}"
    done
    MR_CONFS=$(find "${new_klipper_cfg_loc}" -regextype posix-extended -regex "${new_klipper_cfg_loc}/printer_[1-9]+/moonraker.conf")
    ### replace old file path with new one in moonraker.conf
    for moonraker_conf in ${MR_CONFS}; do
      loc=$(echo "${moonraker_conf}" | rev | cut -d"/" -f2- | rev)
      sed -i -r "/config_path:/ s|config_path:.*|config_path: ${loc}|" "${moonraker_conf}"
    done
    ok_msg "OK!"
  fi

  ### reloading units
  sudo systemctl daemon-reload

  ### restart services
  do_action_service "restart" "klipper"
  do_action_service "restart" "moonraker"
}

do_action_service(){
  shopt -s extglob # enable extended globbing
  SERVICES="${SYSTEMD}/$2?(-*([0-9])).service"
  ### set a variable for the ok and status messages
  [ "$1" == "start" ] && ACTION1="started" && ACTION2="Starting"
  [ "$1" == "stop" ] && ACTION1="stopped" && ACTION2="Stopping"
  [ "$1" == "restart" ] && ACTION1="restarted" && ACTION2="Restarting"
  [ "$1" == "enable" ] && ACTION1="enabled" && ACTION2="Enabling"
  [ "$1" == "disable" ] && ACTION1="disabled" && ACTION2="Disabling"

  if ls "${SERVICES}" 2>/dev/null 1>&2; then
    for service in $(ls "${SERVICES}" | rev | cut -d"/" -f1 | rev); do
      status_msg "${ACTION2} ${service} ..."
      sudo systemctl "${1}" "${service}"
      ok_msg "${service} ${ACTION1}!"
    done
  fi
  shopt -u extglob # disable extended globbing
}

start_klipperscreen(){
  status_msg "Starting KlipperScreen Service ..."
  sudo systemctl start KlipperScreen && ok_msg "KlipperScreen Service started!"
}

stop_klipperscreen(){
  status_msg "Stopping KlipperScreen Service ..."
  sudo systemctl stop KlipperScreen && ok_msg "KlipperScreen Service stopped!"
}

restart_klipperscreen(){
  status_msg "Restarting KlipperScreen Service ..."
  sudo systemctl restart KlipperScreen && ok_msg "KlipperScreen Service restarted!"
}

start_MoonrakerTelegramBot(){
  status_msg "Starting MoonrakerTelegramBot Service ..."
  sudo systemctl start moonraker-telegram-bot && ok_msg "MoonrakerTelegramBot Service started!"
}

stop_MoonrakerTelegramBot(){
  status_msg "Stopping MoonrakerTelegramBot Service ..."
  sudo systemctl stop moonraker-telegram-bot && ok_msg "MoonrakerTelegramBot Service stopped!"
}

restart_MoonrakerTelegramBot(){
  status_msg "Restarting MoonrakerTelegramBot Service ..."
  sudo systemctl restart moonraker-telegram-bot && ok_msg "MoonrakerTelegramBot Service restarted!"
}

restart_nginx(){
  if ls /lib/systemd/system/nginx.service 2>/dev/null 1>&2; then
    status_msg "Restarting NGINX Service ..."
    sudo systemctl restart nginx && ok_msg "NGINX Service restarted!"
  fi
}

dependency_check(){
  local dep=( "${@}" ) # dep: array
  status_msg "Checking for the following dependencies:"
  #check if package is installed, if not write name into array
  for pkg in "${dep[@]}"
  do
    echo -e "${cyan}● ${pkg} ${white}"
    if [[ ! $(dpkg-query -f'${Status}' --show "${pkg}" 2>/dev/null) = *\ installed ]]; then
      inst+=("${pkg}")
    fi
  done
  #if array is not empty, install packages from array elements
  if [ "${#inst[@]}" -ne 0 ]; then
    status_msg "Installing the following dependencies:"
    for element in "${inst[@]}"
    do
      echo -e "${cyan}● ${element} ${white}"
    done
    echo
    sudo apt-get update --allow-releaseinfo-change && sudo apt-get install "${inst[@]}" -y
    ok_msg "Dependencies installed!"
    #clearing the array
    unset inst
  else
    ok_msg "Dependencies already met! Continue..."
  fi
}

setup_gcode_shell_command(){
  echo
  top_border
  echo -e "| You are about to install the G-Code Shell Command     |"
  echo -e "| extension. Please make sure to read the instructions  |"
  echo -e "| before you continue and remember that potential risks |"
  echo -e "| can be involved after installing this extension!      |"
  blank_line
  echo -e "| ${red}You accept that you are doing this on your own risk!${white}  |"
  bottom_border
  while true; do
    read -p "${cyan}###### Do you want to continue? (Y/n):${white} " yn
    case "${yn}" in
      Y|y|Yes|yes|"")
        if [ -d "${KLIPPER_DIR}/klippy/extras" ]; then
          status_msg "Installing gcode shell command extension ..."
          if [ -f "${KLIPPER_DIR}/klippy/extras/gcode_shell_command.py" ]; then
            warn_msg "There is already a file named 'gcode_shell_command.py'\nin the destination location!"
            while true; do
              read -p "${cyan}###### Do you want to overwrite it? (Y/n):${white} " yn
              case "${yn}" in
                Y|y|Yes|yes|"")
                  rm -f "${KLIPPER_DIR}/klippy/extras/gcode_shell_command.py"
                  install_gcode_shell_command
                  break;;
                N|n|No|no)
                  break;;
              esac
            done
          else
            install_gcode_shell_command
          fi
        else
          ERROR_MSG="Folder ~/klipper/klippy/extras not found!"
        fi
        break;;
      N|n|No|no)
        break;;
      *)
        print_unkown_cmd
        print_msg && clear_msg;;
    esac
  done
}

install_gcode_shell_command(){
  do_action_service "stop" "klipper"
  status_msg "Copy 'gcode_shell_command.py' to '${KLIPPER_DIR}/klippy/extras' ..."
  cp "${SRCDIR}/kiauh/resources/gcode_shell_command.py" "${KLIPPER_DIR}/klippy/extras"
  while true; do
    echo
    read -p "${cyan}###### Do you want to create the example shell command? (Y/n):${white} " yn
    case "${yn}" in
      Y|y|Yes|yes|"")
        status_msg "Copy shell_command.cfg ..."
        ### create a backup of the config folder
        backup_klipper_config_dir

        ### handle single printer.cfg
        if [ -f "${klipper_cfg_loc}/printer.cfg" ] && [ ! -f "${klipper_cfg_loc}/shell_command.cfg" ]; then
          ### copy shell_command.cfg to config location
          cp "${SRCDIR}/kiauh/resources/shell_command.cfg" "${klipper_cfg_loc}"
          ok_msg "${klipper_cfg_loc}/shell_command.cfg created!"

          ### write the include to the very first line of the printer.cfg
          sed -i "1 i [include shell_command.cfg]" "${klipper_cfg_loc}/printer.cfg"
        fi

        ### handle multi printer.cfg
        if ls "${klipper_cfg_loc}"/printer_*  2>/dev/null 1>&2; then
          for config in $(find ${klipper_cfg_loc}/printer_*/printer.cfg); do
            path=$(echo "${config}" | rev | cut -d"/" -f2- | rev)
            if [ ! -f "${path}/shell_command.cfg" ]; then
              ### copy shell_command.cfg to config location
              cp "${SRCDIR}/kiauh/resources/shell_command.cfg" "${path}"
              ok_msg "${path}/shell_command.cfg created!"

              ### write the include to the very first line of the printer.cfg
              sed -i "1 i [include shell_command.cfg]" "${path}/printer.cfg"
            fi
          done
        fi
        break;;
      N|n|No|no)
        break;;
    esac
  done
  ok_msg "Shell command extension installed!"
  do_action_service "restart" "klipper"
}

function system_check_webui(){
  ### check system for an installed and enabled octoprint service
  if sudo systemctl list-unit-files | grep -E "octoprint.*" | grep "enabled" &>/dev/null; then
    OCTOPRINT_ENABLED="true"
  fi

  ### check system for an installed haproxy service
  if [[ $(dpkg-query -f'${Status}' --show haproxy 2>/dev/null) = *\ installed ]]; then
    HAPROXY_FOUND="true"
  fi

  ### check system for an installed lighttpd service
  if [[ $(dpkg-query -f'${Status}' --show lighttpd 2>/dev/null) = *\ installed ]]; then
    LIGHTTPD_FOUND="true"
  fi

  ### check system for an installed apache2 service
  if [[ $(dpkg-query -f'${Status}' --show apache2 2>/dev/null) = *\ installed ]]; then
    APACHE2_FOUND="true"
  fi
}

function process_octoprint_dialog(){
  #ask user to disable octoprint when its service was found
  if [ "${OCTOPRINT_ENABLED}" = "true" ]; then
    while true; do
      echo
      top_border
      echo -e "|       ${red}!!! WARNING - OctoPrint service found !!!${white}       |"
      hr
      echo -e "|  You might consider disabling the OctoPrint service,  |"
      echo -e "|  since an active OctoPrint service may lead to unex-  |"
      echo -e "|  pected behavior of the Klipper Webinterfaces.        |"
      bottom_border
      read -p "${cyan}###### Do you want to disable OctoPrint now? (Y/n):${default} " yn
      case "${yn}" in
        Y|y|Yes|yes|"")
          echo -e "###### > Yes"
          status_msg "Stopping OctoPrint ..."
          do_action_service "stop" "octoprint" && ok_msg "OctoPrint service stopped!"
          status_msg "Disabling OctoPrint ..."
          do_action_service "disable" "octoprint" && ok_msg "OctoPrint service disabled!"
          break;;
        N|n|No|no)
          echo -e "###### > No"
          break;;
        *)
          print_unkown_cmd
          print_msg && clear_msg;;
      esac
    done
  fi
}

function fetch_webui_ports(){
  ### read listen ports from possible installed interfaces
  ### and write them to ~/.kiauh.ini
  WEBIFS=(mainsail fluidd octoprint)
  for interface in "${WEBIFS[@]}"; do
    if [ -f "/etc/nginx/sites-available/${interface}" ]; then
      port=$(grep -E "listen" "/etc/nginx/sites-available/${interface}" | head -1 | sed 's/^\s*//' | sed 's/;$//' | cut -d" " -f2)
      if [ ! -n "$(grep -E "${interface}_port" "${INI_FILE}")" ]; then
        sed -i '$a'"${interface}_port=${port}" "${INI_FILE}"
      else
        sed -i "/^${interface}_port/d" "${INI_FILE}"
        sed -i '$a'"${interface}_port=${port}" "${INI_FILE}"
      fi
    else
        sed -i "/^${interface}_port/d" "${INI_FILE}"
    fi
  done
}
