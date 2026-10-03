; cell_builder.asm
; Builds a 16x16 text cell from two 8x16 English characters, replacing the Japanese glyph lookup in all three text renderers.
;
; Written by Derek Pascarella (ateam)

bits 32

cell_builder:
	push eax
	push ebx
	push ecx
	push edi
	lea eax,[esi*2+ENGLISH_TEXT-SCRIPT*2]
	movzx ebx,byte [eax]
	movzx ecx,byte [eax+1]
	shl ebx,5
	shl ecx,5
	add ebx,ENGLISH_FONT-0x400
	add ecx,ENGLISH_FONT-0x400
	mov edi,CELL_BUFFER
	mov esi,16
.row:
	movzx eax,word [ecx]
	shl eax,16
	mov ax,[ebx]
	mov [edi],eax
	add edi,4
	add ebx,2
	add ecx,2
	dec esi
	jnz .row
	mov esi,CELL_BUFFER
	pop edi
	pop ecx
	pop ebx
	pop eax
	ret
