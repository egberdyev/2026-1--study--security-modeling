# Модель экспоненциального роста

Лабораторная работа № 1. Бердыев Эзиз, НФИмд-01-25.

Этот файл написан в стиле литературного программирования (Literate.jl).
Из него операцией *tangle* получается исполняемый сценарий, а операцией
*weave* — Jupyter-блокнот и документация в формате Quarto.

## Постановка задачи

Рассматривается простейшая динамическая модель — экспоненциальный рост.
Скорость изменения величины пропорциональна её текущему значению:

```math
\frac{du}{dt} = \alpha u, \qquad u(0) = u_0 .
```

Уравнение допускает точное решение $u(t) = u_0 e^{\alpha t}$, что делает
задачу удобным эталоном для проверки вычислительного стенда.

````julia
using DrWatson
@quickactivate "project"

using DifferentialEquations
using Plots
using DataFrames
````

## Правая часть уравнения

Функция записана в in-place форме: она не создаёт новый массив, а изменяет
уже существующий вектор производных `du`. Это рекомендуемая форма для
DifferentialEquations.jl, так как она не нагружает сборщик мусора.

````julia
function exponential_growth!(du, u, p, t)
    α = p              # коэффициент роста передаётся как параметр задачи
    du[1] = α * u[1]   # du/dt = αu
    return nothing
end
````

## Параметры базового эксперимента

Значения вынесены отдельно, чтобы их можно было варьировать, не трогая
остальной код.

````julia
u0 = [1.0]         # начальное значение u(0)
α = 0.3            # коэффициент роста
tspan = (0.0, 10.0) # интервал интегрирования
````

## Численное решение

Задача Коши решается методом `Tsit5()` — явным методом Рунге—Кутты
5(4) порядка с адаптивным шагом. Опция `saveat=0.1` сохраняет решение с
постоянным шагом, что упрощает сравнение с аналитической формулой.

````julia
prob = ODEProblem(exponential_growth!, u0, tspan, α)
sol = solve(prob, Tsit5(), saveat = 0.1)
````

## Аналитическое решение и контроль точности

Точное решение вычисляется по формуле, после чего оценивается максимальное
отклонение численного решения от него. Малая величина отклонения
подтверждает корректность настройки стенда.

````julia
u_exact = u0[1] .* exp.(α .* sol.t)
u_num = first.(sol.u)

max_abs_error = maximum(abs.(u_num .- u_exact))
max_rel_error = maximum(abs.(u_num .- u_exact) ./ u_exact)

println("Максимальная абсолютная погрешность: ", max_abs_error)
println("Максимальная относительная погрешность: ", max_rel_error)
````

## Время удвоения

Время удвоения $T_2 = \ln 2 / \alpha$ не зависит от начального значения,
поэтому удобно как характеристика скорости процесса.

````julia
doubling_time = log(2) / α
println("Время удвоения T₂ = ", round(doubling_time, digits = 2))
````

## Таблица результатов

````julia
df = DataFrame(t = sol.t, u_num = u_num, u_exact = u_exact)
println(first(df, 5))
````

## График решения

````julia
plot(sol.t, u_num,
    label = "численное решение",
    xlabel = "Время t",
    ylabel = "Значение u",
    title = "Экспоненциальный рост (α = $α)",
    lw = 2,
    legend = :topleft)

plot!(sol.t, u_exact, label = "аналитическое решение", ls = :dash, lw = 2)

savefig(plotsdir("exponential_growth_α=$α.png"))
````

## Вычисление для набора параметров

Согласно заданию, модель исследуется не только в одной точке, но и на наборе
значений коэффициента роста. Для каждого $\alpha$ вычисляются конечное
значение и время удвоения.

````julia
α_values = [0.1, 0.3, 0.5, 1.0]
sweep = DataFrame(α = Float64[], u_final = Float64[], doubling_time = Float64[])

for a in α_values
    p = ODEProblem(exponential_growth!, u0, tspan, a)
    s = solve(p, Tsit5(), saveat = 0.1)
    push!(sweep, (a, last(s.u)[1], log(2) / a))
end

println(sweep)
````

Результаты сведены на общем графике: чем больше $\alpha$, тем круче кривая и
тем меньше время удвоения.

````julia
plt = plot(xlabel = "Время t", ylabel = "Значение u",
    title = "Влияние коэффициента роста", legend = :topleft)

for a in α_values
    p = ODEProblem(exponential_growth!, u0, tspan, a)
    s = solve(p, Tsit5(), saveat = 0.1)
    plot!(plt, s.t, first.(s.u), label = "α = $a", lw = 2)
end

savefig(plt, plotsdir("exponential_growth_parameter_sweep.png"))
````

## Выводы

Численное и аналитическое решения совпадают с точностью, достаточной для
задач этого класса. Время удвоения обратно пропорционально коэффициенту
роста, что подтверждается параметрическим исследованием.

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

