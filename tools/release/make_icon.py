"""Draws resources/icon/doxypas.ico (a "{*}" doc-comment mark on a blue tile). Needs Pillow; run once, the .ico is committed."""
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'resources', 'icon', 'doxypas.ico')
S = 512
img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle((16, 16, S - 16, S - 16), radius=96, fill=(32, 64, 128, 255))
d.rounded_rectangle((16, 16, S - 16, S // 2), radius=96, fill=(48, 88, 160, 255))
d.rectangle((16, S // 4, S - 16, S // 2), fill=(48, 88, 160, 255))
font = ImageFont.truetype(r'C:\Windows\Fonts\consolab.ttf', 250)
text = '{*}'
w = d.textlength(text, font=font)
d.text(((S - w) / 2, 120), text, font=font, fill=(255, 255, 255, 255))
d.rectangle((120, 410, S - 120, 430), fill=(255, 196, 64, 255))
img.save(OUT, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)], bitmap_format='bmp')  # BMP entries: brcc32 cannot read PNG-compressed icons
