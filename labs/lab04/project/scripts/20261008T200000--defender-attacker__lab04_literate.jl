using DrWatson
@quickactivate "project"

include(srcdir("simulation.jl"))

V = [10.0, 5.0]
c_a = 1.0
c_d = 1.0

A, D = build_payoff_matrices(V, c_a, c_d)

println("Матрица Нападающего A:")
display(A)
println("Матрица Защитника D:")
display(D)

eq = mixed_nash_2x2(A, D)
println("Тип равновесия: ", eq.type)
println("Стратегия Нападающего p = ", eq.p)
println("Стратегия Защитника   q = ", eq.q)

res = run_simulation(Dict("V" => V, "c_a" => c_a, "c_d" => c_d))
println("Выигрыш Нападающего UA = ", res["UA"])
println("Выигрыш Защитника   UD = ", res["UD"])

sym = run_simulation(Dict("V" => [10.0, 10.0], "c_a" => 0.0, "c_d" => 0.0))
println("Тип: ", sym["type"], ", p1 = ", sym["p_1"], ", q1 = ", sym["q_1"])
println("UA = ", sym["UA"], ", UD = ", sym["UD"])

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
