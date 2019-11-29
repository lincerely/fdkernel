#if !defined(PROTO_NEC_HEADER) && defined(NEC98)
# define PROTO_NEC_HEADER
/* console.asm */
UBYTE ASMCFUNC crt_set_mode(UBYTE mode);
VOID ASMCFUNC set_curpos(UBYTE x, UBYTE y);
VOID ASMCFUNC crt_scroll_up(VOID);
VOID ASMCFUNC crt_scroll_down(VOID);
UBYTE ASMCFUNC get_crt_width(VOID);
UBYTE ASMCFUNC get_crt_height(VOID);
VOID ASMCFUNC put_crt(UBYTE x, UBYTE y, UWORD c);
VOID ASMCFUNC put_crt_wattr(UBYTE x, UBYTE y, UWORD c, UBYTE a);
VOID ASMCFUNC clear_crt(UBYTE x, UBYTE y);
VOID ASMCFUNC clear_crt_all(VOID);
VOID ASMCFUNC update_cursor_view(VOID);
VOID ASMCFUNC crt_rollup(UBYTE lines);
VOID ASMCFUNC crt_rolldown(UBYTE lines);

#endif
