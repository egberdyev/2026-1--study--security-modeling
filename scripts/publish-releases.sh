#!/usr/bin/env bash
#
# Публикация релизов на GitHub с приложенными файлами.
#
# Требуется авторизация gh под учётной записью, имеющей право записи в
# репозиторий:
#
#   gh auth login --hostname github.com --git-protocol ssh --web
#
# Использование:
#   ./scripts/publish-releases.sh            # все три лабораторные работы
#   ./scripts/publish-releases.sh 01         # только первую

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="egberdyev/2026-1--study--security-modeling"

declare -a TITLES
TITLES[1]="Лабораторная работа № 1. Подготовка стенда. Модель экспоненциального роста"
TITLES[2]="Лабораторная работа № 2. Основы вероятностного моделирования угроз"
TITLES[3]="Лабораторная работа № 3. Моделирование и анализ графов атак"

publish_one () {
    local nn="$1"
    local n="${nn#0}"
    local lab="lab${nn}"
    local tag="v${n}.0.0"
    local dir="${ROOT}/release/${lab}"

    if [ ! -d "${dir}" ]; then
        echo "!! нет каталога ${dir}; сначала запустите ./scripts/make-release.sh ${nn}" >&2
        return 1
    fi

    local notes
    notes="$(printf '%s\n\n%s\n' \
        "${TITLES[$n]}" \
        "Файлы релиза: отчёт (md, docx, pdf), презентация (md, pdf, html, pptx) и архив с исходными материалами markdown.")"

    if gh release view "${tag}" --repo "${REPO}" >/dev/null 2>&1; then
        echo "== ${tag} уже существует, обновляю файлы"
        gh release upload "${tag}" "${dir}"/* --repo "${REPO}" --clobber
    else
        echo "== создаю релиз ${tag}"
        gh release create "${tag}" "${dir}"/* \
            --repo "${REPO}" \
            --title "${tag} — ${TITLES[$n]}" \
            --notes "${notes}"
    fi
}

if [ "$#" -eq 0 ]; then
    set -- 01 02 03
fi

for nn in "$@"; do
    publish_one "${nn}"
done
