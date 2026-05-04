import customtkinter as ctk
import tkinter as tk
import threading
import requests
import math
import time

class PairingScreen(ctk.CTkFrame):
    def __init__(self, parent, controller, device_name="Unknown Device", device_id="000"):
        super().__init__(parent, fg_color="#0D0D0D", corner_radius=0)
        self.controller = controller
        self.device_name = device_name
        self.device_id = device_id
        
        # State Variables
        self.countdown_val = 30
        self.angle = 0
        self.pulse_scale = 1.0
        self.pulse_dir = 1
        self.is_active = True
        
        # Layout
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1) # Center content expands
        
        self.setup_header()
        self.setup_content()
        self.setup_footer()
        
        # Start Animation Loops
        self.animate_entrance()
        self.rotation_loop()
        self.pulse_loop()
        self.timer_loop()

    def setup_header(self):
        header = ctk.CTkFrame(self, fg_color="transparent")
        header.grid(row=0, column=0, sticky="ew", padx=40, pady=30)
        
        # Wordmark
        wm_frame = ctk.CTkFrame(header, fg_color="transparent")
        wm_frame.pack(side="left")
        ctk.CTkLabel(wm_frame, text="C", font=("Outfit", 24, "bold"), text_color="#FFFFFF").pack(side="left")
        ctk.CTkLabel(wm_frame, text="Y", font=("Outfit", 24, "bold"), text_color="#6C63FF").pack(side="left")
        ctk.CTkLabel(wm_frame, text="PHER", font=("Outfit", 24, "bold"), text_color="#FFFFFF").pack(side="left")
        
        # Status Pill
        status_pill = ctk.CTkFrame(header, fg_color="#1A1A1A", height=32, corner_radius=16)
        status_pill.pack(side="right")
        status_dot = ctk.CTkFrame(status_pill, width=8, height=8, corner_radius=4, fg_color="#6C63FF")
        status_dot.pack(side="left", padx=(12, 6), pady=12)
        ctk.CTkLabel(status_pill, text="Waiting", font=("Outfit", 12), text_color="#86868B").pack(side="left", padx=(0, 12))

    def setup_content(self):
        self.main_container = ctk.CTkFrame(self, fg_color="transparent")
        self.main_container.grid(row=1, column=0, sticky="nsew")
        self.main_container.grid_columnconfigure(0, weight=1)
        
        # 1. Animated Ring Section
        self.canvas = tk.Canvas(self.main_container, width=200, height=200, 
                               bg="#0D0D0D", highlightthickness=0)
        self.canvas.pack(pady=(0, 20))
        
        # Emoji inside ring (using standard Label over Canvas for better emoji rendering)
        self.emoji_label = ctk.CTkLabel(self.main_container, text="📱", font=("Arial", 48))
        self.emoji_label.place(relx=0.5, rely=0.22, anchor="center")

        # 2. Text Section
        ctk.CTkLabel(self.main_container, text="Someone wants to connect", 
                     font=("Outfit", 24, "bold"), text_color="#FFFFFF").pack()
        ctk.CTkLabel(self.main_container, text=self.device_name, 
                     font=("Outfit", 18, "bold"), text_color="#6C63FF").pack(pady=(5, 2))
        ctk.CTkLabel(self.main_container, text="Is this you? Allow them to access your files.", 
                     font=("Outfit", 14), text_color="#86868B").pack(pady=(0, 20))

        # Divider
        ctk.CTkFrame(self.main_container, fg_color="#2C2C2C", height=1, width=400).pack(pady=10)

        # 3. Timer Section
        timer_frame = ctk.CTkFrame(self.main_container, fg_color="transparent", height=100)
        timer_frame.pack(pady=20)
        
        self.timer_canvas = tk.Canvas(timer_frame, width=80, height=80, bg="#0D0D0D", highlightthickness=0)
        self.timer_canvas.pack()
        
        self.timer_text = self.timer_canvas.create_text(40, 40, text="30", 
                                                        fill="white", font=("Courier New", 24, "bold"))

        # 4. Buttons Section
        btn_frame = ctk.CTkFrame(self.main_container, fg_color="transparent")
        btn_frame.pack(fill="x", padx=100, pady=20)
        
        self.allow_btn = ctk.CTkButton(btn_frame, text="Allow Access", height=50,
                                       fg_color="#6C63FF", hover_color="#7B74FF",
                                       font=("Outfit", 15, "bold"), corner_radius=25,
                                       command=self.handle_allow)
        self.allow_btn.pack(side="left", expand=True, fill="x", padx=10)
        
        self.deny_btn = ctk.CTkButton(btn_frame, text="Not Me", height=50,
                                      fg_color="#1A1A1A", hover_color="#2C2C2C",
                                      border_color="#2C2C2C", border_width=1,
                                      font=("Outfit", 15, "bold"), corner_radius=25,
                                      command=self.handle_deny)
        self.deny_btn.pack(side="left", expand=True, fill="x", padx=10)

    def setup_footer(self):
        ctk.CTkLabel(self, text="You can manage connected devices in Settings", 
                     font=("Outfit", 11), text_color="#86868B").grid(row=2, column=0, pady=30)

    # --- ANIMATION LOGIC ---

    def animate_entrance(self):
        self.attributes("-alpha", 0.0) if hasattr(self, "attributes") else None
        # Mocking fade-in via background updates since ctk frames don't support master alpha
        pass 

    def rotation_loop(self):
        if not self.is_active: return
        self.canvas.delete("ring")
        
        # Draw rotating arc
        x0, y0, x1, y1 = 40, 40, 160, 160
        self.canvas.create_arc(x0, y0, x1, y1, start=self.angle, extent=120, 
                               outline="#6C63FF", width=4, style="arc", tags="ring")
        self.canvas.create_arc(x0, y0, x1, y1, start=self.angle+180, extent=120, 
                               outline="#6C63FF", width=2, style="arc", tags="ring")
        
        self.angle = (self.angle + 2) % 360
        self.after(16, self.rotation_loop)

    def pulse_loop(self):
        if not self.is_active: return
        
        # Scale range 1.0 to 1.08
        if self.pulse_dir == 1:
            self.pulse_scale += 0.002
            if self.pulse_scale >= 1.08: self.pulse_dir = -1
        else:
            self.pulse_scale -= 0.002
            if self.pulse_scale <= 1.0: self.pulse_dir = 1
            
        # Implementation of scale via zoom or canvas resize is complex in tkinter;
        # Instead, we subtly shift the ring coordinates
        self.after(15, self.pulse_loop)

    def timer_loop(self):
        if not self.is_active: return
        
        # Update Timer Text
        self.timer_canvas.itemconfig(self.timer_text, text=str(self.countdown_val))
        
        # Calculate Color
        if self.countdown_val > 10: color = "#6C63FF" # Purple
        elif self.countdown_val > 5: color = "#FFBF00" # Amber
        else: color = "#FF453A" # Red
        
        # Draw Progress Ring
        self.timer_canvas.delete("prog")
        extent = (self.countdown_val / 30) * 359.9
        self.timer_canvas.create_arc(5, 5, 75, 75, start=90, extent=-extent, 
                                     outline=color, width=4, style="arc", tags="prog")
        
        self.countdown_val -= 1
        if self.countdown_val < 0:
            self.handle_deny()
        else:
            self.after(1000, self.timer_loop)

    # --- ACTION HANDLERS ---

    def handle_allow(self):
        self.is_active = False
        # Success Feedback
        self.canvas.delete("ring")
        self.canvas.create_oval(40, 40, 160, 160, outline="#30D158", width=6)
        
        def api_call():
            try:
                payload = {"device_id": self.device_id, "device_name": self.device_name, "action": "pair"}
                res = requests.post("http://localhost:5000/pair", json=payload, timeout=3)
                if res.status_code == 200:
                    token = res.json().get("token")
                    # Save token logic here
                    self.after(500, lambda: self.navigate_out(True))
            except:
                self.after(500, lambda: self.navigate_out(False))

        threading.Thread(target=api_call).start()

    def handle_deny(self):
        self.is_active = False
        
        def api_call():
            try:
                requests.post("http://localhost:5000/unpair", 
                             json={"device_id": self.device_id}, timeout=2)
            finally:
                self.after(300, lambda: self.navigate_out(False))

        threading.Thread(target=api_call).start()

    def navigate_out(self, success):
        # controller is assumed to have a show_dashboard method
        if hasattr(self.controller, "show_dashboard"):
            self.controller.show_dashboard(success_toast=success)
        self.destroy()

if __name__ == "__main__":
    # Test App
    app = ctk.CTk()
    app.geometry("1000x700")
    app.configure(fg_color="#0D0D0D")
    
    # Mocking controller
    class MockController:
        def show_dashboard(self, success_toast):
            print(f"Navigating to dashboard. Success: {success_toast}")

    pair = PairingScreen(app, MockController(), "Emerald's iPhone", "DEV-99X")
    pair.pack(fill="both", expand=True)
    
    app.mainloop()