#!/bin/bash

usage() {
    echo "Interactively show slides from a file"
    echo
    echo "Usage:"
    echo "$0 FILE"
    echo
    echo "FILE is the file containing the slides."
    echo "In the file, separate each slide with the word \"slide\" on a"
    echo "line by itself."
    echo
    echo "Control:"
    echo "Pressing k or h will move backwards one slide."
    echo "Pressing anything else will move ahead one slide."
}

slide() {
    local -r TPUT=$(type -p tput)
    [ -x "$TPUT" ] || exit 1
    local -r IFS='' MESSAGE=${1:-<Enter> Next slide | <ctrl+c> Quit}
    local -r COLORS=(red=31 green=32 yellow=33 blue=34 purple=35 cyan=36 end=)
    local -ri COLS=$($TPUT cols) ROWS=$($TPUT lines)
    local -i CENTER=0 LINENUM=0 CTRPOS=0 MSGPOS=0 HASCOLOR=1
    local LINE='' BARE=''
    trap "$TPUT clear" 0
    $TPUT clear
    while read LINE; do
        [ "$LINE" == '!!color' ] && HASCOLOR=1 && continue
        [ "$LINE" == '!!nocolor' ] && HASCOLOR=0 && continue
        BARE=$LINE
        if [ $HASCOLOR -eq 1 ]; then
            for C in "${COLORS[@]}"; do
                BARE=${BARE//<${C%%=*}>/}
                LINE=${LINE//<${C%%=*}>/\\033\[0\;${C##*=}m}
            done
        fi
        [ "$BARE" == '!!vcenter' ] && LINENUM="$((ROWS/2))" && continue
        [ "$BARE" == '!!center' ] && CENTER=1 && continue
        [ "$BARE" == '!!nocenter' ] && CENTER=0 && continue
        [ "$BARE" == '!!pause' ] && read -s < /dev/tty && continue
        if [ "$BARE" == '!!sep' ]; then
            printf -vBARE "%${COLS}s" '' && BARE=${BARE// /-}
            LINE=${LINE//\!\!sep/$BARE}
        fi
        [ ${#MESSAGE} -lt $COLS ] && MSGPOS=$(((COLS-1)-${#MESSAGE}))
        [ ${#BARE} -le $COLS ] && CTRPOS=$(((COLS-${#BARE})/2))
        [ $CENTER -eq 1 ] && $TPUT cup $LINENUM $CTRPOS || $TPUT cup $LINENUM 0
        printf -- "${LINE//%/%%}\n"
        $TPUT cup $ROWS $COLS && let LINENUM++
        [ ${#BARE} -gt $COLS ] && let LINENUM++
    done
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

if [[ ! -x "$(type -p tput)" ]]; then
    echo 'The command "tput" is missing' 
    exit 1
fi

SLIDEFILE="$(type -p slide.sh)"
if [[ ! -x "$SLIDEFILE" ]]; then
    echo 'The command "slide.sh" is missing' 
    exit 1
fi

UNPARSED="$(<"$1")"
I=0
while [[ -n "$UNPARSED" ]]; do
    I=$((I + 1))
    SLIDE[$I]="$(echo "$UNPARSED" | sed -n -e '/^slide$/q;p'; echo x)"
    # bash gotcha: command expansion removes trailing newlines
    # we need them here for counting purposes
    # so throw an "x" on the end and take it off after expansion's done
    SLIDE[$I]="${SLIDE[$I]%x}"
    REMOVE_LINES=$(echo "${SLIDE[$I]}" | wc -l)
    UNPARSED="$(echo "$UNPARSED" | sed 1,"$REMOVE_LINES"d)"
done

SLIDE_IX=1
echo -n "${SLIDE[$SLIDE_IX]}" | slide "$@"
while read -s -N 1; do
    case "$REPLY" in
        [hk])
            GO=-1
            ;;
        *)
            GO=1
            ;;
    esac
    SLIDE_IX=$((SLIDE_IX + GO))
    if [ "$SLIDE_IX" -gt "${#SLIDE[@]}" ]; then
        SLIDE_IX="${#SLIDE[@]}"
    elif [ "$SLIDE_IX" -lt 1 ]; then
        SLIDE_IX=1
    fi
    echo -n "${SLIDE[$SLIDE_IX]}" | slide
done
