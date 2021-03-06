#!/bin/bash

errorExit() {
    [ "$1" ] && echo >&2 $'\n'"$(basename $0): $1"
    exit 1
}
trap "errorExit aborted" 2 3
trap "errorExit terminated" 1 15

if type "$1" &>/dev/null
then PROG="$1" && shift
else errorExit
fi

[ $# -ne 0 ] && errorExit

cd "$(dirname "$(readlink -f "$(which "$0")")")" 2>/dev/null || errorExit

if type echoc &>/dev/null
then c=c
else unset c
fi

echoExec() {
    echo "█◙█ $@" && "$@"
}
iterFiles() {
    echoExec $PROG "${opts[@]}" empty.inp
    for i in {0..2}; do
        for file in lines.$i*.inp; do
            echoExec $PROG "${opts[@]}" "$file"
        done
    done
    echoExec $PROG "${opts[@]}" lines.inp
    python -c "print '█'*40"
    echoExec $PROG "${opts[@]}" -d'>>' empty.inp
    for i in {0..2}; do
        for file in delim.$i*.inp; do
            echoExec $PROG "${opts[@]}" -d'>>' "$file"
        done
    done
    echoExec $PROG "${opts[@]}" -d'>>' delim.inp
}
runTest() {
    echo${c} -n ${c+red} "[$((++num))] "
    echo "$test"
    echo "${opts[@]:+(}${opts[@]:-No options}${opts[@]:+)}"
    echo${c} -n ${c+blue} "Skip? "
    read
    if [[ "$REPLY" != [Yy]* ]]; then
        iterFiles | less
    fi
}

declare -i num=0

test="Random"
opts=(-m)
runTest

test="Grep, case insensitive"
opts=(-c'#' -g'[FB]oo' -o -i)
runTest

test="Grep, inverted"
opts=(-c'#' -G'[fb]oo' -o)
runTest

test="Grep, search all"
opts=(-c'#' -g'[fb]oo')
runTest

test="Sorted"
opts=(-c'#' -s)
runTest

test="All, tabs expanded"
opts=(-a -t4)
runTest

test="All, without comments (numbered)"
opts=(-c'#' -a -n' ')
runTest

test="All, comments preserved"
opts=(-c'#' -a -n' ' -p)
runTest

test="Fixed, wrapped"
opts=(-c'#' -f'2:' --wrap=40 -n' ')
runTest

test="Fixed, including zero (canonically numbered)"
opts=(-c'#' -f'0:1' -f'3:4' -f'9:' -N'[' -n']' --canonical)
runTest

test="Exclude (canonically numbered)"
opts=(-c'#' -e'0:1' -e'3:4' -n' ' --canonical)
runTest

test="Random, except all but first"
opts=(-c'#' -m -e'2:' -n' ')
runTest

test="Random, fixed"
opts=(-c'#' -m -f'1:3' -n' ')
runTest

test="First, comments preserved"
opts=(-c'#' -g'b[aeiou]t' --first -p -n' ')
runTest

test="(Next to) last"
opts=(-c'#' -ae'-1' --last -n' ')
runTest

test="First line, raw"
opts=(-c'#' -ae'4:' --first-line -r -n' ')
runTest

test="List, including zero"
opts=(-c'#' -f'0:9' -g'[fb]oo' --list)
runTest

test="Count"
opts=(-c'#' -f'0:9' -g'[fb]oo' --count)
runTest

exit 0

# vim:set ts=4 sw=4 et:
