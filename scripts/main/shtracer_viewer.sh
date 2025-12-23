#!/bin/sh

# This script can be executed (JSON -> single HTML to stdout) or sourced (unit tests).

_viewer_emit_show_text_js_template() {
	cat <<'EOF'
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
EOF
}

_viewer_emit_traceability_diagrams_js() {
	cat <<'EOF'
// traceability_diagrams.js - Traceability visualizations for shtracer
// Renders the interactive full Sankey diagram and the requirements-centric Type view.

document.addEventListener('DOMContentLoaded', function() {
    // Use embedded JSON data instead of fetching
    if (typeof traceabilityData !== 'undefined') {
        renderSankey(traceabilityData);
    } else {
        document.getElementById('sankey-diagram-full').innerHTML =
            '<p style="color: red; text-align: center; padding: 20px;">' +
            'Error: Traceability data not found. Please regenerate the HTML output.</p>';
        document.getElementById('sankey-diagram-type').innerHTML =
            '<p style="color: red; text-align: center; padding: 20px;">' +
            'Error: Traceability data not found. Please regenerate the HTML output.</p>';
    }
});

function traceTypeFromTraceTarget(traceTarget) {
    if (!traceTarget) return 'Unknown';
    const parts = String(traceTarget).split(':');
    return parts[parts.length - 1].trim() || 'Unknown';
}

function traceTypeColor(type) {
    switch (type) {
        case 'Requirement': return '#e74c3c';
        case 'Architecture': return '#3498db';
        case 'Implementation': return '#2ecc71';
        case 'Unit test': return '#f39c12';
        case 'Integration test': return '#9b59b6';
        default: return '#7f8c8d';
    }
}

function renderLegend(containerId) {
    const el = document.getElementById(containerId);
    if (!el) return;

    const legendData = [
        {type: 'Requirement', color: traceTypeColor('Requirement')},
        {type: 'Architecture', color: traceTypeColor('Architecture')},
        {type: 'Implementation', color: traceTypeColor('Implementation')},
        {type: 'Unit test', color: traceTypeColor('Unit test')},
        {type: 'Integration test', color: traceTypeColor('Integration test')},
        {type: 'Unknown', color: traceTypeColor('Unknown')}
    ];

    el.innerHTML = legendData.map(d =>
        `<span class="legend-item"><span class="legend-swatch" style="background:${d.color}"></span><span>${d.type}</span></span>`
    ).join('');
}

function annotateTraceTargets(data) {
    const fileToTypes = new Map();
    (data.nodes || []).forEach(n => {
        if (!n || !n.file) return;
        const base = String(n.file).split('/').pop();
        const t = traceTypeFromTraceTarget(n.trace_target);
        if (!fileToTypes.has(base)) fileToTypes.set(base, new Set());
        fileToTypes.get(base).add(t);
    });

    const anchors = document.querySelectorAll('#trace-targets a');
    anchors.forEach(a => {
        if (!a || !a.textContent) return;
        const name = a.textContent.trim();
        const types = fileToTypes.has(name) ? Array.from(fileToTypes.get(name)) : [];
        const cleaned = types.filter(t => t && t !== 'Unknown').sort();
        const finalTypes = cleaned.length ? cleaned : ['Unknown'];

        if (!a.parentElement) return;
        if (a.parentElement.querySelector('.trace-target-type')) return;

        finalTypes.forEach(t => {
            const span = document.createElement('span');
            span.className = 'trace-target-type';
            span.textContent = t;
            span.style.backgroundColor = traceTypeColor(t);
            span.style.borderColor = traceTypeColor(t);
            a.insertAdjacentElement('afterend', span);
        });
    });
}

function annotateMatrixBadges() {
    const badges = document.querySelectorAll('.matrix-tag-badge[data-type]');
    badges.forEach(span => {
        if (!span) return;
        const t = span.getAttribute('data-type') || 'Unknown';
        const c = traceTypeColor(t);
        span.style.backgroundColor = c;
        span.style.borderColor = c;
    });
}

function renderSummary(data) {
    const el = document.getElementById('trace-summary');
    if (!el) return;

    const nodes = Array.isArray(data.nodes) ? data.nodes : [];
    const links = Array.isArray(data.direct_links) ? data.direct_links : (Array.isArray(data.links) ? data.links : []);

    function escapeHtml(s) {
        return String(s)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function typeBadge(type) {
        const c = traceTypeColor(type);
        return `<span class="summary-type-badge" style="background-color:${c};border-color:${c};">${escapeHtml(type)}</span>`;
    }

    function escapeJsSingle(s) {
        return String(s)
            .replace(/\\/g, '\\\\')
            .replace(/'/g, "\\'");
    }

    function baseName(p) {
        const s = String(p || '');
        const parts = s.split('/');
        return parts.length ? parts[parts.length - 1] : s;
    }

    function fileIdFromRawName(rawName) {
        return 'Target_' + String(rawName).replace(/\./g, '_');
    }

    function fileExtFromRawName(rawName) {
        const s = String(rawName || '');
        const m = s.match(/\.([^.]+)$/);
        return m ? m[1] : 'sh';
    }

    function nodeIdFromLinkEnd(end) {
        if (typeof end === 'string') return end;
        if (typeof end === 'number') {
            const n = nodes[end];
            return n && typeof n.id === 'string' ? n.id : null;
        }
        if (end && typeof end === 'object') {
            if (typeof end.id === 'string') return end.id;
            if (typeof end.name === 'string') return end.name;
        }
        return null;
    }

    // Match the Type diagram's link label definition/rounding:
    // - Build undirected adjacency from direct links
    // - Compute upstream/downstream projections independently
    // - Split node mass equally across distinct target layers on each side
    // - Format like the diagram: >=10% as integer, else 1 decimal; <0.5% as <1%
    const dims = ['Requirement', 'Architecture', 'Implementation', 'Unit test', 'Integration test'];
    const dimOrder = new Map(dims.map((d, i) => [d, i]));
    const isDim = (d) => dimOrder.has(d);

    function formatPct(value, total) {
        if (!total) return '';
        const p = (value / total) * 100;
        if (p > 0 && p < 0.5) return '<1%';
        const s = (p >= 10 ? p.toFixed(0) : p.toFixed(1));
        return s.replace(/\.0$/, '') + '%';
    }

    const idxById = new Map();
    nodes.forEach((n, i) => {
        if (n && typeof n.id === 'string') idxById.set(n.id, i);
    });

    const typeOf = nodes.map(n => traceTypeFromTraceTarget(n && n.trace_target));
    const idxByDim = {};
    dims.forEach(d => { idxByDim[d] = []; });
    typeOf.forEach((t, i) => {
        if (isDim(t)) idxByDim[t].push(i);
    });

    const adj = Array.from({ length: nodes.length }, () => []);
    links.forEach(l => {
        const aId = nodeIdFromLinkEnd(l.source);
        const bId = nodeIdFromLinkEnd(l.target);
        if (!aId || !bId) return;
        const a = idxById.get(aId);
        const b = idxById.get(bId);
        if (typeof a !== 'number' || typeof b !== 'number') return;
        adj[a].push(b);
        adj[b].push(a);
    });

    const N = {};
    const accUp = {};   // accUp[src][tgt]
    const accDown = {}; // accDown[src][tgt]
    dims.forEach(src => {
        N[src] = idxByDim[src].length;
        accUp[src] = {};
        accDown[src] = {};
        dims.forEach(tgt => {
            if (tgt === src) return;
            accUp[src][tgt] = 0;
            accDown[src][tgt] = 0;
        });
    });

    dims.forEach(src => {
        const srcOrder = dimOrder.get(src);
        idxByDim[src].forEach(i => {
            const upSet = new Set();
            const downSet = new Set();
            (adj[i] || []).forEach(j => {
                const t = typeOf[j];
                if (!isDim(t) || t === src) return;
                const o = dimOrder.get(t);
                if (o < srcOrder) upSet.add(t);
                else if (o > srcOrder) downSet.add(t);
            });

            if (upSet.size) {
                const w = 1 / upSet.size;
                upSet.forEach(tgt => { accUp[src][tgt] += w; });
            }
            if (downSet.size) {
                const w = 1 / downSet.size;
                downSet.forEach(tgt => { accDown[src][tgt] += w; });
            }
        });
    });

    // Per trace target (file) coverage within each layer
    const fileCoverageByDim = {};
    dims.forEach(d => {
        fileCoverageByDim[d] = new Map();
    });

    dims.forEach(src => {
        const srcOrder = dimOrder.get(src);
        idxByDim[src].forEach(i => {
            const n = nodes[i] || {};
            const raw = baseName(n.file);
            if (!raw || raw === 'config.md') return;

            let hasUp = false;
            let hasDown = false;
            (adj[i] || []).forEach(j => {
                const t = typeOf[j];
                if (!isDim(t) || t === src) return;
                const o = dimOrder.get(t);
                if (o < srcOrder) hasUp = true;
                else if (o > srcOrder) hasDown = true;
            });

            const m = fileCoverageByDim[src].get(raw) || { total: 0, up: 0, down: 0 };
            m.total += 1;
            if (hasUp) m.up += 1;
            if (hasDown) m.down += 1;
            fileCoverageByDim[src].set(raw, m);
        });
    });

    let html = '<ul class="summary-list">';
    dims.forEach(src => {
        const den = N[src] || 0;
        if (!den) return;

        // Collect targets in stable order: upstream then downstream (same as diagram layout).
        const upstreamParts = [];
        for (let k = dims.length - 1; k >= 0; k--) {
            const tgt = dims[k];
            if (dimOrder.get(tgt) >= dimOrder.get(src)) continue;
            const v = accUp[src][tgt] || 0;
            if (v > 0) upstreamParts.push(`${tgt} ${formatPct(v, den)}`);
        }
        const downstreamParts = [];
        for (let k = 0; k < dims.length; k++) {
            const tgt = dims[k];
            if (dimOrder.get(tgt) <= dimOrder.get(src)) continue;
            const v = accDown[src][tgt] || 0;
            if (v > 0) downstreamParts.push(`${tgt} ${formatPct(v, den)}`);
        }
        if (!upstreamParts.length && !downstreamParts.length) return;

        html += `<li class=\"summary-total-item\">${typeBadge(src)}`;
        html += '<ul class="summary-sublist">';
        if (upstreamParts.length) {
            html += `<li><span class=\"summary-dir\">upstream:</span> <span class=\"summary-pct\">${escapeHtml(upstreamParts.join(', '))}</span></li>`;
        }
        if (downstreamParts.length) {
            html += `<li><span class=\"summary-dir\">downstream:</span> <span class=\"summary-pct\">${escapeHtml(downstreamParts.join(', '))}</span></li>`;
        }

        const fileEntries = Array.from(fileCoverageByDim[src].entries())
            .sort((a, b) => String(a[0]).localeCompare(String(b[0])));
        if (fileEntries.length) {
            html += `<li><span class=\"summary-dir\">targets:</span>`;
            html += '<ul class="summary-target-list">';
            fileEntries.forEach(([rawName, stats]) => {
                const up = formatPct(stats.up, stats.total);
                const down = formatPct(stats.down, stats.total);
                const id = fileIdFromRawName(rawName);
                const ext = fileExtFromRawName(rawName);
                html += `<li class=\"summary-target-item\">`;
                html += `<a href=\"#\" onclick=\"showText(event, '${escapeJsSingle(id)}', 1, '${escapeJsSingle(ext)}')\" `;
                html += `onmouseover=\"showTooltip(event, '${escapeJsSingle(id)}')\" onmouseout=\"hideTooltip()\">${escapeHtml(rawName)}</a>`;
                html += ` <span class=\"summary-target-cov\">upstream ${escapeHtml(up)} / downstream ${escapeHtml(down)}</span>`;
                html += `</li>`;
            });
            html += '</ul></li>';
        }
        html += '</ul></li>';
    });
    html += '</ul>';
    el.innerHTML = html;
}

function renderParallelSetsRequirements(containerId, nodes, links, colorScale, getTraceType) {
    const container = document.getElementById(containerId);
    const width = container.clientWidth;
    const height = container.clientHeight || 600;

    container.innerHTML = '';

    const margin = { top: 30, right: 20, bottom: 20, left: 20 };
    const innerW = Math.max(0, width - margin.left - margin.right);
    const innerH = Math.max(0, height - margin.top - margin.bottom);
    const barW = 16;

    const svg = d3.select('#' + containerId)
        .append('svg')
        .attr('width', width)
        .attr('height', height);

    const defs = svg.append('defs');
    const gradientCache = new Map();
    function safeId(s) {
        return String(s).replace(/[^a-zA-Z0-9_-]/g, '_');
    }
    function ensurePathGradient(id, x1, y1, x2, y2, c1, c2) {
        if (gradientCache.has(id)) return;
        const lg = defs.append('linearGradient')
            .attr('id', id)
            .attr('gradientUnits', 'userSpaceOnUse')
            .attr('x1', x1)
            .attr('y1', y1)
            .attr('x2', x2)
            .attr('y2', y2);
        lg.append('stop').attr('offset', '0%').attr('stop-color', c1);
        lg.append('stop').attr('offset', '100%').attr('stop-color', c2);
        gradientCache.set(id, true);
    }

    const g = svg.append('g').attr('transform', `translate(${margin.left},${margin.top})`);

    const dims = ['Requirement', 'Architecture', 'Implementation', 'Unit test', 'Integration test'];
    const dimOrder = new Map(dims.map((d, i) => [d, i]));
    const isDim = (d) => dimOrder.has(d);

    function formatPct(value, total) {
        if (!total) return '';
        const p = (value / total) * 100;
        if (p > 0 && p < 0.5) return '<1%';
        const s = (p >= 10 ? p.toFixed(0) : p.toFixed(1));
        return s.replace(/\.0$/, '') + '%';
    }

    // Build undirected adjacency from direct links (numeric indices)
    const adj = Array.from({ length: nodes.length }, () => []);
    links.forEach(l => {
        if (typeof l.source !== 'number' || typeof l.target !== 'number') return;
        adj[l.source].push(l.target);
        adj[l.target].push(l.source);
    });

    const typeOf = nodes.map(n => getTraceType(n && n.trace_target));
    const idxByDim = {};
    dims.forEach(d => { idxByDim[d] = []; });
    typeOf.forEach((t, i) => {
        if (isDim(t)) idxByDim[t].push(i);
    });

    const N = {};
    const coveredUp = {};
    const coveredDown = {};
    const accUp = {}; // accUp[src][tgt] in "node mass" units (upstream: tgt is earlier layer)
    const accDown = {}; // accDown[src][tgt] in "node mass" units (downstream: tgt is later layer)
    dims.forEach(src => {
        N[src] = idxByDim[src].length;
        coveredUp[src] = 0;
        coveredDown[src] = 0;
        accUp[src] = {};
        accDown[src] = {};
        dims.forEach(tgt => {
            if (tgt === src) return;
            accUp[src][tgt] = 0;
            accDown[src][tgt] = 0;
        });
    });

    // Compute independent upstream/downstream projections.
    // A layer is 100% upstream-covered if all its nodes connect to ANY earlier layer.
    // A layer is 100% downstream-covered if all its nodes connect to ANY later layer.
    // Each node contributes mass 1 independently to upstream and downstream, split across distinct target layers on that side.
    dims.forEach(src => {
        const srcOrder = dimOrder.get(src);
        idxByDim[src].forEach(i => {
            const upSet = new Set();
            const downSet = new Set();
            (adj[i] || []).forEach(j => {
                const t = typeOf[j];
                if (!isDim(t) || t === src) return;
                const o = dimOrder.get(t);
                if (o < srcOrder) upSet.add(t);
                else if (o > srcOrder) downSet.add(t);
            });

            if (upSet.size) {
                coveredUp[src] += 1;
                const w = 1 / upSet.size;
                upSet.forEach(tgt => {
                    accUp[src][tgt] += w;
                });
            }

            if (downSet.size) {
                coveredDown[src] += 1;
                const w = 1 / downSet.size;
                downSet.forEach(tgt => {
                    accDown[src][tgt] += w;
                });
            }
        });
    });

    const outDegreeUp = {};
    const outDegreeDown = {};
    dims.forEach(src => {
        outDegreeUp[src] = 0;
        outDegreeDown[src] = 0;
        dims.forEach(tgt => {
            if (tgt === src) return;
            if ((accUp[src][tgt] || 0) > 0) outDegreeUp[src] += 1;
            if ((accDown[src][tgt] || 0) > 0) outDegreeDown[src] += 1;
        });
    });

    const maxN = Math.max(0, ...dims.map(d => N[d] || 0));
    if (maxN <= 0) {
        container.innerHTML = '<p style="text-align:center;padding:20px;">No traceability tags found.</p>';
        return;
    }

    const pxPerNode = innerH / maxN;
    const x = d3.scalePoint().domain(dims).range([0, innerW]).padding(0.5);

    // Precompute band positions per layer/target for ribbon endpoints.
    // Upstream (left) and downstream (right) are independent stacks.
    const bandsUp = {}; // bandsUp[src][tgt] = {y0,y1} where tgt is upstream of src
    const bandsDown = {}; // bandsDown[src][tgt] = {y0,y1} where tgt is downstream of src
    dims.forEach(src => {
        const srcOrder = dimOrder.get(src);

        bandsUp[src] = {};
        let yu = 0;
        // upstream targets: stable order (closest first visually), i.e., reverse dims
        for (let k = dims.length - 1; k >= 0; k--) {
            const tgt = dims[k];
            if (tgt === src) continue;
            if (dimOrder.get(tgt) >= srcOrder) continue;
            const h = (accUp[src][tgt] || 0) * pxPerNode;
            if (h <= 0) continue;
            bandsUp[src][tgt] = { y0: yu, y1: yu + h };
            yu += h;
        }

        bandsDown[src] = {};
        let yd = 0;
        // downstream targets: stable order (left-to-right dims)
        for (let k = 0; k < dims.length; k++) {
            const tgt = dims[k];
            if (tgt === src) continue;
            if (dimOrder.get(tgt) <= srcOrder) continue;
            const h = (accDown[src][tgt] || 0) * pxPerNode;
            if (h <= 0) continue;
            bandsDown[src][tgt] = { y0: yd, y1: yd + h };
            yd += h;
        }
    });

    // Tooltip (reuse existing one if present)
    const tooltip = d3.select('body').selectAll('div.sankey-tooltip.parallelsets')
        .data([null])
        .join('div')
        .attr('class', 'sankey-tooltip parallelsets')
        .style('position', 'absolute')
        .style('visibility', 'hidden')
        .style('background-color', 'white')
        .style('border', '1px solid #ccc')
        .style('border-radius', '4px')
        .style('padding', '8px')
        .style('box-shadow', '0 2px 4px rgba(0,0,0,0.1)')
        .style('font-size', '12px')
        .style('pointer-events', 'none')
        .style('z-index', '1000');

    function ribbonPath(x0, y0a, y0b, x1, y1a, y1b) {
        const c = 0.5;
        const xi = d3.interpolateNumber(x0, x1);
        const x2 = xi(c);
        return (
            `M${x0},${y0a}` +
            `C${x2},${y0a} ${x2},${y1a} ${x1},${y1a}` +
            `L${x1},${y1b}` +
            `C${x2},${y1b} ${x2},${y0b} ${x0},${y0b}` +
            'Z'
        );
    }

    function barLeft(dim) {
        return x(dim) - barW / 2;
    }
    function barRight(dim) {
        return x(dim) + barW / 2;
    }

    function drawRibbonBetween(a, b, isOverlay) {
        const oa = dimOrder.get(a);
        const ob = dimOrder.get(b);
        if (oa == null || ob == null || oa === ob) return;

        let aBand;
        let bBand;
        let x0;
        let x1;
        let p0;
        let p1;
        let html;

        if (oa < ob) {
            // a downstream -> b, and b upstream -> a
            aBand = bandsDown[a] && bandsDown[a][b];
            bBand = bandsUp[b] && bandsUp[b][a];
            if (!aBand || !bBand) return;
            x0 = barRight(a);
            x1 = barLeft(b);
            p0 = formatPct(accDown[a][b] || 0, N[a] || 0);
            p1 = formatPct(accUp[b][a] || 0, N[b] || 0);
            html = `<strong>${a} → ${b}</strong><br>${a}→${b}: ${p0}<br>${b}→${a} (up): ${p1}`;
        } else {
            // a upstream -> b, and b downstream -> a
            aBand = bandsUp[a] && bandsUp[a][b];
            bBand = bandsDown[b] && bandsDown[b][a];
            if (!aBand || !bBand) return;
            x0 = barLeft(a);
            x1 = barRight(b);
            p0 = formatPct(accUp[a][b] || 0, N[a] || 0);
            p1 = formatPct(accDown[b][a] || 0, N[b] || 0);
            html = `<strong>${a} ← ${b}</strong><br>${a}→${b} (up): ${p0}<br>${b}→${a}: ${p1}`;
        }

        const y0a = aBand.y0;
        const y0b = aBand.y1;
        const y1a = bBand.y0;
        const y1b = bBand.y1;

        const gradId = `type-grad-${safeId(containerId)}-${safeId(a)}-${safeId(b)}`;
        ensurePathGradient(gradId, x0, (y0a + y0b) / 2, x1, (y1a + y1b) / 2, colorScale(a), colorScale(b));

        const opacity = isOverlay ? 0.45 : 0.25;

        g.append('path')
            .attr('d', ribbonPath(x0, y0a, y0b, x1, y1a, y1b))
            .attr('fill', `url(#${gradId})`)
            .attr('opacity', opacity)
            .attr('stroke', 'none')
            .on('mouseover', function(event) {
                d3.select(this).attr('opacity', Math.min(0.75, opacity + 0.25));
                tooltip.style('visibility', 'visible')
                    .html(html);
            })
            .on('mousemove', function(event) {
                tooltip.style('top', (event.pageY - 10) + 'px')
                    .style('left', (event.pageX + 10) + 'px');
            })
            .on('mouseout', function() {
                d3.select(this).attr('opacity', opacity);
                tooltip.style('visibility', 'hidden');
            });

        // Per-ribbon percent label (single; avoid duplicating node-side total)
        const hA = Math.max(0, y0b - y0a);
        const hB = Math.max(0, y1b - y1a);
        if (Math.min(hA, hB) >= 12) {
            const showLabel = isOverlay || (oa < ob ? (outDegreeDown[a] > 1) : (outDegreeUp[a] > 1));
            if (showLabel && p0) {
                const labelX = x0 + (x1 - x0) * 0.5;
                g.append('text')
                    .attr('x', labelX)
                    .attr('y', (y0a + y0b) / 2)
                    .attr('dy', '0.35em')
                    .attr('text-anchor', 'middle')
                    .attr('font-size', '10px')
                    .attr('fill', '#333')
                    .text(p0);
            }
        }
    }

    // Draw adjacent ribbons first, then non-adjacent on top (skip overlay effect)
    for (let i = 0; i < dims.length - 1; i++) {
        drawRibbonBetween(dims[i], dims[i + 1], false);
    }
    for (let i = 0; i < dims.length; i++) {
        for (let j = i + 2; j < dims.length; j++) {
            drawRibbonBetween(dims[i], dims[j], true);
        }
    }

    // Bars and labels
    const barGroup = g.append('g').attr('class', 'parallel-bars');
    dims.forEach(d => {
        const total = N[d] || 0;
        if (!total) return;

        const bH = total * pxPerNode;
        const upH = (coveredUp[d] || 0) * pxPerNode;
        const downH = (coveredDown[d] || 0) * pxPerNode;
        const upPct = formatPct(coveredUp[d] || 0, total);
        const downPct = formatPct(coveredDown[d] || 0, total);

        barGroup.append('text')
            .attr('x', x(d))
            .attr('y', -10)
            .attr('text-anchor', 'middle')
            .attr('font-size', '12px')
            .attr('fill', '#333')
            .text(d);

        // Total nodes outline (with base fill to restore node color)
        barGroup.append('rect')
            .attr('x', barLeft(d))
            .attr('y', 0)
            .attr('width', barW)
            .attr('height', Math.max(0, bH))
            .attr('fill', colorScale(d))
            .attr('stroke', '#333')
            .attr('stroke-width', 1)
            .on('mouseover', function() {
                tooltip.style('visibility', 'visible')
                    .html(
                        `<strong>${d}</strong><br>` +
                        `Total: ${total}<br>` +
                        `Upstream: ${coveredUp[d] || 0} (${upPct || '0%'})<br>` +
                        `Downstream: ${coveredDown[d] || 0} (${downPct || '0%'})`
                    );
            })
            .on('mousemove', function(event) {
                tooltip.style('top', (event.pageY - 10) + 'px')
                    .style('left', (event.pageX + 10) + 'px');
            })
            .on('mouseout', function() {
                tooltip.style('visibility', 'hidden');
            });

        // Connected portions (upstream on left half, downstream on right half)
        if (upH > 0) {
            barGroup.append('rect')
                .attr('x', barLeft(d))
                .attr('y', 0)
                .attr('width', barW / 2)
                .attr('height', Math.max(0, upH))
                .attr('fill', colorScale(d))
                .attr('stroke', 'none');
        }
        if (downH > 0) {
            barGroup.append('rect')
                .attr('x', barLeft(d) + barW / 2)
                .attr('y', 0)
                .attr('width', barW / 2)
                .attr('height', Math.max(0, downH))
                .attr('fill', colorScale(d))
                .attr('stroke', 'none');
        }

        // Percent labels (upstream left, downstream right)
        if (upPct) {
            barGroup.append('text')
                .attr('x', barLeft(d) - 6)
                .attr('y', Math.min(Math.max(10, upH / 2), Math.max(10, bH - 10)))
                .attr('dy', '0.35em')
                .attr('text-anchor', 'end')
                .attr('font-size', '11px')
                .attr('fill', '#333')
                .text(upPct);
        }
        if (downPct) {
            barGroup.append('text')
                .attr('x', barRight(d) + 6)
                .attr('y', Math.min(Math.max(10, downH / 2), Math.max(10, bH - 10)))
                .attr('dy', '0.35em')
                .attr('text-anchor', 'start')
                .attr('font-size', '11px')
                .attr('fill', '#333')
                .text(downPct);
        }
    });
}

function renderSankeyDiagram(containerId, nodes, links, colorScale, getTraceType, clickable) {
    const container = document.getElementById(containerId);
    const width = container.clientWidth;
    const height = 600;

    // Clear any existing content
    container.innerHTML = '';

    // Create SVG
    const svg = d3.select('#' + containerId)
        .append('svg')
        .attr('width', width)
        .attr('height', height);

    // Create a group for the sankey diagram
    const g = svg.append('g')
        .attr('transform', 'translate(10,10)');

    // Create Sankey layout
    const sankey = d3.sankey()
        .nodeWidth(15)
        .nodePadding(10)
        .extent([[5, 5], [width - 20, height - 20]]);
    const nodeWidth = 15;

    // Prepare layout copies so we don't mutate the original arrays (separate state for 'all' vs 'type')
    let layoutNodes = nodes.map(n => Object.assign({}, n));
    let layoutLinks = links.map((l, i) => Object.assign({}, l, { index: i }));

    // Normalize links: if source/target are ids (strings), try to map to indices in layoutNodes
    const idToIndex = new Map(layoutNodes.map((n, i) => [n.id, i]));
    layoutLinks.forEach(l => {
        if (typeof l.source === 'string') l.source = idToIndex.get(l.source);
        if (typeof l.target === 'string') l.target = idToIndex.get(l.target);
    });

    // Validate links: ensure numeric indices in-range
    const validLinks = layoutLinks.filter((l, i) => {
        const s = l.source;
        const t = l.target;
        const ok = (typeof s === 'number' && typeof t === 'number' && s >= 0 && s < layoutNodes.length && t >= 0 && t < layoutNodes.length);
        if (!ok) console.warn(`Dropping invalid link (${containerId}) at index ${i}:`, l);
        return ok;
    });

    // (Totals for percent labels are computed later using sankey-produced layout and links.)

    if (validLinks.length > 0) {
        const result = sankey({ nodes: layoutNodes, links: validLinks });
        layoutNodes = result.nodes;
        layoutLinks = result.links;
        // ensure indices stable for gradients
        layoutLinks.forEach((l, idx) => { l.index = idx; });
    } else {
        // No links, position nodes in a grid
        const nodesPerRow = Math.ceil(Math.sqrt(layoutNodes.length));
        const nodeSpacingX = (width - 40) / Math.max(nodesPerRow, 1);
        const nodeSpacingY = (height - 40) / Math.max(Math.ceil(layoutNodes.length / nodesPerRow), 1);
        layoutNodes.forEach((node, i) => {
            const row = Math.floor(i / nodesPerRow);
            const col = i % nodesPerRow;
            node.x0 = col * nodeSpacingX + 20;
            node.x1 = node.x0 + nodeWidth;
            node.y0 = row * nodeSpacingY + 20;
            node.y1 = node.y0 + 20;
        });
    }

    // If clickable (full diagram), use the original nodes/links and group by type
    if (clickable) {
        // Run sankey layout on copies so we don't mutate original node objects shared elsewhere.
        let layoutNodesFull = nodes.map(n => Object.assign({}, n));
        let layoutLinksFull = links.map((l, i) => Object.assign({}, l, { index: i }));

        // Normalize numeric/string references if any
        const idToIndexFull = new Map(layoutNodesFull.map((n, i) => [n.id, i]));
        layoutLinksFull.forEach(l => {
            if (typeof l.source === 'string') l.source = idToIndexFull.get(l.source);
            if (typeof l.target === 'string') l.target = idToIndexFull.get(l.target);
        });

        const validLinksFull = layoutLinksFull.filter((l, i) => {
            const s = l.source;
            const t = l.target;
            return (typeof s === 'number' && typeof t === 'number' && s >= 0 && s < layoutNodesFull.length && t >= 0 && t < layoutNodesFull.length);
        });

        if (validLinksFull.length > 0) {
            try {
                const resultFull = sankey({ nodes: layoutNodesFull, links: validLinksFull });
                layoutNodesFull = resultFull.nodes;
                layoutLinksFull = resultFull.links;
            } catch (e) {
                console.warn(`sankey layout (full) failed on copies: ${e}`);
            }
        } else {
            // fallback grid layout for copies
            const nodesPerRow = Math.ceil(Math.sqrt(layoutNodesFull.length));
            const nodeSpacingX = (width - 40) / Math.max(nodesPerRow, 1);
            const nodeSpacingY = (height - 40) / Math.max(Math.ceil(layoutNodesFull.length / nodesPerRow), 1);
            layoutNodesFull.forEach((node, i) => {
                const row = Math.floor(i / nodesPerRow);
                const col = i % nodesPerRow;
                node.x0 = col * nodeSpacingX + 20;
                node.x1 = node.x0 + nodeWidth;
                node.y0 = row * nodeSpacingY + 20;
                node.y1 = node.y0 + 20;
            });
        }

        // Copy computed positions back onto original `nodes` so click handlers and other metadata stay intact.
        const posById = new Map(layoutNodesFull.map(n => [n.id, n]));
        nodes.forEach(orig => {
            const p = posById.get(orig.id);
            if (p) {
                orig.x0 = p.x0;
                orig.x1 = p.x1;
                orig.y0 = p.y0;
                orig.y1 = p.y1;
            }
        });

        // Finally override x positions to group by type (same layout as original behavior)
        const typeOrder = ['Requirement', 'Architecture', 'Implementation', 'Unit test', 'Integration test'];
        const nodesByType = d3.group(nodes, d => getTraceType(d.trace_target));
        // fixed sizing for full diagram nodes
        const fixedNodeHeight = 24; // px per node
        const nodeGap = 6; // vertical gap between nodes
        const topPadding = 20;
        const bottomPadding = 60; // leave space for legend/labels

        // compute tallest column height to size SVG accordingly
        let maxColumnHeight = 0;
        typeOrder.forEach(type => {
            const typeNodes = nodesByType.get(type) || [];
            const count = typeNodes.length;
            const columnHeight = count > 0 ? (count * fixedNodeHeight + Math.max(0, count - 1) * nodeGap) : 0;
            if (columnHeight > maxColumnHeight) maxColumnHeight = columnHeight;
        });

        const requiredHeight = topPadding + maxColumnHeight + bottomPadding;
        // apply immediately so we can compute positions relative to this height
        const finalHeight = Math.max(height, requiredHeight);
        svg.attr('height', finalHeight);
        // Match container height to SVG height and keep spacing so following sections never overlap.
        container.style.height = finalHeight + 'px';
        container.style.minHeight = finalHeight + 'px';
        container.style.marginBottom = '20px';

        typeOrder.forEach((type, typeIndex) => {
            const typeNodes = nodesByType.get(type) || [];
            let x = (typeIndex / (typeOrder.length - 1)) * (width - 40) + 20;
            const maxX = width - 20 - nodeWidth;
            if (x > maxX) x = maxX;
            const count = typeNodes.length;
            const columnHeight = count > 0 ? (count * fixedNodeHeight + Math.max(0, count - 1) * nodeGap) : 0;
            // center column vertically inside the allocated maxColumnHeight
            const startY = topPadding + (maxColumnHeight - columnHeight) / 2;
            typeNodes.forEach((node, i) => {
                node.x0 = x;
                node.x1 = x + nodeWidth;
                node.y0 = startY + i * (fixedNodeHeight + nodeGap);
                node.y1 = node.y0 + fixedNodeHeight;
            });
        });
    }

    // For the type diagram we preserve the sankey-computed node heights
    // (previously a shrink factor was applied here which caused incorrect sizing).

    // Create tooltip
    const tooltip = d3.select('body').append('div')
        .attr('class', 'sankey-tooltip')
        .style('position', 'absolute')
        .style('visibility', 'hidden')
        .style('background-color', 'white')
        .style('border', '1px solid #ccc')
        .style('border-radius', '4px')
        .style('padding', '8px')
        .style('box-shadow', '0 2px 4px rgba(0,0,0,0.1)')
        .style('font-size', '12px')
        .style('pointer-events', 'none')
        .style('z-index', '1000');

    // Draw links
    // For the full (clickable) diagram, ensure each link.source/target are node objects
    let linksToRender;
    if (clickable) {
        linksToRender = links.map((l, i) => {
            const src = (typeof l.source === 'number') ? nodes[l.source] : l.source;
            const tgt = (typeof l.target === 'number') ? nodes[l.target] : l.target;
            return Object.assign({}, l, { source: src, target: tgt, index: l.index != null ? l.index : i });
        });
    } else {
        linksToRender = (typeof layoutLinks !== 'undefined') ? layoutLinks : links;
    }
    linksToRender.forEach((d, i) => { if (d.index == null) d.index = i; });
    // Filter out padding links (internal-only) from rendering/gradients
    const visibleLinks = linksToRender.filter(l => !l._padding);
    const defs = svg.append('defs');
    const grads = defs.selectAll('linearGradient')
        .data(visibleLinks)
        .enter()
        .append('linearGradient')
        .attr('id', d => `grad-${containerId}-${d.index}`)
        .attr('gradientUnits', 'userSpaceOnUse')
        // Set coordinates so the gradient follows the link from source to target
        .attr('x1', d => d.source && d.source.x1 != null ? d.source.x1 : 0)
        .attr('y1', d => d.source ? (d.source.y0 + d.source.y1) / 2 : 0)
        .attr('x2', d => d.target && d.target.x0 != null ? d.target.x0 : 0)
        .attr('y2', d => d.target ? (d.target.y0 + d.target.y1) / 2 : 0);
    grads.append('stop').attr('offset', '0%').attr('stop-color', d => colorScale(getTraceType(d.source && d.source.trace_target)));
    grads.append('stop').attr('offset', '100%').attr('stop-color', d => colorScale(getTraceType(d.target && d.target.trace_target)));
    if (clickable) {
        // For full diagram, draw links manually since node positions were overridden
        g.append('g')
            .attr('class', 'links')
            .selectAll('path')
            .data(visibleLinks)
            .enter()
            .append('path')
            .attr('d', d => {
                const sourceX = d.source.x1;
                const sourceY = (d.source.y0 + d.source.y1) / 2;
                const targetX = d.target.x0;
                const targetY = (d.target.y0 + d.target.y1) / 2;
                const midX = (sourceX + targetX) / 2;
                return `M${sourceX},${sourceY}C${midX},${sourceY} ${midX},${targetY} ${targetX},${targetY}`;
            })
            .attr('stroke', d => `url(#grad-${containerId}-${d.index})`)
            .attr('stroke-width', d => Math.max(1, d.width || 2))
            .attr('fill', 'none')
            .attr('opacity', 0.6)
            .on('mouseover', function(event, d) {
                d3.select(this).attr('opacity', 1);
                tooltip.style('visibility', 'visible')
                    .html(`<strong>${d.source.id} → ${d.target.id}</strong><br>Value: ${d.rawValue != null ? d.rawValue : d.value}`);
            })
            .on('mousemove', function(event) {
                tooltip.style('top', (event.pageY - 10) + 'px')
                    .style('left', (event.pageX + 10) + 'px');
            })
                .on('mouseout', function() {
                    d3.select(this).attr('opacity', 0.6);
                    tooltip.style('visibility', 'hidden');
                });

                
    } else {
        // For type diagram, use sankey links
        g.append('g')
            .attr('class', 'links')
            .selectAll('path')
            .data(visibleLinks)
            .enter()
            .append('path')
            .attr('d', d3.sankeyLinkHorizontal())
            .attr('stroke', d => `url(#grad-${containerId}-${d.index})`)
            .attr('stroke-width', d => Math.max(1, d.width || 2))
            .attr('fill', 'none')
            .attr('opacity', 0.6)
            .on('mouseover', function(event, d) {
                d3.select(this).attr('opacity', 1);
                tooltip.style('visibility', 'visible')
                    .html(`<strong>${d.source.id} → ${d.target.id}</strong><br>Value: ${d.value}`);
            })
            .on('mousemove', function(event) {
                tooltip.style('top', (event.pageY - 10) + 'px')
                    .style('left', (event.pageX + 10) + 'px');
            })
            .on('mouseout', function() {
                d3.select(this).attr('opacity', 0.6);
                tooltip.style('visibility', 'hidden');
            });

        // Compute totals from sankey-produced layoutLinks (visible only) so percentages are accurate
        const nodeIndex = new Map(((typeof layoutNodes !== 'undefined') ? layoutNodes : nodes).map((n, i) => [n.id, i]));
        const totalsOut = new Array(nodeIndex.size).fill(0);
        const totalsIn = new Array(nodeIndex.size).fill(0);
        // use visibleLinks (padding excluded)
        visibleLinks.forEach(l => {
            const v = (l.value != null) ? l.value : 1;
            const sId = (l.source && l.source.id) ? l.source.id : null;
            const tId = (l.target && l.target.id) ? l.target.id : null;
            if (sId != null && nodeIndex.has(sId)) totalsOut[nodeIndex.get(sId)] += v;
            if (tId != null && nodeIndex.has(tId)) totalsIn[nodeIndex.get(tId)] += v;
        });

        // Draw percent labels along each link (source-side and target-side)
        // Only for visible (non-padding) links
        const linkLabelGroup = g.append('g').attr('class', 'link-labels');
        linkLabelGroup.selectAll('g')
            .data(visibleLinks)
            .enter()
            .append('g')
            .attr('pointer-events', 'none')
            .each(function(d) {
                const gnode = d3.select(this);
                    const v = (d.value != null) ? d.value : 0;
                    // Prefer contributor-based percentages: how many distinct source/target nodes participated
                    // Use contributor counts attached to the aggregated link (from renderSankey) and
                    // use per-type item counts stored on the sankey nodes as denominators.
                    const srcNode = d.source;
                    const tgtNode = d.target;
                    const srcItemCount = srcNode && (srcNode.itemCount != null) ? srcNode.itemCount : 0;
                    const tgtItemCount = tgtNode && (tgtNode.itemCount != null) ? tgtNode.itemCount : 0;
                    const contribFrom = (d.contributorsFromCount != null) ? d.contributorsFromCount : 0;
                    const contribTo = (d.contributorsToCount != null) ? d.contributorsToCount : 0;
                    const pctSrc = srcItemCount > 0 ? Math.round((contribFrom / srcItemCount) * 100) : 0;
                    const pctTgt = tgtItemCount > 0 ? Math.round((contribTo / tgtItemCount) * 100) : 0;

                const sx = d.source && d.source.x1 != null ? d.source.x1 : 0;
                const tx = d.target && d.target.x0 != null ? d.target.x0 : 0;
                const sy = d.source ? (d.source.y0 + d.source.y1) / 2 : 0;
                const ty = d.target ? (d.target.y0 + d.target.y1) / 2 : 0;

                // place source label below the node center to avoid overlapping node text
                gnode.append('text')
                    .text(pctSrc + '%')
                    .attr('x', sx + (tx - sx) * 0.12)
                    .attr('y', sy + 12)
                    .attr('font-size', '10px')
                    .attr('fill', '#111')
                    .attr('text-anchor', 'start')
                    .attr('dy', '0.35em');

                // place target label below the node center to match source placement
                gnode.append('text')
                    .text(pctTgt + '%')
                    .attr('x', sx + (tx - sx) * 0.88)
                    .attr('y', ty + 12)
                    .attr('font-size', '10px')
                    .attr('fill', '#111')
                    .attr('text-anchor', 'end')
                    .attr('dy', '0.35em');
            });
    }

    // Draw nodes
    // For the full diagram use the original nodes so file/line/description are preserved; for type diagram use layoutNodes
    // Filter out padding nodes (internal-only) from rendering
    const nodesToRender = clickable ? nodes : ((typeof layoutNodes !== 'undefined') ? layoutNodes : nodes).filter(n => n.trace_target !== 'pad');

    // Ensure SVG height fits the content: compute vertical extent of nodes and expand SVG/container if needed
    try {
        const yMin = nodesToRender.reduce((min, n) => Math.min(min, n.y0 != null ? n.y0 : Infinity), Infinity);
        const yMax = nodesToRender.reduce((max, n) => Math.max(max, n.y1 != null ? n.y1 : -Infinity), -Infinity);
        if (isFinite(yMin) && isFinite(yMax)) {
            const padding = 40; // space for labels/legend
            const currentSvgHeight = +svg.attr('height') || height;
            const requiredHeight = Math.max(currentSvgHeight, height, Math.ceil(yMax + padding));
            // Update svg and container to the required height (never shrink), preventing overlap.
            svg.attr('height', requiredHeight);
            container.style.height = requiredHeight + 'px';
            container.style.minHeight = requiredHeight + 'px';
            container.style.marginBottom = '20px';
        }
    } catch (e) {
        // ignore and continue if any node lacks coordinates
        console.warn('Could not compute dynamic SVG height:', e);
    }
    const node = g.append('g')
        .attr('class', 'nodes')
        .selectAll('rect')
        .data(nodesToRender)
        .enter()
        .append('rect')
        .attr('x', d => d.x0)
        .attr('y', d => d.y0)
        .attr('height', d => d.y1 - d.y0)
        .attr('width', d => d.x1 - d.x0)
        .attr('fill', d => colorScale(getTraceType(d.trace_target)))
        .attr('stroke', '#333')
        .attr('stroke-width', 1)
        .style('cursor', clickable ? 'pointer' : 'default')
        .on('click', clickable ? function(event, d) {
            if (typeof showText === 'function') {
                // Compute fileName
                const parts = d.file.split('/');
                let filename = parts[parts.length - 1];
                filename = filename.replace(/\./g, '_');
                filename = 'Target_' + filename;
                // Get extension
                const extParts = d.file.split('.');
                const extension = extParts[extParts.length - 1];
                showText(event, filename, d.line, extension);
            }
        } : null)
        .on('mouseover', function(event, d) {
            d3.select(this).attr('stroke-width', 2);
            tooltip.style('visibility', 'visible')
                .html(clickable ? `<strong>${d.id}</strong><br>` +
                      `Type: ${getTraceType(d.trace_target)}<br>` +
                      `File: ${d.file}:${d.line}<br>` +
                      `<em>${d.description}</em>` : `<strong>${d.id}</strong><br>` +
                      `Type: ${d.id}`);
        })
        .on('mousemove', function(event) {
            tooltip.style('top', (event.pageY - 10) + 'px')
                .style('left', (event.pageX + 10) + 'px');
        })
        .on('mouseout', function() {
            d3.select(this).attr('stroke-width', 1);
            tooltip.style('visibility', 'hidden');
        });

    // Add node labels
    // Node labels with white background behind text for readability
    const labelGroups = g.append('g')
        .attr('class', 'node-labels')
        .selectAll('g')
        .data(nodesToRender)
        .enter()
        .append('g')
        .attr('class', 'node-label')
        .style('pointer-events', 'none')
        .attr('transform', d => {
            const x = d.x0 < width / 2 ? d.x1 + 6 : d.x0 - 6;
            const y = (d.y0 + d.y1) / 2;
            return `translate(${x},${y})`;
        });

    labelGroups.append('text')
        .attr('x', 0)
        .attr('y', 0)
        .attr('dy', '0.35em')
        .attr('text-anchor', d => d.x0 < width / 2 ? 'start' : 'end')
        .attr('font-size', '10px')
        .attr('fill', '#333')
        .text(d => d.id);
}

function renderSankey(data) {
		// Color scale for trace targets - more distinct colors
		const colorScale = d3.scaleOrdinal()
				.domain(['Requirement', 'Architecture', 'Implementation', 'Unit test', 'Integration test'])
				.range(['#e74c3c', '#3498db', '#2ecc71', '#f39c12', '#9b59b6']); // More distinct colors

		// Function to extract type from trace_target (safe)
        const getTraceType = traceTypeFromTraceTarget;

        // Legends and top-of-page metadata
        renderLegend('sankey-legend-full');
        renderLegend('sankey-legend-type');
        annotateTraceTargets(data);
        annotateMatrixBadges();
        renderSummary(data);

		// Prepare nodes and links for full diagram
		const sankeyNodes = data.nodes.map((d, i) => ({ ...d, index: i }));
		const nodeIndexMap = new Map(sankeyNodes.map((node, i) => [node.id, i]));
    

		const sankeyLinks = data.links.map(d => ({
				...d,
				source: nodeIndexMap.get(d.source),
				target: nodeIndexMap.get(d.target)
		}));
    
		sankeyLinks.forEach((link, i) => {
				if (link.source === undefined || link.target === undefined) {
						console.error(`Link ${i} has undefined source/target:`, link);
				}
		});

		// Render full diagram
		renderSankeyDiagram('sankey-diagram-full', sankeyNodes, sankeyLinks, colorScale, getTraceType, true);

		// Render type diagram as Parallel Sets (direct-link coverage; matches `--summary` definition)
		const directLinksRaw = Array.isArray(data.direct_links) ? data.direct_links : data.links;
		const directLinks = directLinksRaw
				.map(d => ({
						...d,
						source: nodeIndexMap.get(d.source),
						target: nodeIndexMap.get(d.target)
				}))
				.filter(l => typeof l.source === 'number' && typeof l.target === 'number');

		renderParallelSetsRequirements('sankey-diagram-type', sankeyNodes, directLinks, colorScale, getTraceType);
}

EOF
}

##
# @brief   Generate HTML table header with sortable columns dynamically from TAG_INFO_TABLE
# @param   $1 : TAG_INFO_TABLE (tag information with trace_target)
# @return  HTML <thead> element with sort buttons
_html_add_table_header() {
	_TAG_INFO_TABLE="$1"
	_sep="$SHTRACER_SEPARATOR"

	printf '%s\n' '<thead>'
	printf '%s\n' '  <tr>'

	# Extract unique trace_target types and generate header columns
	{
		if [ -n "$_TAG_INFO_TABLE" ] && [ -r "$_TAG_INFO_TABLE" ]; then
			cat "$_TAG_INFO_TABLE"
		else
			printf '%s\n' "$_TAG_INFO_TABLE"
		fi
	} | awk -F"$_sep" -v col_idx=0 '
		function get_last_segment(s,   n, parts) {
			n = split(s, parts, ":")
			return n > 0 ? parts[n] : s
		}
		{
			if (NF >= 4 && $4 != "") {
				trace_target = $4
				col_name = get_last_segment(trace_target)
				if (!(col_name in seen)) {
					seen[col_name] = 1
					cols[col_idx++] = col_name
				}
			}
		}
		END {
			for (i = 0; i < col_idx; i++) {
				printf "    <th>%s <a href=\"#\" onclick=\"sortTable(%d)\">sort</a></th>\n", cols[i], i
			}
		}
	'

	printf '%s\n' '  </tr>'
	printf '%s\n' '</thead>'
}

##
# @brief   Convert tag table rows to HTML table body
# @param   $1 : TAG_TABLE_FILENAME
# @return  HTML <tbody> element with table data
_html_convert_tag_table() {
	# Convert tag table rows into fixed layer columns based on tag->trace_target mapping.
	# $1: TAG_TABLE_FILENAME (space-separated tags per line)
	# $2: TAG_INFO_TABLE (tag<sep>line<sep>path<sep>trace_target)
	_TAG_TABLE_FILENAME="$1"
	_TAG_INFO_TABLE="$2"
	_sep="$SHTRACER_SEPARATOR"
	_nodata="$NODATA_STRING"

	printf '%s\n' '<tbody>'
	{
		if [ -n "$_TAG_INFO_TABLE" ] && [ -r "$_TAG_INFO_TABLE" ]; then
			cat "$_TAG_INFO_TABLE"
		else
			printf '%s\n' "$_TAG_INFO_TABLE"
		fi
		printf '%s\n' '__SHTRACER_TAG_INFO_END__'
		cat "$_TAG_TABLE_FILENAME"
	} | awk -v sep="$_sep" -v nodata="$_nodata" '
        BEGIN {
            ndims = 0
            mode = 0
        }
        function get_last_segment(s,   n, parts) {
            n = split(s, parts, ":")
            return n > 0 ? parts[n] : s
        }
        function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
        function field1(s, delim,   p1) {
            p1 = index(s, delim)
            if (p1 <= 0) return s
            return substr(s, 1, p1 - 1)
        }
        function field2(s, delim,   rest, p1, p2) {
            p1 = index(s, delim)
            if (p1 <= 0) return ""
            rest = substr(s, p1 + length(delim))
            p2 = index(rest, delim)
            if (p2 <= 0) return rest
            return substr(rest, 1, p2 - 1)
        }
        function field3(s, delim,   rest, p1, p2, p3) {
            p1 = index(s, delim)
            if (p1 <= 0) return ""
            rest = substr(s, p1 + length(delim))
            p2 = index(rest, delim)
            if (p2 <= 0) return ""
            rest = substr(rest, p2 + length(delim))
            p3 = index(rest, delim)
            if (p3 <= 0) return rest
            return substr(rest, 1, p3 - 1)
        }
        function field4(s, delim,   rest, p1, p2, p3) {
            p1 = index(s, delim)
            if (p1 <= 0) return ""
            rest = substr(s, p1 + length(delim))
            p2 = index(rest, delim)
            if (p2 <= 0) return ""
            rest = substr(rest, p2 + length(delim))
            p3 = index(rest, delim)
            if (p3 <= 0) return ""
            return substr(rest, p3 + length(delim))
        }
        function type_from_trace_target(tt,   n, p, t) {
            if (tt == "") return "Unknown"
            n = split(tt, p, ":")
            t = trim(p[n])
            return t == "" ? "Unknown" : t
        }
        function escape_html(s,   t) {
            t = s
            gsub(/&/, "&amp;", t)
            gsub(/</, "&lt;", t)
            gsub(/>/, "&gt;", t)
            gsub(/"/, "&quot;", t)
            return t
        }
        function basename(path,   t) {
            t = path
            gsub(/.*\//, "", t)
            return t
        }
        function ext_from_basename(base) {
            if (match(base, /\.[^\.]+$/)) return substr(base, RSTART + 1)
            return "sh"
        }
        function fileid_from_basename(base,   t) {
            t = base
            gsub(/\./, "_", t)
            return "Target_" t
        }
        function badge(tag, typ, line, fileId, ext,   safeTyp, safeTag, safeId, safeExt) {
            safeTyp = escape_html(typ)
            safeTag = escape_html(tag)
            safeId = escape_html(fileId)
            safeExt = escape_html(ext)
            return "<span class=\"matrix-tag-badge\" data-type=\"" safeTyp "\">" \
                "<a href=\"#\" onclick=\"showText(event, &quot;" safeId "&quot;, " line ", &quot;" safeExt "&quot;)\" " \
                "onmouseover=\"showTooltip(event, &quot;" safeId "&quot;)\" onmouseout=\"hideTooltip()\">" safeTag "</a></span>"
        }
        $0 == "__SHTRACER_TAG_INFO_END__" {
            mode = 1
            next
        }
        mode == 0 {
            if ($0 == "") next
            tag = trim(field1($0, sep))
            if (tag == "") next
            line = trim(field2($0, sep))
            path = trim(field3($0, sep))
            trace_target = trim(field4($0, sep))
            if (line == "" || line + 0 < 1) line = 1
            typ = type_from_trace_target(trace_target)
            tagType[tag] = typ
            tagLine[tag] = line
            base = basename(path)
            tagExt[tag] = ext_from_basename(base)
            tagFileId[tag] = fileid_from_basename(base)
            # Build dims array dynamically
            if (typ != "" && typ != "Unknown" && !(typ in dimIndex)) {
                dims[++ndims] = typ
                dimIndex[typ] = ndims
            }
            next
        }
        {
            for (i = 1; i <= ndims; i++) { cell[i] = nodata; html[i] = "" }
            nextSlot = 1
            nt = split($0, tags, /[[:space:]]+/)
            for (k = 1; k <= nt; k++) {
                t = trim(tags[k])
                if (t == "" || t == nodata) continue
                typ = tagType[t]
                if (typ == "") typ = "Unknown"
                if (typ in dimIndex) {
                    col = dimIndex[typ]
                } else {
                    while (nextSlot <= ndims && cell[nextSlot] != nodata) nextSlot++
                    col = (nextSlot <= ndims) ? nextSlot : ndims
                }
                frag = badge(t, typ, tagLine[t], tagFileId[t], tagExt[t])
                if (cell[col] == nodata) { cell[col] = t; html[col] = frag }
                else { cell[col] = cell[col] " " t; html[col] = html[col] "<br>" frag }
            }
            printf "\n  <tr>\n"
            for (i = 1; i <= ndims; i++) {
                if (cell[i] == nodata) printf "    <td><span class=\"matrix-tag-badge matrix-tag-badge-nodata\">%s</span></td>\n", nodata
                else printf "    <td>%s</td>\n", html[i]
            }
            printf "  </tr>"
        }
    '
	printf '%s\n' '</tbody>'
}

##
# @brief   Generate HTML file information list for sidebar
# @param   $1 : TAG_INFO_TABLE (tag information with file paths)
# @return  HTML <ul> element with clickable file links
_html_generate_file_list() {
	printf '%s\n' '<div id="trace-targets">'
	printf '%s\n' '<ul>'
	echo "$1" \
		| awk -F"$SHTRACER_SEPARATOR" '$1 != "@CONFIG@" {print $3}' \
		| sort -u \
		| awk '{
            n = split($0, parts, "/");
            filename = parts[n];
            raw_filename = filename;
            extension_pos = match(raw_filename, /\.[^\.]+$/);
            gsub(/\./, "_", filename);
            gsub(/^/, "Target_", filename);

            if (extension_pos) {
                extension = substr(raw_filename, extension_pos + 1);
            } else {
                extension = "sh";
            }
            print "<li><a href=\"#\" onclick=\"showText(event, '\''"filename"'\'', 1, '\''"extension"'\'')\" onmouseover=\"showTooltip(event, '\''"filename"'\'')\" onmouseout=\"hideTooltip()\">"raw_filename"</a></li>"
        }'
	printf '%s\n' '</ul>'
	printf '%s\n' '</div>'
}

##
# @brief   Insert file information into HTML with proper indentation
# @param   $1 : HTML_CONTENT (template HTML to modify)
# @param   $2 : INFORMATION (file list HTML)
# @return  Modified HTML with inserted content and fixed indentation
_html_insert_content_with_indentation() {
	_html_insert_info_file="$(shtracer_tmpfile)" || {
		error_exit 1 "_html_insert_content_with_indentation" "Failed to create temporary file"
	}
	trap 'rm -f "$_html_insert_info_file" 2>/dev/null || true' EXIT INT TERM

	printf '%s' "$2" >"$_html_insert_info_file"

	_html_insert_result=$(echo "$1" \
		| awk -v info_file="$_html_insert_info_file" '
			BEGIN {
				idx = 0
				while ((getline line < info_file) > 0) {
					gsub(/\r$/, "", line)
					lines[idx++] = line
				}
				close(info_file)
			}
			{
				if (match($0, / *<!-- INSERT INFORMATION -->/)) {
					print "<!-- SHTRACER INSERTED -->"
					for (i = 0; i < idx; i++) {
						print lines[i]
					}
					print "<!-- SHTRACER INSERTED -->"
				} else {
					print
				}
			}' \
		| awk '
			BEGIN {
			    add_space = 0
			}

			/<!-- SHTRACER INSERTED -->/ {
				if (add_space == 0) {
					add_space = 1
					add_space_count = previous_space_count + (previous_space_count == space_count ? 2 : 4)
				} else {
					add_space = 0
					printf "%*s%s\n", add_space_count, "", $0
					next
				}
			}

			{
				previous_space_count = space_count
				match($0, /^[ \t]*/)
				space_count = RLENGTH

				if (add_space == 1) {
					printf "%*s%s\n", add_space_count, "", $0
				} else {
					print $0
				}
			}
		' \
		| sed '/<!-- SHTRACER INSERTED -->/d')

	rm -f "$_html_insert_info_file" 2>/dev/null || true
	trap - EXIT INT TERM
	echo "$_html_insert_result"
}

##
# @brief Convert a template html file for output.html
# @param $1 : TAG_TABLE_FILENAME
# @param $2 : TAG_INFO_TABLE
# @param $3 : TEMPLATE_HTML_DIR
# @param $4 : JSON_FILE (optional)
convert_template_html() {
	(
		profile_start "convert_template_html"

		_TAG_TABLE_FILENAME="$1"
		_TAG_INFO_TABLE="$2"
		_TEMPLATE_HTML_DIR="$3"
		_JSON_FILE="${4:-}"

		profile_start "convert_template_html_read_json"
		if [ -z "$_JSON_FILE" ]; then
			_JSON_FILE="${OUTPUT_DIR%/}/output.json"
		fi
		profile_end "convert_template_html_read_json"

		profile_start "convert_template_html_build_table"
		_TABLE_HTML="$(_html_add_table_header "$_TAG_INFO_TABLE")"
		_TABLE_HTML="$_TABLE_HTML$(_html_convert_tag_table "$_TAG_TABLE_FILENAME" "$_TAG_INFO_TABLE")"
		profile_end "convert_template_html_build_table"

		profile_start "convert_template_html_insert_tag_table"
		_tmp_table_html_file="$(shtracer_tmpfile)" || {
			error_exit 1 "convert_template_html" "Failed to create temporary file"
		}
		printf '%s' "$_TABLE_HTML" >"$_tmp_table_html_file"
		_HTML_CONTENT="$(
			sed -e "s/'\\n'/'\\\\n'/g" <"${_TEMPLATE_HTML_DIR%/}/template.html" \
				| awk -v table_html_file="$_tmp_table_html_file" -v json_file="$_JSON_FILE" '
                    /^[ \t]*<!-- INSERT TABLE -->/ {
                        print "<!-- SHTRACER INSERTED -->"
                        while ((getline line < table_html_file) > 0) {
                            gsub(/\r$/, "", line)
                            print line
                        }
                        close(table_html_file)
                        print "<!-- SHTRACER INSERTED -->"
                        next
                    }
                    /^[ \t]*<!-- INSERT JSON DATA -->/ {
                        print "const traceabilityData = "
                        while ((getline j < json_file) > 0) {
                            gsub(/\r$/, "", j)
                            gsub(/<\/script>/, "<\\/script>", j)
                            print j
                        }
                        close(json_file)
                        print ";"
                        next
                    }
                    { print }
                '
		)"
		rm -f "$_tmp_table_html_file"
		profile_end "convert_template_html_insert_tag_table"

		profile_start "convert_template_html_insert_information"
		_INFORMATION="$(_html_generate_file_list "$_TAG_INFO_TABLE")"
		profile_end "convert_template_html_insert_information"

		profile_start "convert_template_html_insert_mermaid"
		_HTML_CONTENT="$(_html_insert_content_with_indentation "$_HTML_CONTENT" "$_INFORMATION")"
		profile_end "convert_template_html_insert_mermaid"

		echo "$_HTML_CONTENT"

		profile_end "convert_template_html"
	)
}

##
# @brief   Build TAG_INFO_TABLE from shtracer JSON output
# @param   $1 : JSON_FILE
# @return  Echoes TAG_INFO_TABLE to stdout (tag<sep>line<sep>path per line)
tag_info_table_from_json_file() {
	_JSON_FILE="$1"
	if [ -z "$_JSON_FILE" ] || [ ! -r "$_JSON_FILE" ]; then
		error_exit 1 "tag_info_table_from_json_file" "JSON file not readable"
	fi
	_sep="${SHTRACER_SEPARATOR}"
	_tmp_file="$(shtracer_tmpfile)" || error_exit 1 "tag_info_table_from_json_file" "Failed to create temporary file"
	_tmp_sort="$(shtracer_tmpfile)" || error_exit 1 "tag_info_table_from_json_file" "Failed to create temporary file"
	trap 'rm -f "$_tmp_file" "$_tmp_sort" 2>/dev/null || true' EXIT INT TERM

	awk '
		BEGIN {
			in_nodes = 0
			in_obj = 0
		}
		function grab_str(s, key,   r, v) {
			r = "\"" key "\"[[:space:]]*:[[:space:]]*\""
			if (match(s, r)) {
				v = s
				sub(".*" r, "", v)
				sub("\".*", "", v)
				return v
			}
			return ""
		}
		function grab_int(s, key,   r, v) {
			r = "\"" key "\"[[:space:]]*:[[:space:]]*"
			if (match(s, r)) {
				v = s
				sub(".*" r, "", v)
				sub("[^0-9].*", "", v)
				return v
			}
			return ""
		}
		{
			line = $0
			gsub(/[\{\}\[\],]/, "&\n", line)
			n = split(line, a, /\n/)
			for (i = 1; i <= n; i++) {
				t = a[i]
				if (t == "") { continue }

				if (!in_nodes && t ~ /"nodes"[[:space:]]*:/) {
					seen_nodes_key = 1
				}
				if (!in_nodes && seen_nodes_key && t ~ /\[/) {
					in_nodes = 1
					seen_nodes_key = 0
				}

				if (in_nodes && !in_obj && t ~ /\{/) {
					in_obj = 1
					id = ""
					file = ""
					ln = ""
					idx = ""
                    trace_target = ""
                    type = ""
				}

				if (in_obj) {
					v = grab_str(t, "id"); if (v != "") { id = v }
					v = grab_str(t, "file"); if (v != "") { file = v }
                    v = grab_str(t, "trace_target"); if (v != "") { trace_target = v }
                    v = grab_str(t, "type"); if (v != "") { type = v }
					v = grab_int(t, "line"); if (v != "") { ln = v }
					v = grab_int(t, "index"); if (v != "") { idx = v }

					if (t ~ /\}/) {
						if (idx == "") { idx = 999999999 }
						if (id != "" && file != "" && ln != "") {
                            if (trace_target == "" && type != "") { trace_target = type }
                            print idx "\t" id "\t" ln "\t" file "\t" trace_target
						}
						in_obj = 0
					}
				}

				if (in_nodes && !in_obj && t ~ /\]/) {
					in_nodes = 0
				}
			}
		}
	' <"$_JSON_FILE" \
		| sort -k1,1n \
			>"$_tmp_sort"

	awk -F '\t' -v sep="$_sep" -v OFS="" '
		!seen[$2]++ {
            print $2, sep, $3, sep, $4, sep, $5
		}
	' <"$_tmp_sort" >"$_tmp_file"

	_config_path="$(grep -m 1 '"config_path"' "$_JSON_FILE" 2>/dev/null | sed 's/.*"config_path"[[:space:]]*:[[:space:]]*"//; s/".*//')"
	if [ -n "$_config_path" ]; then
		printf '%s%s%s%s%s%s%s\n' '@CONFIG@' "$_sep" '1' "$_sep" "$_config_path" "$_sep" '' >>"$_tmp_file"
	fi

	cat "$_tmp_file"
	rm -f "$_tmp_file" "$_tmp_sort" 2>/dev/null || true
	trap - EXIT INT TERM
}

##
# @brief   Build TAG_TABLE from shtracer JSON output (chains)
# @param   $1 : JSON_FILE
# @return  Echoes TAG_TABLE rows to stdout (space-separated tags per line)
tag_table_from_json_file() {
	_JSON_FILE="$1"
	if [ -z "$_JSON_FILE" ] || [ ! -r "$_JSON_FILE" ]; then
		error_exit 1 "tag_table_from_json_file" "JSON file not readable"
	fi

	awk '
		BEGIN {
			in_chains = 0
			in_chain = 0
			seen_chains_key = 0
			out = ""
		}
		function grab_str(s,   v) {
			v = s
			sub(/^[[:space:]]*"/, "", v)
			sub(/".*$/, "", v)
			return v
		}
		{
			line = $0
			gsub(/[\{\}\[\],]/, "&\n", line)
			n = split(line, a, /\n/)
			for (i = 1; i <= n; i++) {
				t = a[i]
				if (t == "") { continue }

				if (!in_chains && t ~ /"chains"[[:space:]]*:/) {
					seen_chains_key = 1
				}
				if (!in_chains && seen_chains_key && t ~ /\[/) {
					in_chains = 1
					seen_chains_key = 0
					continue
				}

				if (in_chains && !in_chain && t ~ /\[/) {
					in_chain = 1
					out = ""
					continue
				}

				if (in_chain) {
					if (t ~ /^[[:space:]]*"/) {
						v = grab_str(t)
						if (v != "") {
							if (out == "") out = v
							else out = out " " v
						}
					}
					if (t ~ /\]/) {
						if (out != "") print out
						in_chain = 0
						out = ""
						continue
					}
				}

				if (in_chains && !in_chain && t ~ /\]/) {
					in_chains = 0
				}
			}
		}
	' <"$_JSON_FILE"
}

##
# @brief Convert template js file for tracing targets
# @param $1 : TAG_INFO_TABLE
# @param $2 : TEMPLATE_ASSETS_DIR
convert_template_js() {
	(
		profile_start "convert_template_js"
		_TAG_INFO_TABLE="$1"
		_TEMPLATE_ASSETS_DIR="$2"

		_JS_CONTENTS="$(
			echo "$_TAG_INFO_TABLE" | awk -F"$SHTRACER_SEPARATOR" '{ print $3 }' | sort -u \
				| awk '
                    function js_escape(s) {
                        gsub(/\\/, "\\\\", s)
                        gsub(/"/, "\\\"", s)
                        gsub(/\t/, "\\t", s)
                        gsub(/\r/, "\\r", s)
                        return s
                    }
                    function file_to_js_string(path,   line, out) {
                        out = ""
                        while ((getline line < path) > 0) {
                            gsub(/\r$/, "", line)
                            out = out js_escape(line) "\\n"
                        }
                        close(path)
                        return out
                    }
                    {
                        path = $0
                        n = split($0, parts, "/")
                        raw_filename = parts[n]
                        filename = raw_filename
                        extension_pos = match(raw_filename, /\.[^\.]+$/)
                        if (extension_pos) extension = substr(raw_filename, extension_pos + 1)
                        else extension = "txt"

                        gsub(/\./, "_", filename)
                        gsub(/^/, "Target_", filename)

                        contents = file_to_js_string(path)
                        print "\t\"" js_escape(filename) "\": {"
                        print "\t\tpath:\"" js_escape(path) "\"," 
                        print "\t\tcontent:\"" contents "\"," 
                        print "\t\textension:\"" js_escape(extension) "\""
                        print "\t},"
                    }'
		)"
		_viewer_emit_show_text_js_template | while read -r s; do
			case "$s" in
				*//\ js_contents*)
					printf "%s\n" "$_JS_CONTENTS"
					;;
				*)
					printf "%s\n" "$s"
					;;
			esac
		done
		profile_end "convert_template_js"
	)
}

##
# @brief  Make output files (html, js, css)
# @param  $1 : TAG_TABLE_FILENAME
# @param  $2 : TAGS
make_html() {
	(
		_TEMPLATE_HTML_DIR="${SCRIPT_DIR%/}/scripts/main/template/"
		_TEMPLTE_ASSETS_DIR="${_TEMPLATE_HTML_DIR%/}/assets/"
		_OUTPUT_ASSETS_DIR="${OUTPUT_DIR%/}/assets/"

		_TAG_TABLE_FILENAME="$1"
		_TAG_INFO_TABLE="$(awk <"$2" -F"$SHTRACER_SEPARATOR" -v config_path="${CONFIG_PATH}" -v separator="$SHTRACER_SEPARATOR" '
			BEGIN {
				OFS = separator;
			}
			{
                trace_target = $1;
				tag = $2;
				path = $5
				line = $6
                print tag, line, path, trace_target
			}
			END {
                print "@CONFIG@", "1", config_path, ""
			}')"

		mkdir -p "${OUTPUT_DIR%/}/assets/"
		convert_template_html "$_TAG_TABLE_FILENAME" "$_TAG_INFO_TABLE" "$_TEMPLATE_HTML_DIR" >"${OUTPUT_DIR%/}/output.html"
		convert_template_js "$_TAG_INFO_TABLE" "$_TEMPLTE_ASSETS_DIR" >"${_OUTPUT_ASSETS_DIR%/}/show_text.js"
		cat "${_TEMPLTE_ASSETS_DIR%/}/template.css" >"${_OUTPUT_ASSETS_DIR%/}/template.css"
		_viewer_emit_traceability_diagrams_js >"${_OUTPUT_ASSETS_DIR%/}/traceability_diagrams.js"
	)
}

print_usage() {
	cat <<-USAGE 1>&2
		Usage: shtracer_viewer.sh [--tag-table <tag_table_file>] [-i <json_file>]

		Reads shtracer JSON from stdin (default) or from -i <json_file>,
		and writes a single self-contained HTML document to stdout.

		Examples:
		  # JSON-only (viewer builds the tag table from JSON chains)
		  ./shtracer ./sample/config.md --json | ./scripts/main/shtracer_viewer.sh > output.html

		  # Explicit tag-table path
		  ./shtracer ./sample/config.md --json | ./scripts/main/shtracer_viewer.sh --tag-table ./sample/output/tags/04_tag_table > output.html

		  # JSON file input
		  ./scripts/main/shtracer_viewer.sh -i ./sample/output/output.json > output.html
	USAGE
	exit 1
}

shtracer_viewer_main() {
	JSON_FILE=""
	TAG_TABLE_FILE=""

	while [ $# -gt 0 ]; do
		case "$1" in
			-h | --help)
				print_usage
				;;
			-i)
				shift
				[ $# -gt 0 ] || print_usage
				JSON_FILE="$1"
				;;
			--tag-table)
				shift
				[ $# -gt 0 ] || print_usage
				TAG_TABLE_FILE="$1"
				;;
			*)
				print_usage
				;;
		esac
		shift
	done

	# Determine repo root (SCRIPT_DIR in shtracer terminology)
	_REPO_DIR="$(
		unset CDPATH
		cd "$(dirname "$0")/../.." && pwd -P
	)"
	SCRIPT_DIR="$_REPO_DIR"
	export SCRIPT_DIR

	# Source shared functions (must be sourced, not executed)
	# shellcheck source=scripts/main/shtracer_util.sh
	. "${SCRIPT_DIR%/}/scripts/main/shtracer_util.sh"

	SHTRACER_SEPARATOR="${SHTRACER_SEPARATOR:=<shtracer_separator>}"
	export SHTRACER_SEPARATOR

	NODATA_STRING="${NODATA_STRING:=NONE}"
	export NODATA_STRING

	_TEMPLATE_DIR="${SCRIPT_DIR%/}/scripts/main/template"
	_TEMPLATE_ASSETS_DIR="${_TEMPLATE_DIR%/}/assets"

	_tmp_dir="$(shtracer_tmpdir)" || {
		echo "[shtracer_viewer.sh][error]: failed to create temporary directory" 1>&2
		exit 1
	}
	_json_tmp="${_tmp_dir%/}/input.json"
	_html_tmp="${_tmp_dir%/}/base.html"
	_tag_table_tmp="${_tmp_dir%/}/tag_table"
	_show_text_tmp="${_tmp_dir%/}/show_text.js"
	_trace_js_tmp="${_tmp_dir%/}/traceability_diagrams.js"

	cleanup() {
		rm -rf "$_tmp_dir" 2>/dev/null || true
	}
	trap cleanup EXIT INT TERM

	if [ -n "$JSON_FILE" ]; then
		[ -r "$JSON_FILE" ] || {
			echo "[shtracer_viewer.sh][error]: json not readable: $JSON_FILE" 1>&2
			exit 1
		}
		cat "$JSON_FILE" >"$_json_tmp"
	else
		if [ -t 0 ]; then
			echo "[shtracer_viewer.sh][error]: no stdin; use -i <json_file>" 1>&2
			exit 1
		fi
		cat >"$_json_tmp"
	fi

	if [ -z "$TAG_TABLE_FILE" ]; then
		_config_path="$(grep -m 1 '"config_path"' "$_json_tmp" 2>/dev/null | sed 's/.*"config_path"[[:space:]]*:[[:space:]]*"//; s/".*//')"
		if [ -n "$_config_path" ]; then
			_config_dir="$(dirname "$_config_path")"
			_inferred_table="${_config_dir%/}/output/tags/04_tag_table"
			if [ -r "$_inferred_table" ]; then
				TAG_TABLE_FILE="$_inferred_table"
			fi
		fi
	fi

	if [ -n "$TAG_TABLE_FILE" ] && [ ! -r "$TAG_TABLE_FILE" ]; then
		echo "[shtracer_viewer.sh][error]: tag table not readable: $TAG_TABLE_FILE" 1>&2
		exit 1
	fi

	if [ -z "$TAG_TABLE_FILE" ]; then
		tag_table_from_json_file "$_json_tmp" >"$_tag_table_tmp"
		if [ ! -s "$_tag_table_tmp" ]; then
			echo "[shtracer_viewer.sh][error]: cannot build tag table from JSON (missing/empty chains)" 1>&2
			exit 1
		fi
		TAG_TABLE_FILE="$_tag_table_tmp"
	fi

	_TAG_INFO_TABLE="$(tag_info_table_from_json_file "$_json_tmp")"

	convert_template_html "$TAG_TABLE_FILE" "$_TAG_INFO_TABLE" "$_TEMPLATE_DIR" "$_json_tmp" >"$_html_tmp"
	convert_template_js "$_TAG_INFO_TABLE" "$_TEMPLATE_ASSETS_DIR" >"$_show_text_tmp"
	_viewer_emit_traceability_diagrams_js >"$_trace_js_tmp"

	awk \
		-v css_file="${_TEMPLATE_ASSETS_DIR%/}/template.css" \
		-v show_text_file="$_show_text_tmp" \
		-v trace_js_file="$_trace_js_tmp" \
		'
			function emit_file(path) {
				while ((getline line < path) > 0) {
					gsub(/\r$/, "", line)
					print line
				}
				close(path)
			}
			{
				if ($0 ~ /<link rel="stylesheet" href="\.\/assets\/template\.css">/) {
					print "  <style>"
					emit_file(css_file)
					print "  </style>"
					next
				}
				if ($0 ~ /<script src="\.\/assets\/show_text\.js"><\/script>/) {
					print "  <script>"
					emit_file(show_text_file)
					print "  </script>"
					next
				}
				if ($0 ~ /<script src="\.\/assets\/traceability_diagrams\.js"><\/script>/) {
					print "  <script>"
					emit_file(trace_js_file)
					print "  </script>"
					next
				}
				print
			}
		' <"$_html_tmp"
}

case "$0" in
	*shtracer_viewer.sh | *shtracer_viewer)
		shtracer_viewer_main "$@"
		;;
	*)
		: # sourced
		;;
esac
