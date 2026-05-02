import customtkinter as ctk
import requests
import threading
import time
import socket
import json
import qrcode
import webbrowser
from PIL import Image
from pathlib import Path

COLORS = {
    "bg": "#0D0D0D",
    "sidebar": "#080808",
    "card": "#1A1A1A",
    "accent": "#6C63FF",
    "white": "#FFFFFF",
    "grey": "#86868B",
    "success": "#30D158",
}

INTERNAL_TOKEN = "cypher-internal-pc-app-token-2024"

class DashboardScreen(ctk.CTkFrame):
    def __init__(self, parent):
        super().__init__(parent, fg_color=COLORS["bg"], corner_radius=0)
        
        self.active_panel = "Shared Files"
        self.connected_device = None
        self.connect_code = "------"
        self.local_ip = self.get_local_ip()
        self.broadcast = None

        # UI Layout
        self.setup_sidebar()
        self.setup_main_area()

        # Data Polling
        self.stop_polling = False
        threading.Thread(target=self.poll_data, daemon=True).start()

    def get_local_ip(self):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except: return "127.0.0.1"

    def setup_sidebar(self):
        self.sidebar = ctk.CTkFrame(self, fg_color=COLORS["sidebar"], width=200, corner_radius=0)
        self.sidebar.pack(side="left", fill="y")
        self.sidebar.pack_propagate(False)
        
        # Wordmark
        logo_row = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        logo_row.pack(pady=30)
        ctk.CTkLabel(logo_row, text="C", font=("Helvetica Neue", 24, "bold"), text_color=COLORS["white"]).pack(side="left")
        ctk.CTkLabel(logo_row, text="Y", font=("Helvetica Neue", 24, "bold"), text_color=COLORS["accent"]).pack(side="left")
        ctk.CTkLabel(logo_row, text="PHER", font=("Helvetica Neue", 24, "bold"), text_color=COLORS["white"]).pack(side="left")
        
        # Status Pill
        self.status_pill = ctk.CTkLabel(self.sidebar, text="● Waiting",
                                        font=("Helvetica Neue", 12),
                                        text_color=COLORS["grey"],
                                        fg_color="#151515",
                                        corner_radius=12,
                                        width=120, height=24)
        self.status_pill.pack(pady=(0, 30))
        
        # Nav Items
        self.nav_buttons = {}
        items = [("📁 Shared Files", "Shared Files"),
                 ("👥 Guest Access", "Guest Access"),
                 ("📜 Activity", "Activity"),
                 ("⚙️ Settings", "Settings")]
        
        for text, name in items:
            btn = ctk.CTkButton(self.sidebar, text=text,
                                font=("Helvetica Neue", 14),
                                anchor="w",
                                height=44,
                                corner_radius=12,
                                fg_color="transparent" if name != self.active_panel else COLORS["accent"],
                                text_color=COLORS["white"] if name == self.active_panel else COLORS["grey"],
                                hover_color=COLORS["card"],
                                command=lambda n=name: self.show_panel(n))
            btn.pack(fill="x", padx=15, pady=2)
            self.nav_buttons[name] = btn

        # Bottom Device Info
        self.credit_lbl = ctk.CTkLabel(self.sidebar, text="Designed by Emerald",
                                       font=("Helvetica Neue", 11, "bold"),
                                       text_color="#444444", cursor="hand2")
        self.credit_lbl.pack(side="bottom", pady=(5, 20))
        self.credit_lbl.bind("<Button-1>", lambda e: webbrowser.open("https://www.tiktok.com/@emerald_dev1"))

        self.device_lbl = ctk.CTkLabel(self.sidebar, text="No device linked",
                                       font=("Helvetica Neue", 11),
                                       text_color="#333333")
        self.device_lbl.pack(side="bottom", pady=0)

    def setup_main_area(self):
        self.main_area = ctk.CTkFrame(self, fg_color="transparent")
        self.main_area.pack(side="right", fill="both", expand=True)
        self.show_panel(self.active_panel)

    def show_panel(self, name):
        # Update Nav UI
        self.nav_buttons[self.active_panel].configure(fg_color="transparent", text_color=COLORS["grey"])
        self.active_panel = name
        self.nav_buttons[name].configure(fg_color=COLORS["accent"], text_color=COLORS["white"])
        
        # Clear Main Area
        for widget in self.main_area.winfo_children():
            widget.destroy()
            
        if name == "Shared Files": self.show_home_panel()
        elif name == "Guest Access": self.show_guest_panel()
        elif name == "Activity": self.show_activity_panel()
        elif name == "Settings": self.show_settings_panel()
        else: self.show_placeholder(name)

    def show_placeholder(self, name):
        ctk.CTkLabel(self.main_area, text=name, font=("Helvetica Neue", 24, "bold"), text_color=COLORS["white"]).pack(pady=100)
        ctk.CTkLabel(self.main_area, text="Coming soon in the next update", font=("Helvetica Neue", 14), text_color=COLORS["grey"]).pack()

    def show_home_panel(self):
        if not self.connected_device:
            self.show_waiting_state()
        else:
            self.show_connected_state()

    def show_waiting_state(self):
        # Radar Animation Container
        self.radar_frame = ctk.CTkFrame(self.main_area, fg_color="transparent")
        self.radar_frame.pack(pady=(80, 20))

        self.radar_circle = ctk.CTkFrame(self.radar_frame, width=100, height=100,
                                         corner_radius=50, border_width=2,
                                         border_color=COLORS["accent"], fg_color="transparent")
        self.radar_circle.pack()
        ctk.CTkLabel(self.radar_circle, text="📡", font=("Helvetica Neue", 32)).place(relx=0.5, rely=0.5, anchor="center")

        self.pulse_radar()

        ctk.CTkLabel(self.main_area, text="Waiting for your phone",
                     font=("Helvetica Neue", 22, "bold"), text_color=COLORS["white"]).pack()
        ctk.CTkLabel(self.main_area, text="Open CYPHER on your phone and enter your connect code",
                     font=("Helvetica Neue", 14), text_color=COLORS["grey"]).pack(pady=5)

        # Connect Code Card
        code_card = ctk.CTkFrame(self.main_area, fg_color=COLORS["card"], corner_radius=20, width=380, height=180)
        code_card.pack(pady=40)
        code_card.pack_propagate(False)

        ctk.CTkLabel(code_card, text="YOUR CONNECT CODE", font=("Helvetica Neue", 11, "bold"), text_color=COLORS["grey"]).pack(pady=(25, 0))

        # Format code with spaces
        display_code = " ".join(self.connect_code)
        self.code_lbl = ctk.CTkLabel(code_card, text=display_code,
                                     font=("Courier New", 48, "bold"), text_color=COLORS["accent"])
        self.code_lbl.pack(pady=10)

        addr_row = ctk.CTkFrame(code_card, fg_color="transparent")
        addr_row.pack()
        ctk.CTkLabel(addr_row, text=f"Your PC address: {self.local_ip}", font=("Helvetica Neue", 12), text_color=COLORS["grey"]).pack(side="left")

    def show_connected_state(self):
        # Connected Banner
        banner = ctk.CTkFrame(self.main_area, fg_color="#121A12", corner_radius=12, height=50)
        banner.pack(fill="x", padx=20, pady=20)
        banner.pack_propagate(False)
        ctk.CTkLabel(banner, text=f"📱 {self.connected_device} is connected",
                     font=("Helvetica Neue", 14, "bold"), text_color=COLORS["success"]).pack(relx=0.5, rely=0.5, anchor="center")

        # Stats Grid
        stats_frame = ctk.CTkFrame(self.main_area, fg_color="transparent")
        stats_frame.pack(fill="x", padx=20)

        self.stats_pills = {}
        for i, stat in enumerate(["CPU", "RAM", "DISK"]):
            pill = ctk.CTkFrame(stats_frame, fg_color=COLORS["card"], corner_radius=15, height=80)
            pill.pack(side="left", fill="x", expand=True, padx=5)
            ctk.CTkLabel(pill, text=stat, font=("Helvetica Neue", 11, "bold"), text_color=COLORS["grey"]).pack(pady=(15, 0))
            val_lbl = ctk.CTkLabel(pill, text="0%", font=("Helvetica Neue", 20, "bold"), text_color=COLORS["white"])
            val_lbl.pack()
            self.stats_pills[stat] = val_lbl

    def show_guest_panel(self):
        ctk.CTkLabel(self.main_area, text="Guest Access", font=("Helvetica Neue", 24, "bold"), text_color=COLORS["white"]).pack(pady=(40, 10))
        ctk.CTkLabel(self.main_area, text="Let a friend connect quickly by scanning this QR", font=("Helvetica Neue", 14), text_color=COLORS["grey"]).pack(pady=(0, 40))

        # QR Generation
        qr_data = f"cypher://{self.local_ip}:5000/{self.connect_code}"
        qr = qrcode.QRCode(version=1, box_size=10, border=4)
        qr.add_data(qr_data)
        qr.make(fit=True)
        img = qr.make_image(fill_color="white", back_color="#0D0D0D")

        # Convert PIL to ctkImage
        ctk_img = ctk.CTkImage(light_image=img, dark_image=img, size=(240, 240))

        qr_card = ctk.CTkFrame(self.main_area, fg_color=COLORS["card"], corner_radius=24, width=300, height=300)
        qr_card.pack()
        qr_card.pack_propagate(False)

        ctk.CTkLabel(qr_card, image=ctk_img, text="").place(relx=0.5, rely=0.5, anchor="center")

        ctk.CTkLabel(self.main_area, text="Scan with CYPHER app on phone", font=("Helvetica Neue", 12), text_color=COLORS["accent"]).pack(pady=20)

    def show_activity_panel(self):
        ctk.CTkLabel(self.main_area, text="Recent Activity", font=("Helvetica Neue", 24, "bold"), text_color=COLORS["white"]).pack(pady=(40, 10))

        self.activity_scroll = ctk.CTkScrollableFrame(self.main_area, fg_color="transparent", width=460, height=500)
        self.activity_scroll.pack(fill="both", expand=True, padx=20, pady=10)

        self.refresh_activity()

    def refresh_activity(self):
        for w in self.activity_scroll.winfo_children(): w.destroy()
        try:
            r = requests.get("http://localhost:5000/history", headers={"X-Auth-Token": INTERNAL_TOKEN}, timeout=1)
            if r.status_code == 200:
                history = r.json()[::-1] # Reverse
                for item in history[:10]:
                    row = ctk.CTkFrame(self.activity_scroll, fg_color=COLORS["card"], corner_radius=12, height=60)
                    row.pack(fill="x", pady=5)
                    row.pack_propagate(False)

                    # Icon/Emoji based on endpoint
                    ep = item['endpoint']
                    emoji = "📁" if "/files" in ep else "⚡"
                    if "/power" in ep: emoji = "🔋"

                    ctk.CTkLabel(row, text=emoji, font=("Helvetica Neue", 16)).pack(side="left", padx=15)

                    info_col = ctk.CTkFrame(row, fg_color="transparent")
                    info_col.pack(side="left", fill="y", pady=10)

                    action_text = ep.split('/')[-1].capitalize()
                    ctk.CTkLabel(info_col, text=action_text, font=("Helvetica Neue", 13, "bold"), text_color=COLORS["white"]).pack(anchor="w")
                    ctk.CTkLabel(info_col, text=item['timestamp'], font=("Helvetica Neue", 11), text_color=COLORS["grey"]).pack(anchor="w")

                    status_text = "Done" if item['success'] else "Failed"
                    status_color = COLORS["success"] if item['success'] else "#FF453A"
                    ctk.CTkLabel(row, text=status_text, font=("Helvetica Neue", 11, "bold"), text_color=status_color).pack(side="right", padx=15)
        except: pass

    def show_settings_panel(self):
        ctk.CTkLabel(self.main_area, text="PC Settings", font=("Helvetica Neue", 24, "bold"), text_color=COLORS["white"]).pack(pady=(40, 30))

        settings_card = ctk.CTkFrame(self.main_area, fg_color=COLORS["card"], corner_radius=20, width=420)
        settings_card.pack(padx=20, pady=10, fill="x")

        # PC Name Edit
        name_row = ctk.CTkFrame(settings_card, fg_color="transparent", height=60)
        name_row.pack(fill="x", padx=20, pady=10)
        ctk.CTkLabel(name_row, text="PC Display Name", font=("Helvetica Neue", 14), text_color=COLORS["white"]).pack(side="left")

        self.name_entry = ctk.CTkEntry(name_row, width=200, height=32, corner_radius=10, fg_color="#0D0D0D", border_width=0)
        self.name_entry.pack(side="right")

        # Load current name
        if Path("pc_app/cypher_config.json").exists():
            with open("pc_app/cypher_config.json", "r") as f:
                self.name_entry.insert(0, json.load(f).get("pc_name", "Cypher PC"))

        # Discovery Toggle
        disc_row = ctk.CTkFrame(settings_card, fg_color="transparent", height=60)
        disc_row.pack(fill="x", padx=20, pady=10)
        ctk.CTkLabel(disc_row, text="Auto-Discovery (mDNS)", font=("Helvetica Neue", 14), text_color=COLORS["white"]).pack(side="left")
        ctk.CTkSwitch(disc_row, text="", progress_color=COLORS["accent"]).pack(side="right")

        # Version & Updates
        ver_row = ctk.CTkFrame(settings_card, fg_color="transparent", height=60)
        ver_row.pack(fill="x", padx=20, pady=10)
        ctk.CTkLabel(ver_row, text="Version 1.0.0", font=("Helvetica Neue", 12), text_color=COLORS["grey"]).pack(side="left")
        ctk.CTkButton(ver_row, text="Check for Updates", width=120, height=28, corner_radius=14,
                      fg_color="#222222", hover_color="#333333", font=("Helvetica Neue", 11),
                      command=lambda: print("Checking...")).pack(side="right")

        ctk.CTkButton(self.main_area, text="Save Changes", command=self.save_settings,
                      fg_color=COLORS["accent"], height=44, corner_radius=22).pack(pady=40, padx=40, fill="x")

    def save_settings(self):
        new_name = self.name_entry.get()
        config = {"pc_name": new_name}
        with open("pc_app/cypher_config.json", "w") as f:
            json.dump(config, f)
        # Update current display
        self.device_lbl.configure(text=f"Linked to {self.connected_device}" if self.connected_device else "Waiting...")
        print("[SETTINGS] PC Name updated to:", new_name)

    def pulse_radar(self):
        if hasattr(self, "radar_circle") and self.radar_circle.winfo_exists():
            current_w = self.radar_circle.cget("border_width")
            new_w = 6 if current_w == 2 else 2
            self.radar_circle.configure(border_width=new_w)
            self.after(800, self.pulse_radar)

    def poll_data(self):
        headers = {"X-Auth-Token": INTERNAL_TOKEN}
        while not self.stop_polling:
            try:
                # 1. Check Connect Code (Public)
                r_code = requests.get("http://localhost:5000/connect-code", timeout=1)
                if r_code.status_code == 200:
                    self.connect_code = r_code.json().get("code", "------")
                    if hasattr(self, "code_lbl"):
                        self.after(0, lambda c=self.connect_code: self.code_lbl.configure(text=" ".join(c)))

                # 2. Check Paired Devices
                r_dev = requests.get("http://localhost:5000/paired-devices", headers=headers, timeout=1)
                if r_dev.status_code == 200:
                    devices = r_dev.json()
                    new_device = devices[0]["device_name"] if devices else None
                    if new_device != self.connected_device:
                        self.after(0, lambda d=new_device: self.update_connection_state(d))

                # 3. Stats
                if self.connected_device:
                    r_stats = requests.get("http://localhost:5000/system-stats", headers=headers, timeout=1)
                    if r_stats.status_code == 200:
                        stats = r_stats.json()
                        self.after(0, lambda s=stats: self.update_stats(s))

                # 4. Global Broadcast from Emerald's Hub
                if not self.broadcast:
                    r_hub = requests.get("https://cypher-3ctq.onrender.com/api/broadcast", timeout=2)
                    if r_hub.status_code == 200:
                        data = r_hub.json()
                        if data.get('active'):
                            self.broadcast = data
                            self.after(0, self.show_broadcast_banner)

            except: pass
            time.sleep(1)

    def update_connection_state(self, device_name):
        self.connected_device = device_name
        if device_name:
            self.status_pill.configure(text="● Connected", text_color=COLORS["success"])
            self.device_lbl.configure(text=f"Linked to {device_name}")
        else:
            self.status_pill.configure(text="● Waiting", text_color=COLORS["grey"])
            self.device_lbl.configure(text="No device linked")

        if self.active_panel == "Shared Files":
            self.show_home_panel()

    def update_stats(self, stats):
        if not hasattr(self, "stats_pills") or "CPU" not in self.stats_pills: return
        try:
            self.stats_pills["CPU"].configure(text=f"{int(stats['cpu_percent'])}%")
            self.stats_pills["RAM"].configure(text=f"{int(stats['ram_percent'])}%")
            self.stats_pills["DISK"].configure(text=f"{int(stats['disk_percent'])}%")
        except: pass

    def show_broadcast_banner(self):
        if not self.broadcast: return
        banner = ctk.CTkFrame(self.main_area, fg_color=COLORS["card"], corner_radius=15, height=60, border_width=1, border_color=COLORS["accent"])
        banner.pack(fill="x", padx=20, pady=(0, 20))
        banner.pack_propagate(False)

        ctk.CTkLabel(banner, text="📢", font=("Helvetica Neue", 16)).pack(side="left", padx=15)
        ctk.CTkLabel(banner, text=self.broadcast['title'], font=("Helvetica Neue", 13, "bold"), text_color=COLORS["white"]).pack(side="left")

        btn = ctk.CTkButton(banner, text=self.broadcast.get('link_text', 'Join'),
                            width=100, height=30, corner_radius=15, fg_color=COLORS["accent"],
                            command=lambda: webbrowser.open(self.broadcast['link']))
        btn.pack(side="right", padx=15)
