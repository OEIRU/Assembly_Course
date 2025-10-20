.386                             ; Используем 32-битный режим процессора Intel 80386
.MODEL FLAT, STDCALL             ; Плоская модель памяти; соглашение о вызовах STDCALL (как в Windows API)
OPTION CASEMAP: NONE             ; Имена чувствительны к регистру (msg ≠ MSG)

; Объявление внешних функций Windows API (NEAR — вызов в пределах одного сегмента)
EXTRN GetStdHandle@4:NEAR        ; Получение дескриптора стандартного устройства (4 байта аргумента)
EXTRN WriteConsoleA@20:NEAR      ; Вывод строки в консоль (20 байт аргументов)
EXTRN CharToOemA@8:NEAR          ; Преобразование ANSI → OEM (для корректного отображения в консоли)
EXTRN ReadConsoleA@20:NEAR       ; Чтение строки из консоли
EXTRN ExitProcess@4:NEAR         ; Завершение процесса
EXTRN lstrlenA@4:NEAR            ; Вычисление длины ASCIIZ-строки

; Стандартные константы Windows для дескрипторов
STD_INPUT_HANDLE  EQU -10        ; Идентификатор стандартного ввода (stdin)
STD_OUTPUT_HANDLE EQU -11        ; Идентификатор стандартного вывода (stdout)

.DATA                            ; Секция инициализированных данных

    ; Дескрипторы устройств
    hStdIn      DD 0             ; Дескриптор стандартного ввода
    hStdOut     DD 0             ; Дескриптор стандартного вывода
    bytesRead   DD 0             ; Количество прочитанных байт
    bytesWritten DD 0            ; Количество записанных байт

    ; Сообщения для пользователя
    msgSource    DB "Введите исходную строку: ", 0        ; Приглашение к вводу строки
    msgStartPos  DB "Введите начальную позицию: ", 0      ; Приглашение к вводу позиции
    msgLength    DB "Введите длину подстроки: ", 0        ; Приглашение к вводу длины
    msgResult    DB "Результат: ", 0                      ; Подпись результата
    msgError     DB "Ошибка: некорректные параметры!", 0  ; Сообщение об ошибке
    newline      DB 13, 10, 0                             ; Символы перевода строки (CRLF)

    ; Буферы для хранения данных
    sourceString DB 255 DUP(0)   ; Буфер для исходной строки (макс. 254 символа + 0)
    startPosStr  DB 10 DUP(0)    ; Буфер для строки с начальной позицией
    lengthStr    DB 10 DUP(0)    ; Буфер для строки с длиной подстроки
    resultBuffer DB 255 DUP(0)   ; Буфер для результата (извлечённая подстрока)
    tempBuffer   DB 255 DUP(0)   ; Резервный буфер (не используется в текущей версии)

    ; Числовые параметры
    startPos     DD 0            ; Начальная позиция (нумерация с 1!)
    subLength    DD 0            ; Длина подстроки
    letterFound  DB 0            ; Флаг: найдена хотя бы одна буква (0 — нет, 1 — да)

.CODE                            ; Секция исполняемого кода

start:                           ; Точка входа в программу

    ; --- Получение дескрипторов стандартного ввода и вывода ---
    PUSH STD_INPUT_HANDLE        ; Передаём константу -10 (stdin)
    CALL GetStdHandle@4          ; Вызываем API-функцию
    MOV hStdIn, EAX              ; Сохраняем дескриптор ввода

    PUSH STD_OUTPUT_HANDLE       ; Передаём константу -11 (stdout)
    CALL GetStdHandle@4          ; Получаем дескриптор вывода
    MOV hStdOut, EAX             ; Сохраняем его

    ; --- Преобразование сообщений в OEM-кодировку (для корректного отображения в консоли) ---
    PUSH OFFSET msgSource        ; Адрес строки как dst
    PUSH OFFSET msgSource        ; Адрес строки как src
    CALL CharToOemA@8            ; Преобразуем in-place

    PUSH OFFSET msgStartPos
    PUSH OFFSET msgStartPos
    CALL CharToOemA@8

    PUSH OFFSET msgLength
    PUSH OFFSET msgLength
    CALL CharToOemA@8

    PUSH OFFSET msgResult
    PUSH OFFSET msgResult
    CALL CharToOemA@8

    PUSH OFFSET msgError
    PUSH OFFSET msgError
    CALL CharToOemA@8

    ; --- Ввод исходной строки ---
    PUSH OFFSET msgSource        ; Выводим приглашение
    CALL PrintMessage            ; Используем собственную процедуру вывода
    PUSH OFFSET sourceString     ; Передаём адрес буфера
    CALL ReadInput               ; Читаем строку (автоматически удаляет CRLF)

    ; --- Ввод начальной позиции ---
    PUSH OFFSET msgStartPos
    CALL PrintMessage
    PUSH OFFSET startPosStr
    CALL ReadInput               ; Читаем как строку
    PUSH OFFSET startPosStr
    CALL atoi                    ; Преобразуем строку в целое число
    MOV startPos, EAX            ; Сохраняем результат

    ; --- Ввод длины подстроки ---
    PUSH OFFSET msgLength
    CALL PrintMessage
    PUSH OFFSET lengthStr
    CALL ReadInput
    PUSH OFFSET lengthStr
    CALL atoi
    MOV subLength, EAX           ; Сохраняем длину

    ; --- Проверка корректности параметров ---
    CALL ValidateParameters      ; Вызываем процедуру валидации
    CMP EAX, 0                   ; Если вернулось 0 — ошибка
    JE ErrorExit                 ; Переход к выводу ошибки

    ; --- Извлечение подстроки из исходной строки ---
    CALL ExtractSubstring        ; Копирует нужный фрагмент в resultBuffer

    ; --- Проверка наличия букв и преобразование в нижний регистр ---
    CALL CheckAndConvert         ; Проходит по resultBuffer, ищет буквы, делает строчные
    CMP letterFound, 0           ; Если ни одной буквы не найдено
    JE ErrorExit                 ; — ошибка

    ; --- Вывод результата ---
    PUSH OFFSET msgResult
    CALL PrintMessage            ; Выводим "Результат: "

    PUSH OFFSET resultBuffer
    CALL PrintMessage            ; Выводим саму подстроку

    PUSH OFFSET newline
    CALL PrintMessage            ; Добавляем перевод строки

    JMP ExitProgram              ; Переход к завершению

; --- Обработка ошибки ---
ErrorExit:
    PUSH OFFSET msgError         ; Выводим сообщение об ошибке
    CALL PrintMessage
    PUSH OFFSET newline
    CALL PrintMessage

; --- Завершение программы ---
ExitProgram:
    PUSH 0                       ; Код завершения: 0 = успех
    CALL ExitProcess@4           ; Завершаем процесс

; ==============================================================================
; Процедура: ValidateParameters
; Назначение: проверяет корректность startPos и subLength
; Возвращает: EAX = 1 — OK, EAX = 0 — ошибка
; ==============================================================================
ValidateParameters PROC
    ; Проверка: startPos >= 1 (нумерация с 1!)
    MOV EAX, startPos
    CMP EAX, 1
    JL InvalidParams             ; Если startPos < 1 — ошибка

    ; Проверка: subLength > 0
    MOV EAX, subLength
    CMP EAX, 0
    JLE InvalidParams            ; Если длина ≤ 0 — ошибка

    ; Получаем длину исходной строки
    PUSH OFFSET sourceString
    CALL lstrlenA@4              ; Длина возвращается в EAX
    MOV ECX, EAX                 ; Сохраняем длину в ECX

    ; Проверка: startPos не больше длины строки
    MOV EAX, startPos
    CMP EAX, ECX
    JG InvalidParams             ; Если startPos > длина — ошибка

    ; Проверка: подстрока не выходит за границы строки
    MOV EAX, startPos
    DEC EAX                      ; Переводим в индекс с 0 (startPos-1)
    ADD EAX, subLength           ; Конечная позиция (исключительно)
    CMP EAX, ECX                 ; Сравниваем с длиной строки
    JG InvalidParams             ; Если выходит за границу — ошибка

    MOV EAX, 1                   ; Всё корректно
    RET

InvalidParams:
    MOV EAX, 0                   ; Ошибка
    RET
ValidateParameters ENDP

; ==============================================================================
; Процедура: ExtractSubstring
; Назначение: копирует подстроку из sourceString в resultBuffer
; Использует: startPos (с 1), subLength
; ==============================================================================
ExtractSubstring PROC
    MOV ESI, OFFSET sourceString ; ESI = начало исходной строки
    MOV EAX, startPos
    DEC EAX                      ; Переводим позицию в индекс с 0
    ADD ESI, EAX                 ; ESI указывает на начало подстроки
    MOV EDI, OFFSET resultBuffer ; EDI = начало буфера результата
    MOV ECX, subLength           ; ECX = количество байт для копирования
    CLD                          ; Устанавливаем направление копирования вперёд
    REP MOVSB                    ; Копируем ECX байт из [ESI] в [EDI]
    MOV BYTE PTR [EDI], 0        ; Завершаем строку нулём (ASCIIZ)
    RET
ExtractSubstring ENDP

; ==============================================================================
; Процедура: CheckAndConvert
; Назначение:
;   - Проверяет, есть ли в resultBuffer хотя бы одна буква (англ. или рус.)
;   - Преобразует все заглавные буквы в строчные
;   - Устанавливает флаг letterFound = 1, если найдена хотя бы одна буква
; Примечание: используется OEM-кодировка CP866 (стандартная для консоли Windows)
; ==============================================================================
CheckAndConvert PROC
    MOV EDI, OFFSET resultBuffer ; EDI = указатель на начало результата
    MOV ECX, subLength           ; ECX = длина подстроки
    MOV letterFound, 0           ; Сбрасываем флаг

ProcessLoop:
    MOV AL, [EDI]                ; Загружаем текущий символ

    ; --- Проверка английских заглавных букв A-Z (коды 65–90) ---
    CMP AL, 'A'
    JB CheckEnglishLower         ; Меньше 'A' — не заглавная англ. буква
    CMP AL, 'Z'
    JA CheckEnglishLower         ; Больше 'Z' — тоже нет
    ; Это заглавная английская буква
    MOV letterFound, 1           ; Устанавливаем флаг
    ADD AL, 32                   ; Преобразуем в строчную ('A' + 32 = 'a')
    MOV [EDI], AL                ; Сохраняем обратно
    JMP NextChar

CheckEnglishLower:
    ; --- Проверка английских строчных букв a-z (97–122) ---
    CMP AL, 'a'
    JB CheckRussian              ; Меньше 'a' — не строчная англ. буква
    CMP AL, 'z'
    JA CheckRussian              ; Больше 'z' — тоже нет
    ; Это строчная английская буква
    MOV letterFound, 1           ; Устанавливаем флаг
    JMP NextChar

CheckRussian:
    ; --- Проверка русских заглавных букв А-Я в CP866 ---
    ; Диапазон: 0x80–0x9F (128–159)
    CMP AL, 80h
    JB NextChar                  ; Меньше 0x80 — не русская заглавная
    CMP AL, 9Fh
    JA CheckRussianLower         ; Больше 0x9F — не в этом диапазоне
    ; Это заглавная русская буква
    MOV letterFound, 1
    ; Преобразуем в строчную:
    ;   А-П (0x80–0x8F) → а-п (0xA0–0xAF) → +0x20
    ;   Р-Я (0x90–0x9F) → р-я (0xE0–0xEF) → +0x50
    CMP AL, 90h                  ; Разделяем на две группы по коду 0x90 ('Р')
    JB FirstGroup                ; Если < 0x90 — первая группа
    ; Вторая группа: Р-Я
    ADD AL, 50h                  ; 0x90 + 0x50 = 0xE0 ('р')
    JMP StoreRussian
FirstGroup:
    ; Первая группа: А-П
    ADD AL, 20h                  ; 0x80 + 0x20 = 0xA0 ('а')
StoreRussian:
    MOV [EDI], AL                ; Сохраняем строчную букву
    JMP NextChar

CheckRussianLower:
    ; --- Проверка русских строчных букв а-я в CP866 ---
    ; Диапазоны: 0xA0–0xBF (а-п) и 0xE0–0xEF (р-я)
    CMP AL, 0A0h
    JB NextChar                  ; Меньше 0xA0 — не строчная русская
    CMP AL, 0BFh
    JA CheckRussianLower2        ; Больше 0xBF — проверяем второй диапазон
    ; Это строчная русская буква (а-п)
    MOV letterFound, 1
    JMP NextChar

CheckRussianLower2:
    CMP AL, 0E0h
    JB NextChar                  ; Меньше 0xE0 — не в диапазоне
    CMP AL, 0EFh
    JA NextChar                  ; Больше 0xEF — не русская
    ; Это строчная русская буква (р-я)
    MOV letterFound, 1

NextChar:
    INC EDI                      ; Переход к следующему символу
    LOOP ProcessLoop             ; Повторяем subLength раз
    RET
CheckAndConvert ENDP

; ==============================================================================
; Процедура: PrintMessage
; Назначение: выводит ASCIIZ-строку в консоль
; Аргумент: [ESP+4] = адрес строки
; ==============================================================================
PrintMessage PROC
    PUSH EBP                     ; Сохраняем базовый указатель
    MOV EBP, ESP                 ; Устанавливаем фрейм стека
    PUSH DWORD PTR [EBP+8]       ; Передаём адрес строки в lstrlenA
    CALL lstrlenA@4              ; Получаем длину строки (в EAX)
    PUSH 0                       ; lpReserved = NULL
    PUSH OFFSET bytesWritten     ; Адрес переменной для записи количества выведенных байт
    PUSH EAX                     ; Длина строки
    PUSH DWORD PTR [EBP+8]       ; Адрес строки
    PUSH hStdOut                 ; Дескриптор вывода
    CALL WriteConsoleA@20        ; Выводим строку
    POP EBP                      ; Восстанавливаем EBP
    RET 4                        ; Очищаем 4 байта (адрес строки) со стека
PrintMessage ENDP

; ==============================================================================
; Процедура: ReadInput
; Назначение: читает строку из консоли и удаляет CRLF в конце
; Аргумент: [ESP+4] = адрес буфера
; ==============================================================================
ReadInput PROC
    PUSH EBP
    MOV EBP, ESP
    PUSH 0                       ; lpReserved = NULL
    PUSH OFFSET bytesRead        ; Адрес счётчика прочитанных байт
    PUSH 254                     ; Макс. количество символов (оставляем место под 0)
    PUSH DWORD PTR [EBP+8]       ; Адрес буфера
    PUSH hStdIn                  ; Дескриптор ввода
    CALL ReadConsoleA@20         ; Читаем строку (включая CRLF)

    ; --- Удаление CRLF (\r\n) из конца строки ---
    MOV EDI, DWORD PTR [EBP+8]   ; EDI = адрес буфера
    MOV ECX, bytesRead           ; ECX = количество прочитанных байт
    CMP ECX, 2                   ; Было ли прочитано хотя бы 2 символа?
    JL Done                      ; Если нет — не трогаем
    SUB ECX, 2                   ; Игнорируем последние 2 символа (CRLF)
    MOV BYTE PTR [EDI+ECX], 0    ; Ставим нуль-терминатор на новом конце
Done:
    POP EBP
    RET 4                        ; Очищаем аргумент со стека
ReadInput ENDP

; ==============================================================================
; Процедура: atoi
; Назначение: преобразует ASCIIZ-строку с десятичным числом в целое (EAX)
; Аргумент: [ESP+4] = адрес строки
; Поддерживает только неотрицательные целые числа
; ==============================================================================
atoi PROC
    PUSH EBP
    MOV EBP, ESP
    PUSH EBX                     ; Сохраняем EBX
    PUSH ESI                     ; Сохраняем ESI
    MOV ESI, DWORD PTR [EBP+8]   ; ESI = указатель на строку
    XOR EAX, EAX                 ; EAX = 0 (результат)
    XOR EBX, EBX                 ; EBX = 0 (временное хранение цифры)

ConvertLoop:
    MOV BL, [ESI]                ; Загружаем символ
    CMP BL, 0                    ; Конец строки?
    JE Done                      ; Да — завершаем
    CMP BL, '0'                  ; Меньше '0'?
    JB Done                      ; Недопустимый символ — завершаем
    CMP BL, '9'                  ; Больше '9'?
    JA Done                      ; Недопустимый символ — завершаем
    SUB BL, '0'                  ; Преобразуем символ в цифру
    IMUL EAX, 10                 ; Умножаем накопленное число на 10
    ADD EAX, EBX                 ; Добавляем новую цифру
    INC ESI                      ; Переход к следующему символу
    JMP ConvertLoop              ; Продолжаем

Done:
    POP ESI                      ; Восстанавливаем регистры
    POP EBX
    POP EBP
    RET 4                        ; Очищаем аргумент со стека
atoi ENDP

END start                        ; Указываем точку входа — метка start
