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

# Returns the current HP as an integer.
# If SHHP_HP is not set, it defaults to SHHP_MAX_HP.
#
# Usage: shhp_hp
function shhp_hp() {
    if [[ -z "${SHHP_HP}" ]]; then
        SHHP_HP="${SHHP_MAX_HP}"
    fi
    printf "%d" "${SHHP_HP}"
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

    if (( $(shhp_hp) + amount > SHHP_MAX_HP )); then
        amount=$(( SHHP_MAX_HP - $(shhp_hp) ))
    fi
    SHHP_HP=$(( $(shhp_hp) + amount ))
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
        SHHP_HP=$(( $(shhp_hp) - amount ))
    fi
    if (( $(shhp_hp) < 0 )); then
        SHHP_HP=0
    fi
}

