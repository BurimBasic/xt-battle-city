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
BRICK = sprite(
 '................', '2222222222222222', '2222222.22222222',
 '2222222.22222222', '2222222.22222222', '................',
 '222.222222222.22', '222.222222222.22', '222.222222222.22',
 '222.222222222.22', '2222222222222222', '................')
STEEL = sprite(
 '3333333333333333', '3..............3', '3.333333333333.3',
 '3.3............3', '3.3.33333333.3.3', '3.3.3......3.3.3',
 '3.3.3......3.3.3', '3.3.33333333.3.3', '3.3............3',
 '3.333333333333.3', '3..............3', '3333333333333333')
WATER = sprite(
 '1111111111111111', '1111111111111111', '11..11111..11111',
 '1111111111111111', '111111..11111111', '1111111111111111',
 '1111111111111111', '..11111111..1111', '1111111111111111',
 '11111111111..111', '1111111111111111', '1111111111111111')
# Extra terrain: forest hides part of a tank, ice will preserve motion briefly.
FOREST = sprite(*tuple(
    ''.join('1' if (x * 3 + y * 5) % 9 < 3 else ('2' if (x+y) % 11 == 0 else '.')
            for x in range(16)) for y in range(12)
))
ICE = sprite(*tuple(
    ''.join('3' if y in (0, 11) or x in (0, 15) else
            ('1' if (x+y) % 7 < 2 else '.') for x in range(16)) for y in range(12)
))

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
 '................', '......3333......', '.....333333.....',
 '....33333333....', '....33....33....', '...333.33.333...',
 '...333.33.333...', '....33....33....', '....33333333....',
 '.....333333.....', '......3333......', '................')
TANK_UP = sprite(
 '......11........', '......11........', '..33..11..33....',
 '..3111111133....', '..3113311133....', '..3113311133....',
 '..3113311133....', '..3111111133....', '..3111111133....',
 '..33......33....', '..33......33....', '................')
# Render directions by rotating a 12x12 centered graphic in a 16x12 tile;
# the sprite is 12 wide and 12 tall, then left-padded by 2 pixels.
def tank_grid():
    return [list(r[2:14]) for r in TANK_UP]

def rotate_grid(g):
    n = len(g)
    assert all(len(row) == n for row in g)
    return [[g[n-1-x][y] for x in range(n)] for y in range(n)]

def padded(g):
    return sprite(*('..' + ''.join(r) + '..' for r in g))

G_UP = tank_grid()
TANK_RIGHT = padded(rotate_grid(G_UP))
TANK_DOWN = padded(rotate_grid(rotate_grid(G_UP)))
TANK_LEFT = padded(rotate_grid(rotate_grid(rotate_grid(G_UP))))

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


def get_map(map_path):
    rows = [line.strip() for line in map_path.read_text(encoding='ascii').splitlines() if line.strip()]
    assert len(rows) == 13 and all(len(x) == 13 for x in rows)
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
        '    .word ' + ', '.join(str(640 + 320 * i + 64) for i in range(10)),
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
        '    .word ' + ', '.join(str(648+480*i) for i in range(13)),
        'level_template:',
    ]
    rows = get_map(map_path)
    for row in rows:
        lines.append('    .ascii "' + row + '"')
    lines.append('level_end:')
    lines.append('    .if (level_end - level_template) != 169')
    lines.append('    .error "Level must have exactly 169 cells"')
    lines.append('    .endif')
    for stage in range(2, 10):
        staged = get_map(ROOT / 'assets' / 'maps' / f'level{stage:02}.map')
        lines.append(f'level{stage}_template:')
        for row in staged:
            lines.append('    .ascii "' + row + '"')
    lines.append('stage_ptrs:')
    lines.append('    .word ' + ', '.join(
        'level_template' if i == 1 else f'level{i}_template'
        for i in range(1,10)))
    for name, rows in SPRITES.items():
        lines.append('sprite_' + name + ':')
        data = pack(rows)
        for i in range(0, len(data), 12):
            lines.append('    .byte ' + ', '.join(f'0x{x:02x}' for x in data[i:i+12]))
    lines.extend(generate_hud())
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
