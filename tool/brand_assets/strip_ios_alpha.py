"""Second step after render_icons_test.dart: App Store Connect rejects app
icons with an alpha channel, even fully opaque ones. Run from mobile/:

    python tool/brand_assets/strip_ios_alpha.py
"""
import glob

from PIL import Image

for path in glob.glob("ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png"):
    image = Image.open(path)
    if image.mode == "RGBA":
        assert image.getextrema()[3][0] == 255, f"{path} has transparent pixels"
        image.convert("RGB").save(path, optimize=True)
