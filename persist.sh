echo kabhooom!

# prerequisites(){
    

_confirm() {
  echo "$1, if yes, then continue."
  echo
  read -p "Continue? [Y/n]: " answer
  answer="${answer:-y}"
  if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    # echo "$2"
    
    printf '\033[3A\033[J'
    return 1
  fi
  printf '\033[3A\033[J'
}
# _confirm "Turned on dev options?"
# exit 0;

_usb_debug_ack() {
  getprop init.svc.adbd
}

_get_devices(){
    adb devices 2>/dev/null | grep -A 100 'List of devices attached' | tail -n +2 # | cut -sf -1
}
_set_port(){
    if [ "$(_usb_debug_ack)" != "running" ]; then
        echo "USB debugging is disabled. Turn on the USB debugging and wireless debugging to set the port."
        echo "and make sure the device is paired."
        echo "launching developer options..."
        sleep 2;
        am start -n "com.android.settings/.Settings\$DevelopmentSettingsDashboardActivity" >/dev/null 2>&1
        exit 1
    fi
    PORT=$(nmap -sT -p30000-60000 --open localhost | grep '^ *[0-9]' | cut -d/ -f1 || echo "port not found")
    if [[ -z "$PORT" ]]; then
        echo "Couldn't find port: $PORT"
        echo "make sure to turn on the wireless debugging and pair the device."
        exit 1;
    fi
    echo adb port: $PORT;
}
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
    exit 1
}

# _check_ip_port(){
    
# }
_adb_connection_ack() {
    if [[ -z "$IP" || -z "$PORT" ]]; then
        echo "IP or PORT not set."
        echo IP: $IP
        echo PORT: $PORT
        echo "check "
        exit 1
    fi
    adb connect "$IP:$PORT" # | tee /dev/stderr
}
_post_pairing_notification(){
    local REPLY_FILE="/data/data/com.termux/files/home/.tmp/reply.txt"
    rm -f "$REPLY_FILE"     # clean previous if exists
    
    termux-toast "Notification posted." 
    termux-toast "Open notifications to enter the pairing code."
    
    # Show notification with inline reply
    termux-notification \
      --id 24 \
      --title "Enter text" \
      --content "Type below and send" \
      --priority max \
      --button1 "Send" \
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
    echo "just click on 'pair device with pairing code'"
    echo
    _confirm "okay? [Y|n]"
    echo "starting..."
    echo "Launching wireless debugging settings."
    am start -n com.android.settings/.SubSettings \
        -e :android:show_fragment com.android.settings.development.WirelessDebuggingFragment \
        -e :android:show_fragment_title "Wireless Debugging" >/dev/null 2>&1
    
    PAIR=$(python po2.py)
    echo "port: $PAIR"
    if [ -z $PAIR ]; then 
        echo "Pairing port not found. May time out 30s"
        exit 1;
    fi
    _post_pairing_notification
    echo "reply: $REPLY"
    
    echo "$REPLY" | adb pair "$PAIR"
    
}
stop(){
    echo "Stopping..."
    if [ -z "$(_get_devices)" ]; then
        echo "No devices attached."
        kill -9 "$(pgrep -x adb)" >/dev/null 2>&1
        exit 0;
    fi
    if _get_devices | grep -q '^emulator'; then
        echo "Emulator found:"
        _get_devices
        echo emulator section 
        # adb disconnect emulator-5554
        adb usb
        adb kill-server
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
    
}
start(){
    clear
    echo "checking whether the adb is already connected..."
    if [ -n "$(pgrep -x adb)" ]; then
        if [ -n "$(_get_devices)" ]; then
            echo "already connected"
            _get_devices
            exit 0;
        fi
    fi
    echo "adb is not connected."
    echo
    # local r=_confirm "Do you turned on developer options?"
    if ! _confirm "Do you turned on developer options?"; then 
        echo "Turn on the developer options."
        echo "Tap on (build number/OS version) number 7 times."
        _confirm "About to launch \"About phone\" settings" || exit 1;
        echo "Launching settings..."
        am start -a android.settings.DEVICE_INFO_SETTINGS  >/dev/null 2>&1
        exit 1;

    fi
    if ! _confirm "Do you turned on wireless debugging?" ; then 
        echo "Turn on the wireless debugging."
        echo "Launching wireless debugging settings."
        am start -n com.android.settings/.SubSettings \
            -e :android:show_fragment com.android.settings.development.WirelessDebuggingFragment \
            -e :android:show_fragment_title "Wireless Debugging" >/dev/null 2>&1
        
        exit 1
    fi
    if ! _confirm "Is your device paired?" ; then 
        pair
        
        exit 1;
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
    if ! _adb_connection_ack | grep -q "connected" >/dev/null 2>&1; then
        echo "Failed to connect, make sure to pair first using pairing code or ip and port are invalid."
        pair
        # _adb_connection_ack
        exit 1
    fi
    
    echo "adb connection established successfully.";
    sleep 2
    echo "printing devices..."
    adb devices
    sleep 2
    echo "starting adb tunnel as tcp..."
    adb tcpip 5555;
    echo
    sleep 2
    echo "killing old adb sessions..."
    adb kill-server 2>/dev/null;
    echo
    sleep 2
    echo "starting fresh adb server..."
    adb start-server 2>/dev/null
    sleep 2
    echo "turning off wireless debugging."
    adb shell settings put global adb_wifi_enabled 0;
    echo
    adb devices 
    
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
        echo "Usage: $0 [start|stop]"
        echo "but got: $0 $1"
        exit 1
        ;;
    esac
}
main "$@"
exit 0;
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

