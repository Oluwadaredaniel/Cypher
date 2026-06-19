import customtkinter as ctk
import tkinter as tk
from tkinter import filedialog
import requests
import threading
import os

INTERNAL_TOKEN = "cypher-internal-pc-app-token-2024"
HEADERS = {"X-Auth-Token": INTERNAL_TOKEN}
BASE_URL = "http://localhost:5000"

class FilesPanel(ctk.CTkFrame):
    def __init__(self, parent, controller=None):
        super().__init__(parent, fg_color="#0D0D0D", corner_radius=0)
        self.controller = controller
        self.shared_folders = []
        self.pulse_color = "#2C2C2C"
        
        # UI Setup
        self.setup_header()
        
        # Scrollable area for folders
        self.scroll_frame = ctk.CTkScrollableFrame(
            self, fg_color="transparent", corner_radius=0
        )
        self.scroll_frame.pack(fill="both", expand=True, padx=40, pady=20)
        
        self.setup_storage_section()
        
        # Initial Data Load
        self.load_data()
        self.start_animations()

    def setup_header(self):
        header = ctk.CTkFrame(self, fg_color="transparent")
        header.pack(fill="x", padx=40, pady=(30, 10))
        
        title_box = ctk.CTkFrame(header, fg_color="transparent")
        title_box.pack(side="left")
        
        ctk.CTkLabel(title_box, text="Shared Files", font=("Segoe UI", 20, "bold"), text_color="#FFFFFF").pack(anchor="w")
        ctk.CTkLabel(title_box, text="These folders are visible to your phone", font=("Segoe UI", 13), text_color="#86868B").pack(anchor="w")
        
        self.add_btn = ctk.CTkButton(
            header, text="+ Add Folder", fg_color="#6C63FF", hover_color="#5B52E0",
            corner_radius=20, font=("Segoe UI", 13, "bold"), height=38,
            command=self.browse_and_add
        )
        self.add_btn.pack(side="right")

    def setup_storage_section(self):
        self.storage_container = ctk.CTkFrame(self, fg_color="#1A1A1A", corner_radius=20, height=120)
        self.storage_container.pack(fill="x", padx=40, pady=(0, 30))
        self.storage_container.pack_propagate(False)
        
        ctk.CTkLabel(self.storage_container, text="Storage", font=("Segoe UI", 14, "bold"), text_color="#FFFFFF").pack(anchor="w", padx=20, pady=(15, 5))
        
        self.progress_bar = ctk.CTkProgressBar(self.storage_container, fg_color="#2C2C2C", progress_color="#6C63FF", height=12, corner_radius=6)
        self.progress_bar.pack(fill="x", padx=20, pady=5)
        self.progress_bar.set(0)
        
        label_frame = ctk.CTkFrame(self.storage_container, fg_color="transparent")
        label_frame.pack(fill="x", padx=20, pady=(5, 15))
        
        self.used_lbl = ctk.CTkLabel(label_frame, text="0 GB used", font=("Segoe UI", 12), text_color="#86868B")
        self.used_lbl.pack(side="left")
        
        self.free_lbl = ctk.CTkLabel(label_frame, text="0 GB free", font=("Segoe UI", 12), text_color="#86868B")
        self.free_lbl.pack(side="right")

    def load_data(self):
        def _fetch():
            try:
                # Get existing settings
                r = requests.get(f"{BASE_URL}/settings", headers=HEADERS, timeout=5)
                if r.status_code == 200:
                    self.shared_folders = r.json().get("shared_folders", [])
                
                # Update UI
                self.after(0, self.refresh_folder_list)
                self.update_storage_stats()
            except Exception as e:
                print(f"Load Error: {e}")

        threading.Thread(target=_fetch, daemon=True).start()

    def update_storage_stats(self):
        def _fetch():
            try:
                r = requests.get(f"{BASE_URL}/system-stats", headers=HEADERS, timeout=5)
                if r.status_code == 200:
                    d = r.json()
                    used = d.get('disk_used', 0)
                    total = d.get('disk_total', 0)
                    free = round(total - used, 1)
                    percent = d.get('disk_percent', 0) / 100
                    
                    self.after(0, lambda: self.update_storage_ui(used, free, percent))
            except: pass
        threading.Thread(target=_fetch, daemon=True).start()

    def update_storage_ui(self, used, free, percent):
        self.progress_bar.set(percent)
        self.used_lbl.configure(text=f"{used} GB used")
        self.free_lbl.configure(text=f"{free} GB free")

    def refresh_folder_list(self):
        for widget in self.scroll_frame.winfo_children():
            widget.destroy()
            
        for path in self.shared_folders:
            self.create_folder_card(path)
            
        self.create_add_placeholder()

    def create_folder_card(self, path):
        name = os.path.basename(path) or path
        card = ctk.CTkFrame(self.scroll_frame, fg_color="#1A1A1A", corner_radius=20, height=80)
        card.pack(fill="x", pady=5)
        card.pack_propagate(False)
        
        # Hover effect
        card.bind("<Enter>", lambda e: card.configure(border_width=1, border_color="#6C63FF"))
        card.bind("<Leave>", lambda e: card.configure(border_width=0))

        # Icon
        icon_circle = ctk.CTkFrame(card, width=44, height=44, corner_radius=22, fg_color="#2C2C2C")
        icon_circle.pack(side="left", padx=15)
        icon_circle.pack_propagate(False)
        ctk.CTkLabel(icon_circle, text="📁", font=("Arial", 20)).place(relx=0.5, rely=0.5, anchor="center")

        # Info
        info = ctk.CTkFrame(card, fg_color="transparent")
        info.pack(side="left", fill="y", pady=15)
        ctk.CTkLabel(info, text=name, font=("Segoe UI", 14, "bold"), text_color="#FFFFFF").pack(anchor="w")
        ctk.CTkLabel(info, text=path, font=("Segoe UI", 11), text_color="#86868B").pack(anchor="w")

        # Actions
        actions = ctk.CTkFrame(card, fg_color="transparent")
        actions.pack(side="right", padx=15)
        
        ctk.CTkSwitch(actions, text="", progress_color="#6C63FF", width=40).pack(side="left", padx=10)
        
        remove_btn = ctk.CTkButton(
            actions, text="Remove", font=("Segoe UI", 11), text_color="#86868B",
            fg_color="transparent", hover_color="transparent", width=50,
            command=lambda p=path: self.remove_folder(p)
        )
        remove_btn.pack(side="left")
        remove_btn.bind("<Enter>", lambda e: remove_btn.configure(text_color="#FF453A"))
        remove_btn.bind("<Leave>", lambda e: remove_btn.configure(text_color="#86868B"))

    def create_add_placeholder(self):
        # REMOVE border_style="dashed" from here
        self.add_placeholder = ctk.CTkFrame(
            self.scroll_frame, fg_color="transparent", corner_radius=20, 
            height=80, border_width=2, border_color=self.pulse_color
            # DELETE THE DASHED LINE HERE
        )
        self.add_placeholder.pack(fill="x", pady=10)
        self.add_placeholder.pack_propagate(False)
        
        inner = ctk.CTkFrame(self.add_placeholder, fg_color="transparent")
        inner.place(relx=0.5, rely=0.5, anchor="center")
        
        ctk.CTkLabel(inner, text="📁", font=("Arial", 20)).pack(side="left", padx=10)
        ctk.CTkLabel(inner, text="Add a folder", font=("Segoe UI", 13), text_color="#86868B").pack(side="left")
        
        self.add_placeholder.bind("<Button-1>", lambda e: self.browse_and_add())

    def start_animations(self):
        # Pulse animation for the add card
        def pulse():
            self.pulse_color = "#6C63FF" if self.pulse_color == "#2C2C2C" else "#2C2C2C"
            if hasattr(self, 'add_placeholder'):
                self.add_placeholder.configure(border_color=self.pulse_color)
            self.after(2000, pulse)
        pulse()

    def browse_and_add(self):
        path = filedialog.askdirectory()
        if path and path not in self.shared_folders:
            self.shared_folders.append(path)
            self.save_config()

    def remove_folder(self, path):
        if path in self.shared_folders:
            self.shared_folders.remove(path)
            self.save_config()

    def save_config(self):
        def _send():
            try:
                payload = {"shared_folders": self.shared_folders}
                requests.post(f"{BASE_URL}/settings", json=payload, headers=HEADERS, timeout=5)
                self.after(0, self.refresh_folder_list)
            except Exception as e:
                print(f"Save Error: {e}")
        
        threading.Thread(target=_send, daemon=True).start()