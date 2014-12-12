# LICENSE This code is not under the same license as the rest of the project as it's "stolen". It's cloned from https://github.com/richoH/dotfiles/blob/master/bin/battery and just some modifications are done so it works for my laptop. Check that URL for more recent versions.

POWERTMUX_SEG_BATTERY_TYPE_DEFAULT="percentage"
POWERTMUX_SEG_BATTERY_NUM_HEARTS_DEFAULT=5

HEART_FULL="♥"
HEART_EMPTY="♡"

run_plugin() {
	__process_settings
	battery_status=$(__battery_linux)

	[ -z "$battery_status" ] && return

	case "$POWERTMUX_SEG_BATTERY_TYPE" in
		"percentage")
			output="${HEART_FULL} ${battery_status}%"
			;;
		"cute")
			output=$(__cutinate $battery_status)
	esac
	if [ -n "$output" ]; then
		echo "$output"
	fi
}

__process_settings() {
	if [ -z "$POWERTMUX_SEG_BATTERY_TYPE" ]; then
		export POWERTMUX_SEG_BATTERY_TYPE="${POWERTMUX_SEG_BATTERY_TYPE_DEFAULT}"
	fi
	if [ -z "$POWERTMUX_SEG_BATTERY_NUM_HEARTS" ]; then
		export POWERTMUX_SEG_BATTERY_NUM_HEARTS="${POWERTMUX_SEG_BATTERY_NUM_HEARTS_DEFAULT}"
	fi
}

	__battery_linux() {
		case "$SHELL_PLATFORM" in
			"linux")
				BATPATH=/sys/class/power_supply/BAT0
				if [ ! -d $BATPATH ]; then
					BATPATH=/sys/class/power_supply/BAT1
				fi
				STATUS=$BATPATH/status
				BAT_FULL=$BATPATH/charge_full
				if [ ! -r $BAT_FULL ]; then
					BAT_FULL=$BATPATH/energy_full
				fi
				BAT_NOW=$BATPATH/charge_now
				if [ ! -r $BAT_NOW ]; then
					BAT_NOW=$BATPATH/energy_now
				fi

				if [ "$1" = `cat $STATUS` -o "$1" = "" ]; then
					__linux_get_bat
				fi
				;;
			"bsd")
				STATUS=`sysctl -n hw.acpi.battery.state`
				case $1 in
					"Discharging")
						if [ $STATUS -eq 1 ]; then
							__freebsd_get_bat
						fi
						;;
					"Charging")
						if [ $STATUS -eq 2 ]; then
							__freebsd_get_bat
						fi
						;;
					"")
						__freebsd_get_bat
						;;
				esac
				;;
		esac
	}

	__cutinate() {
		perc=$1
		inc=$(( 100 / $POWERTMUX_SEG_BATTERY_NUM_HEARTS ))


		for i in `seq $POWERTMUX_SEG_BATTERY_NUM_HEARTS`; do
			if [ $perc -lt 99 ]; then
				echo -n $HEART_EMPTY
			else
				echo -n $HEART_FULL
			fi
			echo -n " "
			perc=$(( $perc + $inc ))
		done
	}

	__linux_get_bat() {
		bf=$(cat $BAT_FULL)
		bn=$(cat $BAT_NOW)
		echo $(( 100 * $bn / $bf ))
	}

	__freebsd_get_bat() {
		echo "$(sysctl -n hw.acpi.battery.life)"

	}
