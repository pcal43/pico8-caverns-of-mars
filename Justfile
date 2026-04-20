set dotenv-filename := "project.env"
set dotenv-load
set export

PROJECT_NAME := env("PROJECT_NAME")
VERSION := env("VERSION")
ROOT_DIR := "."
BUILD_DIR := ROOT_DIR + "/build"
PICO8_HOME := ROOT_DIR + "/pico8-home"
PICO8_CARTS := PICO8_HOME + "/carts"

GAME_ROOT := PICO8_CARTS + "/" + PROJECT_NAME
GAME_CART := GAME_ROOT + "/" + PROJECT_NAME + ".p8"

SHRINKO8 := "python3 ../shrinko8/shrinko8.py"
MINIFIED_CART := BUILD_DIR + "/" + PROJECT_NAME + "-min.p8"
RELEASE_ARTIFACT := BUILD_DIR + "/" + PROJECT_NAME + "-" + VERSION + ".p8.png"

UNAME_S := `uname -s`
PICO8_BIN := if UNAME_S == "Darwin" {
  "/Applications/PICO-8.app/Contents/MacOS/pico8"
} else {
  "pico8"
}

clean:
    rm -rf "$BUILD_DIR"

run:
	"$PICO8_BIN" -home "$PICO8_HOME"  -root_path  "$PICO8_CARTS" -run "$GAME_CART"

version:
    mkdir -p "$GAME_ROOT"
    echo 'VERSION = "'"$VERSION"'"' > "$GAME_ROOT/version.lua"

release: clean version
    mkdir -p "$BUILD_DIR"
    "$PICO8_BIN" \
        -home "$PICO8_HOME" \
        -root_path "$PICO8_CARTS" \
        -run "$GAME_CART" \
        -export "$RELEASE_ARTIFACT"

count: release
    $SHRINKO8 "$RELEASE_ARTIFACT" --count

lint: release
    $SHRINKO8 "$GAME_CART" --lint

minify:
    mkdir -p "$BUILD_DIR"
    $SHRINKO8 "$GAME_CART" "$MINIFIED_CART" --minify --no-minify-lines

count-minified: minify
    $SHRINKO8 "$MINIFIED_CART" --count

run-minified: minify
    "$PICO8_BIN" \
        -home "$PICO8_HOME" \
        -root_path "$PICO8_CARTS" \
        -run "$MINIFIED_CART"

run-release: release
    "$PICO8_BIN" -run "$RELEASE_ARTIFACT"
