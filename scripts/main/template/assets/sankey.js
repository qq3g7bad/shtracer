// sankey.js - D3.js Sankey diagram for shtracer
// Loads JSON data and renders interactive traceability flow diagram

document.addEventListener('DOMContentLoaded', function() {
    // Fetch the JSON data
    fetch('./output.json')
        .then(response => {
            if (!response.ok) {
                throw new Error('Failed to load JSON data');
            }
            return response.json();
        })
        .then(data => {
            renderSankey(data);
        })
        .catch(error => {
            console.error('Error loading JSON:', error);
            document.getElementById('sankey-diagram').innerHTML =
                '<p style="color: red; text-align: center; padding: 20px;">' +
                'Error loading traceability data. Please ensure output.json exists.</p>';
        });
});

function renderSankey(data) {
    const container = document.getElementById('sankey-diagram');
    const width = container.clientWidth;
    const height = 600;

    // Clear any existing content
    container.innerHTML = '';

    // Create SVG
    const svg = d3.select('#sankey-diagram')
        .append('svg')
        .attr('width', width)
        .attr('height', height);

    // Create a group for the sankey diagram
    const g = svg.append('g')
        .attr('transform', 'translate(10,10)');

    // Color scale for trace targets
    const colorScale = d3.scaleOrdinal()
        .domain(['Requirement', 'Architecture', 'Implementation', 'Unit test', 'Integration test'])
        .range(['#ff7f7f', '#7f7fff', '#7fff7f', '#ffff7f', '#ff7fff']);

    // Build node index map
    const nodeMap = new Map();
    data.nodes.forEach((node, index) => {
        nodeMap.set(node.id, index);
    });

    // Convert links to use indices
    const links = data.links.map(link => ({
        source: nodeMap.get(link.source),
        target: nodeMap.get(link.target),
        value: link.value
    }));

    // Create Sankey layout
    const sankey = d3.sankey()
        .nodeWidth(15)
        .nodePadding(10)
        .extent([[5, 5], [width - 20, height - 20]])
        .nodeId(d => d.id);

    // Generate the sankey data
    const {nodes: sankeyNodes, links: sankeyLinks} = sankey({
        nodes: data.nodes.map(d => Object.assign({}, d)),
        links: links
    });

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
    g.append('g')
        .attr('class', 'links')
        .selectAll('path')
        .data(sankeyLinks)
        .enter()
        .append('path')
        .attr('d', d3.sankeyLinkHorizontal())
        .attr('stroke', '#999')
        .attr('stroke-width', d => Math.max(1, d.width))
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

    // Draw nodes
    const node = g.append('g')
        .attr('class', 'nodes')
        .selectAll('rect')
        .data(sankeyNodes)
        .enter()
        .append('rect')
        .attr('x', d => d.x0)
        .attr('y', d => d.y0)
        .attr('height', d => d.y1 - d.y0)
        .attr('width', d => d.x1 - d.x0)
        .attr('fill', d => colorScale(d.trace_target))
        .attr('stroke', '#333')
        .attr('stroke-width', 1)
        .style('cursor', 'pointer')
        .on('click', function(event, d) {
            // Use the existing showText function to display file content
            if (typeof showText === 'function') {
                showText(d.file, d.line);
            }
        })
        .on('mouseover', function(event, d) {
            d3.select(this).attr('stroke-width', 2);
            tooltip.style('visibility', 'visible')
                .html(`<strong>${d.id}</strong><br>` +
                      `Type: ${d.trace_target}<br>` +
                      `File: ${d.file}:${d.line}<br>` +
                      `<em>${d.description}</em>`);
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
    g.append('g')
        .attr('class', 'node-labels')
        .selectAll('text')
        .data(sankeyNodes)
        .enter()
        .append('text')
        .attr('x', d => d.x0 < width / 2 ? d.x1 + 6 : d.x0 - 6)
        .attr('y', d => (d.y0 + d.y1) / 2)
        .attr('dy', '0.35em')
        .attr('text-anchor', d => d.x0 < width / 2 ? 'start' : 'end')
        .attr('font-size', '10px')
        .attr('fill', '#333')
        .text(d => d.id)
        .style('pointer-events', 'none');

    // Add legend
    const legend = svg.append('g')
        .attr('class', 'legend')
        .attr('transform', `translate(20, ${height - 100})`);

    const legendData = [
        {type: 'Requirement', color: '#ff7f7f'},
        {type: 'Architecture', color: '#7f7fff'},
        {type: 'Implementation', color: '#7fff7f'},
        {type: 'Unit test', color: '#ffff7f'},
        {type: 'Integration test', color: '#ff7fff'}
    ];

    legend.selectAll('rect')
        .data(legendData)
        .enter()
        .append('rect')
        .attr('x', 0)
        .attr('y', (d, i) => i * 15)
        .attr('width', 12)
        .attr('height', 12)
        .attr('fill', d => d.color);

    legend.selectAll('text')
        .data(legendData)
        .enter()
        .append('text')
        .attr('x', 18)
        .attr('y', (d, i) => i * 15 + 9)
        .attr('font-size', '11px')
        .attr('fill', '#333')
        .text(d => d.type);
}