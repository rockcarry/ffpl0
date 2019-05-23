#!/bin/sh

set -e

case "$1" in
"")
    flex scanner.l && bison -d parser.y
    gcc -o scanner  -D_TEST_SCANNER_  lex.yy.c
    gcc -o compiler -D_TEST_COMPILER_ lex.yy.c parser.tab.c
    ;;
clean)
    rm -rf *.c *.h *.exe *.out
    ;;
esac
