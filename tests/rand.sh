#!/bin/bash

errorExit() {
    [ "$1" ] && echo >&2 "$(basename $0): $1"
    exit 1
}
trap "errorExit aborted" 2 3
trap "errorExit terminated" 1 15

if type "$1" &>/dev/null
then RAND="$1" && shift
else RAND=rand
fi

[ $# -ne 0 ] && errorExit

cd "$(dirname "$(readlink -f "$(which "$0")")")" 2>/dev/null || errorExit

declare -a opt
opt[1]=2 # -d
opt[2]=2 # -c
opt[3]=3 # -g -vis
opt[4]=3 # -a -f -e
opt[5]=4 # --first --first-line --last -n --canonical -r -w
opt[6]=4 # -p -t --list --count

declare -i tests=1 i
for i in "${!opt[@]}"; do
    tests=$(( tests * ${opt[i]} ))
done

for i in $(seq 1 $tests); do
    echo -n "█◙█ $i"
    opts=()
    for n in $(seq 1 ${#opt[@]}); do
        choices=${opt[$n]}
        c=$((i % choices))
        i=$((i / choices))
        case $n in
        1)  case $c in
            0)  opts+=(lines.inp)
                ;;
            1)  opts+=(-d'>>' delim.inp)
                ;;
            esac
            ;;
        2)  case $c in
            1)  opts+=(-c'#')
                ;;
            esac
            ;;
        3)  case $c in
            1)  opts+=(-g'[FB]oo' -g'B[aeiou]T' -i)
                ;;
            2)  opts+=(--grep='[fb]oo' -g 'b[aeiou]t' --not -s)
                ;;
            esac
            ;;
        4)  case $c in
            0)  opts+=(--fixed=2:3,5 -f7:)
                ;;
            1)  opts+=(-a --exclude=:2 -e4:5,-1: -f0:3)
                ;;
            2)  opts+=(-a)
                ;;
            esac
            ;;
        5)  case $c in
            1)  opts+=(--first --first-line -n)
                ;;
            2)  opts+=(--last -n'.' --canonical -rw)
                ;;
            3)  opts+=(-N'[' -n'] ' --wrap=16)
                ;;
            esac
            ;;
        6)  case $c in
            1)  opts+=(-p -t4)
                ;;
            2)  opts+=(--list)
                ;;
            3)  opts+=(--list --count)
                ;;
            esac
            ;;
        esac
    done
    echo "	$RAND ${opts[@]}"
    $RAND "${opts[@]}" || exit $?
done

# vim:set ts=4 sw=4 et:
