"""v0.30 immutable 12x12 tank pixels copied from the user's 115x20 upload.

Source: image(20261114-131733).png, six aligned sprites (left to right)
P1, companion, light, medium, assault, heavy. Original image RGB:
white (255,255,255) -> transparent '.', blue (0,162,232) -> CGA cyan '1',
red (237,28,36) -> CGA magenta '2', grey (195,195,195) -> CGA white '3'.
NO interpolation, no morphology and no invented/replaced pixel placements.
The game reuses P1's packed smooth atlas for the companion: four magenta
pixels are drawn as a tiny runtime overlay at their exact rotated positions.
"""
ART = {
 'player': (
  '.....11.....',
  '.....11.....',
  '.11..11..11.',
  '111.1111.111',
  '11.111111.11',
  '33.111131.33',
  '11.111311.11',
  '33..1111..33',
  '1111....1111',
  '331111111133',
  '111131131111',
  '.1111111111.',
 ),
 'companion': (
  '.....11.....',
  '.....11.....',
  '.11..11..11.',
  '111.1111.111',
  '11.111111.11',
  '33.111131.33',
  '11.111311.11',
  '33..1111..33',
  '1111....1111',
  '331111111133',
  '111122221111',
  '.1111111111.',
 ),
 'light': (
  '....11......',
  '....31......',
  '.11.11.11...',
  '211.31.112..',
  '31.1111.13..',
  '21.1111.12..',
  '31.1221.13..',
  '21.1111.12..',
  '31..11..13..',
  '2111..1112..',
  '.11111111...',
  '...1111.....',
 ),
 'medium': (
  '.....11.....',
  '.....11.....',
  '..11.11.11..',
  '221..11..122',
  '13..1111..31',
  '22.111111.22',
  '13.111121.31',
  '22.111211.22',
  '13..1111..31',
  '221......122',
  '.1111111111.',
  '...111111...',
 ),
 'assault': (
  '....11......',
  '..1.33.1....',
  '.11.11.11...',
  '221.11.122..',
  '13.3113.31..',
  '22.1111.22..',
  '13.1111.31..',
  '22.1111.22..',
  '13.3113.31..',
  '221....122..',
  '.11133111...',
  '..111111....',
 ),
 'heavy': (
  '.....11.....',
  '.11.1111.11.',
  '1111.11.1111',
  '2211.11.1122',
  '11..1111..11',
  '22.121121.22',
  '11.122221.11',
  '22.121121.22',
  '11..1111..11',
  '2211....1122',
  '111111111111',
  '.111.11.111.',
 ),
}
SOURCE_X=(3,17,52,66,83,98)
SOURCE_Y=4
ORDER=('player','companion','light','medium','assault','heavy')

def rotate_right(rows):
    return tuple(''.join(rows[11-x][y] for x in range(12)) for y in range(12))

def directions(name):
    """Four exact 90-degree turns of one 12x12 bitmap, padded to 16x12."""
    up=ART[name]
    right=rotate_right(up)
    down=rotate_right(right)
    left=rotate_right(down)
    return tuple(tuple('..'+row+'..' for row in frame) for frame in (up,right,down,left))

def validate():
    assert tuple(ART)==ORDER
    assert all(len(frame)==12 and all(len(row)==12 and set(row)<={'1','2','3','.'} for row in frame) for frame in ART.values())
    assert '2' not in ''.join(ART['player'])
    for n in ('player','light','medium','assault','heavy'):
        frames=directions(n)
        assert len(frames)==4 and all(len(r)==12 and len(r[0])==16 for r in frames)
        assert frames[0]==tuple('..'+r+'..' for r in ART[n])
    diff=[(x,y) for y in range(12) for x in range(12) if ART['player'][y][x]!=ART['companion'][y][x]]
    assert diff==[(4,10),(5,10),(6,10),(7,10)]
    assert all(ART['companion'][y][x]=='2' for x,y in diff)
validate()
