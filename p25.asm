; ==========================================
; pmtest1.asm
; 编译方法：nasm pmtest1.asm -o pmtest1.bin
; ==========================================

%include	"pm.inc"	; 常量, 宏, 以及一些说明

org	0100h
	jmp	LABEL_BEGIN

[SECTION .gdt]
; GDT
;                              段基址,       段界限     , 属性
LABEL_GDT:	   Descriptor       0,                0, 0           ; 空描述符
LABEL_DESC_CODE32: Descriptor       0, SegCode32Len - 1, DA_C + DA_32; 非一致代码段
LABEL_DESC_VIDEO:  Descriptor 0B8000h,           0ffffh, DA_DRW	     ; 显存首地址 ;Mine【0B8000h就是显存基地址】
; GDT 结束

GdtLen		equ	$ - LABEL_GDT	; GDT长度，Mine【什么叫数组==表？即以LABEL_GDT为标杆，后面跟一群马仔，GdtLen记录该描述符表的长度】
GdtPtr		dw	GdtLen - 1	; GDT界限
		dd	0		; GDT基地址

; Mine【我的更正，选择子并不完全等同于基址偏移地址，参见P32】
; GDT 选择子，Mine【选择子==相应描述符的运行地址相对于全局描述符表的偏移，全局描述符就是表头，它作为标杆】
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT
; END of [SECTION .gdt]

[SECTION .s16]    ; Mine【为从实模式跳转到保护模式所做的准备工作】
[BITS	16]
LABEL_BEGIN:
	mov	ax, cs
	mov	ds, ax	
	mov	es, ax
	mov	ss, ax
	mov	sp, 0100h

	; 初始化 32 位代码段描述符；Mine【1.将LABEL_SEG_CODE32的运行时的内存地址记录在代码段描述符中; 
									; 2.代码段 cs 的值也存入LABEL_DESC_CODE32描述符了】
	xor	eax, eax
	mov	ax, cs
	shl	eax, 4
	add	eax, LABEL_SEG_CODE32
	mov	word [LABEL_DESC_CODE32 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE32 + 4], al
	mov	byte [LABEL_DESC_CODE32 + 7], ah

	; 为加载 GDTR 作准备，Mine【将全局描述符表被加载的内存地址记录在GdtPtr中】
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_GDT		; eax <- gdt 基地址
	mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

	; 加载 GDTR
	lgdt	[GdtPtr]    ; Mine【将GdtPtr指示的6字节加载到寄存器 gdtr】

	; 关中断
	cli

	; 打开地址线A20
	in	al, 92h
	or	al, 00000010b
	out	92h, al

	; 准备切换到保护模式
	mov	eax, cr0
	or	eax, 1  ; Mine【将 cr0 的PE位置1，就表示实模式了】
	mov	cr0, eax

	; 真正进入保护模式
	jmp	dword SelectorCode32:0	
					; 执行这一句会把 SelectorCode32 装入 cs, 
					; 并跳转到 Code32Selector:0  处
					; Mine【SelectorCode32记录了LABEL_DESC_CODE32相对于全局描述符表的偏移地址,而LABEL_DESC_CODE32记录了LABEL_SEG_CODE32的基地址】
; END of [SECTION .s16]


[SECTION .s32]; 32 位代码段. 由实模式跳入. ; Mine【该段程序在实模式下执行，因为 or eax,1 已经设置运行模式为实模式了】
[BITS	32]

LABEL_SEG_CODE32:
	mov	ax, SelectorVideo ; Mine【SelectorVideo作为LABEL_DESC_VIDEO相对于全局描述符表GDT的选择子】
	mov	gs, ax			; 视频段选择子(目的)

	mov	edi, (80 * 11 + 79) * 2	; 屏幕第 11 行, 第 79 列。
	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	mov	al, 'P'
	mov	[gs:edi], ax ; Main【 LABEL_DESC_VIDEO 是显存首地址，而 SelectorVideo 作为LABEL_DESC_VIDEO相对于全局描述符GDT的偏移地址】

	; 到此停止
	jmp	$

SegCode32Len	equ	$ - LABEL_SEG_CODE32
; END of [SECTION .s32]

