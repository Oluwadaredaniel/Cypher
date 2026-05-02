from zeroconf import IPVersion, ServiceInfo, Zeroconf
import socket
import threading

class CypherDiscovery:
    def __init__(self, pc_name, port=5000):
        self.pc_name = pc_name
        self.port = port
        self.zeroconf = Zeroconf(ip_version=IPVersion.V4Only)
        self.info = None

    def get_local_ip(self):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except:
            return "127.0.0.1"

    def start(self):
        local_ip = self.get_local_ip()
        desc = {'version': '1.0.0', 'pc_name': self.pc_name}

        self.info = ServiceInfo(
            "_cypher._tcp.local.",
            f"{self.pc_name}._cypher._tcp.local.",
            addresses=[socket.inet_aton(local_ip)],
            port=self.port,
            properties=desc,
            server=f"{socket.gethostname()}.local.",
        )

        print(f"[DISCOVERY] Advertising {self.pc_name} on {local_ip}:{self.port}")
        self.zeroconf.register_service(self.info)

    def stop(self):
        if self.info:
            self.zeroconf.unregister_service(self.info)
        self.zeroconf.close()

def start_discovery_thread(pc_name):
    discovery = CypherDiscovery(pc_name)
    discovery.start()
    return discovery
