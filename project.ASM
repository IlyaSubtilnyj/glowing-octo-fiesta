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
is_bullet_exists db 0
bullet_X dd ?
bullet_Y dd ?
explosion_X dd ?
explosion_Y dd ?
blockWereCollapsed dd 2 dup(0)

rect RECT

bufMap db 4 dup(1), 0, 0, 4 dup(1), 20 dup(0), 4 dup(1), 0, 0, 4 dup(1), 60 dup(1)

numberBitestoRead dw ?

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
@@:
     cmp eax,WM_TIMER
     jne @f
     cmp [wparam], _TIMERID
     je .wmtimer
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
        invoke LoadBitmap,[wc.hInstance],_WALLS
        mov [hBitmapWalls],eax
        invoke LoadBitmap,[wc.hInstance],_GROUND
        mov [hBitmapGround],eax
        invoke LoadBitmap,[wc.hInstance],_PULA
        mov [hBitmapPula],eax
        invoke LoadBitmap,[wc.hInstance],56
        mov [hBitmapExplosion],eax
        invoke LoadBitmap,[wc.hInstance],57
        mov [hBitmapExplosionMask],eax
        invoke SetTimer,[hwnd], _TIMERID, 28, NULL ;set timer
        jmp .finish

.wmtimer:
;обработчик пули поместить после процедуры таймера!!!потомучто пуля отрисовывается за границами карты
;доделать обработуик проверки на нраницы карты, переименовать его!!!
;добавить идентификатор танку и пуле
        cmp [is_bullet_exists], 1
        jz .checkbullet
        cmp [is_shot], 1
        jnz .nextkey
        mov [is_bullet_exists], 1
        stdcall setBulletCoordinates
        jmp .isnew
.checkbullet:
        stdcall objectMove, _BULLETID, [bullet_direction]
.isnew:
        stdcall borderCollisionCheck, _BULLETID, [bullet_direction]
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
        mov [is_bullet_explosion], 1
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
        invoke GetKeyState,'W'
        cmp eax, 1
        jbe .keyS
        stdcall chooseTankPos,_UP
        stdcall borderCollisionCheck, _TANKID, _UP
        test eax, eax
        jz .endKeyW
        mov eax, [dst_Y]
        sub eax, _SPEED
        stdcall blockCollisionCheckMain, [dst_X], eax, _UP, _TANKID
        cmp eax, 1
        jg .endKeyW
        test eax, eax
        jz @f
        stdcall movementCorrection, _UP
        test eax, eax
        jnz .endKeyW
@@:
        stdcall objectMove, _TANKID, _UP
.endKeyW:
        mov [tank_direction], _UP
        jmp .sendDrawMes
.keyS:
        invoke GetKeyState,'S'
        cmp eax, 1
        jbe @f
        stdcall chooseTankPos,_DOWN
        mov [tank_direction], _DOWN ;поменять
        stdcall borderCollisionCheck, _TANKID, _DOWN
        test eax, eax
        jz .sendDrawMes
        mov eax, [dst_Y]
        add eax, _SPEED
        stdcall blockCollisionCheckMain, [dst_X], eax, _DOWN, _TANKID
        test eax, eax
        jnz .sendDrawMes
        stdcall objectMove, _TANKID, _DOWN
        jmp .sendDrawMes
@@:
        invoke GetKeyState,'A'
        cmp eax, 1
        jbe @f
        stdcall chooseTankPos,_LEFT
        mov [tank_direction], _LEFT
        stdcall borderCollisionCheck, _TANKID, _LEFT
        test eax, eax
        jz .sendDrawMes
        stdcall movementCorrection, _LEFT
        mov eax, [dst_X]
        sub eax, _SPEED
        stdcall blockCollisionCheckMain, eax, [dst_Y], _LEFT, _TANKID
        test eax, eax
        jnz .sendDrawMes
        stdcall objectMove, _TANKID, _LEFT

        jmp .sendDrawMes
@@:
        invoke GetKeyState,'D'
        cmp eax, 1
        jbe .sendDrawMes
        stdcall chooseTankPos,_RIGHT
        mov [tank_direction], _RIGHT
        stdcall borderCollisionCheck, _TANKID, _RIGHT
        test eax, eax
        jz .sendDrawMes
        mov eax, [dst_X]
        add eax, _SPEED
        stdcall blockCollisionCheckMain, eax, [dst_Y], _RIGHT, _TANKID
        test eax, eax
        jnz .sendDrawMes
        stdcall objectMove, _TANKID, _RIGHT


.sendDrawMes:
;перемещение выполнено
        invoke InvalidateRect,[hwnd],NULL,FALSE ;Sends WM_PAINT to window's procedure message processing and some information into PAINSTRUCT
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

        invoke SelectObject, [hMemDC], [hBitmapTank]
        invoke BitBlt, [hdc], [dst_X], [dst_Y], _BLOCKWIDTH, _BLOCKWIDTH, [hMemDC], [src_X], [src_Y], SRCCOPY
;рисую взрыв
        cmp [is_bullet_explosion], 0
        je .next
        cmp [is_bullet_explosion], 2
        jg .null
        jz @f
        mov eax, 0
        jmp .paint
@@:
        mov eax, _BLOCKWIDTH

.paint:
        push eax
        invoke SelectObject, [hMemDC], [hBitmapExplosionMask]
        pop eax
        push eax
        invoke BitBlt, [hdc], [explosion_X], [explosion_Y], _BLOCKWIDTH, _BLOCKWIDTH, [hMemDC], eax, 0, SRCAND
        invoke SelectObject, [hMemDC], [hBitmapExplosion]
        pop eax
        invoke BitBlt, [hdc], [explosion_X], [explosion_Y], _BLOCKWIDTH, _BLOCKWIDTH, [hMemDC], eax, 0, SRCPAINT
        inc [is_bullet_explosion]
        jmp .next
.null:
        mov [is_bullet_explosion], 0
;отрисовал взрыв
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
     jl .failend
     mov eax, [blockWereCollapsed]
     div byte[ten]
     mov bl, ah
     mov eax, _BLOCKWIDTH
     mul bl
     mov [cur_block_co], eax
     sub eax, [dst_X]
     cmp eax, 0
     jg @f
     not eax
     inc eax
@@:
     cmp eax, [mindistdiff]
     jl .failend
     cmp [tank_direction], _RIGHT
     jnz @f
     mov eax, [cur_block_co]
     add eax, _BLOCKWIDTH
     mov [dst_X], eax
     jmp .end
@@:
     mov eax, [cur_block_co]
     sub eax, _BLOCKWIDTH
     mov [dst_X], eax
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

proc borderCollisionCheck, elementid, direction ;eax = 0 - collision occured, else - 1
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
        mov eax, [dst_Y]
        mov [curposition], eax
        jmp .nextstep
@@:
        mov eax, [dst_X]
        mov [curposition], eax
        jmp .nextstep
.nextid:
        cmp [elementid], _BULLETID
        jne .endMove
        mov [width], _BULLETWIDTH
        cmp [direction], 4
        jge @f
        mov eax, [bullet_Y]
        mov [curposition], eax
        jmp .nextstep
@@:
        mov eax, [bullet_X]
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

proc blockCollisionCheckMain uses ebx, ltx, lty, direction, elementid  ;returns the number of block were collapsed
locals
 rtx dd ?
 rty dd ?
 lbx dd ?
 lby dd ?
 oppCornerDistTank dd 29
 oppCornerDistBullet dd 7
 oppCornerDist dd ?
endl
     cmp [elementid], _TANKID
     jnz .bulletid
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
     stdcall blockCollisionCheck, [ltx], [lty], _UP, [oppCornerDist]
     jmp .endCollision
.down:
     cmp [direction], _DOWN
     jnz .left
     stdcall blockCollisionCheck, [lbx], [lby], _DOWN, [oppCornerDist]
     jmp .endCollision
.left:
     cmp [direction], _LEFT
     jnz .right
     stdcall blockCollisionCheck, [ltx], [lty], _LEFT, [oppCornerDist]
     jmp .endCollision
.right:
     stdcall blockCollisionCheck, [rtx], [rty], _RIGHT, [oppCornerDist]
.endCollision:
     ret
endp

proc objectMove, elementid, direction
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
.righttank:
     add [dst_X], _SPEED
     jmp .endMove
.rightbullet:
     add [bullet_X], _BULLETSPEED
.endMove:
     ret
endp

proc blockCollisionCheck uses ebx, x, y, destination, oppCornerDist ;returns the number of block were collapsed; fills the massive of blocks were collapsed
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
     jz .end
     mov ebx, [blockCollisionCount]
     mov [blockWereCollapsed+ebx], eax
     inc [blockCollisionCount]
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
                 56, LANG_NEUTRAL, explosion,\
                 57, LANG_NEUTRAL, explosionmask

bitmap pict,'../work_space/DDRAW.bmp'
bitmap pict2,'../work_space/tankk.bmp'
bitmap walls_pict,'../work_space/walls.bmp'
bitmap ground, '../work_space/ground.bmp'
bitmap pula, '../work_space/bullet.bmp'
bitmap explosion, '../work_space/explosion.bmp'
bitmap explosionmask, '../work_space/explosionmask.bmp'
icon main_icon,icon_48,'../work_space/bomb.ico'
cursor main_cursor,cursor_data,'../work_space/Arrow.cur'