;
; encode.asm - build a 20-byte IPv4 header from the field struct.
;
; This is your starting point. It assembles and links as-is, so the build
; works before you write any code. Right now it writes nothing, so the
; twenty bytes driver.c saves are whatever the buffer held. Your job is to
; replace that with the construction described below.
;
; The contract, from driver.c:
;
;       unsigned char *hdr        [ebp+12]
;       struct ipv4_fields *in    [ebp+8]
;
; driver.c documents the struct layout:
;
;   +0 version   +4 ihl    +8 dscp   +12 ecn   +16 total_length
;   +20 identification    +24 flags  +28 fragment_offset
;   +32 ttl      +36 protocol       +40 checksum
;   +44 src[0..3]                   +48 dst[0..3]
;
; You write twenty bytes into hdr. Every multi-byte field goes out
; big-endian: the high byte first. The fragment offset's top five bits share
; byte 6 with the three flag bits. Its bottom eight bits are byte 7.
;
; The checksum is your job too. Bytes 10-11 must read as zero while the
; checksum is computed. Write them as zero, call ip_checksum over the
; finished header, and store its result into the field. The struct's
; checksum member is read on the decode path only. Don't copy it here.
;
; Do not clobber ebx, esi, edi, or ebp. C assumes they survive your call.
; Return in eax (driver.c ignores it here, so returning 0 is fine).
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _ip_checksum ip_checksum
  %define _encode_header encode_header
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

extern _ip_checksum

segment .text
        global  _encode_header
_encode_header:
        enter   0,0
        pusha

        ;
        ; TODO: build the header from the struct.
        ;
        ; This is the reverse of decode. Mask each field to its width,
        ; shift it up to where it lives, or the pieces of a shared byte
        ; together, then store the byte. The fields that do not straddle
        ; anything are one store each.
        ;
        ; The checksum comes last, after every other byte is written. Write
        ; bytes 10-11 as zero, call ip_checksum with the header and 20, and
        ; store its result (in ax) into the field big-endian. Computing it
        ; before the rest of the header is in place sums whatever garbage
        ; was in the buffer. ip_checksum preserves ebx, esi, edi, and ebp,
        ; so a pointer kept in one of those survives the call. eax, ecx, and
        ; edx do not.
        ;

        ; move the address of the struct and address of header into a register
        mov esi, [ebp + 8]              ; address of struct
        mov edi, [ebp + 12]             ; address of the header array

        ; copy the version and the IHL to the first byte
        mov eax, [esi]                  ; value of the version
        shl eax, 4                      ; move the value to the upper part of al
        mov ebx, [esi + 4]              ; value of the IHL
        or eax, ebx                     ; combine the two values into 1 byte segment
        mov [edi], al                   ; the value of the 0th byte of the header

        ; copy the DSCP and ECN to the second byte
        mov eax, [esi + 8]              ; value of the DSCP
        shl eax, 2                      ; move the value to the upper part of al
        mov ebx, [esi + 12]             ; value of the ECN
        or eax, ebx                     ; combine the two values into 1 byte segment
        mov [edi + 1], al               ; the value of the 1st byte of the header

        ; copy the total length and store them to the header
        mov eax, [esi + 16]             ; value of the total length
        mov [edi + 2], ah               ; upper value of the total length in the header's 2nd byte
        mov [edi + 3], al               ; lower value of the total length in the header's 3rd byte

        ; copy the values of the identification and store them into the header
        mov eax, [esi + 20]             ; value of the identification
        mov [edi + 4], ah               ; upper value of the identification in the header's 4th byte
        mov [edi + 5], al               ; lower value of the identification in the header's 5th byte

        ; copy the values of the flags and the fragment offset 
        mov eax, [esi + 24]             ; value of the flags
        shl eax, 5                      ; shift left by 5 since flags occupy bit 5 - 7
        mov ebx, [esi + 28]             ; value of the fragment offset
        or al, bh                       ; combine the upper 5 bits of the fragment offset with the flags
        mov [edi + 6], al               ; upper byte of flags + 5 bit of offset
        mov [edi + 7], bl               ; remaining 8 bits of offset

        ; copy the value of the TTL and place them into the header
        mov eax, [esi + 32]             ; value of the TTL
        mov [edi + 8], al               ; the value of the 8th byte in the header

        ; copy the value of the Protocol and place them into the header
        mov eax, [esi + 36]             ; value of the protocol
        mov [edi + 9], al               ; the value of the 9th byte in the header

        ; temporarily store 0 to the checksum as the header is being built
        mov [edi + 10], 0              
        mov [edi + 11], 0        

        popa
        mov eax, 0
        leave
        ret
