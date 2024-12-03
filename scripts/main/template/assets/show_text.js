const files = {
  // js_contents

  /*
   *  @TRACE_TARGET_FILENAME@: {
   *    path: "@TRACE_TARGET_PATH@,
   *    content: `
   *  @TRACE_TARGET_CONTENTS@
   *  `,
   *  },
   */

};

/**
 * @brief Show text data in the right side of the output html (text-container).
 * @param event          : [MoueseEvent]
 * @param fileName       : [str] filename used in files (different from the real filename).
 * @param highlightLine  : [int] a line number to highlight
 * @param language       : [str] language for syntax highlighting (highlight.js)
 */
function showText(event, fileName, highlightLine, language) {
  event.preventDefault();
  const file = files[fileName];
  const textContainer = document.getElementById('text-container');
  const lines = file.content.split('\n');
  const highlightedText = lines.map((line, index) => {
    let encodedLine;

    if (hljs.getLanguage(language)) {
      encodedLine = hljs.highlight(line, { language }).value;
    }
    else {
      encodedLine = hljs.highlightAuto(line).value;
    }

    return (index === highlightLine)
      ? `<span class="highlight-line">${encodedLine}</span>`
      : encodedLine;
  }).join('\n');

  textContainer.innerHTML = `<pre><code class="hljs">${highlightedText}</code></pre>`;

  const highlightedElement = textContainer.querySelector('.highlight-line');
  if (highlightedElement) {
    highlightedElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  const outputElement = document.getElementById("file-information");
  outputElement.textContent = file.path;
}

/**
 * @brief Hide display if it is the same tag as the tag one line above
 */
function hideSameText() {
  const table = document.getElementById("tag-table");

  /* reset hidden text */
  const rows = table.rows;
  const tags = table.querySelectorAll('a');
    tags.forEach(tag => {
    tag.classList.remove("hidden-text");
  });

  /* check each row */
  for (let i = 1; i < rows.length; i++) {
    const cells = rows[i].cells;
    for (let j = 0; j < cells.length; j++) {
      const currentCellText = cells[j].innerText.trim();
      const previousCellText = rows[i - 1].cells[j].innerText.trim();
      if (currentCellText === previousCellText) {
        const tag = cells[j].querySelector('a');
        if (tag) {
          tag.classList.add("hidden-text");
        }
      }
    }
  }
}

/**
 * @brief Sort the table based by a clicked column
 * @param columnIndex : [int] selected column
 */
function sortTable(columnIndex) {
  const table = document.getElementById("tag-table");

  /*
   * Set a data attribute in the table to maintain
   * the sort state of each column (first time only)
   */
  if (!table.sortStates) {
    /* Initial value : ascending = false */
    table.sortStates = Array.from(table.querySelectorAll('th')).map(() => false);
  }

  /* Get and switch the current column sorting state */
  const ascending = !table.sortStates[columnIndex];

  /* Reset other column sorting state */
  table.sortStates = table.sortStates.map((_, index) => index === columnIndex ? ascending : false);

  /* Sort the table */
  const rows = Array.from(table.rows).slice(1);
  rows.sort((a, b) => {
    const cellA = a.cells[columnIndex].innerText.trim();
    const cellB = b.cells[columnIndex].innerText.trim();

    let valueA = isNaN(cellA) ? cellA : parseFloat(cellA);
    let valueB = isNaN(cellB) ? cellB : parseFloat(cellB);

    if (valueA < valueB) return ascending ? -1 : 1;
    if (valueA > valueB) return ascending ? 1 : -1;
    return 0;
  });

  rows.forEach(row => table.appendChild(row));

  /* Refresh headers */
  const headers = table.querySelectorAll('th');
  headers.forEach((header, index) => {
    const sortIndicator = header.querySelector('.sort-indicator');
    if (index === columnIndex) {
      if (!sortIndicator) {
        const span = document.createElement('span');
        span.classList.add('sort-indicator');
        header.appendChild(span);
      }
      header.querySelector('.sort-indicator').textContent = ascending ? '🔼' : '🔽';
    }
    else if (sortIndicator) {
      header.removeChild(sortIndicator);
    }
  });
  hideSameText();
}

/**
 * @brief Show the tooltip
 * @param event          : [MoueseEvent]
 * @param fileName       : [str] filename used in files (different from the real filename).
 */
function showTooltip(event, fileName) {
    const tooltip = document.getElementById('tooltip');

    tooltip.textContent = files[fileName].path;
    tooltip.style.left = `${event.pageX + 10}px`;
    tooltip.style.top = `${event.pageY + 10}px`;
    tooltip.style.opacity = 0.9;
}

/**
 * @brief Hide the tooltip
 */
function hideTooltip() {
    const tooltip = document.getElementById('tooltip');
    tooltip.style.opacity = 0;
}

window.onload = function() {
  hideSameText();
};
