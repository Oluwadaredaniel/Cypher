import customtkinter as ctk
import requests
import threading
import json
import time
import socket
import qrcode
from PIL import Image
from io import BytesIO

INTERNAL_TOKEN = "cypher-internal-pc-app-token-2024"
HEADERS = {"X-Auth-Token": INTERNAL_TOKEN}
BASE_URL = "http://localhost:5000"

class GuestPanel(ctk.CTkFrame):
    def __init__(self, parent, controller=None):
        super().__init__(parent, fg_color="#08080A", corner_radius=0)
        self.controller = controller
        
        # Session State
        self.current_state = "NO_SESSION"
        self.available_folders = []
        self.selected_folders = {}
        self.selected_duration = 30 # Default 30 mins
        self.remaining_seconds = 0
        self.guest_session_id = None
        self.is_guest_connected = False
        
        # UI Container
        self.container = ctk.CTkFrame(self, fg_color="transparent")
        self.container.pack(fill="both", expand=True, padx=20, pady=10)
        
        self.show_state("NO_SESSION")

    def get_pc_ip(self):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except: return "127.0.0.1"

    def clear_container(self):
        for widget in self.container.winfo_children():
            widget.destroy()

    def show_state(self, state):
        self.current_state = state
        self.clear_container()
        
        if state == "NO_SESSION":
            self.render_no_session()
        elif state == "SETUP":
            self.render_setup()
        elif state == "ACTIVE":
            self.render_active()

    # --- STATE 1: NO SESSION ---
    def render_no_session(self):
        ctk.CTkLabel(self.container, text="Guest Access Control", font=("Segoe UI", 20, "bold"), text_color="#FFFFFF").pack(anchor="w")
        ctk.CTkLabel(self.container, text="Securely share folders with visitors.", font=("Segoe UI", 13), text_color="#8E8E93").pack(anchor="w", pady=(2, 20))
        
        placeholder = ctk.CTkFrame(self.container, width=320, height=240, fg_color="#121216",
                           border_width=1, border_color="#1D1D26", corner_radius=28)
        placeholder.pack(pady=30)
        placeholder.pack_propagate(False)
        
        ctk.CTkLabel(placeholder, text="👥", font=("Arial", 64)).place(relx=0.5, rely=0.4, anchor="center")
        ctk.CTkLabel(placeholder, text="No active guest session", font=("Segoe UI", 14, "bold"), text_color="#3F3F46").place(relx=0.5, rely=0.7, anchor="center")
        
        ctk.CTkButton(self.container, text="Start New Guest Session", fg_color="#6C63FF", hover_color="#5B52E0",
                      height=52, corner_radius=16, font=("Segoe UI", 14, "bold"),
                      command=lambda: self.show_state("SETUP")).pack(fill="x", pady=20, padx=40)

    # --- STATE 2: SETUP ---
    def render_setup(self):
        ctk.CTkLabel(self.container, text="Setup Guest Access", font=("Segoe UI", 20, "bold"), text_color="#FFFFFF").pack(anchor="w")
        
        # Folder Selection
        ctk.CTkLabel(self.container, text="Which folders can they see?", font=("Segoe UI", 13, "bold"), text_color="#8E8E93").pack(anchor="w", pady=(20, 10))
        
        self.folder_scroll = ctk.CTkScrollableFrame(self.folder_scroll_parent if hasattr(self, 'folder_scroll_parent') else self.container,
                                                    fg_color="#121216", height=180, corner_radius=20, border_width=1, border_color="#1D1D26")
        self.folder_scroll.pack(fill="x", pady=5)
        
        # Duration Selection
        ctk.CTkLabel(self.container, text="Session duration", font=("Segoe UI", 13, "bold"), text_color="#8E8E93").pack(anchor="w", pady=(15, 10))
        duration_frame = ctk.CTkFrame(self.container, fg_color="transparent")
        duration_frame.pack(fill="x")
        
        self.dur_btns = {}
        durations = [("15 min", 15), ("30 min", 30), ("1 hour", 60), ("2 hours", 120)]
        for label, mins in durations:
            btn = ctk.CTkButton(duration_frame, text=label, width=90, height=38, corner_radius=14,
                                fg_color="#6C63FF" if mins == self.selected_duration else "#121216",
                                text_color="#FFFFFF" if mins == self.selected_duration else "#8E8E93",
                                border_width=1, border_color="#6C63FF" if mins == self.selected_duration else "#1D1D26",
                                command=lambda m=mins: self.set_duration(m))
            btn.pack(side="left", padx=4)
            self.dur_btns[mins] = btn

        ctk.CTkButton(self.container, text="Generate Access Code", fg_color="#6C63FF", hover_color="#5B52E0",
                      height=52, corner_radius=16, font=("Segoe UI", 14, "bold"),
                      command=self.start_session).pack(fill="x", pady=(25, 0), padx=40)
        
        self.fetch_available_folders()

    def set_duration(self, mins):
        self.selected_duration = mins
        for m, btn in self.dur_btns.items():
            if m == mins:
                btn.configure(fg_color="#6C63FF", border_color="#6C63FF")
            else:
                btn.configure(fg_color="#1A1A1A", border_color="#2C2C2C")

    def fetch_available_folders(self):
        def _fetch():
            try:
                r = requests.get(f"{BASE_URL}/files", headers=HEADERS, timeout=5)
                if r.status_code == 200:
                    self.available_folders = r.json()
                    self.after(0, self.update_folder_list)
            except: pass
        threading.Thread(target=_fetch, daemon=True).start()

    def update_folder_list(self):
        for f in self.available_folders:
            path = f['path']
            var = ctk.BooleanVar(value=True)
            self.selected_folders[path] = var
            row = ctk.CTkFrame(self.folder_scroll, fg_color="transparent")
            row.pack(fill="x", pady=2, padx=5)
            ctk.CTkCheckBox(row, text=f['name'], variable=var, border_color="#6C63FF", checkcolor="#6C63FF").pack(side="left")
            ctk.CTkLabel(row, text=path, font=("Arial", 10), text_color="#86868B").pack(side="right")

    # --- STATE 3: ACTIVE ---
    def render_active(self):
        # Green Banner (Glass)
        self.status_banner = ctk.CTkFrame(self.container, fg_color="#12241A", height=44, corner_radius=12, border_width=1, border_color="#1F4D32")
        self.status_banner.pack(fill="x", pady=(0, 20))
        self.status_text = ctk.CTkLabel(self.status_banner, text="Guest session is active", text_color="#30D158", font=("Segoe UI", 13, "bold"))
        self.status_text.pack(pady=10)
        
        # QR Code Area (Centered Card)
        qr_card = ctk.CTkFrame(self.container, fg_color="#121216", corner_radius=24, border_width=1, border_color="#1D1D26")
        qr_card.pack(pady=10, padx=20)
        
        self.qr_label = ctk.CTkLabel(qr_card, text="")
        self.qr_label.pack(pady=20, padx=20)
        ctk.CTkLabel(self.container, text="Ask your guest to scan this", text_color="#8E8E93", font=("Segoe UI", 12)).pack()

        # Timer (Bold Accent)
        self.timer_label = ctk.CTkLabel(self.container, text="00:00", font=("Courier New", 48, "bold"), text_color="#6C63FF")
        self.timer_label.pack(pady=15)
        
        # Info
        shared_count = sum(1 for v in self.selected_folders.values() if v.get())
        ctk.CTkLabel(self.container, text=f"Folders shared: {shared_count} selected", font=("Segoe UI", 12), text_color="#3F3F46").pack()
        
        # End Button
        self.end_btn = ctk.CTkButton(self.container, text="End Session Now", fg_color="#1A1A22", hover_color="#FF453A",
                                     height=48, corner_radius=16, border_width=1, border_color="#2C2C35",
                                     command=self.end_session)
        self.end_btn.pack(fill="x", pady=20, padx=40)

        self.generate_qr_logic()
        self.countdown_tick()
        self.poll_guest()

    def generate_qr_logic(self):
        def _logic():
            try:
                # 1. Get Code
                r_code = requests.get(f"{BASE_URL}/connect-code").json()
                code = r_code.get("code")
                
                # 2. Get Guest Token
                ts = int(time.time())
                self.guest_session_id = f"guest-session-{ts}"
                pair_data = {"pairing_code": code, "device_id": self.guest_session_id, "device_name": "Guest Device"}
                r_pair = requests.post(f"{BASE_URL}/pair_device", json=pair_data, headers=HEADERS).json()
                
                if r_pair.get("success"):
                    token = r_pair.get("token")
                    qr_payload = {
                        "ip": self.get_pc_ip(),
                        "port": 5000,
                        "token": token,
                        "folders": [p for p, v in self.selected_folders.items() if v.get()],
                        "expires": ts + (self.selected_duration * 60)
                    }
                    
                    # Generate QR Image
                    qr = qrcode.QRCode(box_size=10, border=2)
                    qr.add_data(json.dumps(qr_payload))
                    qr.make(fit=True)
                    img = qr.make_image(fill_color="#6C63FF", back_color="#0D0D0D")
                    
                    # Convert to CTkImage
                    self.after(0, lambda: self.display_qr(img))
            except: pass
        threading.Thread(target=_logic, daemon=True).start()

    def display_qr(self, pil_img):
        ctk_img = ctk.CTkImage(light_image=pil_img, dark_image=pil_img, size=(180, 180))
        self.qr_label.configure(image=ctk_img)
        self.remaining_seconds = self.selected_duration * 60

    def countdown_tick(self):
        if self.current_state != "ACTIVE": return
        
        if self.remaining_seconds <= 0:
            self.end_session()
            return
            
        self.remaining_seconds -= 1
        mins, secs = divmod(self.remaining_seconds, 60)
        self.timer_label.configure(text=f"{mins:02d}:{secs:02d}")
        
        # Color Shifting
        if self.remaining_seconds < 60: # Under 1 min
            self.timer_label.configure(text_color="#FF453A")
        elif self.remaining_seconds < 300: # Under 5 mins
            self.timer_label.configure(text_color="#FF9F0A")
            
        self.after(1000, self.countdown_tick)

    def poll_guest(self):
        if self.current_state != "ACTIVE": return
        
        def _poll():
            try:
                r = requests.get(f"{BASE_URL}/paired-devices", headers=HEADERS, timeout=2)
                devices = r.json()
                is_present = any(d.get('device_id') == self.guest_session_id for d in devices)
                
                if is_present and not self.is_guest_connected:
                    self.is_guest_connected = True
                    self.after(0, self.flash_banner)
            except: pass
            
        threading.Thread(target=_poll, daemon=True).start()
        self.after(3000, self.poll_guest)

    def flash_banner(self):
        self.status_banner.configure(fg_color="#30D158")
        self.status_text.configure(text_color="#FFFFFF", text="📱 Guest has connected!")
        self.after(2000, lambda: self.status_banner.configure(fg_color="#0D2818"))
        self.after(2000, lambda: self.status_text.configure(text_color="#30D158", text="Guest session is active"))

    def start_session(self):
        self.show_state("ACTIVE")

    def end_session(self):
        def _unpair():
            try:
                requests.post(f"{BASE_URL}/unpair", json={"device_id": self.guest_session_id}, headers=HEADERS)
            except: pass
            self.after(0, lambda: self.show_state("NO_SESSION"))
        
        threading.Thread(target=_unpair, daemon=True).start()
        self.remaining_seconds = 0
        self.is_guest_connected = False