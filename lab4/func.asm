.386
.model flat, c

.data
three REAL8 3.0     ; константа 3.0 (double)
four  REAL8 4.0     ; константа 4.0 (double)

.code
PUBLIC func

; double __cdecl func(double x)
; Вход: x (double) на стеке, по адресу [ebp+8]
; Выход: результат в st(0)
func PROC
    push ebp
    mov ebp, esp

    finit               ; Сброс FPU — стек пуст: []

    fld qword ptr [ebp+8]   ; Загрузить x → st(0) = x
                            ; Стек: [x]

    fsincos                 ; Вычислить sin(x) и cos(x)
                            ; Результат: st(0) = cos(x), st(1) = sin(x)
                            ; Стек: [cos(x), sin(x)]

    fstp st(1)              ; Удалить sin(x) — выталкивает st(1), стек сдвигается
                            ; Стек: [cos(x)]

    fmul st(0), st(0)       ; st(0) = st(0) * st(0) → cos²(x)
                            ; Стек: [cos²(x)]

    fmul qword ptr [three]  ; st(0) = st(0) * 3.0 → 3 * cos²(x)
                            ; Стек: [3 * cos²(x)]

    fdiv qword ptr [four]   ; st(0) = st(0) / 4.0 → (3 * cos²(x)) / 4   
                            ; Стек: [(3 * cos²(x)) / 4]

    pop ebp
    ret                     ; Возврат: результат в st(0)
func ENDP

end