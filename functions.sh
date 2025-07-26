# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2025 Adam Sindelar

SHHP_MAX_HP=3
SHHP_RED="$(tput setaf 9)"
SHHP_YELLOW="$(tput setaf 11)"
SHHP_GREY="$(tput setaf 8)"
SHHP_BLINK="$(tput blink)"
SHHP_RST="$(tput sgr0)"
SHHP_HEART="♥"
SHHP_COLOR=1
export SHHP_TEMP="$(mktemp -d /tmp/shhp.XXXXXX)"
trap 'rm -rf "${SHHP_TEMP}"' EXIT

# Returns the current HP as an integer. If hitpoints are not set, initializes to
# SHHP_MAX_HP.
#
# If an argument is passed, HP is set to that value and then returned.
#
# Usage: shhp_hp [HP]
function shhp_hp() {
    if (( $# > 0 )); then
        echo "$1" > "${SHHP_TEMP}/hp"
    fi
    if [[ ! -f "${SHHP_TEMP}/hp" ]]; then
        echo "${SHHP_MAX_HP}" > "${SHHP_TEMP}/hp"
    fi
    cat "${SHHP_TEMP}/hp" | xargs
}

# Outputs a tput color code for the specified color. If SHHP_COLOR is unset,
# empty strings are returned.
#
# Usage: shhp_color COLOR
function shhp_color() {
    if [[ -z "${SHHP_COLOR}" ]]; then
        return 0
    fi
    case "$1" in
        red)
            printf "%s" "${SHHP_RED}"
            ;;
        yellow)
            printf "%s" "${SHHP_YELLOW}"
            ;;
        grey)
            printf "%s" "${SHHP_GREY}"
            ;;
        reset)
            printf "%s" "${SHHP_RST}"
            ;;
        blink)
            printf "%s" "${SHHP_BLINK}"
            ;;
        *)
            >&2 echo "Unknown color: $1"
            return 1
            ;;
    esac
}

# Prints the current HP as a heart emoji.
#
# Usage: shhp_print_hp
function shhp_print_hp() {
    printf "["
    shhp_color red
    local i
    for (( i = 0; i < $(shhp_hp); i++ )); do
        # If we are at the last heart, blink.
        if (( i == 0 && $(shhp_hp) == 1 )); then
            shhp_color blink
            printf "%s" "${SHHP_HEART}"
            shhp_color reset
        else
            printf "%s" "${SHHP_HEART}"
        fi

        if (( i == SHHP_MAX_HP - 1 )); then
            shhp_color yellow
        fi
    done
    shhp_color grey
    if (( $(shhp_hp) < SHHP_MAX_HP )); then
        for (( ; i < SHHP_MAX_HP; i++ )); do
            printf "x"
        done
    fi
    shhp_color reset
    printf "]"
}

# Heal by AMOUNT up to the maximum HP.
# If AMOUNT is not specified, heal by 1.
#
# Usage: shhp_heal [AMOUNT]
function shhp_heal() {
    local amount=1
    if (( $# > 0 )); then
        amount="$1"
    fi

    if (( $(shhp_hp) >= SHHP_MAX_HP )); then
        return 0  # Already at max HP, no healing needed.
    fi

    # If healing would exceed max HP, set to max HP.
    # Otherwise, heal by the specified amount.
    if (( $(shhp_hp) + amount > SHHP_MAX_HP )); then
        shhp_hp $SHHP_MAX_HP > /dev/null
    else
        # Heal by the specified amount.
        shhp_hp $(( $(shhp_hp) + amount )) > /dev/null
    fi
}

# Heal to SHHP_MAX_HP and then overheal by AMOUNT.
# If AMOUNT is not specified, overheal by 1.
#
# Usage: shhp_overheal [AMOUNT]
function shhp_overheal() {
    local amount=1
    if (( $# > 0 )); then
        amount="$1"
    fi

    if (( $(shhp_hp) < SHHP_MAX_HP + amount )); then
        SHHP_HP=$(( SHHP_MAX_HP + amount ))
    fi
}

# Damage by AMOUNT, or by 1 if not specified.
# Minimum hp is 0.
#
# Usage: shhp_damage [AMOUNT]
function shhp_damage() {
    local amount=1
    if (( $# > 0 )); then
        amount="$1"
    fi
    if (( $(shhp_hp) > 0 )); then
        shhp_hp $(( $(shhp_hp) - amount )) > /dev/null
    fi
    if (( $(shhp_hp) < 0 )); then
        shhp_hp 0 > /dev/null
    fi
}

# Checks whether the last command executed was an error.
#
# Returns 0 if it was an error, 1 if it was not.
#
# Usage: shhp_is_error
function shhp_is_error() {
    case "$1" in
        0) return 1 ;;  # No error
        130) return 1 ;;  # Ctrl-C
        143) return 1 ;;  # Ctrl-Z
        *) return 0 ;;  # Error
    esac
}

# Checks whether the user should take damage based on the last command executed.
#
# The user takes damage if the last command returned an error code, except the
# ones allowed by shhp_is_error. Repeatedly running the same command does not
# cause repeated damage.
#
# Returns 0 if damage should be taken, 1 if not.
#
# Usage: shhp_should_take_damage
function shhp_should_take_damage() {
    # The order of these operations is sensitive. Be careful when
    # editing, because the fc command must count backwards to the interactive
    # command executed by the user.
    SHHP_LAST_CODE="$?"
    SHHP_LAST_COMMAND="$(fc -ln -1 -1 | xargs)"
    local prev_command="$(cat "${SHHP_TEMP}/prev_command" 2>/dev/null || echo "")"

    if [[ "${prev_command}" == "${SHHP_LAST_COMMAND}:${SHHP_LAST_CODE}" ]]; then
        return 1  # Repeated command - no damage.
    fi
    echo "${SHHP_LAST_COMMAND}:${SHHP_LAST_CODE}" > "${SHHP_TEMP}/prev_command"

    if shhp_is_error "${SHHP_LAST_CODE}"; then
        return 0  # Take damage
    fi

    # If the last command was successful, do not take damage.
    return 1  # No damage taken
}

function shhp_die() {
    >&2 echo "You died!"
    # Kill the parent shell.
    kill $(ps -o ppid= $$)
}

function shhp_ps1_hook() {
    if shhp_should_take_damage; then
        >&2 printf "You took %s1 damage%s (last command failed: %s)\n" \
            "$(shhp_color red)" "$(shhp_color reset)" "${SHHP_LAST_COMMAND}"
        shhp_damage
    fi
    shhp_print_hp
    if (( $(shhp_hp) <= 0 )); then
        shhp_die
    fi
}

PS1="\$(shhp_ps1_hook) > "
