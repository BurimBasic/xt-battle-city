#!/usr/bin/env python3
"""Generate 8086-compatible CGA 2bpp tiles, 16x12 pixels (four bytes/row).

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
        assert set(row) <= set('.123'), row
    return rows

EMPTY = sprite(*(['.'*16] * 12))
# Detailed, purely original pixel art, designed for the real four-colour CGA
# RGBI palette. Every texture is exactly 16x12, without source ROM assets.
BRICK = sprite(
 '2222222222222222', '2332223223222232', '2222222222222222',
 '1111111111111111', '2222222222222222', '2223222232223222',
 '2222222222222222', '1111111111111111', '2222222222222222',
 '2232222322232223', '2222222222222222', '1111111111111111')
STEEL = sprite(
 '3333333333333333', '3111111111111113', '3133333333333313',
 '3131..........13', '3131.333333.1.13', '3131.3....3.1.13',
 '3131.3....3.1.13', '3131.333333.1.13', '3131..........13',
 '3133333333333313', '3111111111111113', '3333333333333333')
WATER = sprite(
 '1111111111111111', '11..1111....1111', '11111...11111111',
 '1111111111111111', '111..1111...1111', '1111111111111111',
 '11...11111....11', '1111111111111111', '11111...11111111',
 '1111111111111111', '11..1111111..111', '1111111111111111')
FOREST = sprite(*tuple(
    ''.join('1' if (x * 17 + y * 13 + (x*y)//3) % 11 < 4 else
            ('3' if (x+2*y) % 17 == 0 else '.')
            for x in range(16)) for y in range(12)))
ICE = sprite(*tuple(
    ''.join('3' if x in (0,15) or y in (0,11) else
            ('1' if (x + y*3) % 9 in (0,1) else
             ('3' if (x*3+y) % 19 == 0 else '.'))
            for x in range(16)) for y in range(12)))

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
    'star': ('.3.3.', '33333', '.333.', '33333', '.333.', '3...3', '.....'),
    'helmet': ('.333.', '3...3', '3...3', '33333', '3...3', '3...3', '.....'),
    'grenade': ('..3..', '.333.', '33333', '.333.', '33333', '.3.3.', '3...3'),
    'shovel': ('33333', '..3..', '..3..', '..3..', '..3..', '.333.', '.333.'),
    'clock': ('.333.', '3...3', '3.3.3', '3.33.', '3...3', '3...3', '.333.'),
    'life': ('..3..', '..3..', '33333', '..3..', '..3..', '.....', '.....'),
}
def bonus_sprite(kind):
    g=[['.']*16 for _ in range(12)]
    for y in range(1, 11):
        for x in range(2, 14):
            if y in (1,10) or x in (2,13):
                g[y][x]='2'
    for y,row in enumerate(BONUS_LETTERS[kind]):
        for x,p in enumerate(row):
            if p != '.':
                g[y+3][x+6] = '3'
    return sprite(*(''.join(row) for row in g))

BASE = sprite(
 '................', '.....333333.....', '....31111113....',
 '...3123333213...', '..312333333213..', '..312332233213..',
 '..312332233213..', '..312333333213..', '...3123333213...',
 '....31111113....', '.....333333.....', '................')

def new_tank_up(body='1',trim='3'):
    """Track, turret, gun, armour plates and rivets in 12x12 pixels."""
    g=[['.']*12 for _ in range(12)]
    for y in range(1,11):
        for x in (0,1,10,11):
            g[y][x] = body if x in (1,10) else trim
        for x in range(3,9):
            g[y][x] = body
    for y in (2,6,9):
        for x in (0,11):g[y][x]=body
    for y in range(3,10):
        g[y][2]=trim;g[y][9]=trim
    for x in range(3,9):
        g[3][x]=trim
        g[9][x]=trim
    for y in range(1,5):g[y][5]=trim;g[y][6]=trim
    for y in range(4,8):
        for x in range(4,8):g[y][x]='2' if y==6 else trim
    for x,y in ((3,5),(8,5),(3,8),(8,8)):
        g[y][x]=trim
    g[0][5]=trim;g[0][6]=trim
    return sprite(*('..'+''.join(row)+'..' for row in g))

TANK_UP = new_tank_up()

def tank_grid():return [list(r[2:14]) for r in TANK_UP]
def rotate_grid(g):
    n=len(g)
    assert all(len(row)==n for row in g)
    return [[g[n-1-x][y] for x in range(n)] for y in range(n)]
def padded(g): return sprite(*('..'+''.join(r)+'..' for r in g))

G_UP=tank_grid()
TANK_RIGHT=padded(rotate_grid(G_UP))
TANK_DOWN=padded(rotate_grid(rotate_grid(G_UP)))
TANK_LEFT=padded(rotate_grid(rotate_grid(rotate_grid(G_UP))))

def track_overlay(direction,phase):
    """Two animated tread phases; directional overlay needs only 8 small sprites."""
    rows=[['.']*12 for _ in range(12)]
    for y in range(1,11):
        if (y+2*phase)%4 < 2:
            for x in (0,11):rows[y][x]='3'
        if (y+2*phase)%5==0:
            rows[y][1]='2';rows[y][10]='2'
    for x in (1,10):
        rows[1][x]='3';rows[10][x]='3'
    g=rows
    for _ in range(direction):g=rotate_grid(g)
    return padded(g)

TRACK_SPRITES={f'tread_{d}_{phase}':track_overlay(d,phase)
               for d in range(4) for phase in range(2)}

def explosion_sprite(frame):
    """Four six-colour-frame shapes suggest fire, smoke, shrapnel movement."""
    g=[['.']*16 for _ in range(12)]
    if frame==0:
        points=[(8,5,3),(7,5,3),(8,6,3),(7,6,3),(6,5,2),(9,6,2)]
    elif frame==1:
        points=[(8,2,3),(8,9,3),(3,5,2),(12,5,2),(5,3,3),(10,3,3),
                (5,8,3),(10,8,3),(7,4,2),(8,5,3),(6,6,2),(9,6,2)]
    elif frame==2:
        points=[(1,2,3),(14,1,2),(2,9,2),(13,10,3),(4,5,2),
                (11,5,2),(6,2,3),(10,8,3),(7,6,1),(9,4,1)]
    else:
        points=[(0,0,2),(15,2,3),(3,11,3),(14,10,2),(5,4,1),
                (10,7,1),(8,0,2)]
    for x,y,c in points:g[y][x]=str(c)
    return sprite(*(''.join(r) for r in g))
EXPLOSIONS={f'explosion_{i}':explosion_sprite(i) for i in range(4)}

# White arc around the player's own original tank pixels during invulnerability.
def shield_sprite(art):
    g = [list(row) for row in art]
    for x in range(2, 14):
        if x not in (2,13):
            g[0][x]='3'
            g[11][x]='3'
    for y in range(2,10):
        g[y][1]='3'
        g[y][14]='3'
    return sprite(*(''.join(row) for row in g))


# Enemy is same geometry but visibly magenta instead of cyan.
ENEMY = sprite(*(row.replace('1', '2').replace('3','1') for row in TANK_DOWN))
EG_DOWN = [list(row[2:14]) for row in ENEMY]
# Four NES-style gameplay classes remain distinguishable on 4-color CGA.
def remap(rows, table):
    return sprite(*(row.translate(str.maketrans(table)) for row in rows))

def four_directions(down):
    core = [list(row[2:14]) for row in down]
    left = padded(rotate_grid(core))
    up = padded(rotate_grid(rotate_grid(core)))
    right = padded(rotate_grid(rotate_grid(rotate_grid(core))))
    return up, right, down, left
FAST_UP, FAST_RIGHT, FAST_DOWN, FAST_LEFT = four_directions(remap(ENEMY, {'2':'3'}))
POWER_UP, POWER_RIGHT, POWER_DOWN, POWER_LEFT = four_directions(remap(ENEMY, {'2':'1', '1':'2'}))
ARMOR_UP, ARMOR_RIGHT, ARMOR_DOWN, ARMOR_LEFT = four_directions(remap(ENEMY, {'2':'3', '1':'2'}))
ENEMY_LEFT = padded(rotate_grid(EG_DOWN))
ENEMY_UP = padded(rotate_grid(rotate_grid(EG_DOWN)))
ENEMY_RIGHT = padded(rotate_grid(rotate_grid(rotate_grid(EG_DOWN))))
ENEMY_BULLET = sprite(
 *(['.'*16] * 4),
 '.......22.......', '......2222......', '......2222......',
 '.......22.......', *(['.'*16] * 4))
BULLET = sprite(
 *(['.'*16] * 4),
 '.......33.......', '......3333......', '......3333......',
 '.......33.......', *(['.'*16] * 4))

SPRITES = {
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
SMOOTH_SPRITES = [
    'player_up','player_right','player_down','player_left',
    'player_shield_up','player_shield_right','player_shield_down','player_shield_left',
    'enemy_up','enemy_right','enemy','enemy_left',
    'fast_up','fast_right','fast_down','fast_left',
    'power_up','power_right','power_down','power_left',
    'armor_up','armor_right','armor_down','armor_left',
    'bullet','enemy_bullet',
    'bonus_star','bonus_helmet','bonus_grenade','bonus_shovel','bonus_clock','bonus_life',
    *TRACK_SPRITES.keys(),
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
    }
    for digit in range(10):
        data['hud_digit_'+str(digit)] = hud_font_glyph(str(digit))
    for name, bytes_ in data.items():
        lines.append(name + ':')
        lines.append('    .byte ' + ', '.join(f'0x{x:02x}' for x in bytes_))
    return lines

def generate(map_path):
    lines = [
        '/* GENERATED by tools/build_cga_assets.py. Do not hand-edit. */',
        '.section .data',
        '.p2align 1',
        'brick_sprite_ptrs:',
        '    .word ' + ', '.join('sprite_brick_mask_'+str(i) for i in range(16)),
        'bonus_sprite_ptrs:',
        '    .word ' + ', '.join('sprite_bonus_'+k for k in BONUS_LETTERS),
        'sprite_table:',
        '    .word ' + ', '.join('sprite_' + name for name in SPRITES),
        'tile_row_offsets:',
        '    .word ' + ', '.join(str(480*i) for i in range(16)),
        'level_template:',
    ]
    rows = get_map(map_path)
    for row in rows:
        lines.append('    .ascii "' + row + '"')
    lines.append('level_end:')
    lines.append('    .if (level_end - level_template) != 256')
    lines.append('    .error "Level must have exactly 256 cells"')
    lines.append('    .endif')
    for stage in range(2, 36):
        staged = get_map(ROOT / 'assets' / 'maps' / f'level{stage:02}.map')
        lines.append(f'level{stage}_template:')
        for row in staged:
            lines.append('    .ascii "' + row + '"')
    lines.append('stage_ptrs:')
    lines.append('    .word ' + ', '.join(
        'level_template' if i == 1 else f'level{i}_template'
        for i in range(1,36)))
    for name, rows in SPRITES.items():
        lines.append('sprite_' + name + ':')
        data = pack(rows)
        for i in range(0, len(data), 12):
            lines.append('    .byte ' + ', '.join(f'0x{x:02x}' for x in data[i:i+12]))
    lines.extend(generate_hud())
    # Append the separate masked-blit atlas after the opaque tiled graphics.
    lines.append('    .p2align 1')
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
