# adbw — ADB Wireless Manager

> A Termux shell utility to manage ADB wireless debugging sessions on Android — with guided setup, auto IP/port discovery, and seamless pairing.

---

## Features

- **Auto-discovery** of ADB wireless port via `nmap` and device IP via `ifconfig`
- **Guided setup** — walks you through developer options, wireless debugging, and pairing step by step
- **In-notification pairing** — prompts for the pairing code directly from the Android notification shade via `termux-notification`
- **Clean teardown** — disconnects devices, kills stale ADB processes, and resets server state
- **Status snapshot** — shows current TCP port, PID, and connected devices at a glance

## Usage

```bash
bash adbw.sh [start|stop|status]
```

| Command  | Description                                              |
|----------|----------------------------------------------------------|
| `start`  | Guided flow to establish a wireless ADB connection       |
| `stop`   | Disconnect devices and kill the ADB server               |
| `status` | Print current ADB TCP port, PID, and connected devices   |

## Requirements

- [Termux](https://termux.dev) on Android
- `adb`, `nmap`, `python3`, `termux-api` installed
- Developer options & wireless debugging enabled on device
- `po2.py` present in the same directory (pairing port resolver)

## Notes

The `start` command will automatically launch the relevant Android Settings screens if prerequisites aren't met. After a successful connection, it switches ADB to TCP mode (`tcpip 5555`) and disables wireless debugging to save battery.
