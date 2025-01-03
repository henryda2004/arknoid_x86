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
        
	pallet_position dq board + 38 + 29 * (column_cells +2)
    pallet_size dq 5
    default_pallet_size dq 5    ; Tamaño normal de la paleta
    extended_pallet_size dq 7   ; Tamaño extendido de la paleta

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

    ; Definición del nivel 1 (ejemplo con múltiples bloques)destroyed_blocks
    ; Formato: x_pos, y_pos, tipo_bloque, durabilidad_actual
    level1_blocks:
        ; Tercera fila (tipo 3)
        db 58, 7, 3, 1, 'L'    ; Bloque 7
        db 61, 9, 3, 1, 'C'    ; Bloque 7
        db 35, 9, 3, 1, 'C'    ; Bloque 7
        db 18, 7, 3, 1, 'S'    ; Bloque 7
    level1_blocks_count equ 4   ; Cantidad total de bloques

    ; Nivel 2: Bloques de prueba
    level2_blocks:
        db 60, 7, 1, 1, 'E'    ; Un bloque simple en el nivel 2   ; Un bloque simple en el nivel 2
    level2_blocks_count equ 1

    ; Nivel 3
    level3_blocks:
        db 60, 7, 2, 1, 'E'    ; Bloque 1

    level3_blocks_count equ 1

    ; Nivel 4
    level4_blocks:
        db 60, 7, 4, 1, 'E'    ; Bloque 1
    level4_blocks_count equ 1

    ; Nivel 5
    level5_blocks:
        db 60, 7, 5, 1, 'E'    ; Bloque 1
    level5_blocks_count equ 1

    ; Array para mantener el estado de los bloques
    block_states: times 100 db 0  ; Durabilidad actual de cada bloque

    
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
    enemy_move_delay db 2           ; Mover enemigos cada N ciclos
    enemy_move_total db 0      ; Contador total de movimientos
    enemy_target db 0          ; 0 = persigue bola, 1 = persigue paleta
    MOVEMENT_THRESHOLD db 20   ; Número de movimientos antes de cambiar objetivo
 ;Formato: número de bloques destruidos necesario para que aparezca cada enemigo
    ; Añade esto en la sección .dataa
    level1_spawn_points: db 0, 1, 2, 6, 8, 10, 12, 14, 16, 18    ; 10 enemigos, cada 2 bloques
    level2_spawn_points: db 1, 3, 5, 7, 9, 11, 13, 15, 17, 19    ; 10 enemigos, cada 2 bloques
    level3_spawn_points: db 0, 3, 6, 9, 12, 15, 18, 21, 24, 27   ; 10 enemigos, cada 3 bloques
    level4_spawn_points: db 1, 4, 7, 10, 13, 16, 19, 22, 25, 28  ; 10 enemigos, cada 3 bloques
    level5_spawn_points: db 0, 5, 10, 15, 20, 25, 30, 35, 40, 45 ; 10 enemigos, cada 5 bloques
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
        db 8, 30, 1     ; Vida 4 (inactiva)
        db 10, 30, 0    ; Vida 5 (inactiva)
        db 12, 30, 0    ; Vida 6 (inactiva)
        db 14, 30, 0    ; Vida 7 (inactiva)
    lives_count equ 7    ; Total de vidas
    life_char db "^"    
    current_lives db 4   ; Contador de vidas activas actual

; Estructura para almacenar las letras y sus posiciones
    ; Formato: x, y, letra, activo (1 = activo, 0 = inactivo)
    letters_map: times 100 * 4 db 0  ; Espacio para 100 letras
    letters_count db 0   
    last_letter db ' '    ; Variable para almacenar la última letra
    last_letter_msg db "Poder actual: [ ]", 0xA, 0xD  ; Mensaje para mostrar la última letra
    last_letter_msg_len equ $ - last_letter_msg
    current_power_processed db 0 ; 0 = no procesado, 1 = ya procesado
    max_lives db 7              ; Máximo número de vidas permitidas
    ball_speed dq 1             ; Velocidad normal de la bola
    slow_ball_speed dq 2        ; Velocidad lenta (se usará como divisor)
    speed_counter dq 0          ; Contador para ralentizar el movimiento

    catch_power_active db 0     ; 0 = inactivo, 1 = activo
    ball_caught db 0           ; 0 = no atrapada, 1 = atrapada
    ball_catch_offset dq 0     ; Offset respecto a la paleta cuando está atrapada
    last_key db 0    ; Variable para almacenar la última tecla presionada

    laser_power_active: db 0         ; Flag para indicar si el poder láser está activo
    laser_symbol: db '|'             ; Símbolo para representar el láser
    laser_count: db 0                ; Contador de láseres activos
    lasers: times 200 db 0           ; Array para almacenar posiciones de láseres (x,y)
    laser_speed: dq 1                ; Velocidad del láser

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
lose_life:
    push rbp
    mov rbp, rsp
    
    ; Verificar si aún quedan vidas
    cmp byte [current_lives], 0
    je .game_lost
    
    ; Encontrar la última vida activa
    mov rcx, lives_count
    dec rcx                     ; Empezar desde la última vida
    
    .find_active_life:
        mov rax, rcx
        imul rax, 3            ; Cada vida ocupa 3 bytes
        lea rsi, [lives_data + rax]
        cmp byte [rsi + 2], 1  ; Verificar si está activa
        je .deactivate_life
        dec rcx
        jns .find_active_life  ; Continuar si no hemos llegado a -1
        jmp .game_lost         ; Si no encontramos vidas activas
        
    .deactivate_life:
        ; Calcular posición correcta en el tablero para borrar la vida
        movzx r8, byte [rsi]            ; X
        movzx r9, byte [rsi + 1]        ; Y
        
        ; Calcular offset en el tablero: Y * (column_cells + 2) + X
        mov rax, column_cells
        add rax, 2                      ; Incluir caracteres de nueva línea
        mul r9
        add rax, r8
        lea rdi, [board + rax]
        
        ; Borrar visualmente la vida
        mov byte [rdi], ' '             
        
        ; Desactivar la vida en los datos
        mov byte [rsi + 2], 0          
        dec byte [current_lives]
        
        ; Borrar visualmente la paleta anterior
        mov r8, [pallet_position]
        mov rcx, [pallet_size]
        .erase_pallet_loop:
            mov byte [r8], ' '          ; Reemplazar cada posición con un espacio
            inc r8
            dec rcx
            jnz .erase_pallet_loop
        

        ; Reiniciar posición de la bola y la paleta
        mov qword [ball_x_pos], 40
        mov qword [ball_y_pos], 28
        mov byte [ball_moving], 0
        mov qword [pallet_position], board + 38 + 29 * (column_cells + 2)
        
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
    
    ; Verificar si la bola está en la última fila (row_cells - 1)
    mov rax, [ball_y_pos]
    cmp rax, row_cells - 2
    jne .no_collision
    
    ; Si hay colisión, perder una vida
    call lose_life
    
    .no_collision:
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

            ; Si no es ningún power-up, restaurar tamaño normal
            mov rax, [default_pallet_size]
            mov [pallet_size], rax
            mov qword [ball_speed], 1    ; Restaurar velocidad normal
            mov byte [catch_power_active], 0
            jmp .finish_capture

            .extend_pallet:
                mov byte [catch_power_active], 0
                mov qword [ball_speed], 1    ; Restaurar velocidad normal
                mov rax, [extended_pallet_size]
                mov [pallet_size], rax
                jmp .finish_capture

            .check_add_life:
                mov byte [catch_power_active], 0
                mov rax, [default_pallet_size]
                mov [pallet_size], rax
                mov qword [ball_speed], 1 
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
                mov byte [catch_power_active], 0                
                mov rax, [default_pallet_size]
                mov [pallet_size], rax
                mov qword [ball_speed], 2    ; Activar velocidad lenta
                jmp .finish_capture

            .activate_catch:
                mov rax, [default_pallet_size]
                mov [pallet_size], rax
                mov qword [ball_speed], 1
                mov byte [catch_power_active], 1
                jmp .finish_capture

            .activate_laser:
                mov byte [catch_power_active], 0
                mov rax, [default_pallet_size]
                mov [pallet_size], rax
                mov qword [ball_speed], 1
                mov byte [laser_power_active], 1    ; Activar el poder láser
                jmp .finish_capture

            .finish_capture:
                mov byte [rbx + 3], 0

        .next_letter:
            inc rcx
            jmp .move_loop

    .print_last_letter:
        print last_letter_msg, last_letter_msg_len - 3
        mov al, [last_letter]
        mov [last_letter_msg + 15], al
        print last_letter_msg + last_letter_msg_len - 3, 3

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

    ; Ajustamos para que RCX sea el último índice de láser
    dec rcx              ; Último índice es (laser_count - 1)

.loop_lasers:
    ; RSI apunta a lasers + (rcx * 2) => (x, y) del láser
    lea rsi, [lasers + rcx*2]

    ; 2) Cargar x,y actuales
    movzx r8,  byte [rsi]      ; x
    movzx r9,  byte [rsi + 1]  ; y

    ; 3) Borrar el láser de su posición actual en pantalla
    mov rax, column_cells
    add rax, 2
    mul r9
    add rax, r8
    lea rdi, [board + rax]
    mov byte [rdi], ' '        ; Borramos el símbolo anterior (láser)

    ; 4) Mover el láser hacia arriba (y - 1)
    dec r9

    ; Verificar si ya salió de la pantalla (o si y < 1)
    cmp r9, 1
    jl .delete_laser           ; Si y < 1 => eliminarlo

    ; 5) Si sigue en pantalla => guardar su nueva posición
    mov byte [rsi + 1], r9b

    ; 6) Dibujar láser en la nueva posición
    mov rax, column_cells
    add rax, 2
    mul r9
    add rax, r8
    lea rdi, [board + rax]
    mov al, [laser_symbol]
    mov [rdi], al

.next_laser:
    ; 7) Pasamos al láser anterior
    dec rcx
    cmp rcx, -1
    jg .loop_lasers   ; Mientras rcx >= 0, seguir iterando

    jmp .fin

.delete_laser:
    ; 8) Borrar el láser actual del array
    movzx r12, byte [laser_count]
    dec r12                    ; r12 = último índice
    cmp r12, rcx
    jbe .just_decrement        ; Si rcx ya apunta al último

    ; Si NO es el último láser => copiamos el último en la posición actual
    lea rdi, [lasers + rcx*2]
    lea rsi, [lasers + r12*2]
    mov ax, [rsi]             ; lee 2 bytes (x,y) del último
    mov [rdi], ax             ; copy

.just_decrement:
    dec byte [laser_count]     ; Decrementar el contador total
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

	
	;mov rax, board + r8 + r9 * (column_cells + 2)
	
print_pallet:
    ; Primero borrar la paleta anterior completa (usando el tamaño máximo posible)
    mov r8, [pallet_position]
    mov rcx, [extended_pallet_size]
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
            mov al, [r8+2]       ; Cargar el carácter en esa posición
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

; Nueva función para procesar la tecla C cuando la bola está atrapada
; Procesar la tecla 'c' cuando el poder de atrapar está activo
process_catch_release:
    push rbp
    mov rbp, rsp

    ; Verificar si la bola está atrapada
    cmp byte [ball_caught], 0
    je .end

    ; Verificar si el poder catch está activo
    cmp byte [catch_power_active], 1
    jne .end

    ; Verificar si se presionó la tecla 'c'
    cmp byte [last_key], 'c'
    jne .end

    ; Liberar la bola y asignar dirección inicial
    mov byte [ball_caught], 0
    mov qword [ball_direction_x], 1
    mov qword [ball_direction_y], -1

    ; Limpiar la tecla procesada
    mov byte [last_key], 0

    .end:
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


init_level:

    mov rax, [default_pallet_size]
    mov [pallet_size], rax
    mov qword [ball_speed], 1    ; Restaurar velocidad normal

    ; 1) Copiamos board_template en board para que quede "virgen"
        ; Reiniciar letras activas
    lea rdi, [letters_map]
    mov rcx, 100 * 4             ; Cada letra ocupa 4 bytes, limpiar 100 letras
    xor rax, rax
    rep stosb                    ; Llenar con ceros
    
    ; Inicializar dirección de la bola (derecha y arriba)
    mov qword [ball_direction_x], 1    ; Dirección hacia la derecha (1 = derecha, -1 = izquierda)
    mov qword [ball_direction_y], -1   ; Dirección hacia arriba (-1 = arriba, 1 = abajo)


    ; Reiniciar contador de letras activas
    xor rax, rax
    mov [letters_count], al

    ; Reiniciar última letra capturada
    mov byte [last_letter], ' '
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

    mov rcx, 10
    xor rax, rax
    lea rdi, [enemy_spawns_triggered]
    rep stosb      

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
        mov byte [blocks_remaining], level3_blocks_count
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
    
    ; Verificar si hemos completado todos los niveles (asumiendo 2 niveles por ahora)
    cmp byte [current_level], 6
    je game_win
    
    ; Reinicializar el juego para el siguiente nivel
    call init_level
    
    ; Reinicializar la posición de la bola y la paleta
    mov qword [ball_x_pos], 40
    mov qword [ball_y_pos], 28
    mov byte [ball_moving], 0
    mov qword [pallet_position], board + 38 + 29 * (column_cells + 2)
    
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
    mov byte [enemy_target], 0 ; Inicialmente persigue la bola
    ; Limpiar estado previo de enemigos
    mov rcx, 10 ; Máximo 10 enemigos
    lea rdi, [enemies]
    xor al, al
    rep stosb ; Limpiar datos de enemigos
    
    ; Marcar todos los enemigos como inactivos
    lea rdi, [enemy_spawns_triggered]
    xor al, al
    mov rcx, 10
    rep stosb ; Todos los enemigos no han sido activados aún

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
        
        ; Limpiar posición actual antes de mover
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
        mov byte [rsi], 40             ; X inicial
        mov byte [rsi + 1], 2          ; Y inicial
        mov byte [rsi + 2], 1          ; Activar enemigo
        
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
    call init_enemies
	jmp .main_loop
	

	.main_loop:
        call print_labels
        call print_blocks
        call move_letters
        call update_lasers
        call print_letters
		call print_pallet
        call move_ball
        call check_bottom_collision
        call print_lives
        call check_level_complete
        call check_enemy_spawn
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

