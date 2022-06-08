;=============================================================================
; 32-bit Assembly Example
;
; Empty asm example.
;=============================================================================
IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "VIDEO.inc"
;=============================================================================
; Uninitialized DATA
;=============================================================================
UDATASEG

;=============================================================================
; DATA
;=============================================================================
DATASEG

;=============================================================================
; CODE
;=============================================================================
CODESEG

;-----------------------------------------------------------------------?
; Entry To ASM Code
; In:
;   CS - Code Selector    Base: 00000000h - Limit: 4G
;   DS - Data Selector    Base: 00000000h - Limit: 4G
;   ES - PSP Selector     Base: PSP Seg   - Limit: 100h
;   FS - ?
;   GS - ?
;   SS - Data Selector    Base: 00000000h - Limit: 4G
;   ESP -> STACK segment
;   Direction Flag - ?
;   Interrupt Flag - ?
;
;   All Other Registers Are Undefined!

PROC setupVideo
	USES eax
	mov ax,13h
	
	int 10h
	ret
ENDP setupVideo
;-----------------------------------------------------------------------?
PROC unsetupVideo
	USES eax
	mov ax,03h
	
	int 10h
	ret
ENDP unsetupVideo
;-----------------------------------------------------------------------?
PROC drawAll
	USES eax, ecx, edx
	ARG OffsetscreenBuffer:dword, screenDataArrayLimit:dword
	call waitVBlank
	cld
	mov esi , [OffsetscreenBuffer] ; points to a "db 64000 dup( ? ) " array
	mov edi , 0a0000h ; the video memory
	xor edx, edx
	mov eax, [screenDataArrayLimit]
	mov ecx, 4
	div ecx
	mov ecx, eax ; (320 * 200)/4 , but copy groups four bytes
	rep movsd ; moves a dword and updates ecx , esi and edi	
	ret
ENDP drawAll
;-----------------------------------------------------------------------?

PROC waitVBlank
	mov dx , 03dah ; VGA status port
		@@waitVBlank_wait1 : ; if already in VB, then wait until VB finishes
		in al , dx ; read status
		and al , 8 ; testbit3
	jnz @@waitVBlank_wait1 ; busy wait if in VB
	
	@@waitVBlank_wait2 : ; wait until begin of a new VB
		in al , dx ; read status
		and al , 8 ; testbit 3
	jz @@waitVBlank_wait2 ; busy wait if NOT in VB
	ret
ENDP waitVBlank

END