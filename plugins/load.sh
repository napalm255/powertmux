# Print the average load.

run_plugin() {
  uptime | cut -d "," -f 3- | cut -d ":" -f2 | sed -e "s/^[ \t]*//"
  exit 0
}
