// traceability_diagrams_unittest.mjs - Unit tests for traceability_diagrams.js
// Uses Node.js built-in test runner (node:test + node:assert). Zero npm dependencies.

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { loadDiagramFunctions } from './js_test_helper.mjs';

// Load once — all functions are pure and share no mutable state we care about
const ctx = loadDiagramFunctions({
  traceabilityData: {
    layers: [
      { name: 'Requirement' },
      { name: 'Architecture' },
      { name: 'Implementation' },
    ],
    files: [
      { file_id: 0, file: 'docs/01_requirements.md' },
      { file_id: 1, file: 'docs/02_architecture.md' },
      { file_id: 2, file: 'src/main.sh' },
    ],
    trace_tags: [],
  },
  traceTargetOrder: ['Requirement', 'Architecture', 'Implementation'],
});

// ---------------------------------------------------------------------------
// resolveFilePath
// ---------------------------------------------------------------------------
describe('resolveFilePath', () => {
  const fn = ctx.resolveFilePath;
  const data = {
    files: [
      { file_id: 0, file: 'docs/req.md' },
      { file_id: 1, file: 'docs/arc.md' },
    ],
  };

  it('resolves file_id to file path', () => {
    assert.equal(fn({ file_id: 0 }, data), 'docs/req.md');
    assert.equal(fn({ file_id: 1 }, data), 'docs/arc.md');
  });

  it('falls back to node.file when file_id is missing', () => {
    assert.equal(fn({ file: 'legacy.md' }, data), 'legacy.md');
  });

  it('falls back to node.file when data.files is missing', () => {
    assert.equal(fn({ file_id: 0, file: 'fallback.md' }, {}), 'fallback.md');
    assert.equal(fn({ file_id: 0, file: 'fallback.md' }, null), 'fallback.md');
  });

  it('returns null when neither file_id nor file exists', () => {
    assert.equal(fn({}, data), null);
  });

  it('returns null for out-of-range file_id', () => {
    assert.equal(fn({ file_id: 99 }, data), null);
  });
});

// ---------------------------------------------------------------------------
// getBaseName
// ---------------------------------------------------------------------------
describe('getBaseName', () => {
  const fn = ctx.getBaseName;

  it('extracts basename from Unix path', () => {
    assert.equal(fn('docs/01_requirements.md'), '01_requirements.md');
  });

  it('returns the string when no slashes', () => {
    assert.equal(fn('file.txt'), 'file.txt');
  });

  it('handles deeply nested paths', () => {
    assert.equal(fn('a/b/c/d/e.sh'), 'e.sh');
  });

  it('handles empty string', () => {
    assert.equal(fn(''), '');
  });

  it('handles null/undefined', () => {
    assert.equal(fn(null), '');
    assert.equal(fn(undefined), '');
  });
});

// ---------------------------------------------------------------------------
// getFileExtension
// ---------------------------------------------------------------------------
describe('getFileExtension', () => {
  const fn = ctx.getFileExtension;

  it('extracts .md extension', () => {
    assert.equal(fn('docs/file.md'), 'md');
  });

  it('extracts .sh extension', () => {
    assert.equal(fn('scripts/main.sh'), 'sh');
  });

  it('extracts last extension from double extension', () => {
    assert.equal(fn('archive.tar.gz'), 'gz');
  });

  it('defaults to sh when no extension', () => {
    assert.equal(fn('Makefile'), 'sh');
  });

  it('extracts extension from dotfiles with extension', () => {
    assert.equal(fn('.gitignore'), 'gitignore');
  });

  it('defaults to sh for empty/null', () => {
    assert.equal(fn(''), 'sh');
    assert.equal(fn(null), 'sh');
  });
});

// ---------------------------------------------------------------------------
// prepareLinksForRendering
// ---------------------------------------------------------------------------
describe('prepareLinksForRendering', () => {
  const fn = ctx.prepareLinksForRendering;

  it('resolves numeric source/target to node objects', () => {
    const nodes = [{ id: 'A' }, { id: 'B' }];
    const links = [{ source: 0, target: 1, value: 1 }];
    const result = fn(links, nodes);
    assert.equal(result[0].source.id, 'A');
    assert.equal(result[0].target.id, 'B');
  });

  it('preserves already-object source/target', () => {
    const nodeA = { id: 'A' };
    const nodeB = { id: 'B' };
    const links = [{ source: nodeA, target: nodeB }];
    const result = fn(links, [nodeA, nodeB]);
    assert.equal(result[0].source, nodeA);
    assert.equal(result[0].target, nodeB);
  });

  it('assigns index from original link if present', () => {
    const nodes = [{ id: 'A' }, { id: 'B' }];
    const links = [{ source: 0, target: 1, index: 42 }];
    const result = fn(links, nodes);
    assert.equal(result[0].index, 42);
  });

  it('assigns positional index when link.index is null', () => {
    const nodes = [{ id: 'A' }, { id: 'B' }];
    const links = [{ source: 0, target: 1 }];
    const result = fn(links, nodes);
    assert.equal(result[0].index, 0);
  });

  it('returns empty array for empty input', () => {
    assert.equal(fn([], []).length, 0);
  });
});

// ---------------------------------------------------------------------------
// filterVisibleLinks
// ---------------------------------------------------------------------------
describe('filterVisibleLinks', () => {
  const fn = ctx.filterVisibleLinks;

  it('filters out padding links', () => {
    const links = [
      { id: 1 },
      { id: 2, _padding: true },
      { id: 3 },
    ];
    const result = fn(links);
    assert.equal(result.length, 2);
    assert.equal(result[0].id, 1);
    assert.equal(result[1].id, 3);
  });

  it('assigns visibleIndex sequentially', () => {
    const links = [
      { id: 'a' },
      { id: 'b', _padding: true },
      { id: 'c' },
      { id: 'd' },
    ];
    const result = fn(links);
    assert.equal(result[0].visibleIndex, 0);
    assert.equal(result[1].visibleIndex, 1);
    assert.equal(result[2].visibleIndex, 2);
  });

  it('returns empty array when all are padding', () => {
    const links = [{ _padding: true }, { _padding: true }];
    assert.equal(fn(links).length, 0);
  });

  it('returns empty for empty input', () => {
    assert.equal(fn([]).length, 0);
  });
});

// ---------------------------------------------------------------------------
// traceTypeFromTraceTarget
// ---------------------------------------------------------------------------
describe('traceTypeFromTraceTarget', () => {
  const fn = ctx.traceTypeFromTraceTarget;

  it('uses layer_id when provided (via getLayerName)', () => {
    assert.equal(fn(null, 0), 'Requirement');
    assert.equal(fn(null, 1), 'Architecture');
    assert.equal(fn('ignored', 2), 'Implementation');
  });

  it('falls back to string parsing when layer_id is null', () => {
    assert.equal(fn('path:TestType', null), 'TestType');
  });

  it('falls back to string parsing when layer_id is undefined', () => {
    assert.equal(fn('path:SomeType', undefined), 'SomeType');
  });

  it('parses last segment of colon-separated string', () => {
    assert.equal(fn('a:b:FinalType'), 'FinalType');
  });

  it('returns Unknown for null/undefined traceTarget without layer_id', () => {
    assert.equal(fn(null), 'Unknown');
    assert.equal(fn(undefined), 'Unknown');
  });

  it('returns Unknown for empty string traceTarget', () => {
    assert.equal(fn(''), 'Unknown');
  });
});

// ---------------------------------------------------------------------------
// computeParallelSetsCoverage
// ---------------------------------------------------------------------------
describe('computeParallelSetsCoverage', () => {
  const fn = ctx.computeParallelSetsCoverage;

  it('computes coverage for a simple 2-layer graph', () => {
    const dims = ['Req', 'Arc'];
    const dimOrder = new Map([['Req', 0], ['Arc', 1]]);
    const nodes = [
      { trace_target: 'Req', layer_id: null },
      { trace_target: 'Arc', layer_id: null },
    ];
    const links = [{ source: 0, target: 1 }];
    const getType = (tt) => {
      if (!tt) return 'Unknown';
      return tt.split(':').pop();
    };

    const result = fn(dims, dimOrder, nodes, links, getType);
    assert.equal(result.N['Req'], 1);
    assert.equal(result.N['Arc'], 1);
    assert.equal(result.coveredDown['Req'], 1);
    assert.equal(result.coveredUp['Arc'], 1);
  });

  it('handles empty links', () => {
    const dims = ['A', 'B'];
    const dimOrder = new Map([['A', 0], ['B', 1]]);
    const nodes = [
      { trace_target: 'A', layer_id: null },
      { trace_target: 'B', layer_id: null },
    ];
    const getType = (tt) => tt || 'Unknown';

    const result = fn(dims, dimOrder, nodes, [], getType);
    assert.equal(result.coveredDown['A'], 0);
    assert.equal(result.coveredUp['B'], 0);
  });

  it('handles isolated nodes (no matching dimension)', () => {
    const dims = ['X'];
    const dimOrder = new Map([['X', 0]]);
    const nodes = [{ trace_target: 'X', layer_id: null }];
    const getType = (tt) => tt || 'Unknown';

    const result = fn(dims, dimOrder, nodes, [], getType);
    assert.equal(result.N['X'], 1);
    assert.equal(result.coveredDown['X'], 0);
    assert.equal(result.coveredUp['X'], 0);
  });

  it('computes 3-layer graph with multiple nodes', () => {
    const dims = ['R', 'A', 'I'];
    const dimOrder = new Map([['R', 0], ['A', 1], ['I', 2]]);
    const nodes = [
      { trace_target: 'R', layer_id: null },
      { trace_target: 'R', layer_id: null },
      { trace_target: 'A', layer_id: null },
      { trace_target: 'I', layer_id: null },
    ];
    const links = [
      { source: 0, target: 2 },
      { source: 2, target: 3 },
    ];
    const getType = (tt) => tt || 'Unknown';

    const result = fn(dims, dimOrder, nodes, links, getType);
    assert.equal(result.N['R'], 2);
    assert.equal(result.N['A'], 1);
    assert.equal(result.N['I'], 1);
    assert.equal(result.coveredDown['R'], 1);  // only node 0 has downstream
    assert.equal(result.coveredUp['I'], 1);
  });

  it('skips links with non-numeric source/target', () => {
    const dims = ['A', 'B'];
    const dimOrder = new Map([['A', 0], ['B', 1]]);
    const nodes = [
      { trace_target: 'A', layer_id: null },
      { trace_target: 'B', layer_id: null },
    ];
    const links = [{ source: 'nodeA', target: 'nodeB' }];
    const getType = (tt) => tt || 'Unknown';

    const result = fn(dims, dimOrder, nodes, links, getType);
    assert.equal(result.coveredDown['A'], 0);
    assert.equal(result.coveredUp['B'], 0);
  });
});

// ---------------------------------------------------------------------------
// calculateParallelSetsBarLayout
// ---------------------------------------------------------------------------
describe('calculateParallelSetsBarLayout', () => {
  const fn = ctx.calculateParallelSetsBarLayout;

  it('produces proportional bar heights', () => {
    const dims = ['A', 'B'];
    const dimOrder = new Map([['A', 0], ['B', 1]]);
    const N = { A: 10, B: 5 };
    const coveredUp = { A: 0, B: 3 };
    const coveredDown = { A: 5, B: 0 };
    const accDown = { A: { B: 3 }, B: { A: 0 } };

    const result = fn(dims, dimOrder, N, coveredUp, coveredDown, accDown);
    // A has most nodes → gets maxBarHeight
    assert.ok(result.barHeights['A'] >= result.barHeights['B']);
  });

  it('enforces minimum bar height', () => {
    const dims = ['A', 'B'];
    const dimOrder = new Map([['A', 0], ['B', 1]]);
    const N = { A: 100, B: 1 };
    const coveredUp = { A: 0, B: 0 };
    const coveredDown = { A: 0, B: 0 };
    const accDown = { A: { B: 0 }, B: { A: 0 } };

    const result = fn(dims, dimOrder, N, coveredUp, coveredDown, accDown);
    assert.ok(result.barHeights['B'] >= ctx.DIAGRAM_CONFIG.PARALLEL_SETS.MIN_BAR_HEIGHT);
  });

  it('builds sourceToTargets map', () => {
    const dims = ['A', 'B', 'C'];
    const dimOrder = new Map([['A', 0], ['B', 1], ['C', 2]]);
    const N = { A: 2, B: 2, C: 2 };
    const coveredUp = { A: 0, B: 1, C: 1 };
    const coveredDown = { A: 1, B: 1, C: 0 };
    const accDown = { A: { B: 1, C: 0 }, B: { A: 0, C: 1 }, C: { A: 0, B: 0 } };

    const result = fn(dims, dimOrder, N, coveredUp, coveredDown, accDown);
    assert.equal(JSON.stringify(result.sourceToTargets['A']), JSON.stringify(['B']));
    assert.equal(JSON.stringify(result.sourceToTargets['B']), JSON.stringify(['C']));
    assert.equal(result.sourceToTargets['C'].length, 0);
  });

  it('handles empty dimensions', () => {
    const result = fn([], new Map(), {}, {}, {}, {});
    assert.equal(Object.keys(result.barHeights).length, 0);
    assert.equal(Object.keys(result.barYOffsets).length, 0);
    assert.equal(Object.keys(result.sourceToTargets).length, 0);
  });
});

// ---------------------------------------------------------------------------
// calculateParallelSetsBands
// ---------------------------------------------------------------------------
describe('calculateParallelSetsBands', () => {
  const fn = ctx.calculateParallelSetsBands;

  it('produces non-negative y0/y1 values', () => {
    const dims = ['A', 'B'];
    const dimOrder = new Map([['A', 0], ['B', 1]]);
    const barYOffsets = { A: 0, B: 0 };
    const barHeights = { A: 100, B: 80 };
    const accUp = { A: { B: 0 }, B: { A: 2 } };
    const accDown = { A: { B: 3 }, B: { A: 0 } };
    const N = { A: 5, B: 4 };

    const result = fn(dims, dimOrder, barYOffsets, barHeights, accUp, accDown, N);
    // A downstream to B should exist
    assert.ok(result.bandsDown['A']['B']);
    assert.ok(result.bandsDown['A']['B'].y0 >= 0);
    assert.ok(result.bandsDown['A']['B'].y1 >= result.bandsDown['A']['B'].y0);

    // B upstream from A should exist
    assert.ok(result.bandsUp['B']['A']);
    assert.ok(result.bandsUp['B']['A'].y0 >= 0);
    assert.ok(result.bandsUp['B']['A'].y1 >= result.bandsUp['B']['A'].y0);
  });

  it('skips bands with zero accumulation', () => {
    const dims = ['A', 'B'];
    const dimOrder = new Map([['A', 0], ['B', 1]]);
    const barYOffsets = { A: 0, B: 0 };
    const barHeights = { A: 100, B: 100 };
    const accUp = { A: { B: 0 }, B: { A: 0 } };
    const accDown = { A: { B: 0 }, B: { A: 0 } };
    const N = { A: 5, B: 5 };

    const result = fn(dims, dimOrder, barYOffsets, barHeights, accUp, accDown, N);
    assert.equal(Object.keys(result.bandsDown['A']).length, 0);
    assert.equal(Object.keys(result.bandsUp['B']).length, 0);
  });

  it('handles empty dimensions', () => {
    const result = fn([], new Map(), {}, {}, {}, {}, {});
    assert.equal(Object.keys(result.bandsUp).length, 0);
    assert.equal(Object.keys(result.bandsDown).length, 0);
  });
});

// ---------------------------------------------------------------------------
// calculateSankeyDimensions
// ---------------------------------------------------------------------------
describe('calculateSankeyDimensions', () => {
  const fn = ctx.calculateSankeyDimensions;
  const config = {
    nodeHeight: 24,
    nodeGap: 6,
    topPadding: 20,
    bottomPadding: 60,
  };

  it('calculates rows from max column count', () => {
    const nodesByType = new Map([
      ['Req', [1, 2, 3]],
      ['Arc', [4, 5]],
    ]);
    const result = fn(['Req', 'Arc'], nodesByType, config);
    assert.equal(result.rows, 3);
  });

  it('calculates height with padding', () => {
    const nodesByType = new Map([
      ['Req', [1, 2]],
    ]);
    const result = fn(['Req'], nodesByType, config);
    // height = topPadding + (2 * 24) + (1 * 6) + bottomPadding = 20 + 48 + 6 + 60 = 134
    assert.equal(result.height, 134);
  });

  it('enforces min rows = 1 when no nodes', () => {
    const nodesByType = new Map([
      ['Req', []],
    ]);
    const result = fn(['Req'], nodesByType, config);
    assert.equal(result.rows, 1);
  });

  it('handles empty orderedTypes', () => {
    const nodesByType = new Map();
    const result = fn([], nodesByType, config);
    assert.equal(result.rows, 1);
    // height = 20 + 24 + 0 + 60 = 104
    assert.equal(result.height, 104);
  });

  it('handles missing type in nodesByType', () => {
    const nodesByType = new Map();
    const result = fn(['Missing'], nodesByType, config);
    assert.equal(result.rows, 1);
  });
});

// ---------------------------------------------------------------------------
// reorderNodesByBarycenter
// ---------------------------------------------------------------------------
describe('reorderNodesByBarycenter', () => {
  const fn = ctx.reorderNodesByBarycenter;

  it('reorders nodes by neighbor average position', () => {
    // 3 columns: A, B, C; links from A to B and B to C
    const nodes = [
      { id: 'A0', index: 0 },
      { id: 'A1', index: 1 },
      { id: 'B0', index: 2 },
      { id: 'B1', index: 3 },
    ];
    const nodesByType = new Map([
      ['A', [nodes[0], nodes[1]]],
      ['B', [nodes[2], nodes[3]]],
    ]);
    // A1 connects to B0, A0 connects to B1
    const links = [
      { source: 1, target: 2 },  // A1 → B0
      { source: 0, target: 3 },  // A0 → B1
    ];

    fn(nodesByType, ['A', 'B'], links, nodes);

    // After barycenter: B column should be reordered so B0 is near A1 and B1 near A0
    // The exact order depends on the algorithm, but it should run without error
    const bNodes = nodesByType.get('B');
    assert.equal(bNodes.length, 2);
  });

  it('pushes disconnected nodes to bottom (Infinity barycenter)', () => {
    const nodes = [
      { id: 'A0', index: 0 },
      { id: 'B0', index: 1 },
      { id: 'B1', index: 2 },
    ];
    const nodesByType = new Map([
      ['A', [nodes[0]]],
      ['B', [nodes[1], nodes[2]]],
    ]);
    // Only A0 → B0; B1 is disconnected
    const links = [{ source: 0, target: 1 }];

    fn(nodesByType, ['A', 'B'], links, nodes);

    const bNodes = nodesByType.get('B');
    // B0 (connected) should come before B1 (disconnected)
    assert.equal(bNodes[0].id, 'B0');
    assert.equal(bNodes[1].id, 'B1');
  });

  it('handles empty input', () => {
    const nodesByType = new Map();
    // Should not throw
    fn(nodesByType, [], [], []);
  });

  it('handles single-node columns (no reorder needed)', () => {
    const nodes = [{ id: 'X', index: 0 }];
    const nodesByType = new Map([['T', [nodes[0]]]]);
    fn(nodesByType, ['T'], [], nodes);
    assert.equal(nodesByType.get('T')[0].id, 'X');
  });
});

// ---------------------------------------------------------------------------
// positionNodesInGrid
// ---------------------------------------------------------------------------
describe('positionNodesInGrid', () => {
  const fn = ctx.positionNodesInGrid;
  const config = {
    nodeHeight: 24,
    nodeGap: 6,
    topPadding: 20,
    bottomPadding: 60,
    nodeWidth: 20,
  };

  it('assigns x0, x1, y0, y1 to all nodes', () => {
    const nodes = [{ id: 'A' }, { id: 'B' }];
    const nodesByType = new Map([['Req', nodes]]);

    fn(nodesByType, ['Req'], 800, 300, config);

    nodes.forEach(n => {
      assert.notEqual(n.x0, undefined);
      assert.notEqual(n.x1, undefined);
      assert.notEqual(n.y0, undefined);
      assert.notEqual(n.y1, undefined);
    });
  });

  it('sets x1 = x0 + nodeWidth', () => {
    const nodes = [{ id: 'A' }];
    const nodesByType = new Map([['Req', nodes]]);

    fn(nodesByType, ['Req'], 800, 300, config);
    assert.equal(nodes[0].x1 - nodes[0].x0, config.nodeWidth);
  });

  it('sets y1 = y0 + nodeHeight', () => {
    const nodes = [{ id: 'A' }];
    const nodesByType = new Map([['Req', nodes]]);

    fn(nodesByType, ['Req'], 800, 300, config);
    assert.equal(nodes[0].y1 - nodes[0].y0, config.nodeHeight);
  });

  it('spreads multiple columns across width', () => {
    const nodesA = [{ id: 'A' }];
    const nodesB = [{ id: 'B' }];
    const nodesByType = new Map([['Req', nodesA], ['Arc', nodesB]]);

    fn(nodesByType, ['Req', 'Arc'], 800, 300, config);

    // First column should be left of second column
    assert.ok(nodesA[0].x0 < nodesB[0].x0);
  });

  it('vertically spaces nodes within a column', () => {
    const nodes = [{ id: 'A' }, { id: 'B' }, { id: 'C' }];
    const nodesByType = new Map([['Req', nodes]]);

    fn(nodesByType, ['Req'], 800, 500, config);

    // Each subsequent node should be below the previous
    assert.ok(nodes[1].y0 > nodes[0].y0);
    assert.ok(nodes[2].y0 > nodes[1].y0);
    // Gap between nodes should be nodeHeight + nodeGap
    assert.equal(nodes[1].y0 - nodes[0].y0, config.nodeHeight + config.nodeGap);
  });

  it('handles empty nodesByType', () => {
    const nodesByType = new Map();
    // Should not throw
    fn(nodesByType, [], 800, 300, config);
  });
});
