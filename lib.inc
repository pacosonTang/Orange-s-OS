;; lib.inc

;; 显示 AL 中的数字
DispAL:
	push	ecx
	push	edx
	push	edi
; _dwDispPos:  dd	(80 * 6 + 0) * 2	; 屏幕第 6 行, 第 0 列。(每行80个字节)
; dwDispPos equ	_dwDispPos	- $$
	mov	edi, [dwDispPos]

	mov	ah, 0Fh			; 0000b: 黑底    1111b: 白字
	mov	dl, al			; al 存储 显示的数字(8位)
	shr	al, 4			; al 右移4位, 高4位 -> 低4位 ,低4位暂时不管
	mov	ecx, 2
.begin:
	and	al, 01111b		; 高4位=0000
	cmp	al, 9			;  
	ja	.1				; al > 9 转向 .1
	add	al, '0'			; al <- al对应的 ascii 码
	jmp	.2
.1:
	sub	al, 0Ah			; al <= al - 10
	add	al, 'A'			; ascii('A') = 65 ,大于9，说明为10(A)、11(B)、12(C)、...
.2:
	mov	[gs:edi], ax
	add	edi, 2			; 以上代码已经显示出了高4位对应的数字

	mov	al, dl			; 再看低4位对应的数字是...
	loop	.begin
	;add	edi, 2

	mov	[dwDispPos], edi ; 下一次要写入的地址值

	pop	edi
	pop	edx
	pop	ecx

	ret
;; DispAL 结束


;; 显示一个整型数
DispInt:
						; 以下代码将整型数依次打印 (从右到左)
	mov	eax, [esp + 4]	; 将调用本函数前 压栈的参数值 -> eax	
	shr	eax, 24			; 右移24位
	call	DispAL      ; 打印 bit24~31

	mov	eax, [esp + 4]	; 将调用本函数前 压栈的参数值 -> eax	
	shr	eax, 16			; 右移16位
	call	DispAL      ; 打印 bit16~23

	mov	eax, [esp + 4]	; 将调用本函数前 压栈的参数值 -> eax	
	shr	eax, 8			; 右移8位
	call	DispAL      ; 打印 bit8~15

	mov	eax, [esp + 4]	; 将调用本函数前 压栈的参数值 -> eax
	call	DispAL      ; 打印 bit0~7

	mov	ah, 07h			; 0000b: 黑底    0111b: 灰字
	mov	al, 'h'			; 打印 'h'
	push	edi
						; _dwDispPos:  dd	(80 * 6 + 0) * 2	; 屏幕第 6 行, 第 0 列。(每行80个字节)
						; dwDispPos equ	_dwDispPos	- $$	
	mov	edi, [dwDispPos]
	mov	[gs:edi], ax
	add	edi, 4			; 看到这里，edi+=4，本来应该 edi+=2(因为一个字符占用2字节显存地址),
						; 猜测的话，h后面跟了一个空格，占用了2个字节；(不过这里要怎么理解，都不重要啦)
	mov	[dwDispPos], edi ; 下一次要写入的地址值
	pop	edi

	ret
;; DispInt 结束

;; 显示一个字符串
; _szPMMessage:db "In Protect Mode now. ^-^", 0Ah, 0Ah, 0 ; 进入保护模式后显示此字符串
	; szPMMessage equ _szPMMessage - $$ 
	; $$ == LABEL_DATA
;  上一条指令 push	szPMMessage
DispStr:
	push	ebp
	mov	ebp, esp
	push	ebx
	push	esi
	push	edi

	mov	esi, [ebp + 8]	; pszInfo ; esi <- 字符串偏移地址
	; _dwDispPos:  dd	(80 * 6 + 0) * 2	; 屏幕第 6 行, 第 0 列。(每行80个字节)
	; dwDispPos equ	_dwDispPos	- $$
	mov	edi, [dwDispPos] ; edi <- 写显存偏移地址
	mov	ah, 0Fh			 ; 设置写显存高8位, 且 ah=0f % 160 == 0
.1:
	lodsb				; ds:si -> al ,字符串偏移地址 -> al; 每次循环后，si要增减1
	test	al, al		; 判断 al = 0？
	jz	.2				; al==0，跳转到 .2
	cmp	al, 0Ah			; 是回车吗? 
	jnz	.3				; 不是回车才会跳转到 .3
						; 这个字符串的末尾定义为：0Ah, 0Ah, 0，0是个ending flag，0A是个回车标记。
						
						; 以下代码是当字符是 0Ah 时，才会执行的代码，仅仅是执行回车而已
	push	eax			; 吧 字符串偏移地址 压栈保存
	mov	eax, edi		; eax <- edi , edi=写显存的偏移地址 ,edi=初始960，每写(.2)一次，edi+=2;
	mov	bl, 160			; 每行160个字节(80个字符)
	div	bl				; al(商)...ah(余数) <- ax/bl 
	and	eax, 0FFh		; 取出低8位(商)
	inc	eax				; eax(al-商) 自增1 ，下一行嘛，你不是换行吗？
	mov	bl, 160			; 
	mul	bl				; ax <- al * bl(160), 下一行的偏移地址(每行160字节)
	mov	edi, eax		; edi <- eax 
	pop	eax
	jmp	.1
.3:
	mov	[gs:edi], ax	; 写入显存地址，立即显示字符
	add	edi, 2			; 因为每个字符 占据两个字节(低位字节存储字符的ascii，高位字节存储字符属性)
	jmp	.1

.2:
	mov	[dwDispPos], edi ; 下一次要写入的地址值

	pop	edi
	pop	esi
	pop	ebx
	pop	ebp
	ret
;; DispStr 结束

;; 换行
; _szReturn db	0Ah, 0 ;因为0A==换行，0 == 字符串结束标记
; szReturn	equ	_szReturn	- $$
DispReturn:
	push	szReturn
	call	DispStr			;printf("\n");
	add	esp, 4

	ret
;; DispReturn 结束


; ------------------------------------------------------------------------
; 内存拷贝，仿 memcpy, 从源地址 pSrc 拷贝iSize 字节内容到 目的地址 pDest
; ------------------------------------------------------------------------
; void* MemCpy(void* es:pDest, void* ds:pSrc, int iSize);
; ------------------------------------------------------------------------
MemCpy:
	push	ebp
	mov	ebp, esp

	push	esi
	push	edi
	push	ecx

	mov	edi, [ebp + 8]	; Destination
	mov	esi, [ebp + 12]	; Source
	mov	ecx, [ebp + 16]	; Counter
.1:
	cmp	ecx, 0		; 判断计数器
	jz	.2		; 计数器为零时跳出

	mov	al, [ds:esi]		; ┓ 源地址处的值 -> al
	inc	esi			; ┃
					; ┣ 逐字节移动
	mov	byte [es:edi], al	; ┃
	inc	edi			; ┛

	dec	ecx		; 计数器减一
	jmp	.1		; 循环
.2:
	mov	eax, [ebp + 8]	; 返回值

	pop	ecx
	pop	edi
	pop	esi
	mov	esp, ebp
	pop	ebp

	ret			; 函数结束，返回
; MemCpy 结束-------------------------------------------------------------

