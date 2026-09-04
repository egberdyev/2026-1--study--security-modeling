# Генерация артефактов из литературного исходника (Literate.jl).
#
#   tangle -> исполняемый сценарий  (scripts/)
#   weave  -> Jupyter-блокнот       (notebooks/)
#   weave  -> документация Quarto   (docs/)
#
# Запуск: julia --project=. scripts/make_literate.jl

using DrWatson
@quickactivate "project"

using Literate

src = projectdir("literate", "20260502T022300--exponential-growth__lab01_literate.jl")

Literate.script(src,   projectdir("scripts"))               # чистый код
Literate.notebook(src, projectdir("notebooks"); execute=false) # jupyter notebook
Literate.markdown(src, projectdir("docs"); documenter=false) # документация Quarto

println("Артефакты сгенерированы из ", basename(src))
