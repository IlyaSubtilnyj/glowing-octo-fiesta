format PE GUI 4.0
entry start

include 'win32a.inc'

min_X = 0
max_X = 88
min_Y = 0
max_Y = 68
_WALLS = 88
_GROUND = 60
_PULA = 61
_BRICK = 1
_TIMERID = 4
_TIMERID2 = 5

_UP = 0
_DOWN = 2
_LEFT = 4
_RIGHT = 6

_SPEED = 3
_BULLETSPEED = 8
_BULLETWIDTH = 8
_MAPWIDTH = 300
_BLOCKWIDTH = 30
_TANKID = 1
_TIMERIDEXPLOSION = 2
_BULLETID = 2
_ENEMYID = 5
_ENEMYAMOUNT = 4

struct TANK
        speedx dd ?
        cooX dd ?
        cooY dd ?
        direction dd ?
        amOccupiedBl dd ?
        occupiedBloks dd 2 dup(?)
ends

struct TANKMAS
       rept 4 counter {tanksequent#counter db 0}
       rept 4 counter {enemy#counter TANK ?}
ends

macro initEnemy ordinalNum, isexists, speed, coox, cooy, direction, amOccupiedBl, oc1, oc2 {
      mov [enemyMas.tanksequent#ordinalNum], isexists
      mov [enemyMas.enemy#ordinalNum#.speedx], speed
      mov [enemyMas.enemy#ordinalNum#.cooX], coox
      mov [enemyMas.enemy#ordinalNum#.cooY], cooy
      mov [enemyMas.enemy#ordinalNum#.direction], direction
      mov [enemyMas.enemy#ordinalNum#.amOccupiedBl], amOccupiedBl
      mov [enemyMas.enemy#ordinalNum#.occupiedBloks], oc1
      mov [enemyMas.enemy#ordinalNum#.occupiedBloks+4], oc2
}

macro initEnemySimplified ordinalNum{
      mov ecx, [enemyMas.enemy#ordinalNum#.amOccupiedBl]
@@:
      mov ebx, [enemyMas.enemy#ordinalNum#.occupiedBloks+ecx*4-4]
      mov byte[bufMap+ebx], 0
      loop @b
      mov eax, [a]
      mov [enemyMas.enemy#ordinalNum#.amOccupiedBl], eax
      mov ebx, [b]
      mov [enemyMas.enemy#ordinalNum#.occupiedBloks], ebx
      mov byte[bufMap+ebx*1], 0
      mov ebx, [b+4]
      mov [enemyMas.enemy#ordinalNum#.occupiedBloks+4], ebx
      mov byte[bufMap+ebx*1], 0
      mov [a], 0
}

section '.data' data readable writeable

_class TCHAR 'FASMWIN32',0
_title TCHAR 'Tanks 1990',0
_error TCHAR 'Ошибка запуска.',0
_fileName TCHAR 'map.txt', 0

wc WNDCLASS 0,WindowProc,0,0,NULL,NULL,NULL,COLOR_WINDOWTEXT,NULL,_class

msg MSG
ps PAINTSTRUCT
hBitmap dd ?
hBitmapTank dd ?
hBitmapEnemy1 dd ?
hBitmapWalls dd ?
hBitmapGround dd ?
hBitmapPula dd ?
hCompBitmap dd ?
hBitmapExplosion dd ?
hBitmapExplosionMask dd ?
hdc dd ?
hMemDC dd ?
hMemDCBlock dd ?
hFileMap dd ?
level dd ?
tank_direction db _UP
bullet_direction dd ?
is_bullet_explosion dd 0
is_shot dd 0

hwnd dd ?
src_X dd ?
src_Y dd ?

frame db 0

dst_X dd 150
dst_Y dd 60
src_X_explosion dd 0
is_bullet_exists db 0
bullet_X dd ?
bullet_Y dd ?
explosion_X dd ?
explosion_Y dd ?
blockWereCollapsed dd 2 dup(0)
enemyMas TANKMAS

rect RECT

bufMap db 4 dup(1), 0, 0, 4 dup(1), 20 dup(0), 4 dup(1), 0, 0, 4 dup(1), 60 dup(1)
st_ SYSTEMTIME
Random.wPrevNumber      dd      ?

a dd 0
b dd 2 dup(?)

section '.code' code readable executable

start:
        invoke GetModuleHandle,0
        mov [wc.hInstance],eax
        invoke LoadIcon,[wc.hInstance],17
        mov [wc.hIcon],eax
        invoke LoadCursor,[wc.hInstance],27
        mov [wc.hCursor],eax
        invoke RegisterClass,wc
        test eax,eax
        jz error

        invoke CreateWindowEx,0,_class,_title,WS_VISIBLE+WS_DLGFRAME+ WS_SYSMENU,128,128,600,600,NULL,NULL,[wc.hInstance],NULL
        mov [hwnd], eax
        test eax,eax
        jz error
        ;invoke CreateFile, _fileName, GENERIC_READ+GENERIC_WRITE, FILE_SHARE_READ+FILE_SHARE_WRITE, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_ARCHIVE, 0
        ;invoke CreateFile, _fileName, GENERIC_READ, FILE_SHARE_READ+FILE_SHARE_WRITE, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_ARCHIVE, 0
        ;mov [hFileMap], eax
        ;invoke WriteFile, [hFileMap], bufMap, 100, numberBitestoRead, NULL
        ;invoke ReadFile, [hFileMap], bufMap, 100, numberBitestoRead, NULL
        ;invoke GetLastError
        ;invoke CloseHandle, [hFileMap]
msg_loop:
        invoke GetMessage,msg,NULL,0,0
        cmp eax,1
        jb end_loop
        jne msg_loop
        invoke TranslateMessage,msg
        invoke DispatchMessage,msg
        jmp msg_loop
error:
        invoke MessageBox,NULL,_error,NULL,MB_ICONERROR+MB_OK

end_loop:
        invoke ExitProcess,[msg.wParam]

proc WindowProc hwnd,wmsg,wparam,lparam
     push ebx esi edi
     mov eax,[wmsg]
     cmp eax,WM_CREATE
     je .wmcreate
     cmp eax, WM_LBUTTONDOWN
     jne @f
     mov [is_shot], 1
     jmp .finish
@@:
     cmp eax,WM_PAINT
     je .wmpaint
     cmp eax,WM_DESTROY
     je .wmdestroy
.defwndproc:
        invoke DefWindowProc,[hwnd],[wmsg],[wparam],[lparam]
        jmp .finish
.wmcreate:
        invoke LoadBitmap,[wc.hInstance],37
        mov [hBitmap],eax
        invoke LoadBitmap,[wc.hInstance],38
        mov [hBitmapTank],eax
        mov [hBitmapEnemy1],eax
        invoke LoadBitmap,[wc.hInstance],_WALLS
        mov [hBitmapWalls],eax
        invoke LoadBitmap,[wc.hInstance],_GROUND
        mov [hBitmapGround],eax
        invoke LoadBitmap,[wc.hInstance],_PULA
        mov [hBitmapPula],eax
        invoke LoadBitmap,[wc.hInstance],56
        mov [hBitmapExplosion],eax
        stdcall createBitmapMask, eax, 0
        mov [hBitmapExplosionMask], eax
        invoke SetTimer,[hwnd], _TIMERID, 28, TimerProcedure ;set timer
        jmp .finish
.wmpaint:
        invoke BeginPaint,[hwnd], ps ;Begin painting returns handle to context device -> next line
        mov [hdc], eax

        invoke CreateCompatibleDC, [hdc]
        mov [hMemDC], eax

        invoke GetClientRect,[hwnd], rect ;client area
        invoke BitBlt, [hdc], [rect.left], [rect.top], [rect.right], [rect.bottom], [hMemDC], 0, 0, BLACKNESS

        invoke CreateCompatibleDC, [hdc]
        mov [hMemDCBlock], eax
        invoke SelectObject, [hMemDCBlock], [hBitmapWalls]
        invoke CreateCompatibleBitmap, [hMemDCBlock], _MAPWIDTH, _MAPWIDTH
        mov [hCompBitmap], eax
        invoke SelectObject, [hMemDC], [hCompBitmap]

        stdcall fillMap
        invoke BitBlt, [hdc], 0, 0, _MAPWIDTH, _MAPWIDTH, [hMemDC], 0, 0, SRCCOPY
;draw tank and enemies
        invoke SelectObject, [hMemDC], [hBitmapTank]
        invoke BitBlt, [hdc], [dst_X], [dst_Y], _BLOCKWIDTH, _BLOCKWIDTH, [hMemDC], [src_X], [src_Y], SRCCOPY
        invoke SelectObject, [hMemDC], [hBitmapEnemy1]
        rept 4 counter {
             cmp [enemyMas.tanksequent#counter], 1
             jne @f
             invoke BitBlt, [hdc], [enemyMas.enemy#counter#.cooX], [enemyMas.enemy#counter#.cooY], _BLOCKWIDTH, _BLOCKWIDTH, [hMemDC], 180, 0, SRCCOPY
             @@:
        }
;end drawing
;draw explosions
        cmp [is_bullet_explosion], 0
        jz .next
        invoke SelectObject, [hMemDC], [hBitmapExplosionMask]

        invoke BitBlt, [hdc], [explosion_X], [explosion_Y], _BLOCKWIDTH, _BLOCKWIDTH, [hMemDC], [src_X_explosion], 0, SRCAND
        invoke SelectObject, [hMemDC], [hBitmapExplosion]

        invoke BitBlt, [hdc], [explosion_X], [explosion_Y], _BLOCKWIDTH, _BLOCKWIDTH, [hMemDC], [src_X_explosion], 0, SRCPAINT
;end drawing
.next:
        ;рисую пулю
        cmp [is_bullet_exists], 1
        jne .deleteobjects
        invoke SelectObject, [hMemDC], [hBitmapPula]
        cmp [bullet_direction], _UP
        jne @f
        invoke BitBlt, [hdc], [bullet_X], [bullet_Y], _BULLETWIDTH, _BULLETWIDTH, [hMemDC], 0, 0, SRCCOPY
        jmp .deleteobjects
@@:
        cmp [bullet_direction], _DOWN
        jne @f
        invoke BitBlt, [hdc], [bullet_X], [bullet_Y], _BULLETWIDTH, _BULLETWIDTH, [hMemDC], _BULLETWIDTH, 0, SRCCOPY
        jmp .deleteobjects
@@:
        cmp [bullet_direction], _LEFT
        jne @f
        mov eax, _BULLETWIDTH
        shl eax, 1
        invoke BitBlt, [hdc], [bullet_X], [bullet_Y], _BULLETWIDTH, _BULLETWIDTH, [hMemDC], eax, 0, SRCCOPY
        jmp .deleteobjects
@@:
        mov eax, _BULLETWIDTH
        shl eax, 1
        add eax, _BULLETWIDTH
        invoke BitBlt, [hdc], [bullet_X], [bullet_Y], _BULLETWIDTH, _BULLETWIDTH, [hMemDC], eax, 0, SRCCOPY
        ;конец рисования пули

.deleteobjects:
        invoke DeleteObject, [hCompBitmap]
        invoke DeleteDC,[hMemDCBlock]
        invoke DeleteDC,[hMemDC]

        invoke EndPaint,[hwnd],ps  ;End painting
        jmp .finish

.wmdestroy:
        invoke PostQuitMessage,0
        xor eax,eax
.finish:
        pop edi esi ebx
        ret
endp

proc TimerProcedure2, hwnd, uMsg, idEvent, dwTime: DWORD
     cmp [is_bullet_explosion], 0
     jz .setexplosion
     cmp [is_bullet_explosion], 1
     jz @f
     mov [is_bullet_explosion], 0
     invoke KillTimer, [hwnd], [idEvent]
     jmp .end
@@:
     ;realization
     inc [is_bullet_explosion]
     mov [src_X_explosion], _BLOCKWIDTH
     jmp .end
.setexplosion:
     mov [is_bullet_explosion], 1
     mov [src_X_explosion], 0
.end:
     invoke InvalidateRect,[hwnd],NULL,FALSE
     ret
endp

proc checkKeyToMove, tank_X, tank_Y, new_direction
        stdcall chooseTankPos, [new_direction]
        stdcall borderCollisionCheck, _TANKID, [new_direction], [dst_X], [dst_Y]
        test eax, eax
        jz .endKey
        cmp [new_direction], _UP
        jnz @f
        sub [tank_Y], _SPEED
        jmp .blockCollision
@@:
        cmp [new_direction], _DOWN
        jnz @f
        add [tank_Y], _SPEED
        jmp .blockCollision
@@:
        cmp [new_direction], _LEFT
        jnz @f
        sub [tank_X], _SPEED
        jmp .blockCollision
@@:
        add [tank_X], _SPEED
.blockCollision:
        stdcall blockCollisionCheckMain, [tank_X], [tank_Y], [new_direction], _TANKID
        cmp eax, 1
        jg .endKey
        test eax, eax
        jz @f
        stdcall movementCorrection, [new_direction]
        test eax, eax
        jnz .endKey
@@:
        stdcall objectMove, _TANKID, [new_direction], 0
.endKey:
        mov eax, [new_direction]
        mov [tank_direction], al
     ret
endp

proc bulletMove
        cmp [is_bullet_exists], 0
        jnz .checkbullet
        cmp [is_shot], 0
        jz .nextkey
        stdcall setBulletCoordinates
        jmp .isnew
.checkbullet:
        stdcall objectMove, _BULLETID, [bullet_direction], 0
.isnew:
        stdcall borderCollisionCheck, _BULLETID, [bullet_direction], [bullet_X], [bullet_Y]
        test eax, eax
        jz .deletebullet
        stdcall blockCollisionCheckMain, [bullet_X], [bullet_Y], [bullet_direction], _BULLETID
        ;функция уничтожения блоков
        stdcall deleteCollapsedBlocks, eax
        test eax, eax
        jnz .deletebullet
        jmp .nextkey
.deletebullet:
        mov [is_bullet_exists], 0
        invoke SetTimer,[hwnd], _TIMERID2, 60, TimerProcedure2 ;set timer
        cmp [bullet_direction], 5
        jg .leftright
        mov eax, [bullet_X]
        sub eax, 11
        mov [explosion_X], eax
        mov eax, [bullet_Y]
        sub eax, 15
        mov [explosion_Y], eax
        jmp .nextkey
.leftright:
        mov eax, [bullet_Y]
        sub eax, 11
        mov [explosion_Y], eax
        mov eax, [bullet_X]
        sub eax, 15
        mov [explosion_X], eax
.nextkey:
        mov [is_shot], 0
        ret
endp

macro enemyMain ordinalNum {
     cmp [enemyMas.tanksequent#ordinalNum], 1
     jnz endd#ordinalNum
     stdcall borderCollisionCheck, _ENEMYID, [enemyMas.enemy#ordinalNum#.direction],\
                                   [enemyMas.enemy#ordinalNum#.cooX],\
                                   [enemyMas.enemy#ordinalNum#.cooY]
     test eax, eax
     jz setNewDirection#ordinalNum
     mov ebx, [enemyMas.enemy#ordinalNum#.speedx]
     mov eax, [enemyMas.enemy#ordinalNum#.cooX]
     mov edx, [enemyMas.enemy#ordinalNum#.cooY]
     cmp [enemyMas.enemy#ordinalNum#.direction], _UP
     jnz .down#ordinalNum
     sub edx, ebx
     stdcall blockCollisionCheckMain, eax, edx, _UP, _ENEMYID
     test eax, eax
     jnz setNewDirection#ordinalNum
     initEnemySimplified \#ordinalNum
     stdcall objectMove, _ENEMYID, _UP, [enemyMas.enemy#ordinalNum#.cooY]
     mov [enemyMas.enemy#ordinalNum#.cooY], eax
     jmp endd#ordinalNum
.down#ordinalNum:
     cmp [enemyMas.enemy#ordinalNum#.direction], _DOWN
     jnz .left#ordinalNum
     add edx, ebx
     stdcall blockCollisionCheckMain, eax, edx, _DOWN, _ENEMYID
     test eax, eax
     jnz setNewDirection#ordinalNum
     initEnemySimplified \#ordinalNum
     stdcall objectMove, _ENEMYID, _DOWN, [enemyMas.enemy#ordinalNum#.cooY]
     mov [enemyMas.enemy#ordinalNum#.cooY], eax
     jmp endd#ordinalNum
.left#ordinalNum:
     cmp [enemyMas.enemy#ordinalNum#.direction], _LEFT
     jnz .right#ordinalNum
     sub eax, ebx
     stdcall blockCollisionCheckMain, eax, edx, _LEFT, _ENEMYID
     test eax, eax
     jnz setNewDirection#ordinalNum
     initEnemySimplified \#ordinalNum
     stdcall objectMove, _ENEMYID, _LEFT, [enemyMas.enemy#ordinalNum#.cooX]
     mov [enemyMas.enemy#ordinalNum#.cooX], eax
     jmp endd#ordinalNum
.right#ordinalNum:
     add eax, ebx
     stdcall blockCollisionCheckMain, eax, edx, _RIGHT, _ENEMYID
     test eax, eax
     jnz setNewDirection#ordinalNum
     initEnemySimplified \#ordinalNum
     stdcall objectMove, _ENEMYID, _RIGHT, [enemyMas.enemy#ordinalNum#.cooX]
     mov [enemyMas.enemy#ordinalNum#.cooX], eax
     jmp endd#ordinalNum
setNewDirection#ordinalNum:
     stdcall Random.Initialize
     stdcall Random.Get, 1, 4
     cmp eax, 1
     jne @f
     mov [enemyMas.enemy#ordinalNum#.direction], _UP
     jmp endd#ordinalNum
@@:
     cmp eax, 2
     jne @f
     mov [enemyMas.enemy#ordinalNum#.direction], _DOWN
     jmp endd#ordinalNum
@@:
     cmp eax, 3
     jne @f
     mov [enemyMas.enemy#ordinalNum#.direction], _LEFT
     jmp endd#ordinalNum
@@:
     mov [enemyMas.enemy#ordinalNum#.direction], _RIGHT
endd#ordinalNum:
}

proc newEnemy
     rept 4 counter{
          cmp [enemyMas.tanksequent#counter], 1
          je end#counter
          initEnemy counter, 1, 3, 0, 30, _DOWN, 1, 10, 0 ;точка спауна
          jmp newEnemy.end
          end#counter:
     }
newEnemy.end:
     ret
endp

proc moveEnemy uses ebx,\
               elapsedTime: DWORD
     mov eax, [elapsedTime]
     xor edx, edx
     mov bx, 4000 ;4 seconds
     div bx
     cmp dx, 30
     ja .main
     stdcall newEnemy
.main:
     rept 4 counter{enemyMain\#counter}
     ret
endp

proc Random.Initialize
        invoke GetLocalTime, st_
        ;movzx eax, [st_.wSecond]
        movzx eax, [st_.wMilliseconds]
        mov [Random.wPrevNumber], eax
        ret
endp

proc Random.Get,\
     wMin, wMax
     mov        eax, [Random.wPrevNumber]
     ;indide possible calculations to upgrade the propability of getting the specific
     ;reminder of devision
     ;mov        [Random.wPrevNumber], eax
     mov        ecx, [wMax]
     sub        ecx, [wMin]
     inc        ecx
     xor        edx, edx
     div        ecx
     add        edx, [wMin]
     mov        eax, edx
     ret
endp


proc TimerProcedure, hwnd, uMsg, idEvent, dwTime: DWORD
        stdcall moveEnemy, [dwTime]
        stdcall bulletMove
        invoke GetKeyState,'W'
        cmp eax, 1
        jbe .keyS
        stdcall checkKeyToMove, [dst_X], [dst_Y], _UP
        jmp .sendDrawMes
.keyS:
        invoke GetKeyState,'S'
        cmp eax, 1
        jbe .keyA
        stdcall checkKeyToMove, [dst_X], [dst_Y], _DOWN
        jmp .sendDrawMes
.keyA:
        invoke GetKeyState,'A'
        cmp eax, 1
        jbe .keyD
        stdcall checkKeyToMove, [dst_X], [dst_Y], _LEFT
        jmp .sendDrawMes
.keyD:
        invoke GetKeyState,'D'
        cmp eax, 1
        jbe .sendDrawMes
        stdcall checkKeyToMove, [dst_X], [dst_Y], _RIGHT
.sendDrawMes:
;перемещение выполнено
        invoke InvalidateRect,[hwnd],NULL,FALSE ;Sends WM_PAINT to window's procedure message processing and some information into PAINSTRUCT
.end:
     ret
endp

proc createBitmapMask, hbmColour, crTransparent
locals
 hbmMask dd ?
 hdcMem dd ?
 hdcMem2 dd ?
endl
     invoke CreateBitmap, _BLOCKWIDTH, _BLOCKWIDTH, 1, 1, NULL
     mov [hbmMask], eax

     invoke CreateCompatibleDC, 0
     mov [hdcMem], eax
     invoke CreateCompatibleDC, 0
     mov [hdcMem2], eax

     invoke SelectObject, [hdcMem], [hbmColour]
     invoke SelectObject, [hdcMem2], [hbmMask]

     invoke SetBkColor, [hdcMem], [crTransparent]

     invoke BitBlt, [hdcMem2], 0, 0, _BLOCKWIDTH, _BLOCKWIDTH, [hdcMem], 0, 0, SRCCOPY
     invoke BitBlt, [hdcMem], 0, 0, _BLOCKWIDTH, _BLOCKWIDTH, [hdcMem2], 0, 0, SRCINVERT

     invoke DeleteDC, [hdcMem]
     invoke DeleteDC, [hdcMem2]

     mov eax, [hbmMask]
     ret
endp

proc movementCorrection, new_direction
locals
 mindistdiff dd 24 ;from 30 - TANKWIDTH
 ten db 10
 cur_block_co dd ?
endl
     ;проверка на будущую корректировку
     cmp byte[tank_direction], 3
     jg @f
     cmp [new_direction], 3
     jg .true
     jmp .failend
@@:
     cmp [new_direction], 3
     jg .failend
.true:
     cmp [tank_direction], 3
     jl .vertical
     mov eax, [blockWereCollapsed]
     div byte[ten]
     mov bl, ah
     mov eax, _BLOCKWIDTH
     mul bl
     mov [cur_block_co], eax
     sub eax, [dst_X]
     cmp eax, 0
     jg .g
@@:
     not eax
     inc eax
     cmp eax, [mindistdiff]
     jl .failend
     mov eax, [cur_block_co]
     add eax, _BLOCKWIDTH
     mov [dst_X], eax
     jmp .end
.g:
     cmp eax, [mindistdiff]
     jl .failend
     mov eax, [cur_block_co]
     sub eax, _BLOCKWIDTH
     mov [dst_X], eax
     jmp .end
.vertical:
     mov eax, [blockWereCollapsed]
     div byte[ten]
     mov bl, al
     mov eax, _BLOCKWIDTH
     mul bl
     mov [cur_block_co], eax
     sub eax, [dst_Y]
     cmp eax, 0
     jg .vg
@@:
     not eax
     inc eax
     cmp eax, [mindistdiff]
     jl .failend
     mov eax, [cur_block_co]
     add eax, _BLOCKWIDTH
     mov [dst_Y], eax
     jmp .end
.vg:
     cmp eax, [mindistdiff]
     jl .failend
     mov eax, [cur_block_co]
     sub eax, _BLOCKWIDTH
     mov [dst_Y], eax
     jmp .end
.failend:
     mov eax, -1
     jmp .ending
.end:
     mov eax, 0
.ending:

     ret
endp

proc deleteCollapsedBlocks, countofblocks
     cmp [countofblocks], 0
     jz .noblocks
     mov ecx, [countofblocks]
.deletecycle:
     movzx ebx, byte[blockWereCollapsed+ecx-1]
     mov byte[bufMap+ebx], 0
     loop .deletecycle
     mov eax, [countofblocks]
     jmp .end
.noblocks:
     mov eax, 0
.end:
     ret
endp

proc setBulletCoordinates
        mov [is_bullet_exists], 1
        cmp [tank_direction], _UP
        jne @f
        mov [bullet_direction], _UP
        mov edx, [dst_X]
        add edx, 11
        mov [bullet_X], edx
        mov edx, [dst_Y]
        sub edx, _BULLETWIDTH
        mov [bullet_Y], edx
        jmp .end
@@:
        cmp [tank_direction], _DOWN
        jne @f
        mov [bullet_direction], _DOWN
        mov edx, [dst_X]
        add edx, 11
        mov [bullet_X], edx
        mov edx, [dst_Y]
        add edx, _BLOCKWIDTH
        mov [bullet_Y], edx
        jmp .end
@@:
        cmp [tank_direction], _LEFT
        jne @f
        mov [bullet_direction], _LEFT
        mov edx, [dst_X]
        sub edx, _BULLETWIDTH
        mov [bullet_X], edx
        mov edx, [dst_Y]
        add edx, 11
        mov [bullet_Y], edx
        jmp .end
@@:
        mov [bullet_direction], _RIGHT
        mov edx, [dst_X]
        add edx, _BLOCKWIDTH
        mov [bullet_X], edx
        mov edx, [dst_Y]
        add edx, 11
        mov [bullet_Y], edx
.end:
     ret
endp

proc borderCollisionCheck, elementid, direction, coox, cooy ;eax = 0 - collision occured, else - 1
locals
 four db 4
 result dd 1
 curposition dd ?
 width dd ?
endl
        cmp [elementid], _TANKID
        jne .nextid
        mov [width], _BLOCKWIDTH
        cmp [direction], 4
        jge @f
        mov eax, [cooy]
        mov [curposition], eax
        jmp .nextstep
@@:
        mov eax, [coox]
        mov [curposition], eax
        jmp .nextstep
.nextid:
        cmp [elementid], _BULLETID
        jne .nextsecid
        mov [width], _BULLETWIDTH
        cmp [direction], 4
        jge @f
        mov eax, [cooy]
        mov [curposition], eax
        jmp .nextstep
@@:
        mov eax, [coox]
        mov [curposition], eax
        jmp .nextstep
.nextsecid:
        mov [width], _BLOCKWIDTH
        cmp [direction], 4
        jge @f
        mov eax, [cooy]
        mov [curposition], eax
        jmp .nextstep
@@:
        mov eax, [coox]
        mov [curposition], eax
.nextstep:
        mov eax, [direction]
        div [four]
        test ah, ah
        jnz @f
        cmp [curposition], 0
        jg .endMove
        mov [result], 0
        jmp .endMove
@@:
        mov edx, _MAPWIDTH
        sub edx, [width]
        cmp [curposition], edx
        jl .endMove
        mov [result], 0
.endMove:
        mov eax, [result]
        ret
endp

proc blockCollisionCheckMain uses ebx,\
                             ltx, lty, direction, elementid  ;returns the number of block were collapsed
locals
 rtx dd ?
 rty dd ?
 lbx dd ?
 lby dd ?
 oppCornerDistTank dd 29
 oppCornerDistBullet dd 7
 oppCornerDist dd ?
endl
     cmp [elementid], _ENEMYID
     jz .tanksid
     cmp [elementid], _TANKID
     jnz .bulletid
.tanksid:
     mov eax, [oppCornerDistTank]
     mov [oppCornerDist], eax
     jmp .next
.bulletid:
     mov eax, [oppCornerDistBullet]
     mov [oppCornerDist], eax
.next:
     ;вычисление углов
     mov eax, [ltx]
     mov [lbx], eax
     add eax, [oppCornerDist]
     mov [rtx], eax
     mov eax, [lty]
     mov [rty], eax
     add eax, [oppCornerDist]
     mov [lby], eax
.up:
     cmp [direction], _UP
     jnz .down
     stdcall blockCollisionCheck, [ltx], [lty], _UP, [oppCornerDist], [elementid]
     jmp .endCollision
.down:
     cmp [direction], _DOWN
     jnz .left
     stdcall blockCollisionCheck, [lbx], [lby], _DOWN, [oppCornerDist], [elementid]
     jmp .endCollision
.left:
     cmp [direction], _LEFT
     jnz .right
     stdcall blockCollisionCheck, [ltx], [lty], _LEFT, [oppCornerDist], [elementid]
     jmp .endCollision
.right:
     stdcall blockCollisionCheck, [rtx], [rty], _RIGHT, [oppCornerDist], [elementid]
.endCollision:
     ret
endp

proc objectMove, elementid, direction, coo
     cmp [elementid], _ENEMYID
     jnz .uptank
     cmp [direction], _UP
     jnz .downenemy
     sub [coo], _SPEED ;must be set to [enemyMas.enemy1.speedx]
     mov eax, [coo]
     jmp .endMove
.uptank:
     cmp [elementid], _TANKID
     jnz .upbullet
     cmp [direction], _UP
     jnz .downtank
     sub [dst_Y], _SPEED
     jmp .endMove
.upbullet:
     cmp [direction], _UP
     jnz .downbullet
     sub [bullet_Y], _BULLETSPEED
     jmp .endMove
.downenemy:
     cmp [direction], _DOWN
     jnz .leftenemy
     add [coo], _SPEED
     mov eax, [coo]
     jmp .endMove
.downtank:
     cmp [direction], _DOWN
     jnz .lefttank
     add [dst_Y], _SPEED
     jmp .endMove
.downbullet:
     cmp [direction], _DOWN
     jnz .leftbullet
     add [bullet_Y], _BULLETSPEED
     jmp .endMove
.leftenemy:
     cmp [direction], _LEFT
     jnz .rightenemy
     sub [coo], _SPEED
     mov eax, [coo]
     jmp .endMove
.lefttank:
     cmp [direction], _LEFT
     jnz .righttank
     sub [dst_X], _SPEED
     jmp .endMove
.leftbullet:
     cmp [direction], _LEFT
     jnz .rightbullet
     sub [bullet_X], _BULLETSPEED
     jmp .endMove
.rightenemy:
     add [coo], _SPEED
     mov eax, [coo]
     jmp .endMove
.righttank:
     add [dst_X], _SPEED
     jmp .endMove
.rightbullet:
     add [bullet_X], _BULLETSPEED
.endMove:
     ret
endp

proc calkEnemyBlock, row, column, destination
locals
 ten db 10
 blocknumber dd ?
endl
     mov eax, [row]
     mul [ten]
     add eax, [column]
     mov [blocknumber], eax

     mov ebx, eax
     movzx eax, byte[bufMap+ebx]
     ;comparance with blocks
     cmp eax, 0
     jz .endCollision
     mov eax, -1
     jmp .end
.endCollision:
     mov eax, [blocknumber]
.end:
     ret
endp

proc blockCollisionCheck uses ebx, x, y, destination, oppCornerDist, elementid ;returns the number of block were collapsed; fills the massive of blocks were collapsed
locals
 blockwidth dd _BLOCKWIDTH
 column dd 0
 row dd 0
 blockCollisionCount dd 0
endl
     xor edx, edx
     mov eax, [y]
     div [blockwidth]
     mov word[row], ax
     xor edx, edx
     mov eax, [x]
     div [blockwidth]
     mov word[column], ax
     stdcall calcBlock, [row], [column], [destination]
     cmp eax, -1
     jz @f
     mov [blockCollisionCount], 1
     mov [blockWereCollapsed], eax
@@:
     cmp [elementid], _ENEMYID
     jne @f
     stdcall calkEnemyBlock, [row], [column], [destination]
     cmp eax, -1
     jz @f
     mov [a], 1
     mov [b], eax
@@:
     cmp [destination], _DOWN
     jg @f
     xor edx, edx
     mov eax, [x]
     add eax, [oppCornerDist]
     div [blockwidth]
     mov word[column], ax
     jmp .check
@@:
     xor edx, edx
     mov eax, [y]
     add eax, [oppCornerDist]
     div [blockwidth]
     mov word[row], ax
.check:
     stdcall calcBlock, [row], [column], [destination]
     cmp eax, -1
     jz @f
     mov ebx, [blockCollisionCount]
     mov [blockWereCollapsed+ebx], eax
     inc [blockCollisionCount]
@@:
     cmp [elementid], _ENEMYID
     jne .end
.forenemy:
     cmp [destination], _UP
     jne @f
     xor edx, edx
     mov eax, [y]
     add eax, [oppCornerDist]
     div [blockwidth]
     mov word[row], ax
     jmp .check2
@@:
     cmp [destination], _DOWN
     jne @f
     xor edx, edx
     mov eax, [y]
     sub eax, [oppCornerDist]
     div [blockwidth]
     mov word[row], ax
     jmp .check2
@@:
     cmp [destination], _LEFT
     jne @f
     xor edx, edx
     mov eax, [x]
     add eax, [oppCornerDist]
     div [blockwidth]
     mov word[column], ax
     jmp .check2
@@:
     xor edx, edx
     mov eax, [x]
     sub eax, [oppCornerDist]
     div [blockwidth]
     mov word[column], ax
.check2:
     stdcall calkEnemyBlock, [row], [column], [destination]
     cmp eax, -1
     jz .end
     mov ebx, [a]
     mov [b+ebx*4], eax
     inc [a]
.end:
     mov eax, [blockCollisionCount]
    ret
endp

proc calcBlock uses ebx, row, column, destination ;returns the block number if collision occurs - i don't need to check next point; otherwise returns -1
locals
 ten db 10
 blocknumber dd ?
endl
     mov eax, [row]
     mul [ten]
     add eax, [column]
     mov [blocknumber], eax

     mov ebx, eax
     movzx eax, byte[bufMap+ebx]
     ;comparance with blocks
     cmp eax, _BRICK
     jz .endCollision
     cmp eax, 3
     jz .endCollision
     mov eax, -1
     jmp .end
.endCollision:
     mov eax, [blocknumber]
.end:
     ret
endp

proc chooseTankPos, direction
     mov eax, [direction]
     cmp [tank_direction], al
     jz isOk
     ;mov [tank_direction], al
     mov [frame], al
     jmp endChoose
isOk:
     test [frame], 1
     jnz odd
     inc [frame]
     jmp endChoose
odd:
     dec [frame]
     movzx ebx, [frame]

endChoose:
     mov eax, 30
     mul [frame]
     xchg eax, [src_X]
     ret
endp

proc fillMap uses ebx
locals
 row dd 0
 column dd 0
 map_size dd 100
endl
        invoke SelectObject, [hMemDCBlock], [hBitmapWalls]
        mov ecx, [map_size]
        xor ebx, ebx
_mainLoop:
        push ecx
        cmp byte[bufMap+ebx], 1
        jnz @f
        invoke SelectObject, [hMemDCBlock], [hBitmapWalls]
        jmp _draw
@@:
        cmp byte[bufMap+ebx], 2
        jnz _main
        invoke SelectObject, [hMemDCBlock], [hBitmapGround]
_draw:
        invoke BitBlt, [hMemDC], [column], [row], _BLOCKWIDTH, _BLOCKWIDTH, [hMemDCBlock], 0, 0, SRCCOPY
_main:
        pop ecx
        mov eax, [column]
        add eax, _BLOCKWIDTH
        cmp eax, _MAPWIDTH
        jb @f
        mov eax, _BLOCKWIDTH
        add [row], eax
        xor eax, eax
@@:
        mov [column], eax
        inc ebx
        loop _mainLoop

        ret
endp


section '.idata' import data readable writeable

        library gdi32,'GDI32.DLL',\
                kernel32,'KERNEL32.DLL',\
                user32,'USER32.DLL'

        include 'api\gdi32.inc'
        include 'api\kernel32.inc'
        include 'api\user32.inc'

section '.rsrc' resource data readable

        directory RT_BITMAP,bitmaps,\
                  RT_CURSOR,cursors,\
                  RT_GROUP_CURSOR,group_cursors,\
                  RT_ICON,icons,\
                  RT_GROUP_ICON,group_icons;,\
                  ;RT_VERSION,versions

        resource icons,\
                 48,LANG_NEUTRAL,icon_48

        resource group_icons,\
                 17,LANG_NEUTRAL,main_icon
        resource cursors,\
                 2,LANG_NEUTRAL,cursor_data
        resource group_cursors,\
                 27,LANG_NEUTRAL,main_cursor
        ;resource versions,\
                 ;8,LANG_ENGLISH+SUBLANG_DEFAULT,version
        resource bitmaps,\
                 37,LANG_NEUTRAL,pict,\
                 38,LANG_NEUTRAL,pict2,\
                 _WALLS,LANG_NEUTRAL,walls_pict,\
                 _GROUND,LANG_NEUTRAL,ground,\
                 _PULA,LANG_NEUTRAL,pula,\
                 56, LANG_NEUTRAL, explosion

bitmap pict,'DDRAW.bmp'
bitmap pict2,'tankk.bmp'
bitmap walls_pict,'walls.bmp'
bitmap ground, 'ground.bmp'
bitmap pula, 'bullet.bmp'
bitmap explosion, 'explosion.bmp'
icon main_icon,icon_48,'bomb.ico'
cursor main_cursor,cursor_data,'Arrow.cur'