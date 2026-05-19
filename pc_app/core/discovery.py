from zeroconf import IPVersion, ServiceInfo, Zeroconf
import socket
import threading
import time
import json
import logging
import traceback
import uuid

log = logging.getLogger("cypher")

class CypherDiscovery:
    def __init__(self, pc_name, port=5000):
        self.pc_name = pc_name
        self.port = port
        self.zeroconf = None
        self.info = None
        self.stop_event = threading.Event()
        self.udp_socket = None
        self._lock = threading.Lock()

    def get_local_ip(self):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "127.0.0.1"

    def _broadcast_udp(self):
        """Standard UDP Broadcast with IP change detection."""
        log.info(f"[DISCOVERY] Starting UDP Broadcast on port {self.port+1}")
        self.udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.udp_socket.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        self.udp_socket.settimeout(2)

        last_ip = self.get_local_ip()

        while not self.stop_event.is_set():
            try:
                current_ip = self.get_local_ip()

                # [FIX] Resilient Reconnection:
                # If IP changes (e.g., hotspot reconnect), re-register Zeroconf
                if current_ip != last_ip and current_ip != "127.0.0.1":
                    log.info(f"[DISCOVERY] IP Change detected ({last_ip} -> {current_ip}). Re-registering...")
                    self.update_name(self.pc_name) # Forces re-registration
                    last_ip = current_ip

                with self._lock:
                    broadcast_data = json.dumps({
                        "type": "CYPHER_DISCOVERY",
                        "pc_name": self.pc_name,
                        "port": self.port,
                        "ip": current_ip
                    }).encode('utf-8')

                self.udp_socket.sendto(broadcast_data, ('<broadcast>', self.port + 1))
                time.sleep(5)
            except Exception as e:
                if not self.stop_event.is_set():
                    log.error(f"UDP Broadcast error: {e}")
                break

        if self.udp_socket:
            self.udp_socket.close()

    def start(self):
        try:
            self.zeroconf = Zeroconf(ip_version=IPVersion.V4Only)
            self._register_zeroconf()

            # Start UDP fallback
            threading.Thread(target=self._broadcast_udp, daemon=True).start()

        except Exception as e:
            log.error(f"Discovery startup failed: {e}")
            log.error(traceback.format_exc())

    def _register_zeroconf(self):
        local_ip = self.get_local_ip()
        unique_id = str(uuid.uuid4())[:8]
        desc = {'version': '1.0.0', 'pc_name': self.pc_name}

        self.info = ServiceInfo(
            "_cypher._tcp.local.",
            f"{self.pc_name}-{unique_id}._cypher._tcp.local.",
            addresses=[socket.inet_aton(local_ip)],
            port=self.port,
            properties=desc,
            server=f"{socket.gethostname().replace(' ', '-')}.local.",
        )

        log.info(f"[DISCOVERY] Zeroconf Advertising {self.pc_name} on {local_ip}:{self.port}")
        self.zeroconf.register_service(self.info)

    def update_name(self, new_name):
        """Bulletproof name update for NSD."""
        with self._lock:
            if self.pc_name == new_name:
                return

            log.info(f"[DISCOVERY] Updating broadcast name to: {new_name}")

            # 1. Unregister old service
            if self.zeroconf and self.info:
                try:
                    self.zeroconf.unregister_service(self.info)
                except:
                    pass

            # 2. Update internal name
            self.pc_name = new_name

            # 3. Re-register with new name
            if self.zeroconf:
                self._register_zeroconf()

    def stop(self):
        self.stop_event.set()
        try:
            if self.zeroconf:
                if self.info:
                    self.zeroconf.unregister_service(self.info)
                self.zeroconf.close()
            if self.udp_socket:
                self.udp_socket.close()
        except Exception as e:
            log.error(f"Discovery stop error: {e}")

_global_discovery = None

def start_discovery_thread(pc_name):
    global _global_discovery
    _global_discovery = CypherDiscovery(pc_name)
    _global_discovery.start()
    return _global_discovery

def get_discovery_instance():
    return _global_discovery
