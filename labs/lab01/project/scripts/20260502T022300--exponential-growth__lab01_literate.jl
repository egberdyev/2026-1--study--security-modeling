using DrWatson
@quickactivate "project"

using DifferentialEquations
using Plots
using DataFrames

function exponential_growth!(du, u, p, t)
    α = p              # коэффициент роста передаётся как параметр задачи
    du[1] = α * u[1]   # du/dt = αu
    return nothing
end

u0 = [1.0]         # начальное значение u(0)
α = 0.3            # коэффициент роста
tspan = (0.0, 10.0) # интервал интегрирования

prob = ODEProblem(exponential_growth!, u0, tspan, α)
sol = solve(prob, Tsit5(), saveat = 0.1)

u_exact = u0[1] .* exp.(α .* sol.t)
u_num = first.(sol.u)

max_abs_error = maximum(abs.(u_num .- u_exact))
max_rel_error = maximum(abs.(u_num .- u_exact) ./ u_exact)

println("Максимальная абсолютная погрешность: ", max_abs_error)
println("Максимальная относительная погрешность: ", max_rel_error)

doubling_time = log(2) / α
println("Время удвоения T₂ = ", round(doubling_time, digits = 2))

df = DataFrame(t = sol.t, u_num = u_num, u_exact = u_exact)
println(first(df, 5))

plot(sol.t, u_num,
    label = "численное решение",
    xlabel = "Время t",
    ylabel = "Значение u",
    title = "Экспоненциальный рост (α = $α)",
    lw = 2,
    legend = :topleft)

plot!(sol.t, u_exact, label = "аналитическое решение", ls = :dash, lw = 2)

savefig(plotsdir("exponential_growth_α=$α.png"))

α_values = [0.1, 0.3, 0.5, 1.0]
sweep = DataFrame(α = Float64[], u_final = Float64[], doubling_time = Float64[])

for a in α_values
    p = ODEProblem(exponential_growth!, u0, tspan, a)
    s = solve(p, Tsit5(), saveat = 0.1)
    push!(sweep, (a, last(s.u)[1], log(2) / a))
end

println(sweep)

plt = plot(xlabel = "Время t", ylabel = "Значение u",
    title = "Влияние коэффициента роста", legend = :topleft)

for a in α_values
    p = ODEProblem(exponential_growth!, u0, tspan, a)
    s = solve(p, Tsit5(), saveat = 0.1)
    plot!(plt, s.t, first.(s.u), label = "α = $a", lw = 2)
end

savefig(plt, plotsdir("exponential_growth_parameter_sweep.png"))

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
