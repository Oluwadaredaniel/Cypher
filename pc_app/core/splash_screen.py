import customtkinter as ctk
import tkinter as tk
from core.utils import get_metadata

COLORS = {
    "bg": "#0D0D0D",
    "accent": "#6C63FF",
    "white": "#FFFFFF",
    "grey": "#86868B",
}

class SplashScreen(ctk.CTkFrame):
    def __init__(self, parent, on_complete):
        super().__init__(parent, fg_color=COLORS["bg"], corner_radius=0)
        self.on_complete = on_complete
        self._letter_labels = []
        self._letter_idx = 0

        # Load Dynamic Name
        meta = get_metadata()
        self.app_name = meta.get("app_name", "CYPHER")

        # Center container
        center = ctk.CTkFrame(self, fg_color="transparent")
        center.place(relx=0.5, rely=0.46, anchor="center")

        # Wordmark
        logo_row = ctk.CTkFrame(center, fg_color="transparent")
        logo_row.pack()

        for i, char in enumerate(self.app_name):
            # Emerald's Branding: First letter white, second accent, rest white
            # Or customized based on index
            color = COLORS["accent"] if i == 1 else COLORS["white"]

            lbl = ctk.CTkLabel(logo_row, text=char,
                font=("Helvetica Neue", 58, "bold"),
                text_color=COLORS["bg"]) # Hide initially
            lbl.pack(side="left")
            self._letter_labels.append((lbl, color))

        # Tagline
        self._tagline = ctk.CTkLabel(center,
            text="Your files. Anywhere.",
            font=("Helvetica Neue", 14),
            text_color=COLORS["bg"])
        self._tagline.pack(pady=(10, 0))

        # Progress bar
        self._bar_frame = ctk.CTkFrame(self, fg_color="transparent")
        self._bar_frame.place(relx=0.5, rely=0.62, anchor="center")
        self._bar = ctk.CTkProgressBar(self._bar_frame,
            width=140, height=3,
            corner_radius=2,
            fg_color="#1A1A1A",
            progress_color=COLORS["accent"])
        self._bar.pack()
        self._bar.set(0)

        # Start animation
        self.after(300, self._reveal_letters)

    def _reveal_letters(self):
        if self._letter_idx < len(self._letter_labels):
            lbl, color = self._letter_labels[self._letter_idx]
            lbl.configure(text_color=color)
            self._letter_idx += 1
            self.after(90, self._reveal_letters)
        else:
            self.after(200, self._show_tagline)

    def _show_tagline(self):
        self._tagline.configure(text_color=COLORS["grey"])
        self.after(100, self._animate_bar)

    def _animate_bar(self, step=0):
        if step <= 100:
            self._bar.set(step / 100)
            self.after(15, lambda: self._animate_bar(step + 1))
        else:
            self.after(300, self._fade_out)

    def _fade_out(self, step=10):
        if step >= 0:
            self.after(20, lambda: self._fade_out(step - 1))
        else:
            self.on_complete()
