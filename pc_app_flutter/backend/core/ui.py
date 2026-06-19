import customtkinter as ctk
import os
import json
from splash_screen import SplashScreen
from setup_screen import SetupScreen

class CypherApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        
        self.title("CYPHER")
        self.geometry("520x760")
        self.withdraw() 
        
        # Center main window
        screen_width = self.winfo_screenwidth()
        screen_height = self.winfo_screenheight()
        x = (screen_width // 2) - (520 // 2)
        y = (screen_height // 2) - (760 // 2)
        self.geometry(f"520x760+{x}+{y}")
        
        # Start Splash
        self.splash = SplashScreen(on_complete=self.show_setup)

    def show_setup(self):
        self.deiconify() 
        self.setup = SetupScreen(self, on_setup_complete=self.on_complete)
        self.setup.pack(fill="both", expand=True)

    def on_complete(self, config):
        # Fade out setup and show Success
        self.setup.destroy()
        
        success_frame = ctk.CTkFrame(self, fg_color="#FFFFFF")
        success_frame.pack(fill="both", expand=True)
        
        ctk.CTkLabel(success_frame, text="DECRYPTING SYSTEM...", 
                     font=("Inter", 12, "bold"), text_color="#86868B").place(relx=0.5, rely=0.45, anchor="center")
        
        ctk.CTkLabel(success_frame, text="CYPHER ACTIVE", 
                     font=("Inter", 32, "bold"), text_color="#000000").place(relx=0.5, rely=0.5, anchor="center")
        
        # Final exit after showing status
        self.after(2500, self.destroy)

if __name__ == "__main__":
    app = CypherApp()
    app.mainloop()