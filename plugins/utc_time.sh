# Prints the current time in UTC.

run_plugin() {
  date -u +"%H:%M"
  return 0
}
