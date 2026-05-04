import pystray
from PIL import Image
import threading
import os
import sys

def start_tray():
    def on_show(icon, item):
        icon.stop() # This breaks the loop and allows the main window to be recreated/shown

    def on_exit(icon, item):
        icon.stop()
        os._exit(0)

    icon = pystray.Icon("Cypher", image, "CYPHER", menu=pystray.Menu(
        pystray.MenuItem("Show Dashboard", on_show),
        pystray.MenuItem("Exit", on_exit)
    ))

    threading.Thread(target=icon.run, daemon=True).start()
