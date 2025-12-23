# ✅ README.md

For unit testing.

## ⚽ Getting started

1. Open bash.
1. Set the current directory at this repository.
1. Enter the following commands.

```bash
# Ensure you are in the project root directory (you are currently in the "test" directory)
cd ../../
ls # CHANGELOG.md  LICENSE  README.md  docs  sample  scripts  shtracer

# Update submodule

git submodule update --init

# Change mode

chmod +x ./shtracer
chmod +x ./scripts/test/shtracer_unittest.sh
chmod +x ./scripts/test/unit/*.sh
chmod +x ./scripts/test/integration/*.sh

# Start unit tests

./shtracer -t

```

## Test scripts

filename                     | test target
---------------------------- | ---------------
shtracer_unittest.sh                    | `../../shtracer`
unit/shtracer_func_unittest.sh          | `../main/shtracer_func.sh`
unit/shtracer_viewer_unittest.sh        | `../main/shtracer_viewer.sh`
unit/shtracer_json_unittest.sh          | `../main/shtracer_func.sh` (JSON export)
integration/shtracer_integration_test.sh| End-to-end integration tests
