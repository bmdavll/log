# bash completion for log
! type log &>/dev/null && return 1

# repository for log files
export LOG_DIR="$HOME/documents/txt"

# external editors
#export EDITOR=vim
export LOG_EDITOR=vim

# alias for log
# you can set default options here
# e.g. alias lg='log -i'
alias lg='log'
complete -o filenames -F _log log lg

# entries.pl completion
type _longopt &>/dev/null &&
complete -o filenames -F _longopt entries.pl

# completion for file aliases
_log_alias() {
    local LOG=log
    COMP_CWORD=$((COMP_CWORD+1))
    COMP_WORDS=($LOG "${COMP_WORDS[@]}")
    shift && _log $LOG "$@"
}
# example
alias todo='log todo'
complete -F _log_alias todo

#####################
# end configuration #
#####################

# completion function
_log() {
    [ ! -d "$LOG_DIR" ] && return 1
    local LOG=log NBSP=' ' DBSP="$NBSP$NBSP"
    local cur="$2" ops='m p pf pl o of ol t e ef el d x i a s n c r h'
    local i arg no_opt argv=() op file output compreply=() choices compfiles
    unset COMP_WORDS[0]
    for i in $(seq $COMP_CWORD ${#COMP_WORDS[@]}); do
        unset COMP_WORDS[$i]
    done
    for arg in "${COMP_WORDS[@]}"; do
        case "$arg" in
        --)         if [ "$no_opt" ]
                    then argv+=("$arg")
                    else no_opt=1
                    fi
                    ;;
        -[^0-9]*)   ;;
        *)          argv+=("$arg")
                    ;;
        esac
    done
    set -- "${argv[@]}"
    while true; do
    if [ ! "$no_opt" ]; then
        # option completion
        if [[ "$cur" == --* ]]; then
            compreply=('--help')
            break
        elif [[ "$cur" =~ ^-[hwncvisofeq]+$ ]]; then
            compreply=("$cur")
            break
        elif [[ "$cur" == -* ]]; then
            choices='--help -h -w -n -c -v -i -s -o -f -e -q'
        fi
    fi
    if [ $# -eq 0 ]; then
        # first argument
        choices="$ops"
        compfiles=1
        break
    fi
    if __log_op "$2"; then
        # file op
        file="$1" && shift 2
    elif __log_op "$1"; then
        shift
        if [ $# -gt 0 ]; then
            # op file
            file="$1" && shift
        else
            # op
            if [[ "$op" == [edxi] ]]; then
                __log_print "$LOG" && break
            fi
            compfiles=1 && break
        fi
    elif [ $# -eq 1 ]; then
        # file
        choices="$ops"
        break
    else
        break
    fi
    file=$(eval "echo $file")
    [ ! -f "$LOG_DIR/$file" -a ! -f "$file" ] && break
    if [[ $# -eq 0 && "$op" == [asn] || $# -eq 1 && "$op" == [xi] ]]; then
        compreply=(-)
    elif [[ "$op" == [mpot] ]]; then
        __log_print "$file"
    elif [[ "$op" != [edxi] || $# -ge 2 && "$op" == [xi] ]] ||
        __log_print "$file"
    then
        :
    else
        choices=$(echo "$output" | awk '{print $1}')
    fi
    break
    done
    COMPREPLY=("${compreply[@]}" $(compgen -W "$choices" -- "$cur"))
    if [ "$compfiles" ]; then
        local IFS=$'\n'
        COMPREPLY+=($( [ "$PWD" != "$LOG_DIR" ] && cd "$LOG_DIR" 2>/dev/null &&
                       find . -wholename "./$cur*" \( -type f -o -type l \) |
                       cut -c 3- )
                    $( compgen -f -- "$cur" ))
    fi
    return 0
}

# helper functions
__log_op() {
    if [[ "$1" == [mpotedxiasncrh] || "$1" == [poe][fl] ]]; then
        op="${1:0:1}"
    elif [[ "$1" =~ ^n[^[:alnum:]]+$ ]]; then
        op="n"
    else
        false
    fi
}
__log_print() {
    [ "$COMP_TYPE" = 63 ] && return 1
    local color=35
    output=$($LOG "$1" o 2>/dev/null)
    [ $? -ne 0 -o -z "$output" ] && return 1
    if [ -z "$cur" ]; then
        if [ $COMP_TYPE != 37 ]; then
            echo -e "\e[${color}m" && echo "$output" && echo -en "\e[0m"
            [ -f "$LOG_DIR/$1" ] && compreply="$LOG_DIR/$1" || compreply="$1"
            choices="$DBSP$( ls -lh "$compreply" | cut -d " " -f 5-7 | \
                             sed -e 's/\(.*\)[[:blank:]]\+/\1'$NBSP'/' \
                                 -e 's/[[:blank:]]\+/ '$NBSP'/' )"
            compreply=$(basename -- "$compreply")
            return 0
        fi
    elif [[ "$cur" =~ ^[0-9]+$ ]]; then
        if [ $COMP_TYPE != 37 ]; then
            local preview=$($LOG -n "$1" p "$cur" | awk -v LIMIT=16 '
                NR <= LIMIT {
                    print;
                } END {
                    if (NR) print NR-LIMIT;
                }') over
            if [ "$preview" ]; then
                echo -e "\e[${color}m"
                printf "%s" "$preview" | head -n -1
                echo -en "\e[0m"
                over=${preview##*$'\n'}
                if (( $over > 0 )) 2>/dev/null; then
                    echo -n ... $over more line
                    (( $over > 1 )) && echo s || echo
                fi
                compreply+=("$NBSP" "$DBSP")
            fi
        fi
        choices="0 $(echo "$output" | awk '{print $1}')"
        return 0
    fi
    return 1
}

# vim:set ts=4 sw=4 et:
