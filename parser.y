/* PL/0 parser yacc source code */
/* written by rockcarry */

/* ˵������ */
%{
/* ����ͷ�ļ� */
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

/* �ⲿ�������� */
extern char *yytext;
extern int   yylex(void);
extern FILE *yyin;
extern FILE *yyout;

/* �������� */
#define MAX_STR_LEN     20
#define MAX_VLIST_SIZE  100
#define MAX_NLIST_SIZE  100
#define MAX_QLIST_SIZE  100

/* Ѱַ��ʽ */
#define ADDM_MEM   0   /* �洢��Ѱַ */
#define ADDM_IMM   1   /* ������Ѱַ */
#define ADDM_TEMP  2   /* ��ʱ����Ѱַ */

/* �����붨�� */
#define OP_STOP    0   /* ͣ�� */

/* ������������ */
#define OP_IADD    1   /* ���ͼӷ� */
#define OP_IMINUS  2   /* ���ͼ��� */
#define OP_IMULT   3   /* ���ͳ˷� */
#define OP_IDIV    4   /* ���ͳ��� */

/* ʵ���������� */
#define OP_RADD    5   /* ʵ�ͼӷ� */
#define OP_RMINUS  6   /* ʵ�ͼ��� */
#define OP_RMULT   7   /* ʵ�ͳ˷� */
#define OP_RDIV    8   /* ʵ�ͳ��� */

/* ��������ת�� */
#define OP_ITR     9   /* ����ת��Ϊʵ�� */
#define OP_RTI     10  /* ʵ��ת��Ϊ���� */

/* ��ת */
#define OP_JMP     11
#define OP_JNZ     12
#define OP_IJL     13
#define OP_IJLE    14
#define OP_IJE     15
#define OP_IJG     16
#define OP_IJGE    17
#define OP_IJNE    18
#define OP_RJL     19
#define OP_RJLE    20
#define OP_RJE     21
#define OP_RJG     22
#define OP_RJGE    23
#define OP_RJNE    24

/* ��ֵ */
#define OP_ASIGN   25

/* ���Ͷ��� */
/* �������� */
typedef struct
{
    int      type;  /* �������� */
    int      addm;  /* Ѱַ��ʽ */
    uint32_t value; /* ֵ */
} VarItem, *PVarItem;

/* ���ֱ��� */
typedef struct
{
    char strname[21]; /* ������ */
    int  varindex; /* �����ڱ������е����� */
} NameItem, *PNameItem;

/* ��Ԫʽ���Ͷ��� */
typedef struct
{
    uint8_t optr;    /* ������ */
    int     opnd1;   /* ������1 */
    int     opnd2;   /* ������2 */
    int     result;  /* �������ĵ�ַ */
} Quater,*PQuater;

/* �ڲ�ȫ�ֱ������� */
static VarItem  g_vlist[MAX_VLIST_SIZE] = {0};
static NameItem g_nlist[MAX_NLIST_SIZE] = {0};
static Quater   g_qlist[MAX_QLIST_SIZE] = {0};
static int NXV = 1;
static int NXN = 1;
static int NXQ = 1;

/* �ڲ��������� */
static int  yyparse();
static void yyerror(char *err);
static int  AllocateTempVar(int type);
static void FreeTempVar(int place);
static int  AddNewVar(int type, char *name);
static int  AddNewConst(int type, uint32_t value);
static int  LookUpVar(char *name);
static int  GEN(uint8_t optr, int opnd1, int opnd2, int result);
static void BackPatchChain(int chain, int value);
static int  MergeChain(int chain1, int chain2);
static void FillVarType(int chain, int type);
%}

/* �ķ���ʼ���� */
%start ProgDef

/* �������϶��� */
%union
{
    int  Attr_Type;   /* ��������   */
    int  Attr_Rop;    /* ��ϵ������ */
    int  Attr_Chain;  /* ������   */

    /* �������� */
    struct
    {
        int      type;  /* ������������ */
        uint32_t value; /* ������ֵ */
    } Attr_Const;

    /* �������� */
    char Attr_Var[21];

    /* �������ʽ���� */
    int Attr_AExpr;

    /* �������ʽ���� */
    struct
    {
        int tc;
        int fc;
    } Attr_BExpr;

    /* while ������� */
    struct
    {
        int chain;
        int loopstart;
    } Attr_While;
}

/* �ķ��ս���� */
%token TK_IDEN    100  /* ��ʶ�� */
%token TK_INTNUM  101  /* ������ */
%token TK_REALNUM 102  /* ʵ���� */  

/* �����ǹؼ��ֳ������� */
%token TK_PROGRAM 200  /* Program */
%token TK_BEGIN   201  /* Begin   */
%token TK_END     202  /* End     */
%token TK_VAR     203  /* Var     */
%token TK_INTEGER 204  /* Integer */
%token TK_REAL    205  /* Real    */
%token TK_WHILE   206  /* While   */
%token TK_DO      207  /* Do      */
%token TK_IF      208  /* If      */
%token TK_THEN    209  /* Then    */
%token TK_ELSE    210  /* Else    */
%token TK_OR      211  /* Or      */
%token TK_AND     212  /* And     */
%token TK_NOT     213  /* Not     */
%token TK_PRINT   214  /* Print   */
%token TK_INPUT   215  /* Input   */

/* ����Ϊ������������� */
%token TK_LE      300  /* <= */
%token TK_GE      301  /* >= */
%token TK_NE      302  /* <> */
%token TK_ASIGN   303  /* := */

%token TK_ERRCHAR 600  /* �Ƿ��ַ� */

/* ���ս�����Զ��� */

%type <Attr_Chain>  ProgDef
%type <Attr_Chain>  SubProg

%type <Attr_Chain>  VarDef
%type <Attr_Chain>  VarDefList
%type <Attr_Chain>  VarDefState
%type <Attr_Chain>  VarList
%type <Attr_Type>   VarType
%type <Attr_Var>    Variable

%type <Attr_Chain>  StatementList
%type <Attr_Chain>  Statement
%type <Attr_Chain>  AsignStatement
%type <Attr_Chain>  IfStatement
%type <Attr_Chain>  Condition
%type <Attr_Chain>  CondStElse
%type <Attr_Chain>  WhileStatement
%type <Attr_While>  WED
%type <Attr_While>  WHILE
%type <Attr_Chain>  ComStatement
%type <Attr_Chain>  Series
%type <Attr_Chain>  SeriesSem

%type <Attr_BExpr>  BExpr
%type <Attr_AExpr>  AExpr
%type <Attr_AExpr>  Term
%type <Attr_AExpr>  Factor
%type <Attr_Rop>    Rop
%type <Attr_Const>  Const

%%
               /* ʶ����򲿷� */
ProgDef        :   TK_PROGRAM TK_IDEN ';' SubProg
                   {
                       printf("\r\ndone.\r\n");
                       $$ = 0;
                   }
               ;

SubProg        :   VarDef TK_BEGIN StatementList TK_END '.'
                   {
                       GEN(OP_STOP, 0, 0, 0);
                       $$ = 0;
                   }
               ;

VarDef         :   TK_VAR VarDefList ';'      { $$ = 0; }
               ;

VarDefList     :   VarDefState                { $$ = 0; }
               |   VarDefList ';' VarDefState { $$ = 0; }
               ;

VarDefState    :   VarList ':' VarType { FillVarType($1, $3); $$ = 0; }
               ;

VarList        :   Variable
                   {
                       $$ = LookUpVar($1);
                       if ($$) yyerror("redefine variable !\r\n");
                       else $$ = AddNewVar(0, $1);
                   }
               |   VarList ',' Variable
                   {
                       $$ = LookUpVar($3);
                       if ($$) yyerror("redefine variable !\r\n");
                       else $$ = AddNewVar($1, $3);
                   }
               ;

VarType        :   TK_INTEGER { $$ = TK_INTNUM; }
               |   TK_REAL    { $$ = TK_REALNUM; }
               ;

StatementList  :  Statement { BackPatchChain($1, NXQ); $$ = 0; }
               |  StatementList ';' Statement { BackPatchChain($3, NXQ); $$ = 0; } 
               ;

Statement      :   AsignStatement { $$ = $1; }
               |   IfStatement    { $$ = $1; }
               |   WhileStatement { $$ = $1; }
               |   ComStatement   { $$ = $1; }
               ;

AsignStatement :   Variable TK_ASIGN AExpr
                   {
                       int i = LookUpVar($1);
                       if (i == 0) yyerror("undefined variable !\r\n");
                       if (g_vlist[i].type == g_vlist[$3].type) GEN(OP_ASIGN, $3, 0, i);
                       else
                       {
                           if (g_vlist[i].type == TK_INTNUM) GEN(OP_RTI, $3, 0, i);
                           else GEN(OP_ITR, $3, 0, i);
                       }
                       $$ = 0;
                   }
               ;

IfStatement    :   Condition Statement  { $$ = MergeChain($1, $2); }
               |   CondStElse Statement { $$ = MergeChain($1, $2); }
               ;

CondStElse     :   Condition Statement TK_ELSE
                   {
                       $$ = GEN(OP_JMP, 0, 0, 0);
                       $$ = MergeChain($$, $2);
                       BackPatchChain($1, NXQ);
                   }
               ;

Condition      :   TK_IF BExpr TK_THEN
                   {
                       BackPatchChain($2.tc, NXQ);
                       $$ = $2.fc;
                   }
               ;

WhileStatement :   WED Statement
                   {
                       BackPatchChain($2, $1.loopstart);
                       GEN(OP_JMP, 0, 0, $1.loopstart);
                       $$ = $1.chain;
                   }
               ;

WED            :   WHILE BExpr TK_DO
                   {
                       BackPatchChain($2.tc, NXQ);
                       $$.chain     = $2.fc;
                       $$.loopstart = $1.loopstart;
                   }
               ;

WHILE          :   TK_WHILE { $$.loopstart = NXQ; }
               ;

ComStatement   :   TK_BEGIN Series TK_END { $$ = $2; }
               ;

Series         :   Statement { $$ = $1; }
               |   SeriesSem Statement { $$ = $2; }
               ;

SeriesSem      :   Series ';' { BackPatchChain($1, NXQ); }
               ;

BExpr          :   AExpr Rop AExpr
                   {
                       uint8_t ioptr;
                       uint8_t roptr;
                       int     tempvar;
                       $$.tc = NXQ;
                       $$.fc = NXQ + 1;

                       switch ($2)
                       {
                       case '<':
                           ioptr = OP_IJL;
                           roptr = OP_RJL;
                           break;
                       case '>':
                           ioptr = OP_IJG;
                           roptr = OP_RJG;
                           break;
                       case '=':
                           ioptr = OP_IJE;
                           roptr = OP_RJE;
                           break;
                       case TK_LE:
                           ioptr = OP_IJLE;
                           roptr = OP_RJLE;
                           break;
                       case TK_GE:
                           ioptr = OP_IJGE;
                           roptr = OP_RJGE;
                           break;
                       case TK_NE:
                           ioptr = OP_IJNE;
                           roptr = OP_RJNE;
                           break;
                       }
                       if (g_vlist[$1].type == g_vlist[$3].type)
                       {
                           if (g_vlist[$1].type == TK_INTNUM) GEN(ioptr, $1, $3, 0);
                           else GEN(roptr, $1, $3, 0);
                       }
                       else
                       {
                           tempvar = AllocateTempVar(TK_REALNUM);
                           if (g_vlist[$1].type == TK_INTNUM)
                           {
                               GEN(OP_ITR, $1, 0, tempvar);
                               GEN(roptr, tempvar, $3, 0);
                           }
                           else
                           {
                               GEN(OP_ITR, $3, 0, tempvar);
                               GEN(roptr, $1, tempvar, 0);
                           }
                           FreeTempVar(tempvar);
                       }
                       GEN(OP_JMP, 0, 0, 0);
                   }
               ;

AExpr          :   Term { $$ = $1; }
               |   AExpr '+' Term
                   {
                       if (g_vlist[$1].type == g_vlist[$3].type)
                       {
                           $$ = AllocateTempVar(g_vlist[$1].type);
                           if (g_vlist[$1].type == TK_INTNUM) GEN(OP_IADD, $1, $3, $$);
                           else GEN(OP_RADD, $1, $3, $$);
                       }
                       else
                       {
                           $$ = AllocateTempVar(TK_REALNUM);
                           if (g_vlist[$1].type == TK_INTNUM)
                           {
                               GEN(OP_ITR, $1, 0, $$);
                               GEN(OP_RADD, $$, $3, $$);
                           }
                           else
                           {
                               GEN(OP_ITR, $3, 0, $$);
                               GEN(OP_RADD, $1, $$, $$);
                           }
                       }
                   }
               |   AExpr '-' Term
                   {
                       if (g_vlist[$1].type == g_vlist[$3].type)
                       {
                           $$ = AllocateTempVar(g_vlist[$1].type);
                           if (g_vlist[$1].type == TK_INTNUM) GEN(OP_IMINUS, $1, $3, $$);
                           else GEN(OP_RMINUS, $1, $3, $$);
                       }
                       else
                       {
                           $$ = AllocateTempVar(TK_REALNUM);
                           if (g_vlist[$1].type == TK_INTNUM)
                           {
                               GEN(OP_ITR, $1, 0, $$);
                               GEN(OP_RMINUS, $$, $3, $$);
                           }
                           else
                           {
                               GEN(OP_ITR, $3, 0, $$);
                               GEN(OP_RMINUS, $1, $$, $$);
                           }
                       }
                   }
               ;

Term           :   Factor { $$ = $1; }
               |   Term '*' Factor
                   {
                       if (g_vlist[$1].type == g_vlist[$3].type)
                       {
                           $$ = AllocateTempVar(g_vlist[$1].type);
                           if (g_vlist[$1].type == TK_INTNUM) GEN(OP_IMULT, $1, $3, $$);
                           else GEN(OP_RMULT, $1, $3, $$);
                       }
                       else
                       {
                           $$ = AllocateTempVar(TK_REALNUM);
                           if (g_vlist[$1].type == TK_INTNUM)
                           {
                               GEN(OP_ITR, $1, 0, $$);
                               GEN(OP_RMULT, $$, $3, $$);
                           }
                           else
                           {
                               GEN(OP_ITR, $3, 0, $$);
                               GEN(OP_RMULT, $1, $$, $$);
                           }
                       }
                   }
               |   Term '/' Factor
                   {
                       if (g_vlist[$1].type == g_vlist[$3].type)
                       {
                           $$ = AllocateTempVar(g_vlist[$1].type);
                           if (g_vlist[$1].type == TK_INTNUM) GEN(OP_IDIV, $1, $3, $$);
                           else GEN(OP_RDIV, $1, $3, $$);
                       }
                       else
                       {
                           $$ = AllocateTempVar(TK_REALNUM);
                           if (g_vlist[$1].type == TK_INTNUM)
                           {
                               GEN(OP_ITR, $1, 0, $$);
                               GEN(OP_RDIV, $$, $3, $$);
                           }
                           else
                           {
                               GEN(OP_ITR, $3, 0, $$);
                               GEN(OP_RDIV, $1, $$, $$);
                           }
                       }
                   }
               ;

Factor         :   Variable
                   {
                       $$ = LookUpVar($1);
                       if ($$ == 0) yyerror("undefined variable !\r\n");
                   }
               |   Const { $$ = AddNewConst($1.type, $1.value); }
               |   '(' AExpr ')' { $$ = $2; }
               ;

Variable       :   TK_IDEN { strcpy($$, yytext); }
               ;

Const          :   TK_INTNUM
                   {
                       $$.type  = TK_INTNUM;
                       $$.value = (uint32_t)atoi(yytext);
                   }
               |   TK_REALNUM
                   {
                       
                       $$.type  = TK_REALNUM;
                       $$.value = (uint32_t)atof(yytext);
                   }
               ;

Rop            :   '<'   { $$ = '<';   }
               |   '>'   { $$ = '>';   }
               |   '='   { $$ = '=';   }
               |   TK_LE { $$ = TK_LE; }
               |   TK_GE { $$ = TK_GE; }
               |   TK_NE { $$ = TK_NE; }
               ;

%%
/* ���򲿷� */
static void yyerror(char *err)
{
    printf("\r\n%s %s\r\n", yytext, err);
}

static int  AllocateTempVar(int type)
{
    static int tempnum = 0;
    if (NXV >= MAX_VLIST_SIZE) return 0;
    g_vlist[NXV].type  = type;
    g_vlist[NXV].addm  = ADDM_TEMP;
    g_vlist[NXV].value = (uint32_t)tempnum++;
    return NXV++;
}

static void FreeTempVar(int place)
{
    /* todo... */
}

static int  AddNewVar(int type, char *name)
{
    if (NXN >= MAX_NLIST_SIZE) return 0;
    strcpy(g_nlist[NXN].strname, name);
    g_nlist[NXN].varindex = NXV;

    if (NXV >= MAX_VLIST_SIZE) return 0;
    g_vlist[NXV].type  = type;
    g_vlist[NXV].addm  = ADDM_MEM;
    g_vlist[NXV].value = (uint32_t)NXN++;
    return NXV++;
}

static int  AddNewConst(int type, uint32_t value)
{
    if (NXV >= MAX_VLIST_SIZE) return 0;
    g_vlist[NXV].type  = type;
    g_vlist[NXV].addm  = ADDM_IMM;
    g_vlist[NXV].value = value;
    return NXV++;
}

static int  LookUpVar(char *name)
{
    int i;
    for (i=1; i<MAX_NLIST_SIZE; i++)
    {
        if (strcmp(g_nlist[i].strname, name) == 0)
        {
            return g_nlist[i].varindex;
        }
    }
    return 0;
}

static int  GEN(uint8_t optr, int opnd1, int opnd2, int result)
{
    if (NXQ >= MAX_QLIST_SIZE) return 0;
    g_qlist[NXQ].optr   = optr;
    g_qlist[NXQ].opnd1  = opnd1;
    g_qlist[NXQ].opnd2  = opnd2;
    g_qlist[NXQ].result = result;
    return NXQ++;
}

static void BackPatchChain(int chain, int value)
{
    int temp;
    int p;
    p = chain;
    while (p)
    {
        temp = g_qlist[p].result;
        g_qlist[p].result = value;
        p = temp;
    }
}

static int  MergeChain(int chain1, int chain2)
{
    int temp = chain1;
    if (chain1 == 0) return chain2;
    while (1) 
    {
        if (g_qlist[chain1].result == 0)
        {
            g_qlist[chain1].result = chain2;
            break;
        }
        chain1 = g_qlist[chain1].result;
    }
    return temp;
}

static void FillVarType(int chain, int type)
{
    int temp;
    while (chain)
    {
        temp = g_vlist[chain].type;
        g_vlist[chain].type = type;
        chain = temp;
    }
}

static void GenVarName(char *name, int var)
{
    if (var == 0 || var >= MAX_VLIST_SIZE)
    {
        sprintf(name, "0");
        return;
    }

    switch (g_vlist[var].addm)
    {
    case ADDM_IMM:
        if (g_vlist[var].type == TK_INTNUM) sprintf(name, "%d", (int)g_vlist[var].value);
        else sprintf(name, "%.3f", (float)g_vlist[var].value);
        break;
    case ADDM_MEM:
        sprintf(name, g_nlist[(int)g_vlist[var].value].strname);
        break;
    case ADDM_TEMP:
        sprintf(name, "_T%d", (int)g_vlist[var].value);
        break;
    }
}

static char* optrstr[] =
{
    "STOP ",

    "IADD ",
    "ISUB ",
    "IMULT",
    "IDIV ",

    "RADD ",
    "RSUB ",
    "RMULT",
    "RDIV ",

    "ITR  ",
    "RTI  ",

    "JMP  ",
    "JNZ  ",
    "IJL  ",
    "IJLE ",
    "IJE  ",
    "IJG  ",
    "IJGE ",
    "IJNE ",
    "RJL  ",
    "RJLE ",
    "RJE  ",
    "RJG  ",
    "RJGE ",
    "RJNE ",

    ":=   ",
};
static void GenQuaterList(FILE *fp)
{
    int  i;
    char opnd1[16];
    char opnd2[16];
    char result[16];

    fprintf(fp, "��Ԫʽ����\r\n");
    fprintf(fp, " NO.  OPTR     OPND1    OPND2    RESULT\r\n");
    fprintf(fp, "****************************************\r\n");
    for (i=1; i<NXQ; i++)
    {
        GenVarName(opnd1, g_qlist[i].opnd1);
        GenVarName(opnd2, g_qlist[i].opnd2);
        if (g_qlist[i].optr >= OP_JMP && g_qlist[i].optr <= OP_RJNE)
        {
            sprintf(result, "%d", g_qlist[i].result);
        }
        else GenVarName(result, g_qlist[i].result);
        fprintf(fp, "%3d. (%s,%8s,%8s,%8s)\r\n", i,
            optrstr[g_qlist[i].optr],
            opnd1, opnd2, result);
    }
    fprintf(fp, "\r\n\r\n");
}

static char* straddm[] = 
{
    "MEM",
    "IMM",
    "TEMP"
};
static void GenVarList(FILE *fp)
{
    int   i;
    char *strtype;
    char  strvalue[16];

    fprintf(fp, "������\r\n");
    fprintf(fp, " NO.     TYPE     ADDM     VALUE\r\n");
    fprintf(fp, "*********************************\r\n");
    for (i=1; i<NXV; i++)
    {
        if (g_vlist[i].type == TK_INTNUM) strtype = "INT";
        else if (g_vlist[i].type == TK_REALNUM) strtype = "REAL";
        if (g_vlist[i].addm == ADDM_IMM)
        {
            if (g_vlist[i].type == TK_INTNUM) sprintf(strvalue, "%d", (int)g_vlist[i].value);
            else if (g_vlist[i].type == TK_REALNUM) sprintf(strvalue, "%.3f", (float)g_vlist[i].value);
        }
        else sprintf(strvalue, "%d", (int)g_vlist[i].value);
        fprintf(fp, "%3d. %8s %8s %8s\r\n", i, strtype, straddm[g_vlist[i].addm], strvalue);
    }
    fprintf(fp, "\r\n\r\n");

    fprintf(fp, "���ű�\r\n");
    fprintf(fp, " NO.     NAME      VAR\r\n");
    fprintf(fp, "***********************\r\n");
    for (i=1; i<NXN; i++)
    {
        fprintf(fp, "%3d. %8s %8d\r\n", i,
            g_nlist[i].strname,
            g_nlist[i].varindex);
    }
    fprintf(fp, "\r\n\r\n");
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

    /* ��ʼ���� */
    yyparse();

    /* ������Ԫʽ���кͱ����� */
    GenQuaterList(fpout);
    GenVarList   (fpout);

    fclose(fpout);
    fclose(yyin );
}
#endif



