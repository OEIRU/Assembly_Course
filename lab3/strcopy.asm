.386
.MODEL FLAT, C
OPTION CASEMAP: NONE

EXTERN lstrlenA@4:NEAR
PUBLIC strcopy

.DATA
letterFound DB 0

.CODE
; int __cdecl strcopy(const char* source, char* dest, int nbeg, int nlen)
strcopy PROC C
    push ebp
    mov ebp, esp
    push esi
    push edi
    push ecx
    push ebx

    mov esi, [ebp+8]   ; source
    mov edi, [ebp+12]  ; dest
    mov eax, [ebp+16]  ; nbeg
    mov ecx, [ebp+20]  ; nlen

    ; Проверка параметров
    cmp eax, 1
    jl error
    cmp ecx, 1
    jl error
    mov ebx, [ebp+16]  ; nbeg
    add ebx, [ebp+20]  ; nbeg + nlen
    dec ebx            ; nbeg + nlen - 1
    push esi
    call lstrlenA@4
    cmp ebx, eax       ; (nbeg + nlen - 1) > len ?
    ja error

    ; Копируем подстроку
    mov esi, [ebp+8]
    add esi, [ebp+16]
    dec esi
    mov edi, [ebp+12]
    mov ecx, [ebp+20]
    cld
    rep movsb
    mov byte ptr [edi], 0

    ; Переводим в нижний регистр и ищем буквы
    mov edi, [ebp+12]
    mov ecx, [ebp+20]
    mov byte ptr letterFound, 0
check_loop:
    mov al, [edi]
    cmp al, 0
    je check_done

    ; Английские заглавные A-Z
    cmp al, 'A'
    jl check_eng_lower
    cmp al, 'Z'
    jg check_eng_lower
    add al, 32
    mov [edi], al
    mov byte ptr letterFound, 1
    jmp next_ch

check_eng_lower:
    ; Английские строчные a-z
    cmp al, 'a'
    jl check_rus_upper
    cmp al, 'z'
    jg check_rus_upper
    mov byte ptr letterFound, 1
    jmp next_ch

check_rus_upper:
    ; Русские заглавные А-П (128-143)
    cmp al, 128
    jl check_rus2
    cmp al, 143
    jg check_rus2
    add al, 32
    mov [edi], al
    mov byte ptr letterFound, 1
    jmp next_ch

check_rus2:
    ; Русские заглавные Р-Я (144-159)
    cmp al, 144
    jl check_rus_lower
    cmp al, 159
    jg check_rus_lower
    add al, 80
    mov [edi], al
    mov byte ptr letterFound, 1
    jmp next_ch

check_rus_lower:
    ; Русские строчные а-п (160-175)
    cmp al, 160
    jl next_ch
    cmp al, 175
    jle found_letter
    ; Русские строчные р-я (224-239)
    cmp al, 224
    jl next_ch
    cmp al, 239
    jg next_ch

found_letter:
    mov byte ptr letterFound, 1
    jmp next_ch

next_ch:
    inc edi
    loop check_loop

check_done:
    mov al, letterFound
    test al, al
    jz error
    mov eax, 0
    jmp finish
error:
    mov eax, 1
finish:
    pop ebx
    pop ecx
    pop edi
    pop esi
    pop ebp
    ret
strcopy ENDP

END
