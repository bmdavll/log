/************************************************************************
*
*   Convert escapes (\s, \d, \S, and \D) in the first argument to their
*   character class counterparts ([[:space:]], [[:digit:]], etc.)
*   If no arguments are specified, read from standard input.
*
*   Copyright 2009 David Liang
*
*   This program is free software: you can redistribute it and/or modify
*   it under the terms of the GNU General Public License as published by
*   the Free Software Foundation, either version 3 of the License, or
*   (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU General Public License for more details.
*
*   You should have received a copy of the GNU General Public License
*   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*
************************************************************************/

#include <stdio.h>
#include <ctype.h>

char *p;

int scan(void)
{
    if (*p == '\0')
        return EOF;
    else
        return *p++;
}

int redo_scan(int c, FILE* fp)
{
    if (c != EOF)
        return *--p = c;
    else
        return EOF;
}

int main(int argc, char *argv[])
{
    int (*next)(void);
    int (*backup)(int, FILE*);

    const int BRACKET = 0x1;
    const int BRACKET_PROPER = 0x2;

    int state = 0;
    int c;

    if (argc == 2) {
        p = argv[1];
        next = scan;
        backup = redo_scan;
    }
    else if (argc != 1) {
        return 2;
    }
    else {
        p = NULL;
        next = getchar;
        backup = ungetc;
    }

    while ((c = next()) != EOF) {
        switch (c) {
        case '\\':
            if (! (state & BRACKET)) {
                switch (c = next()) {
                case 's':
                    printf("[[:space:]]");
                    break;
                case 'S':
                    printf("[^[:space:]]");
                    break;
                case 'd':
                    printf("[[:digit:]]");
                    break;
                case 'D':
                    printf("[^[:digit:]]");
                    break;
                case EOF:
                    putchar('\\');
                    break;
                default:
                    putchar('\\');
                    putchar(c);
                    break;
                }
            }
            else {
                putchar('\\');
                state |= BRACKET_PROPER;
            }
            break;
        case '[':
            putchar('[');
            if (! (state & BRACKET)) {
                state |= BRACKET;
                if ((c = next()) == '^')
                    putchar('^');
                else
                    backup(c, stdin);
            }
            else {
                state |= BRACKET_PROPER;
                if ((c = next()) == ':') {
                    putchar(':');
                    while (islower(c = next())) {
                        putchar(c);
                    }
                    if (c == ':') {
                        putchar(':');
                        if ((c = next()) == ']') {
                            putchar(']');
                        }
                        else backup(c, stdin);
                    }
                    else backup(c, stdin);
                }
                else backup(c, stdin);
            }
            break;
        case ']':
            putchar(']');
            if (state & BRACKET) {
                if (state & BRACKET_PROPER) {
                    state &= ~BRACKET_PROPER;
                    state &= ~BRACKET;
                }
                else {
                    state |= BRACKET_PROPER;
                }
            }
            break;
        default:
            putchar(c);
            if (state & BRACKET) {
                state |= BRACKET_PROPER;
            }
            break;
        }
    }

    if (argc == 2)
        putchar('\n');

    return 0;
}

/* vim:set ts=4 sw=4 et fdm=indent: */
