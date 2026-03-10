# $PREFIX/bin/bash
echo kabhooom!
# set -x
_is_termux() {
  [ -d "/data/data/com.termux" ] && \
  [ -n "$PREFIX" ] && \
  [[ "$PREFIX" == *"termux"* ]] && \
  [ -d "$PREFIX/bin" ] && \
  uname -a | grep -q "Android"
}

_battery_low() {
  local level=$(termux-battery-status | grep "percentage" | awk '{print $2}' | tr -d ',')
  [ "$level" -lt 21 ]
}

echo "checking if everything was fine before starting the execution."
echo "checking if the execution environment is termux..."
if ! _is_termux; then
  echo "Not running in Termux environment."
  echo "Exiting."
  exit 1
fi
echo "execution environment is termux."
echo "checking is the battery was low..."
if _battery_low; then 
    echo "battery is running low, charge the battery, else the background processes were getting killed unexpectedly making this script run unpredictably."
    echo "exiting with 1..."
    exit 1;
fi
echo "the battery was high enough to run this script predictably."
echo "continuing the execution..."


_confirm() {
    local l="${2:-3}"
  echo "$1, if yes, then continue."
  echo
  read -p "Continue? [Y/n]: " a
  local a="${a:-y}"
  if [ "$a" != "y" ] && [ "$a" != "Y" ]; then
    # echo "Aborted."
    
    printf "\033[${l}A\033[J"
    return 1
  fi
  printf "\033[${l}A\033[J"
  unset a;
}
# _confirm "Turned on dev options?"
# exit 0;

_adbd_ack() {
  getprop init.svc.adbd | grep -q "running"
}

_get_devices() {
  local r=$(adb devices 2>/dev/null | grep -A 100 'List of devices attached' | tail -n +2)
  if [ -z "$r" ]; then
    return 1
  fi
  echo "$r"
  return
}
_USB_dbug_walkthrough(){
    echo "Turn on USB debugging on the next screen."
    echo "launching dev screens..."
    am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS
    return
}
_dev_ops_walkthrough(){
    echo "Turn on the developer options."
    echo "Tap on (build number/OS version) number 7 times."
    echo
    _confirm "About to launch \"About phone\" settings" 6 || exit 1;
    echo "Launching settings..."
    am start -a android.settings.DEVICE_INFO_SETTINGS  >/dev/null 2>&1
    echo "exiting..."
    echo "after turning on, just re-run the script."
    echo "exiting with 1."
    return
}
_WiLs_debug_walkthrough(){
    echo "Turn on the wireless debugging."
    echo
    _confirm "About to launch wireless debugging settings." 6 || exit 1;
    echo "Launching wireless debugging..."
    am start -n com.android.settings/.SubSettings \
        -e :android:show_fragment com.android.settings.development.WirelessDebuggingFragment \
        -e :android:show_fragment_title "Wireless Debugging" >/dev/null 2>&1
        echo "exiting..."
    echo "just re-run the script after toggling."
    echo "exiting with 1."
    return
}
_cleanup() {
  echo "Interrupted. Cleaning up..."
  kill -9 $PY_PID 2>/dev/null
  adb usb 2>/dev/null
  adb disconnect 2>/dev/null
  rm statics/._port.txt 2>/dev/null
  adb kill-server 2>/dev/null
  kill -9 $(pgrep -x adb) 2>/dev/null
  
  exit 1
}
_set_port(){
    if [ "$(! _adbd_ack)" ]; then
        echo "USB debugging is disabled. Turn on the USB debugging and wireless debugging to set the port."
        echo "and make sure the device is paired."
        echo
        _confirm "About to launch DEVELOPER OPTIONS..." 7 || exit 1;
        echo "Launching developer options..."
        # sleep 2
        am start -n "com.android.settings/.Settings\$DevelopmentSettingsDashboardActivity" >/dev/null 2>&1
        exit 1
    fi
    # nmap -sT -p30000-60000 --open localhost | grep '^ *[0-9]' | cut -d/ -f1
    # python3 ~/get_adbWifi_port.py 2>/dev/null
    
    trap _cleanup SIGINT
    
    python3 statics/get_adbWifi_port.py > statics/._port.txt 2>/dev/null &
    PY_PID=$!
    SECONDS=0
    
    while kill -0 $PY_PID 2>/dev/null; do
      sleep 0.1
      if [ $SECONDS -gt 3 ]; then
        echo -e "Not yet found, still searching..."
        echo "Make sure WIRELESS DEBUGGING is turned on and pair the device, if paired, restart it once."
        sleep 0.75
        printf "\033[3A\033[J"
      fi
    done
    
    PORT=$(cat statics/._port.txt)
    rm statics/._port.txt 2>/dev/null
    
    if [[ -z "$PORT" ]]; then
      echo "Couldn't find port."
      echo "Make sure WIRELESS DEBUGGING is turned ON and the device is paired."
      _confirm "want me to walk you through the process?" 3 || exit 1;
      _WiLs_debug_walkthrough
      exit 1
    fi
    echo "ADB port: $PORT"
}
# _set_port
# exit 0;
_set_ip() {
    for interface in wlan0 v4-ccmni1 v4-ccmni2; do
        local candidate=$(ifconfig 2>/dev/null | grep -A 3 "$interface" | grep 'inet ' | awk '{print $2}')
        [ -z "$candidate" ] && continue
        IP="$candidate"
        echo "IP set to $IP via $interface."
        return 0
    done
    # echo "$IP, $candidate"
    echo "No valid IP found."
    echo "make sure you are connected to a network."
    exit 1
}

# _check_ip_port(){
    
# }
_adb_connection_ack() {
    if [[ -z "$IP" ]] ; then
        _set_ip
    fi
     
    if [[ -z "$PORT" ]]; then 
        _set_port
    fi
    
    if [[ -z "$IP" || -z "$PORT" ]]; then
        echo "IP or PORT not set."
        echo IP: $IP
        echo PORT: $PORT
        echo "check "
        exit 1
    fi
    adb connect "$IP:$PORT" # | tee /dev/stderr
}
persist_adb(){
    echo "hdjjs"
    echo "execution flow entered persist_adb session."
    if ! pgrep -x adb >/dev/null 2>&1; then
        echo "no adb process found."
        _confirm "want to restart the process?" 1 || exit 1;
        echo "restarting the whole process from scratch..."
        start
        local ec=$?
        echo "exiting after the whole process is done."
        exit $ec
    fi
    echo "printing devices from persistence..."
    if ! pgrep -x adb >/dev/null 2>&1; then
      echo "No devices found."
      start
      local ec=$?
      # echo "assuming that the persistent emulator was connected."
      echo "and exiting from persistence after calling 'start'"
      exit $ec
    fi
    
    if ! _get_devices | grep -q "device"; then
      echo "Devices found but none are valid:"
      _get_devices
      adb disconnect 
      echo "trying to pair..."
      _adb_connection_ack
    fi
    if ! _get_devices | grep -q "device"; then
      echo "Devices found but none are valid:"
      echo printing devices: 
      _get_devices
      echo
      echo "disconnecting everything with 'adb disconnect'..."
      adb disconnect
      echo "printing devices: "
      _get_devices
      echo "exiting..."
      exit 1;
    fi
    
    # (_get_devices || echo "can't print devices") && return 1;
    # sleep 10
    
    local r=$(pgrep -x adb);
    echo "pgrep -x adb: $r"
    unset r;
    _get_devices
    echo "starting adb tunnel as tcp..."
    adb tcpip 5555 # >/dev/null 2>&1
    sleep 1
    if nc -z localhost 5555; then
      echo "TCP mode enabled."
    else
        if ! _get_devices | grep -q device; then 
            echo "no valid device found."
            _get_devices
            echo "disconnecting everything..."
            adb disconnect 
            _confirm "want to start the process from scratch?" || exit 1
            start
            exit
        fi
      echo "Failed to enable TCP mode."
      echo "printing devices: "
      _get_devices
      
    fi
    echo
    # sleep 2
    echo "killing old adb sessions..."
    adb kill-server 2>/dev/null;
    echo
    # sleep 2
    echo "starting fresh adb server..."
    adb start-server 2>/dev/null
    # sleep 2
    echo "printing devices: "
    _get_devices
    if _get_devices | grep -q '^emulator'; then
        adb shell settings put global adb_wifi_enabled 0;
        if ! _get_devices | grep -q '^emulator'; then
            echo "turn off both USB debugging and wireless debugging, then turn USB debugging back on."
            _confirm "do you want a persistent adb connection without much battery loss?" || exit 1;
            echo "launching dev options..."
            _USB_dbug_walkthrough
            printing devices 
            if _get_devices | grep -q '^emulator'; then exit 0; fi
            exit 1;
        fi
    fi
    if ! _get_devices | grep -q '^emulator' || ! _adbd_ack; then
        echo "you must turn on atleast one of USB debugging or wireless debugging."
        echo "devices: $(_get_devices)"
        echo "exiting with 1"
        exit 1
    fi
    # _confirm "Want to turn off wireless debugging?" || { echo "keeping wireless debugging on"; exit 0 }
    
    
    echo
    
    exit 0;
}

_get_pairing_code(){
    local REPLY_FILE="statics/.reply.txt"
    rm -f "$REPLY_FILE"     # clean previous if exists
    
    termux-toast "Notification posted." 
    termux-toast "Open notifications to enter the pairing code."
    
    # Show notification with inline reply
    termux-notification \
      --id 24 \
      --title "Pairing device found" \
      --content "Type pairing code below" \
      --priority max \
      --button1 "Enter" \
      --button1-action "echo \"\$REPLY\" > \"$REPLY_FILE\""
    
    echo "Waiting for your reply..."
        # Wait until file appears (poll every 1–2 seconds)
    while [[ ! -f "$REPLY_FILE" ]]; do
        sleep 1.5
    done
    
    # sleep 2
    # termux-notification-remove 42
    
    REPLY=$(cat "$REPLY_FILE")
    rm -f "$REPLY_FILE"
    
    # echo
    # echo "You entered:"
    # echo "$REPLY"
}
# _adb_connection_ack
pair(){
    echo "pairing..."
    echo "Click on 'pair device with pairing code' before 10s-15s after app gets opened."
    echo "after few(2s-3s) seconds, you'll get a notification, enter the pairing code there."
    _confirm "About to launch wireless debugging settings..." || exit 1;
    echo
    echo "Launching..."
    am start -n com.android.settings/.SubSettings \
        -e :android:show_fragment com.android.settings.development.WirelessDebuggingFragment \
        -e :android:show_fragment_title "Wireless Debugging" >/dev/null 2>&1
    
    PAIR=$(python statics/pairingPort.py)
    echo "port: $PAIR"
    if [ -z $PAIR ]; then 
        echo "Pairing port not found. May time out 30s"
        exit 1;
    fi
    _get_pairing_code
    echo "Pairing code: $REPLY"
    if echo "$REPLY" | adb pair "$IP:$PORT" | grep -q "Successfully" ; then 
        echo "Paired!" 
        return 0
    else 
        echo "Pairing failed"
        return 1
    fi
    # echo "$REPLY" | adb pair "$PAIR"
    
}
stop(){
    echo "Stopping..."
    if pgrep -x adb >/dev/null 2>&1 ; then
        echo "adb process found: $(pgrep -x adb)"
        exit 0;
    fi
    adb start-server;
    if ! _get_devices >/dev/null 2>&1 ; then
        echo "No devices attached."
        adb disconnect
        adb usb
        echo "killing adb process..."
        kill -9 "$(pgrep -x adb)" >/dev/null 2>&1
        exit 0;
    fi
    echo "devices found: $(_get_devices)"
    if _get_devices | grep -q '^emulator'; then
        echo "Emulator found:"
        _get_devices
        echo "emulator section" 
        # adb disconnect emulator-5554
        adb usb
        
        echo "disconnecting everything..."
        adb disconnect
        
        echo "killing adb server with 'adb kill-server'..." 
        adb kill-server
        
        echo "making sure there are no residues..."
        
        local p=$(pgrep -x adb)
        if [ -n "$p" ] && ! kill -9 "$p" 2>/dev/null; then
            echo "ADB process found but couldn't kill it. exiting."
            exit 1;
        fi
        echo "adb pid gets printed if adb is still running."
        echo "adb pid: $(pgrep -x adb)";
        
        exit 0;
        # pkill -9 -f $(which adb)
        # pkill -9 -f "$(pgrep -x adb)"
        # exit 0;
    fi
    
    _get_devices
    echo non emulator section 
    
    echo device found, disconnecting...
    adb disconnect # $(_get_devices | awk '{print $1}')
    # _get_devices | awk '{print $1}' | while read device; do adb disconnect "$device"; done
    adb kill-server
    kill -9 "$(pgrep -x adb)" >/dev/null 2>&1
    
    echo "pgrep -x adb: $(pgrep -x adb)"
    echo "pgrep -x socat: $(pgrep -x socat)"
    
}
start(){
    clear
    trap _cleanup SIGINT
    echo "checking whether the adb is already connected..."
    
    if [ -z "$(pgrep -x adb)" ]; then
        echo "adb process not found."
        echo "starting..."
        adb start-server
    fi
    if _get_devices | grep -q device; then 
        echo "found online connected devices."
        _get_devices
        if ! _get_devices | grep -q '^emulator'; then
            echo "but no emulators found."
            persist_adb
        fi
        echo "persistent emulator found."
        echo "printing devices: "
        _get_devices
        echo "exiting..."
        exit 0
    fi
    echo "no valid device found"
    
    # echo "adb is not connected."
    echo "starting from scratch..."
    echo
    
    # local r=_confirm "Do you turned on developer options?"
    if ! _confirm "Do you turned on developer options?"; then 
        _dev_ops_walkthrough
        exit 1;
    fi
    
    if ! _confirm "Do you turned on USB debugging?" ; then 
        _USB_dbug_walkthrough
        echo "just re-run the script after toggling."
        exit 1;
    fi
    if ! _confirm "Do you turned on wireless debugging?" ; then 
        _WiLs_debug_walkthrough
        exit 1;
    fi
    if ! _confirm "Is your device paired?" ; then 
        pair || exit 1
        
    fi
    
    
    
    
    echo "starting..."
    
    echo "finding adb port...";
    _set_port
    
    echo "finding device ip...";
    
    _set_ip
    
    
    # PORT=42327
    echo
    # result=$(adb connect "$IP:$PORT")
    # echo "$result"
    echo "Establishing initial adb connection..."
    local r=$(_adb_connection_ack)
    if ! echo "$r" | grep -q "connected"; then
        echo "Failed to connect, make sure to pair first using pairing code or ip and port are invalid."
        echo "$r";
        if ! _confirm "Do you want me to guide through the painting process?" 2 ; then
            echo "do it manually than, bye."
            exit 1;
        fi
        pair
        # _adb_connection_ack
        if [[ -n "$REPLY" && -n "$PAIR" ]]; then
          _confirm "pairing successful, want to continue further?" || { echo "exiting..."; exit 1; }
        fi
        exit 1
    fi
    
    echo "adb connection established successfully.";
    sleep 2
    
    persist_adb
    
}
status(){
    echo "adb port: $(getprop service.adb.tcp.port)"
    echo "adb pid: $(pgrep -x adb)"
    echo "connected devices: $(_get_devices | awk '{print $1}')"
}
main(){
    case "$1" in
      stop)
        stop
        ;;
      start)
        start
        ;;
      status)
        status
        ;;
      *)
        echo "Usage: $0 [start|stop|status]"
        echo "but got: $0 $1"
        exit 1
        ;;
    esac
}
main "$@"
exit 0; ### <=== script officially ended

if [ "$(_usb_debug_ack)" != "running" ]; then
    echo "USB debugging isn't turned on."
    _confirm "Want me to take to dev screen?" 4 || { echo "exiting" ; exit 1 }
    echo "Launching dev screen..."
    
    am start -n "com.android.settings/.Settings\$DevelopmentSettingsDashboardActivity" >/dev/null 2>&1
    
    
    exit 1;
fi
for interface in wlan0 v4-ccmni1 v4-ccmni2; do
        local candidate=$(ifconfig 2>/dev/null | grep -A 3 "$interface" | grep 'inet ' | awk '{print $2}')
        [ -z "$candidate" ] && continue
        result=$(adb connect "$candidate:$PORT")
        if echo "$result" | grep -q "connected"; then
            adb disconnect "$candidate:$PORT" >/dev/null 2>&1
            IP="$candidate"
            echo "IP set to $IP via $interface."
            return 0
        fi
    done
if [ "$(_usb_debug_ack)" = "running" ]; then
  echo "USB debugging is enabled."
else
  echo "USB debugging is disabled."
fi
# _confirm "Turned on dev options?"
# _confirm "Turned on wireless debugging?"
# _confirm "Turned on pairing code?"

exit 0
# getting connected devices freshly.

if _get_devices | grep -q '^emulator'; then
    echo "emulator found: "
    _get_devices
    echo "exiting..."
    exit 0
else
  echo "No emulator found."
fi

# PORT=$(nmap -sT -p30000-60000 --open localhost | grep '^ *[0-9]' | cut -d/ -f1 || echo "port not found")

