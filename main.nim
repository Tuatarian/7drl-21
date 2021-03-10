import raylib, rayutils, tables, random

randomize()

type
    Player = object
        pos : Vector2
        npos : Vector2
        health : int
        posSeq : seq[Vector2]
        dead, won : bool
        xp : int
    Tile = enum
        GRND, WALL
    OTile = enum
        MED, EN1, NONE
const
    tilesize = 96
    screenWidth = 1248
    screenHeight = 768
    numTilesVec = makevec2(screenWidth / tilesize, screenHeight / tilesize)

InitWindow screenWidth, screenHeight, "7drl"
SetTargetFPS 60

let
    plrTex = LoadTexture "assets/sprites/Player.png"
    tileTexTable = toTable {GRND : LoadTexture "assets/sprites/BaseTile.png", WALL : LoadTexture "assets/sprites/walls/1111.png"}
    oTileTexTable = toTable {NONE : LoadTexture"assets/sprites/BaseTile.png", EN1 : LoadTexture "assets/sprites/Enemy1.png", MED : LoadTexture "assets/sprites/BaseTile.png"}


# ---> Map Management <--- #

proc genOmap(amtSeed : int, map : var seq[seq[(Tile, OTile)]]) : (seq[Vector2], seq[Vector2]) =
    let numots = int gauss(amtSeed.float, 3)
    for i in 0..<numots:
        var spos = makevec2(rand 7, rand 12)
        while map[spos][1] != NONE or spos in makerect(0, 0, 2, 2):
            spos = makevec2(rand 7, rand 12)
        let weight = rand(100)
        if weight < 90:
            map[spos] = (map[spos][0], EN1)
            result[0].add invert spos
        else: 
            map[spos] = (map[spos][0], MED)
            result[1].add invert spos

# ---> Player Management <--- #

func plrAnim(plr : var Player) =
    let dir = plr.npos - plr.pos
    plr.pos += dir / 2
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

# ---> Rendering <--- #

func renderMap(map : seq[seq[(Tile, Otile)]], tileTexTable : Table[Tile, Texture], oTileTexTable : Table[Otile, Texture], tilesize : int) =
    for i in 0..<map.len:
        for j in 0..<map[i].len:
            drawTexFromGrid tileTexTable[map[i, j][0]], j, i, tilesize, WHITE
            drawTexCenteredFromGrid oTileTexTable[map[i, j][1]], j, i, tilesize, WHITE

func renderTrail(plr : Player, tilesize : int) =
    for v in plr.posSeq:
        DrawRectangleV(v * tilesize, makevec2(tilesize, tilesize), WHITE)

var
    plr = Player(pos : makevec2(0, 0), health : 5)
    lfkey : KeyboardKey
    map = genSeqSeq(8, 13, (GRND, NONE))
    elocs, medlocs : seq[Vector2]

(elocs, medlocs) = genOmap(30, map)

while not WindowShouldClose():
    ClearBackground BGREY

    if plr.npos notin plr.posSeq:
        plr.posSeq.add plr.npos
    if plr.pos in plr.posSeq[0..^1]:
        plr.dead = true
    
    if plr.pos in elocs:
        map[invert plr.pos] = (map[invert plr.pos][0], NONE)
        elocs.del elocs.find(plr.pos)
        plr.health += -1

    lfkey = movePLr(plr, numTilesVec, lfkey)
    plrAnim plr

    BeginDrawing()
    renderMap map, tileTexTable, oTileTexTable, tilesize
    renderTrail plr, tilesize
    drawTexCenteredFromGrid plrTex, plr.pos, tilesize, WHITE
    EndDrawing()

CloseWindow()