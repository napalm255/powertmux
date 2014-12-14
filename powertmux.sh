#!/usr/bin/env bash

powertmux() {
  case "${1,,}" in
    status)
      case "${2,,}" in
        left|right)
          case "${3,,}" in
            on|off) tmux set-env "POWERTMUX_STATUS_${2^^}" "$3" ;;
            show)
              local client_width=$(tmux list-clients -F '#{client_width}')
              [ "$(tmux show-env POWERTMUX_STATUS_${2^^} | sed 's:^.*=::')" == "off" ] && return 0 
              [ "${client_width}" -lt 100 ] && [ "${2,,}" == "right" ] && return 0
              [ "${client_width}" -lt 50 ] && return 0
              __powertmux_settings
              __powertmux_print "${2}"
            ;;
          esac
        ;;
      esac
    ;;
    theme)
      tmux set-env "POWERTMUX_THEME" "${2}"
    ;;
  esac
}

__powertmux_complete() {
  local cur prev option_list
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  if [ $COMP_CWORD -eq 1 ]; then
    # first level options
    option_list="status theme"
  elif [ $COMP_CWORD -eq 2 ]; then
    # second level options
    case "${prev}" in
      status) option_list="left right" ;;
       theme) option_list="$(ls $POWERTMUX_DIR_THEMES | sed -e 's/.json//g')" ;;
    esac
  elif [ $COMP_CWORD -eq 3 ]; then
    # third level options
    case "${prev}" in
      left|right) option_list="on off" ;;
    esac
  fi
  COMPREPLY=( $(compgen -W "${option_list}" -- ${cur}) )
}

__powertmux_dir_home() {
  SOURCE="${BASH_SOURCE[0]}"
  while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done
  echo "$( cd -P "$( dirname "$SOURCE" )" && pwd )"
}

__powertmux_settings() {
  [ "$(tmux show-env POWERTMUX_THEME | sed 's:^.*=::')" == "" ] && tmux set-env "POWERTMUX_THEME" "default"
  POWERTMUX_THEME=$(tmux show-env POWERTMUX_THEME | sed 's:^.*=::')

  # read json using lib/jq
  local jq=${POWERTMUX_DIR_LIB}/jq
  local js=${POWERTMUX_DIR_THEMES}/${POWERTMUX_THEME}.json

  [ "$(tmux show-env POWERTMUX_STATUS_LEFT | sed 's:^.*=::')" == "" ] && tmux set-env "POWERTMUX_STATUS_LEFT" "$($jq ".left.display" $js)"
  [ "$(tmux show-env POWERTMUX_STATUS_RIGHT | sed 's:^.*=::')" == "" ] && tmux set-env "POWERTMUX_STATUS_RIGHT" "$($jq ".right.display" $js)"

  POWERTMUX_SEPARATOR_LEFT_BOLD=$($jq ".left.separators.bold" $js)
  POWERTMUX_SEPARATOR_LEFT_THIN=$($jq ".left.separators.thin" $js)
  POWERTMUX_SEPARATOR_RIGHT_BOLD=$($jq ".right.separators.bold" $js)
  POWERTMUX_SEPARATOR_RIGHT_THIN=$($jq ".left.separators.thin" $js)
  POWERTMUX_DEFAULT_BACKGROUND_COLOR=$($jq ".defaults.colors.background" $js)
  POWERTMUX_DEFAULT_FOREGROUND_COLOR=$($jq ".defaults.colors.foreground" $js)
  POWERTMUX_DEFAULT_LEFTSIDE_SEPARATOR=$($jq ".defaults.separators.left" $js | tr '[:lower:]' '[:upper:]' | sed -e 's/\"//g')
  POWERTMUX_DEFAULT_RIGHTSIDE_SEPARATOR=$($jq ".defaults.separators.right" $js | tr '[:lower:]' '[:upper:]' | sed -e 's/\"//g')
  POWERTMUX_DEFAULT_LEFTSIDE_SEPARATOR=$(eval "echo \$$(echo POWERTMUX_SEPARATOR_$(echo ${POWERTMUX_DEFAULT_LEFTSIDE_SEPARATOR}))")
  POWERTMUX_DEFAULT_RIGHTSIDE_SEPARATOR=$(eval "echo \$$(echo POWERTMUX_SEPARATOR_$(echo ${POWERTMUX_DEFAULT_RIGHTSIDE_SEPARATOR}))")

  PLUGINS=($($jq ".left.plugins[]" $js | sed -e 's/\ /,/g' ))
  for ((i = 0; i < ${#PLUGINS[@]}; i++))
  do
    POWERTMUX_LEFT_STATUS_PLUGINS[${i}]=$(echo "${PLUGINS[$i]}" | sed -e 's/,/ /g' -e 's/\"//g')
  done
  PLUGINS=($($jq ".right.plugins[]" $js | sed -e 's/\ /,/g' ))
  for ((i = 0; i < ${#PLUGINS[@]}; i++))
  do
    POWERTMUX_RIGHT_STATUS_PLUGINS[${i}]=$(echo "${PLUGINS[$i]}" | sed -e 's/,/ /g' -e 's/\"//g')
  done

}

__powertmux_print() {
  local side="$1"
  local upper_side=$(echo "$1" | tr '[:lower:]' '[:upper:]')
  eval "local input_plugins=(\"\${POWERTMUX_${upper_side}_STATUS_PLUGINS[@]}\")"
  local powertmux_plugins=()
  local powertmux_plugin_contents=()
  
  __powertmux_plugins_defaults
  __powertmux_plugins
  __powertmux_colors
  __powertmux_process
}

__powertmux_plugins_defaults() {
  for plugin_index in "${!input_plugins[@]}"; do
    eval "local default_separator=\$POWERTMUX_DEFAULT_${upper_side}SIDE_SEPARATOR"
    local input_plugin=(${input_plugins[$plugin_index]})
    input_plugin[3]=$(eval "echo \$$(echo POWERTMUX_SEPARATOR_$(echo ${input_plugin[3]^^}))")

    powertmux_plugin_with_defaults=(
      ${input_plugin[0]:-"no_script"} \
      ${input_plugin[1]:-$POWERTMUX_DEFAULT_BACKGROUND_COLOR} \
      ${input_plugin[2]:-$POWERTMUX_DEFAULT_FOREGROUND_COLOR} \
      ${input_plugin[3]:-$default_separator} \
    )

    powertmux_plugins[$plugin_index]="${powertmux_plugin_with_defaults[@]}"
  done
}

__powertmux_plugins() {
  for plugin_index in "${!powertmux_plugins[@]}"; do
    local powertmux_plugin=(${powertmux_plugins[$plugin_index]})

    if [ -n "$POWERTMUX_DIR_USER_PLUGINS" ] && [ -f "$POWERTMUX_DIR_USER_PLUGINS/${powertmux_plugin[0]}.sh" ] ; then
      local script="$POWERTMUX_DIR_USER_PLUGINS/${powertmux_plugin[0]}.sh"
    else
      local script="$POWERTMUX_DIR_PLUGINS/${powertmux_plugin[0]}.sh"
    fi

    export POWERTMUX_CUR_PLUGIN_BG="${powertmux_plugin[1]}"
    export POWERTMUX_CUR_PLUGIN_FG="${powertmux_plugin[2]}"
    source "$script"
    local output
    output=$(run_plugin)
    local exit_code="$?"
    unset -f run_plugin

    if [ "$exit_code" -ne 0 ] && debug_mode_enabled ; then
      local seg_name="${script##*/}"
      echo "Segment '${seg_name}' exited with code ${exit_code}. Aborting."
      exit 1
    fi

    if [ -n "$output" ]; then
      powertmux_plugin_contents[$plugin_index]=" $output "
    else
      unset -v powertmux_plugins[$plugin_index]
    fi
  done
}

__powertmux_colors() {
  for plugin_index in "${!powertmux_plugins[@]}"; do
    local powertmux_plugin=(${powertmux_plugins[$plugin_index]})
    # Find the next plugin that produces content (i.e. skip empty plugins).
    for next_plugin_index in $(eval echo {$(($plugin_index + 1))..${#powertmux_plugins}}) ; do
      [[ -n ${powertmux_plugins[next_plugin_index]} ]] && break
    done
    local next_plugin=(${powertmux_plugins[$next_plugin_index]})

    if [ $side == 'left' ]; then
      powertmux_plugin[4]=${next_plugin[1]:-$POWERTMUX_DEFAULT_BACKGROUND_COLOR}
    elif [ $side == 'right' ]; then
      powertmux_plugin[4]=${previous_background_color:-$POWERTMUX_DEFAULT_BACKGROUND_COLOR}
    fi

    if __powertmux_plugin_separator_is_thin; then
      powertmux_plugin[5]=${powertmux_plugin[2]}
    else
      powertmux_plugin[5]=${powertmux_plugin[1]}
    fi

    local previous_background_color=${powertmux_plugin[1]}

    powertmux_plugins[$plugin_index]="${powertmux_plugin[@]}"
  done
}

__powertmux_process() {
  for plugin_index in "${!powertmux_plugins[@]}"; do
    local powertmux_plugin=(${powertmux_plugins[$plugin_index]})

    local background_color=${powertmux_plugin[1]}
    local foreground_color=${powertmux_plugin[2]}
    local separator=${powertmux_plugin[3]}
    local separator_background_color=${powertmux_plugin[4]}
    local separator_foreground_color=${powertmux_plugin[5]}

    eval "__powertmux_print_plugin ${side} ${plugin_index} ${background_color} ${foreground_color} ${separator} ${separator_background_color} ${separator_foreground_color}"
  done
}

__powertmux_print_colored_content() {
  echo -n "#[fg=colour$3, bg=colour$2]"
  echo -n "$1"
  echo -n "#[default]"
}

__powertmux_print_plugin() {
  local side=$1
  local content=${powertmux_plugin_contents[$2]}
  local content_background_color=$3
  local content_foreground_color=$4
  local separator=$5
  local separator_background_color=$6
  local separator_foreground_color=$7

  case "${side}" in
    left)
      __powertmux_print_colored_content "$content" $content_background_color $content_foreground_color
      __powertmux_print_colored_content $separator $separator_background_color $separator_foreground_color
    ;;
    right)
      __powertmux_print_colored_content $separator $separator_background_color $separator_foreground_color
      __powertmux_print_colored_content "$content" $content_background_color $content_foreground_color
    ;;
  esac
}

__powertmux_plugin_separator_is_thin() {
  [[ ${powertmux_plugin[3]} == $POWERTMUX_SEPARATOR_LEFT_THIN || \
    ${powertmux_plugin[3]} == $POWERTMUX_SEPARATOR_RIGHT_THIN ]];
}

# Rolling anything what you want.
# arg1: text to roll.
# arg2: max length to display.
# arg3: roll speed in characters per second.
roll_text() {
  local text="$1"  # Text to print
  
  if [ -z "$text" ]; then
  	return;
  fi
  
  local max_len="10"	# Default max length.
  
  if [ -n "$2" ]; then
  	max_len="$2"
  fi
  
  local speed="1"  # Default roll speed in chars per second.
  
  if [ -n "$3" ]; then
  	speed="$3"
  fi
  
  # Skip rolling if the output is less than max_len.
  if [ "${#text}" -le "$max_len" ]; then
  	echo "$text"
  	return
  fi
  
  # Anything starting with 0 is an Octal number in Shell,C or Perl,
  # so we must explicitly state the base of a number using base#number
  local offset=$((10#$(date +%s) * ${speed} % ${#text}))
  
  # Truncate text.
  text=${text:offset}
  
  local char	# Character.
  local bytes # The bytes of one character.
  local index
  
  for ((index=0; index < max_len; index++)); do
  	char=${text:index:1}
  	bytes=$(echo -n $char | wc -c)
  	# The character will takes twice space
  	# of an alphabet if (bytes > 1).
  	if ((bytes > 1)); then
  		max_len=$((max_len - 1))
  	fi
  done
  
  text=${text:0:max_len}
  
  #echo "index=${index} max=${max_len} len=${#text}"
  # How many spaces we need to fill to keep
  # the length of text that will be shown?
  local fill_count=$((${index} - ${#text}))
  
  for ((index=0; index < fill_count; index++)); do
  	text="${text} "
  done
  
  echo "${text}"
}

# clear all variables
unset $(env | grep POWERTMUX | sed -e 's/=.*//g')

# configure variables
export POWERTMUX_DIR_HOME="$(__powertmux_dir_home)"
export POWERTMUX_DIR_LIB="${POWERTMUX_DIR_HOME}/lib"
export POWERTMUX_DIR_THEMES="${POWERTMUX_DIR_HOME}/themes"
export POWERTMUX_DIR_PLUGINS="${POWERTMUX_DIR_HOME}/plugins"
export POWERTMUX_DIR_TEMPORARY="/tmp/powertmux_${USER}"

[ ! -d "$POWERTMUX_DIR_TEMPORARY" ] && mkdir "$POWERTMUX_DIR_TEMPORARY"

# load powertmux
powertmux $@

# enable auto completion
complete -F __powertmux_complete powertmux
