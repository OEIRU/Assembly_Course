.386
.MODEL FLAT, STDCALL
OPTION CASEMAP: NONE

EXTRN GetStdHandle@4:NEAR
EXTRN WriteConsoleA@20:NEAR
EXTRN CharToOemA@8:NEAR
EXTRN ReadConsoleA@20:NEAR
EXTRN ExitProcess@4:NEAR
EXTRN lstrlenA@4:NEAR
EXTRN wsprintfA:NEAR


STD_INPUT_HANDLE EQU -10    ; Константа для получения дескриптора ввода
STD_OUTPUT_HANDLE EQU -11   ; Константа для получения дескриптора вывода


.DATA
    hStdIn DD 0             ; Дескриптор ввода
    hStdOut DD 0            ; Дескриптор вывода
    bytesRead DD 0          ; Количество прочитанных байт
    bytesWritten DD 0       ; Количество записанных байт

    ; Сообщения для пользователя
    msgSource    DB "Введите исходную строку: ", 0
    msgStartPos  DB "Введите начальную позицию: ", 0
    msgLength    DB "Введите длину подстроки: ", 0
    msgResult    DB "Результат: ", 0
    msgError     DB "Ошибка: некорректные параметры!", 0

    ; Буферы для строк и промежуточных данных
    sourceString DB 255 DUP(0)   ; Введённая пользователем строка
    startPosStr  DB 10 DUP(0)    ; Строка для ввода позиции
    lengthStr    DB 10 DUP(0)    ; Строка для ввода длины
    resultBuffer DB 255 DUP(0)   ; Буфер для результата (подстрока)


    ; Числовые значения
    startPos  DD 0               ; Начальная позиция подстроки
    subLength DD 0               ; Длина подстроки
    letterFound DB 0             ; Флаг: найдена ли буква в подстроке


.CODE
start:
    ; Получение дескрипторов ввода и вывода консоли
    PUSH STD_INPUT_HANDLE
    CALL GetStdHandle@4
    MOV hStdIn, EAX
    PUSH STD_OUTPUT_HANDLE
    CALL GetStdHandle@4
    MOV hStdOut, EAX

    ; Переводим все сообщения в OEM-кодировку для корректного вывода в консоль
    PUSH OFFSET msgSource
    PUSH OFFSET msgSource
    CALL CharToOemA@8
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



    ; Запрос исходной строки у пользователя
    PUSH OFFSET msgSource
    CALL PrintMessage
    PUSH OFFSET sourceString
    CALL ReadInput

    ; Запрос начальной позиции подстроки
    PUSH OFFSET msgStartPos
    CALL PrintMessage
    PUSH OFFSET startPosStr
    CALL ReadInput
    PUSH OFFSET startPosStr
    CALL atoi
    MOV startPos, EAX

    ; Запрос длины подстроки
    PUSH OFFSET msgLength
    CALL PrintMessage
    PUSH OFFSET lengthStr
    CALL ReadInput
    PUSH OFFSET lengthStr
    CALL atoi
    MOV subLength, EAX

    ; Проверка корректности параметров 
    ; (позиция и длина не выходят за границы строки)
    CALL ValidateParameters
    CMP EAX, 0
    JE ErrorExit



    ; Выделение подстроки из исходной строки
    CALL ExtractSubstring

    ; Перевод подстроки в нижний регистр и одновременная проверка наличия буквы
    MOV letterFound, 0
    CALL ConvertToLower
    CMP letterFound, 0
    JE ErrorExit

    ; Вывод результата пользователю
    PUSH OFFSET msgResult
    CALL PrintMessage
    PUSH OFFSET resultBuffer
    CALL PrintMessage
    JMP ExitProgram

ErrorExit:
    ; Вывод сообщения об ошибке
    PUSH OFFSET msgError
    CALL PrintMessage

ExitProgram:
    ; Завершение программы
    PUSH 0
    CALL ExitProcess@4


; Проверяет, что параметры подстроки корректны 
; (позиция и длина не выходят за границы исходной строки)
ValidateParameters PROC
    MOV EAX, startPos
        MOV ESI, [ESP+4]
    JL InvalidParams
    PUSH OFFSET sourceString
    CALL lstrlenA@4
    MOV ECX, EAX
    MOV EAX, startPos
    DEC EAX
    ADD EAX, subLength
    CMP EAX, ECX
    JG InvalidParams
    MOV EAX, 1
    RET
InvalidParams:
    MOV EAX, 0
    RET
ValidateParameters ENDP


; Извлекает подстроку из исходной строки по позиции и длине
ExtractSubstring PROC
    MOV ESI, OFFSET sourceString   ; Адрес исходной строки
    ADD ESI, startPos             ; Смещаемся на startPos
    DEC ESI                       ; Корректируем (позиция с 1)
    MOV EDI, OFFSET resultBuffer  ; Куда копировать
    MOV ECX, subLength            ; Сколько символов
    CLD
    REP MOVSB                     ; Копируем подстроку
    MOV BYTE PTR [EDI], 0         ; Завершаем нулём
    RET
ExtractSubstring ENDP


; Переводит подстроку в нижний регистр (английские и русские буквы в CP866)
ConvertToLower PROC
    MOV EDI, OFFSET resultBuffer
    MOV ECX, subLength
ConvertLoop:
    MOV AL, [EDI]
    ; Проверка английских букв (A-Z)
    CMP AL, 'A'
    JL CheckRussian
    CMP AL, 'Z'
    JG CheckRussian
    ADD AL, 32
    MOV [EDI], AL
    MOV letterFound, 1
    JMP NextChar
CheckRussian:
    ; Русские заглавные буквы 'А'-'П' (128..143) -> 'а'-'п' (160..175)
    CMP AL, 128
    JL CheckRtoYa
    CMP AL, 143
    JG CheckRtoYa
    ADD AL, 32
    MOV [EDI], AL
    MOV letterFound, 1
    JMP NextChar
CheckRtoYa:
    ; Русские заглавные буквы 'Р'-'Я' (144..159) -> 'р'-'я' (224..239)
    CMP AL, 144
    JL NextChar
    CMP AL, 159
    JG NextChar
    ADD AL, 80
    MOV [EDI], AL
    MOV letterFound, 1
NextChar:
    INC EDI
    LOOP ConvertLoop
    RET
ConvertToLower ENDP


; Выводит строку на консоль
PrintMessage PROC
    PUSH EBP
    MOV EBP, ESP
    ; Определение длины строки
    PUSH [EBP+8]
    CALL lstrlenA@4
    ; Вывод сообщения
    PUSH 0
    PUSH OFFSET bytesWritten
    PUSH EAX
    PUSH [EBP+8]
    PUSH hStdOut
    CALL WriteConsoleA@20
    POP EBP
    RET 4
PrintMessage ENDP


; Читает строку с консоли, удаляет символы перевода строки
ReadInput PROC
    PUSH EBP
    MOV EBP, ESP
    PUSH 0
    PUSH OFFSET bytesRead
    PUSH 253
    PUSH [EBP+8]
    PUSH hStdIn
    CALL ReadConsoleA@20
    ; Удаление символов CRLF (конец строки)
    MOV EDI, [EBP+8]
    MOV ECX, bytesRead
    CMP ECX, 2
    JL Done
    SUB ECX, 2
    MOV BYTE PTR [EDI+ECX], 0
Done:
    POP EBP
    RET 4
ReadInput ENDP


; Преобразует строку в целое число (atoi)
atoi PROC
    PUSH EBP
    MOV EBP, ESP
    PUSH EBX
    PUSH ESI
    MOV ESI, [EBP+8]
    XOR EAX, EAX
    XOR ECX, ECX
    XOR EBX, EBX
ConvertLoop:
    MOV CL, [ESI]
    INC ESI
    CMP CL, '0'
    JB Done
    CMP CL, '9'
    JA Done
    SUB CL, '0' 
    IMUL EAX, 10
    ADD EAX, ECX
    JMP ConvertLoop
Done:
    POP ESI
    POP EBX
    POP EBP
    RET 4
atoi ENDP



END start