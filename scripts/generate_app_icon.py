from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[1]
source_path = root / "logo.png"
destination = root / "UcapHutang/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

source = Image.open(source_path).convert("RGBA")
canvas = Image.new("RGBA", source.size, (30, 92, 188, 255))
canvas.alpha_composite(source)
icon = canvas.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
icon.save(destination, format="PNG", optimize=True)

print(destination)
