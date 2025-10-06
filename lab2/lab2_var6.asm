.386
.MODEL FLAT, STDCALL
OPTION CASEMAP: NONE

EXTRN GetStdHandle@4:NEAR
EXTRN WriteConsoleA@20:NEAR
EXTRN CharToOemA@8:NEAR
EXTRN ReadConsoleA@20:NEAR
EXTRN ExitProcess@4:NEAR
EXTRN lstrlenA@4:NEAR

STD_INPUT_HANDLE EQU -10
STD_OUTPUT_HANDLE EQU -11

.DATA
    hStdIn DD 0
    hStdOut DD 0
    bytesRead DD 0
    bytesWritten DD 0

    msgSource    DB "Введите исходную строку: ", 0
    msgStartPos  DB "Введите начальную позицию: ", 0
    msgLength    DB "Введите длину подстроки: ", 0
    msgResult    DB "Результат: ", 0
    msgError     DB "Ошибка: некорректные параметры!", 0
    newline      DB 13, 10, 0

    sourceString DB 255 DUP(0)
    startPosStr  DB 10 DUP(0)
    lengthStr    DB 10 DUP(0)
    resultBuffer DB 255 DUP(0)
    tempBuffer   DB 255 DUP(0)

    startPos  DD 0
    subLength DD 0
    letterFound DB 0

.CODE
start:
    ; Получение дескрипторов
    PUSH STD_INPUT_HANDLE
    CALL GetStdHandle@4
    MOV hStdIn, EAX
    
    PUSH STD_OUTPUT_HANDLE
    CALL GetStdHandle@4
    MOV hStdOut, EAX

    ; Преобразование сообщений в OEM
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

    ; Ввод исходной строки
    PUSH OFFSET msgSource
    CALL PrintMessage
    PUSH OFFSET sourceString
    CALL ReadInput

    ; Ввод начальной позиции
    PUSH OFFSET msgStartPos
    CALL PrintMessage
    PUSH OFFSET startPosStr
    CALL ReadInput
    PUSH OFFSET startPosStr
    CALL atoi
    MOV startPos, EAX

    ; Ввод длины
    PUSH OFFSET msgLength
    CALL PrintMessage
    PUSH OFFSET lengthStr
    CALL ReadInput
    PUSH OFFSET lengthStr
    CALL atoi
    MOV subLength, EAX

    ; Проверка параметров
    CALL ValidateParameters
    CMP EAX, 0
    JE ErrorExit

    ; Извлечение подстроки
    CALL ExtractSubstring
    
    ; Проверка наличия букв и преобразование в нижний регистр
    CALL CheckAndConvert
    CMP letterFound, 0
    JE ErrorExit

    ; Вывод результата
    PUSH OFFSET msgResult
    CALL PrintMessage
    
    ; Вывод самой подстроки
    PUSH OFFSET resultBuffer
    CALL PrintMessage
    
    ; Добавляем перевод строки
    PUSH OFFSET newline
    CALL PrintMessage
    
    JMP ExitProgram

ErrorExit:
    PUSH OFFSET msgError
    CALL PrintMessage
    PUSH OFFSET newline
    CALL PrintMessage

ExitProgram:
    PUSH 0
    CALL ExitProcess@4

; Проверка параметров
ValidateParameters PROC
    ; Проверка startPos >= 1
    MOV EAX, startPos
    CMP EAX, 1
    JL InvalidParams
    
    ; Проверка subLength > 0
    MOV EAX, subLength
    CMP EAX, 0
    JLE InvalidParams
    
    ; Получение длины исходной строки
    PUSH OFFSET sourceString
    CALL lstrlenA@4
    MOV ECX, EAX
    
    ; Проверка что startPos не превышает длину строки
    MOV EAX, startPos
    CMP EAX, ECX
    JG InvalidParams
    
    ; Проверка что подстрока не выходит за границы
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

; Извлечение подстроки
ExtractSubstring PROC
    MOV ESI, OFFSET sourceString
    MOV EAX, startPos
    DEC EAX
    ADD ESI, EAX
    MOV EDI, OFFSET resultBuffer
    MOV ECX, subLength
    CLD
    REP MOVSB
    MOV BYTE PTR [EDI], 0
    RET
ExtractSubstring ENDP

; Проверка наличия букв и преобразование в нижний регистр
CheckAndConvert PROC
    MOV EDI, OFFSET resultBuffer
    MOV ECX, subLength
    MOV letterFound, 0
    
ProcessLoop:
    MOV AL, [EDI]
    
    ; Проверка английских букв A-Z
    CMP AL, 'A'
    JB CheckEnglishLower
    CMP AL, 'Z'
    JA CheckEnglishLower
    ; Это заглавная английская буква
    MOV letterFound, 1
    ADD AL, 32  ; Преобразуем в строчную
    MOV [EDI], AL
    JMP NextChar
    
CheckEnglishLower:
    ; Проверка английских букв a-z
    CMP AL, 'a'
    JB CheckRussian
    CMP AL, 'z'
    JA CheckRussian
    ; Это строчная английская буква
    MOV letterFound, 1
    JMP NextChar
    
CheckRussian:
    ; Проверка русских букв в OEM-кодировке (CP866)
    ; Русские заглавные А-Я: 80h-9Fh (128-159)
    CMP AL, 80h
    JB NextChar
    CMP AL, 9Fh
    JA CheckRussianLower
    ; Это заглавная русская буква
    MOV letterFound, 1
    ; Преобразуем в строчную
    CMP AL, 90h  ; Разделяем на две группы
    JB FirstGroup
    ; Вторая группа Р-Я (90h-9Fh -> E0h-EFh)
    ADD AL, 50h
    JMP StoreRussian
FirstGroup:
    ; Первая группа А-П (80h-8Fh -> A0h-AFh)
    ADD AL, 20h
StoreRussian:
    MOV [EDI], AL
    JMP NextChar

CheckRussianLower:
    ; Русские строчные а-я: A0h-BFh и E0h-EFh (160-191 и 224-239)
    CMP AL, 0A0h
    JB NextChar
    CMP AL, 0BFh
    JA CheckRussianLower2
    ; Это строчная русская буква первой группы
    MOV letterFound, 1
    JMP NextChar
    
CheckRussianLower2:
    CMP AL, 0E0h
    JB NextChar
    CMP AL, 0EFh
    JA NextChar
    ; Это строчная русская буква второй группы
    MOV letterFound, 1
    
NextChar:
    INC EDI
    LOOP ProcessLoop
    RET
CheckAndConvert ENDP

; Вывод строки
PrintMessage PROC
    PUSH EBP
    MOV EBP, ESP
    PUSH [EBP+8]
    CALL lstrlenA@4
    PUSH 0
    PUSH OFFSET bytesWritten
    PUSH EAX
    PUSH [EBP+8]
    PUSH hStdOut
    CALL WriteConsoleA@20
    POP EBP
    RET 4
PrintMessage ENDP

; Чтение ввода
ReadInput PROC
    PUSH EBP
    MOV EBP, ESP
    PUSH 0
    PUSH OFFSET bytesRead
    PUSH 254
    PUSH [EBP+8]
    PUSH hStdIn
    CALL ReadConsoleA@20
    ; Удаление CRLF
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

; Преобразование строки в число
atoi PROC
    PUSH EBP
    MOV EBP, ESP
    PUSH EBX
    PUSH ESI
    MOV ESI, [EBP+8]
    XOR EAX, EAX
    XOR EBX, EBX
ConvertLoop:
    MOV BL, [ESI]
    CMP BL, 0
    JE Done
    CMP BL, '0'
    JB Done
    CMP BL, '9'
    JA Done
    SUB BL, '0'
    IMUL EAX, 10
    ADD EAX, EBX
    INC ESI
    JMP ConvertLoop
Done:
    POP ESI
    POP EBX
    POP EBP
    RET 4
atoi ENDP

END start