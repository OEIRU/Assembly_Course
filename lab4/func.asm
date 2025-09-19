    .386
    .model flat, c          ; Соглашение вызова __cdecl

    .data
    three REAL8 3.0         ; Константа 3.0 (double)
    four  REAL8 4.0         ; Константа 4.0 (double)

    .code
    PUBLIC func             

    ; double __cdecl func(double x)
    ; x передается через стек (8 байт), возвращаем через st(0)
    func PROC
        push ebp
        mov ebp, esp

        finit               

        fld qword ptr [ebp+8]   ; Загрузить double x в st(0)
        fsincos                 ; st(0)=cos(x), st(1)=sin(x)
        fstp st(1)              ; Удалить sin(x), оставить cos(x)
        fmul st(0), st(0)       ; st(0) = cos^2(x)
        fmul qword ptr [three]  ; st(0) = 3 * cos^2(x)
        fdiv qword ptr [four]   ; st(0) = (3 * cos^2(x)) / 4

        pop ebp
        ret                 ; __cdecl: очистка стека
    func ENDP

    end