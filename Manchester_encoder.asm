; ************************************************************
; Manchester_encoder routine
; input SRAM cells:
;	*TH1 - 1st number of temperature
;	*TH2 - 2nd number of temperature
;	*TH3 - 3d number of temperature
;	*Flags - B H S flags
;	*Channel - 0, 1 or 2 channel number
; OUTPUT SRAM:
;	*CH_byte, *TH1X_byte, *TH32_Byte, *CRC_byte
; ************************************************************
Manch_encoder:
	push Temp			// Store corrupted registers
	push Temp2
	push ZH
	push ZL	
	push r0	
	push r1

	lds Temp, Channel
	sts CH_byte, Temp 	// Save chanel byte
	lds Temp, TH1 		// load TH1 digit

//	Flags check	
	lds Temp2, Flags	// load flags byte
	or Temp, Temp2
	sts TH1X_byte, Temp	// Save TH1 with flags

	lds Temp, TH3 		// Temp = TH3 digit
	lds Temp2, TH2		// Temp2 = TH2 digit
	swap Temp2
	or Temp2, Temp		// Combine TH2 and TH3 bits in 1 byte
	sts TH32_byte, Temp2// Save TH32_byte
	clr Temp
	lds r0, CH_byte
	add Temp, r0

	lds r0, TH32_byte
	add Temp, r0

	lds r0, TH1X_byte
	add Temp, r0

	//Temp=Computed CRC
	rcall Byte_Rotator	//Rotate CRC
	sts CRC_byte, Temp	// Save CRC in SRAM
	lds Temp, TH1X_byte	// Rotate all bytes and store them rotated
	rcall Byte_Rotator
	sts TH1X_byte, Temp
	lds Temp, TH32_byte
	rcall Byte_Rotator
	sts TH32_byte, Temp
	lds Temp, CH_byte
	rcall Byte_Rotator
	sts CH_byte, Temp
// Now we have rotated array ready for manchester coding	
	clr ZH
	ldi ZL, EncodedBits	// pointer to start of Encoded bits aray
// Fill preamble bits
	ldi Temp, 0b10101010
	std Z+0, Temp
	std Z+1, Temp
	std Z+2, Temp
//Fill sync pattern
	ldi Temp, 0b10101010
	std	Z+3, Temp	
	lds Temp, CH_byte
	rcall Mach_filler
	std Z+4, Temp
	std Z+5, Temp2
	lds Temp, TH32_byte
	rcall Mach_filler
	std Z+6, Temp
	std Z+7, Temp2
	lds Temp, TH1X_byte
	rcall Mach_filler
	std Z+8, Temp
	std Z+9, Temp2
	lds Temp, CRC_byte
	rcall Mach_filler
	std Z+10, Temp
	std Z+11, Temp2
	// OK all bits are coded and saved
// restore corrupted registers and quit
	pop r1	
	pop r0
	pop ZL
	pop ZH
	pop Temp2
	pop Temp
	ret

//********************************************
//	Byte rotator - rotates all bits in byte
// 	in r16 - Byte in
// 	out r16 - Byte out
//********************************************
Byte_rotator:
	push Temp2
	clr Temp2
	sbrc Temp, 0
	sbr Temp2, 0b10000000	
	sbrc Temp, 1
	sbr Temp2, 0b01000000
	sbrc Temp, 2
	sbr Temp2, 0b00100000
	sbrc Temp, 3
	sbr Temp2, 0b00010000
	sbrc Temp, 4
	sbr Temp2, 0b00001000
	sbrc Temp, 5
	sbr Temp2, 0b00000100
	sbrc Temp, 6
	sbr Temp2, 0b00000010
	sbrc Temp, 7
	sbr Temp2, 0b00000001
	mov Temp, Temp2
	pop Temp2
	ret

// ***************************************
// Mach_filler
// in r16 - byte to encode
// out r16, 17 - encoded word
// ***************************************
Mach_filler:
	ldi Temp2, 0b10101010
	sbrc Temp, 7	
	rjmp Manch_chk6
	sbr Temp2, 0b01000000
	cbr Temp2, 0b10000000
Manch_chk6:
	sbrc Temp, 6	
	rjmp Manch_chk5
	sbr Temp2, 0b00010000
	cbr Temp2, 0b00100000
Manch_chk5:
	sbrc Temp, 5	
	rjmp Manch_chk4
	sbr Temp2, 0b00000100
	cbr Temp2, 0b00001000
Manch_chk4:
	sbrc Temp, 4	
	rjmp Manch_chk3
	sbr Temp2, 0b00000001
	cbr Temp2, 0b00000010
Manch_chk3:
	push Temp2
	ldi Temp2, 0b10101010
	sbrc Temp, 3	
	rjmp Manch_chk2
	sbr Temp2, 0b01000000
	cbr Temp2, 0b10000000
Manch_chk2:
	sbrc Temp, 2	
	rjmp Manch_chk1
	sbr Temp2, 0b00010000
	cbr Temp2, 0b00100000
Manch_chk1:
	sbrc Temp, 1	
	rjmp Manch_chk0
	sbr Temp2, 0b00000100
	cbr Temp2, 0b00001000
Manch_chk0:
	sbrc Temp, 0	
	rjmp Manch_chk_exit
	sbr Temp2, 0b00000001
	cbr Temp2, 0b00000010
Manch_chk_exit:
	pop Temp
	ret
