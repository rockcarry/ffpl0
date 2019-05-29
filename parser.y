/* PL/0 parser yacc source code */
/* written by rockcarry */

/* 说明部分 */
%{
/* 包含头文件 */
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "parser.tab.h"

/* 外部符号声明 */
extern char *yytext;
extern int   yylex(void);
extern FILE *yyin;
extern FILE *yyout;

/* 常量定义 */
#define MAX_NLIST_SIZE  100
#define MAX_VLIST_SIZE  100
#define MAX_QLIST_SIZE  100

/* 类型定义 */
typedef struct {
    char name[MAX_VNAME_SIZE]; /* 变量名 */
} NAMEITEM;

typedef struct {
    int  type;  /* 数据类型 */
    int  nidx;  /* 变量名索引 */
} VARITEM;

typedef struct {
    uint8_t optr;    /* 操作符  */
    int32_t result;  /* 操作结果*/
    int32_t opnd1;   /* 操作数1 */
    int32_t opnd2;   /* 操作数2 */
} QUATER;

/* 内部全局变量定义 */
static NAMEITEM g_nlist[MAX_NLIST_SIZE] = {0};
static VARITEM  g_vlist[MAX_VLIST_SIZE] = {0};
static QUATER   g_qlist[MAX_QLIST_SIZE] = {0};
static int NXN = 1;
static int NXV = 1;
static int NXQ = 1;
static int TMP_VAR_IDX = 1;

enum {
    AEXPRT_UNKNOWN,
    AEXPRT_INTEGER,
    AEXPRT_REAL,
};

enum {
    OP_STOP  ,  /* 停机 */
    OP_IADD  ,  /* 整型加法 */
    OP_IMINUS,  /* 整型减法 */
    OP_IMULT ,  /* 整型乘法 */
    OP_IDIV  ,  /* 整型除法 */

    OP_RADD  ,  /* 实型加法 */
    OP_RMINUS,  /* 实型减法 */
    OP_RMULT ,  /* 实型乘法 */
    OP_RDIV  ,  /* 实型除法 */

    OP_ITR   ,  /* 整型转换为实型 */
    OP_RTI   ,  /* 实型转换为整型 */
    OP_ASIGNI,  /* 赋值，整数到内存 */
    OP_ASIGNR,  /* 赋值，实数到内存 */
    OP_ASIGNM,  /* 赋值，内存到内存 */

    OP_IPRT  ,
    OP_RPRT  ,
    OP_IIPT  ,
    OP_RIPT  ,

    OP_JMP   ,
    OP_IJL   ,
    OP_IJLE  ,
    OP_IJE   ,
    OP_IJG   ,
    OP_IJGE  ,
    OP_IJNE  ,
    OP_RJL   ,
    OP_RJLE  ,
    OP_RJE   ,
    OP_RJG   ,
    OP_RJGE  ,
    OP_RJNE  ,
};

static void yyerror(char *err);
static int  lookup_var  (char *name);
static int  add_new_var (char *name);
static void fix_var_type(int chain, int type);
static int  tmpvar_pop  (int type);
static void tmpvar_push (void);
static void tmpvar_reset(void);
static int  GEN(uint8_t optr, int result, int opnd1, int opnd2);
static void fix_jmp_addr(int jmp, int addr);
static void handle_aexpr(AttrAExpr *result, AttrAExpr *expr1, AttrAExpr *expr2, int op);
%}

/* 文法开始符号 */
%start ProgDef

/* 属性联合定义 */
%code requires {
    #define MAX_VNAME_SIZE  21
    typedef struct {
        int isvar;
        int type ;
        union {
            int32_t ival;
            float   fval;
            int32_t vidx;
        } v;
    } AttrAExpr;

    typedef struct {
        int loop;
        int tc;
        int fc;
    } AttrBExpr;
}

%union
{
    AttrAExpr AttrAExpr;
    AttrBExpr AttrBExpr;
    char      AttrVar[MAX_VNAME_SIZE];
    int       AttrVChain;
    int       AttrRop;
}

%type <AttrVar>     Variable
%type <AttrVChain>  VarList
%type <AttrVChain>  VarType
%type <AttrAExpr>   Const
%type <AttrAExpr>   Factor
%type <AttrAExpr>   Term
%type <AttrAExpr>   AExpr
%type <AttrRop>     Rop
%type <AttrBExpr>   BExpr
%type <AttrBExpr>   IfStatement
%type <AttrBExpr>   Condition
%type <AttrBExpr>   CondStElse
%type <AttrBExpr>   WHILE
%type <AttrBExpr>   WED

/* 文法终结符号 */
%token TK_IDEN    256  /* 标识符 */
%token TK_INTNUM  257  /* 整型数 */
%token TK_REALNUM 258  /* 实型数 */

/* 以下是关键字常量定义 */
%token TK_PROGRAM 259  /* Program */
%token TK_BEGIN   260  /* Begin   */
%token TK_END     261  /* End     */
%token TK_VAR     262  /* Var     */
%token TK_INTEGER 263  /* Integer */
%token TK_REAL    264  /* Real    */
%token TK_WHILE   265  /* While   */
%token TK_DO      266  /* Do      */
%token TK_IF      267  /* If      */
%token TK_THEN    268  /* Then    */
%token TK_ELSE    269  /* Else    */
%token TK_OR      270  /* Or      */
%token TK_AND     271  /* And     */
%token TK_NOT     272  /* Not     */
%token TK_PRINT   273  /* Print   */
%token TK_INPUT   274  /* Input   */

/* 以下为运算符常量定义 */
%token TK_LE      275  /* <= */
%token TK_GE      276  /* >= */
%token TK_NE      277  /* <> */
%token TK_ASIGN   278  /* := */

%token TK_ERRCHAR 279  /* 非法字符 */

/* 非终结符属性定义 */
%%
                /* 识别规则部分 */
ProgDef         :   TK_PROGRAM TK_IDEN ';' SubProg {}
                ;

SubProg         :   VarDef TK_BEGIN StatementList TK_END '.' { GEN(OP_STOP, 0, 0, 0); }
                ;

VarDef          :   TK_VAR VarDefList ';' { TMP_VAR_IDX = NXV; }
                ;

VarDefList      :   VarDefState {}
                |   VarDefList ';' VarDefState {}
                ;

VarDefState     :   VarList ':' VarType { fix_var_type($1, $3); }
                ;

VarList         :   Variable
                    {
                        $$ = lookup_var($1);
                        if ($$) printf("redefine variable: %s !\r\n", $1);
                        else    $$ = add_new_var($1);
                    }
                |   VarList ',' Variable
                    {
                        $$ = lookup_var($3);
                        if ($$) printf("redefine variable: %s !\r\n", $3);
                        else    $$ = add_new_var($3);
                    }
                ;

VarType         :   TK_INTEGER  { $$ = AEXPRT_INTEGER; }
                |   TK_REAL     { $$ = AEXPRT_REAL;    }
                ;

Variable        :   TK_IDEN     { strcpy($$, yytext);  }
                ;

Const           :   TK_INTNUM
                    {
                        $$.isvar  = 0;
                        $$.type   = AEXPRT_INTEGER;
                        $$.v.ival = (int32_t)atoi(yytext);
                    }
                |   TK_REALNUM
                    {
                        $$.isvar  = 0;
                        $$.type   = AEXPRT_REAL;
                        $$.v.fval = (float  )atof(yytext);
                    }
                ;

Factor          :   Variable
                    {
                        $$.v.vidx = lookup_var($1);
                        $$.isvar  = 1;
                        $$.type   = g_vlist[$$.v.vidx].type;
                    }
                |   Const         { $$ = $1; }
                |   '(' AExpr ')' { $$ = $2; }

Term            :   Factor { $$ = $1; }
                |   Term '*' Factor { handle_aexpr(&$$, &$1, &$3, '*'); }
                |   Term '/' Factor { handle_aexpr(&$$, &$1, &$3, '/'); }
                ;

AExpr           :   Term   { $$ = $1; }
                |   AExpr '+' Term  { handle_aexpr(&$$, &$1, &$3, '+'); }
                |   AExpr '-' Term  { handle_aexpr(&$$, &$1, &$3, '-'); }
                ;

AsignStatement  :   Variable TK_ASIGN AExpr
                    {
                        int v = lookup_var($1);
                        if (v == 0) printf("undefined variable: %s !\r\n", $1);
                        if ($3.isvar) {
                            if (g_vlist[v].type == $3.type) {
                                if (NXQ > 1 && g_qlist[NXQ - 1].result == $3.v.vidx) {
                                    g_qlist[NXQ - 1].result = v;
                                } else {
                                    GEN(OP_ASIGNM, v, $3.v.vidx, 0);
                                }
                            } else {
                                GEN($3.type == AEXPRT_INTEGER ? OP_ITR : OP_RTI, v, $3.v.vidx, 0);
                            }
                        } else {
                            if (g_vlist[v].type == $3.type) {
                                GEN($3.type == AEXPRT_INTEGER ? OP_ASIGNI : OP_ASIGNR, v, $3.v.ival, 0);
                            } else {
                                int t = tmpvar_pop($3.type);
                                GEN($3.type == AEXPRT_INTEGER ? OP_ASIGNI : OP_ASIGNR, t, $3.v.ival, 0);
                                GEN($3.type == AEXPRT_INTEGER ? OP_ITR : OP_RTI, v, t, 0);
                                if (t) tmpvar_push();
                            }
                        }
                    }
                ;

IOStatement     : TK_INPUT Variable
                {
                    int v = lookup_var($2);
                    if (v == 0) printf("undefined variable: %s !\r\n", $2);
                    GEN(g_vlist[v].type == AEXPRT_INTEGER ? OP_IIPT : OP_RIPT, v, 0, 0);
                }
                | TK_PRINT AExpr
                {
                    if ($2.isvar) {
                        GEN($2.type == AEXPRT_INTEGER ? OP_IPRT : OP_RPRT, $2.v.vidx, 0, 0);
                    } else {
                        int t = tmpvar_pop($2.type);
                        GEN($2.type == AEXPRT_INTEGER ? OP_ASIGNI : OP_ASIGNR, t, $2.v.ival, 0);
                        GEN($2.type == AEXPRT_INTEGER ? OP_IPRT : OP_RPRT, t, 0, 0);
                        if (t) tmpvar_push();
                    }
                }
                ;

IfStatement     :   Condition Statement  { $$ = $1; }
                |   CondStElse Statement { $$ = $1; }
                ;

CondStElse      :   Condition Statement TK_ELSE
                    {
                        $$.fc = $1.fc;
                        $$.tc = NXQ;
                        GEN(OP_JMP, 0, 0, 0);
                        fix_jmp_addr($1.fc, NXQ);
                    }
                ;

Condition       :   TK_IF BExpr TK_THEN { $$ = $2; }
                ;

WhileStatement  :   WED Statement
                    {
                        GEN(OP_JMP, $1.loop, 0, 0);
                        fix_jmp_addr($1.fc, NXQ);
                    }
                ;

WHILE           :   TK_WHILE { $$.loop = NXQ; }
                ;

WED             :   WHILE BExpr TK_DO { $$.loop = $1.loop; $$.fc = $2.fc;}
                ;

SeriesSem       :   Series ';' {}
                ;

Series          :   Statement {}
                |   SeriesSem Statement {}
                ;

ComStatement    :   TK_BEGIN Series TK_END {}
                ;

Statement       :   AsignStatement { tmpvar_reset(); }
                |   IOStatement    {}
                |   IfStatement    { fix_jmp_addr($1.tc, NXQ); fix_jmp_addr($1.fc, NXQ); }
                |   WhileStatement {}
                |   ComStatement   {}
                ;

StatementList   :   Statement {}
                |   StatementList ';' Statement {}
                ;

Rop             :   '<'   { $$ = '<';   }
                |   '>'   { $$ = '>';   }
                |   '='   { $$ = '=';   }
                |   TK_LE { $$ = TK_LE; }
                |   TK_GE { $$ = TK_GE; }
                |   TK_NE { $$ = TK_NE; }
                ;

BExpr           :   AExpr Rop AExpr
                    {
                        int ioptr = 0, roptr = 0;
                        switch ($2) {
                        case '<'  : ioptr = OP_IJGE; roptr = OP_RJGE; break;
                        case '>'  : ioptr = OP_IJLE; roptr = OP_RJLE; break;
                        case '='  : ioptr = OP_IJNE; roptr = OP_RJNE; break;
                        case TK_LE: ioptr = OP_IJG ; roptr = OP_RJG ; break;
                        case TK_GE: ioptr = OP_IJL ; roptr = OP_RJL ; break;
                        case TK_NE: ioptr = OP_IJE ; roptr = OP_RJE ; break;
                        }
                        if ($1.type == $3.type) {
                            $$.fc = NXQ + 0;
                            GEN($1.type == AEXPRT_INTEGER ? ioptr : roptr, 0, $1.v.vidx, $3.v.vidx);
                        } else {
                            int var = tmpvar_pop(AEXPRT_REAL);
                            $$.fc = NXQ + 1;
                            if ($1.type == AEXPRT_INTEGER) {
                                GEN(OP_ITR, var, $1.v.vidx, 0);
                                GEN(roptr, 0, var, $3.v.vidx);
                            } else if ($3.type == AEXPRT_INTEGER) {
                                GEN(OP_ITR, var, $3.v.vidx, 0);
                                GEN(roptr, 0, $1.v.vidx, var);
                            }
                            if (var) tmpvar_push();
                        }
                    }
                ;
%%
/* 程序部分 */
static void yyerror(char *err)
{
    printf("\r\n%s %s\r\n", yytext, err);
}

static int lookup_var(char *name)
{
    int i;
    for (i=1; i<NXV; i++) {
        if (strcmp(name, g_nlist[g_vlist[i].nidx].name) == 0) {
            return i;
        }
    }
    return 0;
}

static int add_new_var(char *name)
{
    if (NXV < MAX_NLIST_SIZE) {
        strcpy(g_nlist[NXN].name, name);
        g_vlist[NXV].type = 0;
        g_vlist[NXV].nidx = NXN++;
        return NXV++;
    } else return 0;
}

static void fix_var_type(int chain, int type)
{
    int i;
    for (i=chain; i>0; i--) {
        if (g_vlist[i].type == 0) {
            g_vlist[i].type = type;
        }
    }
}

static int tmpvar_pop(int type)
{
    if (NXV < MAX_NLIST_SIZE) {
        g_vlist[NXV].type = type;
        g_vlist[NXV].nidx = 0;
        return NXV++;
    } else {
        printf("failed to allocate temp variable !\r\n");
        return 0;
    }
}

static void tmpvar_push (void) { if (NXV > TMP_VAR_IDX) NXV--; }
static void tmpvar_reset(void) { NXV = TMP_VAR_IDX; }

static int GEN(uint8_t optr, int result, int opnd1, int opnd2)
{
    if (NXQ < MAX_QLIST_SIZE) {
        g_qlist[NXQ].optr   = optr;
        g_qlist[NXQ].opnd1  = opnd1;
        g_qlist[NXQ].opnd2  = opnd2;
        g_qlist[NXQ].result = result;
        return NXQ++;
    } else return 0;
}

static void fix_jmp_addr(int jmp, int addr)
{
    if (jmp && !g_qlist[jmp].result) g_qlist[jmp].result = addr;
}

static void handle_aexpr(AttrAExpr *result, AttrAExpr *expr1, AttrAExpr *expr2, int op)
{
    int iopcode = 0, ropcode = 0;
    if (!expr1->isvar && !expr2->isvar) {
        result->isvar = 0;
        if (expr1->type == expr2->type) {
            if (expr1->type == AEXPRT_INTEGER) {
                result->type = AEXPRT_INTEGER;
                switch (op) {
                case '+': result->v.ival = expr1->v.ival + expr2->v.ival; break;
                case '-': result->v.ival = expr1->v.ival - expr2->v.ival; break;
                case '*': result->v.ival = expr1->v.ival * expr2->v.ival; break;
                case '/': result->v.ival = expr1->v.ival / expr2->v.ival; break;
                }
            } else {
                result->type = AEXPRT_REAL;
                switch (op) {
                case '+': result->v.fval = expr1->v.fval + expr2->v.fval; break;
                case '-': result->v.fval = expr1->v.fval - expr2->v.fval; break;
                case '*': result->v.fval = expr1->v.fval * expr2->v.fval; break;
                case '/': result->v.fval = expr1->v.fval / expr2->v.fval; break;
                }
            }
        } else {
            result->type = AEXPRT_REAL;
            if (expr1->type == AEXPRT_INTEGER) {
                switch (op) {
                case '+': result->v.fval = expr1->v.ival + expr2->v.fval; break;
                case '-': result->v.fval = expr1->v.ival - expr2->v.fval; break;
                case '*': result->v.fval = expr1->v.ival * expr2->v.fval; break;
                case '/': result->v.fval = expr1->v.ival / expr2->v.fval; break;
                }
            } else {
                switch (op) {
                case '+': result->v.fval = expr1->v.fval + expr2->v.ival; break;
                case '-': result->v.fval = expr1->v.fval - expr2->v.ival; break;
                case '*': result->v.fval = expr1->v.fval * expr2->v.ival; break;
                case '/': result->v.fval = expr1->v.fval / expr2->v.ival; break;
                }
            }
        }
    } else {
        AttrAExpr expr;
        switch (op) {
        case '+': iopcode = OP_IADD  ; ropcode = OP_RADD  ; break;
        case '-': iopcode = OP_IMINUS; ropcode = OP_RMINUS; break;
        case '*': iopcode = OP_IMULT ; ropcode = OP_RMULT ; break;
        case '/': iopcode = OP_IDIV  ; ropcode = OP_RDIV  ; break;
        }
        if (!expr1->isvar) {
            expr.isvar  = 1;
            expr.type   = expr1->type;
            expr.v.vidx = tmpvar_pop(expr1->type);
            GEN(expr1->type == AEXPRT_INTEGER ? OP_ASIGNI : OP_ASIGNR, expr.v.vidx, expr1->v.ival, 0);
            expr1 = &expr;
        } else if (!expr2->isvar) {
            expr.isvar  = 1;
            expr.type   = expr2->type;
            expr.v.vidx = tmpvar_pop(expr2->type);
            GEN(expr2->type == AEXPRT_INTEGER ? OP_ASIGNI : OP_ASIGNR, expr.v.vidx, expr2->v.ival, 0);
            expr2 = &expr;
        }
        if (expr1->type == expr2->type) {
            result->type   = expr1->type;
            result->v.vidx = tmpvar_pop(result->type);
            GEN(result->type == AEXPRT_INTEGER ? iopcode : ropcode, result->v.vidx, expr1->v.vidx, expr2->v.vidx);
        } else {
            result->type   = AEXPRT_REAL;
            result->v.vidx = tmpvar_pop(result->type);
            if (expr1->type == AEXPRT_INTEGER) {
                GEN(OP_ITR , result->v.vidx, expr1->v.vidx, 0);
                GEN(ropcode, result->v.vidx, result->v.vidx, expr2->v.vidx);
            } else if (expr2->type == AEXPRT_INTEGER) {
                GEN(OP_ITR , result->v.vidx, expr2->v.vidx, 0);
                GEN(ropcode, result->v.vidx, result->v.vidx, expr1->v.vidx);
            }
        }
    }
}

static void gen_name_list(FILE *fp)
{
    int i;
    fprintf(fp, "符号表\r\n");
    fprintf(fp, " no. name                \r\n");
    fprintf(fp, "-------------------------\r\n");
    for (i=1; i<NXN; i++) {
        fprintf(fp, "%3d. %-20s\r\n", i, g_nlist[i].name);
    }
    fprintf(fp, "\r\n\r\n");
}

static void gen_var_list(FILE *fp)
{
    char *type = NULL;
    int   i;
    fprintf(fp, "变量表\r\n");
    fprintf(fp, " no. name                 type \r\n");
    fprintf(fp, "-------------------------------\r\n");
    for (i=1; i<NXV; i++) {
        switch (g_vlist[i].type) {
        case AEXPRT_INTEGER: type = "int" ; break;
        case AEXPRT_REAL   : type = "real"; break;
        }
        fprintf(fp, "%3d. %-20s %s\r\n", i, g_nlist[g_vlist[i].nidx].name, type);
    }
    fprintf(fp, "\r\n\r\n");
}

static char* g_optrstr[] =
{
    "STOP", "I+  ", "I-  ", "I*  ", "I/  ", "R+  ", "R-  ", "R*  ", "R/  ", "ITR ", "RTI ", "I=  ", "R=  ", "M=  ",
    "IPRT", "RPRT", "IIPT", "RIPT", "JMP ",
    "IJL ", "IJLE", "IJE ", "IJG ", "IJGE", "IJNE", "IJL ", "IJLE", "IJE ", "IJG ", "IJGE", "IJNE",
    "RJL ", "RJLE", "RJE ", "RJG ", "RJGE", "RJNE", "RJL ", "RJLE", "RJE ", "RJG ", "RJGE", "RJNE",
};

static void gen_var_name(char *name, int size, int vidx)
{
    if (vidx < 1) {
        snprintf(name, sizeof(name), "");
    } else if (vidx < TMP_VAR_IDX) {
        snprintf(name, sizeof(name), "%s", g_nlist[vidx].name);
    } else {
        snprintf(name, sizeof(name), "T%d", vidx - TMP_VAR_IDX);
    }
}

static void gen_quater_list(FILE *fp)
{
    char result[MAX_VNAME_SIZE], opnd1[MAX_VNAME_SIZE], opnd2[MAX_VNAME_SIZE];
    int  i;
    fprintf(fp, "四元式序列\r\n");
    fprintf(fp, " NO.  OPTR   RESULT    OPND1    OPND2   \r\n");
    fprintf(fp, "----------------------------------------\r\n");
    for (i=1; i<NXQ; i++) {
        strcpy(result, ""); strcpy(opnd1 , ""); strcpy(opnd2 , "");
        if (g_qlist[i].optr == OP_ASIGNI) {
            snprintf(opnd1, sizeof(opnd1), "%d", g_qlist[i].opnd1);
        } else if (g_qlist[i].optr == OP_ASIGNR) {
            snprintf(opnd1, sizeof(opnd1), "%.2f", *(float*)&g_qlist[i].opnd1);
        } else if (g_qlist[i].optr >= OP_JMP && g_qlist[i].optr <= OP_RJNE) {
            snprintf(result, sizeof(result), "%d", g_qlist[i].result);
        }
        if (strcmp(result, "") == 0) gen_var_name(result, sizeof(result), g_qlist[i].result);
        if (strcmp(opnd1 , "") == 0) gen_var_name(opnd1 , sizeof(opnd1 ), g_qlist[i].opnd1 );
        if (strcmp(opnd2 , "") == 0) gen_var_name(opnd2 , sizeof(opnd2 ), g_qlist[i].opnd2 );
        fprintf(fp, "%3d. (%s,%8s,%8s,%8s)\r\n", i, g_optrstr[g_qlist[i].optr], result, opnd1, opnd2);
//      fprintf(fp, "%3d. (%s,%8d,%8d,%8d)\r\n", i, g_optrstr[g_qlist[i].optr], g_qlist[i].result, g_qlist[i].opnd1, g_qlist[i].opnd2);
    }
    fprintf(fp, "\r\n\r\n");
}

static void gen_quater_bin(FILE *fp)
{
    int i;
    for (i=0; i<NXQ; i++) {
        fwrite(&g_qlist[i], sizeof(g_qlist[i]), 1, fp);
    }
}

#ifdef _TEST_COMPILER_
int main(int argc, char *argv[])
{
    FILE *fpout;

    if (argc < 2) {
        printf("PL/0 compiler v0.2 \r\n");
        printf("written by rockcarry \r\n");
        printf("\r\n");
        return 0;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin) {
        printf("failed to open source file: %s ! \r\n", argv[1]);
        return -1;
    }

    fpout = fopen("a.out", "w");
    if (!fpout) {
        printf("failed to create a.out file !\r\n");
        return -1;
    }

    /* 开始编译 */
    yyparse();

    gen_name_list  (stdout);
    gen_var_list   (stdout);
    gen_quater_list(stdout);
    gen_quater_bin (fpout );

    fclose(fpout);
    fclose(yyin );
}
#endif


