#!/system/bin/sh
# Persist the Firefox / Gecko software-rendering workaround for the Vivante GC5000.
#
# Standalone Firefox's GPU/compositor path crashes on this GPU (the Vivante GLES
# driver segfaults -- same root cause that crashes the heavy-page WebView in
# gcChipDynamicPatchProgram/gcChipRecompileShader). Without this, every tab dies and
# Fenix loops its CrashReporterActivity. Gecko has a pure software WebRender path that
# never touches the GPU, so it renders fine once that is forced on (verified on-device:
# google.com renders fully, zero crash reports).
#
# Two pieces are needed and both live under /data (which a factory reset wipes), so
# this init-driven oneshot re-applies them on every boot:
#   1. the GeckoView debug config file with the software-rendering prefs, and
#   2. marking Firefox as the debug app -- GeckoView only reads that config file when
#      the app is debuggable or is the current debug_app.
# Started from the on property:sys.boot_completed=1 trigger in init.pxa1928.rc.
#
# NB: this deliberately does NOT check whether Firefox is installed. It used to exit
# early on `pm path`, which meant a Firefox installed *after* the last boot got no
# workaround at all and crashed until the next reboot (exactly how this resurfaced).
# Writing the config and the debug_app setting unconditionally arms the workaround in
# advance; both are harmless when the package is absent.
#
# NB2: no here-document. mksh implements <<EOF via a temp file under $TMPDIR and falls
# back to a directory the shell user cannot write, so `cat > f <<EOF` silently produced
# a ZERO-BYTE config when this ran as anything but root. printf has no such dependency.

PKG=org.mozilla.firefox
CFG=/data/local/tmp/${PKG}-geckoview-config.yaml

# Let the framework settle so the am binder call succeeds.
sleep 5

printf 'prefs:\n  gfx.webrender.software: true\n  layers.gpu-process.enabled: false\n  gfx.webrender.enabled: false\n  gfx.canvas.accelerated: false\n' > "$CFG" || exit 0
chmod 644 "$CFG"

# GeckoView reads the config only for the debug_app; --persistent stores it in settings
# (survives reboot) but re-assert each boot so a data wipe is covered. Note this is a
# single global slot: setting another debug app by hand will disable the workaround.
am set-debug-app --persistent "$PKG"

log -t firefox_swrender "software WebRender armed for $PKG"
exit 0
