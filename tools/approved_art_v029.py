"""User-approved CGA source masters for XT Battle City v0.29.

Artwork is extracted and hand-corrected from two approved November 13
references. No runtime scaling, blending or extra palette colors.
'.' transparent, '0' opaque black, 1 cyan, 2 magenta, 3 gray.
P1 is cyan/gray ONLY; the companion's two magenta stripes are rendered
at runtime, not baked into another 1920-byte smooth-sprite atlas.
"""
PLAYER_RIGHT=(
 '..1.3333333.331.',
 '.11.31131331331.',
 '.1............1.',
 '..331111111133..',
 '1.3311.333.133..',
 '1.111.33333....1',
 '1.111.3333333331',
 '1.111.3333......',
 '..3311.....133..',
 '...3111111113...',
 '.11...........1.',
 '.11.3313333.331.',
)
PLANE_RIGHT=(
 '.................222............',
 '................2111............',
 '................1111............',
 '..............211311............',
 '..............213331............',
 '.............2111111.....3......',
 '.............21111111332.3......',
 '............211133321112332.....',
 '.311........2111111.1112.3......',
 '21111......111111111.....3......',
 '21111.....1111122222111.........',
 '.231111311111331333131122211332.',
 '1211111311111331333131111111332.',
 '.2111.....1111122222111.........',
 '21111......111111111.....3......',
 '2211.......1111111..1332.3......',
 '............211333321112332.....',
 '............221111121112.3......',
 '.............2111111.....3......',
 '..............213331............',
 '..............211311............',
 '...............21111............',
 '................2111............',
 '.................222............',
)
def turn_left(rows):
    h,w=len(rows),len(rows[0])
    return tuple(''.join(rows[x*h//w][w-1-y*w//h] for x in range(w)) for y in range(h))

def turn_right(rows):
    h,w=len(rows),len(rows[0])
    return tuple(''.join(rows[h-1-x*h//w][y*w//h] for x in range(w)) for y in range(h))

def dark_channels(rows):
    """Opaque dark contours prevent map textures showing inside turret."""
    out=[]
    for y,row in enumerate(rows):
        r=list(row)
        if 2<=y<=9:
            for x in range(3,12):
                if r[x]=='.' and any(c!='.' for c in r[:x]) and any(c!='.' for c in r[x+1:]):
                    r[x]='0'
        out.append(''.join(r))
    return tuple(out)

def player_sprites():
    right=dark_channels(PLAYER_RIGHT)
    up=turn_left(right)
    down=turn_right(right)
    left=tuple(r[::-1] for r in right)
    return up,right,down,left

def plane_sprites():
    right=PLANE_RIGHT
    up=turn_left(right)
    down=tuple(r[::-1] for r in reversed(up))
    left=tuple(r[::-1] for r in right)
    return up,right,down,left

def validate():
    assert len(PLAYER_RIGHT)==12 and all(len(row)==16 for row in PLAYER_RIGHT)
    assert len(PLANE_RIGHT)==24 and all(len(row)==32 for row in PLANE_RIGHT)
    assert set(''.join(PLAYER_RIGHT))<=set('.013')
    assert set(''.join(PLANE_RIGHT))<=set('.0123')
    for sprites,h,w in ((player_sprites(),12,16),(plane_sprites(),24,32)):
        assert len(sprites)==4
        assert all(len(z)==h and all(len(row)==w for row in z) for z in sprites)
validate()
