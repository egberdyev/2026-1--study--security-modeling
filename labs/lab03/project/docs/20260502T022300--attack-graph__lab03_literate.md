# Моделирование и анализ графов атак

Лабораторная работа № 3. Бердыев Эзиз, НФИмд-01-25.

Файл написан в стиле литературного программирования (Literate.jl): из него
порождаются чистый сценарий, Jupyter-блокнот и документация Quarto.

## Постановка задачи

Граф атак — ориентированный граф, вершины которого соответствуют состояниям
системы (узлам сети), а рёбра — возможным действиям злоумышленника. Такая
модель позволяет формализовать процесс проникновения и оценить, какие узлы
сети критичны для безопасности.

В работе строится случайный граф атак, находятся все пути от точки входа до
цели, вычисляются метрики центральности и оценивается вероятность успешной
атаки.

````julia
using DrWatson
@quickactivate "project"

using Graphs
using LinearAlgebra
using Random
using Plots
using DataFrames
using Statistics

Random.seed!(20260502)   # фиксируем зерно ГСЧ для воспроизводимости
````

## Построение графа атак

Рёбра генерируются случайно с вероятностью `edge_prob`, после чего
добавляются доверительные отношения — заранее известные связи между узлами,
которыми злоумышленник может воспользоваться гарантированно.

````julia
function build_attack_graph(n, edge_prob, vulnerabilities, trust_relations)
    g = SimpleDiGraph(n)

    # случайные рёбра: потенциальные переходы между узлами
    for i = 1:n, j = 1:n
        if i != j && rand() < edge_prob
            add_edge!(g, i, j)
        end
    end

    # доверительные отношения добавляются безусловно
    for (u, v) in trust_relations
        add_edge!(g, u, v)
    end

    return g
end
````

## Поиск всех путей атаки

Используется поиск в глубину. Условие `!(neighbor in path)` не даёт
зациклиться: рассматриваются только простые пути. Число простых путей растёт
экспоненциально с размером графа, поэтому метод применим лишь к небольшим
сетям.

````julia
function find_all_paths(g, source, target)
    paths = []

    function dfs(current, path)
        if current == target
            push!(paths, copy(path))
            return
        end
        for neighbor in outneighbors(g, current)
            if !(neighbor in path)
                push!(path, neighbor)
                dfs(neighbor, path)
                pop!(path)      # возврат на шаг назад (backtracking)
            end
        end
    end

    dfs(source, [source])
    return paths
end
````

## PageRank

Собственная реализация PageRank. Величина $\alpha$ — коэффициент затухания:
с вероятностью $\alpha$ «злоумышленник» переходит по ребру, с вероятностью
$1-\alpha$ начинает заново со случайного узла. Узлы без исходящих рёбер
распределяют свой вес равномерно, иначе он терялся бы.

````julia
function simple_pagerank(g; α = 0.85, max_iter = 100, tol = 1e-6)
    n = nv(g)
    n == 0 && return Float64[]

    pr = fill(1.0 / n, n)

    for _ = 1:max_iter
        pr_new = fill((1 - α) / n, n)
        for i = 1:n
            outdeg = outdegree(g, i)
            if outdeg > 0
                for j in outneighbors(g, i)
                    pr_new[j] += α * pr[i] / outdeg
                end
            else
                for j = 1:n
                    pr_new[j] += α * pr[i] / n   # телепортация
                end
            end
        end
        diff = maximum(abs.(pr_new - pr))
        pr = pr_new
        diff < tol && break                      # достигнута сходимость
    end

    return pr
end
````

## Метрики центральности

Каждая метрика отвечает на свой вопрос: in-degree — сколько атак может
прийти в узел; betweenness — насколько часто узел лежит на путях между
другими узлами; closeness — насколько узел близок ко всей сети; PageRank —
насколько узел важен с учётом важности его соседей.

````julia
function compute_centrality_metrics(g)
    return Dict(
        :in_degree => indegree(g),
        :out_degree => outdegree(g),
        :betweenness => betweenness_centrality(g),
        :closeness => closeness_centrality(g),
        :pagerank => simple_pagerank(g),
    )
end
````

## Веса рёбер по оценкам CVSS

Каждому ребру сопоставляется вероятность успешной эксплуатации уязвимости.
Если для пары узлов оценка не задана, используется значение по умолчанию.

````julia
function assign_edge_weights(g, cvss_scores)
    weights = Dict{Edge,Float64}()
    for e in edges(g)
        weights[e] = get(cvss_scores, (src(e), dst(e)), 0.5)
    end
    return weights
end
````

## Наиболее вероятный путь атаки

Вероятность пути равна произведению вероятностей его рёбер. Логарифмирование
превращает произведение в сумму, а замена знака — задачу максимизации в
задачу минимизации, поэтому применим алгоритм Дейкстры с весами
$-\ln p_{ij}$.

````julia
function most_likely_path(g, source, target, weights)
    n = nv(g)
    distmx = fill(Inf, n, n)

    for e in edges(g)
        distmx[src(e), dst(e)] = -log(weights[e])
    end

    state = dijkstra_shortest_paths(g, source, distmx)
    state.dists[target] == Inf && return Int[], 0.0

    # восстанавливаем путь от цели к источнику по массиву предков
    path = Int[]
    current = target
    while current != source
        push!(path, current)
        current = state.parents[current]
    end
    push!(path, source)
    reverse!(path)

    return path, exp(-state.dists[target])   # обратно к вероятности
end
````

## Параметры эксперимента

````julia
params = Dict(
    :n => 20,             # число узлов сети
    :edge_prob => 0.2,    # вероятность появления ребра
    :source => 1,         # точка входа злоумышленника
    :target => 20,        # цель атаки
    :cvss_scores => Dict((1, 3) => 0.9, (2, 5) => 0.7,
        (3, 8) => 0.8, (5, 20) => 0.95),
    :trust_relations => [(4, 6), (6, 10), (10, 15)],
)
````

## Запуск эксперимента

````julia
g = build_attack_graph(params[:n], params[:edge_prob],
    params[:cvss_scores], params[:trust_relations])

paths = find_all_paths(g, params[:source], params[:target])
metrics = compute_centrality_metrics(g)
weights = assign_edge_weights(g, params[:cvss_scores])
likely_path, probability = most_likely_path(g, params[:source],
    params[:target], weights)

println("Число рёбер графа: ", ne(g))
println("Количество путей атаки: ", length(paths))
println("Наиболее вероятный путь: ", likely_path)
println("Вероятность успеха: ", probability)
````

## Критические узлы

Узлы упорядочиваются по PageRank: первые в списке представляют наибольший
интерес и для злоумышленника, и для защиты.

````julia
ranking = DataFrame(
    node = 1:nv(g),
    in_degree = metrics[:in_degree],
    betweenness = metrics[:betweenness],
    pagerank = metrics[:pagerank],
)

sort!(ranking, :pagerank, rev = true)
println(first(ranking, 5))
````

## Исследование масштабируемости

Проверяется, как число простых путей и время их поиска зависят от размера
сети. Отдельный случайный граф — плохая основа для вывода: в нём пути из
вершины 1 в вершину $n$ могут вообще отсутствовать. Поэтому для каждого
размера результат усредняется по `n_trials` независимым реализациям графа.

````julia
sizes = [6, 8, 10, 12, 14, 16]
n_trials = 20

scal = DataFrame(n = Int[], mean_paths = Float64[], mean_seconds = Float64[])

for n in sizes
    paths_count = Int[]
    times = Float64[]
    for _ = 1:n_trials
        gg = build_attack_graph(n, 0.3, Dict(), Tuple{Int,Int}[])
        t = @elapsed p = find_all_paths(gg, 1, n)
        push!(paths_count, length(p))
        push!(times, t)
    end
    push!(scal, (n, mean(paths_count), mean(times)))
end

println(scal)

# к среднему добавляется единица, чтобы логарифмическая шкала оставалась
# корректной при нулевом среднем числе путей
plot(scal.n, scal.mean_paths .+ 1, marker = :o, lw = 2, yscale = :log10,
    xlabel = "Число узлов сети", ylabel = "Среднее число путей атаки + 1",
    title = "Масштабируемость поиска путей (усреднение по $n_trials графам)",
    label = "")

savefig(plotsdir("scalability.png"))
````

## Вычисление для набора параметров

Согласно заданию модель исследуется на наборе значений плотности рёбер.
Чем плотнее сеть, тем больше путей атаки и тем сложнее её защищать.

````julia
probs = [0.1, 0.2, 0.3, 0.4, 0.5]
sweep = DataFrame(edge_prob = Float64[], mean_edges = Float64[],
    mean_paths = Float64[], reachable = Float64[])

for p in probs
    edges_count = Int[]
    paths_count = Int[]
    for _ = 1:n_trials
        gg = build_attack_graph(12, p, Dict(), Tuple{Int,Int}[])
        push!(edges_count, ne(gg))
        push!(paths_count, length(find_all_paths(gg, 1, 12)))
    end
    # доля графов, в которых цель вообще достижима из точки входа
    reachable = count(paths_count .> 0) / n_trials
    push!(sweep, (p, mean(edges_count), mean(paths_count), reachable))
end

println(sweep)

plot(sweep.edge_prob, sweep.mean_paths .+ 1, marker = :o, lw = 2,
    yscale = :log10, xlabel = "Вероятность ребра",
    ylabel = "Среднее число путей атаки + 1",
    title = "Влияние плотности сети", label = "число путей")

savefig(plotsdir("parameter_sweep.png"))

# отдельно — доля сетей, в которых цель достижима
plot(sweep.edge_prob, sweep.reachable, marker = :square, lw = 2,
    xlabel = "Вероятность ребра", ylabel = "Доля достижимых целей",
    title = "Достижимость цели атаки", label = "", ylims = (0, 1.05))

savefig(plotsdir("reachability.png"))
````

## Выводы

Число путей атаки растёт экспоненциально как с размером сети, так и с её
плотностью. Поэтому полный перебор путей применим только к небольшим
фрагментам инфраструктуры, а для реальных сетей необходимы метрики
центральности, позволяющие выделить критические узлы без построения всех
путей.

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

