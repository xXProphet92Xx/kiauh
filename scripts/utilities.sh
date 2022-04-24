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

function select_msg() {
  echo -e "${white}   [➔] ${1}"
}
function status_msg(){
  echo -e "\n${magenta}###### ${1}${white}"
}
function ok_msg(){
  echo -e "${green}[✓ OK] ${1}${white}"
}
function warn_msg(){
  echo -e "${yellow}>>>>>> ${1}${white}"
}
function error_msg(){
  echo -e "${red}>>>>>> ${1}${white}"
}
function abort_msg(){
  echo -e "${red}<<<<<< ${1}${white}"
}
function title_msg(){
  echo -e "${cyan}${1}${white}"
}

function print_error(){
  [ -z "${1}" ] && return
  echo -e "${red}"
  echo -e "#=======================================================#"
  echo -e " ${1} "
  echo -e "#=======================================================#"
  echo -e "${white}"
}

function print_confirm(){
  [ -z "${1}" ] && return
  echo -e "${green}"
  echo -e "#=======================================================#"
  echo -e " ${1} "
  echo -e "#=======================================================#"
  echo -e "${white}"
}

#================================================#
#=================== LOGGING ====================#
#================================================#

function timestamp() {
  date +"[%F %T]"
}

function init_logfile() {
  local log="/tmp/kiauh.log"
  {
    echo -e "#================================================================#"
    echo -e "# New KIAUH session started on: $(date) #"
    echo -e "#================================================================#"
    echo -e "KIAUH $(get_kiauh_version)"
    echo -e "#================================================================#"
  } >> "${log}"
}

function log_info() {
  local message="${1}" log="${LOGFILE}"
  echo -e "$(timestamp) [INFO]: ${message}" | tr -s " " >> "${log}"
}

function log_warning() {
  local message="${1}" log="${LOGFILE}"
  echo -e "$(timestamp) [WARN]: ${message}" | tr -s " " >> "${log}"
}

function log_error() {
  local message="${1}" log="${LOGFILE}"
  echo -e "$(timestamp) [ERR]: ${message}" | tr -s " " >> "${log}"
}

#================================================#
#=============== KIAUH SETTINGS =================#
#================================================#

function read_kiauh_ini(){
  local func=${1}
  if [ ! -f "${INI_FILE}" ]; then
    print_error "ERROR: File '~/.kiauh.ini' not found!"
    log_error "Reading from .kiauh.ini failed! File not found!"
    return 1
  fi
  log_info "Reading from .kiauh.ini ... (${func})"
  source "${INI_FILE}"
}

function init_ini(){
  ### remove pre-version 4 ini files
  if [ -f "${INI_FILE}" ] && ! grep -Eq "^# KIAUH v4\.0\.0$" "${INI_FILE}"; then
    rm "${INI_FILE}"
  fi
  ### initialize v4.0.0 ini file
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
  if ! grep -Eq "^custom_klipper_repo=" "${INI_FILE}"; then
    echo -e "\ncustom_klipper_repo=\c" >> "${INI_FILE}"
  fi
  if ! grep -Eq "^custom_klipper_repo_branch=" "${INI_FILE}"; then
    echo -e "\ncustom_klipper_repo_branch=\c" >> "${INI_FILE}"
  fi
  if ! grep -Eq "^mainsail_install_unstable=" "${INI_FILE}"; then
    echo -e "\nmainsail_install_unstable=false\c" >> "${INI_FILE}"
  fi
  if ! grep -Eq "^fluidd_install_unstable=" "${INI_FILE}"; then
    echo -e "\nfluidd_install_unstable=false\c" >> "${INI_FILE}"
  fi
  fetch_webui_ports
}

function change_klipper_cfg_folder(){
  local current_cfg_loc example_loc recommended_loc new_cfg_loc
  current_cfg_loc="$(get_klipper_cfg_dir)"
  example_loc=$(printf "%s/<your_config_folder>" "${HOME}")
  recommended_loc=$(printf "%s/klipper_config" "${HOME}")
  while true; do
    top_border
    echo -e "|  ${yellow}IMPORTANT:${white}                                           |"
    echo -e "|  Please enter the new path in the following format:   |"
    printf  "|  ${cyan}%-51s${white}  |\n" "${example_loc}"
    blank_line
    echo -e "|  ${red}WARNING: ${white}                                            |"
    echo -e "|  ${red}There will be no validation checks! Make sure to set${white} |"
    echo -e "|  ${red}a valid directory to prevent possible problems!${white}      |"
    blank_line
    printf  "|  Recommended: ${cyan}%-38s${white}  |\n" "${recommended_loc}"
    bottom_border
    echo
    echo -e "${cyan}###### Please set the new Klipper config directory:${white} "
    read -e -i "${current_cfg_loc}" -e new_cfg_loc
    echo
    read -p "${cyan}###### Set config directory to '${yellow}${new_cfg_loc}${cyan}' ? (Y/n):${white} " yn
    case "${yn}" in
      Y|y|Yes|yes|"")
        select_msg "Yes"
        set_klipper_cfg_path "${current_cfg_loc}" "${new_cfg_loc}"
        print_confirm "New config directory set!"
        settings_menu
        break;;
      N|n|No|no)
        select_msg "No"
        settings_menu
        break;;
      *)
        print_error "Invalid command!";;
    esac
  done
}

function set_klipper_cfg_path(){
  local current_cfg_loc="${1}" new_cfg_loc="${2}"
  local instance klipper_services moonraker_services moonraker_configs

  log_info "Function set_klipper_cfg_path invoked\nCurrent location: ${1}\nNew location: ${2}"
  ### backup the old config dir
  backup_klipper_config_dir
  ### write new location to .kiauh.ini
  sed -i "/^custom_klipper_cfg_loc=/d" "${INI_FILE}"
  sed -i '$a'"custom_klipper_cfg_loc=${new_cfg_loc}" "${INI_FILE}"
  status_msg "New directory was set to '${new_cfg_loc}'!"

  ### stop services
  do_action_service "stop" "klipper"
  do_action_service "stop" "moonraker"

  ### copy config files to new klipper config folder
  if [ -n "${current_cfg_loc}" ] && [ -d "${current_cfg_loc}" ]; then
    status_msg "Copy config files to '${new_cfg_loc}' ..."
    if [ ! -d "${new_cfg_loc}" ]; then
      log_info "Copy process started"
      mkdir -p "${new_cfg_loc}"
      cd "${current_cfg_loc}"
      cp -r -v ./* "${new_cfg_loc}"
      ok_msg "Done!"
    else
      log_warning "Copy process skipped, new config directory already exists and may not be empty!"
      warn_msg "New config directory already exists!\nCopy process skipped!"
    fi
  fi

  klipper_services=$(klipper_systemd)
  if [ -n "${klipper_services}" ]; then
    status_msg "Re-writing Klipper services to use new config file location ..."
    for service in ${klipper_services}; do
      if [ "${service}" = "/etc/systemd/system/klipper.service" ]; then
        if grep "Environment=KLIPPER_CONFIG=" "${service}"; then
          ### single instance klipper service installed by kiauh v4 / MainsailOS > 0.5.0
          sudo sed -i -r "/KLIPPER_CONFIG=/ s|CONFIG=(.+)\/printer\.cfg|CONFIG=${new_cfg_loc}/printer\.cfg|" "${service}"
        else
          ### single instance klipper service installed by kiauh v3
          sudo sed -i -r "/ExecStart=/ s|klippy\.py (.+)\/printer\.cfg|klippy\.py ${new_cfg_loc}\/printer\.cfg|" "${service}"
        fi
      else
        instance=$(echo "${service}" | cut -d"-" -f2 | cut -d"." -f1)
        if grep "Environment=KLIPPER_CONFIG=" "${service}"; then
          ### multi instance klipper service installed by kiauh v4 / MainsailOS > 0.5.0
          sudo sed -i -r "/KLIPPER_CONFIG=/ s|CONFIG=(.+)\/printer_${instance}\/printer\.cfg|CONFIG=${new_cfg_loc}\/printer_${instance}\/printer\.cfg|" "${service}"
        else
          ### multi instance klipper service installed by kiauh v3
          sudo sed -i -r "/ExecStart=/ s|klippy\.py (.+)\/printer_${instance}\/printer\.cfg|klippy\.py ${new_cfg_loc}\/printer_${instance}\/printer\.cfg|" "${service}"
        fi
      fi
    done
    ok_msg "OK!"
  fi

  moonraker_services=$(moonraker_systemd)
  if [ -n "${moonraker_services}" ]; then
    ### handle multi moonraker instance service file
    status_msg "Re-writing Moonraker services to use new config file location ..."
    for service in ${moonraker_services}; do
      if [ "${service}" = "/etc/systemd/system/moonraker.service" ]; then
        if grep "Environment=MOONRAKER_CONF=" "${service}"; then
          ### single instance moonraker service installed by kiauh v4 / MainsailOS > 0.5.0
          sudo sed -i -r "/MOONRAKER_CONF=/ s|_CONF=(.+)\/moonraker\.conf|_CONF=${new_cfg_loc}\/moonraker\.conf|" "${service}"
        else
          ### single instance moonraker service installed by kiauh v3
          sudo sed -i -r "/ExecStart=/ s| -c (.+)\/moonraker\.conf| -c ${new_cfg_loc}\/moonraker\.conf|" "${service}"
        fi
      else
        instance=$(echo "${service}" | cut -d"-" -f2 | cut -d"." -f1)
        if grep "Environment=MOONRAKER_CONF=" "${service}"; then
          ### multi instance moonraker service installed by kiauh v4 / MainsailOS > 0.5.0
          sudo sed -i -r "/MOONRAKER_CONF=/ s|_CONF=(.+)\/printer_${instance}\/moonraker\.conf|_CONF=${new_cfg_loc}\/printer_${instance}\/moonraker\.conf|" "${service}"
        else
          ### multi instance moonraker service installed by kiauh v3
          sudo sed -i -r "/ExecStart=/ s| -c (.+)\/printer_${instance}\/moonraker\.conf| -c ${new_cfg_loc}\/printer_${instance}\/moonraker\.conf|" "${service}"
        fi
      fi
    done
    moonraker_configs=$(find "${new_cfg_loc}" -type f -name "moonraker.conf")
    ### replace old file path with new one in moonraker.conf
    for conf in ${moonraker_configs}; do
      loc=$(echo "${conf}" | rev | cut -d"/" -f2- | rev)
      sed -i -r "/config_path:/ s|config_path:.*|config_path: ${loc}|" "${conf}"
    done
    ok_msg "OK!"
  fi

  ### reloading units
  sudo systemctl daemon-reload

  ### restart services
  do_action_service "restart" "klipper"
  do_action_service "restart" "moonraker"
}

function switch_mainsail_releasetype() {
  read_kiauh_ini "${FUNCNAME[0]}"
  local state="${mainsail_install_unstable}"
  if [ "${state}" == "false" ]; then
    sed -i '/mainsail_install_unstable=/s/false/true/' "${INI_FILE}"
    log_info "mainsail_install_unstable changed (false -> true) "
  else
    sed -i '/mainsail_install_unstable=/s/true/false/' "${INI_FILE}"
    log_info "mainsail_install_unstable changed (true -> false) "
  fi
}

function switch_fluidd_releasetype() {
  read_kiauh_ini "${FUNCNAME[0]}"
  local state="${fluidd_install_unstable}"
  if [ "${state}" == "false" ]; then
    sed -i '/fluidd_install_unstable=/s/false/true/' "${INI_FILE}"
    log_info "fluidd_install_unstable changed (false -> true) "
  else
    sed -i '/fluidd_install_unstable=/s/true/false/' "${INI_FILE}"
    log_info "fluidd_install_unstable changed (true -> false) "
  fi
}

function toggle_backup_before_update(){
  read_kiauh_ini "${FUNCNAME[0]}"
  local state="${backup_before_update}"
  if [ "${state}" = "false" ]; then
    sed -i '/backup_before_update=/s/false/true/' "${INI_FILE}"
  else
    sed -i '/backup_before_update=/s/true/false/' "${INI_FILE}"
  fi
}

function set_custom_klipper_repo() {
  read_kiauh_ini "${FUNCNAME[0]}"
  local repo_url=${1} branch=${2}
  sed -i "/^custom_klipper_repo=/d" "${INI_FILE}"
  sed -i '$a'"custom_klipper_repo=${repo_url}" "${INI_FILE}"
  sed -i "/^custom_klipper_repo_branch=/d" "${INI_FILE}"
  sed -i '$a'"custom_klipper_repo_branch=${branch}" "${INI_FILE}"
}

#================================================#
#=============== HANDLE SERVICES ================#
#================================================#

function do_action_service(){
  local action=${1} service=${2}
  services=$(find "${SYSTEMD}" -maxdepth 1 -regextype posix-extended -regex "${SYSTEMD}/${service}(-[^0])?[0-9]*.service")
  if [ -n "${services}" ]; then
    for service in ${services}; do
      service=$(echo "${service}" | rev | cut -d"/" -f1 | rev)
      status_msg "${action^} ${service} ..."
      if sudo systemctl "${action}" "${service}"; then
        log_info "${service}: ${action} > success"
        ok_msg "${action^} ${service} successfull!"
      else
        log_warning "${service}: ${action} > failed"
        warn_msg "${action^} ${service} failed!"
      fi
    done
  fi
}

#================================================#
#================ DEPENDENCIES ==================#
#================================================#

function python3_check(){
  local major minor
  ### python 3 check
  status_msg "Your Python 3 version is: $(python3 --version)"
  major=$(python3 --version | cut -d" " -f2 | cut -d"." -f1)
  minor=$(python3 --version | cut -d"." -f2)
  if [ "${major}" -ge 3 ] && [ "${minor}" -ge 7 ]; then
    echo "true"
  else
    echo "false"
  fi
}

function dependency_check(){
  local dep=( "${@}" )
  local packages
  status_msg "Checking for the following dependencies:"
  #check if package is installed, if not write its name into array
  for pkg in "${dep[@]}"; do
    echo -e "${cyan}● ${pkg} ${white}"
    if [[ ! $(dpkg-query -f'${Status}' --show "${pkg}" 2>/dev/null) = *\ installed ]]; then
      packages+=("${pkg}")
    fi
  done
  #if array is not empty, install packages from array
  if (( ${#packages[@]} > 0 )); then
    status_msg "Installing the following dependencies:"
    for package in "${packages[@]}"; do
      echo -e "${cyan}● ${package} ${white}"
    done
    echo
    if sudo apt-get update --allow-releaseinfo-change && sudo apt-get install "${packages[@]}" -y; then
      ok_msg "Dependencies installed!"
    else
      error_msg "Installing dependencies failed!"
      return 1 # exit kiauh
    fi
  else
    ok_msg "Dependencies already met!"
    return
  fi
}

function system_check_webui(){
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

function fetch_webui_ports(){
  ### read ports from possible installed interfaces and write them to ~/.kiauh.ini
  local interfaces=("mainsail" "fluidd" "octoprint")
  for interface in "${interfaces[@]}"; do
    if [ -f "/etc/nginx/sites-available/${interface}" ]; then
      port=$(grep -E "listen" "/etc/nginx/sites-available/${interface}" | head -1 | sed 's/^\s*//' | sed 's/;$//' | cut -d" " -f2)
      if ! grep -Eq "${interface}_port" "${INI_FILE}"; then
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

#================================================#
#=================== SYSTEM =====================#
#================================================#

function check_system_updates(){
  local updates_avail info_msg
  updates_avail=$(apt list --upgradeable 2>/dev/null | sed "1d")
  if [ -n "${updates_avail}" ]; then
    # add system updates to the update all array for the update all function in the updater
    SYS_UPDATE_AVAIL="true" && update_arr+=(update_system)
    info_msg="${yellow}System upgrade available!${white}"
  else
    SYS_UPDATE_AVAIL="false"
    info_msg="${green}System up to date!       ${white}"
  fi
  echo "${info_msg}"
}

function update_system(){
  status_msg "Updating System ..."
  if sudo apt-get update --allow-releaseinfo-change && sudo apt-get upgrade -y; then
    print_confirm "Update complete! Check the log above!\n ${yellow}KIAUH will not install any dist-upgrades or\n any packages which have been kept back!${green}"
  else
    print_error "System update failed! Please watch for any errors printed above!"
  fi
}

function check_usergroups(){
  local group_dialout group_tty
  if grep -q "dialout" </etc/group && ! grep -q "dialout" <(groups "${USER}"); then
    group_dialout="false"
  fi
  if grep -q "tty" </etc/group && ! grep -q "tty" <(groups "${USER}"); then
    group_tty="false"
  fi
  if [ "${group_dialout}" == "false" ] || [ "${group_tty}" == "false" ] ; then
    top_border
    echo -e "| ${yellow}WARNING: Your current user is not in group:${white}           |"
    [ "${group_tty}" == "false" ] && echo -e "| ${yellow}● tty${white}                                                 |"
    [ "${group_dialout}" == "false" ] && echo -e "| ${yellow}● dialout${white}                                             |"
    blank_line
    echo -e "| It is possible that you won't be able to successfully |"
    echo -e "| connect and/or flash the controller board without     |"
    echo -e "| your user being a member of that group.               |"
    echo -e "| If you want to add the current user to the group(s)   |"
    echo -e "| listed above, answer with 'Y'. Else skip with 'n'.    |"
    blank_line
    echo -e "| ${yellow}INFO:${white}                                                 |"
    echo -e "| ${yellow}Relog required for group assignments to take effect!${white}  |"
    bottom_border
    while true; do
      read -p "${cyan}###### Add user '${USER}' to group(s) now? (Y/n):${white} " yn
      case "${yn}" in
        Y|y|Yes|yes|"")
          select_msg "Yes"
          status_msg "Adding user '${USER}' to group(s) ..."
          if [ "${group_tty}" == "false" ]; then
            sudo usermod -a -G tty "${USER}" && ok_msg "Group 'tty' assigned!"
          fi
          if [ "${group_dialout}" == "false" ]; then
            sudo usermod -a -G dialout "${USER}" && ok_msg "Group 'dialout' assigned!"
          fi
          ok_msg "Remember to relog/restart this machine for the group(s) to be applied!"
          break;;
        N|n|No|no)
          select_msg "No"
          break;;
        *)
          print_error "Invalid command!";;
      esac
    done
  fi
}

function set_custom_hostname(){
  echo
  top_border
  echo -e "|  Changing the hostname of this machine allows you to  |"
  echo -e "|  access a webinterface that is configured for port 80 |"
  echo -e "|  by simply typing '<hostname>.local' in the browser.  |"
  echo -e "|                                                       |"
  echo -e "|  E.g.: If you set the hostname to 'my-printer' you    |"
  echo -e "|        can open Mainsail / Fluidd / Octoprint by      |"
  echo -e "|        browsing to: http://my-printer.local           |"
  bottom_border
  while true; do
    read -p "${cyan}###### Do you want to change the hostname? (y/N):${white} " yn
    case "${yn}" in
      Y|y|Yes|yes)
        select_msg "Yes"
        change_hostname
        break;;
      N|n|No|no|"")
        select_msg "No"
        break;;
      *)
        error_msg "Invalid command!";;
    esac
  done
}

function change_hostname(){
    local new_hostname
    echo
    top_border
    echo -e "|  ${green}Allowed characters: a-z, 0-9 and single '-'${white}          |"
    echo -e "|  ${red}No special characters allowed!${white}                       |"
    echo -e "|  ${red}No leading or trailing '-' allowed!${white}                  |"
    bottom_border
    while true; do
      read -p "${cyan}###### Please set the new hostname:${white} " new_hostname
      if [[ ${new_hostname} =~ ^[^\-\_]+([0-9a-z]\-{0,1})+[^\-\_]+$ ]]; then
        while true; do
          echo
          read -p "${cyan}###### Do you want '${new_hostname}' to be the new hostname? (Y/n):${white} " yn
          case "${yn}" in
            Y|y|Yes|yes|"")
              select_msg "Yes"
              set_hostname "${new_hostname}"
              break;;
            N|n|No|no)
              select_msg "No"
              abort_msg "Skip hostname change ..."
              break;;
            *)
              print_error "Invalid command!";;
          esac
        done
      else
        warn_msg "'${new_hostname}' is not a valid hostname!"
      fi
      break
    done
}

function set_hostname(){
  local new_hostname=${1} current_date
  #check for dependencies
  local dep=(avahi-daemon)
  dependency_check "${dep[@]}"

  #create host file if missing or create backup of existing one with current date&time
  if [ -f /etc/hosts ]; then
    current_date=$(get_date)
    status_msg "Creating backup of hosts file ..."
    sudo cp "/etc/hosts /etc/hosts.${current_date}.bak"
    ok_msg "Backup done!"
    ok_msg "File:'/etc/hosts.${current_date}.bak'"
  else
    sudo touch /etc/hosts
  fi

  #set new hostname in /etc/hostname
  status_msg "Setting hostname to '${new_hostname}' ..."
  status_msg "Please wait ..."
  sudo hostnamectl set-hostname "${new_hostname}"

  #write new hostname to /etc/hosts
  status_msg "Writing new hostname to /etc/hosts ..."
  echo "127.0.0.1       ${new_hostname}" | sudo tee -a /etc/hosts &>/dev/null
  ok_msg "New hostname successfully configured!"
  ok_msg "Remember to reboot for the changes to take effect!"
}