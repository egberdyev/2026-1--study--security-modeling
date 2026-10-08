# Генерация артефактов из литературного кода (Literate.jl):
# чистый код (scripts/), jupyter notebook (notebooks/), документация Quarto (docs/).
using DrWatson
@quickactivate "project"
using Literate

for name in ["20261008T200000--defender-attacker__lab04_literate.jl",
             "20261008T200100--defender-attacker-params__lab04_literate.jl"]
    src = projectdir("literate", name)
    Literate.script(src, projectdir("scripts"))
    Literate.notebook(src, projectdir("notebooks"); execute = false)
    Literate.markdown(src, projectdir("docs"); flavor = Literate.QuartoFlavor())
end
println("Готово")