/* PL/0 scanner lex source code */
/* written by rockcarry */

/* ���岿�� */
%{
#include "parser.tab.h"
%}

/* �����Ǻ궨�� */
letter  [A-Za-z]
D       [0-9]
alnum   [A-Za-z0-9]
white   [ \t\r\n]
iden    {letter}{alnum}*
%start  COMMENT

%%
                 /* ������ʶ����򲿷� */
                 /* ʶ��ע�� */
"{"              { BEGIN COMMENT; }
<COMMENT>"}"     { BEGIN 0;       }
<COMMENT>\n      { }
<COMMENT>[^\}]+  { }

                              /* ʶ��ؼ��� */
[Pp][Rr][Oo][Gg][Rr][Aa][Mm]  { return TK_PROGRAM; }  /* Program */
[Bb][Ee][Gg][Ii][Nn]          { return TK_BEGIN;   }  /* Begin   */
[Ee][Nn][Dd]                  { return TK_END;     }  /* End     */
[Vv][Aa][Rr]                  { return TK_VAR;     }  /* Var     */
[Ii][Nn][Tt][Ee][Gg][Ee][Rr]  { return TK_INTEGER; }  /* Integer */
[Rr][Ee][Aa][Ll]              { return TK_REAL;    }  /* Real    */
[Ww][Hh][Ii][Ll][Ee]          { return TK_WHILE;   }  /* While   */
[Dd][Oo]                      { return TK_DO;      }  /* Do      */
[Ii][Ff]                      { return TK_IF;      }  /* If      */
[Tt][Hh][Ee][Nn]              { return TK_THEN;    }  /* Then    */
[Ee][Ll][Ss][Ee]              { return TK_ELSE;    }  /* Else    */
[Oo][Rr]                      { return TK_OR;      }  /* Or      */
[Aa][Nn][Dd]                  { return TK_AND;     }  /* And     */
[Nn][Oo][Tt]                  { return TK_NOT;     }  /* Not     */
[Pp][Rr][Ii][Nn][Tt]          { return TK_PRINT;   }  /* Print   */
[Ii][Nn][Pp][Uu][Tt]          { return TK_INPUT;   }  /* Input   */

           /* ʶ���ʶ�� */
{iden}     { return TK_IDEN;    }

           /* ʶ�������� */
{D}+       { return TK_INTNUM;  } 

           /* ʶ��ʵ���� */
{D}*\.{D}+ { return TK_REALNUM; }

           /* ʶ��հ��ַ� */
{white}+   { }

      /* ������ʶ������� */
"+"   { return '+';      }
"-"   { return '-';      }
"*"   { return '*';      }
"/"   { return '/';      }
"<"   { return '<';      }
">"   { return '>';      }
"="   { return '=';      }
"<="  { return TK_LE;    }
">="  { return TK_GE;    }
"<>"  { return TK_NE;    }
":="  { return TK_ASIGN; }
","   { return ',';      }
";"   { return ';';      }
"."   { return '.';      }
":"   { return ':';      }

      /* error char */
.     { printf("Invalid char:%s\n", yytext); return TK_ERRCHAR; }

%%
/* �����Ǹ����������� */
int yywrap(void) { return 1; }

/* ���Գ��� */
#ifdef _TEST_SCANNER_
int main(int argc, char *argv[])
{
    int code;

    if (argc < 2) {
        printf("PL/0 scanner v0.2 \r\n");
        printf("written by rockcarry \r\n");
        printf("\r\n");
        return 0;
    }

    yyin = fopen(argv[1], "rb");
    if (!yyin) {
        printf("failed to open source file: %s ! \r\n", argv[1]);
        return -1;
    }

    /* ��ʼ���дʷ����� */
    while ((code = yylex()) != 0) {
        fprintf(yyout, "%3d    %s\r\n", code, yytext);
    }

    /* �ʷ�������� */
    fclose(yyin);
    return 0;
}
#endif







