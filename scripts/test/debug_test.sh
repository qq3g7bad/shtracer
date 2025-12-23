#!/bin/sh
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SHTRACER_BIN="${SCRIPT_DIR}/../../shtracer"

# Create test config
mkdir -p /tmp/debug_config
cat >/tmp/debug_config.md <<'EOT'
:Requirement
"test_req.md"
""
""
"Test requirement"
`@REQ[0-9\.]+@`
`<!--.*-->`
1
EOT

# Create test file
cat >/tmp/debug_config/test_req.md <<'EOT'
@REQ1.1@ Test requirement
EOT

# Run shtracer
cd /tmp && "$SHTRACER_BIN" debug_config.md --json

# Show JSON
cat output/output.json
