#include <iostream>
#include <cstdio>
#include <cmath>
#include <cstdlib>

int main() {
    // Открываем pipe к gnuplot
    FILE* gnuplotPipe = _popen("gnuplot -persistent", "w");
    if (!gnuplotPipe) {
        std::cerr << "Не удалось запустить gnuplot. Установите его и добавьте в PATH.\n";
        return 1;
    }

    // Настройка графика
    fprintf(gnuplotPipe, "set title \"График функции y = (3 * cos^2(x)) / 4\"\n");
    fprintf(gnuplotPipe, "set xlabel \"x\"\n");
    fprintf(gnuplotPipe, "set ylabel \"y\"\n");
    fprintf(gnuplotPipe, "set grid\n");
    fprintf(gnuplotPipe, "set style line 1 lc rgb '#FF0000' lt 1 lw 2 pt 7 ps 0.5\n"); 
    fprintf(gnuplotPipe, "plot '-' with lines ls 1 title \"y = (3 * cos^2(x)) / 4\"\n");

    // Генерируем данные: x от -2? до 2?
    const double step = 0.05;
    for (double x = -2 * M_PI; x <= 2 * M_PI; x += step) {
        double y = (3.0 * pow(cos(x), 2)) / 4.0;
        fprintf(gnuplotPipe, "%f %f\n", x, y);
    }
    fprintf(gnuplotPipe, "e\n"); // конец данных

    fflush(gnuplotPipe);
    _pclose(gnuplotPipe);

    std::cout << "График построен. Окно gnuplot должно открыться.\n";
    system("pause");
    return 0;
}