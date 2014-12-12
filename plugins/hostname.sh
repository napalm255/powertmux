# Prints the hostname.

POWERTMUX_SEG_HOSTNAME_FORMAT_DEFAULT="short"

__process_settings() {
  if [ -z "$POWERTMUX_SEG_HOSTNAME_FORMAT" ]; then
    export POWERTMUX_SEG_HOSTNAME_FORMAT="${POWERTMUX_SEG_HOSTNAME_FORMAT_DEFAULT}"
  fi
}

run_plugin() {
  __process_settings
  local opts=""
  if [ "$POWERTMUX_SEG_HOSTNAME_FORMAT" == "short" ]; then
    if shell_is_osx || shell_is_bsd; then
      opts="-s"
    else
      opts="--short"
    fi
  fi
  hostname ${opts}
  return 0
}
