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

function renderSankey(data) {
    // Color scale for trace targets - more distinct colors
    const colorScale = d3.scaleOrdinal()
        .domain(['Requirement', 'Architecture', 'Implementation', 'Unit test', 'Integration test'])
        .range(['#e74c3c', '#3498db', '#2ecc71', '#f39c12', '#9b59b6']); // More distinct colors

    // Function to extract type from trace_target (safe)
    const getTraceType = (traceTarget) => {
        if (!traceTarget) return 'Unknown';
        const parts = String(traceTarget).split(':');
        return parts[parts.length - 1].trim();
    };

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
        // Reserve at least the SVG height, but allow the container to grow
        // (e.g., legend div) so following sections never overlap.
        container.style.height = 'auto';
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
            // Update svg and reserve at least that height; allow container to grow for legend.
            svg.attr('height', requiredHeight);
            container.style.height = 'auto';
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

    // Add legend as an HTML element below the SVG to avoid adding extra whitespace inside the SVG
    const legendData = [
        {type: 'Requirement', color: '#e74c3c'},
        {type: 'Architecture', color: '#3498db'},
        {type: 'Implementation', color: '#2ecc71'},
        {type: 'Unit test', color: '#f39c12'},
        {type: 'Integration test', color: '#9b59b6'},
        {type: 'Unknown', color: '#7f8c8d'}
    ];

    const containerDiv = d3.select('#' + containerId);
    const legendDiv = containerDiv.append('div')
        .attr('class', 'sankey-legend')
        .style('display', 'flex')
        .style('gap', '12px')
        .style('flex-wrap', 'wrap')
        .style('margin-top', '10px')
        .style('align-items', 'center');

    const legendItems = legendDiv.selectAll('.legend-item')
        .data(legendData)
        .enter()
        .append('div')
        .attr('class', 'legend-item')
        .style('display', 'flex')
        .style('align-items', 'center')
        .style('margin-right', '12px');

    legendItems.append('span')
        .style('display', 'inline-block')
        .style('width', '12px')
        .style('height', '12px')
        .style('background-color', d => d.color)
        .style('margin-right', '6px')
        .style('border', '1px solid #333');

    legendItems.append('span')
        .style('font-size', '11px')
        .style('color', '#333')
        .text(d => d.type);
}
