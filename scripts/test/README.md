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
chmod +x ./scripts/test/shtracer*test.sh

# Start unit tests

./shtracer -t

```

## Test scripts

filename                     | test target
---------------------------- | ---------------
shtracer_test.sh             | `../../shtracer`
shtracer_func_test.sh        | `../main/shtracer_func.sh`
shtracer_html_test.sh        | `../main/shtracer_html.sh`
shtracer_integration_test.sh | End-to-end integration tests
