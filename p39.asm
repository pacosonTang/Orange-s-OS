; ==========================================
; pmtest2.asm
; 编译方法：nasm pmtest2.asm -o pmtest2.com
; ==========================================

%include	"pm.inc"	; 常量, 宏, 以及一些说明

	org	0100h
	jmp	LABEL_BEGIN

[SECTION .gdt]
; GDT
;                            段基址,        段界限 , 属性
LABEL_GDT:         Descriptor    0,              0, 0         ; 空描述符
LABEL_DESC_NORMAL: Descriptor    0,         0ffffh, DA_DRW    ; Normal 描述符
LABEL_DESC_CODE32: Descriptor    0, SegCode32Len-1, DA_C+DA_32; 非一致代码段, 32
LABEL_DESC_CODE16: Descriptor    0,         0ffffh, DA_C      ; 非一致代码段, 16
LABEL_DESC_DATA:   Descriptor    0,      DataLen-1, DA_DRW    ; Data
LABEL_DESC_STACK:  Descriptor    0,     TopOfStack, DA_DRWA+DA_32; Stack, 32 位
LABEL_DESC_TEST:   Descriptor 0500000h,     0ffffh, DA_DRW
LABEL_DESC_VIDEO:  Descriptor  0B8000h,     0ffffh, DA_DRW    ; 显存首地址
; GDT 结束

GdtLen		equ	$ - LABEL_GDT	; GDT长度
GdtPtr		dw	GdtLen - 1	; GDT界限
		dd	0		; GDT基地址

; GDT 选择子
SelectorNormal		equ	LABEL_DESC_NORMAL	- LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorCode16		equ	LABEL_DESC_CODE16	- LABEL_GDT
SelectorData		equ	LABEL_DESC_DATA		- LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK	- LABEL_GDT
SelectorTest		equ	LABEL_DESC_TEST		- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT
; END of [SECTION .gdt]

[SECTION .data1]	 ; 数据段
ALIGN	32
[BITS	32]
LABEL_DATA:
SPValueInRealMode	dw	0
; 字符串
PMMessage:		db	"In Protect Mode now. ^-^", 0	; 在保护模式中显示 ;Mine【后面的零作为字符串的结束标志，Line189、232的test会用到】
OffsetPMMessage		equ	PMMessage - $$ ; Mine【$$ == LABEL_DATA 的基地址，相对于 LABEL_DATA 的偏移地址】
StrTest:		db	"ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0   ;Mine【后面的零作为字符串的结束标志】
OffsetStrTest		equ	StrTest - $$
DataLen			equ	$ - LABEL_DATA
; END of [SECTION .data1]


; 全局堆栈段
[SECTION .gs]
ALIGN	32
[BITS	32]
LABEL_STACK:
	times 512 db 0

TopOfStack	equ	$ - LABEL_STACK - 1

; END of [SECTION .gs]


[SECTION .s16]     ; Mine【为从实模式跳转到保护模式所做的准备工作】
[BITS	16]
LABEL_BEGIN:
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	sp, 0100h

	; 下一行指令的解说：
	; 待会要跳回到实模式，这里是保存跳转前的相关 value
	; mov [label_backto_real + 3], ax, 这是在代码已经加载到了内存之后再执行的，为什么加上3，一位jmp指令占用3个字节， 而jmp后面跟着跳转地址；
	; 他的作用是在段基地址存储单元中去重新设置新值 去 覆盖原先的段基地址，作者真心很是聪明啊。
	mov	[LABEL_GO_BACK_TO_REAL+3], ax
	mov	[SPValueInRealMode], sp		; Mine【保存sp，然后返回实模式后，再将sp取出来】

	; 初始化 16 位代码段描述符  ; Mine【为什么会有 16位代码段LABEL_SEG_CODE16，因为CPU从保护模式返回到实模式，只能从16位代码段中返回 】
	mov	ax, cs
	movzx	eax, ax		; Mine【movzx，无符号扩展传送指令；MOVZX AX,BL 运行完以上汇编语句之后，AX的值为0080H。】
	shl	eax, 4
	add	eax, LABEL_SEG_CODE16
	mov	word [LABEL_DESC_CODE16 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE16 + 4], al
	mov	byte [LABEL_DESC_CODE16 + 7], ah

	; 初始化 32 位代码段描述符
	xor	eax, eax
	mov	ax, cs
	shl	eax, 4
	add	eax, LABEL_SEG_CODE32
	mov	word [LABEL_DESC_CODE32 + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_CODE32 + 4], al
	mov	byte [LABEL_DESC_CODE32 + 7], ah

	; 初始化数据段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_DATA		; Mine【数据段的基址便是 LABEL_DATA 的物理地址 
							; 所以 OffsetStrTest 既是字符串相对于 LABEL_DATA 的偏移地址，也是其在数据段的偏移 】
	mov	word [LABEL_DESC_DATA + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_DATA + 4], al
	mov	byte [LABEL_DESC_DATA + 7], ah
	
	; 初始化堆栈段描述符
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_STACK
	mov	word [LABEL_DESC_STACK + 2], ax
	shr	eax, 16
	mov	byte [LABEL_DESC_STACK + 4], al
	mov	byte [LABEL_DESC_STACK + 7], ah

	; 为加载 GDTR 作准备
	xor	eax, eax
	mov	ax, ds
	shl	eax, 4
	add	eax, LABEL_GDT		; eax <- gdt 基地址
	mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

	; 加载 GDTR
	lgdt	[GdtPtr]

	; 关中断
	cli

	; 打开地址线A20
	in	al, 92h
	or	al, 00000010b
	out	92h, al

	; 准备切换到保护模式
	mov	eax, cr0
	or	eax, 1
	mov	cr0, eax

	; 真正进入保护模式
	jmp	dword SelectorCode32:0	; 执行这一句会把 SelectorCode32 装入 cs, 并跳转到 Code32Selector:0  处

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LABEL_REAL_ENTRY:		; 从保护模式跳回到实模式就到了这里
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax

	mov	sp, [SPValueInRealMode]

	in	al, 92h		; `.
	and	al, 11111101b	;  | 关闭 A20 地址线
	out	92h, al		; /

	sti			; 开中断

	mov	ax, 4c00h	; `.
	int	21h		; /  回到 DOS
; END of [SECTION .s16]


[SECTION .s32]; 32 位代码段. 由实模式跳入.
[BITS	32]

LABEL_SEG_CODE32:
	mov	ax, SelectorData
	mov	ds, ax			; 数据段选择子
	mov	ax, SelectorTest
	mov	es, ax			; 测试段选择子
	mov	ax, SelectorVideo
	mov	gs, ax			; 视频段选择子

	mov	ax, SelectorStack		; Mine【改变了ss和esp， 则在32位代码段中所有的堆栈操作将会在新增的堆栈段中进行】
	mov	ss, ax			; 堆栈段选择子

	mov	esp, TopOfStack


	; 下面显示一个字符串
	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	xor	esi, esi
	xor	edi, edi
	mov	esi, OffsetPMMessage	; 源数据偏移
	mov	edi, (80 * 10 + 0) * 2	; 目的数据偏移。屏幕第 10 行, 第 0 列。
	cld
.1:
	lodsb    ; Mine【lodsb、lodsw：把DS:SI指向的存储单元中的数据装入AL或AX，然后根据DF标志增减SI】
	test	al, al  ; Mine【1. test ax，100b  将 ax的 值  和 100b进行“与”操作 ，但不改变ax本身
					; 2. 若与操作的结果为零则ZF置位】
	jz	.2
	mov	[gs:edi], ax
	add	edi, 2
	jmp	.1
.2:	; 显示完毕

	call	DispReturn ; Mine【call == push ip ; jmp near ptr 标号】

	call	TestRead	; Mine【先读出数据】
	call	TestWrite	; Mine【再写入数据】
	call	TestRead	; Mine【再次读出数据】

	; 到此停止
	jmp	SelectorCode16:0 ; Mine【Line31，Line80 已经初始化LABEL_DESC_CODE16，保存着LABEL_SEG_CODE16的基地址 】

; ------------------------------------------------------------------------
TestRead:
	xor	esi, esi
	mov	ecx, 8
.loop:
	mov	al, [es:esi]	; Mine【读取字符串的基地址到al】
	call	DispAL
	inc	esi
	loop	.loop

	call	DispReturn

	ret
; TestRead 结束-----------------------------------------------------------


; ------------------------------------------------------------------------
TestWrite:
	push	esi
	push	edi
	xor	esi, esi
	xor	edi, edi
	mov	esi, OffsetStrTest	; 源数据偏移
	cld
.1:
	lodsb		; Mine【lodsb、lodsw：把DS:SI指向的存储单元中的数据装入AL或AX，然后根据DF标志增减SI】
	test	al, al		; Mine【1. test ax，100b  将 ax的 值  和 100b进行“与”操作 ，但不改变ax本身
					    ; 2. 若与操作的结果为零则ZF置位】
	jz	.2
	mov	[es:edi], al
	inc	edi
	jmp	.1
.2:

	pop	edi
	pop	esi

	ret
; TestWrite 结束----------------------------------------------------------


; ------------------------------------------------------------------------
; 显示 AL 中的数字
; 默认地:
;	数字已经存在 AL 中
;	edi 始终指向要显示的下一个字符的位置
; 被改变的寄存器:
;	ax, edi
; ------------------------------------------------------------------------
DispAL:		; Mine【DispAL 将al中的字节用十六进制数的形式显示出来，字的前景色为红色】
	push	ecx
	push	edx

	mov	ah, 0Ch			; 0000: 黑底    1100: 红字
	mov	dl, al
	shr	al, 4
	mov	ecx, 2
.begin:
	and	al, 01111b
	cmp	al, 9
	ja	.1
	add	al, '0'
	jmp	.2
.1:
	sub	al, 0Ah
	add	al, 'A'
.2:
	mov	[gs:edi], ax
	add	edi, 2

	mov	al, dl
	loop	.begin
	add	edi, 2

	pop	edx
	pop	ecx

	ret
; DispAL 结束-------------------------------------------------------------


; ------------------------------------------------------------------------
DispReturn:		; Mine【DispReturn 模拟一个回车的显示，实际上是让下一个字符显示在下一行的开头处】
	push	eax
	push	ebx
	mov	eax, edi	; Mine【edi始终指向要显示的下一个字符的位置】
	mov	bl, 160
	div	bl		; Mine【被除数默认放在ax内或ax（低16位）和dx（高16位）中; 结果al保存商，ah保存余数，或AX保存商，DX保存余数】
	and	eax, 0FFh
	inc	eax		; Mine【inc 将指定的操作数加1】
	mov	bl, 160
	mul	bl
	; Mine【mul src：如果SRC是字节操作数，则把AL中的无符号数与SRC相乘得到16位结果送AX中，即：AX←（AL)*(SRC)。
	; 如果SRC是字操作数，则把AX中的无符号数与SRC相乘得到32位结果送DX和AX中，DX存高16位，AX存低16位，即：AX←（AL）*（SRC）。】
	
	mov	edi, eax
	pop	ebx
	pop	eax

	ret ; Mine【1. ret == pop IP == 
		;		2. ip = (ss) * 16+ (sp);(sp） = (sp) + 2; 】
; DispReturn 结束---------------------------------------------------------

SegCode32Len	equ	$ - LABEL_SEG_CODE32
; END of [SECTION .s32]


; 16 位代码段. 由 32 位代码段跳入, 跳出后到实模式
[SECTION .s16code]
ALIGN	32
[BITS	16]
LABEL_SEG_CODE16:
	; 跳回实模式:
	mov	ax, SelectorNormal		; Mine【 选择子 SelectorNormal 是对描述符 LABEL_DESC_NORMAL 的索引 】
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax

	mov	eax, cr0
	and	al, 11111110b		; Mine【cr0的最后一位PE位置为0，进入实模式】
	mov	cr0, eax

LABEL_GO_BACK_TO_REAL:
	jmp	0:LABEL_REAL_ENTRY	; 段地址会在程序开始处被设置成正确的值

Code16Len	equ	$ - LABEL_SEG_CODE16

; END of [SECTION .s16code]
