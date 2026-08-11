#!/system/bin/sh
# Persist the Firefox / Gecko software-rendering workaround for the Vivante GC5000.
#
# Standalone Firefox's GPU/compositor path crashes on this GPU (the Vivante GLES
# driver segfaults in libGLESv2_MRVL on glDrawElementsInstanced -- same root cause
# that whitescreens/crashes Chrome and the heavy-page WebView). Gecko has a pure
# software WebRender path that never touches the GPU, so it renders fine once that
# is forced on. Two pieces are needed and both live under /data (which a factory
# reset wipes), so this init-driven oneshot re-applies them on every boot:
#   1. the GeckoView debug config file with the software-rendering prefs, and
#   2. marking Firefox as the debug app -- GeckoView only reads the config file
#      when the app is debuggable or is the current debug_app.
# Started from the on property:sys.boot_completed=1 trigger in init.pxa1928.rc.

PKG=org.mozilla.firefox
CFG=/data/local/tmp/${PKG}-geckoview-config.yaml

# Let the framework settle so am/pm binder calls succeed.
sleep 5

# Do nothing if Firefox is not installed.
pm path "$PKG" >/dev/null 2>&1 || exit 0

cat > "$CFG" <<'YAML'
prefs:
  gfx.webrender.software: true
  layers.gpu-process.enabled: false
  gfx.webrender.enabled: false
  gfx.canvas.accelerated: false
YAML
chmod 644 "$CFG"

# GeckoView reads the config only for the debug_app; --persistent stores it in
# settings (survives reboot) but we re-assert each boot so a data wipe is covered.
am set-debug-app --persistent "$PKG"

exit 0
