"""Chemin de l'executable Godot : env GODOT, sinon l'install Windows habituelle, sinon `godot` du PATH."""
import os

WIN_DEFAULT = "C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"


def godot_exe() -> str:
    if os.environ.get("GODOT"):
        return os.environ["GODOT"]
    return WIN_DEFAULT if os.name == "nt" and os.path.exists(WIN_DEFAULT) else "godot"
