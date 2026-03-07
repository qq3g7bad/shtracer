// js_test_helper.mjs - VM-based loader for traceability_diagrams.js
// Loads the browser-global script into a Node.js sandbox for unit testing.

import { readFileSync } from 'node:fs';
import { createContext, runInContext } from 'node:vm';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const DIAGRAMS_PATH = resolve(
  __dirname, '..', '..', 'main', 'templates', 'traceability_diagrams.js'
);

/**
 * Load traceability_diagrams.js into a VM sandbox and return the context
 * with all function declarations accessible as properties.
 *
 * @param {Object} [opts] - Optional overrides for sandbox globals
 * @param {Object} [opts.traceabilityData] - Mock traceabilityData
 * @param {Array}  [opts.traceTargetOrder] - Mock traceTargetOrder
 * @param {Object} [opts.DIAGRAM_CONFIG]   - Override DIAGRAM_CONFIG
 * @returns {Object} The sandbox context containing all global functions
 */
export function loadDiagramFunctions(opts = {}) {
  const src = readFileSync(DIAGRAMS_PATH, 'utf8');

  const sandbox = {
    // Minimal browser stubs
    window: {},
    console: {
      log() {},
      warn() {},
      error() {},
    },
    document: {
      addEventListener() {},          // no-op: prevents DOMContentLoaded
      getElementById() { return null; },
      body: {},
    },
    getComputedStyle() {
      return { getPropertyValue() { return ''; } };
    },
    Map,
    Set,
    Array,
    Object,
    Math,
    String,
    Number,
    Infinity,
    parseInt,
    parseFloat,
    isNaN,
    isFinite,
    typeof: undefined,

    // Globals expected by the script
    traceabilityData: opts.traceabilityData || { layers: [], files: [], trace_tags: [] },
    traceTargetOrder: opts.traceTargetOrder || [],
    DIAGRAM_CONFIG: opts.DIAGRAM_CONFIG || undefined,  // let the script define it
  };

  // window and sandbox share the same object for _traceTypeColorMap etc.
  sandbox.window = sandbox;

  // Replace top-level const/let with var so declarations become sandbox properties.
  // Only target lines that start with const/let (top-level), not inside functions.
  // This is a simple heuristic: replace "const DIAGRAM_CONFIG" specifically,
  // as function-scoped const/let are fine.
  const patchedSrc = src.replace(/^const DIAGRAM_CONFIG/m, 'var DIAGRAM_CONFIG');

  const ctx = createContext(sandbox);
  runInContext(patchedSrc, ctx, { filename: 'traceability_diagrams.js' });
  return ctx;
}
