IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "VIDEO.inc"
INCLUDE "RAND.inc"
; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG

SCREEN_WIDTH = 320
SCREEN_HEIGHT = 200
WIDTH_SCALE = SCREEN_WIDTH/320 ; could be used to scale the maze according to the width and height of the screen 
HEIGHT_SCALE = SCREEN_HEIGHT/200
SCREEN_DATALIMIT = SCREEN_HEIGHT * SCREEN_WIDTH ; the maximum amount of data array you can make to represent the screen


COLOR_SNAKE = 2 	;green
COLOR_FOOD = 4		;red
COLOR_POISON = 3 	;cyan
COLOR_BOOSTER = 5	;magenta
COLOR_WALL = 1		;blue

START_LEN = 10
SNAKE_SPEED = 2 ; recommended  between 1 and 20 => 1 = fastest snakespeed

; score incrementation/decrementation
FOOD_ADD = 1
POISON_FOOD_SUB = 2
BOOSTER_FOOD_ADD = 5 * FOOD_ADD
FOOD_BIGNESS = 5 ; how big the food will be (recommended 1-9)

WAIT_MILLISECONDS = 80 ; amount of milliseconds to wait during first startup of the game (look into initGame for more info)
WAIT_SECONDS = 3 ; amount of seconds to wait during first startup of the game (look into initGame for more info)

PAUZE_SCREEN_HEIGHT = 1 ; height of the pauze and ending screen

PROC welcomeWindow
	USES eax, edx
	
	; printing message
	mov ah, 09h
	mov edx, offset welcomeMessage
	int 21h	
	
	@@getKey:
		mov ah, 00h	
		int 16h
		cmp ah, 28	;ENTER
		
		je @@return
		cmp al, 61h ; a
		je @@speed1
		cmp al, 7Ah ; z
		je @@speed2
		cmp al, 65h ; e
		je @@speed3
		
		cmp al, 30h ; 0
		jge @@foodBigness
		
		cmp ah, 01	;ESC
		jne @@getKey
		call exitGame
		
	@@speed1:
		mov [snakeSpeed], 1
		jmp @@getKey
	@@speed2:
		mov [snakeSpeed], 2
		jmp @@getKey
	@@speed3:
		mov [snakeSpeed], 3
		jmp @@getKey
		
	@@foodBigness:
		cmp al, 3Ah; check if the number is between 0-9
		jg @@getKey
		
		sub al, 30h ; subtract the excessive unicode
		mov bl, al
		xor eax, eax
		mov al, bl
		mov [foodBigness], eax
		jmp @@getKey
		
	@@return:
		ret	
ENDP welcomeWindow

PROC showScore
	USES eax, ebx, ecx, edx
	
	; setting up cursor position
	mov edx, PAUZE_SCREEN_HEIGHT ; y-position (row)
	mov ebx, 0 ; x-position (column)
	mov ah, 02h ; set cursor position
	shl edx, 08h ; row in dh (00h is top)
	mov dl, bl ; column in dl (00h is left)
	mov bh, 0 ; page number in bh
	int 10h
	
	; printing messsage 
	mov ah, 09h
	mov edx, offset exitMessage
	int 21h
	
	mov eax, [score]
	xor ebx, ebx
	mov ecx, 10
	@@toChars: ; converting the score number to unicode possible to be printed later
		xor edx, edx
		div ecx
		add edx, 48
		push edx
		inc ebx
		cmp eax, 0
	jnz @@toChars
	
	@@print:
		pop edx
		mov ah, 2
		int 21h
		dec ebx
		cmp ebx,0
	jnz @@print
	
	@@getKeystroke:
		mov ah, 00h	; call int 16h to get keystroke	
		int 16h
		cmp ah, 01 ; ESC
		je @@return
		cmp al, 70h ; p
		jne @@getKeystroke
	@@return:
		ret	
ENDP showScore

; gives a random position that's not colliding with the snake nor colliding with a wall, used for new spawned foods
PROC newFood
	@@randPos:
		call rand, SCREEN_DATALIMIT
		cmp [_screenBuffer + eax], COLOR_SNAKE ;check if snake
		je @@randPos
		cmp [_screenBuffer + eax], COLOR_WALL ;check if wall
		je @@randPos
		call foodWallCollision, eax ; detects if food spawned on top of a wall
		cmp esi, 1
		je @@randPos
		ret
ENDP newFood

; gives a random position that's not colliding with any wall, used when spawning the snake.
PROC newSnake
	@@randPos:
		call rand, SCREEN_DATALIMIT
		cmp [_screenBuffer + eax], COLOR_WALL ;check if wall
		je @@randPos
		ret
ENDP newSnake

PROC initGame
	USES eax, ebx, ecx, edx, esi
	ARG waitSeconds:dword, waitMilliseconds:byte
	
	call makeMaze
	
	; CREATE SNAKE
	call rand_init
	call newSnake	;set rand start position in eax
	
	mov ebx, START_LEN
	@@init_snake:
		mov [_snakeBuffer + 4*(ebx-1)],eax
		dec ebx
		inc eax
		cmp ebx, 0
		jnz @@init_snake
	
	call drawSnake
	
	; initialize food positions
	call newFood
	mov [poisonPixel], eax
	call newFood
	mov [boosterPixel], eax
	call newFood
	mov [foodPixel], eax

	; draw food
	call drawFood, [poisonPixel], COLOR_POISON
	call drawFood, [boosterPixel], COLOR_BOOSTER
	call drawFood, [foodPixel], COLOR_FOOD
	
	; refreshing the visual update once so the player can prepare his actions before the game starts
	call updateSnake
	call updateScreen
	call drawAll, offset _screenBuffer, SCREEN_DATALIMIT
	
	; waiting about 2-4 seconds before the player can control the snake, this gives extra thinking time for the player before the game starts
	mov esi, [waitSeconds]
		@@pLoop:
			call handleInput
			mov ah, 2Ch ; get current time 
			int 21h

			xor dh, dh   
			mov ax, dx   ; verplaats de milliseconden in dh-dl naar ax zodat dit gebruikt kan worden bij het delen
			mov bl, [waitMilliseconds] ; de hoeveelheid milliseconden we moeten wachten
			div bl       ; de deling vergelijkbaar met een modulo
			cmp ah, 0    ; de rest na deling
			jnz @@pLoop
		dec esi
		cmp esi, 0
		jne @@pLoop
	
	ret
ENDP initGame

PROC drawRectangle
	USES eax, ebx, ecx, edx
	ARG POS:dword, WID:dword, HEI:dword
	
	mov eax, [POS]
	xor ebx,ebx
	
	@@draw_rectangle:
		xor ecx,ecx
		@@draw_line:
			mov [_screenBuffer + eax], COLOR_WALL
			inc eax
			inc ecx
			cmp ecx, [WID]
			jne @@draw_line
		sub eax, [WID]
		add eax, SCREEN_WIDTH
		inc ebx
		cmp ebx, [HEI]
		jne @@draw_rectangle
		
	ret
ENDP drawRectangle

; We wanted to make this parametric so the maze would scale with the width and height, but this brought strange bugs and was not usefull in end
PROC makeMaze
	call drawRectangle, 0, 320, 5
	call drawRectangle, 0, 5, 200
	call drawRectangle, 315, 5, 200
	call drawRectangle, 62400, 320, 5
	call drawRectangle, 1650, 5, 50
	call drawRectangle, 24000, 100, 5
	call drawRectangle, 1750, 5, 125
	call drawRectangle, 1800, 5, 25
	call drawRectangle, 15895, 100, 5
	call drawRectangle, 31875, 120, 5
	call drawRectangle, 33700, 5, 90
	call drawRectangle, 43430, 5, 60
	ret
ENDP makeMaze

PROC drawSnake
	USES eax, ebx
	;GET SNAKE BUFFER LENGTH
	mov eax, [score]
	add eax, START_LEN
	;PUT SNAKE IN SCREENBUFFER
	xor ebx,ebx
	@@draw_snake:
		mov ebx,[_snakeBuffer + 4*(eax-1)]
		mov [_screenBuffer + ebx], COLOR_SNAKE
		dec eax
		cmp eax,0
		jnz @@draw_snake
	ret
ENDP drawSnake

PROC drawProjectile
	USES eax
	
	cmp [projLaunched], 0 ; if no projectile was launched, don't draw
	je @@skip
	
	mov eax, [projectilePos]
	mov [_screenBuffer + eax], COLOR_SNAKE
	
	@@skip:
		ret
ENDP drawProjectile

PROC handleInput
	mov ah, 01h
	int 16h
	jz SHORT @@nokey
	mov ah, 00h
	int 16h
	cmp al, 1Bh ;ESC
	je @@escape
	cmp al, 70h; p
	je @@pauze
	cmp ah, 77	;RIGHT
	je @@right
	cmp ah, 75 ;LEFT
	je @@left
	cmp ah, 72 ;UP
	je @@up
	cmp ah, 80 ;DOWN
	je @@down
	cmp al, 20h ; SPACE
	je @@space
	ret
	@@right:
		call updateDir, 1
		ret
	@@left:
		call updateDir, -1
		ret
	@@up:
		call updateDir, -SCREEN_WIDTH
		ret
	@@down:
		call updateDir, SCREEN_WIDTH
		ret
	@@escape:
		call exitGame
		ret
	@@pauze:
		call showScore
		ret
	@@space:
		call projectileInit
		ret
	@@nokey:
		xor eax,eax
		ret
ENDP handleInput

PROC projectileInit ; initiate a flying projectile
	USES eax
	
	cmp [projLaunched], 1 ; if already launched, don't relaunch another projectile
	je @@skip
	
	mov [projLaunched], 1
	mov eax, [_snakeBuffer]
	mov [projectilePos], eax
	mov eax, [projDirection]
	add [projectilePos], eax
	@@skip:
		ret
ENDP projectileInit

PROC updateDir ; updates the direction of the projectile an the snake
	ARG userInput:dword
	USES eax
	xor eax,eax
	sub eax, [direction]
	cmp eax, [userInput]
	je @@fullRotation
		mov eax, [userInput]
		mov [direction], eax
	
	cmp [projLaunched], 1 ;if projectile launched, don't change the direction of the projectile
	je @@fullRotation
	mov [projDirection], eax
	
	@@fullRotation:
		ret
ENDP updateDir

PROC updateSnake
	USES eax, ebx, edx
	
	;GET SNAKE BUFFER LENGTH
	mov eax, [score]
	add eax, START_LEN
	@@update_snake:
		mov ebx,[_snakeBuffer+ 4*(eax-1)]
		mov [_snakeBuffer+ 4*eax],ebx
		dec eax
		cmp eax, 0
	jne @@update_snake	
	
	;MOVE HEAD
	mov ebx,[_snakeBuffer]
	add ebx,[direction]
	mov [_snakeBuffer],ebx
	ret
ENDP updateSnake

PROC updateProjectile
	USES eax, ebx
	
	cmp [projLaunched], 0 ; if projectile isn't launched yet, don't update the position
	je @@skip
	
	mov ebx,[projectilePos]
	mov eax, [projDirection]
	shl eax, 1 ;multiply the speed of the projectile by 2 times the speed of the snake
	add ebx, eax
	mov [projectilePos], ebx
	@@skip:
		ret
ENDP updateProjectile

PROC clearScreen
	USES eax
	xor eax, eax
	@@clear_screen:
		mov [_screenBuffer+ eax], 0
		inc eax
		cmp eax, SCREEN_DATALIMIT
		jne @@clear_screen
	ret
ENDP clearScreen

PROC collisionDetection
	USES eax, ebx, ecx, edx
	ARG snakePos:dword
	
	; checks the snake for collisions to the wall boundaries
	mov ebx, [snakePos]
	cmp [_screenBuffer + ebx], COLOR_WALL ;wall collision
	je NEAR @@exit
	cmp ebx, 0
	jl  NEAR @@exit	;upper boundary
	cmp ebx, SCREEN_DATALIMIT
	jge NEAR @@exit	;lower boundary
	mov eax, [snakePos]
	mov ecx, SCREEN_WIDTH
	xor edx, edx
	div ecx
	cmp edx, 0
	je SHORT @@exit	;horizontal boundaries
	
	; check for tail collision
	mov eax, [score]
	add eax, START_LEN
	@@check_snake_tail:
		mov ebx, [_snakeBuffer + 4* eax] ; tail
		mov edx, [_snakeBuffer] ; head
		cmp edx, ebx
		je @@exit
		dec eax
		cmp eax, 0
		jne @@check_snake_tail
	
	; this section checks if the projectile collided with the wall or outer boundaries
	cmp [projLaunched], 0 ;if projectile is launched check if it hit something
	je @@skip
	
	mov ebx, [projectilePos]
	cmp [_screenBuffer + ebx], COLOR_WALL ;wall collision
	je @@projCollision
	cmp ebx, 0
	jl @@projCollision ;upper boundary
	cmp ebx, SCREEN_DATALIMIT
	jge @@projCollision	;lower boundary
	mov eax, [projectilePos]
	mov ecx, SCREEN_WIDTH
	xor edx, edx
	div ecx
	cmp edx, 0
	je @@projCollision	;horizontal boundaries
	jmp @@skip
	
	@@projCollision:
		mov [projLaunched], 0
		mov [projectilePos], 0
		mov eax, [direction]
		mov [projDirection], eax ; updating direction
	@@skip:
		ret
	@@exit:
		call exitGame
		ret
ENDP collisionDetection

PROC foodWallCollision
	USES eax, ebx, ecx, edx
	ARG foodPos:dword
	mov ebx, [foodPos]
	xor esi, esi
	xor ecx, ecx ; outer loop
	xor edx, edx ; inner loop
	
		; inner and outer loop checks if the food collided with a wall and should remake a new foodPos
		@@innerLoop:
			cmp [_screenBuffer + ebx], COLOR_WALL
			je @@retryRand
			inc edx
			add ebx, 1
			cmp edx, [foodBigness]
			jl @@innerLoop
		
		@@outerLoop:
			sub ebx, edx
			xor edx, edx
			add ebx, SCREEN_WIDTH
			inc ecx
			cmp ecx, [foodBigness]
			jl @@innerLoop
			jmp @@done
	@@retryRand:
		mov esi, 1
		ret
	@@done:
		ret
ENDP foodWallCollision

PROC drawFood ; draws the food with a certain bigness
	USES eax, ebx, ecx, edx
	ARG foodPos:dword, food:byte
	mov ebx, [foodPos]
	mov al, [food]
	xor ecx, ecx ; outer loop
	xor edx, edx ; inner loop
		
		@@innerLoop:
			mov [_screenBuffer + ebx], al
			inc edx
			add ebx, 1
			cmp edx, [foodBigness]
			jl @@innerLoop
		
		@@outerLoop:
			sub ebx, edx
			xor edx, edx
			add ebx, SCREEN_WIDTH
			inc ecx
			cmp ecx, [foodBigness]
			jl @@innerLoop
			jmp @@done
		
	@@done:
		ret
ENDP drawFood

PROC foodCollision
	USES eax, ebx
	
	; food collision?
	mov ebx,[_snakeBuffer]
	cmp [_screenBuffer + ebx],COLOR_FOOD
	je NEAR @@food
	cmp [_screenBuffer + ebx],COLOR_POISON
	je SHORT @@poison
	cmp [_screenBuffer + ebx],COLOR_BOOSTER
	je NEAR @@booster
	
	; food collision with projectile?
	mov ebx, [projectilePos]
	cmp [_screenBuffer + ebx],COLOR_FOOD
	je @@projFood
	cmp [_screenBuffer + ebx],COLOR_POISON
	je @@projPoison
	cmp [_screenBuffer + ebx],COLOR_BOOSTER
	je @@projBooster
	ret
	
	; let the projectile diseppear 
	@@projFood:
		mov [projLaunched], 0
		jmp @@food
	@@projPoison:
		mov [projLaunched], 0
		jmp @@poison
	@@projBooster:
		mov [projLaunched], 0
		jmp @@booster
	
	; increment/substract score if food was eaten
	@@food:
		mov [_screenBuffer + ebx], COLOR_SNAKE
		call newFood
		mov [foodPixel], eax
		add [score], FOOD_ADD
		ret
	@@poison:
		mov [_screenBuffer + ebx], COLOR_SNAKE
		call newFood
		mov [poisonPixel], eax
		cmp [score], POISON_FOOD_SUB
		jl @@negativeSkip ; skip substracting if score is smaller than POISON_FOOD_SUB
		sub [score], POISON_FOOD_SUB
		@@negativeSkip:
			ret
	@@booster:
		mov [_screenBuffer + ebx], COLOR_SNAKE
		call newFood
		mov [boosterPixel], eax
		add [score], BOOSTER_FOOD_ADD
		ret
	
ENDP foodCollision

PROC updateScreen
	USES eax, ebx
	call clearScreen
	call drawSnake
	call drawProjectile
	call makeMaze
	
	; draw food
	call drawFood, [poisonPixel], COLOR_POISON
	call drawFood, [boosterPixel], COLOR_BOOSTER
	call drawFood, [foodPixel], COLOR_FOOD

	; check if snake is out of bound or against a wall, (exit game if collision)
	call collisionDetection, [_snakeBuffer]
	
	; check if the snake ate something
	call foodCollision
	ret
	
ENDP updateScreen

PROC exitGame
	call clearScreen
	call drawAll, offset _screenBuffer, SCREEN_DATALIMIT
	call showScore
	call unsetupVideo
	mov ax, 04C00h
	int 21h
	ret
ENDP exitGame

PROC pauzeLoop ;pauses the game until the game waited pauze_int milliseconds
	USES eax, ebx, ecx, edx
	ARG pauze_int:byte ;smaller than 20
	
	@@pLoop:
		mov ah, 2Ch ; get current time 
		int 21h

		xor dh, dh   
		mov ax, dx   ; verplaats de milliseconden in dh-dl naar ax zodat dit gebruikt kan worden bij het delen
		mov bl, [pauze_int] ; de hoeveelheid milliseconden we moeten wachten
		div bl       ; de deling vergelijkbaar met een modulo
		cmp ah, 0    ; de rest na deling
		jnz @@pLoop
		jmp @@exitPauzeLoop
	
	@@exitPauzeLoop:
		; screen update + snake position update
		call handleInput ; keyInputs reeds registreren
		call updateSnake
		call updateProjectile
		call updateScreen
		call drawAll, offset _screenBuffer, SCREEN_DATALIMIT
		ret

ENDP pauzeLoop

PROC MAIN
	sti
	cld
	
	push ds
	pop es
	
	call setupVideo
	call welcomeWindow
	call initGame, WAIT_SECONDS, WAIT_MILLISECONDS
	@@gameLoop:
		
		
		call pauzeLoop, [snakeSpeed] ; recommended  between 1 and 20 => 1 = fastest snakespeed

		jmp @@gameLoop
ENDP MAIN
; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
_screenBuffer db SCREEN_DATALIMIT dup(0)
_snakeBuffer dd SCREEN_DATALIMIT dup(0)
projectilePos dd 0
snakeSpeed dd SNAKE_SPEED
foodBigness dd FOOD_BIGNESS
score dd 0
foodPixel dd 0
poisonPixel dd 0
boosterPixel dd 0
direction dd 1
projDirection dd 1
projLaunched dd 0
welcomeMessage db "COBRA",10,13,"PRESS ENTER TO PLAY",10,13,"PRESS ESC TO EXIT", 10, 13, "PRESS SPACE TO SHOOT", 10, 13, 10, 13, "Change speed from default Z", 10, 13, "fast= A  medium = Z  slow = E", 10, 13, 10, 13, "Change food bigness from default 5", 10, 13, "Press any single number for bigness (you may have to hold down shift)", '$'
exitMessage db 13,"PRESS ESC OR P TO EXIT",10,13,"SCORE: ",'$'
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 1000h

END MAIN
