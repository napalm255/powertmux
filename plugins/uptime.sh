# Prints the uptime.

run_plugin() {
  uptime | grep -PZo "(?<=up )[^,]*"
  return 0
}
