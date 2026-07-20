import sys
import re

def strings(filename, min=4):
    with open(filename, "rb") as f:
        result = ""
        for b in f.read():
            c = chr(b)
            if c.isprintable():
                result += c
            else:
                if len(result) >= min:
                    yield result
                result = ""
        if len(result) >= min:
            yield result

fname = "game/art/anims/AnimationLibrary_Godot.glb"
print(f"Scanning {fname} for strings...")
try:
    found = 0
    for s in strings(fname):
        # Filter for likely animation names (heuristic)
        # e.g. "Armature|Walk", "Run", etc.
        # Or standard GLTF JSON keys might appear if it's GLB (the JSON chunk is readable)
        if "animation" in s.lower() or "armature" in s.lower() or "mixamo" in s.lower():
            print(s)
            found += 1
    print(f"Done. Found {found} lines of interest.")
except Exception as e:
    print(e)
