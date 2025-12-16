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
 * @param event          : [MouseEvent]
 * @param fileName       : [str] filename used in files (different from the real filename).
 * @param highlightLine  : [int] a line number to highlight
 * @param language       : [str] language for syntax highlighting (highlight.js)
 */
function showText(event, fileName, highlightLine, language) {
  event.preventDefault();
  const file = files[fileName];
  const textContainer = document.getElementById('text-container');
  const outputElement = document.getElementById("file-information");

  // Decode Base64 content (UTF-8 compatible)
  const binaryString = atob(file.contentBase64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  const content = new TextDecoder('utf-8').decode(bytes);

  // Skip syntax highlighting for markdown files
  let highlightedContent;
  if (language === 'md' || language === 'markdown' || language === 'txt') {
    // For markdown and text files, escape HTML and add basic formatting
    highlightedContent = content
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;')
      // Add color to markdown headings
      .replace(/^(#{1,6})\s+(.+)$/gm, '<span style="color: #0969da; font-weight: bold;">$1 $2</span>');
  } else {
    // For code files, use syntax highlighting
    if (hljs.getLanguage(language)) {
      highlightedContent = hljs.highlight(content, { language }).value;
    } else {
      highlightedContent = hljs.highlightAuto(content).value;
    }
  }

  // Split the highlighted HTML into lines and add highlight-line class to the target line
  const lines = highlightedContent.split('\n');
  const finalText = lines.map((line, index) => {
    return (index === highlightLine)
      ? `<span class="highlight-line">${line}</span>`
      : line;
  }).join('\n');

  textContainer.innerHTML = `<pre><code class="hljs">${finalText}</code></pre>`;

  const highlightedElement = textContainer.querySelector('.highlight-line');
  if (highlightedElement) {
    highlightedElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

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

  if (!table.sortStates) {
    table.sortStates = Array.from(table.querySelectorAll('th')).map(() => false);
  }

  const ascending = !table.sortStates[columnIndex];
  table.sortStates = table.sortStates.map((_, index) => index === columnIndex ? ascending : false);

  const rows = Array.from(table.rows).slice(1);

  rows.sort((a, b) => {
    const cellA = a.cells[columnIndex].innerText.trim();
    const cellB = b.cells[columnIndex].innerText.trim();

    // "REQ" や "@" を除去し、数値部分だけを取り出す
    const extractNumbers = (str) => str
      .replace(/[^\d.]/g, '') // 数字とピリオド以外を削除
      .split('.')             // ピリオドで分割
      .map(num => /^\d+$/.test(num) ? parseInt(num, 10) : NaN) // 数値変換
      .filter(num => !isNaN(num)); // NaN を除外

    const valueA = extractNumbers(cellA);
    const valueB = extractNumbers(cellB);

    // **各要素ごとに比較**
    for (let i = 0; i < Math.max(valueA.length, valueB.length); i++) {
      const numA = valueA[i] || 0; // 足りない桁は 0 として扱う
      const numB = valueB[i] || 0;
      if (numA !== numB) {
        return ascending ? numA - numB : numB - numA;
      }
    }

    return 0;
  });

  rows.forEach(row => table.appendChild(row));

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
