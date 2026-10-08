;
; checksum.asm - the one's complement internet checksum.
;
; This is your starting point. It assembles and links as-is, so the build
; works before you write any code. Right now it always returns 0, which
; makes every header decode as VALID. The decode path sums the header as it
; stands and tests for zero, so a routine that returns 0 says "valid" for
; everything. Your job is to replace that with the sum described below.
;
; The contract, from driver.c:
;
;       int len                   [ebp+12]
;       unsigned char *hdr        [ebp+8]
;
; Sum len bytes of hdr as len/2 16-bit big-endian words into a 32-bit
; accumulator. Fold the carries until the result fits in 16 bits. Return
; the one's complement of that in ax. The manual's worked example is the
; test. Zero the checksum field, sum the sample header, and you must get
; 0x9CBC.
;
; The decode path calls this over the header as it stands, checksum field
; included. A valid header returns 0 and an invalid one does not. The
; encode path calls it over a header whose checksum field you wrote as zero.
; One routine serves both uses. You don't need to know which one called
; you.
;
; Do not clobber ebx, esi, edi, or ebp. C assumes they survive your call.
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _ip_checksum ip_checksum
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

segment .text
        global  _ip_checksum
_ip_checksum:
        enter   0,0
        pusha

        ;
        ; TODO: the checksum loop.
        ;
        ; The manual's recipe:
        ;
        ;   1. Treat the header as 16-bit big-endian words. Load each byte
        ;      pair and recombine. Never load the pair as a single 16-bit
        ;      value, which gives you the bytes reversed.
        ;   2. Add each word to a 32-bit accumulator. Keep the carries. The
        ;      fold below returns them to the sum.
        ;   3. While the accumulator exceeds 16 bits, add its high half to
        ;      its low half. This is the end-around carry. A large sum can
        ;      need the fold twice.
        ;   4. NOT the low 16 bits. That is the checksum.
        ;
        ; len is always even, since the driver calls this with 20. A loop
        ; that consumes two bytes per iteration and stops on ecx == 0 is
        ; enough. Leave the answer in ax when you return.
        ;

        ; setup, we move the pointer to esi, and the size to ecx
        mov     esi, [ebp+8]
        mov     ecx, [ebp+12]
        shr     ecx, 1
        
        ; our main accumulator (32bit/4byte)
        mov     edx, 0

        ; if the shr sets off the ZF, it means the word count is 0
        jz      .fold
        
.checksum_loop:

        cmp     ecx, 0
        jle     .fold
        ; high byte
        movzx   eax, byte [esi]
        shl     eax, 8                  ; move to bits 8-15
        
        ;low byte
        movzx   ebx, byte [esi + 1]
        or      eax, ebx                 ; 0-7

        ; add to accumulator 
        add     edx, eax
        ; move to next endian
        add     esi, 2
        dec     ecx
        jmp     .checksum_loop

.fold:
        ; stores the higher bits in eax for arithmetic later
        mov     eax, edx
        shr     eax, 16

        ; if there is nothing above bit 15, fold is finished
        jz      .done

        ; edx now only contains its lower half
        movzx   edx, dx
        ; upper half of edx (now eax) add to edx (now only dx)
        add     edx, eax
        jmp     .fold

.done:
        not     edx
        and     edx, 0xFFFF
        ; replace original value with edx ( now with all 0s after bit 16)
        mov   [esp + 28], edx

        ; DO NOTTTTT mov eax, 0 after popa as that replaces eax with 0, 
        ; we also cant just mov eax, edx after popa because edx is also popped, leaving it with 0
        ; if we dont replace the original value of eax we end up with a wasted (incorrect) checksum, as it will 
        ; always be 0 returned

        popa
        leave
        ret
