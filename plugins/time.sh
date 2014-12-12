# Prints the current time.

POWERTMUX_SEG_TIME_FORMAT_DEFAULT="%H:%M"

__process_settings() {
  if [ -z "$POWERTMUX_SEG_TIME_FORMAT" ]; then
    export POWERTMUX_SEG_TIME_FORMAT="${POWERTMUX_SEG_TIME_FORMAT_DEFAULT}"
  fi
}

run_plugin() {
  __process_settings
  date +"$POWERTMUX_SEG_TIME_FORMAT"
  return 0
}
