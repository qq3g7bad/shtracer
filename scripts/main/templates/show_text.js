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

// Global tag lookup cache (built from traceabilityData)
let tagLocationCache = null;
let childTagCache = null;

/**
 * Build tag location cache from trace Tags
 */
function buildTagLocationCache() {
	if (tagLocationCache) return;
	if (typeof traceabilityData === 'undefined') return;

	tagLocationCache = {};
	(traceabilityData.trace_tags || []).forEach(tag => {
		const file = traceabilityData.files[tag.file_id];
		if (!file) return;

		const baseName = file.file.replace(/.*\//, '').replace(/\./g, '_');
		const fileName = 'Target_' + baseName;
		const ext = file.file.match(/\.([^.]+)$/)?.[1] || 'txt';
		const layer = traceabilityData.layers[tag.layer_id];

		tagLocationCache[tag.id] = {
			fileName: fileName,
			line: tag.line,
			ext: ext,
			description: tag.description || '',
			layerName: layer ? layer.name : 'Unknown',
			fromTags: tag.from_tags || []
		};
	});
}

/**
 * Build child tag cache (reverse lookup)
 */
function buildChildTagCache() {
	if (childTagCache) return;
	if (typeof traceabilityData === 'undefined') return;

	childTagCache = {};

	// Initialize empty arrays for all tags
	(traceabilityData.trace_tags || []).forEach(tag => {
		childTagCache[tag.id] = [];
	});

	// Build reverse lookup: for each tag, record it as a child of its parent tags
	(traceabilityData.trace_tags || []).forEach(tag => {
		if (tag.from_tags && tag.from_tags.length > 0) {
			tag.from_tags.forEach(parentTag => {
				if (parentTag !== 'NONE' && childTagCache[parentTag]) {
					childTagCache[parentTag].push(tag.id);
				}
			});
		}
	});
}

/**
 * Find tag location by tag ID
 */
function findTagLocation(tagId) {
	if (!tagLocationCache) buildTagLocationCache();
	return tagLocationCache[tagId] || null;
}

/**
 * Find child tags for a given tag ID
 */
function findChildTags(tagId) {
	if (!childTagCache) buildChildTagCache();
	return childTagCache[tagId] || [];
}

/**
 * Navigate to a tag by ID
 */
function navigateToTag(event, tagId) {
	event.preventDefault();
	const tagInfo = findTagLocation(tagId);
	if (tagInfo) {
		showText(event, tagInfo.fileName, tagInfo.line, tagInfo.ext,
				 tagId, tagInfo.description, tagInfo.layerName, tagInfo.fromTags.join(','));
	}
}

/**
 * @brief Show text data in the right side of the output html (text-container).
 * @param event          : [MouseEvent]
 * @param fileName       : [str] filename used in files (different from the real filename).
 * @param highlightLine  : [int] a line number to highlight
 * @param language       : [str] language for syntax highlighting (highlight.js)
 * @param tagId          : [str] optional tag ID being viewed
 * @param tagDescription : [str] optional tag description
 * @param layerName      : [str] optional layer name
 * @param fromTagsStr    : [str] optional comma-separated parent tag IDs
 */
function showText(event, fileName, highlightLine, language, tagId, tagDescription, layerName, fromTagsStr) {
	event.preventDefault();
	const file = files[fileName];
	const textContainer = document.getElementById('text-container');
	const tagInfoPanel = document.getElementById('tag-info-panel');

    const content = file.content;

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
	// Note: highlightLine is 1-based (human-readable line number), but array index is 0-based
	const lines = highlightedContent.split('\n');
	const finalText = lines.map((line, index) => {
		const lineClass = (index === highlightLine - 1) ? ' class="highlight-line"' : '';
		return `<div${lineClass}>${line || '&#8203;'}</div>`;
	}).join('');

	textContainer.innerHTML = `<pre><code class="hljs">${finalText}</code></pre>`;

	const highlightedElement = textContainer.querySelector('.highlight-line');
	if (highlightedElement) {
		highlightedElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
	}

	// Populate tag info panel if tag metadata is provided
	if (tagId && tagInfoPanel) {
		// Build parent tags HTML
		let parentTagsHtml = '';
		const fromTags = fromTagsStr ? fromTagsStr.split(',').filter(t => t && t !== 'NONE') : [];
		if (fromTags.length > 0) {
			parentTagsHtml = fromTags.map(tag => {
				const parentInfo = findTagLocation(tag);
				if (!parentInfo) return `<span class="tag-link-missing">${escapeHtml(tag)}</span>`;
				return `<a href="#" class="tag-link" onclick="navigateToTag(event, '${escapeHtml(tag)}')">${escapeHtml(tag)}</a>`;
			}).join(', ');
		} else {
			parentTagsHtml = '<span class="no-parent">None (root)</span>';
		}

		// Build child tags HTML (reverse lookup)
		const childTags = findChildTags(tagId);
		let childTagsHtml = '';
		if (childTags && childTags.length > 0) {
			childTagsHtml = childTags.map(tag => {
				return `<a href="#" class="tag-link" onclick="navigateToTag(event, '${escapeHtml(tag)}')">${escapeHtml(tag)}</a>`;
			}).join(', ');
		} else {
			childTagsHtml = '<span class="no-child">None (leaf)</span>';
		}

		tagInfoPanel.innerHTML = `
			<div class="tag-info-header">
				<span class="tag-id">${escapeHtml(tagId)}</span>
				<span class="tag-layer">${escapeHtml(layerName || '')}</span>
			</div>
			<div class="tag-description">${escapeHtml(tagDescription || '(no description)')}</div>
			<div class="tag-parent">
				<span class="label">⬆ Parent:</span> ${parentTagsHtml}
			</div>
			<div class="tag-children">
				<span class="label">⬇ Children:</span> ${childTagsHtml}
			</div>
			<div class="tag-file-location">
				<span class="label">📄 Location:</span> ${escapeHtml(file.path)}:${highlightLine}
			</div>
		`;
		tagInfoPanel.style.display = 'block';
	} else if (tagInfoPanel) {
		tagInfoPanel.style.display = 'none';
	}
}

/**
 * Escape HTML characters
 */
function escapeHtml(text) {
	const div = document.createElement('div');
	div.textContent = text;
	return div.innerHTML;
}

/**
 * @brief Hide display if it is the same tag as the tag one line above
 */
function hideSameText() {
	const table = document.getElementById("tag-table");
	if (!table) return; // Exit if table doesn't exist yet

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
 * @param event : [MouseEvent] click event (used to find the table)
 * @param columnIndex : [int] selected column
 */
function sortTable(event, columnIndex) {
	// Find the table element from the clicked link
	const table = event.target.closest('table');
	if (!table) return;

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
	// Initialize tag location cache
	if (typeof traceabilityData !== 'undefined') {
		buildTagLocationCache();
		buildChildTagCache();
	}
};
