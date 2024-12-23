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
	pallet_position dq board + 40 + 29 * (column_cells +2)
	pallet_size dq 3

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
    block_type_1: db "UUUU"    ; Durabilidad 1
    block_type_2: db "OOOO"    ; Durabilidad 2
    block_type_3: db "DDDD"    ; Durabilidad 3
    block_type_4: db "LLLL"    ; Durabilidad 4
    block_type_5: db "VVVV"    ; Durabilidad 5
    block_type_6: db "8888"    ; Durabilidad 6
    block_length: equ 4        ; Longitud de cada bloque

    ; Estructura para el nivel actual
    current_level db 1
    blocks_remaining db 0

    ; Definición del nivel 1 (ejemplo con múltiples bloques)
    ; Formato: x_pos, y_pos, tipo_bloque, durabilidad_actual
    level1_blocks:
        ; Primera fila (tipo 1)
        db 60, 3, 1, 1    ; Bloque 1s
        db 65, 3, 1, 1    ; Bloque 2
        db 70, 3, 1, 1    ; Bloque 3
        
        ; Segunda fila (tipo 2)
        db 60, 5, 2, 1    ; Bloque 4
        db 65, 5, 2, 1    ; Bloque 5
        db 70, 5, 2, 1    ; Bloque 6
        
        ; Tercera fila (tipo 3)
        db 60, 7, 3, 2    ; Bloque 7
        db 65, 7, 3, 2    ; Bloque 8
        db 70, 7, 3, 2    ; Bloque 9
    level1_blocks_count equ 9   ; Cantidad total de bloques

    ; Array para mantener el estado de los bloques
    block_states: times 100 db 0  ; Durabilidad actual de cada bloque

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
init_level:
    ; 1) Copiamos board_template en board para que quede "virgen"
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

    ; 2) blocks_remaining = 9
    mov byte [blocks_remaining], level1_blocks_count

    ; 3) Rellenar block_states con la durabilidad inicial
    xor rcx, rcx             ; Contador para el loop
    .init_loop:
        cmp rcx, level1_blocks_count
        jge .done

        ; Calcular el offset correcto para level1_blocks
        mov rax, rcx         ; Preservar el contador
        shl rax, 2          ; Multiplicar por 4 (cada bloque tiene 4 bytes)
        
        ; Obtener la durabilidad del bloque desde level1_blocks
        mov dl, byte [level1_blocks + rax + 3]  ; Obtener durabilidad
        
        ; Guardar la durabilidad en block_states
        mov byte [block_states + rcx], dl

        inc rcx
        jmp .init_loop

    .done:
        ret




; Función para imprimir los bloques
; Función modificada para imprimir bloques
print_blocks:
    xor r12, r12               ; Índice del bloque actual
    
    .print_loop:
        cmp r12, level1_blocks_count
        jge .end
        
        ; Verificar si el bloque está activo
        movzx rax, byte [block_states + r12]
        test rax, rax
        jz .next_block             ; Si durabilidad es 0, bloque destruido
        
        ; Obtener posición y tipo del bloque
        mov r8b, [level1_blocks + r12 * 4]     ; X position
        mov r9b, [level1_blocks + r12 * 4 + 1] ; Y position
        mov r10b, [level1_blocks + r12 * 4 + 2]; Tipo de bloque
        
        ; Calcular posición en el tablero
        movzx r8, r8b
        movzx r9, r9b
        add r8, board
        mov rax, column_cells + 2
        mul r9
        add r8, rax
        
        ; Imprimir el bloque según su tipo
        mov rcx, block_length      ; Longitud del bloque (4 caracteres)
        mov rsi, block_type_1      ; Dirección base de los tipos de bloques
        movzx rax, r10b
        dec rax                    ; Ajustar índice (tipos empiezan en 1)
        imul rax, block_length     ; Calcular offset al tipo correcto
        add rsi, rax               ; rsi apunta al tipo de bloque correcto
        
    .print_block_chars:
        mov al, [rsi]             ; Obtener carácter del bloque
        mov [r8], al              ; Colocarlo en el tablero
        inc rsi
        inc r8
        dec rcx
        jnz .print_block_chars
        
    .next_block:
        inc r12
        jmp .print_loop
        
    .end:
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
check_block_collision:
    push rbp
    mov rbp, rsp

    mov al, [r10] ; leer caracter de board[r10]

    ; Checar si es 'U','O','D','L','V','8'
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

    ; Si no coincide
    xor rax, rax
    pop rbp
    ret

    .possible:
        ; Buscar cuál de los blocks del level1_blocks coincide
        push rbx
        push rdi
        push rsi
        push r12

        xor r12, r12
    .find_block_loop:
        cmp r12, level1_blocks_count
        jge .no_block_found

        ; Ver si el block_states[r12] > 0
        mov bl, [block_states + r12]
        test bl, bl
        jz .next_block ; si 0 => bloque destruido

        ; leer x,y
        mov rax, level1_blocks
        imul r12, 4
        add rax, r12
        mov dl, [rax]       ; x
        mov cl, [rax+1]     ; y

        ; revertir r12
        mov r12, r12
        shr r12, 2

        ; base_dir = board + y*(col+2) + x
        lea rdi, [board]
        xor rax, rax
        mov rax, column_cells + 2
        movzx rcx, cl
        imul rax, rcx
        add rdi, rax
        movzx rax, dl
        add rdi, rax

        ; checar si r10 esta en [rdi..rdi+3]
        cmp r10, rdi
        jb .next_block
        lea rbx, [rdi + 4]
        cmp r10, rbx
        jae .next_block

        ; Si llegamos aqui => colisión con el bloque r12
        ; 1) Decrementar su durabilidad
        dec byte [block_states + r12]

        ; 2) Leer valor actualizado
        mov bl, [block_states + r12]
        test bl, bl
        jnz .still_alive   ; si no es 0, no se borra todavía

        ; si llegó a 0 => borrar (poner 4 espacios)
        mov rcx, 4
    .erase_block_chars:
        mov byte [rdi], char_space
        inc rdi
        loop .erase_block_chars

        ; blocks_remaining--
        dec byte [blocks_remaining]

    .still_alive:
        ; Retornar 1 => colisión
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



_start:
	call canonical_off
	call start_screen
    call init_level
	jmp .main_loop
	

	.main_loop:
		call print_pallet
        call move_ball
        call print_blocks
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

