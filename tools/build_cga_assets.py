#!/usr/bin/env python3
"""Generate v0.11 8086-compatible CGA 2bpp art (16x12 tiles).

Each pixel: 0 black, 1 cyan, 2 magenta, 3 white in CGA mode 4 palette 1.
The original tank/level art is kept in this file as ASCII source.
"""
from pathlib import Path
import argparse

ROOT = Path(__file__).resolve().parents[1]
WIDTH, HEIGHT = 16, 12

def sprite(*rows):
    assert len(rows) == HEIGHT
    for row in rows:
        assert len(row) == WIDTH, (len(row), row)
        assert set(row) <= set('.0123'), row
    return rows

EMPTY = sprite(*(['.'*16] * 12))
# Detailed, purely original pixel art, designed for the real four-colour CGA
# RGBI palette. Every texture is exactly 16x12, without source ROM assets.
# Material hierarchy: clean silhouette / medium details / sparing highlights.
# Favor 2-4 pixel clusters instead of dithering and isolated checkerboard noise.
def brick_tile():
    """Three staggered courses; never use green/cyan highlights on red bricks."""
    g=[['2']*16 for _ in range(12)]
    for y in range(12):
        course=y//4
        offset=4 if course%2 else 0
        for x in range(16):
            joint=(x-offset)%8
            if y%4==3 or joint==0:
                g[y][x]='.'        # deep mortar; outline survives palette swap
            elif y%4==0 and 2<=joint<=5:
                g[y][x]='3'        # a SINGLE continuous light edge
    return sprite(*(''.join(row) for row in g))
BRICK=brick_tile()

def steel_tile():
    """Riveted, recessed steel plate, not two green 'eyes'."""
    g=[['1']*16 for _ in range(12)]
    for y in range(12):
        for x in range(16):
            if x in (0,15) or y in (0,11): g[y][x]='3'
            elif x in (1,14) or y in (1,10): g[y][x]='.'
            elif x in (2,13) or y in (2,9): g[y][x]='3'
            else: g[y][x]='1'
    for x,y in ((4,4),(11,4),(4,7),(11,7)):
        g[y][x]='.'                  # four fixed recessed rivets
    for x in range(6,10):
        g[5][x]='3'
        g[6][x]='3'
    return sprite(*(''.join(row) for row in g))
STEEL=steel_tile()

# v0.18: compact, independent color-cluster motifs after inspecting
# original late-80s CGA/MSX/NES compositional principles. No ROM pixels copied.
# Water: just two sparse undulating lines instead of three thick jagged bands.
WATER=sprite(
 '................',
 '..11......11....',
 '.1111....1111...',
 '11..11..11..11..',
 '......11......11',
 '................',
 '................',
 '....11......11..',
 '...1111....1111.',
 '..11..11..11..11',
 '11......11......',
 '................')

# Forest: paired evergreen SILHOUETTES, not round blobs / cyan rings.
FOREST=sprite(
 '....1.......1...',
 '...111.....111..',
 '..11111...11111.',
 '....1.......1...',
 '...111.....111..',
 '..11111...11111.',
 '.1111111.1111111',
 '....3.......3...',
 '....3.......3...',
 '................',
 '................',
 '................')

# Ice: clean solid sheet with two asymmetrical faceted white glints.
ICE=sprite(
 '3333333333333333',
 '3111111111111113',
 '3111133311111113',
 '3111333331111113',
 '3113333111111113',
 '3133311111111113',
 '3111111111111113',
 '3111111111133113',
 '3111111111333313',
 '3111111113333113',
 '3111111111111113',
 '3333333333333333')

# Each wall tracks four independent quadrants. Fourteen intermediate shapes
# deliberately preserve the brick texture of the original *project* artwork.
def brick_mask_sprite(mask):
    rows = []
    for y, row in enumerate(BRICK):
        out = ''.join(p if mask & (1 << ((0 if y < 6 else 2) + (0 if x < 8 else 1)))
                      else '.' for x, p in enumerate(row))
        rows.append(out)
    return sprite(*rows)

# New assets drawn as original pixel glyphs, not copied from the NES ROM.
BONUS_LETTERS = {
    # Eight-column symbols at 7x6, readable as icons at native CGA size.
    # Each icon has an intentionally different silhouette.
    'star':    ('...3...', '.3.3.3.', '..333..', '3333333', '..333..', '.3...3.'),
    'helmet':  ('..333..', '.33333.', '33...33', '3333333', '3.3.3.3', '.......'),
    'grenade': ('..333..', '.33333.', '3333333', '33.3.33', '.33333.', '..3.3..'),
    'shovel':  ('3333333', '...3...', '...3...', '...3...', '..333..', '..333..'),
    'clock':   ('..333..', '.3...3.', '3..3..3', '3..33.3', '.3...3.', '..333..'),
    'life':    ('.33.33.', '3333333', '3333333', '.33333.', '..333..', '...3...'),
    'laser':   ('...3...', '...3...', '.33333.', '3333333', '..333..', '...3...'),
    'ally':    ('3.3.3.3', '3333333', '.33333.', '33.3.33', '3333333', '3.3.3.3'),
    'triple':  ('3.3.3.3', '3.3.3.3', '.3.3.3.', '.3.3.3.', '3.3.3.3', '3.3.3.3'),
    'homing':  ('.33333.', '3.....3', '3.333.3', '3.3.3.3', '3.333.3', '.33333.'),
    'frenzy':  ('3..3..3', '.3.3.3.', '..333..', '3333333', '.3...3.', '3.....3'),
    'pong':    ('..333..', '.3...3.', '3.....3', '3.....3', '.3...3.', '..333..'),
    'quad':    ('...3...', '...3...', '3333333', '...3...', '...3...', '...3...'),
    'super':   ('3.3.3.3', '.33333.', '3333333', '3333333', '.33333.', '3.3.3.3'),
}
def bonus_sprite(kind):
    # Clean white square border and a 7x6 centered high-contrast pictogram.
    g=[['.']*16 for _ in range(12)]
    for y in range(1,11):
        for x in range(2,13):
            if x in (2,12) or y in (1,10):g[y][x]='3'
    glyph=BONUS_LETTERS[kind]
    occupied=[(x,y) for y,row in enumerate(glyph) for x,ch in enumerate(row) if ch!='.']
    minx=min(x for x,y in occupied);maxx=max(x for x,y in occupied)
    miny=min(y for x,y in occupied);maxy=max(y for x,y in occupied)
    x0=(15-minx-maxx)//2
    y0=(11-miny-maxy)//2
    for x,y in occupied:
        g[y+y0][x+x0]='3'
    return sprite(*(''.join(row) for row in g))

# Transparent masked overlay that erases only the WHITE perimeter. Pixel
# value '0' is opaque CGA black; '.' stays transparent, so bonus glyphs
# remain on screen while the border blinks during its final 27 ticks.
def bonus_frame_erase():
    rows=[]
    for y in range(12):
        rows.append(''.join('0' if 1<=y<=10 and 2<=x<=12 and
                         (x in (2,12) or y in (1,10)) else '.'
                         for x in range(16)))
    return sprite(*rows)
BONUS_FRAME_ERASE=bonus_frame_erase()

BASE = sprite(
 '................', '.....333333.....', '....31111113....',
 '...3123333213...', '..312333333213..', '..312332233213..',
 '..312332233213..', '..312333333213..', '...3123333213...',
 '....31111113....', '.....333333.....', '................')

# Hand-authored geometry rather than recolored copies. Readable at native
# 320x200, not merely when enlarged: two tracks, a distinct turret, a muzzle.
def tank_up_geometry(kind='player'):
    """Hand-tuned 12x12 tank silhouettes. Readable as silhouettes at 1:1.

    Common language: connected tracks, front-facing long gun, large turret,
    broad chassis. Type, not noisy recolouring, controls each footprint.
    """
    body, highlight, turret = {
        'player': ('3','1','3'),
        'basic':  ('2','3','3'),
        'fast':   ('2','3','1'),
        'power':  ('2','3','3'),
        'armor':  ('3','2','1'),
    }[kind]
    g=[['.']*12 for _ in range(12)]
    def paint(y,x0,x1,c):
        if 0<=y<12:
            for x in range(max(0,x0),min(12,x1+1)):g[y][x]=c
    track=(0,1,10,11) if kind=='armor' else (1,2,9,10)
    for y in range(2,11):
        for x in track:g[y][x]=body
    # Strong paired track silhouettes: treads remain recognizable in all palettes.
    for y in (2,5,8,10):
        for x in track:g[y][x]=highlight
    # Centered chassis bridges tracks at two structural cross-members.
    for y in range(4,11):paint(y,4,7,body)
    # Black channels separate left/right tracks from the center chassis.
    for y in (4,10):paint(y,2,9,body)
    # Fixed, opaque roof and a distinct round/square turret, not random dots.
    for y in (5,6,7):paint(y,4,7,turret)
    paint(5,5,6,highlight)
    paint(7,5,6,body)
    # Long centered cannon makes heading instantly visible.
    for y in range(0,5):paint(y,5,6,turret)
    # Class-specific outline, no frame-by-frame palette differences.
    if kind=='player':
        paint(8,4,7,highlight)
        paint(9,3,8,body)
        paint(9,5,6,turret)
    elif kind=='basic':
        paint(8,5,6,highlight)
        paint(10,2,3,'.')
        paint(10,8,9,'.')
    elif kind=='fast':
        # Longer needle gun and narrower body: light scout.
        paint(0,5,5,highlight)
        for y in (7,9):g[y][3]=g[y][8]='.'
        paint(8,5,6,highlight)
    elif kind=='power':
        # Wide barrel and squared-off shoulder armor.
        paint(1,4,7,turret)
        for y in (4,8):
            g[y][3]=g[y][8]=highlight
        paint(9,4,7,highlight)
    else:
        # Wide armored tank; broad rectangular turret and thickened shoulders.
        paint(4,2,9,highlight)
        for y in range(5,9):
            g[y][3]=g[y][8]=highlight
        paint(8,4,7,turret)
    return sprite(*('..'+''.join(row)+'..' for row in g))

TANK_UP=tank_up_geometry('player')

def rotate_grid(g):
    n=len(g)
    assert all(len(row)==n for row in g)
    return [[g[n-1-x][y] for x in range(n)] for y in range(n)]
def padded(g):return sprite(*('..'+''.join(r)+'..' for r in g))
def directions(up):
    core=[list(row[2:14]) for row in up]
    right=rotate_grid(core)
    down=rotate_grid(right)
    left=rotate_grid(down)
    return up,padded(right),padded(down),padded(left)

TANK_UP,TANK_RIGHT,TANK_DOWN,TANK_LEFT=directions(TANK_UP)
ENEMY_UP,ENEMY_RIGHT,ENEMY,ENEMY_LEFT=directions(tank_up_geometry('basic'))
FAST_UP,FAST_RIGHT,FAST_DOWN,FAST_LEFT=directions(tank_up_geometry('fast'))
POWER_UP,POWER_RIGHT,POWER_DOWN,POWER_LEFT=directions(tank_up_geometry('power'))
ARMOR_UP,ARMOR_RIGHT,ARMOR_DOWN,ARMOR_LEFT=directions(tank_up_geometry('armor'))

# v0.29 user-approved 16x12 cyan P1, one canonical RIGHT master.
# Import before constructing SPRITES, including its shielded P1 versions.
from approved_art_v029 import player_sprites
TANK_UP,TANK_RIGHT,TANK_DOWN,TANK_LEFT = player_sprites()

def track_overlay(direction,phase):
    """Two synchronized travelling bars per track, not white pixel confetti."""
    core=[['.']*12 for _ in range(12)]
    for y in range(2,11):
        if (y+phase*2)%4 in (0,1):
            for x in (1,10):core[y][x]='3'
    for _ in range(direction):core=rotate_grid(core)
    return padded(core)
TRACK_SPRITES={f'tread_{d}_{phase}':track_overlay(d,phase)
               for d in range(4) for phase in range(2)}

def explosion_sprite(frame):
    # Controlled four-frame animation: impact, expanding fire, shrapnel,
    # dissipating smoke. Chunky connected clusters, not random dither.
    g=[['.']*16 for _ in range(12)]
    if frame==0:
        groups=[(6,4,4,4,'3'),(5,5,6,2,'2')]
    elif frame==1:
        groups=[(6,2,4,8,'2'),(3,4,10,4,'3'),(5,4,6,4,'1')]
    elif frame==2:
        groups=[(6,3,4,5,'1'),(3,3,2,2,'3'),(12,2,2,2,'2'),(3,8,2,2,'2'),(11,9,2,2,'3')]
    else:
        groups=[(4,3,2,2,'1'),(12,3,2,2,'1'),(3,8,2,2,'3'),(11,8,2,2,'1')]
    for x,y,w,h,c in groups:
        for yy in range(y,min(12,y+h)):
            for xx in range(x,min(16,x+w)):
                g[yy][xx]=c
    return sprite(*(''.join(row) for row in g))
EXPLOSIONS={f'explosion_{i}':explosion_sprite(i) for i in range(4)}

def shield_sprite(art):
    """Complete symmetric protective bubble outside tank. Never overwrite tank."""
    g=[list(row) for row in art]
    halo=[]
    for x in range(1,15):halo.extend([(x,0),(x,11)])
    for y in range(1,11):halo.extend([(0,y),(15,y)])
    halo.extend([(1,1),(14,1),(1,10),(14,10)])
    for x,y in halo:
        if g[y][x]=='.':g[y][x]='3'
    return sprite(*(''.join(row) for row in g))

ENEMY_BULLET = sprite(
 *(['.'*16] * 4),
 '.......22.......', '......2222......', '......2222......',
 '.......22.......', *(['.'*16] * 4))
BULLET = sprite(
 *(['.'*16] * 4),
 '.......33.......', '......3333......', '......3333......',
 '.......33.......', *(['.'*16] * 4))

SPRITES = {
    'shield_outline': shield_sprite(EMPTY),
    'empty': EMPTY,
    'brick': BRICK,
    'steel': STEEL,
    'water': WATER,
    'forest': FOREST,
    'ice': ICE,
    'base': BASE,
    'player_up': TANK_UP,
    'player_right': TANK_RIGHT,
    'player_down': TANK_DOWN,
    'player_left': TANK_LEFT,
    'player_shield_up': shield_sprite(TANK_UP),
    'player_shield_right': shield_sprite(TANK_RIGHT),
    'player_shield_down': shield_sprite(TANK_DOWN),
    'player_shield_left': shield_sprite(TANK_LEFT),
    'enemy': ENEMY,
    'enemy_up': ENEMY_UP,
    'enemy_right': ENEMY_RIGHT,
    'enemy_left': ENEMY_LEFT,
    'fast_up': FAST_UP,
    'fast_right': FAST_RIGHT,
    'fast_down': FAST_DOWN,
    'fast_left': FAST_LEFT,
    'power_up': POWER_UP,
    'power_right': POWER_RIGHT,
    'power_down': POWER_DOWN,
    'power_left': POWER_LEFT,
    'armor_up': ARMOR_UP,
    'armor_right': ARMOR_RIGHT,
    'armor_down': ARMOR_DOWN,
    'armor_left': ARMOR_LEFT,
    'bullet': BULLET,
    'enemy_bullet': ENEMY_BULLET,
    **{'brick_mask_'+str(i): brick_mask_sprite(i) for i in range(16)},
    **{'bonus_'+kind: bonus_sprite(kind) for kind in BONUS_LETTERS},
    'bonus_frame_erase': BONUS_FRAME_ERASE,
    **TRACK_SPRITES,
    **EXPLOSIONS,
}


def pack(rows):
    output = []
    for row in rows:
        for i in range(0, WIDTH, 4):
            pixels = row[i:i+4]
            value = 0
            for p in pixels:
                value = (value << 2) | (0 if p == '.' else int(p))
            output.append(value)
    assert len(output) == 48
    return output


# Each moving sprite has four one-pixel horizontal variants. Each row packs
# five mask bytes followed by five color bytes; zero pixels are transparent.
# This makes arbitrary-pixel CGA compositing fast enough to test on an 8088
# without allocating a 16 KB off-screen framebuffer. 4*12*10=480 bytes.
# v0.28: ONE native-resolution 32x24 original top-view twin-engine plane.
# 8086 packs each orientation as 24*16 bytes, unchanged from v0.27.
# All four directions are mathematical turns/mirrors of THIS master.
# 2bpp transparent original art: swept wings, twin nacelles, glazed
# cockpit, rudder, tailplane and discrete visible propeller hubs.
def plane_sprite(*rows):
    assert len(rows) == 24
    assert all(len(row) == 32 and set(row) <= set('.0123') for row in rows)
    return rows

PLANE_V = plane_sprite(
 '...............22...............',
 '..............2222..............',
 '........2.....1331.....2........',
 '.......333....1331....333.......',
 '......21112...1331...21112......',
 '......13331...1331...13331......',
 '......13331...1111...13331......',
 '......13331...3113...13331......',
 '......13321.11311311.13321......',
 '......11121111111111111121......',
 '.....1111213311111133111211.....',
 '.113331112131112211131112133311.',
 '11111111121111122111111121111111',
 '22211111111111111111111111111222',
 '..2221111111111111111111111222..',
 '.....2211121111111111211122.....',
 '.........11111111111111.........',
 '..............1111..............',
 '..............1111..............',
 '............11133111............',
 '.........13333111133331.........',
 '..........221111111122..........',
 '.............111111.............',
 '...............22...............')
PLANE_V_DOWN = plane_sprite(*(row[::-1] for row in reversed(PLANE_V)))
def plane_turn_right(rows):
    # Rotate around the sprite centre then resample to the same 32x24
    # viewport; no separately painted directional variants.
    return plane_sprite(*(
        ''.join(rows[23 - x*24//32][y*32//24] for x in range(32))
        for y in range(24)
    ))
PLANE_H = plane_turn_right(PLANE_V)
PLANE_H_LEFT = plane_sprite(*(row[::-1] for row in PLANE_H))
# v0.29 user's chosen WWII twin-engine airplane from the screenshot,
# native 32x24, pre-rotated at BUILD TIME from ONE right-facing master.
from approved_art_v029 import plane_sprites
PLANE_V,PLANE_H,PLANE_V_DOWN,PLANE_H_LEFT = plane_sprites()
SPRITES['plane_horizontal'] = PLANE_H
SPRITES['plane_horizontal_left'] = PLANE_H_LEFT
SPRITES['plane_vertical'] = PLANE_V
SPRITES['plane_vertical_down'] = PLANE_V_DOWN
WIDE_PLANES = ('plane_horizontal','plane_horizontal_left','plane_vertical','plane_vertical_down')
def pack_wide_plane(rows):
    """32x24, 8 mask + 8 color bytes per scanline, 384 B/direction."""
    expanded=list(rows)  # genuine 32x24 master; no 2x block scaling
    assert len(expanded)==24 and all(len(row)==32 for row in expanded)
    out=[]
    for row in expanded:
        mask=[]; color=[]
        for x in range(0,32,4):
            mm=0; cc=0
            for pixel in row[x:x+4]:
                cc=(cc<<2)|(0 if pixel=='.' else int(pixel))
                mm=(mm<<2)|(0 if pixel=='.' else 3)
            mask.append(mm); color.append(cc)
        out.extend(mask+color)
    assert len(out)==384
    return out

SMOOTH_SPRITES = [

    'player_up','player_right','player_down','player_left',
    'enemy_up','enemy_right','enemy','enemy_left',
    'fast_up','fast_right','fast_down','fast_left',
    'power_up','power_right','power_down','power_left',
    'armor_up','armor_right','armor_down','armor_left',
    'bullet','enemy_bullet',
    'bonus_star','bonus_helmet','bonus_grenade','bonus_shovel','bonus_clock','bonus_life',
    'bonus_laser','bonus_ally','bonus_triple','bonus_homing','bonus_frenzy',
    'bonus_frame_erase','bonus_pong','bonus_quad','bonus_super','shield_outline',
    *EXPLOSIONS.keys(),
]

def pack_smooth(rows):
    result=[]
    for phase in range(4):
        for row in rows:
            pixels=['.']*phase+list(row)+['.']*(4-phase)
            assert len(pixels)==20
            color=[]
            mask=[]
            for i in range(0,20,4):
                value=0
                cover=0
                for ch in pixels[i:i+4]:
                    value=(value<<2)|(0 if ch=='.' else int(ch))
                    cover=(cover<<2)|(0 if ch=='.' else 3)
                color.append(value)
                mask.append(cover)
            result.extend(mask+color)
    assert len(result)==480
    return result

def get_map(map_path):
    rows = [line.strip() for line in map_path.read_text(encoding='ascii').splitlines() if line.strip()]
    assert len(rows) == 16 and all(len(x) == 16 for x in rows)
    assert set(''.join(rows)) <= set('.#~TEPBFI')
    assert ''.join(rows).count('P') == 1
    assert ''.join(rows).count('B') == 1
    assert ''.join(rows).count('E') >= 1
    return rows



# Tiny 8x8 black-on-white HUD font and badges, packed CGA mode 4 (2 bits/pixel).
# No BIOS text is used on the grey/white sidebar: glyph backgrounds must remain white.
HUD_FONT = {
 '0': ('.###.', '#...#', '#..##', '#.#.#', '##..#', '#...#', '.###.'),
 '1': ('..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.'),
 '2': ('.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'),
 '3': ('####.', '....#', '....#', '.###.', '....#', '....#', '####.'),
 '4': ('...#.', '..##.', '.#.#.', '#..#.', '#####', '...#.', '...#.'),
 '5': ('#####', '#....', '#....', '####.', '....#', '....#', '####.'),
 '6': ('.###.', '#....', '#....', '####.', '#...#', '#...#', '.###.'),
 '7': ('#####', '....#', '...#.', '..#..', '.#...', '.#...', '.#...'),
 '8': ('.###.', '#...#', '#...#', '.###.', '#...#', '#...#', '.###.'),
 '9': ('.###.', '#...#', '#...#', '.####', '....#', '....#', '.###.'),
 'p': ('####.', '#...#', '#...#', '####.', '#....', '#....', '#....'),
 'x': ('.....', '.....', '#...#', '.#.#.', '..#..', '.#.#.', '#...#'),
 's': ('.####', '#....', '#....', '.###.', '....#', '....#', '####.'),
 'a': ('.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'),
 'u': ('#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'),
 't': ('#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'),
 'o': ('.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'),
 'm': ('#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'),
 'n': ('#...#', '##..#', '##..#', '#.#.#', '#..##', '#..##', '#...#'),
 'b': ('####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'),
 'k': ('#...#', '#..#.', '#.#..', '##...', '#.#..', '#..#.', '#...#'),
 'i': ('#####', '..#..', '..#..', '..#..', '..#..', '..#..', '#####'),
 'c': ('.###.', '#...#', '#....', '#....', '#....', '#...#', '.###.'),
 'v': ('#...#', '#...#', '#...#', '#...#', '#...#', '.#.#.', '..#..'),
 'r': ('####.', '#...#', '#...#', '####.', '#.#..', '#..#.', '#...#'),
 '.': ('.....', '.....', '.....', '.....', '.....', '.##..', '.##..'),
 '-': ('.....', '.....', '.....', '#####', '.....', '.....', '.....'),
}
HUD_TANK = (
 '...##...', '.######.', '###..###', '########',
 '###..###', '###..###', '.######.', '...##...',
)
HUD_FLAG = (
 '..#.....', '..#####.', '..#####.', '..####..',
 '..#.....', '..#.....', '.###....', '........',
)

def hud_glyph(rows):
    """Each '#' is black (CGA index 0), '.' is white (index 3)."""
    assert len(rows) == 8 and all(len(r) == 8 and set(r) <= {'#', '.'} for r in rows)
    data = []
    for row in rows:
        for i in (0,4):
            n=0
            for px in row[i:i+4]:
                n = (n << 2) | (0 if px=='#' else 3)
            data.append(n)
    assert len(data) == 16
    return data


def hud_font_glyph(ch):
    shape = HUD_FONT[ch]
    assert len(shape) == 7 and all(len(row)==5 for row in shape)
    return hud_glyph(tuple('.' + row + '..' for row in shape) + ('........',))


def generate_hud():
    lines = [
        '/* HUD CGA 8x8 glyphs, generated from original pixel-font patterns. */',
        'hud_indicator_offsets:',
        '    .word ' + ', '.join(str(225 + 480 * i) for i in range(5)),
        'hud_digit_ptrs:',
        '    .word ' + ', '.join('hud_digit_' + str(i) for i in range(10)),
    ]
    data = {
        'hud_blank_icon': hud_glyph(('........',)*8),
        'hud_tank_icon': hud_glyph(HUD_TANK),
        'hud_flag_icon': hud_glyph(HUD_FLAG),
        'hud_star_icon': hud_glyph(('...##...', '#.####.#', '.######.', '########', '########', '.######.', '#.####.#', '...##...')),
        'hud_p_char': hud_font_glyph('p'),
        'hud_x_char': hud_font_glyph('x'),
        'hud_s_char': hud_font_glyph('s'),
        'hud_a_char': hud_font_glyph('a'),
        'hud_u_char': hud_font_glyph('u'),
        'hud_t_char': hud_font_glyph('t'),
        'hud_o_char': hud_font_glyph('o'),
        'hud_m_char': hud_font_glyph('m'),
        'hud_n_char': hud_font_glyph('n'),
        'hud_b_char': hud_font_glyph('b'),
        'hud_r_char': hud_font_glyph('r'),
        'hud_dash_char': hud_font_glyph('-'),
        'hud_k_char': hud_font_glyph('k'),
        'hud_i_char': hud_font_glyph('i'),
        'hud_c_char': hud_font_glyph('c'),
        'hud_v_char': hud_font_glyph('v'),
        'hud_dot_char': hud_font_glyph('.'),
        'hud_copyright_icon': hud_glyph((
            '..####..', '.#....#.', '#..##..#', '#.#....#',
            '#.#....#', '#..##..#', '.#....#.', '..####..')),
    }
    for digit in range(10):
        data['hud_digit_'+str(digit)] = hud_font_glyph(str(digit))
    for name, bytes_ in data.items():
        lines.append(name + ':')
        lines.append('    .byte ' + ', '.join(f'0x{x:02x}' for x in bytes_))
    return lines

MAP_NIBBLES = '.#~TEPBFI'

def packed_map(rows):
    # One 4-bit material code per tile, left tile in low nibble.
    data=[]
    for row in rows:
        for x in range(0,16,2):
            data.append(MAP_NIBBLES.index(row[x]) | (MAP_NIBBLES.index(row[x+1]) << 4))
    assert len(data)==128
    return data

def compressed_map(rows):
    """8088-friendly 1-byte runs: count (1..16) in high nibble, material low."""
    cells=''.join(rows)
    data=[]
    i=0
    while i<len(cells):
        end=i+1
        while end<len(cells) and end-i<16 and cells[end]==cells[i]:
            end+=1
        data.append(((end-i-1)<<4)|MAP_NIBBLES.index(cells[i]))
        i=end
    assert sum((x>>4)+1 for x in data)==256
    return data

def emit_packed_map(lines, rows):
    data=compressed_map(rows)
    for pos in range(0,len(data),8):
        lines.append('    .byte ' + ', '.join(f'0x{n:02x}' for n in data[pos:pos+8]))

def generate(map_path):
    lines = [
        '/* GENERATED by tools/build_cga_assets.py. Do not hand-edit. */',
        '.section .data',
        '.p2align 1',
        'brick_sprite_ptrs:',
        '    .word ' + ', '.join('sprite_brick_mask_'+str(i) for i in range(16)),
        'tile_row_offsets:',
        '    .word ' + ', '.join(str(480*i) for i in range(16)),
        'level_template:',
    ]
    rows = get_map(map_path)
    emit_packed_map(lines, rows)
    lines.append('level_end:')
    lines.append('    .if (level_end - level_template) > 128')
    lines.append('    .error "RLE level exceeds original packed size"')
    lines.append('    .endif')
    for stage in range(2, 36):
        staged = get_map(ROOT / 'assets' / 'maps' / f'level{stage:02}.map')
        lines.append(f'level{stage}_template:')
        emit_packed_map(lines, staged)
    lines.append('stage_ptrs:')
    lines.append('    .word ' + ', '.join(
        'level_template' if i == 1 else f'level{i}_template'
        for i in range(1,36)))
    # Keep only the true opaque tile atlas. The legacy sprite table and
    # old tank, bullet and bonus opaque copies were never referenced by
    # the masked smooth renderer; retain one star used by DOS smoke.
    static_names = ["empty", "steel", "water", "forest", "ice", "base",
                    "bonus_star"] + [f"brick_mask_{i}" for i in range(16)]
    for name in static_names:
        rows=SPRITES[name]
        lines.append('sprite_' + name + ':')
        data = pack(rows)
        for i in range(0, len(data), 12):
            lines.append('    .byte ' + ', '.join(f'0x{x:02x}' for x in data[i:i+12]))
    lines.extend(generate_hud())
    # Append the separate masked-blit atlas after the opaque tiled graphics.
    lines.append('    .p2align 1')
    # Ship four compact scaled CGA aircraft frames instead of 480B sprites.
    for name in WIDE_PLANES:
        lines.append('wide_' + name + ':')
        data=pack_wide_plane(SPRITES[name])
        for i in range(0,len(data),16):
            lines.append('    .byte ' + ', '.join(f'0x{x:02x}' for x in data[i:i+16]))
    for name in SMOOTH_SPRITES:
        lines.append('smooth_' + name + ':')
        data=pack_smooth(SPRITES[name])
        for i in range(0,len(data),20):
            lines.append('    .byte ' + ', '.join(f'0x{x:02x}' for x in data[i:i+20]))
    return '\n'.join(lines) + '\n' 


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()
    path = ROOT / 'src' / 'dos' / 'cga_assets.inc'
    generated = generate(ROOT / 'assets' / 'maps' / 'level01.map')
    if args.check:
        assert path.read_text(encoding='ascii') == generated, 'generated assets are stale'
        print('CGA assets match source map and artwork')
    else:
        path.write_text(generated, encoding='ascii')
        print(f'generated {path} ({len(SPRITES)} sprites x 48 bytes)')

if __name__ == '__main__':
    main()
