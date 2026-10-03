; invincible.asm
; SET UP menu hook that draws the INVINCIBLE option, and damage hook that ignores player damage while it is on.
;
; Written by Derek Pascarella (ateam)

bits 32

; Replaces "mov esi,SETUP_LIST" in the SET UP draw routine.
draw_hook:
	pushad
	mov esi,LABEL_LIST
	call DRAW_LIST
	mov esi,OFF_LIST
	cmp word [FLAG],0
	je .draw
	mov esi,ON_LIST
.draw:
	call DRAW_LIST
	popad
	mov esi,SETUP_LIST
	ret

; Replaces "movsx ax,al / sub [ebx+0x88],ax" in the damage routine (EBX+0x88 is HP).
damage_hook:
	movsx ax,al
	cmp word [FLAG],0
	je .apply
	cmp ebx,PLAYER_1P
	je .zero
	cmp ebx,PLAYER_2P
	jne .apply
.zero:
	xor ax,ax
.apply:
	sub [ebx+0x88],ax
	ret
