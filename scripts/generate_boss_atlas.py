"""Paint a small original, hand-composed raster atlas for the prototype boss."""
from PIL import Image, ImageDraw, ImageFilter
import math, random
from pathlib import Path

SIZE = 512
OUT = Path(__file__).resolve().parents[1] / "assets" / "boss" / "ritual_briar_atlas.png"
OUT.parent.mkdir(parents=True, exist_ok=True)
atlas = Image.new("RGBA", (SIZE * 4, SIZE * 3), (0, 0, 0, 0))

def frame(row, col):
    im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    phase = col / 3
    seed = row * 23 + col * 5
    rng = random.Random(seed)
    sway = [-8, -3, 4, 9][col] if row == 0 else 0
    # Loose root skirt and tendrils.
    for i in range(11):
        x = 256 + sway + (i - 5) * 26
        y = 382 + rng.randint(-9, 10)
        bend = rng.randint(-28, 28)
        d.line([(x, y), (x + bend, 438), (x + bend * 1.4, 474)], fill=(49, 31, 24, 255), width=rng.randint(12, 23), joint="curve")
        d.line([(x, y + 3), (x + bend, 438)], fill=(102, 58, 37, 180), width=4)
    # Main trunk, layered organic planes.
    d.polygon([(179+sway,385),(148+sway,315),(167+sway,245),(183+sway,185),(214+sway,129),(251+sway,112),(292+sway,131),(330+sway,185),(349+sway,255),(362+sway,329),(326+sway,393)], fill=(47,31,27,255))
    d.polygon([(190+sway,345),(177+sway,275),(198+sway,201),(225+sway,151),(254+sway,139),(271+sway,178),(259+sway,251),(277+sway,333),(249+sway,382)], fill=(103,61,40,255))
    d.polygon([(271+sway,177),(307+sway,147),(329+sway,201),(343+sway,276),(325+sway,356),(287+sway,379),(300+sway,294)], fill=(65,42,34,255))
    # crown branches and thorn spurs
    for side in (-1,1):
        pts=[(256+sway+side*43,180),(256+sway+side*70,115),(256+sway+side*104,85),(256+sway+side*126,39)]
        d.line(pts, fill=(51,34,28,255), width=20, joint="curve")
        d.line([(x-side*4,y) for x,y in pts], fill=(125,75,45,210), width=4, joint="curve")
        d.polygon([(256+sway+side*124,42),(256+sway+side*141,3),(256+sway+side*111,30)], fill=(38,28,25,255))
        for j in range(3):
            x=256+sway+side*(70+j*21); y=195+j*31
            d.polygon([(x,y),(x+side*36,y-38),(x+side*15,y+15)], fill=(43,30,27,255))
    # Maw: opening grows during telegraph; closes as it staggers.
    openness = (0.22 + 0.13*col) if row == 1 else (0.55 if row == 0 else max(0.12,0.5-0.12*col))
    mouth_y=225
    d.ellipse((199+sway,mouth_y-42*openness,315+sway,mouth_y+75*openness), fill=(22,14,17,255), outline=(33,21,20,255), width=8)
    d.arc((202+sway,mouth_y-40*openness,312+sway,mouth_y+68*openness), 190, 350, fill=(170,101,52,255), width=9)
    for j in range(5):
        tx=214+sway+j*19
        d.polygon([(tx,mouth_y-11),(tx+8,mouth_y+15),(tx+15,mouth_y-10)], fill=(217,185,127,255))
    # Eyes with warm sickly glow.
    glow=Image.new("RGBA",im.size,(0,0,0,0)); gd=ImageDraw.Draw(glow)
    eye_y=183 if row != 1 else 171
    for x in (218+sway,294+sway):
        gd.ellipse((x-24,eye_y-23,x+24,eye_y+23),fill=(197,137,35,120))
    glow=glow.filter(ImageFilter.GaussianBlur(17)); im=Image.alpha_composite(im,glow); d=ImageDraw.Draw(im,"RGBA")
    for x in (218+sway,294+sway):
        d.ellipse((x-12,eye_y-8,x+12,eye_y+9), fill=(217,180,71,255))
        d.ellipse((x-3,eye_y-8,x+3,eye_y+9), fill=(18,13,15,255))
    # Bark streaks and scars.
    for i in range(26):
        x=rng.randint(183,337)+sway; y=rng.randint(213,373)
        d.line((x,y,x+rng.randint(-7,7),y+rng.randint(8,25)), fill=(151,95,57,rng.randint(75,160)), width=rng.randint(1,4))
    if row == 2 and col >= 2:
        d.ellipse((175,170,337,350), fill=(16,12,17,85))
        for i in range(18):
            x=rng.randint(150,365); y=rng.randint(370,485)
            d.ellipse((x,y,x+5,y+5), fill=(169,136,76,rng.randint(50,180)))
    atlas.alpha_composite(im, (col*SIZE,row*SIZE))

for r in range(3):
    for c in range(4): frame(r,c)
atlas.save(OUT)
print(OUT)
