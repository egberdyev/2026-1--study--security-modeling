# Модель конфликта «Защитник–Нападающий» (лабораторная работа № 4).
# Антагонистическая игра двух игроков: Нападающий выбирает актив для атаки,
# Защитник — актив для усиленной защиты. Ищем равновесие Нэша.

using LinearAlgebra
using DataFrames, CSV
using DrWatson

# Платёжные матрицы: строка i — какой актив атакуют, столбец j — какой защищают.
# A — выигрыши Нападающего, D — выигрыши Защитника.
function build_payoff_matrices(V::Vector{Float64}, c_a::Float64, c_d::Float64)
    n = length(V)
    A = zeros(n, n)  # Attacker
    D = zeros(n, n)  # Defender
    for i = 1:n, j = 1:n
        if i != j
            # атака не встретила защиты: Нападающий получает ценность актива
            A[i, j] = V[i] - c_a
            D[i, j] = -V[i] - c_d
        else
            # атака попала на защищённый актив и отражена
            A[i, j] = -c_a
            D[i, j] = -c_d
        end
    end
    return A, D
end

# Равновесие Нэша для игры 2x2: сначала ищем чистое, иначе — смешанное.
function mixed_nash_2x2(A::Matrix{Float64}, D::Matrix{Float64})
    # Чистое равновесие: ни одному игроку невыгодно менять свой выбор.
    # 3-i — «другая» стратегия (для i = 1 это 2, для i = 2 это 1).
    for i = 1:2, j = 1:2
        if A[i, j] >= A[3-i, j] && D[i, j] >= D[i, 3-j]
            p = zeros(2); p[i] = 1.0
            q = zeros(2); q[j] = 1.0
            return (p = p, q = q, type = "pure")
        end
    end

    # Смешанное равновесие из условия безразличия:
    # Защитник подбирает q так, чтобы Нападающему было всё равно, что атаковать.
    denomA = (A[1, 1] - A[2, 1]) - (A[1, 2] - A[2, 2])
    if abs(denomA) > 1e-10
        q1 = clamp((A[2, 2] - A[1, 2]) / denomA, 0.0, 1.0)
    else
        q1 = 0.5
    end
    q = [q1, 1 - q1]

    # Нападающий подбирает p так, чтобы Защитнику было всё равно, что защищать.
    denomD = (D[1, 1] - D[1, 2]) - (D[2, 1] - D[2, 2])
    if abs(denomD) > 1e-10
        p1 = clamp((D[2, 2] - D[2, 1]) / denomD, 0.0, 1.0)
    else
        p1 = 0.5
    end
    p = [p1, 1 - p1]

    return (p = p, q = q, type = "mixed")
end

# Один эксперимент: матрицы -> равновесие -> ожидаемые выигрыши.
function run_simulation(params::Dict)
    V = params["V"]
    c_a = params["c_a"]
    c_d = params["c_d"]
    A, D = build_payoff_matrices(V, c_a, c_d)
    eq = mixed_nash_2x2(A, D)

    if eq.type == "pure"
        i = argmax(eq.p)
        j = argmax(eq.q)
        UA = A[i, j]
        UD = D[i, j]
    else
        # ожидаемый выигрыш U = p' * M * q
        UA = eq.p' * A * eq.q
        UD = eq.p' * D * eq.q
    end

    return Dict(
        "p_1" => eq.p[1], "p_2" => eq.p[2],
        "q_1" => eq.q[1], "q_2" => eq.q[2],
        "type" => eq.type,
        "UA" => UA, "UD" => UD,
        "V1" => V[1], "V2" => V[2],
        "c_a" => c_a, "c_d" => c_d,
    )
end

# Сетка параметров: 3 x 3 ценности и 3 x 3 затраты = 81 вариант.
function generate_params()
    dicts = []
    for v1 in [5.0, 10.0, 15.0], v2 in [5.0, 10.0, 15.0]
        for c_a in [0.0, 1.0, 3.0], c_d in [0.0, 1.0, 3.0]
            push!(dicts, Dict("V" => [v1, v2], "c_a" => c_a, "c_d" => c_d))
        end
    end
    return dicts
end

# Расчёт всех вариантов и сохранение в data/sims/results.csv.
function main_simulations()
    params_list = generate_params()
    rows = []
    for p in params_list
        push!(rows, run_simulation(p))
    end
    results = DataFrame(rows)
    mkpath(datadir("sims"))
    CSV.write(datadir("sims", "results.csv"), results)
    return results
end

# Загрузка сохранённых результатов.
function load_results()
    path = datadir("sims", "results.csv")
    if isfile(path)
        return CSV.read(path, DataFrame)
    else
        error("Файл с результатами не найден. Сначала выполните main_simulations().")
    end
end