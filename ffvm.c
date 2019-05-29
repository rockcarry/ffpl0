#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <conio.h>

#define MAX_QLIST_SIZE  100
#define MAX_STACK_SIZE  100

enum {
    OP_STOP  ,  /* ͣ�� */
    OP_IADD  ,  /* ���ͼӷ� */
    OP_IMINUS,  /* ���ͼ��� */
    OP_IMULT ,  /* ���ͳ˷� */
    OP_IDIV  ,  /* ���ͳ��� */

    OP_RADD  ,  /* ʵ�ͼӷ� */
    OP_RMINUS,  /* ʵ�ͼ��� */
    OP_RMULT ,  /* ʵ�ͳ˷� */
    OP_RDIV  ,  /* ʵ�ͳ��� */

    OP_ITR   ,  /* ����ת��Ϊʵ�� */
    OP_RTI   ,  /* ʵ��ת��Ϊ���� */
    OP_ASIGNI,  /* ��ֵ���������ڴ� */
    OP_ASIGNR,  /* ��ֵ��ʵ�����ڴ� */
    OP_ASIGNM,  /* ��ֵ���ڴ浽�ڴ� */

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

typedef struct {
    uint8_t optr;    /* ������  */
    int32_t result;  /* �������*/
    int32_t opnd1;   /* ������1 */
    int32_t opnd2;   /* ������2 */
} QUATER;

static QUATER   g_qlist[MAX_QLIST_SIZE] = {0};
static uint32_t g_stack[MAX_STACK_SIZE] = {0};

int main(int argc, char *argv[])
{
    FILE *fp = NULL;
    int   stop = 0, pc, ret;
    int32_t *iopnd1, *iopnd2, *iresult;
    float   *fopnd1, *fopnd2, *fresult;

    if (argc < 2) {
        printf("ffvm v1.0.0\n\n");
        return 0;
    }

    fp = fopen(argv[1], "rb");
    if (fp) {
        for (pc=0; pc<MAX_QLIST_SIZE; pc++) {
            ret = fread(&g_qlist[pc], sizeof(QUATER), 1, fp);
            if (ret != 1) break;
        }
        for (pc=1,stop=0; pc<MAX_QLIST_SIZE && !stop; ) {
            iopnd1 = (int32_t*)&g_stack[g_qlist[pc].opnd1 ];
            iopnd2 = (int32_t*)&g_stack[g_qlist[pc].opnd2 ];
            iresult= (int32_t*)&g_stack[g_qlist[pc].result];
            fopnd1 = (float  *)&g_stack[g_qlist[pc].opnd1 ];
            fopnd2 = (float  *)&g_stack[g_qlist[pc].opnd2 ];
            fresult= (float  *)&g_stack[g_qlist[pc].result];
            switch (g_qlist[pc].optr) {
            case OP_STOP  : stop = 1;                     break;
            case OP_IADD  : *iresult = *iopnd1 + *iopnd2; break;
            case OP_IMINUS: *iresult = *iopnd1 - *iopnd2; break;
            case OP_IMULT : *iresult = *iopnd1 * *iopnd2; break;
            case OP_IDIV  : *iresult = *iopnd1 / *iopnd2; break;
            case OP_RADD  : *fresult = *fopnd1 + *fopnd2; break;
            case OP_RMINUS: *fresult = *fopnd1 - *fopnd2; break;
            case OP_RMULT : *fresult = *fopnd1 * *fopnd2; break;
            case OP_RDIV  : *fresult = *fopnd1 / *fopnd2; break;
            case OP_ITR   : *fresult = *iopnd1;           break;
            case OP_RTI   : *iresult = *fopnd1;           break;
            case OP_ASIGNI: *iresult = g_qlist[pc].opnd1; break;
            case OP_ASIGNR: *iresult = g_qlist[pc].opnd1; break;
            case OP_ASIGNM: *iresult = *iopnd1;           break;
            case OP_IPRT  : printf("%d\n", *iresult);     break;
            case OP_RPRT  : printf("%f\n", *fresult);     break;
            case OP_IIPT  : scanf ("%d", iresult);        break;
            case OP_RIPT  : scanf ("%f", fresult);        break;
            case OP_JMP   : pc = g_qlist[pc].result;      continue;
            case OP_IJL   : if (*iopnd1 <  *iopnd2) { pc = g_qlist[pc].result; continue; } break;
            case OP_IJLE  : if (*iopnd1 <= *iopnd2) { pc = g_qlist[pc].result; continue; } break;
            case OP_IJE   : if (*iopnd1 == *iopnd2) { pc = g_qlist[pc].result; continue; } break;
            case OP_IJG   : if (*iopnd1 >  *iopnd2) { pc = g_qlist[pc].result; continue; } else break;
            case OP_IJGE  : if (*iopnd1 >= *iopnd2) { pc = g_qlist[pc].result; continue; } break;
            case OP_IJNE  : if (*iopnd1 != *iopnd2) { pc = g_qlist[pc].result; continue; } break;
            case OP_RJL   : if (*fopnd1 <  *fopnd2) { pc = g_qlist[pc].result; continue; } break;
            case OP_RJLE  : if (*fopnd1 <= *fopnd2) { pc = g_qlist[pc].result; continue; } break;
            case OP_RJE   : if (*fopnd1 == *fopnd2) { pc = g_qlist[pc].result; continue; } break;
            case OP_RJG   : if (*fopnd1 >  *fopnd2) { pc = g_qlist[pc].result; continue; } break;
            case OP_RJGE  : if (*fopnd1 >= *fopnd2) { pc = g_qlist[pc].result; continue; } break;
            case OP_RJNE  : if (*fopnd1 != *fopnd2) { pc = g_qlist[pc].result; continue; } break;
            }
            pc++;
        }
        fclose(fp);
    }

    getch();
    return 0;
}


