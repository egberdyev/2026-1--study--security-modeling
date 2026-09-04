#!/usr/bin/env bash
#
# Сборка файлов релиза для лабораторной работы.
#
# Собирает в каталог release/lab<NN>/ полный комплект файлов, требуемый
# чек-листом сдачи:
#
#   * отчёт в markdown, docx и pdf;
#   * презентация в markdown, pdf, html и pptx;
#   * архив с исходными материалами markdown (qmd, изображения, библиография).
#
# Использование:
#   ./scripts/make-release.sh 01
#   ./scripts/make-release.sh 01 02 03
#
# Файлы отчёта и презентации должны быть предварительно собраны:
#   cd labs/lab01/report && quarto render
#   cd labs/lab01/presentation && quarto render

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

build_one () {
    local nn="$1"
    local lab="lab${nn}"
    local base="security-modeling-${lab}"
    local labdir="${ROOT}/labs/${lab}"
    local outdir="${ROOT}/release/${lab}"

    if [ ! -d "${labdir}" ]; then
        echo "!! каталог ${labdir} не найден, пропускаю" >&2
        return 1
    fi

    rm -rf "${outdir}"
    mkdir -p "${outdir}"

    local missing=0

    copy_if () {
        local src="$1"
        if [ -f "${src}" ]; then
            cp "${src}" "${outdir}/"
        else
            echo "!! отсутствует: ${src}" >&2
            missing=1
        fi
    }

    # Отчёт: markdown, docx, pdf
    copy_if "${labdir}/report/_output/${base}-report.md"
    copy_if "${labdir}/report/_output/${base}-report.docx"
    copy_if "${labdir}/report/_output/${base}-report.pdf"

    # Презентация: markdown, pdf, html, pptx
    copy_if "${labdir}/presentation/_output/${base}-presentation.md"
    copy_if "${labdir}/presentation/_output/${base}-presentation.pdf"
    copy_if "${labdir}/presentation/_output/${base}-presentation.html"
    copy_if "${labdir}/presentation/_output/${base}-presentation.pptx"

    # Архив с исходными материалами markdown
    local tmp
    tmp="$(mktemp -d)"
    mkdir -p "${tmp}/${base}-sources"

    for d in report presentation; do
        mkdir -p "${tmp}/${base}-sources/${d}"
        # исходники markdown, конфигурация сборки, библиография, иллюстрации
        for item in *.qmd _quarto.yml bib image _resources; do
            if [ -e "${labdir}/${d}/${item}" ]; then
                cp -R "${labdir}/${d}/${item}" "${tmp}/${base}-sources/${d}/"
            fi
        done
    done

    # литературные исходники и сгенерированная из них документация
    if [ -d "${labdir}/project/literate" ]; then
        cp -R "${labdir}/project/literate" "${tmp}/${base}-sources/"
    fi
    if [ -d "${labdir}/project/docs" ]; then
        cp -R "${labdir}/project/docs" "${tmp}/${base}-sources/"
    fi
    if [ -d "${labdir}/project/notebooks" ]; then
        cp -R "${labdir}/project/notebooks" "${tmp}/${base}-sources/"
    fi

    (cd "${tmp}" && zip -qr "${outdir}/${base}-sources.zip" "${base}-sources")
    rm -rf "${tmp}"

    # GitVerse не принимает .html как файл релиза («Invalid file format»),
    # поэтому презентация в html дополнительно кладётся в архив.
    if [ -f "${outdir}/${base}-presentation.html" ]; then
        (cd "${outdir}" && zip -q "${base}-presentation-html.zip" \
            "${base}-presentation.html")
    fi

    echo "== ${lab}: файлы релиза в ${outdir}"
    ls -1 "${outdir}"

    if [ "${missing}" -ne 0 ]; then
        echo "!! ${lab}: комплект неполный, соберите документы через quarto render" >&2
        return 1
    fi
}

if [ "$#" -eq 0 ]; then
    set -- 01 02 03
fi

status=0
for nn in "$@"; do
    build_one "${nn}" || status=1
done

exit "${status}"
