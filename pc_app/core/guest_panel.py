import os
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
        
        # UI State
        self.current_state = "DASHBOARD" # DASHBOARD, SETUP, QR_VIEW
        self.available_folders = []
        self.selected_folders = {}
        self.selected_duration = 30
        self.active_sessions = []
        
        # UI Container
        self.container = ctk.CTkFrame(self, fg_color="transparent")
        self.container.pack(fill="both", expand=True, padx=20, pady=10)
        
        self.show_state("DASHBOARD")
        self._start_polling()

    def clear_container(self):
        for widget in self.container.winfo_children():
            widget.destroy()

    def show_state(self, state):
        self.current_state = state
        self.clear_container()
        
        if state == "DASHBOARD":
            self.render_dashboard()
        elif state == "SETUP":
            self.render_setup()
        elif state == "QR_VIEW":
            self.render_qr_view()

    # --- DASHBOARD: Active Sessions & Activity ---
    def render_dashboard(self):
        header = ctk.CTkFrame(self.container, fg_color="transparent")
        header.pack(fill="x", pady=(0, 20))
        
        ctk.CTkLabel(header, text="Guest Access Hub", font=("Segoe UI", 20, "bold"), text_color="#FFFFFF").pack(side="left")
        
        # New Session Button
        ctk.CTkButton(header, text="+ New Access", width=120, height=32, corner_radius=8,
                      fg_color="#6C63FF", font=("Segoe UI", 12, "bold"),
                      command=lambda: self.show_state("SETUP")).pack(side="right")

        self.sessions_scroll = ctk.CTkScrollableFrame(self.container, fg_color="transparent", height=400)
        self.sessions_scroll.pack(fill="both", expand=True)
        
        self.update_sessions_ui()

    def update_sessions_ui(self):
        if self.current_state != "DASHBOARD": return

        for widget in self.sessions_scroll.winfo_children():
            widget.destroy()

        if not self.active_sessions:
            placeholder = ctk.CTkFrame(self.sessions_scroll, fg_color="#121216", height=200, corner_radius=20)
            placeholder.pack(fill="x", pady=40)
            ctk.CTkLabel(placeholder, text="No active guest sessions", font=("Segoe UI", 14), text_color="#3F3F46").pack(expand=True)
            return

        for session in self.active_sessions:
            card = ctk.CTkFrame(self.sessions_scroll, fg_color="#121216", corner_radius=16, border_width=1, border_color="#1D1D26")
            card.pack(fill="x", pady=6, padx=2)

            # Left: Info
            info_frame = ctk.CTkFrame(card, fg_color="transparent")
            info_frame.pack(side="left", fill="both", expand=True, padx=15, pady=12)

            token_short = session['token'][:8] + "..."
            ctk.CTkLabel(info_frame, text=f"Guest {token_short}", font=("Segoe UI", 14, "bold"), text_color="#FFFFFF").pack(anchor="w")

            # Time Remaining
            rem = session.get('time_remaining_seconds', 0)
            mins, secs = divmod(rem, 60)
            timer_text = f"Ends in {mins:02d}:{secs:02d}"
            timer_color = "#6C63FF" if rem > 300 else "#FF453A"
            ctk.CTkLabel(info_frame, text=timer_text, font=("Segoe UI", 12), text_color=timer_color).pack(anchor="w")

            # Recent Activity
            log = session.get('access_log', [])
            if log:
                last_act = log[-1]
                detail = f"Last: {last_act['action']} {os.path.basename(last_act['file_path'])}"
                ctk.CTkLabel(info_frame, text=detail, font=("Segoe UI", 11), text_color="#8E8E93").pack(anchor="w", pady=(5, 0))
            else:
                ctk.CTkLabel(info_frame, text="Connected, no activity yet", font=("Segoe UI", 11), text_color="#3F3F46").pack(anchor="w", pady=(5, 0))

            # Right: Revoke
            ctk.CTkButton(card, text="Revoke", width=80, height=32, corner_radius=8,
                          fg_color="#1A1A1A", hover_color="#FF453A",
                          command=lambda t=session['token']: self.revoke_session(t)).pack(side="right", padx=15)

    # --- SETUP: Choose Folders & Duration ---
    def render_setup(self):
        ctk.CTkLabel(self.container, text="Setup Guest Access", font=("Segoe UI", 20, "bold"), text_color="#FFFFFF").pack(anchor="w")
        
        # Back Button
        ctk.CTkButton(self.container, text="← Back to Hub", width=100, height=24, fg_color="transparent",
                      text_color="#6C63FF", hover_color="#1A1A1A", anchor="w",
                      command=lambda: self.show_state("DASHBOARD")).pack(anchor="w", pady=5)

        # Folder Selection
        ctk.CTkLabel(self.container, text="Which folders can they see?", font=("Segoe UI", 13, "bold"), text_color="#8E8E93").pack(anchor="w", pady=(15, 5))
        
        self.folder_scroll = ctk.CTkScrollableFrame(self.container, fg_color="#121216", height=150, corner_radius=16, border_width=1, border_color="#1D1D26")
        self.folder_scroll.pack(fill="x", pady=5)
        
        # Duration Selection
        ctk.CTkLabel(self.container, text="Session duration", font=("Segoe UI", 13, "bold"), text_color="#8E8E93").pack(anchor="w", pady=(15, 10))
        duration_frame = ctk.CTkFrame(self.container, fg_color="transparent")
        duration_frame.pack(fill="x")
        
        self.dur_btns = {}
        durations = [("15m", 15), ("30m", 30), ("1h", 60), ("2h", 120)]
        for label, mins in durations:
            btn = ctk.CTkButton(duration_frame, text=label, width=75, height=36, corner_radius=12,
                                fg_color="#6C63FF" if mins == self.selected_duration else "#121216",
                                command=lambda m=mins: self.set_duration(m))
            btn.pack(side="left", padx=4)
            self.dur_btns[mins] = btn

        ctk.CTkButton(self.container, text="Create Guest Link", fg_color="#6C63FF", hover_color="#5B52E0",
                      height=52, corner_radius=16, font=("Segoe UI", 14, "bold"),
                      command=self.start_session).pack(fill="x", pady=(25, 0), padx=40)
        
        self.fetch_available_folders()

    def set_duration(self, mins):
        self.selected_duration = mins
        for m, btn in self.dur_btns.items():
            btn.configure(fg_color="#6C63FF" if m == mins else "#121216")

    def fetch_available_folders(self):
        def _fetch():
            try:
                r = requests.get(f"{BASE_URL}/settings", headers=HEADERS, timeout=5)
                if r.status_code == 200:
                    shared_folders = r.json().get("shared_folders", [])
                    self.available_folders = [{"name": os.path.basename(f) or f, "path": f} for f in shared_folders]
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
            ctk.CTkCheckBox(row, text=f['name'], variable=var, border_color="#6C63FF", checkmark_color="#6C63FF", font=("Segoe UI", 12)).pack(side="left")

    # --- QR VIEW: Show the Code ---
    def render_qr_view(self):
        ctk.CTkLabel(self.container, text="Guest Access Ready", font=("Segoe UI", 20, "bold"), text_color="#FFFFFF").pack(anchor="w")
        
        qr_card = ctk.CTkFrame(self.container, fg_color="#121216", corner_radius=24, border_width=1, border_color="#1D1D26")
        qr_card.pack(pady=20, padx=20)
        
        self.qr_label = ctk.CTkLabel(qr_card, text="")
        self.qr_label.pack(pady=20, padx=20)

        ctk.CTkLabel(self.container, text="Guests can scan this to see files.", text_color="#8E8E93", font=("Segoe UI", 12)).pack()
        
        ctk.CTkButton(self.container, text="Done (Go to Hub)", fg_color="#1A1A22", height=48, corner_radius=16,
                      command=lambda: self.show_state("DASHBOARD")).pack(fill="x", pady=20, padx=40)

        self.generate_qr_logic()

    def generate_qr_logic(self):
        def _logic():
            try:
                selected = [p for p, v in self.selected_folders.items() if v.get()]
                payload = {"folders": selected, "duration_minutes": self.selected_duration}
                r = requests.post(f"{BASE_URL}/guest/create", json=payload, headers=HEADERS, timeout=5)
                data = r.json()
                if data.get("success"):
                    guest_url = data.get("url")
                    qr = qrcode.QRCode(box_size=10, border=2)
                    qr.add_data(guest_url)
                    qr.make(fit=True)
                    img = qr.make_image(fill_color="#6C63FF", back_color="#0D0D0D")
                    self.after(0, lambda: self.display_qr(img))
            except: pass
        threading.Thread(target=_logic, daemon=True).start()

    def display_qr(self, pil_img):
        ctk_img = ctk.CTkImage(light_image=pil_img, dark_image=pil_img, size=(180, 180))
        self.qr_label.configure(image=ctk_img)

    # --- ACTIONS ---
    def start_session(self):
        self.show_state("QR_VIEW")

    def revoke_session(self, token):
        def _revoke():
            try: requests.post(f"{BASE_URL}/guest/end?token={token}", headers=HEADERS)
            except: pass
            self.after(0, self.refresh_sessions)
        threading.Thread(target=_revoke, daemon=True).start()

    def refresh_sessions(self):
        def _fetch():
            try:
                r = requests.get(f"{BASE_URL}/guest/sessions", headers=HEADERS, timeout=3)
                if r.status_code == 200:
                    self.active_sessions = r.json().get("sessions", [])
                    self.after(0, self.update_sessions_ui)
            except: pass
        threading.Thread(target=_fetch, daemon=True).start()

    def _start_polling(self):
        self.refresh_sessions()
        self.after(5000, self._start_polling)
