#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <string.h>
#include <cstdlib>

extern "C" {
    int __cdecl strcopy(const char* source, char* dest, int nbeg, int nlen);
}

int main()
{
    // Переключаем консоль на кодовую страницу 866 (CP866) для корректного отображения русских символов
    system("chcp 866 > nul");

    // Инициализируем буферы нулями — защита от мусора
    char str1[256] = { 0 };
    char str2[256] = { 0 };
    int nbeg, nlen;

    // Ввод исходной строки
    printf("Input: ");
    fgets(str1, sizeof(str1), stdin); 

    // Удаляем символы
    size_t len = strlen(str1);
    if (len > 0 && str1[len - 1] == '\n')
    {
        str1[len - 1] = '\0';
        // Проверим, не остался ли \r перед \n
        if (len > 1 && str1[len - 2] == '\r')
            str1[len - 2] = '\0';
    }

    // Ввод начальной позиции и длины подстроки
    printf("start point: ");
    scanf("%d", &nbeg);

    printf("len: ");
    scanf("%d", &nlen);

    // Вызов ассемблерной функции
    int res = strcopy(str1, str2, nbeg, nlen);

    // Вывод результата
    if (res == 0)
        printf("Output: %s\n", str2);
    else
        printf("ERROR: Incorrect params!\n");

    return 0;
}