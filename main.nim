import raylib, rayutils, tables

template BGREY() : auto = makecolor("282828", 255)
template OFFWHITE() : auto = makecolor(235, 235, 235)

type
    Player = object
        pos : Vector2
        npos : Vector2
        health : int
        posSeq : seq[Vector2]
        dead, won : bool
    Tile = enum
        GRND, WALL
    OTile = enum
        MED, EN1, NONE
const
    tilesize = 96
    screenWidth = 1248
    screenHeight = 768
    numTilesVec = makevec2(screenWidth / tilesize, screenHeight / tilesize)

let
    tileTexTable = toTable {GRND : LoadTexture "assets/sprites/BaseTile.png", WALL : LoadTexture "assets/sprites/walls/1111.png"}
    oTileTexTable = toTable {NONE : LoadTexture"assets/sprites/BaseTile.png", EN1 : LoadTexture "assets/sprites/Enemy1.png"}

# ---> Player Management <--- #

func plrAnim(plr : var Player) =
    let dir = plr.npos - plr.npos
    plr.pos += dir.normalize / 2
    if abs(plr.npos - plr.pos) <& 0.1:
        plr.pos = plr.npos

func movePlr(plr : var Player, numtilesVec : Vector2, lfkey : KeyboardKey) : KeyboardKey =
    if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT):
        if lfkey == KEY_LEFT:
            result = KEY_LEFT
        else:
            plr.npos.x += -1
            result = KEY_LEFT
    elif IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT):
        if lfkey == KEY_RIGHT:
            result = KEY_RIGHT
        else:
            plr.npos.x += 1
            result = KEY_RIGHT
    elif IsKeyDown(KEY_W) or IsKeyDown(KEY_UP):
        if lfkey == KEY_UP:
            result = KEY_UP
        else:
            plr.npos.y += -1
            result = KEY_UP
    elif IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN):
        if lfkey == KEY_DOWN:
            result = KEY_DOWN
        else:
            plr.npos.y += 1
            result = KEY_DOWN
    else:
        result = KEY_SCROLL_LOCK
    plr.npos = anticlamp(clamp(plr.npos, numTilesVec - 1), makevec2(0, 0))

# ---> Render Map <--- #

func renderMap(map : seq[seq[(Tile, Otile)]], tileTexTable : Table[Tile, Texture], oTileTexTable : Table[Otile, Texture]) =
    for i in 0..<map.len:
        for j in 0..<map[i].len:
            DrawTexture tileTexTable[map[i, j][0]], j, i, WHITE
            drawTexCentered oTileTexTable[map[i, j][1]], j, i, WHITE

var
    plr = Player(pos : makevec2(0, 0), health : 3)
    lfkey : KeyboardKey

InitWindow screenWidth, screenHeight, "7drl"
SetTargetFPS 60

while not WindowShouldClose():
    ClearBackground BGREY

    if plr.npos notin plr.posSeq:
        plr.posSeq.add plr.npos
    if plr.pos in plr.posSeq[0..^1]:
        plr.dead = true

    lfkey = movePLr(plr, numTilesVec, lfkey)
    plrAnim plr


CloseWindow()