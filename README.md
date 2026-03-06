# auto-adbt — adb connection automator for termux

Automates wireless ADB setup on Android from within Termux — no PC needed.

---

## What it does

- Detects your device IP and wireless ADB port automatically
- Walks you through enabling developer options, USB debugging, and wireless debugging step by step
- Handles pairing via pairing code (with in-notification reply)
- Persists the ADB connection over TCP so it survives USB disconnects
- Gracefully stops and cleans up ADB sessions

---

## Requirements

- [Termux](https://termux.dev)
- `adb` — `pkg install android-tools`
- `termux-api` — `pkg install termux-api` + [Termux:API app](https://f-droid.org/packages/com.termux.api/)
- `python3` — `pkg install python`
- `zeroconf` — `pip install zeroconf`
- `get_adbWifi_port.py` and `pairingPort.py` in the same directory

---

## Usage

```bash
bash adbt.sh [start|stop|status]
```

| Command  | Description                                      |
|----------|--------------------------------------------------|
| `start`  | Interactive setup — guides through full connection flow |
| `stop`   | Disconnects devices and kills ADB server         |
| `status` | Shows ADB port, PID, and connected devices       |

---

## Flow overview

```
start
 ├─ already connected? → persist & exit
 ├─ developer options enabled?
 ├─ USB debugging on?
 ├─ wireless debugging on?
 ├─ paired? → pair if not (auto pairing code via notification)
 ├─ detect port (get_adbWifi_port.py)
 ├─ detect IP (wlan0 / v4-ccmni1 / v4-ccmni2)
 ├─ adb connect
 └─ persist over TCP → exit
```

---

## Notes

- Run from inside a Termux session on the device you want to debug
- Wireless debugging port changes each session — that's expected
- `persist_adb` switches to `tcpip 5555` and kills the wireless debugging port so the connection holds without a cable

---

## License

MIT
