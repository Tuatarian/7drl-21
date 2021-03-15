import raylib, rayutils, tables, random, strformat, math, os, sequtils

randomize()

type
    Player = object
        pos : Vector2
        npos : Vector2
        health : int
        posSeq : seq[Vector2]
        dead, won, canMove : bool
        xp : int
        lvl : int
        fullhealth : int
    Tile = enum
        GRND, WALL, LVEN
    OTile = enum
        MED, EN1, NONE, SPIKE, PRSPK
const
    tilesize = 96
    rScreenWidth = 1920
    rScreenHeight = 1080
    screenWidth = 1248
    screenHeight = 768
    marginX = (rScreenWidth - screenWidth) div 2
    marginY = (rScreenHeight - screenHeight) div 2
    numTilesVec = makevec2(screenWidth / tilesize, screenHeight / tilesize)

InitWindow rScreenWidth, rScreenHeight, "7drl"
SetTargetFPS 60

let
    plrTex = LoadTexture "assets/sprites/Player.png"
    tileTexTable = toTable {GRND : LoadTexture "assets/sprites/BaseTile.png", LVEN : LoadTexture "assets/sprites/LvlEndPortal.png"}
    oTileTexTable = toTable {NONE : LoadTexture "assets/sprites/BaseTile.png", EN1 : LoadTexture "assets/sprites/Enemy1.png", MED : LoadTexture "assets/sprites/medkit.png", SPIKE : LoadTexture "assets/sprites/Enemy2.png", PRSPK : LoadTexture "assets/sprites/settingsicon.png"}
    moveOgg = LoadSound "assets/sounds/Move.ogg"
    winOgg = LoadSound "assets/sounds/GenericNotify.ogg"
    loseOgg = LoadSound "assets/sounds/Error.ogg"
    hitOgg = LoadSound "assets/sounds/SocialNotify.ogg"


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
    if makevec2(12, 5) in result: result.del result.find makevec2(12, 5)

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

func movePlr(plr : var Player, numtilesVec : Vector2, lfkey : var KeyboardKey) : bool =
    if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT):
        if lfkey == KEY_LEFT:
            lfkey = KEY_LEFT
            result = false
        else:
            plr.npos.x += -1
            lfkey = KEY_LEFT
            result = true
    elif IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT):
        if lfkey == KEY_RIGHT:
            lfkey = KEY_RIGHT
            result = false
        else:
            plr.npos.x += 1
            lfkey = KEY_RIGHT
            result = true
    elif IsKeyDown(KEY_W) or IsKeyDown(KEY_UP):
        if lfkey == KEY_UP:
            lfkey = KEY_UP
            result = false
        else:
            plr.npos.y += -1
            lfkey = KEY_UP
            result = true
    elif IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN):
        if lfkey == KEY_DOWN:
            lfkey = KEY_DOWN
            result = false
        else:
            plr.npos.y += 1
            lfkey = KEY_DOWN
            result = true
    else:
        lfkey = KEY_SCROLL_LOCK
    plr.npos = anticlamp(clamp(plr.npos, numTilesVec - 1), makevec2(0, 0))

# ---> Rendering <--- #

func renderMap(map : seq[seq[(Tile, Otile)]], tileTexTable : Table[Tile, Texture], oTileTexTable : Table[Otile, Texture], tilesize : int) =
    for i in 0..<map.len:
        for j in 0..<map[i].len:
            drawTexFromGrid tileTexTable[map[i, j][0]], j, i, tilesize, WHITE
            drawTexCenteredFromGrid oTileTexTable[map[i, j][1]], j, i, tilesize, WHITE
    drawTexFromGrid tileTexTable[LVEN], 12, 4, tilesize, WHITE

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
    plr = Player(canMove : true, npos : makevec2(0, 0), pos : makevec2(0, 0), health : 2, fullhealth : 2, lvl : 4)
    lfkey : KeyboardKey
    map = genSeqSeq(8, 13, (GRND, NONE))
    elocs, medlocs : seq[Vector2]
    trailTexTable = toTable {"0000" : LoadTexture "assets/sprites/trails/0000.png"}
    winTimer, deathTimer : int
    estreak : int
    plrpcache : seq[Vector2]
    currentlv = 1
    attTurns5 : int
    spikelocs : seq[Vector2]
    fbuf = LoadRenderTexture(screenWidth, screenHeight)
    bossenemsleft : int
    deadTextCache : bool
    victory : bool
    xpc : int
    musicArr : seq[Music]
    lastSong = -1
    spacecache : bool
    spacecache2 : bool

for f in walkDir("assets/sounds/music"):
    musicArr.add LoadMusicStream f[1]
    musicArr[^1].SetMusicVolume 0.45
moveOgg.SetSoundVolume 0.55

for i in 0..12:
    var bini = $int2bin i
    while bini.len != 4:
        bini = "0" & bini
    trailTexTable[bini] = LoadTexture &"assets/sprites/trails/{bini}.png"

(elocs, medlocs) = genOmap(50, 6, map)

SetMasterVolume 0.75
InitAudioDevice()

while not WindowShouldClose():
    ClearBackground BGREY

    musicArr.iterIt UpdateMusicStream it

    if IsKeyPressed(KEY_SPACE):
        if not spacecache2:
            spacecache = true
            spacecache2 = true
    else:
        spacecache = false
        spacecache2 = false

    if musicArr.mapIt(IsMusicPlaying it).foldl(a or b) == false or spacecache:
        spacecache = false
        musicArr.iterIt(StopMusicStream it)
        var inx = rand(musicArr.len - 1)
        while inx == lastSong:
            inx = rand(musicArr.len - 1)
        PlayMusicStream musicArr[inx]

    if plr.npos notin plr.posSeq:
        plr.posSeq.add plr.npos

    if plr.pos in plr.posSeq[0..^2] or plr.health < 0:
        plr.dead = true

    if elocs.len > 0 and plr.pos in elocs and map[invert plr.pos][1] == EN1:
        hitOgg.SetSoundVolume 1 + (estreak - 1) / 2
        PlaySound hitOgg
        map[invert plr.pos] = (map[invert plr.pos][0], NONE)
        elocs.del elocs.find(plr.pos)
        plr.health += -1
        estreak += 1
        plrpcache.add plr.pos
        bossenemsleft += -1

    if spikelocs.len > 0 and plr.pos in spikelocs and map[invert plr.pos][1] == SPIKE:
        map[invert plr.pos] = (map[invert plr.pos][0], NONE)
        spikelocs.del spikelocs.find(plr.pos)
        plr.dead = true


    if medlocs.len > 0 and plr.pos in medlocs and map[invert plr.pos][1] == MED:
        map[invert plr.pos] = (map[invert plr.pos][0], NONE)
        medlocs.del medlocs.find(plr.pos)
        plr.health += plr.fullhealth
        plrpcache.add plr.pos

    xpc = plr.xp + (estreak ^ 2 + estreak) div 2

    if plr.npos notin elocs and plr.npos notin medlocs and plr.pos notin plrpcache:
        plr.xp += (estreak ^ 2 + estreak) div 2
        hitOgg.SetSoundVolume 1
        while (plr.lvl) ^ 2 < plr.xp:
            plr.xp += -(plr.lvl ^ 2)
            plr.lvl += 2
        estreak = 0

    if plr.pos == makevec2(12, 4):
        if bossenemsleft <= 0:
            plr.won = true
        else: plr.dead = true

    if plr.dead:
        plr.canMove = false
        if deathTimer == 5:
            PlaySound loseOgg
            attTurns5 = 0
            deadTextCache = true
            bossenemsleft = 0
            deathTimer = 0
            plr.dead = false
            plr.canMove = true
            plr.posSeq = @[]
            plr = Player(canMove : true, npos : makevec2(0, 0), pos : makevec2(0, 0), health : 2, fullhealth : 2, lvl : 4, xp : 0)
            plr.fullhealth = 2
            plr.health = 2
            currentlv = 1
            elocs = @[]
            spikelocs = @[]
            medlocs = @[]
            map = genSeqSeq(8, 13, (GRND, NONE))
            (elocs, medlocs) = genOmap(50, 6, map)
        else: deathTimer += 1

    if plr.won:
        deathTimer = 0
        plr.canMove = false
        if winTimer == 7:
            PlaySound winOgg
            attTurns5 = 0
            plr.won = false
            currentlv += 1
            plr.dead = false
            plr.canMove = true
            winTimer = 0
            plr.posSeq = @[]
            elocs = @[]
            medlocs = @[]
            spikelocs = @[]
            plr = Player(canMove : true, npos : makevec2(0, 0), pos : makevec2(0, 0), health : 2, fullhealth : 2, lvl : plr.lvl, xp : plr.xp)
            plr.fullhealth = 2
            plr.health =  2 + (plr.lvl - 4) div 2
            bossenemsleft = 0
            map = genSeqSeq(8, 13, (GRND, NONE))
            (elocs, medlocs) = genOmap(50, 6, map)
            if makevec2(0, 0) in elocs: elocs.del elocs.find makevec2(0, 0)
            if makevec2(12, 4) in elocs: elocs.del elocs.find makevec2(12, 4)
            if makevec2(0, 0) in medlocs: medlocs.del medlocs.find makevec2(0, 0)
            if makevec2(12, 4) in elocs: elocs.del elocs.find makevec2(12, 4)
            if currentlv == 6 or currentlv == 3:
                bossenemsleft = 8
            if currentlv == 9:
                victory = true
                plr.dead = true
                currentlv = 0
        else: winTimer += 1

    if plr.canMove:
        if movePLr(plr, numTilesVec, lfkey):
            PlaySound moveOgg
            victory = false
            deadTextCache = false
            if currentlv == 3:
                attTurns5 += 1
                if attTurns5 mod 3 == 0:
                    if attTurns5 div 3 == 1:
                        for i in 0..7:
                            spikelocs.add makevec2(6, i)
                            map[i, 6] = (map[i, 6][0], SPIKE)
                    elif attTurns5 div 3 == 2:
                        attTurns5 = 0
                        for i in 0..12:
                            spikelocs.add makevec2(i, 4)
                            map[4, i] = (map[4, i][0], SPIKE)
                else:
                    spikelocs = @[]
                    for i in 0..7:
                        for j in 0..<map.len:
                            for i in 0..<map[j].len:
                                if map[j, i][1] == SPIKE:
                                    map[j, i] = (map[j, i][0], NONE)
                    if attTurns5 < 3 and attTurns5 mod 3 == 2:
                        for i in 0..7:
                            map[i, 6] = (map[i, 6][0], PRSPK)
                    elif attTurns5 < 6 and attTurns5 mod 3 == 2:
                        for i in 0..12:
                            map[4, i] = (map[4, i][0], PRSPK)
            elif currentlv == 6:
                attTurns5 += 1
                if attTurns5 mod 3 == 0:
                    if attTurns5 div 3 == 1:
                        for i in 0..7:
                            spikelocs.add makevec2(i, i)
                            map[i, i] = (map[i, i][0], SPIKE)
                    elif attTurns5 div 3 == 2:
                        attTurns5 = 0
                        for i in 0..7:
                            spikelocs.add makevec2(12 - i, i)
                            map[i, 12 - i] = (map[i, 12 - i][0], SPIKE)
                else:
                    spikelocs = @[]
                    for i in 0..7:
                        for j in 0..<map.len:
                            for i in 0..<map[j].len:
                                if map[j, i][1] == SPIKE:
                                    map[j, i] = (map[j, i][0], NONE)
                    if attTurns5 < 3 and attTurns5 mod 3 == 2:
                        for i in 0..7:
                            map[i, i] = (map[i, i][0], PRSPK)
                    elif attTurns5 < 6 and attTurns5 mod 3 == 2:
                        for i in 0..7:
                            map[i, 12 - i] = (map[i, 12 - i][0], PRSPK)     
    plrAnim plr

    BeginTextureMode(fbuf)
    renderMap map, tileTexTable, oTileTexTable, tilesize
    renderTrail plr, trailTexTable, tilesize
    drawTexCenteredFromGrid plrTex, plr.pos, tilesize, WHITE
    EndTextureMode()

    BeginDrawing()
    DrawTexturePro(fbuf.texture, makerect(0, 0, screenWidth, -screenHeight), makerect(0, 0, screenWidth, screenHeight), makevec2(-marginX, -marginY), 0, WHITE)
    DrawRectangleLines(marginX, marginY, screenWidth, screenHeight, WHITE)
    if victory:
        drawTextCenteredX &"You Won!", rScreenWidth div 2 + 2, 53, 80, RED
        drawTextCenteredX &"You Won!", rScreenWidth div 2 - 1, 50, 80, WHITE
    elif deadTextCache:
        drawTextCenteredX &"You Died!", rScreenWidth div 2 + 2, 53, 80, RED
        drawTextCenteredX &"You Died!", rScreenWidth div 2 - 1, 50, 80, WHITE
    else:
        drawTextCenteredX &"Health : {plr.health}", rScreenWidth div 2 + 2, 53, 80, RED
        drawTextCenteredX &"Health : {plr.health}", rScreenWidth div 2 - 1, 50, 80, WHITE

    DrawText &"XP : {xpc} / {plr.lvl ^ 2}", 102, 73, 40, RED
    DrawText &"XP : {xpc} / {plr.lvl ^ 2}", 100 - 1, 70, 40, WHITE

    DrawText &"Level : {1 + (plr.lvl - 4) div 2}", rScreenWidth - 252, 73, 40, RED
    DrawText &"Level : {1 + (plr.lvl - 4) div 2}", rScreenWidth - 250 - 1, 70, 40, WHITE
    if currentlv == 3 or currentlv == 6:
        drawTextCenteredX &"Kill {max(bossenemsleft, 0)} enemies to proceed", rScreenWidth div 2 + 2, rScreenHeight - 120, 80, RED
        drawTextCenteredX &"Kill {max(bossenemsleft, 0)} enemies to proceed", rScreenWidth div 2 - 1, rScreenHeight - 123, 80, WHITE
    EndDrawing()



CloseWindow()