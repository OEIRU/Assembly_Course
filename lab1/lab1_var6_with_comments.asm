.386                             ; Используем архитектуру Intel 80386
.MODEL FLAT, STDCALL             ; Плоская модель памяти; соглашение о вызовах STDCALL
OPTION CASEMAP: NONE             ; Чувствительность к регистру символов (имена меток и процедур как есть)

; Объявляем внешние функции Windows API (с суффиксами @N — размер аргументов в байтах)
EXTERN WriteConsoleA@20: PROC    ; Вывод текста в консоль (20 байт аргументов)
EXTERN CharToOemA@8: PROC        ; Преобразование ANSI ? OEM (для корректного отображения в консоли)
EXTERN GetStdHandle@4: PROC      ; Получение дескриптора стандартного устройства (ввод/вывод)
EXTERN lstrlenA@4: PROC          ; Длина строки ASCIIZ
EXTERN ExitProcess@4: PROC       ; Завершение процесса
EXTERN ReadConsoleA@20: PROC     ; Чтение строки из консоли

.DATA                            ; Секция инициализированных данных
    msg_input           DB "Введите число в двоичной системе: ", 0   ; Приглашение к вводу
    msg_decimal         DB "В десятичной системе: ", 0               ; Подпись для вывода числа в десятичной системе
    msg_result_bin      DB "Результат в двоичной системе: ", 0       ; Подпись для результата в двоичной системе
    msg_result_dec      DB "Результат в десятичной системе: ", 0     ; Подпись для результата в десятичной системе
    msg_poly            DB "Вычисление полинома: -1*x^2 + 8*x + 10", 13, 10, 0  ; Описание полинома + CRLF
    ERROR_STR           DB "Ошибка: введено недвоичное число или неверная длина", 0  ; Сообщение об ошибке
    OVERFLOW_STR        DB "Переполнение при вычислении", 0          ; Сообщение о переполнении
    newline             DB 13, 10, 0                                 ; Символы перевода строки (CRLF)

    DOUT                DD ?        ; Дескриптор стандартного вывода (stdout)
    DIN                 DD ?        ; Дескриптор стандартного ввода (stdin)
    bytes_read          DD ?        ; Количество прочитанных байт
    bytes_written       DD ?        ; Количество записанных байт
    x                   DD ?        ; Хранит введённое число (в десятичной форме)
    result              DD ?        ; Результат вычисления полинома
    BUF                 DB 100 DUP (?)   ; Буфер для ввода строки (до 100 символов)
    output_buf          DB 100 DUP (?)   ; Буфер для формирования строкового результата
    sign_flag           DB 0        ; Флаг: 1 — число отрицательное, 0 — положительное

.CODE                            ; Секция кода
MAIN PROC                        ; Точка входа в программу

    ; --- Преобразование строк в OEM-кодировку (для корректного отображения в консоли Windows) ---
    MOV EAX, OFFSET msg_input    ; Загружаем адрес строки msg_input в EAX
    PUSH EAX                     ; Повторно передаём тот же адрес как второй аргумент (dst = src)
    PUSH EAX                     ; Передаём адрес строки как первый аргумент (src)
    CALL CharToOemA@8            ; Вызываем CharToOemA(src, dst)

    MOV EAX, OFFSET msg_decimal  ; Аналогично для msg_decimal
    PUSH EAX
    PUSH EAX
    CALL CharToOemA@8

    MOV EAX, OFFSET msg_result_bin
    PUSH EAX
    PUSH EAX
    CALL CharToOemA@8

    MOV EAX, OFFSET msg_result_dec
    PUSH EAX
    PUSH EAX
    CALL CharToOemA@8

    MOV EAX, OFFSET msg_poly
    PUSH EAX
    PUSH EAX
    CALL CharToOemA@8

    MOV EAX, OFFSET ERROR_STR
    PUSH EAX
    PUSH EAX
    CALL CharToOemA@8

    MOV EAX, OFFSET OVERFLOW_STR
    PUSH EAX
    PUSH EAX
    CALL CharToOemA@8

    ; --- Получение дескрипторов стандартного ввода и вывода ---
    PUSH -11                     ; STD_OUTPUT_HANDLE (-11) — стандартный вывод
    CALL GetStdHandle@4          ; Получаем дескриптор stdout
    MOV DOUT, EAX                ; Сохраняем его в переменную DOUT

    PUSH -10                     ; STD_INPUT_HANDLE (-10) — стандартный ввод
    CALL GetStdHandle@4          ; Получаем дескриптор stdin
    MOV DIN, EAX                 ; Сохраняем его в переменную DIN

    ; --- Вывод сообщения о полиноме ---
    PUSH OFFSET msg_poly         ; Адрес строки
    CALL lstrlenA@4              ; Получаем длину строки (возвращается в EAX)
    PUSH 0                       ; lpReserved = NULL
    PUSH OFFSET bytes_written    ; Адрес переменной для записи количества выведенных символов
    PUSH EAX                     ; Длина строки (nNumberOfCharsToWrite)
    PUSH OFFSET msg_poly         ; lpBuffer — указатель на строку
    PUSH DOUT                    ; hConsoleOutput — дескриптор вывода
    CALL WriteConsoleA@20        ; Выводим строку в консоль

    ; --- Вывод приглашения к вводу ---
    PUSH OFFSET msg_input
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET msg_input
    PUSH DOUT
    CALL WriteConsoleA@20

    ; --- Чтение ввода от пользователя ---
    PUSH 0                       ; lpReserved = NULL
    PUSH OFFSET bytes_read       ; Адрес переменной для количества прочитанных символов
    PUSH 100                     ; Максимальное количество символов для чтения
    PUSH OFFSET BUF              ; Буфер для хранения ввода
    PUSH DIN                     ; Дескриптор ввода
    CALL ReadConsoleA@20         ; Читаем строку из консоли

    ; --- Обработка введённой строки ---
    MOV ESI, OFFSET BUF          ; ESI указывает на начало введённой строки
    MOV ECX, bytes_read          ; ECX = количество прочитанных байт
    SUB ECX, 2                   ; Вычитаем 2 символа (CRLF — возврат каретки и перевод строки)
    JBE ERROR                    ; Если длина ? 0 — ошибка

    ; --- Проверка на отрицательное число (начинается с '-') ---
    MOV sign_flag, 0             ; Сбрасываем флаг знака
    CMP BYTE PTR [ESI], '-'      ; Проверяем первый символ
    JNE CHECK_POSITIVE           ; Если не '-', пропускаем обработку знака
    MOV sign_flag, 1             ; Устанавливаем флаг отрицательного числа
    INC ESI                      ; Пропускаем символ '-'
    DEC ECX                      ; Уменьшаем длину строки
    JZ ERROR                     ; Если после '-' ничего нет — ошибка

CHECK_POSITIVE:
    ; --- Проверка допустимой длины двоичного числа (1–32 бита) ---
    CMP ECX, 1                   ; Минимум 1 символ
    JB ERROR                     ; Меньше 1 — ошибка
    CMP ECX, 32                  ; Максимум 32 символа (32-битное число)
    JA ERROR                     ; Больше 32 — ошибка

    ; --- Преобразование двоичной строки в целое число (в EAX) ---
    XOR EAX, EAX                 ; Обнуляем EAX (результат)

BIN_CONV_LOOP:
    MOV BL, [ESI]                ; Загружаем текущий символ
    CMP BL, '0'                  ; Проверяем, не меньше ли '0'
    JB ERROR                     ; Если да — недопустимый символ
    CMP BL, '1'                  ; Проверяем, не больше ли '1'
    JA ERROR                     ; Если да — недопустимый символ
    SUB BL, '0'                  ; Преобразуем символ в цифру (0 или 1)
    SHL EAX, 1                   ; Сдвигаем результат влево на 1 бит (умножение на 2)
    MOVZX EBX, BL                ; Расширяем BL до 32 бит без знака
    ADD EAX, EBX                 ; Добавляем текущий бит
    JC ERROR                     ; Если произошло переполнение — ошибка
    INC ESI                      ; Переходим к следующему символу
    LOOP BIN_CONV_LOOP           ; Повторяем ECX раз

    ; --- Применение знака к числу ---
    CMP sign_flag, 1             ; Проверяем, было ли число отрицательным
    JNE STORE_X                  ; Если нет — пропускаем
    NEG EAX                      ; Инвертируем знак (делаем число отрицательным)

STORE_X:
    MOV DWORD PTR x, EAX         ; Сохраняем результат в переменную x

    ; --- Вывод введённого числа в десятичной системе ---
    PUSH OFFSET msg_decimal
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET msg_decimal
    PUSH DOUT
    CALL WriteConsoleA@20

    MOV EAX, x                   ; Загружаем число для преобразования
    LEA ESI, output_buf          ; Указатель на буфер вывода
    CALL NUMBER_TO_DEC_STRING    ; Преобразуем число в строку
    PUSH OFFSET output_buf
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET output_buf
    PUSH DOUT
    CALL WriteConsoleA@20

    ; --- Вывод перевода строки ---
    PUSH OFFSET newline
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET newline
    PUSH DOUT
    CALL WriteConsoleA@20

    ; --- Вычисление полинома: -1*x^2 + 8*x + 10 ---
    MOV EAX, DWORD PTR x         ; Загружаем x
    IMUL EAX, EAX                ; x * x ? x? (знаковое умножение)
    JO OVERFLOW                  ; Если переполнение — переход к обработке ошибки
    NEG EAX                      ; -x?
    MOV EBX, EAX                 ; Сохраняем -x? в EBX

    MOV EAX, DWORD PTR x         ; Загружаем x снова
    IMUL EAX, 8                  ; 8 * x
    JO OVERFLOW                  ; Проверка переполнения
    ADD EBX, EAX                 ; -x? + 8x
    JO OVERFLOW                  ; Проверка переполнения

    ADD EBX, 10                  ; -x? + 8x + 10
    JO OVERFLOW                  ; Проверка переполнения
    MOV DWORD PTR result, EBX    ; Сохраняем результат

    ; --- Вывод результата в двоичной системе ---
    PUSH OFFSET msg_result_bin
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET msg_result_bin
    PUSH DOUT
    CALL WriteConsoleA@20

    MOV EAX, result              ; Загружаем результат
    PUSH EAX                     ; Сохраняем на стеке (потому что NUMBER_TO_BIN_STRING меняет EAX)
    LEA ESI, output_buf          ; Указатель на буфер вывода
    CALL NUMBER_TO_BIN_STRING    ; Преобразуем в двоичную строку
    POP EAX                      ; Восстанавливаем результат (для получения длины строки)
    PUSH OFFSET output_buf
    CALL lstrlenA@4              ; Получаем длину результирующей строки
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET output_buf
    PUSH DOUT
    CALL WriteConsoleA@20

    ; --- Перевод строки ---
    PUSH OFFSET newline
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET newline
    PUSH DOUT
    CALL WriteConsoleA@20

    ; --- Вывод результата в десятичной системе ---
    PUSH OFFSET msg_result_dec
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET msg_result_dec
    PUSH DOUT
    CALL WriteConsoleA@20

    MOV EAX, result
    LEA ESI, output_buf
    CALL NUMBER_TO_DEC_STRING
    PUSH OFFSET output_buf
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET output_buf
    PUSH DOUT
    CALL WriteConsoleA@20

    ; --- Перевод строки ---
    PUSH OFFSET newline
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET newline
    PUSH DOUT
    CALL WriteConsoleA@20

    ; --- Корректное завершение программы ---
    PUSH 0                       ; Код выхода = 0 (успех)
    CALL ExitProcess@4           ; Завершаем процесс

; --- Обработка ошибки ввода ---
ERROR:
    PUSH OFFSET ERROR_STR
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET ERROR_STR
    PUSH DOUT
    CALL WriteConsoleA@20
    PUSH 1                       ; Код выхода = 1 (ошибка)
    CALL ExitProcess@4

; --- Обработка переполнения ---
OVERFLOW:
    PUSH OFFSET OVERFLOW_STR
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET OVERFLOW_STR
    PUSH DOUT
    CALL WriteConsoleA@20
    PUSH 1
    CALL ExitProcess@4

; ==============================================================================
; Процедура: NUMBER_TO_BIN_STRING
; Назначение: преобразует 32-битное целое число (в EAX) в двоичную строку
; Вход: EAX — число, ESI — адрес буфера для строки
; Выход: EDI — длина результирующей строки
; ==============================================================================
NUMBER_TO_BIN_STRING PROC
    XOR EDI, EDI                 ; Обнуляем счётчик длины строки
    TEST EAX, EAX                ; Проверяем знак числа
    JNS POSITIVE_BIN             ; Если неотрицательное — пропускаем обработку знака
    NEG EAX                      ; Делаем число положительным для обработки
    MOV BYTE PTR [ESI], '-'      ; Записываем минус в буфер
    INC ESI                      ; Переходим к следующей позиции
    INC EDI                      ; Увеличиваем длину строки

POSITIVE_BIN:
    BSR ECX, EAX                 ; Находим позицию старшего установленного бита
    JZ ZERO_NUMBER               ; Если число = 0 — особый случай
    INC ECX                      ; ECX = количество битов (BSR даёт индекс, +1 — кол-во)
    MOV EBX, EAX                 ; Сохраняем исходное число
    MOV EDX, 1                   ; EDX = маска
    SHL EDX, CL                  ; Сдвигаем 1 на CL позиций (CL = кол-во бит)
    SHR EDX, 1                   ; Корректируем маску (теперь она указывает на старший бит)
    MOV EAX, EBX                 ; Восстанавливаем число в EAX
    MOV EBX, ECX                 ; Сохраняем количество битов в EBX

BIN_LOOP:
    TEST EAX, EDX                ; Проверяем, установлен ли текущий бит
    JNZ BIT_ONE                  ; Если да — записываем '1'
    MOV BYTE PTR [ESI], '0'      ; Иначе — '0'
    JMP NEXT_BIT
BIT_ONE:
    MOV BYTE PTR [ESI], '1'      ; Записываем '1'

NEXT_BIT:
    INC ESI                      ; Переход к следующей позиции в буфере
    INC EDI                      ; Увеличиваем длину строки
    SHR EDX, 1                   ; Сдвигаем маску вправо на 1 бит
    DEC EBX                      ; Уменьшаем счётчик битов
    JNZ BIN_LOOP                 ; Повторяем, пока не обработаны все биты
    JMP END_BIN                  ; Завершаем

ZERO_NUMBER:
    MOV BYTE PTR [ESI], '0'      ; Для числа 0 — просто записываем '0'
    INC ESI
    INC EDI

END_BIN:
    RET                          ; Возврат из процедуры
NUMBER_TO_BIN_STRING ENDP

; ==============================================================================
; Процедура: NUMBER_TO_DEC_STRING
; Назначение: преобразует 32-битное целое число (в EAX) в десятичную строку
; Вход: EAX — число, ESI — адрес буфера для строки
; Выход: EDI — длина результирующей строки (внутренне используется, но не возвращается явно)
; ==============================================================================
NUMBER_TO_DEC_STRING PROC
    PUSH EAX                     ; Сохраняем регистры на стеке
    PUSH EBX
    PUSH ECX
    PUSH EDX

    MOV EBX, EAX                 ; Сохраняем исходное число
    LEA EDI, [ESI]               ; EDI = указатель на текущую позицию в буфере вывода
    TEST EAX, EAX                ; Проверяем знак
    JNS dec_positive             ; Если неотрицательное — пропускаем
    NEG EAX                      ; Делаем положительным
    MOV BYTE PTR [EDI], '-'      ; Записываем минус
    INC EDI                      ; Переходим к следующей позиции

dec_positive:
    CMP EAX, 0                   ; Проверяем, равно ли число нулю
    JNE dec_loop_start           ; Если нет — начинаем деление
    MOV BYTE PTR [EDI], '0'      ; Иначе — записываем '0'
    INC EDI
    JMP dec_done

dec_loop_start:
    LEA EBX, [ESP-32]            ; Используем стек как временный буфер (32 байта — хватит для 10 цифр)
    MOV ECX, 0                   ; Счётчик цифр

dec_loop:
    XOR EDX, EDX                 ; Обнуляем старшую часть делимого (EDX:EAX)
    DIV DWORD PTR [ten]          ; Делим EAX на 10 ? частное в EAX, остаток в EDX
    ADD DL, '0'                  ; Преобразуем остаток в ASCII-символ
    DEC EBX                      ; Двигаемся назад по временному буферу
    MOV [EBX], DL                ; Сохраняем цифру
    INC ECX                      ; Увеличиваем счётчик цифр
    TEST EAX, EAX                ; Проверяем, закончились ли цифры
    JNZ dec_loop                 ; Если нет — продолжаем

    ; --- Копируем цифры из временного буфера в выходной буфер ---
    MOV EAX, ECX                 ; EAX = количество цифр
dec_copy:
    MOV DL, [EBX]                ; Загружаем цифру
    MOV [EDI], DL                ; Записываем в выходной буфер
    INC EBX                      ; Переходим к следующей цифре во временном буфере
    INC EDI                      ; Переходим к следующей позиции в выходном буфере
    DEC EAX                      ; Уменьшаем счётчик
    JNZ dec_copy                 ; Повторяем, пока не скопированы все цифры

dec_done:
    MOV BYTE PTR [EDI], 0        ; Завершаем строку нулём (ASCIIZ)

    POP EDX                      ; Восстанавливаем регистры
    POP ECX
    POP EBX
    POP EAX
    RET

ten DD 10                        ; Константа 10 для деления
NUMBER_TO_DEC_STRING ENDP

MAIN ENDP                        ; Конец процедуры MAIN
END MAIN                         ; Точка входа программы — MAIN
