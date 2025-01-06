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
    tv_nsec dq 20000000


;This is for cleaning up the screen
clear:		db 27, "[2J", 27, "[H"
clear_length:	equ $-clear
	
	

; Start Message
msg1: db "        TECNOLOGICO DE COSTA RICA        ", 0xA, 0xD
msg2: db "        ARQUITECTURA DE COMPUTADORAS I        ", 0xA, 0xD
msg3: db "        ESTUDIANTE: HENRY NUNEZ PEREZ        ", 0xA, 0xD
msg4: db "        PROFESOR: ERNESTO RIVERA ALVARADO        ", 0xA, 0xD
msg5: db "        ARKANOID RETRO        ", 0xA, 0xD
msg6: db "        PRESIONE CUALQUIER TECLA PARA INICIAR        ", 0xA, 0xD
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

	; Guardamos la plantilla del tablero (32 filas)
    board_template:
        full_line
        %rep 30
        hollow_line
        %endrep
        full_line
    board_template_size: equ $ - board_template

    ; Espacio real que se usará en la ejecución
    board: times board_template_size db 0
    board_size: equ board_template_size

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

; Mensajes para los niveles
    level_msg: db "NIVEL "
    level_msg_len: equ $ - level_msg
    level_1_char: db "1"
    level_2_char: db "2"
    level_3_char: db "3"
    level_4_char: db "4"
    level_5_char: db "5"
    level_char_len: equ 1

    ; Timespec para la pausa del mensaje de nivel
    level_display_time:
        lvl_tv_sec dq 1           ; 1 segundo
        lvl_tv_nsec dq 0
        
	pallet_position dq board + 38 + 29 * (column_cells +2)
    pallet_size dq 5
    default_pallet_size dq 5    ; Tamaño normal de la paleta
    extended_pallet_size dq 7   ; Tamaño extendido de la paleta

	ball_x_pos: dq 40
	ball_y_pos: dq 28
    ball_direction_x dq 1    ; 1 = derecha, -1 = izquierda
    ball_direction_y dq -1   ; -1 = arriba, 1 = abajo
    ball_moving db 0         ; 0 = estática, 1 = en movimiento
    ball_active db 0

    ball2_x_pos:        dq 0
    ball2_y_pos:        dq 0
    ball2_direction_x:  dq 0
    ball2_direction_y:  dq 0
    ball2_moving:       db 0    ; 0 = estática, 1 = en movimiento
    ball2_active:       db 0    ; 0 = inactiva, 1 = activa

    ; -- Pelota 3 --
    ball3_x_pos:        dq 0
    ball3_y_pos:        dq 0
    ball3_direction_x:  dq 0
    ball3_direction_y:  dq 0
    ball3_moving:       db 0
    ball3_active:       db 0


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

    ; Definición de tipos de bloques
    block_type_1: db "UUUUUU"    ; Durabilidad 1
    block_type_2: db "OOOOOO"    ; Durabilidad 2
    block_type_3: db "DDDDDD"    ; Durabilidad 3
    block_type_4: db "LLLLLL"    ; Durabilidad 4
    block_type_5: db "VVVVVV"    ; Durabilidad 5
    block_type_6: db "888888"    ; Durabilidad 6
    block_length: equ 6        ; Longitud de cada bloque

    ; Estructura para el nivel actual
    current_level db 3
    blocks_remaining db 0

    ; Definición del nivel 1 (ejemplo con múltiples bloques)destroyed_blocks
    ; Formato: x_pos, y_pos, tipo_bloque, durabilidad_actual
    level1_blocks:
        ; Tercera fila (tipo 3)
        db 1, 5, 5, 2, ' '   
        db 7, 5, 5, 2, ' '    
        db 13, 5, 5, 2, ' '   
        db 19, 5, 5, 2, ' '   
        db 25, 5, 5, 2, ' '   
        db 31, 5, 5, 2, ' '   
        db 37, 5, 5, 2, ' '   
        db 43, 5, 5, 2, ' '   
        db 49, 5, 5, 2, ' '   
        db 55, 5, 5, 2, ' '   
        db 61, 5, 5, 2, ' '  
        db 67, 5, 5, 2, ' '   
        db 73, 5, 5, 2, ' '   

        db 1, 6, 4, 1, 'E'   
        db 7, 6, 2, 1, 'S'    
        db 13, 6, 4, 1, 'S'   
        db 19, 6, 2, 1, 'S'   
        db 25, 6, 4, 1, ' '   
        db 31, 6, 2, 1, ' '   
        db 37, 6, 4, 1, ' '   
        db 43, 6, 2, 1, 'C'   
        db 49, 6, 4, 1, ' '   
        db 55, 6, 2, 1, ' '   
        db 61, 6, 4, 1, ' '  
        db 67, 6, 2, 1, ' '   
        db 73, 6, 4, 1, ' ' 

        db 1, 7, 1, 1, ' '   
        db 7, 7, 3, 1, ' '    
        db 13, 7, 1, 1, ' '   
        db 19, 7, 3, 1, ' '   
        db 25, 7, 1, 1, ' '   
        db 31, 7, 3, 1, ' '   
        db 37, 7, 1, 1, ' '   
        db 43, 7, 3, 1, ' '   
        db 49, 7, 1, 1, ' '   
        db 55, 7, 3, 1, ' '   
        db 61, 7, 1, 1, ' '  
        db 67, 7, 3, 1, ' '   
        db 73, 7, 1, 1, ' ' 

        db 1, 8, 4, 1, ' '   
        db 7, 8, 2, 1, ' '    
        db 13, 8, 4, 1, 'P'   
        db 19, 8, 2, 1, ' '   
        db 25, 8, 4, 1, ' '   
        db 31, 8, 2, 1, ' '   
        db 37, 8, 4, 1, 'E'   
        db 43, 8, 2, 1, 'C'   
        db 49, 8, 4, 1, ' '   
        db 55, 8, 2, 1, ' '   
        db 61, 8, 4, 1, ' '  
        db 67, 8, 2, 1, ' '   
        db 73, 8, 4, 1, ' ' 

        db 1, 9, 1, 1, ' '   
        db 7, 9, 3, 1, ' '    
        db 13, 9, 1, 1, ' '   
        db 19, 9, 3, 1, ' '   
        db 25, 9, 1, 1, ' '   
        db 31, 9, 3, 1, ' '   
        db 37, 9, 1, 1, ' '   
        db 43, 9, 3, 1, ' '     
        db 49, 9, 1, 1, ' '   
        db 55, 9, 3, 1, ' '   
        db 61, 9, 1, 1, ' '  
        db 67, 9, 3, 1, ' '   
        db 73, 9, 1, 1, ' ' 

        db 1, 10, 4, 1, 'E'   
        db 7, 10, 2, 1, ' '    
        db 13, 10, 4, 1, ' '   
        db 19, 10, 2, 1, ' '   
        db 25, 10, 4, 1, ' '   
        db 31, 10, 2, 1, ' '   
        db 37, 10, 4, 1, 'C'   
        db 43, 10, 2, 1, ' '   
        db 49, 10, 4, 1, ' '   
        db 55, 10, 2, 1, 'L'   
        db 61, 10, 4, 1, ' '  
        db 67, 10, 2, 1, ' '   
        db 73, 10, 4, 1, ' ' 

    level1_blocks_count equ 78   ; Cantidad total de bloques

    ; Nivel 2: Bloques de prueba
    level2_blocks:
        db 1, 3, 4, 1, ' '

        db 1, 4, 3, 1, ' '   
        db 7, 4, 4, 1, ' '   
                
        db 1, 5, 2, 1, ' '   
        db 7, 5, 3, 1, ' '
        db 13, 5, 4, 1, 'D'

        db 1, 6, 1, 1, ' '   
        db 7, 6, 2, 1, ' '
        db 13, 6, 3, 1, ' '
        db 19, 6, 4, 1, ' '   

        db 1, 7, 4, 1, ' '   
        db 7, 7, 1, 1, ' '
        db 13, 7, 2, 1, ' '
        db 19, 7, 3, 1, ' '  
        db 25, 7, 4, 1, ' '   

        db 1, 8, 3, 1, ' '   
        db 7, 8, 4, 1, ' '
        db 13, 8, 1, 1, ' '
        db 19, 8, 2, 1, ' '  
        db 25, 8, 3, 1, ' ' 
        db 31, 8, 4, 1, ' '   

        db 1, 9, 2, 1, ' '   
        db 7, 9, 3, 1, ' '
        db 13, 9, 4, 1, ' '
        db 19, 9, 1, 1, ' '  
        db 25, 9, 2, 1, ' ' 
        db 31, 9, 3, 1, 'C' 
        db 37, 9, 4, 1, ' '   

        db 1, 10, 1, 1, ' '   
        db 7, 10, 2, 1, ' '
        db 13, 10, 3, 1, ' '
        db 19, 10, 4, 1, ' '  
        db 25, 10, 1, 1, ' ' 
        db 31, 10, 2, 1, ' ' 
        db 37, 10, 3, 1, 'L'  
        db 43, 10, 4, 1, ' '   

        db 1, 11, 4, 1, ' '   
        db 7, 11, 1, 1, ' '
        db 13, 11, 2, 1, ' '
        db 19, 11, 3, 1, 'D'  
        db 25, 11, 4, 1, ' ' 
        db 31, 11, 1, 1, ' ' 
        db 37, 11, 2, 1, ' '  
        db 43, 11, 3, 1, ' ' 
        db 49, 11, 4, 1, ' '   

        db 1, 12, 3, 1, ' '   
        db 7, 12, 4, 1, ' '
        db 13, 12, 1, 1, ' '
        db 19, 12, 2, 1, ' '  
        db 25, 12, 3, 1, ' ' 
        db 31, 12, 4, 1, ' ' 
        db 37, 12, 1, 1, ' '  
        db 43, 12, 2, 1, ' ' 
        db 49, 12, 3, 1, ' '
        db 55, 12, 4, 1, ' '   

        db 1, 13, 2, 1, ' '   
        db 7, 13, 3, 1, ' '
        db 13, 13, 4, 1, ' '
        db 19, 13, 1, 1, 'D'  
        db 25, 13, 2, 1, ' ' 
        db 31, 13, 3, 1, ' ' 
        db 37, 13, 4, 1, ' '  
        db 43, 13, 1, 1, ' ' 
        db 49, 13, 2, 1, ' '
        db 55, 13, 3, 1, ' ' 
        db 61, 13, 4, 1, ' '   

        db 1, 14, 1, 1, ' '   
        db 7, 14, 2, 1, ' '
        db 13, 14, 3, 1, ' '
        db 19, 14, 4, 1, ' '  
        db 25, 14, 1, 1, ' ' 
        db 31, 14, 2, 1, ' ' 
        db 37, 14, 3, 1, ' '  
        db 43, 14, 4, 1, ' ' 
        db 49, 14, 1, 1, ' '
        db 55, 14, 2, 1, ' ' 
        db 61, 14, 3, 1, ' '  
        db 67, 14, 4, 1, ' '   

        db 1, 15, 5, 2, ' '   
        db 7, 15, 5, 2, ' '
        db 13, 15, 5, 2, ' '
        db 19, 15, 5, 2, ' '  
        db 25, 15, 5, 2, ' ' 
        db 31, 15, 5, 2, ' ' 
        db 37, 15, 5, 2, ' '  
        db 43, 15, 5, 2, ' ' 
        db 49, 15, 5, 2, ' '
        db 55, 15, 5, 2, ' ' 
        db 61, 15, 5, 2, ' '  
        db 67, 15, 5, 2, ' '
        db 73, 15, 4, 1, ' '   
       

    level2_blocks_count equ 91

    ; Nivel 3
    level3_blocks:

        db 1, 2, 1, 1, ' '   
        db 7, 2, 2, 1, ' '    
        db 13, 2, 1, 1, ' '   
        db 19, 2, 2, 1, ' '   
        db 25, 2, 1, 1, ' '   
        db 31, 2, 2, 1, ' '   
        db 37, 2, 1, 1, ' '   
        db 43, 2, 2, 1, ' '   
        db 49, 2, 1, 1, ' '   
        db 55, 2, 2, 1, ' '   
        db 61, 2, 1, 1, ' '  
        db 67, 2, 2, 1, ' '   
        db 73, 2, 1, 1, ' ' 

        db 1, 6, 4, 1, ' '   
        db 7, 6, 4, 1, ' '    
        db 13, 6, 4, 1, ' '   
        db 19, 6, 6, 99, ' '   
        db 25, 6, 6, 99, ' '   
        db 31, 6, 6, 99, ' '   
        db 37, 6, 6, 99, ' '   
        db 43, 6, 6, 99, ' '   
        db 49, 6, 6, 99, ' '   
        db 55, 6, 6, 99, ' '   
        db 61, 6, 6, 99, ' '  
        db 67, 6, 6, 99, ' '   
        db 73, 6, 6, 99, ' ' 

        db 1, 8, 4, 1, ' '   
        db 7, 8, 3, 1, ' '    
        db 13, 8, 4, 1, ' '   
        db 19, 8, 3, 1, ' '   
        db 25, 8, 4, 1, ' '   
        db 31, 8, 3, 1, ' '   
        db 37, 8, 4, 1, ' '   
        db 43, 8, 3, 1, ' '   
        db 49, 8, 4, 1, ' '   
        db 55, 8, 3, 1, ' '   
        db 61, 8, 4, 1, ' '  
        db 67, 8, 3, 1, ' '   
        db 73, 8, 4, 1, ' ' 

        db 1, 11, 6, 99, ' '   
        db 7, 11, 6, 99, ' '    
        db 13, 11, 6, 99, ' '   
        db 19, 11, 6, 99, ' '   
        db 25, 11, 6, 99, ' '   
        db 31, 11, 6, 99, ' '   
        db 37, 11, 6, 99, ' '   
        db 43, 11, 6, 99, ' '   
        db 49, 11, 6, 99, ' '   
        db 55, 11, 6, 99, ' '   
        db 61, 11, 3, 1, 'D'  
        db 67, 11, 3, 1, ' '   
        db 73, 11, 3, 1, ' ' 

        db 1, 13, 1, 1, 'D'   
        db 7, 13, 2, 1, 'P'    
        db 13, 13, 1, 1, 'C'   
        db 19, 13, 2, 1, ' '   
        db 25, 13, 1, 1, ' '   
        db 31, 13, 2, 1, ' '   
        db 37, 13, 1, 1, ' '   
        db 43, 13, 2, 1, ' '   
        db 49, 13, 1, 1, ' '   
        db 55, 13, 2, 1, ' '   
        db 61, 13, 1, 1, ' '  
        db 67, 13, 2, 1, ' '   
        db 73, 13, 1, 1, ' ' 

        db 1, 15, 2, 1, ' '   
        db 7, 15, 2, 1, ' '    
        db 13, 15, 2, 1, ' '   
        db 19, 15, 6, 99, ' '   
        db 25, 15, 6, 99, ' '   
        db 31, 15, 6, 99, ' '   
        db 37, 15, 6, 99, ' '   
        db 43, 15, 6, 99, ' '   
        db 49, 15, 6, 99, ' '   
        db 55, 15, 6, 99, ' '   
        db 61, 15, 6, 99, ' '  
        db 67, 15, 6, 99, ' '   
        db 73, 15, 6, 99, ' ' 

        db 1, 18, 2, 1, ' '   
        db 7, 18, 3, 1, ' '    
        db 13, 18, 2, 1, 'D'   
        db 19, 18, 3, 1, ' '   
        db 25, 18, 2, 1, ' '   
        db 31, 18, 3, 1, ' '   
        db 37, 18, 2, 1, ' '   
        db 43, 18, 3, 1, ' '   
        db 49, 18, 2, 1, ' '   
        db 55, 18, 3, 1, 'D'   
        db 61, 18, 2, 1, ' '  
        db 67, 18, 3, 1, 'C'   
        db 73, 18, 2, 1, ' ' 


        db 1, 20, 6, 99, ' '   
        db 7, 20, 6, 99, ' '    
        db 13, 20, 6, 99, ' '   
        db 19, 20, 6, 99, ' '   
        db 25, 20, 6, 99, ' '   
        db 31, 20, 6, 99, ' '   
        db 37, 20, 6, 99, ' '   
        db 43, 20, 6, 99, ' '   
        db 49, 20, 6, 99, ' '   
        db 55, 20, 6, 99, ' '   
        db 61, 20, 1, 1, ' '  
        db 67, 20, 1, 1, 'S'   
        db 73, 20, 1, 1, 'C' 

    level3_blocks_count equ 104

    ; Nivel 4
    level4_blocks:

        db 7, 4, 1, 1, ' '    
        db 13, 4, 2, 1, ' '   
        db 19, 4, 3, 1, ' '   
        db 25, 4, 5, 2, ' '   
        db 31, 4, 2, 1, ' '

        db 43, 4, 1, 1, ' '   
        db 49, 4, 2, 1, ' '   
        db 55, 4, 3, 1, 'D'   
        db 61, 4, 4, 1, ' '  
        db 67, 4, 2, 1, ' ' 

        db 7, 5, 2, 1, ' '    
        db 13, 5, 3, 1, ' '   
        db 19, 5, 5, 2, ' '   
        db 25, 5, 2, 1, ' '   
        db 31, 5, 1, 1, ' '

        db 43, 5, 2, 1, ' '   
        db 49, 5, 3, 1, ' '   
        db 55, 5, 4, 1, ' '   
        db 61, 5, 2, 1, ' '  
        db 67, 5, 5, 2, ' '  

        db 7, 6, 3, 1, ' '    
        db 13, 6, 5, 2, ' '   
        db 19, 6, 2, 1, ' '   
        db 25, 6, 1, 1, ' '   
        db 31, 6, 2, 1, ' '

        db 43, 6, 3, 1, ' '   
        db 49, 6, 4, 1, ' '   
        db 55, 6, 2, 1, ' '   
        db 61, 6, 5, 2, ' '  
        db 67, 6, 2, 1, ' '

        db 7, 7, 5, 2, ' '    
        db 13, 7, 2, 1, ' '   
        db 19, 7, 1, 1, ' '   
        db 25, 7, 2, 1, ' '   
        db 31, 7, 3, 1, ' '

        db 43, 7, 4, 1, ' '   
        db 49, 7, 2, 1, ' '   
        db 55, 7, 5, 2, ' '   
        db 61, 7, 2, 1, ' '  
        db 67, 7, 3, 1, ' '

        db 7, 8, 2, 1, ' '    
        db 13, 8, 1, 1, ' '   
        db 19, 8, 2, 1, ' '   
        db 25, 8, 3, 1, ' '   
        db 31, 8, 4, 1, ' '

        db 43, 8, 2, 1, ' '   
        db 49, 8, 5, 2, ' '   
        db 55, 8, 2, 1, ' '   
        db 61, 8, 3, 1, ' '  
        db 67, 8, 4, 1, ' '

        db 7, 9, 1, 1, ' '    
        db 13, 9, 2, 1, ' '   
        db 19, 9, 3, 1, ' '   
        db 25, 9, 4, 1, ' '   
        db 31, 9, 2, 1, ' '

        db 43, 9, 5, 2, ' '   
        db 49, 9, 2, 1, ' '   
        db 55, 9, 3, 1, ' '   
        db 61, 9, 4, 1, ' '  
        db 67, 9, 2, 1, ' '

        db 7, 10, 2, 1, ' '    
        db 13, 10, 3, 1, ' '   
        db 19, 10, 4, 1, ' '   
        db 25, 10, 2, 1, ' '   
        db 31, 10, 1, 1, ' '

        db 43, 10, 2, 1, ' '   
        db 49, 10, 3, 1, ' '   
        db 55, 10, 4, 1, ' '   
        db 61, 10, 2, 1, ' '  
        db 67, 10, 1, 1, ' '

        db 7, 11, 3, 1, ' '   
        db 13, 11, 4, 1, ' '   
        db 19, 11, 2, 1, ' '   
        db 25, 11, 1, 1, ' '  
        db 31, 11, 5, 2, ' '

        db 43, 11, 3, 1, ' '   
        db 49, 11, 4, 1, ' '   
        db 55, 11, 2, 1, ' '   
        db 61, 11, 1, 1, ' '  
        db 67, 11, 2, 1, ' '

        db 7, 12, 4, 1, ' '   
        db 13, 12, 2, 1, ' '   
        db 19, 12, 1, 1, ' '   
        db 25, 12, 5, 2, ' '  
        db 31, 12, 3, 1, ' '

        db 43, 12, 4, 1, ' '    
        db 49, 12, 2, 1, ' '   
        db 55, 12, 1, 1, ' '   
        db 61, 12, 2, 1, ' '   
        db 67, 12, 3, 1, ' '

        db 7, 13, 2, 1, ' '   
        db 13, 13, 1, 1, ' '   
        db 19, 13, 5, 2, ' '   
        db 25, 13, 3, 1, 'C'  
        db 31, 13, 4, 1, ' '

        db 43, 13, 2, 1, ' '    
        db 49, 13, 1, 1, ' '   
        db 55, 13, 2, 1, ' '   
        db 61, 13, 3, 1, ' '   
        db 67, 13, 5, 2, ' '

        db 7, 14, 1, 1, ' '   
        db 13, 14, 5, 2, ' '   
        db 19, 14, 3, 1, ' '   
        db 25, 14, 4, 1, ' '  
        db 31, 14, 2, 1, ' '

        db 43, 14, 1, 1, ' '    
        db 49, 14, 2, 1, ' '   
        db 55, 14, 3, 1, ' '   
        db 61, 14, 5, 2, ' '   
        db 67, 14, 2, 1, ' '

        db 7, 15, 5, 2, ' '   
        db 13, 15, 3, 1, ' '   
        db 19, 15, 4, 1, ' '   
        db 25, 15, 2, 1, ' '  
        db 31, 15, 1, 1, ' '

        db 43, 15, 2, 1, 'E'    
        db 49, 15, 3, 1, 'L'   
        db 55, 15, 5, 2, ' '   
        db 61, 15, 2, 1, ' '   
        db 67, 15, 1, 1, ' '

        db 7, 16, 3, 1, ' '   
        db 13, 16, 4, 1, ' '   
        db 19, 16, 2, 1, ' '   
        db 25, 16, 1, 1, ' '  
        db 31, 16, 2, 1, ' '

        db 43, 16, 3, 1, ' '    
        db 49, 16, 5, 2, ' '   
        db 55, 16, 2, 1, ' '   
        db 61, 16, 1, 1, ' '   
        db 67, 16, 2, 1, ' '

        db 7, 17, 4, 1, ' '   
        db 13, 17, 2, 1, ' '   
        db 19, 17, 1, 1, ' '   
        db 25, 17, 2, 1, ' '  
        db 31, 17, 3, 1, ' '

        db 43, 17, 5, 2, ' '    
        db 49, 17, 2, 1, ' '    
        db 55, 17, 1, 1, ' '   
        db 61, 17, 2, 1, ' '   
        db 67, 17, 3, 1, ' '

    level4_blocks_count equ 140

    ; Nivel 5
    level5_blocks:

        db 19, 3, 2, 1, 'E'   
        db 55, 3, 2, 1, ' '   

        db 19, 4, 2, 1, ' '   
        db 55, 4, 2, 1, 'L' 

        db 25, 5, 2, 1, ' '   
        db 49, 5, 2, 1, 'S'   

        db 25, 6, 2, 1, ' '   
        db 49, 6, 2, 1, ' '   

        db 19, 7, 5, 2, ' '   
        db 25, 7, 5, 2, ' '  
        db 31, 7, 5, 2, ' '
        db 37, 7, 5, 2, ' '
        db 43, 7, 5, 2, ' '    
        db 49, 7, 5, 2, ' '    
        db 55, 7, 5, 2, ' '   

        db 19, 8, 5, 2, ' '   
        db 25, 8, 5, 2, ' '  
        db 31, 8, 5, 2, ' '
        db 37, 8, 5, 2, ' '
        db 43, 8, 5, 2, ' '    
        db 49, 8, 5, 2, ' '    
        db 55, 8, 5, 2, ' '   

        db 13, 9, 5, 2, ' '   
        db 19, 9, 5, 2, ' '   
        db 25, 9, 4, 1, 'C'  
        db 31, 9, 5, 2, ' '
        db 37, 9, 5, 2, ' '
        db 43, 9, 5, 2, ' '    
        db 49, 9, 4, 1, 'D'    
        db 55, 9, 5, 2, ' '   
        db 61, 9, 5, 2, ' '  

        db 13, 10, 5, 2, ' '   
        db 19, 10, 5, 2, ' '   
        db 25, 10, 4, 1, ' '  
        db 31, 10, 5, 2, ' '
        db 37, 10, 5, 2, ' '
        db 43, 10, 5, 2, ' '    
        db 49, 10, 4, 1, ' '    
        db 55, 10, 5, 2, ' '   
        db 61, 10, 5, 2, ' '   
        
        db 7, 11, 5, 2, ' '   
        db 13, 11, 5, 2, ' '   
        db 19, 11, 5, 2, ' '   
        db 25, 11, 5, 2, ' '  
        db 31, 11, 5, 2, ' '
        db 37, 11, 5, 2, ' '
        db 43, 11, 5, 2, ' '    
        db 49, 11, 5, 2, ' '    
        db 55, 11, 5, 2, ' '   
        db 61, 11, 5, 2, ' '   
        db 67, 11, 5, 2, ' '

        db 7, 12, 5, 2, ' '   
        db 13, 12, 5, 2, ' '   
        db 19, 12, 5, 2, ' '   
        db 25, 12, 5, 2, ' '  
        db 31, 12, 5, 2, ' '
        db 37, 12, 5, 2, ' '
        db 43, 12, 5, 2, ' '    
        db 49, 12, 5, 2, ' '    
        db 55, 12, 5, 2, ' '   
        db 61, 12, 5, 2, ' '   
        db 67, 12, 5, 2, ' '

        db 7, 13, 5, 2, ' '   
        db 13, 13, 5, 2, ' '   
        db 19, 13, 5, 2, ' '   
        db 25, 13, 5, 2, ' '  
        db 31, 13, 5, 2, ' '
        db 37, 13, 5, 2, ' '
        db 43, 13, 5, 2, ' '    
        db 49, 13, 5, 2, ' '    
        db 55, 13, 5, 2, ' '   
        db 61, 13, 5, 2, ' '   
        db 67, 13, 5, 2, ' '

        
        db 7, 14, 5, 2, ' '   
        db 19, 14, 5, 2, ' '   
        db 25, 14, 5, 2, ' '  
        db 31, 14, 5, 2, ' '
        db 37, 14, 5, 2, ' '
        db 43, 14, 5, 2, ' '    
        db 49, 14, 5, 2, ' '    
        db 55, 14, 5, 2, ' '   
        db 67, 14, 5, 2, ' '

        db 7, 15, 5, 2, ' '   
        db 19, 15, 5, 2, ' '      
        db 55, 15, 5, 2, ' '   
        db 67, 15, 5, 2, ' '
 
        db 7, 16, 5, 2, ' '   
        db 19, 16, 5, 2, ' '      
        db 55, 16, 5, 2, ' '   
        db 67, 16, 5, 2, ' '


        db 25, 17, 5, 2, ' '  
        db 31, 17, 5, 2, ' '
        db 43, 17, 5, 2, ' '    
        db 49, 17, 5, 2, ' ' 

        db 25, 18, 5, 2, ' '  
        db 31, 18, 5, 2, ' '
        db 43, 18, 5, 2, ' '    
        db 49, 18, 5, 2, ' ' 

    level5_blocks_count equ 98

    ; Array para mantener el estado de los bloques
    block_states: times 200 db 0  ; Durabilidad actual de cada bloque

    
    ; Variables para almacenar los valores
    current_score dq 0          ; Score actual
    destroyed_blocks db 0       ; Bloques destruidos en el nivel actual
    
    ; Buffer para convertir números a string
    number_buffer: times 20 db 0

    enemy_chars db "@", "#", "$", "&", "@"    ; El nivel 1 y 5 comparten el mismo caracter (@)
    
    ; Estructura para los enemigos (x, y, activo)
    enemies: times 10 * 3 db 0     ; Máximo 5 enemigos, cada uno con 3 bytes (x, y, activo)
    enemies_count db 10            ; Cantidad de enemigos activos
    
    enemy_points dq 50              ; Puntos por destruir un enemigo
    enemy_move_counter db 0         ; Contador para controlar velocidad de movimiento
    enemy_move_delay db 9           ; Mover enemigos cada N ciclos
    enemy_move_total db 0      ; Contador total de movimientos
    enemy_target db 0          ; 0 = persigue bola, 1 = persigue paleta
    MOVEMENT_THRESHOLD db 20   ; Número de movimientos antes de cambiar objetivo
 ;Formato: número de bloques destruidos necesario para que aparezca cada enemigo
    ; Añade esto en la sección .dataa
    level1_spawn_points: db 70, 71, 72, 73, 74, 76, 120, 140, 160, 180    ; 10 enemigos, cada 2 bloques
    level2_spawn_points: db 0, 30, 50, 70, 85, 110, 130, 150, 170, 190    ; 10 enemigos, cada 2 bloques
    level3_spawn_points: db 0, 0, 0, 50, 55, 60, 100, 100, 100, 100   ; 10 enemigos, cada 3 bloques
    level4_spawn_points: db 0, 4, 15, 30, 40, 50, 70, 90, 100, 120  ; 10 enemigos, cada 3 bloques
    level5_spawn_points: db 0, 0, 10, 20, 30, 35, 40, 50, 60, 80 ; 10 enemigos, cada 5 bloques
        ; Arreglo de punteros a los spawn points de cada nivel
    spawn_points_table:
        dq level1_spawn_points
        dq level2_spawn_points
        dq level3_spawn_points
        dq level4_spawn_points
        dq level5_spawn_points

    ; Variables para el comportamiento de enemigos
    BEHAVIOR_CHANGE_TIME db 30    ; Ciclos antes de cambiar comportamiento
    behavior_counter db 0          ; Contador para cambio de comportamiento
    current_behavior db 0          ; 0 = persigue bola, 1 = persigue paleta
    enemy_spawns_triggered: times 10 db 0  ; 0 = no spawned, 1 = spawned

    score_label: db "Puntaje: [          ]", 0xA, 0xD  ; 10 espacios para el número
    score_label_len: equ $ - score_label
    blocks_label: db "Bloques destruidos: [   ]", 0xA, 0xD  ; 3 espacios para el número
    blocks_label_len: equ $ - blocks_label
    
    ; Posición donde insertar los números en los labels
    score_pos equ 10    ; Posición después de "Puntaje: ["
    blocks_pos equ 20   ; Posición después de "Bloques destruidos: ["
    
    ; Definición de las vidas (x, y, estado)
    ; Formato: posición_x, posición_y, estado (1 = activa, 0 = inactiva)
    lives_data: 
        db 2, 30, 1     ; Vida 1 (activa)
        db 4, 30, 1     ; Vida 2 (activa)
        db 6, 30, 1     ; Vida 3 (inactiva)
        db 8, 30, 0     ; Vida 4 (inactiva)
        db 10, 30, 0    ; Vida 5 (inactiva)
        db 12, 30, 0    ; Vida 6 (inactiva)
        db 14, 30, 0    ; Vida 7 (inactiva)
    lives_count equ 7    ; Total de vidas
    life_char db "^"    
    current_lives db 3   ; Contador de vidas activas actual

; Estructura para almacenar las letras y sus posiciones
    ; Formato: x, y, letra, activo (1 = activo, 0 = inactivo)
    letters_map: times 100 * 4 db 0  ; Espacio para 100 letras
    letters_count db 0   
    last_letter db ' '    ; Variable para almacenar la última letra
    last_letter_msg db "Poder actual: [ ]", 0xA, 0xD  ; Mensaje para mostrar la última letra
    last_letter_msg_len equ $ - last_letter_msg
    current_power_processed db 0 ; 0 = no procesado, 1 = ya procesado
    max_lives db 7              ; Máximo número de vidas permitidas
    ball_speed dq 7             ; Velocidad normal de la bola
    slow_ball_speed dq 2        ; Velocidad lenta (se usará como divisor)
    speed_counter dq 0          ; Contador para ralentizar el movimiento
   
    initial_catch_active db 0   ; 0 = inactivo, 1 = activo

    catch_power_active db 0     ; 0 = inactivo, 1 = activo
    ball_caught db 0           ; 0 = no atrapada, 1 = atrapada
    ball_caught_2 db 0           ; 0 = no atrapada, 1 = atrapada
    ball_caught_3 db 0           ; 0 = no atrapada, 1 = atrapada

    ball_catch_offset dq 0     ; Offset respecto a la paleta cuando está atrapada
    last_key db 0    ; Variable para almacenar la última tecla presionada

    laser_power_active: db 0         ; Flag para indicar si el poder láser está activo
    laser_symbol: db '|'             ; Símbolo para representar el láser
    laser_count: db 0                ; Contador de láseres activos
    lasers: times 200 db 0           ; Array para almacenar posiciones de láseres (x,y)
    laser_speed: dq 1                ; Velocidad del láser

    balls_data:     ; Array para almacenar hasta 3 bolas
        ; Bola 1 (principal)
        dq 0        ; x_pos
        dq 0        ; y_pos
        dq 1        ; direction_x
        dq -1       ; direction_y
        db 1        ; active
        ; Bola 2
        dq 0        ; x_pos
        dq 0        ; y_pos
        dq -1       ; direction_x
        dq -1       ; direction_y
        db 0        ; active
        ; Bola 3
        dq 0        ; x_pos
        dq 0        ; y_pos
        dq 0        ; direction_x
        dq -1       ; direction_y
        db 0        ; active
    
    balls_count db 1     ; Contador de bolas activas
    BALL_STRUCT_SIZE equ 33  ; Tamaño de cada estructura de bola (8*4 + 1)
    enemy_last_x:       times 10 db 0
    enemy_last_y:       times 10 db 0
    enemy_stuck_count:  times 10 db 0
    letter_move_counter db 0
    initial_ball_offset_x equ 2    ; Offset desde el centro de la paleta
    initial_ball_offset_y equ -1   ; Offset vertical desde la paleta

section .text


print_lives:
    push rbp
    mov rbp, rsp
    
    xor r12, r12                    ; Índice de la vida actual
    
    .print_loop:
        cmp r12, lives_count
        jge .end
        
        ; Calcular offset de la vida actual
        mov rax, r12
        imul rax, 3                     ; Cada vida ocupa 3 bytes (x, y, estado)
        lea rsi, [lives_data + rax]
        
        ; Calcular posición en el tablero
        movzx r8, byte [rsi]            ; X
        movzx r9, byte [rsi + 1]        ; Y
        
        ; Calcular offset en el tablero
        mov rax, column_cells
        add rax, 2                      ; Incluir caracteres de nueva línea
        mul r9
        add rax, r8
        lea rdi, [board + rax]
        
        ; Verificar estado de la vida y dibujar el carácter correspondiente
        cmp byte [rsi + 2], 1
        je .draw_active
        
        ; Si está inactiva, dibujar espacio
        mov byte [rdi], ' '
        jmp .next_life
        
    .draw_active:
        ; Si está activa, dibujar el símbolo de vida
        mov al, [life_char]
        mov [rdi], al
        
    .next_life:
        inc r12
        jmp .print_loop
        
    .end:
        pop rbp
        ret

; Función para desactivar una vida
; Función modificada para perder una vida
; Modificar lose_life para reiniciar solo la bola principal
lose_life:
    push rbp
    mov rbp, rsp
    
    ; Verificar si aún quedan vidas
    cmp byte [current_lives], 0
    je .game_lost
    
    ; Encontrar la última vida activa
    mov rcx, lives_count
    dec rcx
    
    .find_active_life:
        mov rax, rcx
        imul rax, 3
        lea rsi, [lives_data + rax]
        cmp byte [rsi + 2], 1
        je .deactivate_life
        dec rcx
        jns .find_active_life
        jmp .game_lost
        
    .deactivate_life:
        ; Borrar vida visualmente y en datos
        movzx r8, byte [rsi]
        movzx r9, byte [rsi + 1]
        mov rax, column_cells
        add rax, 2
        mul r9
        add rax, r8
        lea rdi, [board + rax]
        mov byte [rdi], ' '
        mov byte [rsi + 2], 0
        dec byte [current_lives]
        
        ; Borrar paleta anterior
        mov r8, [pallet_position]
        mov rcx, [pallet_size]
        .erase_pallet_loop:
            mov byte [r8], ' '
            inc r8
            dec rcx
            jnz .erase_pallet_loop
        
        ; Reiniciar solo la bola principal
        mov qword [ball_x_pos], 40
        mov qword [ball_y_pos], 28
        mov byte [ball_moving], 0
        mov byte [ball_active], 1       ; Activar bola principal
        mov qword [pallet_position], board + 38 + 29 * (column_cells + 2)
        
        ; Asegurarse que las otras bolas están desactivadas
        mov byte [ball2_active], 0
        mov byte [ball3_active], 0
        
        jmp .end
        
    .game_lost:
        call game_lost
        jmp .end
        
    .end:
        pop rbp
        ret
; Función modificada para verificar colisión con el borde inferior
check_bottom_collision:
    push rbp
    mov rbp, rsp
    
    ; Verificar si el nivel está completo (no quedan bloques)
    cmp byte [blocks_remaining], 0
    je .balls_remain            ; Si no quedan bloques, no perder vidas
    
    ; Verificar bola principal
    cmp byte [ball_active], 1
    jne .check_ball2
    mov rax, [ball_y_pos]
    cmp rax, row_cells - 2
    jne .check_ball2
    
    ; Borrar visualmente la bola principal
    mov r8, [ball_x_pos]
    mov r9, [ball_y_pos]
    add r8, board
    mov rcx, r9
    mov rax, column_cells + 2
    imul rcx
    add r8, rax
    mov byte [r8], char_space    ; Borrar la bola del tablero
    
    mov byte [ball_active], 0
    mov byte [ball_moving], 0

.check_ball2:
    cmp byte [ball2_active], 1
    jne .check_ball3
    mov rax, [ball2_y_pos]
    cmp rax, row_cells - 2
    jne .check_ball3
    mov byte [ball2_active], 0
    mov byte [ball2_moving], 0

.check_ball3:
    cmp byte [ball3_active], 1
    jne .check_active_balls
    mov rax, [ball3_y_pos]
    cmp rax, row_cells - 2
    jne .check_active_balls
    mov byte [ball3_active], 0
    mov byte [ball3_moving], 0

.check_active_balls:
    ; Verificar si quedan bolas activas
    xor rcx, rcx
    
    ; Contar bolas activas
    mov al, byte [ball_active]
    add rcx, rax
    mov al, byte [ball2_active]
    add rcx, rax
    mov al, byte [ball3_active]
    add rcx, rax
    
    ; Si no hay bolas activas y quedan bloques, perder vida
    test rcx, rcx
    jnz .balls_remain
    
    cmp byte [blocks_remaining], 0  ; Verificar si quedan bloques
    je .balls_remain               ; Si no quedan bloques, no perder vida
    
    call lose_life
    mov byte [ball_active], 1      ; Reactivar bola principal
    
.balls_remain:
    pop rbp
    ret

; Nueva función para game over
game_lost:
    ; Limpiar la pantalla
    print clear, clear_length
    
    ; Mostrar mensaje de derrota
    section .data
        lost_msg: db "¡Has perdido!", 0xA, 0xD
        lost_msg_len: equ $ - lost_msg
    section .text
    
    ; Imprimir mensaje de derrota
    print lost_msg, lost_msg_len
    print score_msg, score_msg_len
    
    ; Mostrar puntaje final
    mov rax, [current_score]
    mov rdi, number_buffer
    call number_to_string
    print number_buffer, 20
    
    ; Esperar un momento antes de salir
    mov qword [timespec + 0], 2    ; 2 segundos
    mov qword [timespec + 8], 0    ; 0 nanosegundos
    sleeptime
    
    jmp exit


; Función para registrar una nueva letra en el mapa
; Entrada:
;   al - letra a registrar
;   r8b - posición x
;   r9b - posición y
register_letter:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    cmp al, ' '
    je .end

    ; Encontrar un espacio libre en el mapa
    xor rcx, rcx
    movzx rdx, byte [letters_count]
    
    .find_slot:
        cmp rcx, 100              ; Máximo de letras
        jge .end                  ; Si no hay espacio, salir
        
        lea rbx, [letters_map + rcx * 4]
        cmp byte [rbx + 3], 0    ; Verificar si el slot está inactivo
        je .found_slot
        
        inc rcx
        jmp .find_slot
        
    .found_slot:
        ; Guardar la información de la letra
        mov [rbx], r8b           ; x
        mov [rbx + 1], r9b       ; y
        mov [rbx + 2], al        ; letra
        mov byte [rbx + 3], 1    ; marcar como activo
        
        inc byte [letters_count]
        
    .end:
        pop rcx
        pop rbx
        pop rbp
        ret

; Función para imprimir todas las letras registradas
print_letters:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    xor rcx, rcx
    
    .print_loop:
        cmp rcx, 100              ; Máximo de letras
        jge .end
        
        ; Obtener puntero a la letra actual
        lea rbx, [letters_map + rcx * 4]
        
        ; Verificar si está activa
        cmp byte [rbx + 3], 0
        je .next_letter
        
        ; Calcular posición en el tablero
        movzx r8, byte [rbx]      ; x
        movzx r9, byte [rbx + 1]  ; y
        
        ; Calcular offset en el tablero
        mov rax, column_cells
        add rax, 2                ; Incluir caracteres de nueva línea
        mul r9
        add rax, r8
        lea rdi, [board + rax]
        
        ; Imprimir la letra
        mov al, [rbx + 2]
        mov [rdi], al
        
    .next_letter:
        inc rcx
        jmp .print_loop
        
    .end:
        pop rcx
        pop rbx
        pop rbp
        ret

; Función para borrar una letra específica
; Entrada:
;   r8b - posición x
;   r9b - posición y
remove_letter:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    
    xor rcx, rcx
    
    .find_loop:
        cmp rcx, 100              ; Máximo de letras
        jge .end
        
        lea rbx, [letters_map + rcx * 4]
        
        ; Verificar si está activa y coincide la posición
        cmp byte [rbx + 3], 0
        je .next_letter
        
        mov al, [rbx]
        cmp al, r8b
        jne .next_letter
        
        mov al, [rbx + 1]
        cmp al, r9b
        jne .next_letter
        
        ; Encontrada la letra, desactivarla
        mov byte [rbx + 3], 0
        dec byte [letters_count]
        jmp .end
        
    .next_letter:
        inc rcx
        jmp .find_loop
        
    .end:
        pop rcx
        pop rbx
        pop rbp
        ret
; Función para mover las letras hacia abajo
move_letters:
    push rbp
    mov rbp, rsp
    push rbx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11

    xor rcx, rcx

    ; Verificar si debemos mover la letra en este frame
    inc byte [letter_move_counter]    ; Incrementar contador
    cmp byte [letter_move_counter], 11 ; Ajusta este número para cambiar velocidad
    jl .skip_all                         ; Si no es momento de mover, terminar
    mov byte [letter_move_counter], 0 ; Resetear contador

    .move_loop:
        cmp rcx, 100
        jge .print_last_letter
        
        lea rbx, [letters_map + rcx * 4]
        cmp byte [rbx + 3], 0
        je .next_letter

        movzx r8, byte [rbx]
        movzx r9, byte [rbx + 1]

        mov rax, column_cells
        add rax, 2
        mul r9
        add rax, r8
        lea rdi, [board + rax]
        mov byte [rdi], ' '

        inc byte [rbx + 1]
        movzx r9, byte [rbx + 1]

        cmp r9, row_cells - 1
        jl .check_pallet_collision

        mov byte [rbx + 3], 0
        jmp .next_letter

        .check_pallet_collision:
            mov rax, column_cells
            add rax, 2
            mul r9
            add rax, r8
            lea rdi, [board + rax]

            mov al, [rdi]
            cmp al, ' '
            je .next_letter
            cmp al, char_equal
            je .capture_letter

            mov al, [rbx + 2]
            mov [rdi], al
            jmp .next_letter

        .capture_letter:
            ; Obtener la nueva letra
            mov al, [rbx + 2]
            
            ; Comparar con la última letra
            cmp al, [last_letter]
            je .same_letter
            
            ; Es una letra diferente, resetear el procesamiento
            mov byte [current_power_processed], 0
            
            .same_letter:
            ; Guardar la nueva letra
            mov [last_letter], al
            
            ; Verificar si es 'E' para extender la paleta
            cmp al, 'E'
            je .extend_pallet
            
            ; Verificar si es 'P' para añadir vida
            cmp al, 'P'
            je .check_add_life

            cmp al, 'S'
            je .slow_ball

            cmp al, 'C'
            je .activate_catch
            
            cmp al, 'L'
            je .activate_laser

            cmp al, 'D'
            je .activate_split

            ; Si no es ningún power-up, restaurar tamaño normal
            mov rax, [default_pallet_size]
            mov [pallet_size], rax
            mov qword [ball_speed], 7    ; Restaurar velocidad normal
            mov byte [catch_power_active], 0
            mov byte [laser_power_active], 0
            jmp .finish_capture

            .extend_pallet:
                mov byte [laser_power_active], 0
                mov byte [catch_power_active], 0
                mov qword [ball_speed], 7    ; Restaurar velocidad normal
                mov rax, [extended_pallet_size]
                mov [pallet_size], rax
                jmp .finish_capture

            .check_add_life:
                mov byte [laser_power_active], 0
                mov byte [catch_power_active], 0
                mov rax, [default_pallet_size]
                mov [pallet_size], rax
                mov qword [ball_speed], 7 
                ; Verificar si ya procesamos este power-up
                cmp byte [current_power_processed], 0
                jne .finish_capture
                
                ; Preservar registros importantes
                push rcx
                push rbx
                
                ; Marcar como procesado
                mov byte [current_power_processed], 1
                
                ; Añadir una vida
                call add_life
                
                ; Restaurar registros
                pop rbx
                pop rcx
                
            .slow_ball:
                mov byte [laser_power_active], 0
                mov byte [catch_power_active], 0                
                mov rax, [default_pallet_size]
                mov [pallet_size], rax
                mov qword [ball_speed], 10    ; Activar velocidad lenta
                jmp .finish_capture

            .activate_catch:
                mov byte [laser_power_active], 0
                mov rax, [default_pallet_size]
                mov [pallet_size], rax
                mov qword [ball_speed], 7
                mov byte [catch_power_active], 1
                jmp .finish_capture

            .activate_laser:
                mov byte [catch_power_active], 0
                mov rax, [default_pallet_size]
                mov [pallet_size], rax
                mov qword [ball_speed], 7
                mov byte [laser_power_active], 1    ; Activar el poder láser
                jmp .finish_capture

            .activate_split:
                mov byte [laser_power_active], 0
                mov byte [catch_power_active], 0
                mov rax, [default_pallet_size]
                mov [pallet_size], rax
                mov qword [ball_speed], 7 
                call activate_split_power
                jmp .finish_capture

            .finish_capture:
                mov byte [rbx + 3], 0

        .next_letter:
            inc rcx
            jmp .move_loop

    .print_last_letter:
        ; ;; en vez de imprimir, saltamos
        jmp .end


    .skip_all:                        ; Nueva etiqueta para saltar todo cuando no movemos
        pop r11
        pop r10
        pop r9
        pop r8
        pop rsi
        pop rdi
        pop rbx
        pop rbp
        ret

    .end:
        pop r11
        pop r10
        pop r9
        pop r8
        pop rsi
        pop rdi
        pop rbx
        pop rbp
        ret

print_power_label:
    push rbp
    mov  rbp, rsp
    
    ; Crear buffer temporal
    sub rsp, 32
    
    ; Copiar el mensaje base al buffer
    mov rdi, rsp
    mov rsi, last_letter_msg
    mov rcx, last_letter_msg_len
    rep movsb
    
    ; Insertar la última letra capturada
    mov al, [last_letter]
    mov byte [rsp + 15], al    ; Asumiendo que 15 es la posición correcta
    
    ; Imprimir el buffer completo
    print rsp, last_letter_msg_len
    
    ; Restaurar stack
    add rsp, 32
    pop rbp
    ret



clear_lasers:
    push rbp
    mov  rbp, rsp

    ; Recorrer el array de láseres
    xor rcx, rcx                ; Índice del láser
    movzx rbx, byte [laser_count]  ; Cantidad de láseres activos

    .clear_loop:
        cmp rcx, rbx
        jge .done                ; Salir si no quedan láseres

        ; Obtener posición del láser actual
        lea rsi, [lasers + rcx * 2]
        movzx r8, byte [rsi]     ; X
        movzx r9, byte [rsi + 1] ; Y

        ; Calcular posición en el tablero
        mov rax, column_cells
        add rax, 2
        mul r9
        add rax, r8
        lea rdi, [board + rax]

        ; Borrar el láser visualmente
        mov byte [rdi], ' '

        ; Pasar al siguiente láser
        inc rcx
        jmp .clear_loop

    .done:
        ; Resetear contador de láseres
        mov byte [laser_count], 0

        pop rbp
        ret


; Nueva función para actualizar los láseres
update_lasers:
    push rbp
    mov rbp, rsp
    
    ; Verificar si el poder láser está activo
    cmp byte [laser_power_active], 0
    je .end
    
    ; Verificar si se presionó la tecla de espacio
    cmp byte [last_key], ' '
    jne .skip_shooting
    
    ; Disparar nuevos láseres
    call shoot_lasers
    mov byte [last_key], 0    ; Limpiar la tecla procesada
    
    .skip_shooting:
    ; Mover los láseres existentes
    call move_lasers
    
    .end:
        pop rbp
        ret

activate_split_power:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdx
    
    ; Si ambas bolas extra ya están activas, salimos
    mov cl, byte [ball2_active]
    and cl, byte [ball3_active]
    cmp cl, 1
    je .end
    
.find_active_ball:
    ; Guardar posición de la bola activa
    xor rax, rax    ; Limpiar rax
    xor rbx, rbx    ; Limpiar rbx
    
    ; Revisar ball1
    cmp byte [ball_active], 1
    je .use_ball1
    
    ; Revisar ball2
    cmp byte [ball2_active], 1
    je .use_ball2
    
    ; Revisar ball3
    cmp byte [ball3_active], 1
    je .use_ball3
    
    jmp .end        ; Si no hay bolas activas, salimos

.use_ball1:
    mov rax, qword [ball_x_pos]
    mov rbx, qword [ball_y_pos]
    jmp .create_missing_balls

.use_ball2:
    mov rax, qword [ball2_x_pos]
    mov rbx, qword [ball2_y_pos]
    jmp .create_missing_balls

.use_ball3:
    mov rax, qword [ball3_x_pos]
    mov rbx, qword [ball3_y_pos]
    jmp .create_missing_balls

.create_missing_balls:
    ; Intentar crear ball2 si no está activa
    cmp byte [ball2_active], 1
    je .create_ball3    ; Si ball2 ya está activa, intentar crear ball3
    
    ; Crear ball2
    mov qword [ball2_x_pos], rax
    mov qword [ball2_y_pos], rbx
    mov qword [ball2_direction_x], -1
    mov qword [ball2_direction_y], -1
    mov byte [ball2_moving], 1
    mov byte [ball2_active], 1
    
.create_ball3:
    ; Intentar crear ball3 si no está activa
    cmp byte [ball3_active], 1
    je .end
    
    ; Crear ball3
    mov qword [ball3_x_pos], rax
    mov qword [ball3_y_pos], rbx
    mov qword [ball3_direction_x], 1
    mov qword [ball3_direction_y], -1
    mov byte [ball3_moving], 1
    mov byte [ball3_active], 1

.end:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    pop rbp
    ret


shoot_lasers:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Verificar si hay espacio para más láseres
    movzx rax, byte [laser_count]
    cmp rax, 98  ; Asegurar que hay espacio para 2 láseres
    jge .end
    
    ; Obtener posición de la paleta
    mov r8, [pallet_position]
    sub r8, board                  ; Offset relativo de la paleta
    
    ; Calcular coordenadas x,y
    mov rax, r8
    mov r9, column_cells
    add r9, 2                     ; Ancho total de línea
    xor rdx, rdx
    div r9                        ; rax = y, rdx = x
    
    ; Guardar coordenadas
    mov r10, rax                  ; Y en r10
    mov r11, rdx                  ; X en r11
    
    ; Validar coordenadas
    cmp r10, 0
    jl .end
    cmp r10, row_cells
    jge .end
    cmp r11, 0
    jl .end
    cmp r11, column_cells
    jge .end
    
    ; Calcular índice para el primer láser
    movzx rbx, byte [laser_count]
    imul rbx, 2                   ; Cada láser usa 2 bytes
    
    ; Primer láser (izquierda)
    lea rdi, [lasers + rbx]
    mov [rdi], r11b              ; X
    mov al, r10b
    dec al                       ; Y - 1
    mov [rdi + 1], al           ; Y
    
    ; Segundo láser (derecha)
    mov al, r11b
    add al, byte [pallet_size]
    dec al                       ; Ajustar para el último carácter
    lea rdi, [lasers + rbx + 2]
    mov [rdi], al               ; X
    mov al, r10b
    dec al                      ; Y - 1
    mov [rdi + 1], al          ; Y
    
    ; Incrementar contador de láseres
    add byte [laser_count], 2
    
    
    .end:
        pop rbx
        pop rbp
        ret

; Función corregida para mover láseres
; Función corregida para mover láseres
; Esta es la parte clave para recorrer los láseres de atrás hacia adelante.

; Actualizar la función move_lasers para incluir verificación de colisiones
; ============================================================
; NUEVA FUNCIÓN move_lasers (todo-en-uno)
; ============================================================
; Mueve cada láser hacia arriba, verifica colisiones (bloques/enemigos)
; y lo elimina inmediatamente si choca, de lo contrario lo dibuja.
; ============================================================
move_lasers:
    push rbp
    mov  rbp, rsp
    push rbx
    push rdi
    push rsi
    push r12
    push r13
    push r14
    push r15

    ; 1) Tomamos la cantidad de láseres
    movzx rcx, byte [laser_count]
    test rcx, rcx
    jz .fin              ; Si es cero, no hay láseres => salir

    ; Ajustamos RCX para que sea el último índice (laser_count - 1)
    dec rcx              ; Empezamos desde el último láser

.loop_lasers:
    ; RSI apunta a lasers + (rcx * 2) => (x, y) del láser
    lea rsi, [lasers + rcx*2]

    ; 2) Cargar x,y actuales del láser
    movzx r8,  byte [rsi]      ; X
    movzx r9,  byte [rsi + 1]  ; Y

    ; 3) Borrar el láser de su posición actual en pantalla
    ;    (por si en el ciclo anterior se había dibujado)
    mov rax, column_cells
    add rax, 2
    mul r9
    add rax, r8
    lea rdi, [board + rax]
    mov byte [rdi], ' '        ; Borramos el símbolo anterior (láser)

    ; 4) Mover el láser hacia arriba (y - 1)
    dec r9

    ; Si y < 1, está fuera de pantalla => eliminarlo
    cmp r9, 1
    jl .delete_laser

    ; Guardamos la posición nueva en el array (aún no lo dibujamos)
    mov byte [rsi + 1], r9b

    ; 5) Verificamos colisión inmediata con bloques o enemigos
    ;    - Primero colisión con bloques
    ; ---------------------------------------------------------
    ; Calculamos la nueva dirección de memoria para esa posición (r9,r8)
    mov rax, column_cells
    add rax, 2
    mul r9
    add rax, r8
    lea rdi, [board + rax]   ; rdi apunta a la celda donde estaría el láser

    ; Revisar si hay bloque
    push rcx
    push rsi
    push rdi
    mov r10, rdi    ; En check_block_collision, r10 = posición en board
    call check_block_collision
    pop rdi
    pop rsi
    pop rcx

    test rax, rax          ; rax=1 => hubo colisión con bloque
    jnz .delete_laser      ; si chocó, eliminar ya el láser

    ;    - Luego colisión con enemigos
    ; ---------------------------------------------------------
    push rcx
    push rsi
    push rdi
    ; Pasamos (r8=X, r9=Y, r10=punteroEnBoard) a la función
    ; o podemos crear una versión inlined. A modo de ejemplo:
    ; Llamamos a check_laser_enemy_collision, que retorna
    ; rax=1 si hubo colisión con enemigo, 0 si no.
    ;
    ; Hacemos algo como:
    mov r10, rdi
    call check_laser_enemy_collision
    pop rdi
    pop rsi
    pop rcx

    test rax, rax          ; rax=1 => colisión con un enemigo
    jnz .delete_laser

    ; 6) Si NO hubo colisión, dibujamos el láser en la nueva posición
    mov al, [laser_symbol]
    mov [rdi], al

.next_laser:
    ; Pasamos al láser anterior en el array
    dec rcx
    cmp rcx, -1
    jg .loop_lasers   ; Mientras rcx >= 0, seguir iterando
    jmp .fin

; -----------------------------------------------------------------
; Subrutina interna: .delete_laser
; -----------------------------------------------------------------
; Elimina el láser actual del array 'lasers' moviendo el último
; láser a su posición (si no es el último). Decrementa laser_count.
.delete_laser:
    movzx r12, byte [laser_count]
    dec r12                    ; r12 = índice del último láser
    cmp r12, rcx
    jbe .just_decrement        ; Si rcx ya apunta al último, no copiamos

    ; Copiamos el último láser a la posición actual
    lea rdi, [lasers + rcx*2]
    lea rsi, [lasers + r12*2]
    mov ax, [rsi]             ; lee 2 bytes (X,Y) del último láser
    mov [rdi], ax             ; copiamos X,Y

.just_decrement:
    dec byte [laser_count]    ; Decrementar contador de láseres
    jmp .next_laser

.fin:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rbx
    pop rbp
    ret


; Nueva función para verificar colisión entre láser y enemigos
; ==========================================================
; NUEVA check_laser_enemy_collision - inlined destroy
; ==========================================================
check_laser_enemy_collision:
    push rbp
    mov  rbp, rsp
    
    xor r13, r13            ; Índice del enemigo
    xor rax, rax            ; 0 = no colisión

.loop_enemies:
    cmp r13, 5              ; Máximo 5 enemigos
    jge .end

    ; r13 * 3 => offset del enemigo i
    mov rcx, r13
    imul rcx, 3
    lea rsi, [enemies + rcx]   ; rsi => &enemies[i]

    ; Verificar si está activo
    cmp byte [rsi+2], 1
    jne .next_enemy

    ; Cargar posición X/Y del enemigo
    movzx r14, byte [rsi]      ; X
    movzx r15, byte [rsi+1]    ; Y

    ; Comparar con posición del láser (r8=X, r9=Y)
    cmp r8, r14
    jne .next_enemy
    cmp r9, r15
    jne .next_enemy

    ; ==== Colisión detectada con láser ====

    ; 1) Desactivar enemigo
    mov byte [rsi+2], 0     ; (activo=0)

    ; 2) Sumar puntos
    mov rax, [enemy_points]
    add [current_score], rax

    ; 3) (Opcional) Borrar del board, SOLO si no coincide con la paleta
    ;    Evita crasheos en la fila de la paleta (row_cells - 2).
    cmp r15, row_cells - 2
    je .skip_erase

    ; Borrar visualmente del board
    mov rax, column_cells
    add rax, 2
    mul r15
    add rax, r14
    lea rdi, [board + rax]
    mov byte [rdi], ' '

.skip_erase:

    ; 4) Devolver rax=1 => colisión con enemigo
    mov rax, 1
    jmp .end

.next_enemy:
    inc r13
    jmp .loop_enemies

.end:
    pop rbp
    ret


; Función auxiliar para eliminar un láser específico
remove_laser:
    push rbp
    mov rbp, rsp

    ; Borrar el láser del tablero
    mov byte [r10], ' '

    ; Mover el último láser a esta posición si no es el último
    movzx rax, byte [laser_count]
    dec rax                    ; Índice del último láser
    cmp r12, rax              ; Comparar con láser actual
    je .just_decrease         ; Si es el último, solo decrementar contador

    ; Copiar último láser a la posición actual
    lea rdi, [lasers + r12*2]
    lea rsi, [lasers + rax*2]
    mov dx, [rsi]             ; Copiar X,Y del último láser
    mov [rdi], dx

.just_decrease:
    dec byte [laser_count]    ; Decrementar contador de láseres

    pop rbp
    ret

add_life:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdi
    push rsi
    push r8
    push r9
    
    ; Verificar si ya tenemos el máximo de vidas
    movzx rax, byte [current_lives]
    cmp rax, 7          ; Comparar con el máximo de vidas
    jge .end
    
    ; Incrementar el contador de vidas
    inc byte [current_lives]
    
    ; Encontrar la siguiente vida inactiva
    xor rcx, rcx
    
    .find_inactive:
        cmp rcx, lives_count
        jge .end
        
        ; Calcular offset de la vida actual
        mov rax, rcx
        imul rax, 3
        lea rsi, [lives_data + rax]
        
        ; Verificar si está inactiva
        cmp byte [rsi + 2], 0
        je .activate_life
        
        inc rcx
        jmp .find_inactive
        
    .activate_life:
        ; Activar la vida
        mov byte [rsi + 2], 1
        
    .end:
        pop r9
        pop r8
        pop rsi
        pop rdi
        pop rcx
        pop rbx
        pop rbp
        ret


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

print_ball_2:
    mov r8, [ball2_x_pos]
    mov r9, [ball2_y_pos]
    add r8, board
    mov rcx, r9
    mov rax, column_cells + 2
    imul rcx
    add r8, rax
    mov byte [r8], char_O
    ret

print_ball_3:
    mov r8, [ball3_x_pos]
    mov r9, [ball3_y_pos]
    add r8, board
    mov rcx, r9
    mov rax, column_cells + 2
    imul rcx
    add r8, rax
    mov byte [r8], char_O
    ret

	;mov rax, board + r8 + r9 * (column_cells + 2)
	
print_pallet:
    ; Primero borrar la paleta anterior completa (usando el tamaño máximo posible)
    mov r8, [pallet_position]
    mov rcx, [pallet_size]
    .clear_pallet:
        mov byte [r8], char_space
        inc r8
        dec rcx
        jnz .clear_pallet

    ; Luego dibujar la nueva paleta con el tamaño actual
    mov r8, [pallet_position]
    mov rcx, [pallet_size]
    .write_pallet:
        mov byte [r8], char_equal
        inc r8
        dec rcx
        jnz .write_pallet

    ret

move_pallet:
    
    cmp byte [ball_moving], 0
    jne .continue_movement
    mov byte [ball_moving], 1

    .continue_movement:
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



            
; Nueva función auxiliar para actualizar la posición de la bola atrapada
update_caught_ball_position:
    push rbp
    mov rbp, rsp
    
    ; Calcular la nueva posición de la bola basada en la paleta
    mov r8, [pallet_position]
    sub r8, board          ; Obtener posición relativa
    mov rax, column_cells + 2
    xor rdx, rdx
    div rax                ; División para obtener X,Y
    
    ; rdx contiene X (resto), rax contiene Y (cociente)
    mov r9, rax            ; Y de la paleta
    dec r9                 ; Una posición arriba de la paleta
    
    ; Añadir el offset guardado a la posición X
    mov rax, rdx
    add rax, [ball_catch_offset]
    mov [ball_x_pos], rax
    mov [ball_y_pos], r9
    
    pop rbp
    ret


move_all_balls:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; Inicializar contador de bolas
    xor rbx, rbx
    
.loop_balls:
    ; Verificar si hemos procesado todas las bolas
    cmp bl, byte [balls_count]
    jge .end
    
    ; Calcular offset de la bola actual
    mov rax, BALL_STRUCT_SIZE
    mul rbx
    
    ; Verificar si la bola está activa
    cmp byte [balls_data + rax + 32], 1
    jne .next_ball
    
    ; Guardar offset en la pila
    push rax
    
    ; Llamar a move_ball con los parámetros de esta bola
    call move_ball
    
    ; Restaurar offset
    pop rax
    
.next_ball:
    inc rbx
    jmp .loop_balls
    
.end:
    pop rbx
    pop rbp
    ret

move_ball:

    cmp byte [ball_caught], 1
    je .move_with_pallet

    cmp byte [ball_moving], 0
    je .end

    ; Incrementar contador de velocidad
    inc qword [speed_counter]
    
    ; Verificar si debemos mover la bola en este ciclo
    mov rax, [speed_counter]
    cmp rax, [ball_speed]
    jl .end
    
    ; Resetear contador de velocidad
    mov qword [speed_counter], 0

    ; Borrar la posición actual de la bola
    mov r8, [ball_x_pos]
    mov r9, [ball_y_pos]
    add r8, board
    mov rcx, r9
    mov rax, column_cells + 2
    imul rcx
    add r8, rax
    mov byte [r8], char_space

    ; Calcular siguiente posición X
    mov r8, [ball_x_pos]
    mov r9, [ball_y_pos]
    mov rax, [ball_direction_x]
    add r8, rax               ; Nueva posición X

    ; Calcular la dirección de memoria para la siguiente posición
    mov r10, r8
    add r10, board
    mov rcx, r9
    mov rax, column_cells + 2
    imul rcx
    add r10, rax

    ; Verificar si hay una X en la siguiente posición X
    mov al, [r10]
    cmp al, 'X'
    jne .check_block_x
    neg qword [ball_direction_x]  ; Cambiar dirección X si hay una X
    jmp .end

    .move_with_pallet:
        ; Borrar la posición actual de la bola
        mov r8, [ball_x_pos]
        mov r9, [ball_y_pos]
        mov r10, r8
        add r10, board
        mov rcx, r9
        mov rax, column_cells + 2
        imul rcx
        add r10, rax
        mov byte [r10], char_space

        ; Actualizar posición X basada en la paleta
        mov r8, [pallet_position]      ; Obtener posición actual de la paleta
        sub r8, board                  ; Ajustar por el offset del tablero
        add r8, [ball_catch_offset]    ; Añadir el offset guardado
        mov [ball_x_pos], r8          ; Guardar nueva posición X

        ; Mantener la bola una posición arriba de la paleta
        mov r9, [ball_y_pos]          ; Mantener la misma altura
        mov [ball_y_pos], r9          ; Actualizar posición Y

        jmp .end


    .check_block_x:
        ; Verificar colisión con bloques en X
        push r8     ; Guardar registros que usa check_block_collision
        push r9
        push r10
        call check_block_collision
        pop r10
        pop r9
        pop r8
        test rax, rax
        jz .check_paddle_x      ; Si no hay colisión, verificar paleta
        neg qword [ball_direction_x]  ; Si hay colisión, rebotar
        jmp .end

    .check_paddle_x:
        ; Verificar si hay una paleta (=) en la siguiente posición X
        cmp byte [r10], char_equal
        jne .check_y_movement
        neg qword [ball_direction_x]  ; Cambiar dirección X si hay una paleta
        jmp .end

    .check_y_movement:
        ; Calcular siguiente posición Y
        mov rax, [ball_direction_y]
        add r9, rax                  ; Nueva posición Y

        ; Calcular la dirección de memoria para la siguiente posición Y
        mov r10, r8
        add r10, board
        mov rcx, r9
        mov rax, column_cells + 2
        imul rcx
        add r10, rax

        ; Verificar si hay una X en la siguiente posición Y
        mov al, [r10]
        cmp al, 'X'
        jne .check_block_y
        neg qword [ball_direction_y]  ; Cambiar dirección Y si hay una X
        jmp .end

    .check_block_y:
        ; Verificar colisión con bloques en Y
        push r8     ; Guardar registros que usa check_block_collision
        push r9
        push r10
        call check_block_collision
        pop r10
        pop r9
        pop r8
        test rax, rax
        jz .check_paddle_y      ; Si no hay colisión, verificar paleta
        neg qword [ball_direction_y]  ; Si hay colisión, rebotar
        jmp .end

    .check_paddle_y:
        ; Verificar si hay una paleta (=) en la siguiente posición Y
        cmp byte [r10], char_equal
        jne .update_position

        ; Verificar si el poder catch está activo
        cmp byte [catch_power_active], 1
        jne .normal_bounce

        ; Activar el modo "atrapado"
        mov byte [ball_caught], 1
        
        ; Guardar la posición X actual de la bola como offset
        mov rax, [ball_x_pos]           ; Posición X actual de la bola
        sub rax, [pallet_position]      ; Restar la posición de la paleta
        add rax, board                  ; Ajustar por el offset del tablero
        mov [ball_catch_offset], rax    ; Guardar el offset
        
        jmp .end

    .normal_bounce:
        neg qword [ball_direction_y]  ; Cambiar dirección Y si hay una paleta
        jmp .end


    .update_position:
        mov [ball_x_pos], r8
        mov [ball_y_pos], r9

    .end:
        ret


move_ball_2:

    cmp byte [ball_caught_2], 1
    je .move_with_pallet

    cmp byte [ball2_moving], 0
    je .end

    ; Incrementar contador de velocidad
    inc qword [speed_counter]
    
    ; Verificar si debemos mover la bola en este ciclo
    mov rax, [speed_counter]
    cmp rax, [ball_speed]
    jl .end
    
    ; Resetear contador de velocidad
    mov qword [speed_counter], 0

    ; Borrar la posición actual de la bola
    mov r8, [ball2_x_pos]
    mov r9, [ball2_y_pos]
    add r8, board
    mov rcx, r9
    mov rax, column_cells + 2
    imul rcx
    add r8, rax
    mov byte [r8], char_space

    ; Calcular siguiente posición X
    mov r8, [ball2_x_pos]
    mov r9, [ball2_y_pos]
    mov rax, [ball2_direction_x]
    add r8, rax               ; Nueva posición X

    ; Calcular la dirección de memoria para la siguiente posición
    mov r10, r8
    add r10, board
    mov rcx, r9
    mov rax, column_cells + 2
    imul rcx
    add r10, rax

    ; Verificar si hay una X en la siguiente posición X
    mov al, [r10]
    cmp al, 'X'
    jne .check_block_x
    neg qword [ball2_direction_x]  ; Cambiar dirección X si hay una X
    jmp .end

    .move_with_pallet:
        ; Borrar la posición actual de la bola
        mov r8, [ball2_x_pos]
        mov r9, [ball2_y_pos]
        mov r10, r8
        add r10, board
        mov rcx, r9
        mov rax, column_cells + 2
        imul rcx
        add r10, rax
        mov byte [r10], char_space

        ; Actualizar posición X basada en la paleta
        mov r8, [pallet_position]      ; Obtener posición actual de la paleta
        sub r8, board                  ; Ajustar por el offset del tablero
        add r8, [ball_catch_offset]    ; Añadir el offset guardado
        mov [ball2_x_pos], r8          ; Guardar nueva posición X

        ; Mantener la bola una posición arriba de la paleta
        mov r9, [ball2_y_pos]          ; Mantener la misma altura
        mov [ball2_y_pos], r9          ; Actualizar posición Y

        jmp .end


    .check_block_x:
        ; Verificar colisión con bloques en X
        push r8     ; Guardar registros que usa check_block_collision
        push r9
        push r10
        call check_block_collision
        pop r10
        pop r9
        pop r8
        test rax, rax
        jz .check_paddle_x      ; Si no hay colisión, verificar paleta
        neg qword [ball2_direction_x]  ; Si hay colisión, rebotar
        jmp .end

    .check_paddle_x:
        ; Verificar si hay una paleta (=) en la siguiente posición X
        cmp byte [r10], char_equal
        jne .check_y_movement
        neg qword [ball2_direction_x]  ; Cambiar dirección X si hay una paleta
        jmp .end

    .check_y_movement:
        ; Calcular siguiente posición Y
        mov rax, [ball2_direction_y]
        add r9, rax                  ; Nueva posición Y

        ; Calcular la dirección de memoria para la siguiente posición Y
        mov r10, r8
        add r10, board
        mov rcx, r9
        mov rax, column_cells + 2
        imul rcx
        add r10, rax

        ; Verificar si hay una X en la siguiente posición Y
        mov al, [r10]
        cmp al, 'X'
        jne .check_block_y
        neg qword [ball2_direction_y]  ; Cambiar dirección Y si hay una X
        jmp .end

    .check_block_y:
        ; Verificar colisión con bloques en Y
        push r8     ; Guardar registros que usa check_block_collision
        push r9
        push r10
        call check_block_collision
        pop r10
        pop r9
        pop r8
        test rax, rax
        jz .check_paddle_y      ; Si no hay colisión, verificar paleta
        neg qword [ball2_direction_y]  ; Si hay colisión, rebotar
        jmp .end

    .check_paddle_y:
        ; Verificar si hay una paleta (=) en la siguiente posición Y
        cmp byte [r10], char_equal
        jne .update_position

        ; Verificar si el poder catch está activo
        cmp byte [catch_power_active], 1
        jne .normal_bounce

        ; Activar el modo "atrapado"
        mov byte [ball_caught_2], 1
        
        ; Guardar la posición X actual de la bola como offset
        mov rax, [ball2_x_pos]           ; Posición X actual de la bola
        sub rax, [pallet_position]      ; Restar la posición de la paleta
        add rax, board                  ; Ajustar por el offset del tablero
        mov [ball_catch_offset], rax    ; Guardar el offset
        
        jmp .end

    .normal_bounce:
        neg qword [ball2_direction_y]  ; Cambiar dirección Y si hay una paleta
        jmp .end


    .update_position:
        mov [ball2_x_pos], r8
        mov [ball2_y_pos], r9

    .end:
        ret

move_ball_3:

    cmp byte [ball_caught_3], 1
    je .move_with_pallet

    cmp byte [ball3_moving], 0
    je .end

    ; Incrementar contador de velocidad
    inc qword [speed_counter]
    
    ; Verificar si debemos mover la bola en este ciclo
    mov rax, [speed_counter]
    cmp rax, [ball_speed]
    jl .end
    
    ; Resetear contador de velocidad
    mov qword [speed_counter], 0

    ; Borrar la posición actual de la bola
    mov r8, [ball3_x_pos]
    mov r9, [ball3_y_pos]
    add r8, board
    mov rcx, r9
    mov rax, column_cells + 2
    imul rcx
    add r8, rax
    mov byte [r8], char_space

    ; Calcular siguiente posición X
    mov r8, [ball3_x_pos]
    mov r9, [ball3_y_pos]
    mov rax, [ball3_direction_x]
    add r8, rax               ; Nueva posición X

    ; Calcular la dirección de memoria para la siguiente posición
    mov r10, r8
    add r10, board
    mov rcx, r9
    mov rax, column_cells + 2
    imul rcx
    add r10, rax

    ; Verificar si hay una X en la siguiente posición X
    mov al, [r10]
    cmp al, 'X'
    jne .check_block_x
    neg qword [ball3_direction_x]  ; Cambiar dirección X si hay una X
    jmp .end

    .move_with_pallet:
        ; Borrar la posición actual de la bola
        mov r8, [ball3_x_pos]
        mov r9, [ball3_y_pos]
        mov r10, r8
        add r10, board
        mov rcx, r9
        mov rax, column_cells + 2
        imul rcx
        add r10, rax
        mov byte [r10], char_space

        ; Actualizar posición X basada en la paleta
        mov r8, [pallet_position]      ; Obtener posición actual de la paleta
        sub r8, board                  ; Ajustar por el offset del tablero
        add r8, [ball_catch_offset]    ; Añadir el offset guardado
        mov [ball3_x_pos], r8          ; Guardar nueva posición X

        ; Mantener la bola una posición arriba de la paleta
        mov r9, [ball3_y_pos]          ; Mantener la misma altura
        mov [ball3_y_pos], r9          ; Actualizar posición Y

        jmp .end


    .check_block_x:
        ; Verificar colisión con bloques en X
        push r8     ; Guardar registros que usa check_block_collision
        push r9
        push r10
        call check_block_collision
        pop r10
        pop r9
        pop r8
        test rax, rax
        jz .check_paddle_x      ; Si no hay colisión, verificar paleta
        neg qword [ball3_direction_x]  ; Si hay colisión, rebotar
        jmp .end

    .check_paddle_x:
        ; Verificar si hay una paleta (=) en la siguiente posición X
        cmp byte [r10], char_equal
        jne .check_y_movement
        neg qword [ball3_direction_x]  ; Cambiar dirección X si hay una paleta
        jmp .end

    .check_y_movement:
        ; Calcular siguiente posición Y
        mov rax, [ball3_direction_y]
        add r9, rax                  ; Nueva posición Y

        ; Calcular la dirección de memoria para la siguiente posición Y
        mov r10, r8
        add r10, board
        mov rcx, r9
        mov rax, column_cells + 2
        imul rcx
        add r10, rax

        ; Verificar si hay una X en la siguiente posición Y
        mov al, [r10]
        cmp al, 'X'
        jne .check_block_y
        neg qword [ball3_direction_y]  ; Cambiar dirección Y si hay una X
        jmp .end

    .check_block_y:
        ; Verificar colisión con bloques en Y
        push r8     ; Guardar registros que usa check_block_collision
        push r9
        push r10
        call check_block_collision
        pop r10
        pop r9
        pop r8
        test rax, rax
        jz .check_paddle_y      ; Si no hay colisión, verificar paleta
        neg qword [ball3_direction_y]  ; Si hay colisión, rebotar
        jmp .end

    .check_paddle_y:
        ; Verificar si hay una paleta (=) en la siguiente posición Y
        cmp byte [r10], char_equal
        jne .update_position

        ; Verificar si el poder catch está activo
        cmp byte [catch_power_active], 1
        jne .normal_bounce

        ; Activar el modo "atrapado"
        mov byte [ball_caught_3], 1
        
        ; Guardar la posición X actual de la bola como offset
        mov rax, [ball3_x_pos]           ; Posición X actual de la bola
        sub rax, [pallet_position]      ; Restar la posición de la paleta
        add rax, board                  ; Ajustar por el offset del tablero
        mov [ball_catch_offset], rax    ; Guardar el offset
        
        jmp .end

    .normal_bounce:
        neg qword [ball3_direction_y]  ; Cambiar dirección Y si hay una paleta
        jmp .end


    .update_position:
        mov [ball3_x_pos], r8
        mov [ball3_y_pos], r9

    .end:
        ret

; Nueva función para procesar la tecla C cuando la bola está atrapada
; Procesar la tecla 'c' cuando el poder de atrapar está activo
process_catch_release:
    push rbp
    mov  rbp, rsp

    ; Verificar si el poder de catch está activo
    cmp byte [catch_power_active], 1
    jne .no_catch_power

    ; Verificar si se presionó 'c' (derecha y arriba)
    cmp byte [last_key], 'c'
    je .release_right
    
    ; Verificar si se presionó 'x' (izquierda y arriba)
    cmp byte [last_key], 'x'
    je .release_left
    
    jmp .no_catch_power

.release_right:
    ; Liberar la bola hacia la derecha
    cmp byte [ball_caught], 1
    jne .check_ball2_right
    mov byte [ball_caught], 0
    mov qword [ball_direction_x], 1    ; Derecha
    mov qword [ball_direction_y], -1   ; Arriba
    jmp .release_complete

.check_ball2_right:
    cmp byte [ball_caught_2], 1
    jne .check_ball3_right
    mov byte [ball_caught_2], 0
    mov qword [ball2_direction_x], 1
    mov qword [ball2_direction_y], -1
    jmp .release_complete

.check_ball3_right:
    cmp byte [ball_caught_3], 1
    jne .release_complete
    mov byte [ball_caught_3], 0
    mov qword [ball3_direction_x], 1
    mov qword [ball3_direction_y], -1
    jmp .release_complete

.release_left:
    ; Liberar la bola hacia la izquierda
    cmp byte [ball_caught], 1
    jne .check_ball2_left
    mov byte [ball_caught], 0
    mov qword [ball_direction_x], -1   ; Izquierda
    mov qword [ball_direction_y], -1   ; Arriba
    jmp .release_complete

.check_ball2_left:
    cmp byte [ball_caught_2], 1
    jne .check_ball3_left
    mov byte [ball_caught_2], 0
    mov qword [ball2_direction_x], -1
    mov qword [ball2_direction_y], -1
    jmp .release_complete

.check_ball3_left:
    cmp byte [ball_caught_3], 1
    jne .release_complete
    mov byte [ball_caught_3], 0
    mov qword [ball3_direction_x], -1
    mov qword [ball3_direction_y], -1

.release_complete:
    ; Si era el catch inicial, desactivarlo
    cmp byte [initial_catch_active], 1
    jne .finish
    mov byte [initial_catch_active], 0
    mov byte [catch_power_active], 0  ; Desactivar poder de catch después de la 1ra vez

.finish:
    mov byte [last_key], 0  ; Limpiar la tecla
.no_catch_power:
    pop rbp
    ret



display_level_number:
    push rbp
    mov rbp, rsp
    
    ; Limpiar la pantalla primero
    print clear, clear_length
    
    ; Calcular la posición central para el mensaje
    ; Para el mensaje "NIVEL X", necesitamos centrar 7 caracteres
    mov rax, column_cells
    sub rax, 7                  ; longitud de "NIVEL X"
    shr rax, 1                  ; dividir por 2 para centrar
    
    ; Calcular la fila central
    mov rbx, row_cells
    shr rbx, 1                  ; dividir por 2 para obtener la fila central
    
    ; Calcular el offset en el buffer
    mov rcx, column_cells + 2   ; ancho total de una línea incluyendo newline
    mul rbx                     ; multiplicar por la fila central
    add rax, rbx                ; añadir el offset horizontal
    
    ; Escribir "NIVEL " en la posición calculada
    lea rdi, [board + rax]
    mov rsi, level_msg
    mov rcx, level_msg_len
    rep movsb
    
    ; Escribir el número del nivel
    mov al, [current_level]
    add al, '0'                 ; convertir a ASCII
    mov [rdi], al
    
    ; Mostrar el board con el mensaje
    print board, board_size
    
    ; Esperar un segundo
    mov rax, sys_nanosleep
    mov rdi, level_display_time
    xor rsi, rsi
    syscall
    
    pop rbp
    ret

; Función para inicializar un tablero vacío
init_empty_board:
    push rsi
    push rdi
    push rcx
    push rax

    lea rsi, [board_template]   ; Copiar la plantilla del tablero
    lea rdi, [board]            ; Destino: el tablero actual
    mov rcx, board_template_size
    rep movsb                   ; Copiar el tablero

    pop rax
    pop rcx
    pop rdi
    pop rsi
    ret

clear_enemies_from_board:
    push rbp
    mov rbp, rsp
    push rsi
    push rdi

    ; Primero limpiar board
    mov rcx, board_size      
    lea rsi, [board]         

.clear_loop:
    cmp rcx, 0              
    je .clear_template      ; En vez de terminar, vamos a limpiar template
    
    mov al, [rsi]           
    cmp al, '@'             
    je .make_space
    cmp al, '#'             
    je .make_space
    cmp al, '$'             
    je .make_space
    cmp al, '&'             
    je .make_space
    
    jmp .next               

.make_space:
    mov byte [rsi], ' '     

.next:
    inc rsi                 
    dec rcx                
    jmp .clear_loop        

.clear_template:
    ; Ahora limpiar board_template
    mov rcx, board_template_size
    lea rsi, [board_template]

.template_loop:
    cmp rcx, 0
    je .end
    
    mov al, [rsi]
    cmp al, '@'
    je .make_space_template
    cmp al, '#'
    je .make_space_template
    cmp al, '$'
    je .make_space_template
    cmp al, '&'
    je .make_space_template
    
    jmp .next_template

.make_space_template:
    mov byte [rsi], ' '

.next_template:
    inc rsi
    dec rcx
    jmp .template_loop

.end:
    pop rdi
    pop rsi
    pop rbp
    ret




init_level:
    call clear_enemies_from_board
    mov byte [ball2_active], 0
    mov byte [ball3_active], 0
    mov byte [laser_power_active], 0
    call clear_lasers
    mov rax, [default_pallet_size]
    mov [pallet_size], rax
    mov qword [ball_speed], 7    ; Restaurar velocidad normal

    ; 1) Copiamos board_template en board para que quede "virgen"
        ; Reiniciar letras activas
    lea rdi, [letters_map]
    mov rcx, 100 * 4             ; Cada letra ocupa 4 bytes, limpiar 100 letras
    xor rax, rax
    rep stosb                    ; Llenar con ceros
    
    ; Inicializar dirección de la bola (derecha y arriba)
    mov qword [ball_direction_x], 1    ; Dirección hacia la derecha (1 = derecha, -1 = izquierda)
    mov qword [ball_direction_y], -1   ; Dirección hacia arriba (-1 = arriba, 1 = abajo)

    ; En init_level, después de inicializar las direcciones
    mov byte [catch_power_active], 1    ; Activar el poder catch
    mov byte [ball_caught], 1           ; Marcar la bola como atrapada
    mov byte [initial_catch_active], 1  ; Marcar que es el catch inicial

    ; Calcular y guardar el offset inicial de la bola respecto a la paleta
    mov rax, [ball_x_pos]              ; Posición X actual de la bola
    sub rax, [pallet_position]         ; Restar la posición de la paleta
    add rax, board                     ; Ajustar por el offset del tablero
    mov [ball_catch_offset], rax       ; Guardar el offset



    ; Reiniciar contador de letras activas
    xor rax, rax
    mov [letters_count], al

    ; Reiniciar última letra capturada
    mov byte [last_letter], ' '
    mov byte [destroyed_blocks], 0 
    call init_empty_board
    call display_level_number

    push rsi
    push rdi
    push rcx
    push rax

    lea rsi, [board_template]
    lea rdi, [board]
    mov rcx, board_template_size
    rep movsb                 ; Copiamos la plantilla a board

    pop rax
    pop rcx
    pop rdi
    pop rsi

    mov rcx, 10
    xor rax, rax
    lea rdi, [enemy_spawns_triggered]
    rep stosb   
    call init_enemies   

    ; Verificar el nivel actual y cargar los bloques correspondientes
    cmp byte [current_level], 1
    je .level1
    cmp byte [current_level], 2
    je .level2
    cmp byte [current_level], 3
    je .level3
    cmp byte [current_level], 4
    je .level4
    cmp byte [current_level], 5
    je .level5
    jmp .done



    .level1:
        mov byte [blocks_remaining], level1_blocks_count
        xor rcx, rcx             
        .init_loop1:
            cmp rcx, level1_blocks_count
            jge .done
            mov rax, rcx         
            imul rax, 5         ; en vez de shl rax,2
            mov dl, byte [level1_blocks + rax + 3]  
            mov byte [block_states + rcx], dl
            inc rcx
            jmp .init_loop1

    .level2:
        mov byte [blocks_remaining], level2_blocks_count
        xor rcx, rcx             
        .init_loop2:
            cmp rcx, level2_blocks_count
            jge .done
            mov rax, rcx         
            imul rax, 5         ; en vez de shl rax,2
            mov dl, byte [level2_blocks + rax + 3]  
            mov byte [block_states + rcx], dl
            inc rcx
            jmp .init_loop2
    .level3:
        mov byte [blocks_remaining], 64
        xor rcx, rcx             
        .init_loop3:
            cmp rcx, level3_blocks_count
            jge .done
            mov rax, rcx         
            imul rax, 5         ; en vez de shl rax,2
            mov dl, byte [level3_blocks + rax + 3]  
            mov byte [block_states + rcx], dl
            inc rcx
            jmp .init_loop3

    .level4:
        mov byte [blocks_remaining], level4_blocks_count
        xor rcx, rcx             
        .init_loop4:
            cmp rcx, level4_blocks_count
            jge .done
            mov rax, rcx         
            imul rax, 5         ; en vez de shl rax,2
            mov dl, byte [level4_blocks + rax + 3]  
            mov byte [block_states + rcx], dl
            inc rcx
            jmp .init_loop4

    .level5:
        mov byte [blocks_remaining], level5_blocks_count
        xor rcx, rcx             
        .init_loop5:
            cmp rcx, level5_blocks_count
            jge .done
            mov rax, rcx         
            imul rax, 5         ; en vez de shl rax,2
            mov dl, byte [level5_blocks + rax + 3]  
            mov byte [block_states + rcx], dl
            inc rcx
            jmp .init_loop5
    .done:
        ret


; Función para verificar y manejar la transición de nivel
check_level_complete:
    ; Verificar si quedan bloques
    cmp byte [blocks_remaining], 0
    jne .not_complete
    
    ; Incrementar el nivel
    inc byte [current_level]
    
    ; Verificar si hemos completado todos los niveles
    cmp byte [current_level], 6
    je game_win
    

    call clear_enemies_from_board
    ; Primero establecer las posiciones seguras
    mov qword [pallet_position], board + 38 + 29 * (column_cells + 2)
    mov qword [ball_x_pos], 40
    mov qword [ball_y_pos], 28
    mov byte [ball_moving], 0
    
    ; Asegurar que la bola esté en un estado seguro
    mov byte [catch_power_active], 1
    mov byte [ball_caught], 1
    mov byte [initial_catch_active], 1
    
    ; Reinicializar el juego para el siguiente nivel
    call init_level
    
.not_complete:
    ret

    ; Nueva función para manejar la victoria del juego
game_win:
    ; Limpiar la pantalla primero
    print clear, clear_length
    
    ; Mensaje de victoria
    mov rax, [current_score]    ; Obtener el puntaje final
    mov rdi, number_buffer      ; Convertir a string
    call number_to_string
    
    ; Definir mensaje de victoria
    section .data
        win_msg: db "¡Felicidades! ¡Has ganado!", 0xA, 0xD
        win_msg_len: equ $ - win_msg
        score_msg: db "Puntaje final: "
        score_msg_len: equ $ - score_msg
    section .text
    
    ; Imprimir mensajes
    print win_msg, win_msg_len
    print score_msg, score_msg_len
    print number_buffer, 20
    
    ; Esperar un momento antes de salir
    mov qword [timespec + 0], 2    ; 2 segundos
    mov qword [timespec + 8], 0    ; 0 nanosegundos
    sleeptime
    
    jmp exit

; Función para imprimir los bloques
; Función modificada para imprimir bloques

; Primero, agreguemos una función para obtener el puntero a los bloques del nivel actual
get_current_level_blocks:
    cmp byte [current_level], 1
    je .level1
    cmp byte [current_level], 2
    je .level2
    cmp byte [current_level], 3
    je .level3
    cmp byte [current_level], 4
    je .level4
    cmp byte [current_level], 5
    je .level5
    ; Si llegamos aquí, hay un error en el nivel
    xor rax, rax
    ret

    .level1:
        lea rax, [level1_blocks]
        ret
    .level2:
        lea rax, [level2_blocks]
        ret
    .level3:
        lea rax, [level3_blocks]
        ret
    .level4:
        lea rax, [level4_blocks]
        ret
    .level5:
        lea rax, [level5_blocks]
        ret
; Función para obtener la cantidad de bloques del nivel actual
get_current_level_count:
    cmp byte [current_level], 1
    je .level1
    cmp byte [current_level], 2
    je .level2
    cmp byte [current_level], 3
    je .level3
    cmp byte [current_level], 4
    je .level4
    cmp byte [current_level], 5
    je .level5
    ; Si llegamos aquí, hay un error en el nivel
    xor rax, rax
    ret

    .level1:
        mov rax, level1_blocks_count
        ret
    .level2:
        mov rax, level2_blocks_count
        ret
    .level3:
        mov rax, level3_blocks_count
        ret
    .level4:
        mov rax, level4_blocks_count
        ret
    .level5:
        mov rax, level5_blocks_count
        ret


print_blocks:
    push rbp
    mov rbp, rsp
    
    ; Obtener puntero a los bloques del nivel actual
    call get_current_level_blocks
    mov r13, rax                  ; Guardar puntero a los bloques en r13
    
    ; Obtener cantidad de bloques del nivel actual
    call get_current_level_count
    mov r14, rax                  ; Guardar cantidad de bloques en r14
    
    xor r12, r12                  ; Índice del bloque actual
    
    .print_loop:
        cmp r12, r14                  ; Usar r14 en lugar de level1_blocks_count
        jge .end
        
        ; Verificar si el bloque está activo
        movzx rax, byte [block_states + r12]
        test rax, rax
        jz .next_block
        
        ; Obtener posición y tipo del bloque usando r13
        mov rax, r12
        imul rax, 5
        add rax, r13
        mov r8b, [rax]        ; X position
        mov r9b, [rax + 1]    ; Y position
        mov r10b, [rax + 2]   ; Tipo de bloque

        ; El resto de la lógica de impresión permanece igual
        movzx r8, r8b
        movzx r9, r9b
        add r8, board
        mov rax, column_cells + 2
        mul r9
        add r8, rax
        
        mov rcx, block_length
        mov rsi, block_type_1
        movzx rax, r10b
        dec rax
        imul rax, block_length
        add rsi, rax
        
    .print_block_chars:
        mov al, [rsi]
        mov [r8], al
        inc rsi
        inc r8
        dec rcx
        jnz .print_block_chars
        
    .next_block:
        inc r12
        jmp .print_loop
        
    .end:
        pop rbp
        ret

; Función para convertir número a string
; Input: RAX = número a convertir
; RDI = buffer donde escribir el string
number_to_string:
    push rbx
    push rdx
    push rsi
    mov rbx, 10          ; Divisor
    mov rcx, 0          ; Contador de dígitos
    
    ; Si el número es 0, manejarlo especialmente
    test rax, rax
    jnz .convert_loop
    mov byte [rdi], '0'
    mov byte [rdi + 1], 0
    jmp .end
    
    .convert_loop:
        xor rdx, rdx    ; Limpiar RDX para la división
        div rbx         ; RAX/10, cociente en RAX, residuo en RDX
        add dl, '0'     ; Convertir a ASCII
        push rdx        ; Guardar el dígito
        inc rcx         ; Incrementar contador
        test rax, rax   ; Verificar si quedan más dígitos
        jnz .convert_loop
        
    .write_loop:
        pop rdx         ; Obtener dígito
        mov [rdi], dl   ; Escribir al buffer
        inc rdi         ; Siguiente posición
        dec rcx         ; Decrementar contador
        jnz .write_loop
        
    mov byte [rdi], 0   ; Null terminator
    
    .end:
    pop rsi
    pop rdx
    pop rbx
    ret

; Función para imprimir los labels
print_labels:
    push rbp
    mov rbp, rsp

    ; Crear buffer temporal
    sub rsp, 32

    ; Copiar labels a buffer temporal
    mov rdi, rsp
    lea rsi, [score_label]
    mov rcx, score_label_len
    rep movsb

    ; Convertir score a string
    mov rax, [current_score]
    mov rdi, number_buffer
    call number_to_string

    ; Calcular longitud del número
    mov rcx, 0
    mov rdi, number_buffer
    .count_loop:
        cmp byte [rdi + rcx], 0
        je .count_done
        inc rcx
        jmp .count_loop
    .count_done:

    ; Insertar el número en la posición correcta, alineado a la derecha
    mov rdi, rsp
    add rdi, score_pos           ; Moverse a la posición del número
    mov rsi, 10                  ; Espacio reservado para el número
    sub rsi, rcx                 ; Calcular padding necesario
    .pad_loop:
        test rsi, rsi
        jz .pad_done
        mov byte [rdi], ' '      ; Añadir espacio de padding
        inc rdi
        dec rsi
        jmp .pad_loop
    .pad_done:

    ; Copiar el número
    mov rsi, number_buffer
    rep movsb

    ; Imprimir el buffer completo
    print rsp, score_label_len

    ; Repetir proceso para bloques destruidos
    mov rdi, rsp
    lea rsi, [blocks_label]
    mov rcx, blocks_label_len
    rep movsb

    ; Verificar que el `[` esté en su posición correcta
    mov rdi, rsp
    add rdi, blocks_pos - 1  ; Posición exacta donde debe ir el '['
    mov byte [rdi], '['      ; Garantizar que el `[` esté presente

    ; Convertir bloques destruidos a string
    movzx rax, byte [destroyed_blocks]
    mov rdi, number_buffer
    call number_to_string

    ; Calcular longitud del número
    mov rcx, 0
    mov rdi, number_buffer
    .count_loop2:
        cmp byte [rdi + rcx], 0
        je .count_done2
        inc rcx
        jmp .count_loop2
    .count_done2:

    ; Insertar el número en la posición correcta, alineado a la derecha
    mov rdi, rsp
    add rdi, blocks_pos         ; Moverse a la posición del número
    mov rsi, 3                  ; Espacio reservado para el número
    sub rsi, rcx                ; Calcular padding necesario
    .pad_loop2:
        test rsi, rsi
        jz .pad_done2
        mov byte [rdi], ' '      ; Añadir espacio de padding
        inc rdi
        dec rsi
        jmp .pad_loop2
    .pad_done2:

    ; Copiar el número
    mov rsi, number_buffer
    rep movsb

    ; Imprimir el buffer completo
    print rsp, blocks_label_len

    ; Restaurar stack
    add rsp, 32
    pop rbp
    ret



check_block_collision:
    push rbp
    mov rbp, rsp

    ; Almacenar el carácter en la posición r10 (pos. de la bola en board[])
    mov al, [r10]

    ; Verificar si el carácter es un bloque
    cmp al, 'U'  
    je .possible
    cmp al, 'O'  
    je .possible
    cmp al, 'D'  
    je .possible
    cmp al, 'L'  
    je .possible
    cmp al, 'V'  
    je .possible
    cmp al, '8'  
    je .possible

    ; No es bloque, salir
    xor rax, rax
    pop rbp
    ret

.possible:
    push rbx
    push rdi
    push rsi
    push r12
    push r13
    push r14
    push r15

    ; 1) Obtener base de los bloques del nivel actual
    call get_current_level_blocks
    mov r13, rax  ; (r13) = base de levelX_blocks

    ; 2) Obtener la cantidad de bloques
    call get_current_level_count
    mov r14, rax

    xor r12, r12  ; Índice del bloque actual

.find_block_loop:
    cmp r12, r14
    jge .no_block_found  ; Se acabaron los bloques

    ; Calcular puntero base del bloque actual en levelX_blocks
    mov rax, r12
    imul rax, 5            ; (x, y, tipo, durabilidad_inicial, letra)
    add rax, r13
    mov r15, rax           ; r15 apunta a los datos del bloque actual

    ; --- Aquí la diferencia: la durabilidad no la leemos de [r15+3], sino de block_states[r12]
    movzx rbx, byte [block_states + r12]  ; Durabilidad "viva" en block_states
    test rbx, rbx
    jz .next_block  ; si durabilidad=0 => bloque destruido => ignorar

    ; Obtener coordenadas
    mov dl, [r15]         ; x
    mov cl, [r15 + 1]     ; y

    ; Calcular posición en el board
    lea rdi, [board]
    xor rax, rax
    mov rax, column_cells
    add rax, 2
    movzx rcx, cl         ; y
    imul rax, rcx
    add rdi, rax
    movzx rax, dl         ; x
    add rdi, rax

    ; Guardar la posición base del bloque
    push rdi

    ; Verificar si la bola (r10) está dentro de [rdi .. rdi+block_length)
    cmp r10, rdi
    jb .skip_collision
    lea rbx, [rdi + block_length]
    cmp r10, rbx
    jae .skip_collision

    ; ------- Hay colisión, reducir durabilidad en block_states
    dec byte [block_states + r12]
    ; Volver a cargar durabilidad
    movzx rbx, byte [block_states + r12]
    test rbx, rbx
    jnz .update_display  ; si no llegó a 0 => solo "golpeado"

    ; >>> Llegó a 0 => Bloque destruido
    pop rdi  ; recuperar puntero base del bloque en board
    mov rcx, block_length
.clear_loop:
    mov byte [rdi], ' '
    inc rdi
    loop .clear_loop

    ; Dibujar letra del bloque destruido
    mov al, [r15 + 4]  ; Obtener la letra asociada
    sub rdi, block_length
    mov [rdi], al      ; Escribir la letra en la posición inicial
    ; Después de escribir la letra en el tablero
    mov al, [r15 + 4]      ; Obtener la letra
    movzx r8, byte [r15]   ; Posición x del bloque
    movzx r9, byte [r15 + 1] ; Posición y del bloque
    call register_letter
    ; Actualizar contadores globales
    dec byte [blocks_remaining]
    inc byte [destroyed_blocks]

    ; Sumar puntos según el tipo
    movzx rax, byte [r15 + 2]  ; tipo del bloque original
    imul rax, 10
    add [current_score], rax

    mov rax, 1  ; colisión con destrucción
    jmp .end_pop

.update_display:
    ; => durabilidad >0, se podría actualizar el "look" del bloque
    mov rax, 1  ; colisión con "rebote"  
    pop rdi     ; pop que quedó pendiente
    jmp .end_pop

.skip_collision:
    pop rdi     ; si no hubo colisión, quita de la pila
.next_block:
    inc r12
    jmp .find_block_loop

.no_block_found:
    xor rax, rax  ; 0 => no hubo colisión

.end_pop:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rbx
    pop rbp
    ret



init_enemies:
    push rbp
    mov rbp, rsp
    
    ; Reiniciar contadores de movimiento
    mov byte [enemy_move_total], 0
    mov byte [enemy_target], 0
    
    ; Limpiar completamente el array de enemigos
    mov rcx, 30  ; 10 enemigos * 3 bytes cada uno
    lea rdi, [enemies]
    xor al, al
    rep stosb    ; Llenar todo con ceros
    
    ; Marcar todos los spawns como no activados
    lea rdi, [enemy_spawns_triggered]
    mov rcx, 10
    rep stosb
    
    pop rbp
    ret


random_move_enemy:
    push rbp
    mov  rbp, rsp
    push rbx
    push rdx
    push rdi

    ; r12 = índice del enemigo
    ; 1) obtener puntero al enemigo i
    mov rax, r12
    imul rax, 3
    lea rbx, [enemies + rax]     ; rbx => &enemies[r12]

    ; 2) Cargar X, Y actuales (NO SE BORRA AQUÍ TODAVÍA)
    movzx r8, byte [rbx]         ; r8 = X actual
    movzx r9, byte [rbx + 1]     ; r9 = Y actual

    ; 3) Generar "movimiento aleatorio" => tomamos [enemy_move_counter] & 3
    movzx rax, byte [enemy_move_counter]
    and rax, 3

    cmp rax, 0
    je .try_left
    cmp rax, 1
    je .try_right
    cmp rax, 2
    je .try_up
    ; si es 3 => mover abajo
.try_down:
    inc r9
    jmp .check_valid

.try_up:
    dec r9
    jmp .check_valid

.try_right:
    inc r8
    jmp .check_valid

.try_left:
    dec r8

.check_valid:
    ; 4) Verificar límites
    cmp r8, 1                    
    jle .invalid_move
    cmp r8, column_cells        
    jge .invalid_move
    cmp r9, 1                    
    jle .invalid_move
    cmp r9, row_cells          
    jge .invalid_move

    ; 5) Verificar colisión con bloques/enemigos
    push r8
    push r9
    mov rax, column_cells
    add rax, 2
    mul r9
    add rax, r8
    lea rdi, [board + rax]
    mov al, [rdi]

    ; Revisa si es bloque o borde
    cmp al, 'U'
    je .pop_and_invalid
    cmp al, 'O'
    je .pop_and_invalid
    cmp al, 'D'
    je .pop_and_invalid
    cmp al, 'L'
    je .pop_and_invalid
    cmp al, 'V'
    je .pop_and_invalid
    cmp al, '8'
    je .pop_and_invalid
    cmp al, 'X'
    je .pop_and_invalid

    ; Revisa si hay enemigo
    cmp al, '@'
    je .pop_and_invalid
    cmp al, '#'
    je .pop_and_invalid
    cmp al, '$'
    je .pop_and_invalid
    cmp al, '&'
    je .pop_and_invalid

    call check_enemy_at_position
    cmp rax, 1
    je .pop_and_invalid

    ; ------------------------------
    ; SI LLEGAMOS AQUI => POSICIÓN NUEVA ES VÁLIDA
    ; AHORA SÍ BORRAMOS LA POSICIÓN ANTIGUA:
    ; ------------------------------
    pop r9
    pop r8

    ; (A) Borrar la posición antigua en el board
    ;    (X,Y) originales estaban en [rbx], [rbx+1].
    movzx r10, byte [rbx]   ; oldX
    movzx r11, byte [rbx+1] ; oldY
    mov rax, column_cells
    add rax, 2
    mul r11
    add rax, r10
    lea rdi, [board + rax]
    mov byte [rdi], ' '     ; BORRA la posición vieja

    ; (B) Guardar la nueva X,Y en la estructura
    mov byte [rbx], r8b
    mov byte [rbx + 1], r9b

    jmp .done

.pop_and_invalid:
    pop r9
    pop r8

.invalid_move:
    ; Restablecer la posición X,Y en [rbx], [rbx+1] (no se borró la vieja)
    movzx r8, byte [rbx]
    movzx r9, byte [rbx + 1]
    ; Se queda donde estaba
.done:
    pop rdi
    pop rdx
    pop rbx
    pop rbp
    ret


; Función para mover enemigos
move_enemies:
    push rbp
    mov rbp, rsp
    
    ; Incrementar contador de movimiento
    inc byte [enemy_move_counter]
    movzx rax, byte [enemy_move_counter]
    cmp al, [enemy_move_delay]
    jne .end
    
    ; Resetear contador
    mov byte [enemy_move_counter], 0
    
    xor r12, r12                    ; Índice del enemigo
    
    .enemy_loop:
        cmp r12, 10                     ; Máximo 10 enemigos
        jge .end
        
        ; Calcular offset del enemigo actual
        mov rax, r12
        imul rax, 3                     ; Cada enemigo ocupa 3 bytes
        lea rsi, [enemies + rax]
        
        ; Verificar si el enemigo está activo
        cmp byte [rsi + 2], 1
        jne .next_enemy
        
        ; Obtener posición actual
        movzx r8, byte [rsi]            ; X
        movzx r9, byte [rsi + 1]        ; Y
        
        lea rdi, [enemy_last_x]
        add rdi, r12
        mov al, [rdi]             ; al = last_x

        lea rdx, [enemy_last_y]
        add rdx, r12
        mov ah, [rdx]             ; ah = last_y

        ; r8 = X actual del enemigo
        ; r9 = Y actual del enemigo

        ; *** En lugar de cmp ah, r9b => hacemos lo siguiente:
        mov dl, ah      ; dl = old_Y
        mov bl, r9b     ; bl = new_Y
        cmp dl, bl
        jne .not_stuck

        ; => SI son iguales => pasa al siguiente check
        mov dl, al      ; dl = old_X
        mov bl, r8b     ; bl = new_X
        cmp dl, bl
        jne .not_stuck

        ; => MISMA POSICIÓN (STUCK)
        lea rbx, [enemy_stuck_count]
        add rbx, r12
        inc byte [rbx]              ; Aumentar contador de “pegarse”

        ; Verificar si supera umbral, digamos 3
        movzx rcx, byte [rbx]
        cmp rcx, 2
        jl .check_normal_move       ; Si aún no llega a 3, seguir normal

        ; SI LLEGA A 3, FORZAR UN MOVIMIENTO ALEATORIO:
        ;  1) resetear el stuck_count
        mov byte [rbx], 0

        ;  2) cambiar random
        call random_move_enemy        ; (Ver ejemplo de abajo)
        jmp .next_enemy

    .not_stuck:
        ; => Se movió
        lea rbx, [enemy_stuck_count]
        add rbx, r12
        mov byte [rbx], 0            ; Resetear

        ; Guardar su nueva posición en “last_x, last_y”
        lea rdi, [enemy_last_x]
        add rdi, r12
        mov [rdi], r8b
        
        lea rdi, [enemy_last_y]
        add rdi, r12
        mov [rdi], r9b

        ; Limpiar posición actual antes de mover
    .check_normal_move:
        push r8
        push r9
        mov rax, column_cells
        add rax, 2
        mul r9
        add rax, r8
        lea rdi, [board + rax]
        mov byte [rdi], ' '         ; Limpiar rastro
        pop r9
        pop r8

        ; Determinar comportamiento basado en índice
        mov rax, r12
        and rax, 1                      ; 0 para índices pares, 1 para impares
        test rax, rax
        jz .chase_ball
        jmp .chase_paddle             ; Si es 1, perseguir paleta
        
        ; Perseguir bola (comportamiento original)
    .chase_ball:
        mov r10, [ball_x_pos]
        cmp r8, r10
        jg .move_left
        jl .move_right
        
        mov r10, [ball_y_pos]
        cmp r9, r10
        jg .move_up
        jl .move_down
        jmp .check_collision
        
    .chase_paddle:
        ; Obtener la posición X actual de la paleta
        mov r10, [pallet_position]
        sub r10, board              ; Convertir a offset relativo
        
        ; Calcular la posición X real de la paleta
        mov rax, r10
        mov rbx, column_cells
        add rbx, 2                  ; Añadir newline chars
        xor rdx, rdx
        div rbx                     ; rax = y, rdx = x
        
        ; rdx ahora contiene la posición X de la paleta
        ; Añadir la mitad del tamaño de la paleta para apuntar al centro
        mov rcx, [pallet_size]
        shr rcx, 1                  ; Dividir por 2
        add rdx, rcx
        
        ; Comparar con posición X del enemigo y mover gradualmente
        cmp r8, rdx
        je .check_y_paddle          ; Si está en la misma X, verificar Y
        jg .move_left              ; Si está a la derecha, mover izquierda
        jl .move_right             ; Si está a la izquierda, mover derecha

    .check_y_paddle:
        ; La Y de la paleta siempre es row_cells - 2
        mov r10, row_cells
        sub r10, 2
        
        ; Comparar con posición Y del enemigo y mover gradualmente
        cmp r9, r10
        je .no_movement            ; Si está en la misma Y, no mover
        jg .move_up               ; Si está abajo, mover arriba
        jl .move_down             ; Si está arriba, mover abajo
        
    .no_movement:
        jmp .check_collision

    ; También agregar una nueva sección para el movimiento suave
    .smooth_transition:
        ; Si el enemigo está muy lejos de su objetivo, limitar el movimiento
        mov al, [enemy_target]
        test al, al
        jz .check_collision        ; Si persigue la bola, movimiento normal
        
        ; Verificar distancia en X
        mov r10, rdx              ; Posición X objetivo
        sub r10, r8               ; Calcular diferencia
        cmp r10, 5               ; Si la diferencia es mayor a 5
        jg .limit_right_movement  ; Limitar movimiento a la derecha
        cmp r10, -5              ; Si la diferencia es menor a -5
        jl .limit_left_movement   ; Limitar movimiento a la izquierda
        jmp .check_collision
        
    .limit_right_movement:
        add r8, 2                ; Mover solo 2 unidades a la derecha
        jmp .check_collision
        
    .limit_left_movement:
        sub r8, 2                ; Mover solo 2 unidades a la izquierda
        jmp .check_collision
    .move_left:
        dec r8
        jmp .check_vertical
        
    .move_right:
        inc r8
        jmp .check_vertical
        
    .move_up:
        dec r9
        jmp .check_collision
        
    .move_down:
        inc r9
        jmp .check_collision
        
    .check_vertical:
        mov al, [enemy_target]
        test al, al
        jnz .chase_paddle         ; Si persigue paleta, volver a su lógica
        mov r10, [ball_y_pos]     ; Si no, seguir persiguiendo la bola
        cmp r9, r10
        jg .move_up
        jl .move_down
        
    .check_collision:
        ; Verificar colisión con bordes
        cmp r8, 1                       ; Borde izquierdo
        jle .next_enemy
        cmp r8, column_cells
        jge .next_enemy
        cmp r9, 1                       ; Borde superior
        jle .next_enemy
        cmp r9, row_cells
        jge .next_enemy
        
        ; Verificar colisión con bloques antes de moverse
        push r8
        push r9
        push r10
        
        ; Calcular posición en el tablero para verificar
        mov rax, column_cells
        add rax, 2
        mul r9
        add rax, r8
        lea r10, [board + rax]
        
        ; Verificar si hay un bloque en la nueva posición
        mov al, [r10]
        cmp al, 'U'
        je .invalid_move
        cmp al, 'O'
        je .invalid_move
        cmp al, 'D'
        je .invalid_move
        cmp al, 'L'
        je .invalid_move
        cmp al, 'V'
        je .invalid_move
        cmp al, '8'
        je .invalid_move
        cmp al, 'X'
        je .invalid_move
        cmp al, '@'                 ; Enemigo nivel 1 y 5
        je .invalid_move
        cmp al, '#'                 ; Enemigo nivel 2
        je .invalid_move
        cmp al, '$'                 ; Enemigo nivel 3
        je .invalid_move
        cmp al, '&'                 ; Enemigo nivel 4
        je .invalid_move
        
        call check_enemy_at_position
        cmp rax, 1
        je .invalid_move
        pop r10
        pop r9
        pop r8
        
        ; Guardar nueva posición si es válida
        mov [rsi], r8b
        mov [rsi + 1], r9b
        jmp .next_enemy
        
    .invalid_move:
        pop r10
        pop r9
        pop r8
        
    .next_enemy:
        inc r12
        jmp .enemy_loop
        
    .end:
        pop rbp
        ret

check_enemy_at_position:
    push rbp
    mov rbp, rsp
    
    ; Parámetros esperados en r8 (X) y r9 (Y)
    mov rax, column_cells
    add rax, 2
    mul r9
    add rax, r8
    lea rdi, [board + rax]
    movzx rax, byte [rdi]
    
    ; Verificar todos los caracteres de enemigos
    cmp al, '@'
    je .enemy_found
    cmp al, '#'
    je .enemy_found
    cmp al, '$'
    je .enemy_found
    cmp al, '&'
    je .enemy_found
    
    xor rax, rax    ; No hay enemigo (retorna 0)
    jmp .end
    
.enemy_found:
    mov rax, 1      ; Hay enemigo (retorna 1)
    
.end:
    pop rbp
    ret

get_current_spawn_points:
    push rbp
    mov rbp, rsp
    
    movzx rax, byte [current_level]
    dec rax                         ; Ajustar para índice base 0
    mov rax, [spawn_points_table + rax * 8]
    
    pop rbp
    ret

; Función para verificar si debe aparecer un nuevo enemigo
check_enemy_spawn:
    push rbp
    mov rbp, rsp
    
    ; Obtener spawn points del nivel actual
    call get_current_spawn_points
    mov r12, rax                    ; r12 = puntero a spawn points
    
    ; Obtener cantidad de bloques destruidos
    movzx r13, byte [destroyed_blocks]
    
    ; Verificar cada punto de spawn
    xor rcx, rcx                    ; Índice del enemigo
    
    .check_loop:
        cmp rcx, 10                     ; Máximo 10 enemigos
        jge .end
        
        ; Verificar si este spawn point ya fue usado
        cmp byte [enemy_spawns_triggered + rcx], 1
        je .next_enemy
        
        ; Verificar si este enemigo ya está activo
        mov rax, rcx
        imul rax, 3                     ; Cada enemigo ocupa 3 bytes
        lea rsi, [enemies + rax]
        cmp byte [rsi + 2], 1          ; Verificar si está activo
        je .next_enemy
        
        ; Verificar si debemos spawnear este enemigo
        movzx rax, byte [r12 + rcx]    ; Obtener punto de spawn
        cmp r13, rax                   ; Comparar con bloques destruidos
        jne .next_enemy
        
        ; Marcar este spawn point como usado
        mov byte [enemy_spawns_triggered + rcx], 1
        
        ; Spawner nuevo enemigo
        mov al, 4
        add al, cl       ; con 'rcx' como índice
        mov [rsi], al
        mov byte [rsi+1], 2
        mov byte [rsi+2], 1

        ; Inicializar comportamiento
        mov rax, rcx
        and rax, 1                     ; Alternar comportamiento basado en índice par/impar
        mov [current_behavior], al      ; 0 = persigue bola, 1 = persigue paleta
        
    .next_enemy:
        inc rcx
        jmp .check_loop
        
    .end:
        pop rbp
        ret


; Función para dibujar enemigos
print_enemies:
    push rbp
    mov rbp, rsp
    
    xor r12, r12                    ; Índice del enemigo
    
    .print_loop:
        cmp r12, 10                      ; Máximo 5 enemigos
        jge .end
        
        ; Calcular offset del enemigo actual
        mov rax, r12
        imul rax, 3                     ; Cada enemigo ocupa 3 bytes
        lea rsi, [enemies + rax]
        
        ; Verificar si el enemigo está activo
        cmp byte [rsi + 2], 1
        jne .next_enemy
        
        ; Calcular posición en el tablero
        movzx r8, byte [rsi]            ; X
        movzx r9, byte [rsi + 1]        ; Y
        
        ; Calcular offset en el tablero
        mov rax, column_cells
        add rax, 2                      ; Incluir caracteres de nueva línea
        mul r9
        add rax, r8
        lea rdi, [board + rax]
        
        ; Obtener carácter del enemigo según el nivel
        movzx rax, byte [current_level]
        dec rax                         ; Ajustar para índice base 0
        mov al, [enemy_chars + rax]
        
        ; Dibujar enemigo
        mov [rdi], al
        
    .next_enemy:
        inc r12
        jmp .print_loop
        
    .end:
        pop rbp
        ret

; Función para verificar colisión con enemigos
; Función para verificar colisión con enemigos
check_enemy_collision:
    push rbp
    mov rbp, rsp
    
    xor r12, r12                    ; Índice del enemigo
    xor rax, rax                    ; Valor de retorno (0 = no colisión)
    
    .check_loop:
        cmp r12, 5                      ; Máximo 5 enemigos
        jge .end
        
        ; Calcular offset del enemigo actual
        mov rcx, r12
        imul rcx, 3                     ; Cada enemigo ocupa 3 bytes
        lea rsi, [enemies + rcx]
        
        ; Verificar si el enemigo está activo
        cmp byte [rsi + 2], 1
        jne .next_enemy
        
        ; Verificar colisión con la bola
        movzx r8, byte [rsi]            ; X enemigo
        movzx r9, byte [rsi + 1]        ; Y enemigo
        
        ; Verificar si la bola está en el rango del enemigo (considerando el enemigo como un área)
        mov r10, [ball_x_pos]
        mov r11, [ball_y_pos]
        
        ; Comprobar colisión vertical (misma columna)
        cmp r10, r8
        jne .check_horizontal
        sub r11, r9
        cmp r11, 1
        jg .check_horizontal
        cmp r11, -1
        jl .check_horizontal
        
        ; Colisión vertical detectada
        call destroy_enemy
        neg qword [ball_direction_y]    ; Invertir dirección vertical
        mov rax, 1
        jmp .end
        
    .check_horizontal:
        ; Comprobar colisión horizontal (misma fila)
        mov r10, [ball_x_pos]
        mov r11, [ball_y_pos]
        cmp r11, r9
        jne .check_paddle
        sub r10, r8
        cmp r10, 1
        jg .check_paddle
        cmp r10, -1
        jl .check_paddle
        
        ; Colisión horizontal detectada
        call destroy_enemy
        neg qword [ball_direction_x]    ; Invertir dirección horizontal
        mov rax, 1
        jmp .end
        
    .check_paddle:
        ; Verificar colisión con la paleta
        mov r10, [pallet_position]
        sub r10, board
        mov rax, r10
        mov r11, column_cells
        add r11, 2
        xor rdx, rdx
        div r11                     ; División para obtener la posición Y
        mov r11, rdx               ; X de la paleta en r11
        
        mov rcx, [pallet_size]     ; Obtener el tamaño de la paleta
        
        ; Verificar si el enemigo está en la misma fila que la paleta
        mov r13, row_cells
        sub r13, 2                 ; Y de la paleta
        cmp r9, r13               ; Comparar Y del enemigo con Y de la paleta
        jne .next_enemy
        
        ; Verificar si el enemigo está dentro del rango X de la paleta
        cmp r8, r11               ; Comparar X del enemigo con X inicial de la paleta
        jl .next_enemy
        
        add r11, rcx              ; Añadir el tamaño de la paleta
        cmp r8, r11               ; Comparar X del enemigo con X final de la paleta
        jg .next_enemy
        
        ; Si llegamos aquí, hay colisión con la paleta
        call destroy_enemy        ; Destruir el enemigo
        mov rax, 1                ; Indicar que hubo colisión
        jmp .end
        
    .next_enemy:
        inc r12
        jmp .check_loop
        
    .end:
        pop rbp
        ret

; Función para destruir un enemigo
destroy_enemy:
    ; Desactivar enemigo
    mov byte [rsi + 2], 0   ; Marcar enemigo como inactivo

    ; Sumar puntos por destruir enemigo
    mov rax, [enemy_points]
    add [current_score], rax

    ; No tocar bloques destruidos aquí
    ret


_start:
	call canonical_off
	call start_screen
    call init_level
	jmp .main_loop
	

    .main_loop:
        call print_labels
        call print_blocks
        call move_letters
        call update_lasers
        call print_letters
        call print_pallet
        
        ; Mover bola principal solo si está activa
        cmp byte [ball_active], 1
        jne .skip_ball1
            call move_ball
        .skip_ball1:

        ; Mover bola 2 si está activa
        cmp byte [ball2_active], 1
        jne .skip_ball2
            call move_ball_2
        .skip_ball2:

        ; Mover bola 3 si está activa
        cmp byte [ball3_active], 1
        jne .skip_ball3
            call move_ball_3
        .skip_ball3:

        call check_bottom_collision    ; Nueva función que maneja todas las bolas
        call print_lives

        ; Imprimir solo las bolas activas
        cmp byte [ball_active], 1
        jne .no_pb1
            call print_ball
        .no_pb1:

        cmp byte [ball2_active], 1
        jne .no_pb2
            call print_ball_2
        .no_pb2:

        cmp byte [ball3_active], 1
        jne .no_pb3
            call print_ball_3
        .no_pb3:

        call check_level_complete
        call check_enemy_spawn
        call move_enemies
        call check_enemy_collision
        call print_enemies
        call print_power_label
		print board, board_size				
		;setnonblocking	
	.read_more:	
	    getchar	
	    cmp rax, 1
	    jne .done
	
	    mov al, [input_char]
	    mov [last_key], al      ; Registrar la última tecla presionada
	
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
	    cmp al, 'c'             ; Verificar si se presionó la tecla 'c'
	    je .release_ball        ; Si sí, liberar la bola
	
        cmp al, 'x'             ; Verificar si se presionó la tecla 'c'
	    je .release_ball        ; Si sí, liberar la bola
	

	    cmp al, 'q' 
	    je exit
	    jmp .read_more
	
    .release_ball:
	    call process_catch_release
	    jmp .done
	
    .done:
	    sleeptime
	    print clear, clear_length
	    jmp .main_loop




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

