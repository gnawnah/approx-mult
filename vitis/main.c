#include <stdio.h>
#include "xil_io.h"
#include "xparameters.h"
#include "xil_printf.h"

#define APPROX_BASE   0x43C00000    // your peripheral base address
#define REG_A         0x00          // operand A  (slv_reg0)
#define REG_B         0x04          // operand B  (slv_reg1)
#define REG_RESULT    0x08          // result     (reg2 -> product)

int main()
{
    u32 a, b, result;

    xil_printf("Approx multiplier over AXI\r\n");

    // test case 1: a = 12, b = 15
    a = 12;
    b = 15;
    Xil_Out32(APPROX_BASE + REG_A, a);      // write operand A
    Xil_Out32(APPROX_BASE + REG_B, b);      // write operand B
    result = Xil_In32(APPROX_BASE + REG_RESULT);   // read product
    xil_printf("a=%d b=%d -> product=%d\r\n", a, b, result);

    // test case 2: a = 100, b = 100
    a = 100;
    b = 100;
    Xil_Out32(APPROX_BASE + REG_A, a);
    Xil_Out32(APPROX_BASE + REG_B, b);
    result = Xil_In32(APPROX_BASE + REG_RESULT);
    xil_printf("a=%d b=%d -> product=%d\r\n", a, b, result);

    // test case 3: a = 255, b = 255
    a = 255;
    b = 255;
    Xil_Out32(APPROX_BASE + REG_A, a);
    Xil_Out32(APPROX_BASE + REG_B, b);
    result = Xil_In32(APPROX_BASE + REG_RESULT);
    xil_printf("a=%d b=%d -> product=%d\r\n", a, b, result);

    return 0;
}