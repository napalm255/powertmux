export POWERTMUX_DIR_HOME="$(dirname $0)"
export POWERTMUX_DIR_PLUGINS="$POWERTMUX_DIR_HOME/plugins"
export POWERTMUX_DIR_TEMPORARY="/tmp/powertmux_${USER}"
export POWERTMUX_DIR_THEMES="$POWERTMUX_DIR_HOME/themes"
export POWERTMUX_RCFILE="$HOME/.powertmuxrc"
export POWERTMUX_RCFILE_DEFAULT="$HOME/.powertmuxrc.default"
export SHELL_PLATFORM='unknown'

ostype() { echo $OSTYPE | tr '[A-Z]' '[a-z]'; }
case "$(ostype)" in
  *'linux'*  ) SHELL_PLATFORM='linux' ;;
  *'darwin'* ) SHELL_PLATFORM='osx'   ;;
  *'bsd'*    ) SHELL_PLATFORM='bsd'   ;;
esac

export POWERTMUX_DEBUG_MODE_ENABLED_DEFAULT="false"
export POWERTMUX_PATCHED_FONT_IN_USE_DEFAULT="false"
export POWERTMUX_THEME_DEFAULT="default"

if [ ! -d "$POWERTMUX_DIR_TEMPORARY" ]; then
  mkdir "$POWERTMUX_DIR_TEMPORARY"
fi

debug_mode_enabled() {
  [ -n "$POWERTMUX_DEBUG_MODE_ENABLED" -a "$POWERTMUX_DEBUG_MODE_ENABLED" != "false" ];
}

patched_font_in_use() {
  [ -z "$POWERTMUX_PATCHED_FONT_IN_USE" -o "$POWERTMUX_PATCHED_FONT_IN_USE" != "false" ];
}

shell_is_linux() { [[ $SHELL_PLATFORM == 'linux' || $SHELL_PLATFORM == 'bsd' ]]; }
shell_is_osx()   { [[ $SHELL_PLATFORM == 'osx' ]]; }
shell_is_bsd()   { [[ $SHELL_PLATFORM == 'bsd' || $SHELL_PLATFORM == 'osx' ]]; }

export -f shell_is_linux
export -f shell_is_osx
export -f shell_is_bsd

#! Check script arguments.

check_arg_side() {
  local side="$1"		
  if ! [ "$side" ==  "left" -o "$side" == "right" ]; then
    echo "Argument must be must be the side to handle {left, right} and not \"${side}\"."
    exit 1
  fi
}
__print_colored_content() {
  echo -n "#[fg=colour$3, bg=colour$2]"
  echo -n "$1"
  echo -n "#[default]"
}

powertmux_muted() {
  [ -e "$(__powertmux_mute_file $1)" ];
}

toggle_powertmux_mute_status() {
  if powertmux_muted $1; then
    rm "$(__powertmux_mute_file $1)"
  else
    touch "$(__powertmux_mute_file $1)"
  fi
}

__powertmux_mute_file() {
  local tmux_session=$(tmux display -p "#S")
  echo -n "${POWERTMUX_DIR_TEMPORARY}/mute_${tmux_session}_$1"
}

print_powertmux() {
  local side="$1"
  local upper_side=$(echo "$1" | tr '[:lower:]' '[:upper:]')
  eval "local input_plugins=(\"\${POWERTMUX_${upper_side}_STATUS_PLUGINS[@]}\")"
  local powertmux_plugins=()
  local powertmux_plugin_contents=()
  
  __check_platform
  
  __process_plugin_defaults
  __process_scripts
  __process_colors
  
  __process_powertmux
}

__process_plugin_defaults() {
	for plugin_index in "${!input_plugins[@]}"; do
		local input_plugin=(${input_plugins[$plugin_index]})
		eval "local default_separator=\$POWERTMUX_DEFAULT_${upper_side}SIDE_SEPARATOR"

		powertmux_plugin_with_defaults=(
			${input_plugin[0]:-"no_script"} \
			${input_plugin[1]:-$POWERTMUX_DEFAULT_BACKGROUND_COLOR} \
			${input_plugin[2]:-$POWERTMUX_DEFAULT_FOREGROUND_COLOR} \
			${input_plugin[3]:-$default_separator} \
		)

		powertmux_plugins[$plugin_index]="${powertmux_plugin_with_defaults[@]}"
	done
}

__process_scripts() {
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

__process_colors() {
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

		if __plugin_separator_is_thin; then
			powertmux_plugin[5]=${powertmux_plugin[2]}
		else
			powertmux_plugin[5]=${powertmux_plugin[1]}
		fi

		local previous_background_color=${powertmux_plugin[1]}

		powertmux_plugins[$plugin_index]="${powertmux_plugin[@]}"
	done
}

__process_powertmux() {
	for plugin_index in "${!powertmux_plugins[@]}"; do
		local powertmux_plugin=(${powertmux_plugins[$plugin_index]})

		local background_color=${powertmux_plugin[1]}
		local foreground_color=${powertmux_plugin[2]}
		local separator=${powertmux_plugin[3]}
		local separator_background_color=${powertmux_plugin[4]}
		local separator_foreground_color=${powertmux_plugin[5]}

		eval "__print_${side}_plugin ${plugin_index} ${background_color} ${foreground_color} ${separator} ${separator_background_color} ${separator_foreground_color}"
	done
}

__print_left_plugin() {
	local content=${powertmux_plugin_contents[$1]}
	local content_background_color=$2
	local content_foreground_color=$3
	local separator=$4
	local separator_background_color=$5
	local separator_foreground_color=$6

	__print_colored_content "$content" $content_background_color $content_foreground_color
	__print_colored_content $separator $separator_background_color $separator_foreground_color
}

__print_right_plugin() {
	local content=${powertmux_plugin_contents[$1]}
	local content_background_color=$2
	local content_foreground_color=$3
	local separator=$4
	local separator_background_color=$5
	local separator_foreground_color=$6

	__print_colored_content $separator $separator_background_color $separator_foreground_color
	__print_colored_content "$content" $content_background_color $content_foreground_color
}

__plugin_separator_is_thin() {
	[[ ${powertmux_plugin[3]} == $POWERTMUX_SEPARATOR_LEFT_THIN || \
		${powertmux_plugin[3]} == $POWERTMUX_SEPARATOR_RIGHT_THIN ]];
}

__check_platform() {
	if [ "$SHELL_PLATFORM" == "unknown" ] && debug_mode_enabled; then
		 echo "Unknown platform; modify config/shell.sh"  &1>&2
	fi
}

# Read user rc file.

process_settings() {
	__read_rcfile

	if [ -z "$POWERTMUX_DEBUG_MODE_ENABLED" ]; then
		export POWERTMUX_DEBUG_MODE_ENABLED="${POWERTMUX_DEBUG_MODE_ENABLED_DEFAULT}"
	fi

	if [ -z "$POWERTMUX_PATCHED_FONT_IN_USE" ]; then
		export POWERTMUX_PATCHED_FONT_IN_USE="${POWERTMUX_PATCHED_FONT_IN_USE_DEFAULT}"
	fi

	if [ -z "$POWERTMUX_THEME" ]; then
		export POWERTMUX_THEME="${POWERTMUX_THEME_DEFAULT}"
	fi

	eval POWERTMUX_DIR_USER_PLUGINS="$POWERTMUX_DIR_USER_PLUGINS"
	eval POWERTMUX_DIR_USER_THEMES="$POWERTMUX_DIR_USER_THEMES"
	if [ -n "$POWERTMUX_DIR_USER_THEMES" ] && [ -f "${POWERTMUX_DIR_USER_THEMES}/${POWERTMUX_THEME}.sh" ]; then
		source "${POWERTMUX_DIR_USER_THEMES}/${POWERTMUX_THEME}.sh"
	else
		source "${POWERTMUX_DIR_THEMES}/${POWERTMUX_THEME}.sh"
	fi

}

__read_rcfile() {
	if [  -f "$POWERTMUX_RCFILE" ]; then
		source "$POWERTMUX_RCFILE"
	fi
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
# Get the current path in the plugin.
get_tmux_cwd() {
	local env_name=$(tmux display -p "TMUXPWD_#D" | tr -d %)
	local env_val=$(tmux show-environment | grep --color=never "$env_name")
	# The version below is still quite new for tmux. Uncomment this in the future :-)
	#local env_val=$(tmux show-environment "$env_name" 2>&1)

	if [[ ! $env_val =~ "unknown variable" ]]; then
		local tmux_pwd=$(echo "$env_val" | sed 's/^.*=//')
		echo "$tmux_pwd"
	fi
}

if [ "$2" == "mute" ]; then
  check_arg_side "$1"
  toggle_powertmux_mute_status "$1"
elif ! powertmux_muted "$1"; then
  process_settings
  check_arg_side "$1"
  print_powertmux "$1"
fi

exit 0