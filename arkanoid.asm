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
column_cells: 	equ 78 ; set to any (reasonable) value you wish
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
        
	pallet_position dq board + 40 + 29 * (column_cells +2)
	pallet_size dq 5

	ball_x_pos: dq 40
	ball_y_pos: dq 28
    ball_direction_x dq 1    ; 1 = derecha, -1 = izquierda
    ball_direction_y dq -1   ; -1 = arriba, 1 = abajo
    ball_moving db 0         ; 0 = estática, 1 = en movimiento

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
    current_level db 1
    blocks_remaining db 0

    ; Definición del nivel 1 (ejemplo con múltiples bloques)
    ; Formato: x_pos, y_pos, tipo_bloque, durabilidad_actual
    level1_blocks:
        ; Tercera fila (tipo 3)
        db 56, 7, 3, 2    ; Bloque 7
    level1_blocks_count equ 1   ; Cantidad total de bloques

    ; Nivel 2: Bloques de prueba
    level2_blocks:
        db 60, 7, 1, 1    ; Un bloque simple en el nivel 2   ; Un bloque simple en el nivel 2
    level2_blocks_count equ 1

    ; Nivel 3
    level3_blocks:
        db 60, 7, 2, 1    ; Bloque 1

    level3_blocks_count equ 1

    ; Nivel 4
    level4_blocks:
        db 60, 7, 4, 1    ; Bloque 1
    level4_blocks_count equ 1

    ; Nivel 5
    level5_blocks:
        db 60, 7, 5, 1    ; Bloque 1
    level5_blocks_count equ 1

    ; Array para mantener el estado de los bloques
    block_states: times 100 db 0  ; Durabilidad actual de cada bloque

    score_label db "Puntaje: "
    score_label_len equ $ - score_label
    blocks_label db "Bloques destruidos: "
    blocks_label_len equ $ - blocks_label
    
    ; Variables para almacenar los valores
    current_score dq 0          ; Score actual
    destroyed_blocks db 0       ; Bloques destruidos en el nivel actual
    
    ; Buffer para convertir números a string
    number_buffer: times 20 db 0

    enemy_chars db "@", "#", "$", "&", "@"    ; El nivel 1 y 5 comparten el mismo caracter (@)
    
    ; Estructura para los enemigos (x, y, activo)
    enemies: times 5 * 3 db 0     ; Máximo 5 enemigos, cada uno con 3 bytes (x, y, activo)
    enemies_count db 2            ; Cantidad de enemigos activos
    
    enemy_points dq 50              ; Puntos por destruir un enemigo
    enemy_move_counter db 0         ; Contador para controlar velocidad de movimiento
    enemy_move_delay db 3           ; Mover enemigos cada N ciclos
    enemy_move_total db 0      ; Contador total de movimientos
    enemy_target db 0          ; 0 = persigue bola, 1 = persigue paleta
    MOVEMENT_THRESHOLD db 20   ; Número de movimientos antes de cambiar objetivo

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

move_ball:
    ; Si la bola no está en movimiento, no hacer nada
    cmp byte [ball_moving], 0
    je .end

    ; Borrar la posición actual de la bola
    mov r8, [ball_x_pos]
    mov r9, [ball_y_pos]
    add r8, board
    mov rcx, r9
    mov rax, column_cells + 2
    imul rcx
    add r8, rax
    mov byte [r8], char_space    ; Borrar la bola actual

    ; Calcular siguiente posición X
    mov r8, [ball_x_pos]
    mov r9, [ball_y_pos]
    mov rax, [ball_direction_x]
    add r8, rax                  ; Nueva posición X

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
    neg qword [ball_direction_y]  ; Cambiar dirección Y si hay una paleta
    jmp .end


    .update_position:
        mov [ball_x_pos], r8
        mov [ball_y_pos], r9

    .end:
        ret

; Función para inicializar el nivel
; Función para inicializar el nivel
; Función para mostrar el número de nivel
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


init_level:
    ; 1) Copiamos board_template en board para que quede "virgen"
    mov byte [destroyed_blocks], 0 
    call init_empty_board
    call display_level_number
    call init_enemies
    
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
            shl rax, 2          
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
            shl rax, 2          
            mov dl, byte [level2_blocks + rax + 3]  
            mov byte [block_states + rcx], dl
            inc rcx
            jmp .init_loop2
    .level3:
        mov byte [blocks_remaining], level3_blocks_count
        xor rcx, rcx             
        .init_loop3:
            cmp rcx, level3_blocks_count
            jge .done
            mov rax, rcx         
            shl rax, 2          
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
            shl rax, 2          
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
            shl rax, 2          
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
    
    ; Verificar si hemos completado todos los niveles (asumiendo 2 niveles por ahora)
    cmp byte [current_level], 6
    je game_win
    
    ; Reinicializar el juego para el siguiente nivel
    call init_level
    
    ; Reinicializar la posición de la bola y la paleta
    mov qword [ball_x_pos], 40
    mov qword [ball_y_pos], 28
    mov byte [ball_moving], 0
    mov qword [pallet_position], board + 40 + 29 * (column_cells + 2)
    
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
        mov r8b, [r13 + r12 * 4]      ; X position
        mov r9b, [r13 + r12 * 4 + 1]  ; Y position
        mov r10b, [r13 + r12 * 4 + 2] ; Tipo de bloque
        
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
    
    ; Guardar el score en string
    mov rax, [current_score]
    mov rdi, number_buffer
    call number_to_string
    
    ; Imprimir score label
    print score_label, score_label_len
    print number_buffer, 20
    
    ; Nueva línea
    mov byte [number_buffer], 0xA
    mov byte [number_buffer + 1], 0xD
    print number_buffer, 2
    
    ; Convertir bloques destruidos a string
    movzx rax, byte [destroyed_blocks]
    mov rdi, number_buffer
    call number_to_string
    
    ; Imprimir label de bloques destruidos
    print blocks_label, blocks_label_len
    print number_buffer, 20
    
    ; Nueva línea
    mov byte [number_buffer], 0xA
    mov byte [number_buffer + 1], 0xD
    print number_buffer, 2
    
    pop rbp
    ret

; Función modificada para detectar colisión
; Función mejorada para detectar colisión y manejar la física
; Función corregida para manejar colisiones con bloques completos
;---------------------------------------------------------
; check_block_collision:
;   Detecta si en la posición r10 (que apunta a board[])
;   hay un bloque ("UUUU","OOOO","DDDD","LLLL","VVVV","8888").
;   De ser así, localiza qué bloque es, lo "destruye" y
;   retorna 1 para indicar colisión. Si no encuentra bloque,
;   retorna 0.
;---------------------------------------------------------
;--------------------------------------
; check_block_collision
;--------------------------------------
; Actualizar check_block_collision para usar el nivel actual
check_block_collision:
    push rbp
    mov rbp, rsp

    mov al, [r10]

    ; Verificación de caracteres igual que antes...
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

    xor rax, rax
    pop rbp
    ret

    .possible:
        push rbx
        push rdi
        push rsi
        push r12

        ; Obtener puntero a los bloques del nivel actual
        call get_current_level_blocks
        mov r13, rax                  ; Guardar puntero a los bloques
        
        ; Obtener cantidad de bloques del nivel actual
        call get_current_level_count
        mov r14, rax                  ; Guardar cantidad de bloques

        xor r12, r12
    .find_block_loop:
        cmp r12, r14                  ; Usar r14 en lugar de level1_blocks_count
        jge .no_block_found

        ; El resto de la lógica de verificación de colisiones...
        mov bl, [block_states + r12]
        test bl, bl
        jz .next_block

        ; Usar r13 para acceder a los bloques del nivel actual
        mov rax, r13
        imul r12, 4
        add rax, r12
        mov dl, [rax]       ; x
        mov cl, [rax+1]     ; y

        ; Revertir r12
        mov r12, r12
        shr r12, 2

        ; La misma lógica de detección de colisiones...
        lea rdi, [board]
        xor rax, rax
        mov rax, column_cells + 2
        movzx rcx, cl
        imul rax, rcx
        add rdi, rax
        movzx rax, dl
        add rdi, rax

        cmp r10, rdi
        jb .next_block
        lea rbx, [rdi + 6]
        cmp r10, rbx
        jae .next_block

        ; Manejo de colisión igual que antes...
        dec byte [block_states + r12]
        mov bl, [block_states + r12]
        test bl, bl
        jnz .still_alive

        mov rcx, block_length
    .erase_block_chars:
        mov byte [rdi], char_space
        inc rdi
        loop .erase_block_chars

        dec byte [blocks_remaining]
        inc byte [destroyed_blocks]     ; Incrementar contador de bloques destruidos
    
        ; Calcular puntos basado en la durabilidad original del bloque
        mov rax, r12                    ; Índice del bloque
        imul rax, 4                     ; Multiplicar por 4 (tamaño de cada entrada)
        add rax, r13                    ; Agregar base de los bloques
        movzx rax, byte [rax + 2]       ; Obtener tipo de bloque (durabilidad original)
        imul rax, 10                    ; Multiplicar por 10
        add [current_score], rax        ; Agregar al score total

    .still_alive:
        mov rax, 1
        pop r12
        pop rsi
        pop rdi
        pop rbx
        pop rbp
        ret

    .next_block:
        inc r12
        jmp .find_block_loop

    .no_block_found:
        xor rax, rax
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
    mov byte [enemy_target], 0      ; Inicialmente persigue la bola
    ; Limpiar estado previo de enemigos
    mov rcx, 15                     ; 5 enemigos * 3 bytes
    lea rdi, [enemies]
    xor al, al
    rep stosb
    
    ; Configurar enemigo según el nivel actual
    movzx rcx, byte [current_level]
    dec rcx                         ; Ajustar para índice base 0
    
    ; Activar un enemigo
    lea rdi, [enemies]
    
    ; Posición X inicial (centro de la pantalla)
    mov byte [rdi], 4
    
    ; Posición Y inicial (cerca de la parte superior)
    mov byte [rdi + 1], 1
    
    ; Marcar como activo
    mov byte [rdi + 2], 1
    
    ; Establecer cantidad de enemigos activos
    mov byte [enemies_count], 1
    
    pop rbp
    ret

; Función para mover enemigos
move_enemies:
    push rbp
    mov rbp, rsp
    
    ; Control de velocidad de movimiento
    inc byte [enemy_move_counter]
    mov al, [enemy_move_counter]
    cmp al, [enemy_move_delay]
    jl .end
    
    ; Resetear contador
    mov byte [enemy_move_counter], 0
    
    ; Incrementar contador total de movimientos y verificar umbral
    inc byte [enemy_move_total]
    mov al, [enemy_move_total]
    cmp al, [MOVEMENT_THRESHOLD]
    jl .continue_normal
    mov byte [enemy_target], 1    ; Cambiar a perseguir paleta
    
    .continue_normal:
        ; Iterar sobre enemigos
        xor r12, r12                    ; Índice del enemigo
        
    .enemy_loop:
        cmp r12, 5                      ; Máximo 5 enemigos
        jge .end
        
        ; Calcular offset del enemigo actual
        mov rax, r12
        imul rax, 3                     ; Cada enemigo ocupa 3 bytes
        lea rsi, [enemies + rax]
        
        ; Verificar si el enemigo está activo
        cmp byte [rsi + 2], 1
        jne .next_enemy
        
        ; Obtener posición actual del enemigo
        movzx r8, byte [rsi]            ; X
        movzx r9, byte [rsi + 1]        ; Y
        
        ; Borrar posición actual del enemigo en el tablero
        push r8                         ; Guardar coordenadas actuales
        push r9
        
        ; Calcular offset en el tablero para borrar
        mov rax, column_cells
        add rax, 2                      ; Incluir caracteres de nueva línea
        mul r9
        add rax, r8
        lea rdi, [board + rax]
        mov byte [rdi], ' '             ; Borrar posición actual
        
        pop r9                          ; Restaurar coordenadas
        pop r8
        
        ; Decidir objetivo basado en enemy_target
        mov al, [enemy_target]
        test al, al
        jnz .chase_paddle              ; Si es 1, perseguir paleta
        
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

; Función para dibujar enemigos
print_enemies:
    push rbp
    mov rbp, rsp
    
    xor r12, r12                    ; Índice del enemigo
    
    .print_loop:
        cmp r12, 5                      ; Máximo 5 enemigos
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
    mov byte [rsi + 2], 0
    
    ; Sumar puntos
    mov rax, [enemy_points]
    add [current_score], rax
    
    ret

_start:
	call canonical_off
	call start_screen
    call init_level
    call init_enemies
	jmp .main_loop
	

	.main_loop:
        call print_labels
		call print_pallet
        call move_ball
        call print_blocks
        call check_level_complete
        call move_enemies
        call check_enemy_collision
        call print_enemies
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

