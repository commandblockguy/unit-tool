/*
 *--------------------------------------
 * Program Name:
 * Author:
 * License:
 * Description:
 *--------------------------------------
*/

#include <capnhook.h>
#include <fileioc.h>
#include <debug.h>

extern void parse_hook;
extern void hs_hook;

#define RAM_START ((void*)0xD00000)
#define PRGM_ADDR ((void*)0xD1A87F)

int main(int argc, const char **argv)
{
    uint8_t data_meter[18]  = {0x0c, 0x80, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x80, 0xf1, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0};
    uint8_t data_gram[18]   = {0x0c, 0x7D, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x80, 0xf0, 0xf1, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0};
    uint8_t data_second[18] = {0x0c, 0x80, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x80, 0xf0, 0xf0, 0xf1, 0xf0, 0xf0, 0xf0, 0xf0};
    uint8_t data_ampere[18] = {0x0c, 0x80, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x80, 0xf0, 0xf0, 0xf0, 0xf1, 0xf0, 0xf0, 0xf0};
    uint8_t data_kelvin[18] = {0x0c, 0x80, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x80, 0xf0, 0xf0, 0xf0, 0xf0, 0xf1, 0xf0, 0xf0};
    ti_SetVar(TI_CPLX_TYPE, ti_M, data_meter);
    ti_SetVar(TI_CPLX_TYPE, ti_G, data_gram);
    ti_SetVar(TI_CPLX_TYPE, ti_S, data_second);
    ti_SetVar(TI_CPLX_TYPE, ti_A, data_ampere);
    ti_SetVar(TI_CPLX_TYPE, ti_K, data_kelvin);

    if(!argc) return 1;

    // It's time to reflect upon one of the great mysteries of life
    // How does one find themselves?
    ti_var_t slot = ti_OpenVar(argv[0], "r", TI_PRGM_TYPE);
    if(!slot) return 1;
    void *self = ti_GetDataPtr(slot);
    if(!self) return 1;
    ti_Close(slot);
    // It's that simple.

    if(self >= RAM_START) {
        // Sometimes you find yourself in RAM.
        // RAM is a terrible place to be, let's not be there.
        return 1;
    }

    dbg_printf("Program at %p, running at %p, hooks at %p/%p and %p/%p\n", self, PRGM_ADDR, &parse_hook - PRGM_ADDR + self, &parse_hook, &hs_hook - PRGM_ADDR + self, &hs_hook);

    hook_error_t err;
    err = hook_Install(0xFF0000, &parse_hook - PRGM_ADDR + self, 0, HOOK_TYPE_PARSER, 5, "Unit manipulation hook");
    dbg_printf("Err %u installing hook at %p\n", err, &parse_hook - PRGM_ADDR + self);
    err = hook_Install(0xFF0001, &hs_hook - PRGM_ADDR + self, 0, HOOK_TYPE_HOMESCREEN, 5, "Unit manipulation hook");
    dbg_printf("Err %u installing hook at %p\n", err, &hs_hook - PRGM_ADDR + self);
    hook_Sync();

    // Enable lowercase
    *(uint8_t*)0xD000A4 |= 8;

    return 0;
}
