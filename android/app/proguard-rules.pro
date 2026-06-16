# Shaking & Minification Rules for Zivofit

# ML Kit Text Recognition has references to optional languages (Chinese, Japanese, etc.)
# which are not imported in the app's gradle dependencies. This stops R8 from warning/failing.
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.android.gms.internal.ml.**
