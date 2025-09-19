.386
.MODEL FLAT, STDCALL
OPTION CASEMAP: NONE

EXTERN WriteConsoleA@20: PROC
EXTERN CharToOemA@8: PROC
EXTERN GetStdHandle@4: PROC
EXTERN lstrlenA@4: PROC
EXTERN ExitProcess@4: PROC
EXTERN ReadConsoleA@20: PROC

.DATA
    msg_input           DB "Введите число в двоичной системе: ", 0
    msg_decimal         DB "В десятичной системе: ", 0
    msg_result_bin      DB "Результат в двоичной системе: ", 0
    msg_result_dec      DB "Результат в десятичной системе: ", 0
    msg_poly            DB "Вычисление полинома: -1*x^2 + 8*x + 10", 13, 10, 0
    ERROR_STR           DB "Ошибка: введено недвоичное число или неверная длина", 0
    OVERFLOW_STR        DB "Переполнение при вычислении", 0
    newline             DB 13, 10, 0

    DOUT                DD ?
    DIN                 DD ?
    bytes_read          DD ?
    bytes_written       DD ?
    x                   DD ?
    result              DD ?
    BUF                 DB 100 DUP (?)
    output_buf          DB 100 DUP (?)
    sign_flag           DB 0

.CODE
MAIN PROC
    ; Преобразование строк в OEM-кодировку
    MOV EAX, OFFSET msg_input
    PUSH EAX
    PUSH EAX
    CALL CharToOemA@8

    MOV EAX, OFFSET msg_decimal
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

    ; Получение дескрипторов ввода и вывода
    PUSH -11
    CALL GetStdHandle@4
    MOV DOUT, EAX

    PUSH -10
    CALL GetStdHandle@4
    MOV DIN, EAX

    ; Вывод сообщения о полиноме
    PUSH OFFSET msg_poly
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET msg_poly
    PUSH DOUT
    CALL WriteConsoleA@20

    ; Вывод приглашения к вводу
    PUSH OFFSET msg_input
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET msg_input
    PUSH DOUT
    CALL WriteConsoleA@20

    ; Ввод числа
    PUSH 0
    PUSH OFFSET bytes_read
    PUSH 100
    PUSH OFFSET BUF
    PUSH DIN
    CALL ReadConsoleA@20

    ; Обработка введенной строки
    MOV ESI, OFFSET BUF
    MOV ECX, bytes_read
    SUB ECX, 2                  ; Игнорируем CRLF
    JBE ERROR                   ; Если длина 0 или меньше

    ; Проверка на отрицательное число
    MOV sign_flag, 0
    CMP BYTE PTR [ESI], '-'
    JNE CHECK_POSITIVE
    MOV sign_flag, 1
    INC ESI
    DEC ECX
    JZ ERROR                    ; Если только минус

CHECK_POSITIVE:
    ; Проверка длины
    CMP ECX, 1
    JB ERROR
    CMP ECX, 32
    JA ERROR

    ; Преобразование двоичной строки в число
    XOR EAX, EAX
BIN_CONV_LOOP:
    MOV BL, [ESI]
    CMP BL, '0'
    JB ERROR
    CMP BL, '1'
    JA ERROR
    SUB BL, '0'
    SHL EAX, 1
    MOVZX EBX, BL
    ADD EAX, EBX
    JC ERROR                    ; Переполнение
    INC ESI
    LOOP BIN_CONV_LOOP

    ; Учет знака
    CMP sign_flag, 1
    JNE STORE_X
    NEG EAX

STORE_X:
    MOV DWORD PTR x, EAX

    ; Вывод введенного числа в десятичной системе
    PUSH OFFSET msg_decimal
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET msg_decimal
    PUSH DOUT
    CALL WriteConsoleA@20

    MOV EAX, x
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

    PUSH OFFSET newline
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET newline
    PUSH DOUT
    CALL WriteConsoleA@20


    ; Вычисление полинома: -1*x^2 + 8*x + 10
    MOV EAX, DWORD PTR x
    IMUL EAX, EAX                ; x^2
    JO OVERFLOW                  ; Проверка переполнения
    NEG EAX                      ; -x^2
    MOV EBX, EAX                 ; EBX = -x^2

    MOV EAX, DWORD PTR x
    IMUL EAX, 8                  ; 8*x
    JO OVERFLOW
    ADD EBX, EAX                 ; EBX = -x^2 + 8*x
    JO OVERFLOW

    ADD EBX, 10                  ; EBX = -x^2 + 8*x + 10
    JO OVERFLOW
    MOV DWORD PTR result, EBX

    ; Вывод результата в двоичной системе
    PUSH OFFSET msg_result_bin
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET msg_result_bin
    PUSH DOUT
    CALL WriteConsoleA@20

    MOV EAX, result
    PUSH EAX                ; Сохраняем результат
    LEA ESI, output_buf
    CALL NUMBER_TO_BIN_STRING
    POP EAX                 ; Восстанавливаем результат
    PUSH OFFSET output_buf
    CALL lstrlenA@4         ; Получаем длину строки
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX                ; длина строки
    PUSH OFFSET output_buf
    PUSH DOUT
    CALL WriteConsoleA@20

    PUSH OFFSET newline
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET newline
    PUSH DOUT
    CALL WriteConsoleA@20

    ; Вывод результата в десятичной системе
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
    CALL lstrlenA@4         ; Получаем длину строки
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX                ; длина строки
    PUSH OFFSET output_buf
    PUSH DOUT
    CALL WriteConsoleA@20

    PUSH OFFSET newline
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET newline
    PUSH DOUT
    CALL WriteConsoleA@20

    ; Завершение программы
    PUSH 0
    CALL ExitProcess@4

ERROR:
    PUSH OFFSET ERROR_STR
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytes_written
    PUSH EAX
    PUSH OFFSET ERROR_STR
    PUSH DOUT
    CALL WriteConsoleA@20
    PUSH 1
    CALL ExitProcess@4

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

; Преобразование числа в EAX в двоичную строку
; ESI - буфер для строки
; На выходе: EDI - длина строки
NUMBER_TO_BIN_STRING PROC
    XOR EDI, EDI
    TEST EAX, EAX
    JNS POSITIVE_BIN
    NEG EAX
    MOV BYTE PTR [ESI], '-'
    INC ESI
    INC EDI
POSITIVE_BIN:
    BSR ECX, EAX            ; Находим индекс старшего установленного бита
    JZ ZERO_NUMBER          ; Если число ноль
    INC ECX                 ; ECX = количество бит для вывода
    MOV EBX, EAX
    MOV EDX, 1
    SHL EDX, CL
    SHR EDX, 1              ; EDX = маска для старшего бита
    MOV EAX, EBX
    MOV EBX, ECX            ; Сохраняем количество бит в EBX
BIN_LOOP:
    TEST EAX, EDX
    JNZ BIT_ONE
    MOV BYTE PTR [ESI], '0'
    JMP NEXT_BIT
BIT_ONE:
    MOV BYTE PTR [ESI], '1'
NEXT_BIT:
    INC ESI
    INC EDI
    SHR EDX, 1
    DEC EBX
    JNZ BIN_LOOP
    JMP END_BIN
ZERO_NUMBER:
    MOV BYTE PTR [ESI], '0'
    INC ESI
    INC EDI
END_BIN:
    RET
NUMBER_TO_BIN_STRING ENDP

; Преобразование числа в EAX в десятичную строку
; ESI - буфер для строки
; На выходе: EDI - длина строки

; Корректная процедура преобразования числа в EAX в десятичную строку
; ESI - буфер для строки
; На выходе: EDI - длина строки



NUMBER_TO_DEC_STRING PROC
    ; EAX - число, ESI - буфер
    PUSH EAX
    PUSH EBX
    PUSH ECX
    PUSH EDX

    MOV EBX, EAX         ; EBX = исходное число
    LEA EDI, [ESI]       ; EDI = буфер вывода
    TEST EAX, EAX
    JNS dec_positive
    NEG EAX
    MOV BYTE PTR [EDI], '-'
    INC EDI
dec_positive:
    ; Если число 0, сразу пишем '0'
    CMP EAX, 0
    JNE dec_loop_start
    MOV BYTE PTR [EDI], '0'
    INC EDI
    JMP dec_done
dec_loop_start:
    ; Формируем цифры справа налево во временном массиве на стеке
    LEA EBX, [ESP-32]    ; EBX = временный стек (32 байта)
    MOV ECX, 0           ; ECX = количество цифр
dec_loop:
    XOR EDX, EDX
    DIV DWORD PTR [ten]
    ADD DL, '0'
    DEC EBX
    MOV [EBX], DL
    INC ECX
    TEST EAX, EAX
    JNZ dec_loop
    ; Копируем цифры из временного стека в буфер
    MOV EAX, ECX         ; EAX = количество цифр
dec_copy:
    MOV DL, [EBX]
    MOV [EDI], DL
    INC EBX
    INC EDI
    DEC EAX
    JNZ dec_copy
dec_done:
    MOV BYTE PTR [EDI], 0

    POP EDX
    POP ECX
    POP EBX
    POP EAX
    RET
ten DD 10
NUMBER_TO_DEC_STRING ENDP

MAIN ENDP
END MAIN