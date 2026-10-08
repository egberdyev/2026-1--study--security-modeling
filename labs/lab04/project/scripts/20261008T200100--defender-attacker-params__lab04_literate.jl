using DrWatson
@quickactivate "project"

using Plots, DataFrames, Statistics
include(srcdir("simulation.jl"))

params_list = generate_params()
println("Число вариантов: ", length(params_list))

results = main_simulations()
first(results, 5)

combine(groupby(results, :type), nrow => :count)

filtered = results[(results.c_a .== 1.0) .& (results.c_d .== 1.0), :]
ratio = filtered.V1 ./ filtered.V2
scatter(ratio, filtered.p_1, group = filtered.type,
    xlabel = "V1 / V2", ylabel = "p1 (вероятность атаки на актив 1)",
    title = "Стратегия Нападающего (c_a=1, c_d=1)", legend = :topright)
savefig(plotsdir("p1_vs_ratio.png"))

grp = groupby(filtered, [:V1, :V2])
summ = combine(grp, :UA => mean => :UA_mean)
heatmap(sort(unique(summ.V1)), sort(unique(summ.V2)),
    (x, y) -> summ[(summ.V1 .== x) .& (summ.V2 .== y), :UA_mean][1],
    xlabel = "V1", ylabel = "V2", title = "Средний выигрыш Нападающего")
savefig(plotsdir("heatmap_UA.png"))

cds = 0.0:0.5:6.0
UD = [run_simulation(Dict("V" => [10.0, 5.0], "c_a" => 1.0, "c_d" => cd))["UD"]
      for cd in cds]
plot(cds, UD, marker = :o, lw = 2, label = "",
    xlabel = "c_d (стоимость защиты)", ylabel = "UD",
    title = "Выигрыш Защитника от стоимости защиты")
savefig(plotsdir("UD_vs_cd.png"))

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
