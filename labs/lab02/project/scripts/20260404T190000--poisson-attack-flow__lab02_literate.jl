using DrWatson
@quickactivate "project"

using Distributions
using Statistics
using Plots
using StatsPlots
using DataFrames

params = Dict(
    :λ => 5.0,                 # интенсивность потока, атак в час
    :T => 24.0,                # длительность наблюдения, часов
    :num_hours_for_est => 10000, # объём выборки для оценки вероятности
)

k_threshold = 10               # порог: «более 10 атак за час»

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

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
