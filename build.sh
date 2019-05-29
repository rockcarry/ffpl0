#!/bin/sh

set -e

case "$1" in
"")
    flex scanner.l && bison -d parser.y
    gcc -o scanner  -D_TEST_SCANNER_  lex.yy.c
    gcc -o compiler -D_TEST_COMPILER_ lex.yy.c parser.tab.c
    gcc -o ffvm ffvm.c
    ;;
clean)
    rm -rf parser.tab.* lex.yy.* *.exe *.out
    ;;
esac
