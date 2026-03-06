from zeroconf import Zeroconf, ServiceBrowser
import threading
import sys

done = threading.Event()

class Listener:
    def add_service(self, zc, type_, name):
        info = zc.get_service_info(type_, name)
        if info:
            ip = ".".join(str(b) for b in info.addresses[0])
            print(f"{ip}:{info.port}")
            done.set()

    def remove_service(self, zc, type_, name): pass
    def update_service(self, zc, type_, name): pass

zc = Zeroconf()
ServiceBrowser(zc, "_adb-tls-pairing._tcp.local.", Listener())
found = done.wait(timeout=30)
zc.close()

if not found:
    sys.exit(1)  # non-zero = timeout/not found
