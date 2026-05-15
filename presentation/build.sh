#!/usr/bin/env bash
# Сборка производных форматов реферата из report.md (требуется pandoc + LaTeX для PDF)
set -euo pipefail
cd "$(dirname "$0")"

PANDOC_OPTS=(
  --from=markdown
  --citeproc
  --bibliography=references.bib
  --metadata=link-citations:true
  --metadata=lang:ru-RU
  --metadata=figPrefix:"Рисунок"
  --metadata=tblPrefix:"Таблица"
)

echo "→ report.docx"
pandoc report.md "${PANDOC_OPTS[@]}" -o report.docx

echo "→ report.pdf"
pandoc report.md "${PANDOC_OPTS[@]}" -o report.pdf --pdf-engine=xelatex -V mainfont="Times New Roman" -V geometry:margin=2.5cm

echo "→ presentation.pptx (Marp)"
marp presentation.md --pptx -o presentation.pptx

echo "Готово."
