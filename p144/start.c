
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                            start.c
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                                                    Forrest Yu, 2005
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

#include "type.h"
#include "const.h"
#include "protect.h"

PUBLIC	void*	memcpy(void* pDst, void* pSrc, int iSize);

PUBLIC	void	disp_str(char * pszInfo);

PUBLIC	u8		gdt_ptr[6];	/* 0~15:Limit  16~47:Base  u8 = unsigned charu8 是 unsigned char 
													   u16 是 unsigned short 
													   u32 是 unsigned int */
PUBLIC	DESCRIPTOR	gdt[GDT_SIZE];		// GDT_SIZE=128 in defined in const.h 

PUBLIC void cstart()
{

	disp_str("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
		 "-----\"cstart\" begins-----\n");

	/* 将 LOADER 中的 GDT 复制到新的 GDT 中 */
	memcpy(&gdt,				   /* New GDT */
	       (void*)(*((u32*)(&gdt_ptr[2]))),    /* Base  of Old GDT */
	       *((u16*)(&gdt_ptr[0])) + 1	   /* Limit of Old GDT */
		);
	/* gdt_ptr[6] 共 6 个字节：0~15:Limit  16~47:Base。用作 sgdt/lgdt 的参数。[因为gdtr是6个字节，高32位基地址,低16位界限]*/
	u16* p_gdt_limit = (u16*)(&gdt_ptr[0]);		// 把新的存储段限长的地址 导出 以便通过指针 被赋值
	u32* p_gdt_base  = (u32*)(&gdt_ptr[2]);		// 把新的存储段基地址的地址 导出 以便被通过指针 被赋值
	*p_gdt_limit = GDT_SIZE * sizeof(DESCRIPTOR) - 1;
	*p_gdt_base  = (u32)&gdt;
}
