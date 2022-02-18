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
extern size_t parse_hook_size;
extern void hs_hook;
extern size_t hs_hook_size;

int main(void)
{
    uint8_t data_second[18] = {0x0c, 0x80, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x80, 0xf1, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0};
    uint8_t data_minute[18] = {0x0c, 0x81, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x80, 0xf1, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0, 0xf0};
    ti_SetVar(TI_CPLX_TYPE, ti_S, data_second);
    ti_SetVar(TI_CPLX_TYPE, ti_M, data_minute);

    hook_error_t err;
    err = hook_Install(0xFF0000, &parse_hook, parse_hook_size, HOOK_TYPE_PARSER, 5, "Unit manipulation hook");
    dbg_printf("Err %u\n", err);
    err = hook_Install(0xFF0001, &hs_hook, hs_hook_size, HOOK_TYPE_HOMESCREEN, 5, "Unit manipulation hook");
    dbg_printf("Err %u\n", err);
    hook_Sync();
    return 0;
}
