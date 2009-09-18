# bash completion for rand

! type rand &>/dev/null && return 1

_rand() {
    local cur="$2" choices
    if [[ "$cur" == - || "$cur" == --* ]]; then
        choices+=' --help --usage --delimiter= --comment='
        choices+=' --grep= --not --ignore-case --search-all'
        choices+=' --all --fixed= --exclude= --random --first --last'
        choices+=' --first-line --canonical --preserve --raw'
        choices+=' --tabs= --wrap --wrap= --list --count'
    elif [[ "$cur" =~ ^-[visamprw]*[dcgfet]?$ ]]; then
        choices="$cur"
    fi
    COMPREPLY=($(compgen -W "$choices" -- "$cur"))
}
complete -o bashdefault -o default -F _rand rand

# vim:set ts=4 sw=4 et:
