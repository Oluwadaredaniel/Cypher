import customtkinter as ctk
import threading
import time

class RecordingOverlay:
    def __init__(self):
        self.root = None
        self.stop_event = threading.Event()
        self.is_active = False

    def start(self):
        if self.is_active: return
        self.is_active = True
        self.stop_event.clear()
        threading.Thread(target=self._run, daemon=True).start()

    def stop(self):
        self.is_active = False
        self.stop_event.set()
        if self.root:
            self.root.after(0, self.root.destroy)

    def _run(self):
        self.root = ctk.CTk()

        # Make it a small, floating bar at the top-center
        screen_width = self.root.winfo_screenwidth()
        width = 240
        height = 40
        x = (screen_width // 2) - (width // 2)
        y = 10 # 10px from top

        self.root.geometry(f"{width}x{height}+{x}+{y}")
        self.root.overrideredirect(True) # Remove title bar
        self.root.attributes("-topmost", True) # Always on top
        self.root.attributes("-alpha", 0.9) # Slightly transparent
        self.root.configure(fg_color="#1A1A1A")

        # Layout
        frame = ctk.CTkFrame(self.root, fg_color="#1A1A1A", corner_radius=20, border_width=1, border_color="#FF453A")
        frame.pack(fill="both", expand=True)

        self.dot = ctk.CTkLabel(frame, text="●", font=("Segoe UI", 18, "bold"), text_color="#FF453A")
        self.dot.pack(side="left", padx=(20, 10))

        self.label = ctk.CTkLabel(frame, text="CYPHER RECORDING", font=("Segoe UI", 11, "bold"), text_color="#FFFFFF")
        self.label.pack(side="left")

        # Blinking effect
        def blink():
            if not self.is_active: return
            current = self.dot.cget("text_color")
            new_color = "#FF453A" if current != "#FF453A" else "#333333"
            self.dot.configure(text_color=new_color)
            self.root.after(800, blink)

        self.root.after(800, blink)
        self.root.mainloop()

# Global instance
overlay_manager = RecordingOverlay()
