#!/bin/bash
#
# Word of the day script, with function to format and highlight log output.
#
# Usage
# =====
# print random entry:
# $ wotd
#
# entry lookup (with command-line completion):
# $ wotd WORD
#
# pretty print:
# $ wotd p
#
# insert entry:
# $ wotd s
#
wotd() {
    local LOG=log
    if [ $# -eq 0 ]; then
        $LOG -w wotd m | _wotd_highlight
        return ${PIPESTATUS[0]}
    elif [ $# -eq 1 ]; then
        case "$1" in
        m|p|p[fl])  $LOG -w wotd "$1" | _wotd_highlight
                    return ${PIPESTATUS[0]}
                    ;;
        [otexias]|[oe][fl]|-*)
                    $LOG wotd "$1"
                    ;;
        *)          $LOG -w wotd p "$1" | _wotd_highlight
                    return ${PIPESTATUS[0]}
                    ;;
        esac
    else
        $LOG wotd "$@"
    fi
}
_wotd_highlight() {
    local MARK=' '
    perl -pe 's/^\s*\d+\s+(.*)$/\1'$MARK'/; s/^\s+(?=\w)/• /; s/^ +/  /' |
    fold -sw "$COLUMNS" |
    GREP_COLORS="${GREP_COLORS-ms=31}" grep -P '^\S+(?=.*'$MARK'$)|'
}

# completion
_wotd() {
    if [[ "$COMP_CWORD" -eq 1 && "$2" != -* ]]
    then COMPREPLY=($(compgen -W "$(log -n wotd o)" -- "$2"))
    else _log_alias "$@"
    fi
}
complete -F _wotd wotd

# print a random entry when this script is sourced
(GREP_COLORS='ms=34' wotd && python -c "print '—'*$COLUMNS") 2>/dev/null

# done
true

# vim:set ts=4 sw=4 et:
