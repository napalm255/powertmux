# Print the current date.

POWERTMUX_SEG_DATE_FORMAT_DEFAULT="%F"

__process_settings() {
  if [ -z "$POWERTMUX_SEG_DATE_FORMAT" ]; then
    export POWERTMUX_SEG_DATE_FORMAT="${POWERTMUX_SEG_DATE_FORMAT_DEFAULT}"
  fi
}

run_plugin() {
  __process_settings
  date +"$POWERTMUX_SEG_DATE_FORMAT"
  return 0
}
