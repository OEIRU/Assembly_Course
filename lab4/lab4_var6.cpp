#include <iostream>
#include <locale>

extern "C" double __cdecl func(double x);

int main() {
    std::setlocale(LC_ALL, "Russian");
    double x, res;

    std::cout << "Рассчет функции y = (3 * cos^2(x)) / 4\nВведите x: ";
    std::cin >> x;

    if (std::cin.good()) {
        res = func(x); // Вызов ассемблерной функции
        std::cout << "Результат: " << res << std::endl;
    }
    else {
        std::cout << "Ошибка ввода" << std::endl;
    }

    system("pause");
    return 0;
}