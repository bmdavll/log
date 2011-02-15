#!/bin/bash

errorExit() {
    [ "$1" ] && echo >&2 "$(basename $0): $1"
    exit 1
}
trap "errorExit aborted" 2 3
trap "errorExit terminated" 1 15

if type "$1" &>/dev/null
then PROG="$1" && shift
else errorExit
fi

[ $# -ne 0 ] && errorExit

declare -a opt
opt[1]=2
opt[2]=2
opt[3]=3
opt[4]=3
opt[5]=4
opt[6]=4

declare -i tests=1 i
for i in "${!opt[@]}"; do
    tests=$(( tests * ${opt[i]} ))
done

exec 1>"$PROG.sh"
echo '#!/bin/bash'
echo '# test script for '"$PROG"
echo
echo 'set -e'
echo 'cd "$(dirname "$(readlink -f "$(which "$0")")")" 2>/dev/null'
echo

for i in $(seq 1 $tests); do
    echo -n 'echo "█◙█ '$i$'\t'
    opts=()
    for n in $(seq 1 ${#opt[@]}); do
        choices=${opt[$n]}
        c=$((i % choices))
        i=$((i / choices))
        case $n in
        1)  case $c in
            0)  opts+=(lines.inp)
                ;;
            1)  opts+=(-d"'>>'" delim.inp)
                ;;
            esac
            ;;
        2)  case $c in
            1)  opts+=(-c"'#'")
                ;;
            esac
            ;;
        3)  case $c in
            1)  opts+=(-g"'[FB]oo'" -g"'B[aeiou]T'" -i)
                ;;
            2)  opts+=(--grep-not="'[fb]oo'" -G "'b[aeiou]t'" -o)
                ;;
            esac
            ;;
        4)  case $c in
            0)  opts+=(-f7:)
                ;;
            1)  opts+=(-a -f0:3 -e:2 -e4:5,-1: -e0)
                ;;
            2)  opts+=(-a --sort)
                ;;
            esac
            ;;
        5)  case $c in
            1)  opts+=(--first --first-line -n)
                ;;
            2)  opts+=(--last -n"'.'" --canonical -rw)
                ;;
            3)  opts+=(-N"'['" -n"'] '" --wrap=16)
                ;;
            esac
            ;;
        6)  case $c in
            1)  opts+=(-p -t4 --separate-entries)
                ;;
            2)  opts+=(--list)
                ;;
            3)  opts+=(--list --count)
                ;;
            esac
            ;;
        esac
    done
    echo "${opts[@]}"\"
    echo "$PROG ${opts[@]}"
done

chmod +x "$PROG.sh"

# vim:set ts=4 sw=4 et:
