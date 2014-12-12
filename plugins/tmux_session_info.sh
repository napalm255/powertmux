# Prints tmux session info.
# Assuems that [ -n "$TMUX"].

run_plugin() {
  tmux display-message -p '#S:#I.#P'
  return 0
}
