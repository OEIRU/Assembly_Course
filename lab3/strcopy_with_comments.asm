.386                    
.MODEL FLAT, C         
OPTION CASEMAP: NONE    

EXTERN lstrlenA@4:NEAR

; Экспортируемая функция — будет видна извне
PUBLIC strcopy

.DATA
; Глобальная переменная, флаг: найдена ли хотя бы одна буква в подстроке
letterFound DB 0        ; 1 байт, изначально 0 (false)

.CODE

; Сигнатура функции на C:
; int __cdecl strcopy(const char* source, char* dest, int nbeg, int nlen)
;
; Соглашение о вызовах cdecl:
; - Аргументы передаются через стек справа налево
; - Вызывающий код очищает стек
; - Возвращаемое значение — в EAX
strcopy PROC C
    ; === Сохранение контекста вызывающей функции ===
    ; Сохраняем базовый указатель стека текущей функции
    push ebp
    mov ebp, esp        ; Теперь EBP указывает на начало текущего фрейма стека

    ; Сохраняем регистры, которые должны быть сохранены вызываемой функцией
    push esi
    push edi
    push ecx            
    push ebx

    ; === Загрузка аргументов из стека ===
    ; В cdecl аргументы лежат в стеке по смещениям относительно EBP:
    ; [ebp+0]  — сохранённый EBP
    ; [ebp+4]  — возвратный адрес
    ; [ebp+8]  — source      (const char*)
    ; [ebp+12] — dest        (char*)
    ; [ebp+16] — nbeg        (int, 1-based начальная позиция)
    ; [ebp+20] — nlen        (int, длина подстроки)
    mov esi, [ebp+8]    ; ESI = указатель на исходную строку (source)
    mov edi, [ebp+12]   ; EDI = указатель на буфер назначения (dest)
    mov eax, [ebp+16]   ; EAX = nbeg (начальная позиция, 1-based!)
    mov ecx, [ebp+20]   ; ECX = nlen (длина подстроки)

    ; === Проверка корректности входных параметров ===
    ; nbeg должен быть >= 1
    cmp eax, 1
    jl error            ; Если nbeg < 1 → ошибка

    ; nlen должен быть >= 1
    cmp ecx, 1
    jl error            ; Если nlen < 1 → ошибка

    ; Проверка: не выходит ли (nbeg + nlen - 1) за пределы длины строки?
    ; Расчёт: конечная позиция = nbeg + nlen - 1 (т.к. nbeg 1-based)
    mov ebx, [ebp+16]   ; ebx = nbeg
    add ebx, [ebp+20]   ; ebx = nbeg + nlen
    dec ebx             ; ebx = nbeg + nlen - 1 → индекс последнего копируемого символа (0-based)

    ; Вызов lstrlenA для получения длины исходной строки (в eax)
    push esi            ; Передаём source как аргумент (stdcall)
    call lstrlenA@4
    add esp, 4          ; Очистка стека после вызова

    ; Сравниваем: если (nbeg + nlen - 1) > длина строки → выход за границы
    cmp ebx, eax        ; ebx = индекс последнего символа, eax = длина строки
    ja error            ; Если индекс >= длина → ошибка

    ; === Копирование подстроки из source в dest ===
    mov esi, [ebp+8]        ; Восстанавливаем source
    add esi, [ebp+16]       ; esi += nbeg → указывает на nbeg-й символ
    dec esi                 ; esi-- → теперь указывает на (nbeg-1)-й символ

    mov edi, [ebp+12]       ; edi = dest
    mov ecx, [ebp+20]       ; ecx = nlen
    cld                     ; Устанавливаем направление копирования вперёд (ESI++, EDI++)
    rep movsb               ; Копируем nlen байт из [ESI] в [EDI]
    mov byte ptr [edi], 0   ; edi указывает сразу после скопированных данных

    ; === Приведение всех заглавных букв к строчным и проверка наличия букв ===
    mov edi, [ebp+12]       ; edi = начало dest (скопированная подстрока)
    mov ecx, [ebp+20]       ; ecx = длина подстроки
    mov byte ptr letterFound, 0  ; Сбрасываем флаг: пока буквы не найдены

check_loop:
    ; Загружаем текущий символ
    mov al, [edi]
    cmp al, 0               ; Если символ == '\0' — выходим
    je check_done

    ; === Проверка и преобразование английских заглавных букв (A-Z) ===
    cmp al, 'A'
    jl check_eng_lower      ; Если < 'A' — не заглавная английская
    cmp al, 'Z'
    jg check_eng_lower      ; Если > 'Z' — не заглавная английская
    ; Если попали сюда — это A-Z
    add al, 32              ; Преобразуем в строчную: 'A' (65) → 'a' (97)
    mov [edi], al           ; Сохраняем обратно в строку
    mov byte ptr letterFound, 1  ; Фиксация буквы
    jmp next_ch

check_eng_lower:
    ; === Проверка английских строчных букв (a-z) ===
    cmp al, 'a'
    jl check_rus_upper      ; Если < 'a' — не строчная английская
    cmp al, 'z'
    jg check_rus_upper      ; Если > 'z' — не строчная английская
    ; Это a-z → уже строчная, но всё равно буква
    mov byte ptr letterFound, 1
    jmp next_ch

check_rus_upper:
    ; === Проверка русских заглавных букв А-П (коды 128–143) ===
    cmp al, 128
    jl check_rus2           ; Если < 128 — не в диапазоне А-П
    cmp al, 143
    jg check_rus2           ; Если > 143 — не А-П
    ; Это А-П → преобразуем в строчные: +32 (128→160, 143→175)
    add al, 32
    mov [edi], al
    mov byte ptr letterFound, 1
    jmp next_ch

check_rus2:
    ; === Проверка русских заглавных букв Р-Я (144–159) ===
    cmp al, 144
    jl check_rus_lower      ; Если < 144 — не Р-Я
    cmp al, 159
    jg check_rus_lower      ; Если > 159 — не Р-Я
    ; Это Р-Я → преобразуем в строчные: +80 (144+80=224)
    add al, 80
    mov [edi], al
    mov byte ptr letterFound, 1
    jmp next_ch

check_rus_lower:
    ; === Проверка русских строчных букв ===
    ; а-п: 160–175
    cmp al, 160
    jl next_ch              ; Если < 160 — не буква
    cmp al, 175
    jle found_letter        ; Если ≤175 → это а-п → буква найдена

    ; р-я: 224–239
    cmp al, 224
    jl next_ch              ; Если между 176–223 — не буква
    cmp al, 239
    jg next_ch              ; Если >239 — не буква

    ; Если дошли сюда — это р-я (224–239)
found_letter:
    mov byte ptr letterFound, 1
    jmp next_ch

next_ch:
    inc edi                 ; Переход к следующему символу в dest
    loop check_loop         ; Уменьшает ECX и продолжает, пока ECX ≠ 0

check_done:
    ; === Проверка: была ли найдена хоть одна буква? ===
    mov al, letterFound
    test al, al             ; То же, что cmp al, 0
    jz error                ; Если letterFound == 0 → ошибка

    ; Успешное завершение
    mov eax, 0              ; Возвращаем 0 → успех
    jmp finish

error:
    mov eax, 1              ; Возвращаем 1 → ошибка

finish:
    ; === Восстановление сохранённых регистров в обратном порядке ===
    pop ebx
    pop ecx
    pop edi
    pop esi
    pop ebp
    ret                     ; Возврат в вызывающую функцию

strcopy ENDP

END