

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
                             ltx, lty, direction, elementid, ordinalNum  ;returns the number of block were collapsed
locals
 rtx dd ?
 rty dd ?
 lbx dd ?
 lby dd ?
 rbx dd ?
 rby dd ?
 oppCornerDistTank dd 29
 oppCornerDistBullet dd 7
 oppCornerDist dd ?
 error dd 0
endl
     mov [Motion.blockCollisionCount], 0
     mov [Motion.blockWereCollapsed], 0
     mov [Motion.blockWereCollapsed+4], 0

     mov [a], 0
     mov [b], 0
     mov [b+4], 0

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
     mov [rbx], eax
     mov eax, [lty]
     mov [rty], eax
     add eax, [oppCornerDist]
     mov [lby], eax
     mov [rby], eax
.up:
     cmp [direction], _UP
     jnz .down
     stdcall blockCollisionCheck, [ltx], [lty], [ordinalNum], -1, 0
     stdcall blockCollisionCheck, [rtx], [rty], [ordinalNum], [lbx], [lby]
     jmp .end
.down:
     cmp [direction], _DOWN
     jnz .left
     stdcall blockCollisionCheck, [lbx], [lby], [ordinalNum], -1, 0
     stdcall blockCollisionCheck, [rbx], [rby], [ordinalNum], [ltx], [lty]
     jmp .end
.left:
     cmp [direction], _LEFT
     jnz .right
     stdcall blockCollisionCheck, [ltx], [lty], [ordinalNum], -1, 0
     stdcall blockCollisionCheck, [lbx], [lby], [ordinalNum], [rtx], [rty]
     jmp .end
.right:
     cmp [direction], _RIGHT
     jz @f
     mov [error], 1
     jmp .end
@@:
     stdcall blockCollisionCheck, [rtx], [rty],[ordinalNum], -1, 0
     stdcall blockCollisionCheck, [rbx], [rby],[ordinalNum], [ltx], [lty]
.end:
     mov eax, [error]
     ret
endp


proc blockCollisionCheck uses ebx,\
                         objx, objy, ordinal_num, exobjx, exobjy ;returns the number of block were collapsed; fills the massive of blocks were collapsed
locals
 ord_num_block dd ?
endl
     stdcall MCALCORDNUMOFBLOCK, [objx], [objy]
     mov [ord_num_block], eax
     stdcall MCOMPARCOLLISION, eax, [ordinal_num]
     cmp eax, -1
     jnz .collision
     cmp [exobjx], -1
     jnz .here
     mov eax, [ord_num_block]
     mov ebx, [a]
     shl ebx, 2
     mov [b+ebx], eax
     inc [a]
     jmp .end
.collision:
     mov ebx, [Motion.blockCollisionCount]
     shl ebx, 2
     mov [Motion.blockWereCollapsed+ebx], eax
     inc [Motion.blockCollisionCount]
.here:
      cmp [exobjx], -1
      jz .end
      stdcall MCALCORDNUMOFBLOCK, [exobjx], [exobjy]
      mov ebx, [a]
      shl ebx, 2
      mov [b+ebx], eax
      inc [a]
      mov eax, -1
.end:
    ret
endp

proc MCOMPARCOLLISION uses ebx,\
                           ord_num_block, ordinal_num ;returns -1 - not collapsed
;comparator
     mov ebx, [ord_num_block]
     movzx eax, byte[bufMap+ebx]

     ;comparance with blocks
     cmp eax, _BRICK
     jz .endCollision
     cmp eax, _TANKBLOCK
     jnz .endNotCollision
     cmp [ordinal_num], 0
     jz .endCollision
     stdcall isMyBlock, [ord_num_block], [ordinal_num]
     test eax, eax
     jnz .endNotCollision
.endCollision:
     mov eax, [ord_num_block]
     jmp .end
.endNotCollision:
     mov eax, -1
.end:
     ret
endp

proc isMyBlock uses ebx,\
                    ord_num_block, ordinal_num
     xor ebx, ebx
     dec [ordinal_num]
     cmp [ordinal_num], 0
     jz .next
     mov ecx, [ordinal_num]
@@:
     add ebx, sizeof.TANK
     loop @b
.next:
     add ebx, sizeof.pred
     lea eax, [enemyMas+ebx]
     mov ebx, eax
     add ebx, sizeof.amOccupiedBl
     mov ecx, [ebx]
     add ebx, 4
     mov eax, [ord_num_block]
@@:
     cmp eax, [ebx]
     je @f
     add ebx, 4
     loop @b
     mov eax, 0
     jmp .end
@@:
     mov eax, 1
.end:
    ret
endp

proc MCALCORDNUMOFBLOCK x, y
locals
 ;row doesn't needed, watch code below
 column dd ?
endl
     mov ecx, _BLOCKWIDTH

     xor edx, edx
     mov eax, [x]
     div ecx
     mov [column], eax

     xor edx, edx
     mov eax, [y]
     div ecx
     ;in eax row
     mov cl, 10
     mul cl
     add eax, [column]
     ret
endp