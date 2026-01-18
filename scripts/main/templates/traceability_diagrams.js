// traceability_diagrams.js - Traceability visualizations for shtracer
// Renders the interactive full Sankey diagram and the requirements-centric Type view.

// Initialize global color mapping based on traceTargetOrder
(function() {
    if (!window._traceTypeColorMap) {
        window._traceTypeColorMap = new Map();
    }

    // Color scheme for trace targets
    const colorScheme = ['#e74c3c', '#3498db', '#2ecc71', '#f39c12', '#9b59b6',
                        '#1abc9c', '#e67e22', '#95a5a6', '#34495e', '#c0392b'];

    // If traceTargetOrder exists, use it to initialize color mapping
    if (typeof traceTargetOrder !== 'undefined' && Array.isArray(traceTargetOrder)) {
        console.log('[Color Init] Initializing colors for', traceTargetOrder.length, 'layer types:', traceTargetOrder);
        traceTargetOrder.forEach((type, index) => {
            if (!window._traceTypeColorMap.has(type)) {
                const color = colorScheme[index % colorScheme.length];
                window._traceTypeColorMap.set(type, color);
                console.log(`[Color Init] ${type} → ${color}`);
            }
        });
    } else {
        console.warn('[Color Init] traceTargetOrder not defined or not an array');
    }

    // Always ensure Unknown has a color
    if (!window._traceTypeColorMap.has('Unknown')) {
        window._traceTypeColorMap.set('Unknown', '#7f8c8d');
    }

    console.log('[Color Init] Final color map:', Array.from(window._traceTypeColorMap.entries()));
})();

// Configuration constants for diagram rendering
const DIAGRAM_CONFIG = {
    SANKEY: {
        NODE_HEIGHT: 24,
        NODE_GAP: 6,
        NODE_WIDTH: 20,
        NODE_PADDING: 12,
        TOP_PADDING: 20,
        BOTTOM_PADDING: 60
    },
    PARALLEL_SETS: {
        BAR_WIDTH: 16,
        HEIGHT_PER_NODE: 15,
        MIN_BAR_HEIGHT: 30,
        MAX_BAR_HEIGHT: 200,
        BAR_SPACING: 15,
        MIN_HEIGHT: 150,
        MAX_HEIGHT: 800
    },
    TOOLTIP: {
        FONT_SIZE: '12px',
        OFFSET_X: 10,
        OFFSET_Y: -10
    },
    COLORS: {
        UNKNOWN: '#7f8c8d',
        STROKE: '#333',
        TEXT: '#333'
    }
};

// Utility functions for file path resolution
/**
 * Resolve file path for a node, handling both v0.1.3 (file_id) and legacy (file) formats
 * @param {Object} node - The node object
 * @param {Object} data - The traceability data (with files array)
 * @returns {string|null} The resolved file path or null
 */
function resolveFilePath(node, data) {
    if (node.file_id !== undefined && data && data.files && data.files[node.file_id]) {
        return data.files[node.file_id].file;
    }
    return node.file || null;
}

/**
 * Extract base filename from a path
 * @param {string} path - Full file path
 * @returns {string} Base filename
 */
function getBaseName(path) {
    const parts = String(path || '').split('/');
    return parts.length ? parts[parts.length - 1] : path;
}

/**
 * Extract file extension from a path
 * @param {string} path - Full file path
 * @returns {string} File extension (default: 'sh')
 */
function getFileExtension(path) {
    const match = String(path || '').match(/\.([^.]+)$/);
    return match ? match[1] : 'sh';
}

/**
 * Create a reusable D3 tooltip
 * @param {string} className - CSS class name for the tooltip (optional)
 * @returns {Object} D3 selection for the tooltip
 */
function createTooltip(className = 'sankey-tooltip') {
    return d3.select('body').append('div')
        .attr('class', className)
        .style('position', 'absolute')
        .style('visibility', 'hidden')
        .style('background-color', 'white')
        .style('border', '1px solid #ccc')
        .style('border-radius', '4px')
        .style('padding', '8px')
        .style('box-shadow', '0 2px 4px rgba(0,0,0,0.1)')
        .style('font-size', DIAGRAM_CONFIG.TOOLTIP.FONT_SIZE)
        .style('pointer-events', 'none')
        .style('z-index', '1000');
}

/**
 * Prepare links for rendering (normalize source/target references)
 * @param {Array} links - Raw link array
 * @param {Array} nodes - Node array for index lookup
 * @returns {Array} Prepared links with source/target as objects
 */
function prepareLinksForRendering(links, nodes) {
    return links.map((l, i) => {
        const src = (typeof l.source === 'number') ? nodes[l.source] : l.source;
        const tgt = (typeof l.target === 'number') ? nodes[l.target] : l.target;
        return Object.assign({}, l, {
            source: src,
            target: tgt,
            index: l.index != null ? l.index : i
        });
    });
}

/**
 * Filter out padding links (internal-only links)
 * @param {Array} links - Link array
 * @returns {Array} Visible links only
 */
function filterVisibleLinks(links) {
    const visible = links.filter(l => !l._padding);
    visible.forEach((d, i) => { d.visibleIndex = i; });
    return visible;
}

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

function getLayerName(layerId) {
    // Get layer name from layer_id using global traceabilityData
    if (typeof traceabilityData === 'undefined' || !traceabilityData.layers) {
        console.warn('[getLayerName] traceabilityData or layers not defined');
        return 'Unknown';
    }
    if (layerId === null || layerId === undefined || layerId < 0) {
        console.warn('[getLayerName] Invalid layerId:', layerId);
        return 'Unknown';
    }
    const layer = traceabilityData.layers[layerId];
    if (!layer) {
        console.warn('[getLayerName] Layer not found for layerId:', layerId);
        return 'Unknown';
    }
    // Debug: log first few layer lookups
    if (layerId < 5) {
        console.log(`[getLayerName] layer_id=${layerId} → name="${layer.name}"`);
    }
    return layer.name;
}

// Legacy function - kept for compatibility but now uses layer_id
function traceTypeFromTraceTarget(traceTarget, layerId) {
    // If layer_id is provided, use it directly
    if (layerId !== null && layerId !== undefined) {
        return getLayerName(layerId);
    }
    // Fallback: parse trace_target string (for backward compatibility)
    if (!traceTarget) return 'Unknown';
    const parts = String(traceTarget).split(':');
    const type = parts[parts.length - 1].trim() || 'Unknown';
    return type;
}

function traceTypeColor(type) {
    // Use global color mapping initialized at startup
    if (!window._traceTypeColorMap) {
        window._traceTypeColorMap = new Map();
    }

    if (!window._traceTypeColorMap.has(type)) {
        // Fallback: assign color if type not in initial mapping
        const colorScheme = ['#e74c3c', '#3498db', '#2ecc71', '#f39c12', '#9b59b6',
                            '#1abc9c', '#e67e22', '#95a5a6', '#34495e', '#c0392b'];
        const nextIndex = window._traceTypeColorMap.size;
        const color = type === 'Unknown' ? '#7f8c8d' : colorScheme[nextIndex % colorScheme.length];
        window._traceTypeColorMap.set(type, color);
    }

    return window._traceTypeColorMap.get(type);
}

function renderLegend(containerId, types) {
    const el = document.getElementById(containerId);
    if (!el) return;

    // If types not provided, use config.md order or extract from traceabilityData
    if (!types && typeof traceabilityData !== 'undefined') {
        if (typeof traceTargetOrder !== 'undefined' && Array.isArray(traceTargetOrder) && traceTargetOrder.length > 0) {
            // Use config.md order and filter to only types present in nodes
            const nodesTypes = new Set();
            (traceabilityData.trace_tags || traceabilityData.nodes || []).forEach(n => {
                const t = traceTypeFromTraceTarget(n && n.trace_target, n && n.layer_id);
                if (t && t !== 'Unknown') nodesTypes.add(t);
            });
            types = traceTargetOrder.filter(t => nodesTypes.has(t));
        } else {
            // Fallback: extract unique trace types from nodes in order of first appearance
            const seenTypes = new Set();
            const extractedTypes = [];
            (traceabilityData.trace_tags || traceabilityData.nodes || []).forEach(n => {
                const t = traceTypeFromTraceTarget(n && n.trace_target, n && n.layer_id);
                if (t && t !== 'Unknown' && !seenTypes.has(t)) {
                    seenTypes.add(t);
                    extractedTypes.push(t);
                }
            });
            types = extractedTypes;
        }
    }

    if (!types || types.length === 0) {
        types = ['Unknown'];
    }

    const legendData = types.map(type => ({
        type: type,
        color: traceTypeColor(type)
    }));

    el.innerHTML = legendData.map(d =>
        `<span class="legend-item"><span class="legend-swatch" style="background:${d.color}"></span><span>${d.type}</span></span>`
    ).join('');
}

function annotateTraceTargets(data) {
    const fileToTypes = new Map();
    (data.trace_tags || data.nodes || []).forEach(n => {
        if (!n) return;
        const filePath = resolveFilePath(n, data);
        if (!filePath) return;
        const base = getBaseName(filePath);
        const t = traceTypeFromTraceTarget(n.trace_target, n.layer_id);
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

    const nodes = Array.isArray(data.trace_tags) ? data.trace_tags : (Array.isArray(data.nodes) ? data.nodes : []);
    // Derive links from trace_tags using from_tags array
    const links = Array.isArray(data.trace_tags) || Array.isArray(data.nodes)
        ? (data.trace_tags || data.nodes || [])
            .flatMap(tag => (tag.from_tags || [])
                .filter(ft => ft && ft !== 'NONE')
                .map(ft => ({ source: ft, target: tag.id })))
        : [];

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

    function fileIdFromRawName(rawName) {
        return 'Target_' + String(rawName).replace(/\./g, '_');
    }

    function formatVersionDisplay(versionRaw) {
        if (!versionRaw || versionRaw === 'unknown') return 'unknown';
        if (versionRaw.startsWith('git:')) {
            return versionRaw.substring(4); // Remove "git:" prefix
        }
        if (versionRaw.startsWith('mtime:')) {
            // Convert "mtime:2025-12-26T10:30:45Z" to "2025-12-26 10:30"
            const timestamp = versionRaw.substring(6); // Remove "mtime:" prefix
            return timestamp.replace('T', ' ').replace(/:\d{2}Z$/, '');
        }
        return versionRaw;
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

    // Use trace target order from config.md if available, otherwise extract from nodes
    let dims = [];
    if (typeof traceTargetOrder !== 'undefined' && Array.isArray(traceTargetOrder) && traceTargetOrder.length > 0) {
        // Use config.md order and filter to only types present in nodes
        const nodesTypes = new Set();
        nodes.forEach(n => {
            const t = traceTypeFromTraceTarget(n && n.trace_target, n && n.layer_id);
            if (t && t !== 'Unknown') nodesTypes.add(t);
        });
        dims = traceTargetOrder.filter(t => nodesTypes.has(t));
    } else {
        // Fallback: extract unique trace types from nodes in order of first appearance
        const seenTypes = new Set();
        nodes.forEach(n => {
            const t = traceTypeFromTraceTarget(n && n.trace_target, n && n.layer_id);
            if (t && t !== 'Unknown' && !seenTypes.has(t)) {
                seenTypes.add(t);
                dims.push(t);
            }
        });
    }
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

    const typeOf = nodes.map(n => traceTypeFromTraceTarget(n && n.trace_target, n && n.layer_id));
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

            // Handle both v0.1.2 (file field) and v0.1.3 (file_id field) formats
            const filePath = resolveFilePath(n, data);
            const raw = filePath ? getBaseName(filePath) : '';
            const fileVersion = (typeof n.file_id === 'number' && data.files && data.files[n.file_id])
                ? data.files[n.file_id].version || 'unknown'
                : n.file_version || 'unknown';

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

            const m = fileCoverageByDim[src].get(raw) || { total: 0, up: 0, down: 0, version: fileVersion };
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
        fileEntries.forEach(([rawName, stats]) => {
            const up = formatPct(stats.up, stats.total);
            const down = formatPct(stats.down, stats.total);
            const id = fileIdFromRawName(rawName);
            const ext = getFileExtension(rawName);
            const versionDisplay = formatVersionDisplay(stats.version);
            html += `<li class=\"summary-target-item\">`;
            html += `<a href=\"#\" onclick=\"showText(event, '${escapeJsSingle(id)}', 1, '${escapeJsSingle(ext)}')\" `;
            html += `onmouseover=\"showTooltip(event, '${escapeJsSingle(id)}')\" onmouseout=\"hideTooltip()\">${escapeHtml(rawName)}</a>`;
            html += ` <span class=\"summary-version\">(${escapeHtml(versionDisplay)})</span>`;
            html += ` <span class=\"summary-target-cov\">upstream ${escapeHtml(up)} / downstream ${escapeHtml(down)}</span>`;
            html += `</li>`;
        });
        html += '</ul></li>';
    });
    html += '</ul>';
    el.innerHTML = html;
}

/**
 * Render the Traceability Health section with coverage analysis and isolated tags
 * @param {Object} data - Traceability data object containing health information
 */
function renderHealth(data) {
    const el = document.getElementById('traceability-health');
    if (!el) return;
    if (!data.health) {
        el.innerHTML = '<p>No health data available.</p>';
        return;
    }

    const health = data.health;
    const totalTags = health.total_tags || 0;
    let tagsWithLinks = health.tags_with_links || 0;
    const isolatedTags = health.isolated_tags || 0;
    const danglingRefs = health.dangling_references || 0;

    // Sanity check: tags_with_links should never exceed total_tags
    if (tagsWithLinks > totalTags) {
        console.warn(`Data inconsistency: tags_with_links (${tagsWithLinks}) > total_tags (${totalTags}). Capping to total_tags.`);
        tagsWithLinks = totalTags;
    }

    // Calculate percentages
    let isolatedPct = 0;
    let tagsWithLinksPct = 0;
    if (totalTags > 0) {
        isolatedPct = Math.floor((100 * isolatedTags) / totalTags);
        tagsWithLinksPct = Math.floor((100 * tagsWithLinks) / totalTags);
    }

    function escapeHtml(s) {
        return String(s)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function escapeJsSingle(s) {
        return String(s)
            .replace(/\\/g, '\\\\')
            .replace(/'/g, "\\'");
    }

    function getBaseName(path) {
        if (!path) return '';
        return path.split('/').pop();
    }

    function getFileExtension(fileName) {
        if (!fileName) return 'txt';
        const parts = fileName.split('.');
        return parts.length > 1 ? parts[parts.length - 1] : 'txt';
    }

    function fileIdFromRawName(rawName) {
        return 'Target_' + String(rawName).replace(/\./g, '_');
    }

    // Build Coverage Analysis table
    let html = '<h3>Coverage Analysis</h3>';
    html += '<table class="health-table">';
    html += '<thead><tr><th>Metric</th><th>Value</th></tr></thead>';
    html += '<tbody>';
    html += `<tr><td>Total Tags</td><td>${totalTags}</td></tr>`;
    html += `<tr><td>Tags with Links</td><td>${tagsWithLinks} (${tagsWithLinksPct}%)</td></tr>`;
    html += `<tr><td>Isolated Tags</td><td>${isolatedTags} (${isolatedPct}%)</td></tr>`;
    html += `<tr><td>Dangling References</td><td>${danglingRefs}</td></tr>`;
    html += '</tbody></table>';

    // Build Isolated Tags section
    html += '<h3>Isolated Tags</h3>';

    const isolatedList = health.isolated_tag_list || [];
    const isolatedCount = isolatedList.length;

    if (isolatedCount === 0) {
        html += '<p>✓ No isolated tags found.</p>';
    } else {
        html += `<p>${isolatedCount} isolated tag(s) with no downstream traceability:</p>`;
        html += '<details>';
        html += `<summary>Show isolated tags (${isolatedCount})</summary>`;
        html += '<ul class="isolated-tags-list">';
        
        isolatedList.forEach(item => {
            const tagId = item.id || '';
            const fileId = item.file_id;
            const line = item.line || 1;

            // Resolve file path
            let filePath = 'unknown';
            let fileBaseName = 'unknown';
            if (typeof fileId === 'number' && data.files && data.files[fileId]) {
                filePath = data.files[fileId].file || 'unknown';
                fileBaseName = getBaseName(filePath);
            }

            if (filePath !== 'unknown') {
                const targetId = fileIdFromRawName(fileBaseName);
                const ext = getFileExtension(fileBaseName);

                // Get tag info from traceabilityData
                let tagDescription = '';
                let layerName = '';
                let fromTags = '';
                const tagNode = (data.trace_tags || data.nodes || []).find(t => t.id === tagId);
                if (tagNode) {
                    tagDescription = tagNode.description || '';
                    const layer = data.layers && data.layers[tagNode.layer_id];
                    layerName = layer ? layer.name : '';
                    fromTags = (tagNode.from_tags || []).filter(t => t && t !== 'NONE').join(',');
                }

                html += '<li>';
                html += `<span class="matrix-tag-badge" data-type="${escapeHtml(layerName)}">`;
                html += `<a href="#" onclick="showText(event, '${escapeJsSingle(targetId)}', ${line}, '${escapeJsSingle(ext)}', '${escapeJsSingle(tagId)}', '${escapeJsSingle(tagDescription)}', '${escapeJsSingle(layerName)}', '${escapeJsSingle(fromTags)}')" `;
                html += `onmouseover="showTooltip(event, '${escapeJsSingle(targetId)}', '${escapeJsSingle(tagId)}', ${line}, '${escapeJsSingle(layerName)}', '${escapeJsSingle(tagDescription)}')" `;
                html += `onmouseout="hideTooltip()">`;
                html += `${escapeHtml(tagId)}`;
                html += `</a>`;
                html += `</span>`;
                html += '</li>';
            } else {
                html += '<li>';
                html += `<span class="matrix-tag-badge" data-type="${escapeHtml(layerName)}">`;
                html += `${escapeHtml(tagId)}`;
                html += `</span>`;
                html += '</li>';
            }
        });
        
        html += '</ul>';
        html += '</details>';
    }

    // Build Dangling References section
    html += '<h3>Dangling References</h3>';

    const danglingList = health.dangling_reference_list || [];
    const danglingCount = danglingList.length;

    if (danglingCount === 0) {
        html += '<p>✓ No dangling references found.</p>';
    } else {
        html += `<p>${danglingCount} dangling reference(s) - tags referencing non-existent parents:</p>`;
        html += '<details>';
        html += `<summary>Show dangling references (${danglingCount})</summary>`;
        html += '<table class="dangling-refs-table">';
        html += '<thead><tr><th>Child Tag</th><th>Missing Parent</th><th>File</th><th>Line</th></tr></thead>';
        html += '<tbody>';

        danglingList.forEach(item => {
            const childTag = item.child_tag || '';
            const missingParent = item.missing_parent || '';
            const fileId = item.file_id;
            const line = item.line || 1;

            // Resolve file path
            let filePath = 'unknown';
            let fileBaseName = 'unknown';
            if (typeof fileId === 'number' && data.files && data.files[fileId]) {
                filePath = data.files[fileId].file || 'unknown';
                fileBaseName = getBaseName(filePath);
            }

            if (filePath !== 'unknown') {
                const targetId = fileIdFromRawName(fileBaseName);
                const ext = getFileExtension(fileBaseName);

                // Get tag info from traceabilityData
                let tagDescription = '';
                let layerName = '';
                let fromTags = '';
                const tagNode = (data.trace_tags || data.nodes || []).find(t => t.id === childTag);
                if (tagNode) {
                    tagDescription = tagNode.description || '';
                    const layer = data.layers && data.layers[tagNode.layer_id];
                    layerName = layer ? layer.name : '';
                    fromTags = (tagNode.from_tags || []).filter(t => t && t !== 'NONE').join(',');
                }

                html += '<tr>';
                html += '<td>';
                html += `<span class="matrix-tag-badge" data-type="${escapeHtml(layerName)}">`;
                html += `<a href="#" onclick="showText(event, '${escapeJsSingle(targetId)}', ${line}, '${escapeJsSingle(ext)}', '${escapeJsSingle(childTag)}', '${escapeJsSingle(tagDescription)}', '${escapeJsSingle(layerName)}', '${escapeJsSingle(fromTags)}')" `;
                html += `onmouseover="showTooltip(event, '${escapeJsSingle(targetId)}', '${escapeJsSingle(childTag)}', ${line}, '${escapeJsSingle(layerName)}', '${escapeJsSingle(tagDescription)}')" `;
                html += `onmouseout="hideTooltip()">`;
                html += `${escapeHtml(childTag)}`;
                html += `</a>`;
                html += `</span>`;
                html += '</td>';
                html += `<td><code>${escapeHtml(missingParent)}</code></td>`;
                html += `<td>${escapeHtml(fileBaseName)}</td>`;
                html += `<td>${line}</td>`;
                html += '</tr>';
            } else {
                html += '<tr>';
                html += '<td>';
                html += `<span class="matrix-tag-badge" data-type="${escapeHtml(layerName)}">`;
                html += `${escapeHtml(childTag)}`;
                html += `</span>`;
                html += '</td>';
                html += `<td><code>${escapeHtml(missingParent)}</code></td>`;
                html += `<td>${escapeHtml(fileBaseName)}</td>`;
                html += `<td>${line}</td>`;
                html += '</tr>';
            }
        });

        html += '</tbody></table>';
        html += '</details>';
    }

    html += '<hr>';
    el.innerHTML = html;
}

/**
 * Compute coverage statistics for Parallel Sets diagram
 * @param {Array} dims - Dimension array (trace types)
 * @param {Map} dimOrder - Map of dimension to order index
 * @param {Array} nodes - Array of nodes
 * @param {Array} links - Array of links
 * @param {Function} getTraceType - Function to get trace type from node
 * @returns {Object} Object with coverage statistics and adjacency info
 */
function computeParallelSetsCoverage(dims, dimOrder, nodes, links, getTraceType) {
    const isDim = (d) => dimOrder.has(d);

    // Build undirected adjacency from direct links
    const adj = Array.from({ length: nodes.length }, () => []);
    links.forEach(l => {
        if (typeof l.source !== 'number' || typeof l.target !== 'number') return;
        adj[l.source].push(l.target);
        adj[l.target].push(l.source);
    });

    const typeOf = nodes.map(n => getTraceType(n && n.trace_target, n && n.layer_id));
    const idxByDim = {};
    dims.forEach(d => { idxByDim[d] = []; });
    typeOf.forEach((t, i) => {
        if (isDim(t)) idxByDim[t].push(i);
    });

    const N = {};
    const coveredUp = {};
    const coveredDown = {};
    const accUp = {};
    const accDown = {};

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

    // Compute upstream/downstream projections
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
                upSet.forEach(tgt => { accUp[src][tgt] += w; });
            }

            if (downSet.size) {
                coveredDown[src] += 1;
                const w = 1 / downSet.size;
                downSet.forEach(tgt => { accDown[src][tgt] += w; });
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

    return { N, coveredUp, coveredDown, accUp, accDown, outDegreeUp, outDegreeDown };
}

/**
 * Calculate bar heights and Y positions for Parallel Sets
 * @param {Array} dims - Dimension array (trace types)
 * @param {Map} dimOrder - Map of dimension to order index
 * @param {Object} N - Node counts per dimension
 * @param {Object} coveredUp - Upstream coverage per dimension
 * @param {Object} coveredDown - Downstream coverage per dimension
 * @param {Object} accDown - Downstream accumulation per dimension pair
 * @returns {Object} Object with barHeights, barYOffsets, sourceToTargets
 */
function calculateParallelSetsBarLayout(dims, dimOrder, N, coveredUp, coveredDown, accDown) {
    const heightPerNode = DIAGRAM_CONFIG.PARALLEL_SETS.HEIGHT_PER_NODE;
    const minBarHeight = DIAGRAM_CONFIG.PARALLEL_SETS.MIN_BAR_HEIGHT;
    const maxBarHeight = DIAGRAM_CONFIG.PARALLEL_SETS.MAX_BAR_HEIGHT;
    const barSpacing = DIAGRAM_CONFIG.PARALLEL_SETS.BAR_SPACING;

    const barHeights = {};
    dims.forEach(dim => {
        const total = N[dim] || 0;
        const upCov = coveredUp[dim] || 0;
        const downCov = coveredDown[dim] || 0;
        const maxCov = Math.max(upCov, downCov, total * 0.3);
        const calcHeight = maxCov * heightPerNode;
        barHeights[dim] = Math.min(maxBarHeight, Math.max(minBarHeight, calcHeight));
    });

    // Build connection map
    const sourceToTargets = {};
    dims.forEach(src => {
        sourceToTargets[src] = [];
        dims.forEach(tgt => {
            if (src !== tgt) {
                const srcOrder = dimOrder.get(src);
                const tgtOrder = dimOrder.get(tgt);
                if (srcOrder < tgtOrder && (accDown[src][tgt] > 0)) {
                    sourceToTargets[src].push(tgt);
                }
            }
        });
    });

    // Position bars
    const barYOffsets = {};
    barYOffsets[dims[0]] = 0;

    for (let i = 1; i < dims.length; i++) {
        const dim = dims[i];
        let strongestSource = null;
        let maxWeight = 0;

        for (let j = 0; j < i; j++) {
            const prevDim = dims[j];
            const weight = accDown[prevDim][dim] || 0;
            if (weight > maxWeight) {
                maxWeight = weight;
                strongestSource = prevDim;
            }
        }

        if (strongestSource) {
            const siblings = sourceToTargets[strongestSource];
            const siblingIndex = siblings.indexOf(dim);

            if (siblingIndex === 0) {
                barYOffsets[dim] = barYOffsets[strongestSource];
            } else {
                const prevSibling = siblings[siblingIndex - 1];
                barYOffsets[dim] = barYOffsets[prevSibling] + barHeights[prevSibling] + barSpacing;
            }
        } else {
            barYOffsets[dim] = 0;
        }
    }

    return { barHeights, barYOffsets, sourceToTargets };
}

/**
 * Calculate band positions for ribbons in Parallel Sets
 * @param {Array} dims - Dimension array (trace types)
 * @param {Map} dimOrder - Map of dimension to order index
 * @param {Object} barYOffsets - Bar Y offsets
 * @param {Object} barHeights - Bar heights
 * @param {Object} accUp - Upstream accumulation
 * @param {Object} accDown - Downstream accumulation
 * @param {Object} N - Node counts
 * @returns {Object} Object with bandsUp and bandsDown
 */
function calculateParallelSetsBands(dims, dimOrder, barYOffsets, barHeights, accUp, accDown, N) {
    const heightPerNode = DIAGRAM_CONFIG.PARALLEL_SETS.HEIGHT_PER_NODE;

    const scaleForDim = (dim) => {
        const total = N[dim] || 0;
        const barHeight = barHeights[dim];
        return total > 0 ? (barHeight / total) : 0;
    };

    const bandsUp = {};
    const bandsDown = {};

    dims.forEach(src => {
        const srcOrder = dimOrder.get(src);
        const srcYOffset = barYOffsets[src];

        bandsUp[src] = {};
        let yu = srcYOffset;
        for (let k = dims.length - 1; k >= 0; k--) {
            const tgt = dims[k];
            if (tgt === src || dimOrder.get(tgt) >= srcOrder) continue;
            const h = (accUp[src][tgt] || 0) * scaleForDim(src);
            if (h <= 0) continue;
            bandsUp[src][tgt] = { y0: yu, y1: yu + h };
            yu += h;
        }

        bandsDown[src] = {};
        let yd = srcYOffset;
        for (let k = 0; k < dims.length; k++) {
            const tgt = dims[k];
            if (tgt === src || dimOrder.get(tgt) <= srcOrder) continue;
            const h = (accDown[src][tgt] || 0) * scaleForDim(src);
            if (h <= 0) continue;
            bandsDown[src][tgt] = { y0: yd, y1: yd + h };
            yd += h;
        }
    });

    return { bandsUp, bandsDown };
}

function renderParallelSetsRequirements(containerId, nodes, links, colorScale, getTraceType) {
    const container = document.getElementById(containerId);
    const width = container.clientWidth;

    container.innerHTML = '';

    const margin = { top: 5, right: 20, bottom: 20, left: 20 };
    const innerW = Math.max(0, width - margin.left - margin.right);
    let innerH = 200; // Initial value, will be recalculated based on bar heights
    let height = margin.top + margin.bottom + innerH; // Initial height
    const barW = DIAGRAM_CONFIG.PARALLEL_SETS.BAR_WIDTH;

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

    // Use trace target order from config.md if available, otherwise extract from nodes
    let dims = [];
    if (typeof traceTargetOrder !== 'undefined' && Array.isArray(traceTargetOrder) && traceTargetOrder.length > 0) {
        // Use config.md order and filter to only types present in nodes
        const nodesTypes = new Set();
        nodes.forEach(n => {
            const t = getTraceType(n && n.trace_target, n && n.layer_id);
            if (t && t !== 'Unknown') nodesTypes.add(t);
        });
        dims = traceTargetOrder.filter(t => nodesTypes.has(t));
    } else {
        // Fallback: extract unique trace types from nodes in order of first appearance
        const seenTypes = new Set();
        nodes.forEach(n => {
            const t = getTraceType(n && n.trace_target, n && n.layer_id);
            if (t && t !== 'Unknown' && !seenTypes.has(t)) {
                seenTypes.add(t);
                dims.push(t);
            }
        });
    }
    const dimOrder = new Map(dims.map((d, i) => [d, i]));
    const isDim = (d) => dimOrder.has(d);

    function formatPct(value, total) {
        if (!total) return '';
        const p = (value / total) * 100;
        if (p > 0 && p < 0.5) return '<1%';
        const s = (p >= 10 ? p.toFixed(0) : p.toFixed(1));
        return s.replace(/\.0$/, '') + '%';
    }

    // Compute coverage statistics
    const coverage = computeParallelSetsCoverage(dims, dimOrder, nodes, links, getTraceType);
    const { N, coveredUp, coveredDown, accUp, accDown, outDegreeUp, outDegreeDown } = coverage;

    const maxN = Math.max(0, ...dims.map(d => N[d] || 0));
    if (maxN <= 0) {
        container.innerHTML = '<p style="text-align:center;padding:20px;">No traceability tags found.</p>';
        return;
    }

    // Calculate bar layout
    const layout = calculateParallelSetsBarLayout(dims, dimOrder, N, coveredUp, coveredDown, accDown);
    const { barHeights, barYOffsets, sourceToTargets } = layout;

    // Adjust canvas height
    let maxY = 0;
    dims.forEach(dim => {
        maxY = Math.max(maxY, barYOffsets[dim] + barHeights[dim]);
    });
    const naturalHeight = maxY + 20;
    const minHeight = DIAGRAM_CONFIG.PARALLEL_SETS.MIN_HEIGHT;
    const maxHeight = DIAGRAM_CONFIG.PARALLEL_SETS.MAX_HEIGHT;
    innerH = Math.min(maxHeight, Math.max(minHeight, naturalHeight));

    // Update SVG height
    height = margin.top + margin.bottom + innerH;
    svg.attr('height', height);
    container.style.height = height + 'px';
    container.style.minHeight = height + 'px';
    container.style.marginBottom = '20px';

    const x = d3.scalePoint().domain(dims).range([0, innerW]).padding(0.5);

    // Calculate band positions for ribbons
    const bands = calculateParallelSetsBands(dims, dimOrder, barYOffsets, barHeights, accUp, accDown, N);
    const { bandsUp, bandsDown } = bands;

    // Tooltip (reuse existing one if present, or create new)
    const tooltip = d3.select('body').selectAll('div.sankey-tooltip.parallelsets')
        .data([null])
        .join(
            enter => createTooltip('sankey-tooltip parallelsets')
        );

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

    let ribbonCounter = 0;
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

        // Use numeric index for gradient ID to ensure uniqueness
        const gradId = `type-grad-${safeId(containerId)}-ribbon-${ribbonCounter++}`;
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

        const bH = barHeights[d];
        const yOffset = barYOffsets[d];
        const upH = ((coveredUp[d] || 0) / total) * bH;
        const downH = ((coveredDown[d] || 0) / total) * bH;
        const upPct = formatPct(coveredUp[d] || 0, total);
        const downPct = formatPct(coveredDown[d] || 0, total);

        barGroup.append('text')
            .attr('x', x(d))
            .attr('y', yOffset - 10)
            .attr('text-anchor', 'middle')
            .attr('font-size', '12px')
            .attr('fill', '#333')
            .text(d);

        // Total nodes outline (with base fill to restore node color)
        barGroup.append('rect')
            .attr('x', barLeft(d))
            .attr('y', yOffset)
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
                .attr('y', yOffset)
                .attr('width', barW / 2)
                .attr('height', Math.max(0, upH))
                .attr('fill', colorScale(d))
                .attr('stroke', 'none');
        }
        if (downH > 0) {
            barGroup.append('rect')
                .attr('x', barLeft(d) + barW / 2)
                .attr('y', yOffset)
                .attr('width', barW / 2)
                .attr('height', Math.max(0, downH))
                .attr('fill', colorScale(d))
                .attr('stroke', 'none');
        }

        // Percent labels (upstream left, downstream right)
        if (upPct) {
            barGroup.append('text')
                .attr('x', barLeft(d) - 6)
                .attr('y', yOffset + Math.min(Math.max(10, upH / 2), Math.max(10, bH - 10)))
                .attr('dy', '0.35em')
                .attr('text-anchor', 'end')
                .attr('font-size', '11px')
                .attr('fill', '#333')
                .text(upPct);
        }
        if (downPct) {
            barGroup.append('text')
                .attr('x', barRight(d) + 6)
                .attr('y', yOffset + Math.min(Math.max(10, downH / 2), Math.max(10, bH - 10)))
                .attr('dy', '0.35em')
                .attr('text-anchor', 'start')
                .attr('font-size', '11px')
                .attr('fill', '#333')
                .text(downPct);
        }
    });
}

/**
 * Calculate Sankey diagram dimensions based on node counts
 * @param {Array} orderedTypes - Ordered array of trace types
 * @param {Map} nodesByType - Map of types to nodes
 * @param {Object} config - Configuration with nodeHeight, nodeGap, topPadding, bottomPadding
 * @returns {Object} Object with rows and height properties
 */
function calculateSankeyDimensions(orderedTypes, nodesByType, config) {
    const maxColumnCount = orderedTypes.reduce((max, t) => {
        const cnt = (nodesByType.get(t) || []).length;
        return cnt > max ? cnt : max;
    }, 0);

    const rows = Math.max(1, maxColumnCount);
    const height = config.topPadding + (rows * config.nodeHeight) +
                   Math.max(0, rows - 1) * config.nodeGap + config.bottomPadding;

    return { rows, height };
}

/**
 * Position nodes in a grid layout grouped by type
 * @param {Map} nodesByType - Map of types to nodes
 * @param {Array} orderedTypes - Ordered array of trace types
 * @param {number} width - Container width
 * @param {number} height - Container height
 * @param {Object} config - Configuration with nodeHeight, nodeGap, topPadding, bottomPadding, nodeWidth
 */
function positionNodesInGrid(nodesByType, orderedTypes, width, height, config) {
    const denom = Math.max(1, orderedTypes.length - 1);
    const availableH = Math.max(0, height - config.topPadding - config.bottomPadding);

    orderedTypes.forEach((type, typeIndex) => {
        const typeNodes = nodesByType.get(type) || [];
        let x = (typeIndex / denom) * (width - 40) + 20;
        const maxX = width - 20 - config.nodeWidth;
        if (x > maxX) x = maxX;

        const count = typeNodes.length;
        const columnHeight = count > 0 ?
            (count * config.nodeHeight + Math.max(0, count - 1) * config.nodeGap) : 0;
        const startY = config.topPadding + Math.max(0, (availableH - columnHeight) / 2);

        typeNodes.forEach((node, i) => {
            node.x0 = x;
            node.x1 = x + config.nodeWidth;
            node.y0 = startY + i * (config.nodeHeight + config.nodeGap);
            node.y1 = node.y0 + config.nodeHeight;
        });
    });
}

/**
 * Render Sankey diagram links with gradients
 * @param {Object} g - D3 group selection
 * @param {Object} svg - D3 SVG selection
 * @param {Array} visibleLinks - Array of visible links
 * @param {Function} colorScale - Color scale function
 * @param {Function} getTraceType - Function to get trace type from node
 * @param {string} containerId - Container element ID
 * @param {Object} tooltip - D3 tooltip selection
 */
function renderSankeyLinks(g, svg, visibleLinks, colorScale, getTraceType, containerId, tooltip) {
    const defs = svg.append('defs');
    const grads = defs.selectAll('linearGradient')
        .data(visibleLinks)
        .enter()
        .append('linearGradient')
        .attr('id', d => `grad-${containerId}-${d.visibleIndex}`)
        .attr('gradientUnits', 'userSpaceOnUse')
        .attr('x1', d => d.source && d.source.x1 != null ? d.source.x1 : 0)
        .attr('y1', d => d.source ? (d.source.y0 + d.source.y1) / 2 : 0)
        .attr('x2', d => d.target && d.target.x0 != null ? d.target.x0 : 0)
        .attr('y2', d => d.target ? (d.target.y0 + d.target.y1) / 2 : 0);

    grads.append('stop').attr('offset', '0%')
        .attr('stop-color', d => colorScale(getTraceType(d.source && d.source.trace_target, d.source && d.source.layer_id)));
    grads.append('stop').attr('offset', '100%')
        .attr('stop-color', d => colorScale(getTraceType(d.target && d.target.trace_target, d.target && d.target.layer_id)));

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
        .attr('stroke', d => `url(#grad-${containerId}-${d.visibleIndex})`)
        .attr('stroke-width', d => Math.max(1, d.width || 2))
        .attr('fill', 'none')
        .attr('opacity', 0.6)
        .on('mouseover', function(event, d) {
            d3.select(this).attr('opacity', 1);
            tooltip.style('visibility', 'visible')
                .html(`<strong>${d.source.id} → ${d.target.id}</strong><br>Value: ${d.rawValue != null ? d.rawValue : d.value}`);
        })
        .on('mousemove', function(event) {
            tooltip.style('top', (event.pageY + DIAGRAM_CONFIG.TOOLTIP.OFFSET_Y) + 'px')
                .style('left', (event.pageX + DIAGRAM_CONFIG.TOOLTIP.OFFSET_X) + 'px');
        })
        .on('mouseout', function() {
            d3.select(this).attr('opacity', 0.6);
            tooltip.style('visibility', 'hidden');
        });
}

/**
 * Render Sankey diagram nodes with interactivity
 * @param {Object} g - D3 group selection
 * @param {Array} nodes - Array of nodes
 * @param {Function} colorScale - Color scale function
 * @param {Function} getTraceType - Function to get trace type from node
 * @param {Object} tooltip - D3 tooltip selection
 */
function renderSankeyNodes(g, nodes, colorScale, getTraceType, tooltip) {
    g.append('g')
        .attr('class', 'nodes')
        .selectAll('rect')
        .data(nodes)
        .enter()
        .append('rect')
        .attr('x', d => d.x0)
        .attr('y', d => d.y0)
        .attr('height', d => d.y1 - d.y0)
        .attr('width', d => d.x1 - d.x0)
        .attr('fill', d => colorScale(getTraceType(d.trace_target, d.layer_id)))
        .attr('stroke', DIAGRAM_CONFIG.COLORS.STROKE)
        .attr('stroke-width', 1)
        .style('cursor', 'pointer')
        .on('click', function(event, d) {
            if (typeof showText === 'function') {
                const filePath = resolveFilePath(d, traceabilityData);
                if (!filePath) {
                    console.error('Cannot determine file path for node:', d);
                    return;
                }
                const baseName = getBaseName(filePath);
                const filename = 'Target_' + baseName.replace(/\./g, '_');
                const extension = getFileExtension(filePath);
                const tagId = d.id || '';
                const tagDescription = d.description || '';
                const layerName = (d.layer_id !== undefined && traceabilityData.layers && traceabilityData.layers[d.layer_id])
                    ? traceabilityData.layers[d.layer_id].name : '';
                const fromTags = (d.from_tags || []).filter(t => t && t !== 'NONE').join(',');
                showText(event, filename, d.line, extension, tagId, tagDescription, layerName, fromTags);
            }
        })
        .on('mouseover', function(event, d) {
            d3.select(this).attr('stroke-width', 2);
            const filePath = resolveFilePath(d, traceabilityData);
            tooltip.style('visibility', 'visible')
                .html(`<strong>${d.id}</strong><br>` +
                      `Type: ${getTraceType(d.trace_target, d.layer_id)}<br>` +
                      `File: ${filePath || 'unknown'}:${d.line}<br>` +
                      `<em>${d.description}</em>`);
        })
        .on('mousemove', function(event) {
            tooltip.style('top', (event.pageY + DIAGRAM_CONFIG.TOOLTIP.OFFSET_Y) + 'px')
                .style('left', (event.pageX + DIAGRAM_CONFIG.TOOLTIP.OFFSET_X) + 'px');
        })
        .on('mouseout', function() {
            d3.select(this).attr('stroke-width', 1);
            tooltip.style('visibility', 'hidden');
        });
}

/**
 * Render node labels for Sankey diagram
 * @param {Object} g - D3 group selection
 * @param {Array} nodes - Array of nodes
 * @param {number} width - Container width
 */
function renderSankeyLabels(g, nodes, width) {
    const labelGroups = g.append('g')
        .attr('class', 'node-labels')
        .selectAll('g')
        .data(nodes)
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
        .attr('fill', DIAGRAM_CONFIG.COLORS.TEXT)
        .text(d => d.id);
}

function renderSankeyDiagram(containerId, nodes, links, colorScale, getTraceType, typeOrder) {
    const container = document.getElementById(containerId);
    const width = container.clientWidth;

    // Configuration for diagram sizing
    const config = {
        nodeHeight: DIAGRAM_CONFIG.SANKEY.NODE_HEIGHT,
        nodeGap: DIAGRAM_CONFIG.SANKEY.NODE_GAP,
        topPadding: DIAGRAM_CONFIG.SANKEY.TOP_PADDING,
        bottomPadding: DIAGRAM_CONFIG.SANKEY.BOTTOM_PADDING,
        nodeWidth: DIAGRAM_CONFIG.SANKEY.NODE_WIDTH
    };

    // Group nodes by type and determine ordering
    const nodesByType = d3.group(nodes, d => getTraceType(d.trace_target, d.layer_id));
    const presentTypes = Array.from(nodesByType.keys());

    // Use caller-provided order (from config), or extract dynamically from data
    let orderedTypes = (Array.isArray(typeOrder) && typeOrder.length > 0) ? [...typeOrder] : [...presentTypes];
    // Append any missing types not in the provided order
    if (Array.isArray(typeOrder) && typeOrder.length > 0) {
        presentTypes.forEach(t => {
            if (!orderedTypes.includes(t)) orderedTypes.push(t);
        });
    }

    // Calculate diagram dimensions
    const { rows, height } = calculateSankeyDimensions(orderedTypes, nodesByType, config);

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

    // Position nodes in a custom grid layout grouped by type
    positionNodesInGrid(nodesByType, orderedTypes, width, height, config);

    // Ensure SVG/container match the computed height
    svg.attr('height', height);
    container.style.height = height + 'px';
    container.style.minHeight = height + 'px';
    container.style.marginBottom = '20px';

    // Create tooltip
    const tooltip = createTooltip('sankey-tooltip');

    // Prepare and render links
    const linksToRender = prepareLinksForRendering(links, nodes);
    const visibleLinks = filterVisibleLinks(linksToRender);
    renderSankeyLinks(g, svg, visibleLinks, colorScale, getTraceType, containerId, tooltip);

    // Adjust SVG height if needed based on actual node positions
    try {
        const yMin = nodes.reduce((min, n) => Math.min(min, n.y0 != null ? n.y0 : Infinity), Infinity);
        const yMax = nodes.reduce((max, n) => Math.max(max, n.y1 != null ? n.y1 : -Infinity), -Infinity);
        if (isFinite(yMin) && isFinite(yMax)) {
            const padding = 40;
            const currentSvgHeight = +svg.attr('height') || height;
            const requiredHeight = Math.max(currentSvgHeight, height, Math.ceil(yMax + padding));
            svg.attr('height', requiredHeight);
            container.style.height = requiredHeight + 'px';
            container.style.minHeight = requiredHeight + 'px';
        }
    } catch (e) {
        console.warn('Could not compute dynamic SVG height:', e);
    }

    // Render nodes and labels
    renderSankeyNodes(g, nodes, colorScale, getTraceType, tooltip);
    renderSankeyLabels(g, nodes, width);
}

function renderSankey(data) {
		// Function to extract type from trace_target (safe)
        const getTraceType = traceTypeFromTraceTarget;

		// Use trace target order from config.md if available, otherwise extract from nodes
		let types = [];
		if (typeof traceTargetOrder !== 'undefined' && Array.isArray(traceTargetOrder) && traceTargetOrder.length > 0) {
			// Use config.md order and filter to only types present in nodes
			const nodesTypes = new Set();
			(data.trace_tags || data.nodes || []).forEach(n => {
				const t = getTraceType(n && n.trace_target, n && n.layer_id);
				if (t && t !== 'Unknown') nodesTypes.add(t);
			});
			types = traceTargetOrder.filter(t => nodesTypes.has(t));
		} else {
			// Fallback: extract unique trace types from nodes in order of first appearance
			const seenTypes = new Set();
			(data.trace_tags || data.nodes || []).forEach(n => {
				const t = getTraceType(n && n.trace_target, n && n.layer_id);
				if (t && t !== 'Unknown' && !seenTypes.has(t)) {
					seenTypes.add(t);
					types.push(t);
				}
			});
		}

		// Use global color mapping for consistency across all diagrams
		const colorScale = d3.scaleOrdinal()
				.domain(types)
				.range(types.map(t => traceTypeColor(t)));

        // Legends and top-of-page metadata
        renderLegend('sankey-legend-full');
        renderLegend('sankey-legend-type');
        annotateTraceTargets(data);
        annotateMatrixBadges();
        renderSummary(data);
        renderHealth(data);
        // Re-apply badge colors after renderHealth creates isolated/dangling badges
        annotateMatrixBadges();

		// Prepare nodes and links for full diagram
		const sankeyNodes = (data.trace_tags || data.nodes || []).map((d, i) => ({ ...d, index: i }));
		const nodeIndexMap = new Map(sankeyNodes.map((node, i) => [node.id, i]));


		// Derive links from trace_tags using from_tags array
		const derivedLinks = (data.trace_tags || data.nodes || [])
			.flatMap(tag => (tag.from_tags || [])
				.filter(ft => ft && ft !== 'NONE')
				.map(ft => ({ source: ft, target: tag.id })));

		const sankeyLinks = derivedLinks.map(d => ({
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
        renderSankeyDiagram('sankey-diagram-full', sankeyNodes, sankeyLinks, colorScale, getTraceType, types);

		// Render type diagram as Parallel Sets (direct-link coverage; matches `--summary` definition)
		// Use the same derived links for consistency with v0.2.0 format
		const directLinks = derivedLinks
				.map(d => ({
						...d,
						source: nodeIndexMap.get(d.source),
						target: nodeIndexMap.get(d.target)
				}))
				.filter(l => typeof l.source === 'number' && typeof l.target === 'number');

		renderParallelSetsRequirements('sankey-diagram-type', sankeyNodes, directLinks, colorScale, getTraceType);
}

