import customtkinter as ctk
import json
from pathlib import Path
from core.utils import get_config_path

COLORS = {
    "bg": "#0D0D0D",
    "card": "#1A1A1A",
    "accent": "#6C63FF",
    "white": "#FFFFFF",
    "grey": "#86868B",
}

CONFIG_FILE = get_config_path("cypher_config.json")

class SetupScreen(ctk.CTkFrame):
    def __init__(self, parent, on_setup_complete):
        super().__init__(parent, fg_color=COLORS["bg"], corner_radius=0)
        self.on_complete = on_setup_complete
        
        self.pc_name = ctk.StringVar(value="")
        self.folders = {
            "Desktop": True,
            "Documents": True,
            "Downloads": True,
            "Videos": True,
            "Music": True,
            "Pictures": True
        }
        
        self.container = ctk.CTkFrame(self, fg_color="transparent")
        self.container.pack(fill="both", expand=True, padx=40, pady=40)
        
        self.show_step_1()

    def clear_container(self):
        for widget in self.container.winfo_children():
            widget.destroy()

    def show_step_1(self):
        self.clear_container()

        ctk.CTkLabel(self.container, text="Name your PC",
                     font=("Segoe UI", 28, "bold"),
                     text_color=COLORS["white"]).pack(pady=(40, 10))

        ctk.CTkLabel(self.container, text="This name will be shown on your phone",
                     font=("Segoe UI", 14),
                     text_color=COLORS["grey"]).pack(pady=(0, 30))

        self.name_entry = ctk.CTkEntry(self.container,
                                       placeholder_text="e.g. Home PC, Gaming Setup",
                                       width=340, height=50,
                                       corner_radius=25,
                                       fg_color=COLORS["card"],
                                       border_color="#333333",
                                       text_color=COLORS["white"])
        self.name_entry.pack(pady=20)

        self.next_btn = ctk.CTkButton(self.container, text="Next",
                                      command=self.validate_step_1,
                                      width=200, height=50,
                                      corner_radius=25,
                                      fg_color=COLORS["accent"],
                                      hover_color="#5B52E5",
                                      font=("Segoe UI", 15, "bold"))
        self.next_btn.pack(side="bottom", pady=40)

    def validate_step_1(self):
        name = self.name_entry.get().strip()
        if name:
            self.pc_name.set(name)
            self.show_step_2()

    def show_step_2(self):
        self.clear_container()

        ctk.CTkLabel(self.container, text="Shared Folders",
                     font=("Segoe UI", 28, "bold"),
                     text_color=COLORS["white"]).pack(pady=(40, 10))

        ctk.CTkLabel(self.container, text="Choose which folders to share with CYPHER",
                     font=("Segoe UI", 14),
                     text_color=COLORS["grey"]).pack(pady=(0, 30))

        scroll = ctk.CTkScrollableFrame(self.container, fg_color="transparent", width=340, height=300)
        scroll.pack(fill="both", expand=True)

        for folder, enabled in self.folders.items():
            f_row = ctk.CTkFrame(scroll, fg_color=COLORS["card"], corner_radius=15, height=60)
            f_row.pack(fill="x", pady=5)
            f_row.pack_propagate(False)
            
            ctk.CTkLabel(f_row, text=folder, font=("Segoe UI", 15),
                         text_color=COLORS["white"]).pack(side="left", padx=20)
            
            sw = ctk.CTkSwitch(f_row, text="", command=lambda f=folder: self.toggle_folder(f),
                               progress_color=COLORS["accent"], fg_color="#333333")
            sw.select() if enabled else sw.deselect()
            sw.pack(side="right", padx=10)

        btn_row = ctk.CTkFrame(self.container, fg_color="transparent")
        btn_row.pack(side="bottom", fill="x", pady=40)

        ctk.CTkButton(btn_row, text="Back", command=self.show_step_1,
                      width=100, height=50, corner_radius=25,
                      fg_color="#333333", text_color=COLORS["white"]).pack(side="left", padx=10)

        ctk.CTkButton(btn_row, text="Next", command=self.show_step_3,
                      width=200, height=50, corner_radius=25,
                      fg_color=COLORS["accent"], font=("Segoe UI", 15, "bold")).pack(side="right", padx=10)

    def toggle_folder(self, folder):
        self.folders[folder] = not self.folders[folder]

    def show_step_3(self):
        self.clear_container()

        ctk.CTkLabel(self.container, text="Ready to go!",
                     font=("Segoe UI", 28, "bold"),
                     text_color=COLORS["white"]).pack(pady=(40, 10))

        summary_card = ctk.CTkFrame(self.container, fg_color=COLORS["card"], corner_radius=20, width=340, height=180)
        summary_card.pack(pady=40)
        summary_card.pack_propagate(False)

        ctk.CTkLabel(summary_card, text="PC NAME", font=("Segoe UI", 11, "bold"), text_color=COLORS["grey"]).pack(pady=(20, 0))
        ctk.CTkLabel(summary_card, text=self.pc_name.get(), font=("Segoe UI", 20, "bold"), text_color=COLORS["white"]).pack()

        folder_count = sum(1 for v in self.folders.values() if v)
        ctk.CTkLabel(summary_card, text=f"{folder_count} Folders Shared", font=("Segoe UI", 14), text_color=COLORS["accent"]).pack(pady=20)

        ctk.CTkButton(self.container, text="Open CYPHER", command=self.finish,
                      width=340, height=60, corner_radius=30,
                      fg_color=COLORS["accent"], font=("Segoe UI", 16, "bold")).pack(side="bottom", pady=40)

    def finish(self):
        config = {
            "pc_name": self.pc_name.get(),
            "shared_folders": [f for f, enabled in self.folders.items() if enabled]
        }
        with open(CONFIG_FILE, "w") as f:
            json.dump(config, f)

        # [UPDATE] Sync onboarding name to global settings.json for mDNS and server
        try:
            settings_path = get_config_path("settings.json")
            settings = {}
            if settings_path.exists():
                with open(settings_path, 'r') as f:
                    settings = json.load(f)

            settings["device_name"] = self.pc_name.get()

            with open(settings_path, 'w') as f:
                json.dump(settings, f, indent=4)
        except Exception as e:
            print(f"Error syncing onboarding name: {e}")

        self.on_complete()
