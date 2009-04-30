
;***************************************************************************
;*
;* Add32 == 32+32 Bit Unsigned Addition
;*
;* add1L::add1H  +  add2L::add2H  =  add1L::add1H
;*     item             item             sum
;* r20r21r22r23  +  r16r17r18r19  =  r20r21r22r23
;*
;***************************************************************************
.def    add20   = r16   ; item 2 byte 0 (LSB)
.def    add21   = r17   ; item 2 byte 1
.def    add22   = r18   ; item 2 byte 2
.def    add23   = r19   ; item 2 byte 3 (MSB)
.def    add10   = r20   ; item 1 byte 0 (LSB)
.def    add11   = r21   ; item 1 byte 1
.def    add12   = r22   ; item 1 byte 2
.def    add13   = r23   ; item 1 byte 3 (MSB)

Add32sign:      brts    Sub32sign       ;
Add32:          add     add10,add20     ;Add low bytes
                adc     add11,add21     ;Add higher bytes with carry
                adc     add12,add22     ;
                adc     add13,add23     ;
                ret                     ;

;***************************************************************************
;*
;* Sub32 == 32-32 Bit Unsigned Subtraction
;*
;* sub1L::sub1H  -  sub2L::sub2H  =  sub1L::sub1H
;*   minuend         subtrahend       difference
;* r20r21r22r23  -  r16r17r18r19  =  r20r21r22r23
;*
;***************************************************************************
.def    sub20   = r16   ; subtrahend byte 0 (LSB)
.def    sub21   = r17   ; subtrahend byte 1
.def    sub22   = r18   ; subtrahend byte 2
.def    sub23   = r19   ; subtrahend byte 3 (MSB)
.def    sub10   = r20   ; minuend byte 0 (LSB)
.def    sub11   = r21   ; minuend byte 1
.def    sub12   = r22   ; minuend byte 2
.def    sub13   = r23   ; minuend byte 3 (MSB)

Sub32sign:      clt                     ;sign +
Sub32:          sub     sub10,sub20     ;Subtract low bytes
                sbc     sub11,sub21     ;Subtract higher bytes with carry
                sbc     sub12,sub22     ;
                sbc     sub13,sub23     ;
                brcc    Return32u       ;return clear carry if result>=0
                set                     ;sign -
Neg32:          subi    sub10,1         ;if result<0
                sbci    sub11,0         ;   neg result
                sbci    sub12,0         ;
                sbci    sub13,0         ;   (dec result)
Com32:          com     sub10           ;       &
                com     sub11           ;   (com result)
                com     sub12           ;
                com     sub13           ;   return set carry after com
Return32u:      ret      

;***************************************************************************
;*
;* Div32 == 32/32 Bit Unsigned Division
;*
;* dd32uL::dd32uH / dv32uL::dv32uH = dres32uL::dres32uH (drem32uL::drem32uH)
;*    dividend          divisor            result            remainder
;*  r20r21r22r23  /  r16r17r18r19  =    r20r21r22r23        r24r25r26r27
;*
;***************************************************************************
.def    dv32u0   =r16   ; divisor byte 0 (LSB)
.def    dv32u1   =r17   ; divisor byte 1
.def    dv32u2   =r18   ; divisor byte 2
.def    dv32u3   =r19   ; divisor byte 3 (MSB)
.def    dres32u0 =r20   ; result byte 0 (LSB)
.def    dres32u1 =r21   ; result byte 1
.def    dres32u2 =r22   ; result byte 2
.def    dres32u3 =r23   ; result byte 3 (MSB)
.def    dd32u0   =r20   ; dividend byte 0 (LSB)
.def    dd32u1   =r21   ; dividend byte 1
.def    dd32u2   =r22   ; dividend byte 2
.def    dd32u3   =r23   ; dividend byte 3 (MSB)
.def    drem32u0 =r24   ; remainder byte 0 (LSB)
.def    drem32u1 =r25   ; remainder byte 1
.def    drem32u2 =r26   ; remainder byte 2
.def    drem32u3 =r27   ; remainder byte 3 (MSB)
.def    dcnt32u  =r28   ; loop counter

Div32b:         clr     dv32u1          ;divisor is one byte
Div32w:         clr     dv32u2          ;           two bytes
Div32t:         clr     dv32u3          ;           three bytes
Div32:          clr     drem32u0        ;clear 4 lower remainde byte
                clr     drem32u1        ;
                clr     drem32u2        ;
                sub     drem32u3,drem32u3;and carry
                ldi     dcnt32u,33      ;init loop counter
d32u_loop:      rol     dd32u0          ;shift left dividend
                rol     dd32u1          ;
                rol     dd32u2          ;
                rol     dd32u3          ;
                dec     dcnt32u         ;decrement loop counter
                breq    Com32           ;if counter zero invert result
                rol     drem32u0        ;shift dividend into remainder
                rol     drem32u1        ;
                rol     drem32u2        ;
                rol     drem32u3        ;
                sub     drem32u0,dv32u0 ;remainder = remainder - divisor
                sbc     drem32u1,dv32u1 ;
                sbc     drem32u2,dv32u2 ;
                sbc     drem32u3,dv32u3 ;
                brcc    d32u_loop       ;clear carry to be shifted into res
                add     drem32u0,dv32u0 ;if result negative
                adc     drem32u1,dv32u1 ;   restore remainder
                adc     drem32u2,dv32u2 ;
                adc     drem32u3,dv32u3 ;
                rjmp    d32u_loop       ;   set carry to be shifted into res

;***************************************************************************
;*
;* Mul32 == 8x16 Bit Unsigned Multiplication
;*
;* mp32uL::mp32uH  x  mc32uL  =  m32uL::m32uH
;*   multiplier        multiplicand         result
;*  r20r21   x   r16   =  r20r21r22r23
;*
;***************************************************************************
.def    mc32u0  =r16    ; multiplicand byte 0 (LSB)
.def    mc32u1  =r17    ; multiplicand byte 1
.def    mc32u2  =r18    ; multiplicand byte 2
.def    mc32u3  =r19    ; multiplicand byte 3 (MSB)
.def    mp32u0  =r20    ; multiplier byte 0 (LSB)
.def    mp32u1  =r21    ; multiplier byte 1
.def    mp32u2  =r22    ; multiplier byte 2
.def    mp32u3  =r23    ; multiplier byte 3 (MSB)
.def    m32u0   =r20    ; result byte 0 (LSB)
.def    m32u1   =r21    ; result byte 1
.def    m32u2   =r22    ; result byte 2
.def    m32u3   =r23    ; result byte 3
.def    m32u4   =r24    ; result byte 4
.def    m32u5   =r25    ; result byte 5
.def    m32u6   =r26    ; result byte 6
.def    m32u7   =r27    ; result byte 7 (MSB)
.def    mcnt32u =r28    ; loop counter

Mul32b:         clr     mc32u1          ;multiplicand is one byte
Mul32w:         clr     mc32u2          ;                two bytes
Mul32t:         clr     mc32u3          ;                three bytes
Mul32:          clr     m32u7           ;clear 4 highest bytes of result
                clr     m32u6           ;
                clr     m32u5           ;
                sub     m32u4,m32u4     ;and carry
                ldi     mcnt32u,33      ;init loop counter
m32u_loop:      ror     m32u3           ;rotate result and multiplier
                ror     m32u2           ;
                ror     m32u1           ;
                ror     m32u0           ;
                dec     mcnt32u         ;decrement loop counter
                breq    Return32u       ;if counter zero return
                brcc    m32u_skip       ;if bit 0 of multiplier set
                add     m32u4,mc32u0    ;   add multiplicand to result
                adc     m32u5,mc32u1    ;
                adc     m32u6,mc32u2    ;
                adc     m32u7,mc32u3    ;
m32u_skip:      ror     m32u7           ;shift right result byte 7
                ror     m32u6           ;rotate right result
                ror     m32u5           ;
                ror     m32u4           ;
                rjmp    m32u_loop       ;

;***************************************************************************
;*
;* Bin2BCD == 16-bit Binary to BCD conversion
;*
;* fbinL:fbinH  >>>  tBCD0:tBCD1:tBCD2
;*     hex                  dec
;*   r16r17     >>>      r20r21r22
;*
;***************************************************************************
.def    fbinL   =r16    ; binary value Low byte
.def    fbinH   =r17    ; binary value High byte
.def    tBCD0   =r20    ; BCD value digits 0 and 1
.def    tBCD1   =r21    ; BCD value digits 2 and 3
.def    tBCD2   =r22    ; BCD value digit 4 (MSD is lowermost nibble)

Bin2BCD20:      mov     r16,r20         ;for compatibility with Math32
                mov     r17,r21         ;
Bin2BCD16:      ldi     tBCD2,0xff      ;initialize digit 4
binbcd_4:       inc     tBCD2           ;
                subi    fbinL,low(10000);subiw fbin,10000
                sbci    fbinH,high(10000)
                brcc    binbcd_4        ;
                ldi     tBCD1,0x9f      ;initialize digits 3 and 2
binbcd_3:       subi    tBCD1,0x10      ;
                subi    fbinL,low(-1000);addiw fbin,1000
                sbci    fbinH,high(-1000)
                brcs    binbcd_3        ;
binbcd_2:       inc     tBCD1           ;
                subi    fbinL,low(100)  ;subiw fbin,100
                sbci    fbinH,high(100) ;
                brcc    binbcd_2        ;
                ldi     tBCD0,0xa0      ;initialize digits 1 and 0
binbcd_1:       subi    tBCD0,0x10      ;
                subi    fbinL,-10       ;addi fbin,10
                brcs    binbcd_1        ;
                add     tBCD0,fbinL     ;LSD
binbcd_ret:     ret                     ;
.equ Bin2BCD=Bin2BCD20 ;default registers BIN to BCD call
