bits 64
default rel


; Here comes the defines
sys_read: equ 0	
sys_write:	equ 1
sys_nanosleep:	equ 35
sys_time:	equ 201
sys_fcntl:	equ 72


STDIN_FILENO: equ 0

F_SETFL:	equ 0x0004
O_NONBLOCK: equ 0x0004

;screen clean definition
row_cells:	equ 32	; set to any (reasonable) value you wish
column_cells: 	equ 80 ; set to any (reasonable) value you wish
array_length:	equ row_cells * column_cells + row_cells ; cells are mapped to bytes in the array and a new line char ends each row

;This is regarding the sleep time
timespec:
    tv_sec  dq 0
    tv_nsec dq 200000000


;This is for cleaning up the screen
clear:		db 27, "[2J", 27, "[H"
clear_length:	equ $-clear
	
	

; Start Message
msg1: db "        TECNOLOGICO DE COSTA RICA        ", 0xA, 0xD
msg2: db "        ARQUITECTURA DE COMPUTADORAS I        ", 0xA, 0xD
msg3: db "        ESTUDIANTE: HENRY NUNEZ PEREZ        ", 0xA, 0xD
msg4: db "        PROFESOR: ERNESTO RIVERA ALVARADO        ", 0xA, 0xD
msg5: db "        ARKANOID RETRO        ", 0xA, 0xD
msg6: db "        PRESIONE ENTER PARA INICIAR        ", 0xA, 0xD
msg1_length: equ $-msg1
msg2_length: equ $-msg2
msg3_length: equ $-msg3
msg4_length: equ $-msg4
msg5_length: equ $-msg5
msg6_length: equ $-msg6

; Usefull macros



%macro setnonblocking 0
	mov rax, sys_fcntl
    mov rdi, STDIN_FILENO
    mov rsi, F_SETFL
    mov rdx, O_NONBLOCK
    syscall
%endmacro

%macro unsetnonblocking 0
	mov rax, sys_fcntl
    mov rdi, STDIN_FILENO
    mov rsi, F_SETFL
    mov rdx, 0
    syscall
%endmacro

%macro full_line 0
    times column_cells db "X"
    db 0x0a, 0xD
%endmacro

%macro hollow_line 0
    db "X"
    times column_cells-2 db " "
    db "X", 0x0a, 0xD
%endmacro


%macro print 2
	mov eax, sys_write
	mov edi, 1 	; stdout
	mov rsi, %1
	mov edx, %2
	syscall
%endmacro

%macro getchar 0
	mov     rax, sys_read
    mov     rdi, STDIN_FILENO
    mov     rsi, input_char
    mov     rdx, 1 ; number of bytes
    syscall         ;read text input from keyboard
%endmacro

%macro sleeptime 0
	mov eax, sys_nanosleep
	mov rdi, timespec
	xor esi, esi		; ignore remaining time in case of call interruption
	syscall			; sleep for tv_sec seconds + tv_nsec nanoseconds
%endmacro



global _start

section .bss

input_char: resb 1

section .data

	board:
		full_line
        %rep 30
        hollow_line
        %endrep
        full_line
	board_size:   equ   $ - board

	; Added for the terminal issue
	termios:        times 36 db 0
	stdin:          equ 0
	ICANON:         equ 1<<1
	ECHO:           equ 1<<3
	VTIME: 			equ 5
	VMIN:			equ 6
	CC_C:			equ 18

section .text
;;;;;;;;;;;;;;;;;;;;for the working of the terminal;;;;;;;;;;;;;;;;;
canonical_off:
        call read_stdin_termios

        ; clear canonical bit in local mode flags
        push rax
        mov eax, ICANON
        not eax
        and [termios+12], eax
		mov byte[termios+CC_C+VTIME], 0
		mov byte[termios+CC_C+VMIN], 0
        pop rax

        call write_stdin_termios
        ret

echo_off:
        call read_stdin_termios

        ; clear echo bit in local mode flags
        push rax
        mov eax, ECHO
        not eax
        and [termios+12], eax
        pop rax

        call write_stdin_termios
        ret

canonical_on:
        call read_stdin_termios

        ; set canonical bit in local mode flags
        or dword [termios+12], ICANON
		mov byte[termios+CC_C+VTIME], 0
		mov byte[termios+CC_C+VMIN], 1
        call write_stdin_termios
        ret

echo_on:
        call read_stdin_termios

        ; set echo bit in local mode flags
        or dword [termios+12], ECHO

        call write_stdin_termios
        ret

read_stdin_termios:
        push rax
        push rbx
        push rcx
        push rdx

        mov eax, 36h
        mov ebx, stdin
        mov ecx, 5401h
        mov edx, termios
        int 80h

        pop rdx
        pop rcx
        pop rbx
        pop rax
        ret

write_stdin_termios:
        push rax
        push rbx
        push rcx
        push rdx

        mov eax, 36h
        mov ebx, stdin
        mov ecx, 5402h
        mov edx, termios
        int 80h

        pop rdx
        pop rcx
        pop rbx
        pop rax
        ret

;;;;;;;;;;;;;;;;;;;;end for the working of the terminal;;;;;;;;;;;;

char_equal: equ 61
char_space: equ 32
char_O: equ 79
left_direction: equ -1
right_direction: equ 1


section .data
	pallet_position dq board + 40 + 29 * (column_cells +2)
	pallet_size dq 3

	ball_x_pos: dq 40
	ball_y_pos: dq 28
; Definir los límites de la pantalla o área de juego
    board_top_left_x equ 1
    board_top_left_y equ 1
    board_bottom_right_x equ column_cells - 1
    board_bottom_right_y equ row_cells

    ; Limites laterales
    left_edge equ board_top_left_x               ; Límite izquierdo en la primera columna
    right_edge equ board_bottom_right_x         ; Límite derecho en la última columna

    ; O también puedes hacerlo así si prefieres usando las coordenadas en memoria para obtener la ubicación exacta:
    left_edge_position dq board + (board_top_left_y * (column_cells + 2)) ; Coordenada de la parte izquierda del marco
    right_edge_position dq board + (board_top_left_y * (column_cells + 2) + board_bottom_right_x - 1) ; Coordenada de la parte derecha del marco

section .text

;	Function: print_ball
; This function displays the position of the ball
; Arguments: none
;
; Return:
;	Void
print_ball:
	mov r8, [ball_x_pos]
	mov r9, [ball_y_pos]
	add r8, board

	mov rcx, r9
	mov rax, column_cells + 2
	imul rcx
	
	add r8, rax
	mov byte [r8], char_O
	ret

	
	;mov rax, board + r8 + r9 * (column_cells + 2)
	



;	Function: print_pallet
; This function moves the pallet in the game
; Arguments: none
;
; Return;
;	void
print_pallet:
	mov r8, [pallet_position]
	mov rcx, [pallet_size]
	.write_pallet:
		mov byte [r8], char_equal
		inc r8
		dec rcx
		jnz .write_pallet

	ret
	
;	Function: move_pallet
; This function is in charge of moving the pallet in a given direction
; Arguments:
;	rdi: left direction or right direction
;
; Return:
;	void
move_pallet:
    cmp rdi, left_direction
    jne .move_right
    
    .move_left:
        ; Verificar si la siguiente posición sería una X (borde izquierdo)
        mov r8, [pallet_position]
        dec r8              ; Verificar la posición a la izquierda
        mov al, [r8]       ; Cargar el carácter en esa posición
        cmp al, 'X'        ; Comparar si es una X
        je .end            ; Si es X, no mover
        
        mov r8, [pallet_position]
        mov r9, [pallet_size]
        mov byte [r8 + r9 - 1], char_space  ; Borrar último carácter de la paleta
        dec r8
        mov [pallet_position], r8
        jmp .end
        
    .move_right:
        ; Verificar si la siguiente posición después de la paleta sería una X
        mov r8, [pallet_position]
        mov r9, [pallet_size]
        add r8, r9         ; Moverse al final de la paleta
        mov al, [r8]       ; Cargar el carácter en esa posición
        cmp al, 'X'        ; Comparar si es una X
        je .end            ; Si es X, no mover
        
        mov r8, [pallet_position]
        mov byte [r8], char_space
        inc r8
        mov [pallet_position], r8
    .end:
        ret

_start:
	call canonical_off
	call start_screen
	jmp .main_loop
	

	.main_loop:
		call print_pallet
		call print_ball
		print board, board_size				
		;setnonblocking	
	.read_more:	
		getchar	
		
		cmp rax, 1
    	jne .done
		
		mov al,[input_char]

		cmp al, 'a'
	    jne .not_left
	    mov rdi, left_direction
		call move_pallet
	    jmp .done
		
		.not_left:
		 	cmp al, 'd'
	    	jne .not_right
			mov rdi, right_direction
	    	call move_pallet
    		jmp .done		

		.not_right:

    		cmp al, 'q'
    		je exit

			jmp .read_more
		
		.done:	
			;unsetnonblocking		
			sleeptime	
			print clear, clear_length
    		jmp .main_loop

		print clear, clear_length
		
		jmp exit


start_screen:
    print clear, clear_length    ; Limpiamos la pantalla primero
    print msg1, msg1_length
    
    .wait_for_key:              ; Agregamos una etiqueta para esperar la tecla
        getchar                 ; Esperamos una tecla
        cmp rax, 1             ; Verificamos si se leyó un carácter
        jne .wait_for_key      ; Si no se leyó, seguimos esperando
        
    print clear, clear_length   ; Limpiamos la pantalla antes de salir
    ret

exit: 
	call canonical_on
	mov    rax, 60
    mov    rdi, 0
    syscall

