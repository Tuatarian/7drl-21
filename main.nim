import raylib, rayutils, tables, random, lenientops, strformat

randomize()

type
    Player = object
        pos : Vector2
        npos : Vector2
        health : int
        posSeq : seq[Vector2]
        dead, won, canMove : bool
        xp : int
        fullhealth : int
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
    oTileTexTable = toTable {NONE : LoadTexture "assets/sprites/BaseTile.png", EN1 : LoadTexture "assets/sprites/Enemy1.png", MED : LoadTexture "assets/sprites/medkit.png"}


# ---> Map Management <--- #

proc cellAutomaton(iters : int, prevalence : int, map : var seq[seq[(Tile, OTile)]]) : seq[Vector2] =
    for j in 0..<map.len:
        for i in 0..<map[j].len:
            let weight = rand(100)
            if weight < prevalence:
                map[j, i] = (map[j, i][0], EN1)
                if makevec2(i, j) notin result: result.add makevec2(i, j)
    for itr in 0..iters:
        for j in 0..<map.len:
            for i in 0..<map[j].len:
                var liveNeighbors : int
                for c in map.getNeighborTiles(j, i):
                    if c[1] != EN1: liveNeighbors += 1
                if liveNeighbors in 2..3:
                    if map[j, i][1] != EN1:
                        discard
                    elif liveNeighbors == 3:
                        map[j, i] = (map[j, i][0], EN1)
                        if makevec2(i, j) notin result: result.add makevec2(i, j)
                elif map[j, i][1] == EN1:
                    map[j, i] = (map[j, i][0], NONE)
                    if makevec2(i, j) in result: result.del result.find(makevec2(i, j))
    if makevec2(0, 0) in result: result.del result.find makevec2(0, 0)

proc genOmap(prevalence : int, mednum : int, map : var seq[seq[(Tile, OTile)]]) : (seq[Vector2], seq[Vector2]) =
    result[0] = cellAutomaton(10, prevalence, map)
    let numMed = int gauss(mednum.float, 1)
    for i in 0..<numMed:
        var spos = makevec2(rand map.len - 1, rand map[0].len - 1)
        while map[spos][1] != NONE or spos in makerect(0, 0, 1, 1):
            spos = makevec2(map.len - 1, rand map[0].len - 1)
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

func renderTrail(plr : Player, texTable : Table[string, Texture], tilesize : int) =
    if plr.posSeq.len > 1:
        for i in 0..<plr.posSeq.len:
            var texId = "0000"
            if i != plr.posSeq.len - 1 and i != 0:
                let dir = plr.posSeq[i - 1] - plr.posSeq[i]
                let dir2 = plr.posSeq[i + 1] - plr.posSeq[i]
                let dirX = [dir.x, dir2.x]
                let dirY = [dir.y, dir2.y]
                for i in dirX:
                    if i == -1:
                        texId[3] = '1'
                    elif i == 1:
                        texId[1] = '1'
                for i in dirY:
                    if i == -1:
                        texId[0] = '1'
                    elif i == 1:
                        texID[2] = '1'
                DrawTextureV(texTable[texId], plr.posSeq[i] * tilesize, WHITE)
            elif i == 0:
                let dir = plr.posSeq[i + 1] - plr.posSeq[i]
                if dir.x == -1:
                    texId[3] = '1'
                elif dir.x == 1:
                    texId[1] = '1'
                if dir.y == -1:
                    texId[0] = '1'
                elif dir.y == 1:
                    texID[2] = '1'
                DrawTextureV(texTable[texId], plr.posSeq[i] * tilesize, WHITE)
            elif i == plr.posSeq.len - 1:
                let dir = plr.posSeq[i - 1] - plr.posSeq[i]
                if dir.x == -1:
                    texId[3] = '1'
                elif dir.x == 1:
                    texId[1] = '1'
                if dir.y == -1:
                    texId[0] = '1'
                elif dir.y == 1:
                    texID[2] = '1'
                DrawTextureV(texTable[texId], plr.posSeq[i] * tilesize, WHITE)                     

var
    plr = Player(pos : makevec2(0, 0), health : 2, fullhealth : 2)
    lfkey : KeyboardKey
    map = genSeqSeq(8, 13, (GRND, NONE))
    elocs, medlocs : seq[Vector2]
    trailTexTable = toTable {"0000" : LoadTexture "assets/sprites/trails/0000.png"}
    winTimer, deathTimer : int

for i in 0..12:
    var bini = $int2bin i
    while bini.len != 4:
        bini = "0" & bini
    trailTexTable[bini] = LoadTexture &"assets/sprites/trails/{bini}.png"

(elocs, medlocs) = genOmap(50, 6, map)

while not WindowShouldClose():
    ClearBackground BGREY

    if plr.npos notin plr.posSeq:
        plr.posSeq.add plr.npos

    if plr.pos in plr.posSeq[0..^2] or plr.health < 0:
        plr.dead = true
        plr.canMove = false
    
    if elocs.len > 0 and plr.pos in elocs:
        map[invert plr.pos] = (map[invert plr.pos][0], NONE)
        echo plr.pos
        elocs.del elocs.find(plr.pos)
        plr.health += -1
        echo plr.health

    if medlocs.len > 0 and plr.pos in medlocs:
        map[invert plr.pos] = (map[invert plr.pos][0], NONE)
        medlocs.del medlocs.find(plr.pos)
        plr.health += plr.fullhealth
        echo plr.health


    if (not plr.canMove) and plr.dead:
        if deathTimer == 5:
            deathTimer = 0
            plr.dead = false
            plr.canMove = true
            plr.posSeq = @[]
            plr = Player(pos : makevec2(0, 0), health : 2, fullhealth : 2)
            elocs = @[]
            medlocs = @[]
            map = genSeqSeq(8, 13, (GRND, NONE))
            (elocs, medlocs) = genOmap(50, 6, map)
        deathTimer += 1

    if plr.won:
        deathTimer = 0
        plr.canMove = false
        if winTimer == 7:
            plr.won = false
            plr.canMove = true
            winTimer = 0
            plr.posSeq = @[]
            elocs = @[]
            medlocs = @[]
            map = genSeqSeq(8, 13, (GRND, NONE))
            (elocs, medlocs) = genOmap(50, 6, map)
        else: winTimer += 1


    lfkey = movePLr(plr, numTilesVec, lfkey)
    plrAnim plr

    BeginDrawing()
    renderMap map, tileTexTable, oTileTexTable, tilesize
    renderTrail plr, trailTexTable, tilesize
    drawTexCenteredFromGrid plrTex, plr.pos, tilesize, WHITE
    EndDrawing()

CloseWindow()