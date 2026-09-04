# Вероятностное моделирование потока атак

Лабораторная работа № 2. Бердыев Эзиз, НФИмд-01-25.

Файл написан в стиле литературного программирования (Literate.jl): из него
порождаются чистый сценарий, Jupyter-блокнот и документация Quarto.

## Постановка задачи

Моделируется поток атак на веб-сервер. Поток считается пуассоновским:
события происходят независимо друг от друга с постоянной интенсивностью
$\lambda$. Тогда число событий за интервал длины $T$ распределено по закону
Пуассона, а интервалы между соседними событиями — по показательному закону:

```math
P(N = k) = \frac{(\lambda T)^k}{k!} e^{-\lambda T}, \qquad
f_\tau(x) = \lambda e^{-\lambda x} .
```

Цель — оценить вероятность события «более 10 атак за час» двумя способами
(теоретически и по результатам моделирования) и исследовать сходимость
эмпирической оценки.

````julia
using DrWatson
@quickactivate "project"

using Distributions
using Statistics
using Plots
using StatsPlots
using DataFrames
````

## Параметры модели

Параметры собраны в словарь: DrWatson использует его и для запуска
симуляции, и для формирования имени файла с результатами (`savename`).

````julia
params = Dict(
    :λ => 5.0,                 # интенсивность потока, атак в час
    :T => 24.0,                # длительность наблюдения, часов
    :num_hours_for_est => 10000, # объём выборки для оценки вероятности
)

k_threshold = 10               # порог: «более 10 атак за час»
````

## Модель потока событий

Функция возвращает три величины: почасовое число атак, интервалы между
атаками и моменты наступления атак. Число атак за час генерируется напрямую
из распределения Пуассона, а интервалы — из показательного распределения со
средним $1/\lambda$; это два эквивалентных описания одного процесса.

````julia
function simulate_attacks(λ::Float64, T::Float64)
    hourly_counts = rand(Poisson(λ), floor(Int, T))

    intervals = Float64[]
    total_time = 0.0

    # накапливаем интервалы, пока не выйдем за горизонт наблюдения T
    while total_time < T
        τ = rand(Exponential(1 / λ))
        push!(intervals, τ)
        total_time += τ
    end

    # последний интервал вывел нас за пределы T — отбрасываем его
    if total_time > T
        pop!(intervals)
    end

    attack_times = cumsum(intervals)

    return (hourly_counts = hourly_counts,
        intervals = intervals,
        attack_times = attack_times)
end

simulate_attacks(p::Dict) = simulate_attacks(p[:λ], p[:T])
````

## Запуск эксперимента

Помимо самой траектории процесса оцениваются две вероятности события
«более 10 атак за час»: эмпирическая (доля часов в большой выборке) и
теоретическая (через функцию распределения Пуассона).

````julia
function run_simulation(p)
    λ = p[:λ]
    T = p[:T]
    n = p[:num_hours_for_est]

    res = simulate_attacks(λ, T)

    hourly_sample = rand(Poisson(λ), n)

    emp_prob = count(hourly_sample .> k_threshold) / n
    theor_prob = 1 - cdf(Poisson(λ), k_threshold)

    return Dict(
        :hourly_counts => res.hourly_counts,
        :intervals => res.intervals,
        :attack_times => res.attack_times,
        :emp_prob => emp_prob,
        :theor_prob => theor_prob,
    )
end

data = run_simulation(params)

println("Эмпирическая вероятность  = ", data[:emp_prob])
println("Теоретическая вероятность = ", data[:theor_prob])
println("Абсолютное расхождение    = ", abs(data[:emp_prob] - data[:theor_prob]))
````

## Проверка распределений

Строятся четыре графика: гистограмма числа атак в сравнении с законом
Пуассона, накопленное число атак, гистограмма интервалов в сравнении с
показательным законом и QQ-график интервалов.

````julia
hourly_counts = data[:hourly_counts]
intervals = data[:intervals]
attack_times = data[:attack_times]

λ̂ = mean(hourly_counts)   # оценка интенсивности по выборке

p1 = histogram(hourly_counts, normalize = true, bins = 20,
    title = "Распределение числа атак", label = "эмпирическое")
plot!(p1, 0:maximum(hourly_counts), pdf.(Poisson(λ̂), 0:maximum(hourly_counts)),
    label = "Пуассон", lw = 2)

p2 = plot(attack_times, 1:length(attack_times),
    xlabel = "Время", ylabel = "Число атак",
    title = "Накопление атак", label = "")

p3 = histogram(intervals, normalize = true, bins = 20,
    title = "Интервалы между атаками", label = "эмпирическое")
plot!(p3, x -> pdf(Exponential(1 / λ̂), x), 0, maximum(intervals),
    label = "показательное", lw = 2)

p4 = qqplot(Exponential(1 / λ̂), intervals, title = "QQ-график интервалов")

plot(p1, p2, p3, p4, layout = (2, 2), size = (900, 700))
savefig(plotsdir("attack_sim_plots.png"))
````

## Сходимость оценки вероятности

Закон больших чисел утверждает, что эмпирическая частота сходится к
вероятности при росте объёма выборки. Проверяем это напрямую.

````julia
Ns = [10, 50, 100, 500, 1000, 5000, 10000]
estimates = Float64[]

for N in Ns
    sample = rand(Poisson(params[:λ]), N)
    push!(estimates, count(sample .> k_threshold) / N)
end

theoretical = 1 - cdf(Poisson(params[:λ]), k_threshold)

plot(Ns, estimates, marker = :o, xscale = :log10,
    xlabel = "Размер выборки", ylabel = "Вероятность",
    title = "Сходимость оценки", label = "эмпирическая")
hline!([theoretical], ls = :dash, label = "теоретическая", lw = 2)

savefig(plotsdir("convergence.png"))

println(DataFrame(N = Ns, empirical = estimates,
    error = abs.(estimates .- theoretical)))
````

## Вычисление для набора параметров

Согласно заданию модель исследуется на наборе значений интенсивности.
С ростом $\lambda$ вероятность превысить фиксированный порог быстро растёт.

````julia
λ_values = [1.0, 3.0, 5.0, 10.0]
N = 10_000

sweep = DataFrame(λ = Float64[], empirical = Float64[], theoretical = Float64[])

for λ in λ_values
    sample = rand(Poisson(λ), N)
    emp = count(sample .> k_threshold) / N
    theor = 1 - cdf(Poisson(λ), k_threshold)
    push!(sweep, (λ, emp, theor))
end

println(sweep)

plot(sweep.λ, sweep.empirical, marker = :o, lw = 2,
    xlabel = "Интенсивность λ", ylabel = "P(N > 10)",
    title = "Зависимость вероятности от интенсивности",
    label = "эмпирическая")
plot!(sweep.λ, sweep.theoretical, marker = :square, ls = :dash, lw = 2,
    label = "теоретическая")

savefig(plotsdir("parameter_sweep.png"))
````

## Выводы

Эмпирические и теоретические значения согласуются, распределение числа атак
соответствует закону Пуассона, а интервалов — показательному закону. С
увеличением объёма выборки погрешность оценки убывает, что подтверждает
действие закона больших чисел.

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

