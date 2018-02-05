.if 0
		XXX - canvas_find gets in infinite loop if canvas is not found
		.endif

;-------------------------------------------------------------------------------
;BASIC interface 
;-------------------------------------------------------------------------------
	.code
	.org		$07FF			;start 2 before load address so
						;we can inject it into the binary
						
	.byte		$01, $08		;load address
	
	.word		_basNext, $000A		;BASIC next addr and this line #
	.byte		$9E			;SYS command
	.asciiz		"2061"			;2061 and line end
_basNext:
	.word		$0000			;BASIC prog terminator
	.assert         * = $080D, error, "BASIC Loader incorrect!"
bootstrap:
		JMP	init

		;;  C64 BASIC extension vectors
		tokenise_vector		=	$0304
		untokenise_vector	=	$0306
		execute_vector		=	$0308
		
;-------------------------------------------------------------------------------
init:
		;; Get acces to DMAgic etc
		LDA	#$47
		STA	$D02F
		LDA	#$53
		STA	$D02F
		
		;; Install $C000 block (and preloaded tiles)
		;; (This also does most of the work initialising the screen)
		lda 	#>c000blockdmalist
		sta	$d701
		lda	#<c000blockdmalist
		sta	$d705
		;; Now patch the screen update by filling the canvas display
		;; with spaces. The canvas screen is 80*50 * 2 bytes per char,
		;; so 8000 bytes in total.  We only need to fill the top 25 rows,
		;; however.
		LDA	#$20
		LDX	#$00
@spaceLoop:
		STA	$E000, X
		STA	$E100, X
		STA	$E200, X
		STA 	$E300, X
		STA	$E400, X
		STA	$E500, X
		STA	$E600, X
		STA	$E700, X
		STA	$E800, X
		STA	$E900, X
		STA	$EA00, X
		STA	$EB00, X
		STA 	$EC00, X
		STA	$ED00, X
		STA	$EE00, X
		STA	$EF00, X
		INX
		INX
		BNE	@spaceLoop

		;; enable wedge
		jsr 	megabasic_enable

		;; Then make the demo tile set available for use
		jsr 	tileset_point_to_start_of_area
		jsr 	tileset_install

		;; Finally, set up the raster interrupt to happen at raster
		;; $100 (just below bottom of text area).
		SEI	
		LDA	#<raster_irq
		STA	$0314
		LDA	#>raster_irq
		STA	$0315		
		LDA	#$7F
		STA	$DC0D
		STA	$DC0E
		LDA	#$9B
		STA	$D011
		LDA	#$00
		STA	$D012
		LDA	#$81
		STA	$D01A
		CLI

		;; XXX And setup NMI ($0318) and BRK ($0316) catchers?
		;; (Model of $FE47 in C64 KERNAL).
		
		rts

c000blockdmalist:
		;; Install pre-prepared tileset @ $12000+
		.byte $0A,$00 	; F011A list follows
		;; Normal F011A list
		.byte $04 ; copy + chained request
		.word preloaded_tiles_length ; set size
		.word preloaded_tiles  ; starting at $4000
		.byte $00   ; of bank $0
		.word $2000 ; destination address is $2000
		.byte $01   ; of bank $1 ( = $12000)
		.word $0000 ; modulo (unused)		

		;; Clear $A000-$FFFF out (so that we can put screen data
		;; at $A000-$BFFF and $E000-$FFFF). This obviously has to
		;; happen BEFORE we copy our code into $C000 :)
		.byte $0A,$00 	; F011A list follows		
		;; Normal F011A list
		.byte $07 ; fill + chained
		.word $10000-$A000 ; size of copy 
		.word $0000 ; source address = fill value
		.byte $00   ; of bank $0
		.word $A000 ; destination address is $A000
		.byte $00   ; of bank $0
		.word $0000 ; modulo (unused)

		;; Clear colour RAM at $FF80800-$FF847FF to go with the above
		.byte $81,$FF  	; destination is $FFxxxxx
		.byte $0A,$00 	; F011A list follows
		;; Normal F011A list
		.byte $07 ; fill + chained
		.word $4000 ; size of copy is 16KB
		.word $0000 ; source address = fill value
		.byte $00   ; of bank $0
		.word $0800 ; destination address is $0800
		.byte $08   ; of bank $0
		.word $0000 ; modulo (unused)
		;;  Clear option $81 from above
		.byte $81,$00
		
		;; Copy MEGA BASIC code to $C000+
		.byte $0A,$00 	; F011A list follows		
		;; Normal F011A list
		.byte $00 ; copy + end of list chain
		.word $1000 ; size of copy is 4KB
		.word c000block ; source address
		.byte $00   ; of bank $0
		.word $C000 ; destination address is $C000
		.byte $00   ; of bank $0
		.word $0000 ; modulo (unused)		


preloaded_tiles:	
		.incbin "bin/megabanner.tiles"
preloaded_tiles_end:	
		preloaded_tiles_length = preloaded_tiles_end - preloaded_tiles
		
;-------------------------------------------------------------------------------
		;; Routines that get installed at $C000
;-------------------------------------------------------------------------------
c000block:	
		.org $C000

megabasic_enable:

		;;  Copy C64 tokens to start of our token list
		;; (but don't copy end of token list)
		LDX	#(($A19C -1) - $A09E + 1)
@tokencopy:
		lda	$A09E,x
		sta	tokenlist,x
		dex
		cpx 	#$ff
		bne 	@tokencopy
		
		;; install vector
		lda #<megabasic_tokenise
		sta tokenise_vector
		lda #>megabasic_tokenise
		sta tokenise_vector+1

		;; Install new detokenise routine
		lda #<megabasic_detokenise
		sta untokenise_vector
		lda #>megabasic_detokenise
		sta untokenise_vector+1

		;; Install new execute routine
		lda #<megabasic_execute
		sta execute_vector
		lda #>megabasic_execute
		sta execute_vector+1

		lda 	#<welcomeText
		ldy 	#>welcomeText
		JSR	$AB1E
		
		RTS

welcomeText:	
		.byte $93,$11,"    **** MEGA65 MEGA BASIC V0.1 ****",$0D
		.byte $11," 55296 GRAPHIC 38911 PROGRAM BYTES FREE",$0D
		.byte $00
		
megabasic_disable:
		RTS

		;; Works on modified version of the ROM tokeniser, but with extended
		;; token list.
		;; Original C64 ROM routine is from $A57C to $A612.
		;; The BASIC keyword list is at $A09E to $A19F.
		;; $A5BC is the part that reads a byte from the token list.
		;; The main complication is that the token list is already $FF bytes
		;; long, so we can't extend it an keep using an 8-bit offset.
		;; We can replace the SBC $A09E,Y with a JSR to a new routine that can
		;; handle >256 bytes of token list.  But life is not that easy, either,
		;; because Y is used in all sorts of other places in that routine.

		;; We will need two pages of tokens, so $A5AE needs to reset access to the low-page
		;; of tokens, as well as Y=0, $0B=0
		
megabasic_tokenise:

		;; Get the basic execute pointer low byte
		LDX	$7A
		;; Set the save index
		LDY	#$04
		;; Clear the quote/data flag
		STY	$0F

@tokeniseNextChar:
		;; Get hi page flag for tokenlist scanning, so that if we INC it, it will
		;; point back to the first page.  As we start with offset = $FF, the first
		;; increment will do this. Since offsets are pre-incremented, this means
		;; that it will switch to the low page at the outset, and won't switch again
		;; until a full page has been stepped through.
		PHA
		LDA 	#$FF
		STA	token_hi_page_flag
		PLA
		
		;; Read a byte from the input buffer
		LDA	$0200,X
		;; If bit 7 is clear, try to tokenise
		BPL	@tryTokenise
		;; Now check for PI (char $FF)
		CMP	#$FF 	; = PI
		BEQ	@gotToken_a5c9
		;; Not PI, but bit 7 is set, so just skip over it, and don't store
		INX
		BNE	@tokeniseNextChar
@tryTokenise:
		;; Now look for some common things
		;; Is it a space?
		CMP	#$20	; space
		BEQ	@gotToken_a5c9
		;; Not space, so save byte as search character
		STA	$08
		CMP	#$22	; quote marks
		BEQ	@foundQuotes_a5ee
		BIT	$0F	; Check quote/data mode
		BVS	@gotToken_a5c9 ; If data mode, accept as is
		CMP	#$3F	       ; Is it a "?" (short cut for PRINT)
		BNE	@notQuestionMark
		LDA	#$99	; Token for PRINT
		BNE	@gotToken_a5c9 ; Accept the print token (branch always taken, because $99 != $00)
@notQuestionMark:
		;; Check for 0-9, : or ;
		CMP 	#$30
		BCC	@notADigit
		CMP	#$3C
		BCC	@gotToken_a5c9
@notADigit:
		;; Remember where we are upto in the BASIC line of text
		STY	$71
		;; Now reset the pointer into tokenlist
		LDY	#$00
		;; And the token number minus $80 we are currently considering.
		;; We start with token #0, since we search from the beginning.
		STY	$0B
		;; Decrement Y from $00 to $FF, because the inner loop increments before processing
		;; (Y here represents the offset in the tokenlist)
		DEY
		;; Save BASIC execute pointer
		STX	$7A
		;; Decrement X also, because the inner loop pre-increments
		DEX
@compareNextChar_a5b6:
		;; Advance pointer in tokenlist
		jsr tokenListAdvancePointer
		;; Advance pointer in BASIC text
		INX
@compareProgramTextAndToken:
		;; Read byte of basic program
		LDA	$0200, X
		;; Now subtract the byte from the token list.
		;; If the character matches, we will get $00 as result.
		;; If the character matches, but was ORd with $80, then $80 will be the
		;; result.  This allows efficient detection of whether we have found the
		;; end of a keyword.
		bit 	token_hi_page_flag
		bmi	@useTokenListHighPage
		SEC
		SBC	tokenlist, Y
		jmp	@dontUseHighPage
@useTokenListHighPage:
		SEC
		SBC	tokenlist+$100,Y
@dontUseHighPage:
		;; If zero, then compare the next character
		BEQ	@compareNextChar_a5b6
		;; If $80, then it is the end of the token, and we have matched the token
		CMP	#$80
		BNE	@tokenDoesntMatch
		;; A = $80, so if we add the token number stored in $0B, we get the actual
		;; token number
		ORA	$0B
@tokeniseNextProgramCharacter:
		;; Restore the saved index into the BASIC program line
		LDY	$71
@gotToken_a5c9:
		;; We have worked out the token, so record it.
		INX
		INY
		STA	$0200 - 5, Y
		;; Now check for end of line (token == $00)
		LDA	$0200 - 5, Y
		BEQ @tokeniseEndOfLine_a609

		;; Now think about what we have to do with the token
		SEC
		SBC	#$3A
		BEQ	@tokenIsColon_a5dc
		CMP	#($83 - $3A) ; (=$49) Was it the token for DATA?
		BNE	@tokenMightBeREM_a5de
@tokenIsColon_a5dc:
		;; Token was DATA
		STA	$0F	; Store token - $3A (why?)
@tokenMightBeREM_a5de:
		SEC
		SBC	#($8F - $3A) ; (=$55) Was it the token for REM?
		BNE	@tokeniseNextChar
		;; Was REM, so say we are searching for end of line (== $00)
		;; (which is conveniently in A now) 
		STA	$08	
@label_a5e5:
		;; Read the next BASIC program byte
		LDA	$0200, X
		BEQ	@gotToken_a5c9
		;; Does the next character match what we are searching for?
		CMP	$08
		;; Yes, it matches, so indicate we have the token
		BEQ	@gotToken_a5c9

@foundQuotes_a5ee:
		;; Not a match yet, so advance index for tokenised output
		INY
		;; And write token to output
		STA	$0200 - 5, Y
		;; Increment read index of basic program
		INX
		;; Read the next BASIC byte (X should never be zero)
		BNE	@label_a5e5

@tokenDoesntMatch:
		;; Restore BASIC execute pointer to start of the token we are looking at,
		;; so that we can see if the next token matches
		LDX	$7A
		;; Increase the token ID number, since the last one didn't match
		INC	$0B
		;; Advance pointer in tokenlist from the end of the last token to the start
		;; of the next token, ready to compare the BASIC program text with this token.
@advanceToNextTokenLoop:
		jsr 	tokenListAdvancePointer
		jsr 	tokenListReadByteMinus1
		BPL	@advanceToNextTokenLoop
		;; Check if we have reached the end of the token list
		jsr	tokenListReadByte
		;; If not, see if the program text matches this token
		BNE	@compareProgramTextAndToken

		;; We reached the end of the token list without a match,
		;; so copy this character to the output, and 
		LDA	$0200, X
		;; Then advance to the next character of the BASIC text
		;; (BPL acts as unconditional branch, because only bytes with bit 7
		;; cleared can get here).
		BPL	@tokeniseNextProgramCharacter
@tokeniseEndOfLine_a609:
		;; Write end of line marker (== $00), which is conveniently in A already
		STA	$0200 - 3, Y
		;; Decrement BASIC execute pointer high byte
		DEC	$7B
		;; ... and set low byte to $FF
		LDA	#$FF
		STA	$7A
		RTS

tokenListAdvancePointer:	
		INY
		BNE	@dontAdvanceTokenListPage
		PHP
		PHA
		LDA	token_hi_page_flag
		EOR	#$FF
		STA	token_hi_page_flag
		;; XXX Why on earth do we need these three NOPs here to correctly parse the extra
		;; tokens? If you remove one, then the first token no longer parses, and the later
		;; ones get parsed with token number one less than it should be!
		NOP
		NOP
		NOP
		PLA
		PLP
@dontAdvanceTokenListPage:
		PHP
		PHX
		PHA
		tya
		tax
		bit	token_hi_page_flag
		bmi	@page2
		jmp	@done
@page2:		
		@done:
		
		PLA
		PLX
		PLP
		RTS

tokenListReadByte:	
		bit 	token_hi_page_flag
		bmi	@useTokenListHighPage
		LDA	tokenlist, Y
		RTS
@useTokenListHighPage:
		LDA	tokenlist+$100,Y
		RTS		

tokenListReadByteMinus1:	
		bit 	token_hi_page_flag
		bmi	@useTokenListHighPage
		LDA	tokenlist - 1, Y
		RTS
@useTokenListHighPage:
		LDA	tokenlist - 1 + $100,Y
		RTS		
		
megabasic_detokenise:
		;; The C64 detokenise routine lives at $A71A-$A741.
		;; The routine is quite simple, reading through the token list,
		;; decrementing the token number each time the end of at token is
		;; found.  The only complications for us, is that we need to change
		;; the parts where the token bytes are read from the list to allow
		;; the list to be two pages long.

		;; Print non-tokens directly
		bpl 	jump_to_a6f3
		;; Print PI directly
		cmp	#$ff
		beq	jump_to_a6f3
		;; If in quote mode, print directly
		bit	$0f
		bmi 	jump_to_a6f3

		;; At this point, we know it to be a token

		;; Tokens are $80-$FE, so subtract #$7F, to renormalise them
		;; to the range $01-$7F
		SEC
		SBC	#$7F
		;; Put the normalised token number into the X register, so that
		;; we can easily count down
		TAX
		STY	$49 	; and store it somewhere necessary, apparently

		;; Now get ready to find the string and output it.
		;; Y is used as the offset in the token list, and gets pre-incremented
		;; so we start with it equal to $00 - $01 = $FF
		LDY	#$FF
		;; Set token_hi_page_flag to $FF, so that when Y increments for the first
		;; time, it increments token_hi_page_flag, making it $00 for the first page of
		;; the token list.
		STY	token_hi_page_flag

		
@detokeniseSearchLoop:
		;; Decrement token index by 1
		DEX
		;; If X = 0, this is the token, so read the bytes out
		beq	@thisIsTheToken
		;; Since it is not this token, we need to skip over it
@detokeniseSkipLoop:
		jsr tokenListAdvancePointer
		jsr tokenListReadByte
		BPL	@detokeniseSkipLoop
		;; Found end of token, loop to see if the next token is it
		BMI	@detokeniseSearchLoop
@thisIsTheToken:
		jsr tokenListAdvancePointer
		jsr tokenListReadByte
		;; If it is the last byte of the token, return control to the LIST
		;; command routine from the BASIC ROM
		BMI	jump_list_command_finish_printing_token_a6ef
		;; As it is not the end of the token, print it out
		JSR	$AB47
		BNE	@thisIsTheToken

		;; This can only be reached if the next byte in the token list is $00
		;; This could only happen in C64 BASIC if the token ID following the
		;; last is attempted to be detokenised.
		;; This is the source of the REM SHIFT+L bug, as SHIFT+L gives the
		;; character code $CC, which is exactly the token ID required, and
		;; the C64 BASIC ROM code here simply fell through the FOR routine.
		;; Actually, understanding this, makes it possible to write a program
		;; that when LISTed, actually causes code to be executed!
		;; However, this vulnerability appears not possible to be exploited,
		;; because $0201, the next byte to be read from the input buffer during
		;; the process, always has $00 in it when the FOR routine is run,
		;; causing a failure when attempting to execute the FOR command.
		;; Were this not the case, REM (SHIFT+L)I=1TO10:GOTO100, when listed
		;; would actually cause GOTO100 to be run, thus allowing LIST to
		;; actually run code. While still not a very strong form of source
		;; protection, it could have been a rather fun thing to try.

		;; Instead of having this error, we will just cause the character to
		;; be printed normally.
		LDY	$49
jump_to_a6f3:	
		JMP 	$A6F3
jump_list_command_finish_printing_token_a6ef:
		JMP	$A6EF

megabasic_execute:		
		JSR	$0073
		;; Is it a MEGA BASIC primary keyword?
		CMP	#$CC
		BCC	@basic2_token
		CMP	#token_first_sub_command
		BCC	megabasic_execute_token
		;; Handle PI
		CMP	#$FF
		BEQ	@basic2_token
		;; Else, it must be a MEGA BASIC secondary keyword
		;; You can't use those alone, so ILLEGAL DIRECT ERROR
		jmp megabasic_perform_illegal_direct_error
@basic2_token:
		;; $A7E7 expects Z flag set if ==$00, so update it
		CMP	#$00
		JMP	$A7E7

megabasic_execute_token:
		;; Normalise index of new token
		SEC
		SBC 	#$CC
		ASL
		;; Clip it to make sure we don't have any overflow of the jump table
		AND	#$0E
		TAX
		PHX
		;; Get next token/character ready
		JSR	$0073
		PLX
		JMP 	(newtoken_jumptable,X)

		;; Tokens are $CC-$FE, so to be safe, we need to have a jump
newtoken_jumptable:
		.word 	megabasic_perform_fast
		.word 	megabasic_perform_slow
		.word	megabasic_perform_canvas ; canvas operations, including copy/stamping, clearing, creating new
		.word	megabasic_perform_colour ; set colours
		.word	megabasic_perform_tile ; "TILE" command, used for TILESET and other purposes
		.word	megabasic_perform_syntax_error ; "SET" SYNTAXERROR: Used only with TILE to make TILESET
		.word 	megabasic_perform_syntax_error
		.word 	megabasic_perform_syntax_error
		.word 	megabasic_perform_syntax_error

		basic2_main_loop 	=	$A7AE

tokenlist:
		;; Reserve space for C64 BASIC token list, less the end $00 marker
		.res ($A19C - $A09E + 1), $00
		;; End of list marker (remove to enable new tokens)
				;.byte $00
		;; Now we have our new tokens
		;; extra_token_count must be correctly set to the number of tokens
		;; (This lists only the number of tokens that are good for direct use.
		;; Keywords found only within statements are not in this tally.)
		extra_token_count = 5
		token_fast = $CC + 0
		.byte "FAS",'T'+$80
		token_slow = $CC + 1
		.byte "SLO",'W'+$80

		token_canvas = $CC + 2
		.byte "CANVA",'S'+$80
		token_colour = $CC + 3
		.byte "COLOU",'R'+$80
		token_tile = $CC + 4
		.byte "TIL",'E'+$80

		token_first_sub_command = token_tile + 1
		
		;; These tokens are keywords used within other
		;; commands, not as executable commands. These
		;; will all generate syntax errors.
		token_text = token_first_sub_command + 0
		.byte "TEX",'T'+$80
		token_sprite = token_first_sub_command + 1
		.byte "SPRIT",'E'+$80
		token_screen = token_first_sub_command + 2
		.byte "SCREE",'N'+$80 
		token_border = token_first_sub_command + 3
		.byte "BORDE",'R'+$80
		token_set = token_first_sub_command + 4
		.byte "SE",'T'+$80
		token_delete = token_first_sub_command + 5
		.byte "DELET",'E'+$80
		token_stamp = token_first_sub_command + 6
		.byte "STAM",'P'+$80
		token_at = token_first_sub_command + 7
		.byte "A",'T'+$80
		token_from = token_first_sub_command + 8
		.byte "FRO",'M'+$80
		;; And the end byte
		.byte $00		

		;; Quick reference to C64 BASIC tokens
		token_clr	=	$9C
		token_new	=	$A2
		token_on	=	$91
		token_to	=	$A4

megabasic_perform_tile:
		;; Valid syntax options:
		;; TILE SET LOAD <"filename"> [,device]
		CMP	#token_set
		bne	megabasic_perform_syntax_error
		JSR	$0073
		CMP	#$93 	; Token for "LOAD" keyword
		bne	megabasic_perform_syntax_error
		JSR	$0073
		;; Convienently the LOAD command has a routine we
		;; can call that gets the filename and device + ,1
		;; options.
		LDA	#$00 	; Set LOAD/VERIFY flag for LOAD
		STA	$0A
		JSR	$E1D4

		;; XXX - Not yet implemented
		
		jmp	basic2_main_loop

megabasic_perform_fast:
		jsr	enable_viciv
		LDA	#$40
		TSB	$D054
		JMP	basic2_main_loop		
		
megabasic_perform_slow:
		jsr	enable_viciv
		LDA	#$40
		TRB	$D054
		JMP	basic2_main_loop		
		
megabasic_perform_colour:
		;; What are we being asked to colour?
		SEC
		SBC	#token_text
		LBMI	megabasic_perform_undefined_function
		CMP	#token_stamp-token_text
		LBCS	megabasic_perform_undefined_function
		;; Okey, we have a valid colour target
		STA	colour_target
		;; Advance to next token
		JSR	$0073
		
		;; All options then require a colour number,
		;; how it is interpretted depends on the target

		;; Evaluate expression
		JSR	$AD8A
		;; Convert FAC to integer in $14-$15
		JSR	$B7F7

		;; Handle the simple cases
		LDA	colour_target
		LDX	#$20
		CMP	#(token_border-token_text)
		BEQ	set_vic_register
		LDX	#$21
		CMP	#(token_screen-token_text)
		BEQ	set_vic_register
		CMP	#(token_text-token_text)
		BNE	@mustBeSpriteColour
@settingTextColour:
		;; Here we are setting the text colour
		;; (this is just a convenience from using CHR$
		;; codes to set the text colour)
		LDA	$14
		STA	$286
		JMP	basic2_main_loop
@mustBeSpriteColour:
		;; Syntax is:
		;; COLOUR SPRITE <n> COLOUR <m> = <r>,<g>,<b>
		;; Where, n is the sprite #, m is the colour ID (0-15), and R,G and B are the RGB values

		;; For now just say undefined function
		JMP	megabasic_perform_undefined_function
		
set_vic_register:	
		JSR	enable_viciv
		LDA	$14
		STA	$D000,X
		;; Re-force video mode in case it was a hot register
		JSR	update_viciv_registers

		JMP	basic2_main_loop

megabasic_perform_load_error:
		LDX	#$1D
		JMP	$A437
		
megabasic_perform_syntax_error:
		LDX	#$0B
		JMP	$A437

megabasic_perform_illegal_direct_error:
		LDX	#$15
		JMP	$A437

megabasic_perform_illegal_quantity_error:
		LDX	#$0E
		JMP	$A437
		
megabasic_perform_canvas:

		;; All CANVAS statement variants require a canvas number
		jsr	$0079
		
		;; Evaluate expression
		JSR	$AD8A
		;; Convert FAC to integer in $14-$15
		JSR	$B7F7
		LDA	$15
		BEQ	@canvasIDNotInvalid
		jmp	megabasic_perform_illegal_quantity_error
@canvasIDNotInvalid:
		LDA	$14
		sta	source_canvas

		;; Get current token 
		JSR	$0079
		CMP	#token_stamp
		LBEQ	megabasic_perform_canvas_stamp
		CMP	#token_delete
		LBEQ	megabasic_perform_canvas_delete
		CMP	#token_clr
		LBEQ	megabasic_perform_canvas_clear
		CMP	#token_new
		LBEQ	megabasic_perform_canvas_new
		CMP	#token_set
		LBEQ	megabasic_perform_canvas_settile
		;; Else, its bad
		JMP	megabasic_perform_undefined_function
		
megabasic_perform_canvas_stamp:
		;; CANVAS s STAMP [from x1,y1 TO x2,y2] ON CANVAS t [AT x3,y3]
		;; Minimal example:
		;; CANVAS 1 STAMP ON CANVAS 0
		;; (with default tileset, should display MEGA65 banner at top of screen)

		;; Get the token after "STAMP"
				
		;; At this point we have only CANVAS STAMP
		LDA	source_canvas
		jsr	canvas_find
		BCS	@foundCanvas
		jmp	megabasic_perform_illegal_quantity_error
@foundCanvas:
		;; $03-$06 pointer now points to canvas header
		;; (unless special case of canvas 0)
		;; Get dimensions of canvas
		LDA	#0
		sta	source_canvas_x1
		sta	source_canvas_y1
		LDA	source_canvas
		BNE	@notCanvas0
		;; Is canvas 0, so dimensions are fixed: 80x50
		lda	#80
		sta	source_canvas_x2
		lda	#50
		sta	source_canvas_y2
		jmp	@gotCanvasSize
@notCanvas0:
		;; Read canvas size from canvas header block
		LDZ	#16
		NOP
		NOP
		LDA	($03),Z
		STA	source_canvas_x2
		INZ
		NOP
		NOP
		LDA	($03),Z
		STA	source_canvas_y2
		LDZ	#$00
@gotCanvasSize:
		;; Get token following STAMP
		JSR	$0073
		cmp	#token_from
		lbne	@stampAll
		;; We are being given a region to copy
		JSR	$0073
		;; get X1
		JSR	$AD8A
		JSR	$B7F7
		LDA	$15
		LBNE	megabasic_perform_illegal_quantity_error
		LDA	$14
		cmp	source_canvas_x2
		lbcs	megabasic_perform_illegal_quantity_error
		STA	source_canvas_x1
		;; get comma between X1 and Y1
		jsr 	$0079
		CMP	#$2C
		LBNE	megabasic_perform_syntax_error
		jsr	$0073
		;; get Y1
		JSR	$AD8A
		JSR	$B7F7
		LDA	$15
		LBNE	megabasic_perform_illegal_quantity_error
		LDA	$14
		cmp	source_canvas_y2
		lbcs	megabasic_perform_illegal_quantity_error
		STA	source_canvas_y1
		;; Check for TO keyword between coordinate pairs
		JSR	$0079
		CMP	#token_to
		LBNE	megabasic_perform_syntax_error
		JSR	$0073
		;; get X2
		JSR	$AD8A
		JSR	$B7F7
		LDA	$15
		LBNE	megabasic_perform_illegal_quantity_error
		LDA	$14
		cmp	source_canvas_x2
		lbcs	megabasic_perform_illegal_quantity_error
		STA	source_canvas_x2
		;; get comma between X2 and Y2
		jsr 	$0079
		CMP	#$2C
		LBNE	megabasic_perform_syntax_error
		jsr	$0073
		;; get Y2
		JSR	$AD8A
		JSR	$B7F7
		LDA	$15
		LBNE	megabasic_perform_illegal_quantity_error
		LDA	$14
		cmp	source_canvas_y2
		lbcs	megabasic_perform_illegal_quantity_error
		STA	source_canvas_y2

		;; Get next token ready (should be TO)
		JSR	$0079
@stampAll:
		;; check that next tokens are ON CANVAS (or just CANVAS to save space and typing)
		CMP	#token_canvas
		BEQ	@skipOn
		CMP	#token_on
		LBNE	megabasic_perform_syntax_error
		jsr 	$0073
		CMP	#token_canvas
		LBNE	megabasic_perform_syntax_error
@skipOn:
		;; Next should be the destination canvas
		JSR	$0073
		JSR	$AD8A
		JSR	$B7F7
		LDA	$15
		LBNE	megabasic_perform_illegal_quantity_error
		LDA	$14
		STA	target_canvas
		jsr	canvas_find
		BCS	@foundCanvas2
		jmp	megabasic_perform_illegal_quantity_error
@foundCanvas2:
		;; Finally, look for optional AT X,Y
		LDA	#$00
		STA	target_canvas_x
		STA	target_canvas_y
		jsr	$0079
		CMP	#token_at
		BNE	@noAt
		;; Parse AT X,y
		JSR	$0073
		;; get X
		JSR	$AD8A
		JSR	$B7F7
		LDA	$15
		LBNE	megabasic_perform_illegal_quantity_error
		LDA	$14
		STA	target_canvas_x
		;; get comma between X1 and Y1
		jsr 	$0079
		CMP	#$2C
		LBNE	megabasic_perform_syntax_error
		jsr	$0073
		;; get Y
		JSR	$AD8A
		JSR	$B7F7
		LDA	$15
		LBNE	megabasic_perform_illegal_quantity_error
		LDA	$14
		STA	target_canvas_y
@noAt:

		;; We now have all that we need to do a token stamping
		;; 1. We know the source and target canvases exist
		;; 2. We know the source region to copy from
		;; 3. We know the target location to draw into

		;; Now we need to get pointers to the various structures,
		;; and iterate through the copy.
		jsr	megabasic_stamp_canvas

		JMP	basic2_main_loop

megabasic_stamp_canvas:
		jsr	zp_scratch_stash
		
		;; CANVAS stamping (copying)
		;; We copy from source_canvas to target_canvas.
		;; Copy is of source_canvas_{x1,y1} to _{x2,y2}, inclusive,
		;; and target is at target_canvas_{x,y}.
		;; The source canvas coordinates are assumed to be valid.
		;; Target canvas dimensions will be deduced and applied
		;; For the copy, we want to do each line in turn.
		;; We need pointers to the four locations, all of
		;; which need to be 32-bit pointers, so that we
		;; can access outside the first 64KB.

		;; Get pointers to, and size of everything
		
		;; Get target pointers into $10-$17
		lda	target_canvas
		jsr	@prepareCanvasPointers
		;; Then copy to $18-$1F
		LDX	#$10
		LDY	#$18
		jsr	copy_32bit_pointer
		LDX	#$14
		LDY	#$1C
		jsr	copy_32bit_pointer
		;; (and canvas dimensions)
		LDX	#$07
		LDY	#$09
		jsr	copy_32bit_pointer

		;; Then get source canvas, and do the same
		lda	source_canvas
		jsr	@prepareCanvasPointers

		LDX	#$00
@ll1a:		LDA	$10, X
		STA	$0400+40*0, X
		INX
		CPX	#$10
		BNE	@ll1a

		lda $07
		sta $044c
		lda $08
		sta $044d
		lda $09
		sta $044e
		lda $0a
		sta $044f
		
		;; The pointers are currently to the start of the
		;; regions.  We need to advance them to the first
		;; line in the source and targets, and then advance
		;; them by the X offset in each.
		;; After that, we can subtract the start offsets,
		;; and process as though copy is from 0,0 to 0,0,
		;; with normalised width and height.
		;; The fast way is to multiply the row number by the
		;; row length. We can use the hardware multiplier for
		;; this.
		jsr 	enable_viciv ; make multiplier registers visible

		; source width*2 = row bytes		
		LDA	$07	
		ASL
		STA	$D780
		ROL
		AND	#$01
		STA	$D781
		;; start row
		LDA	source_canvas_y1
		STA	$D784
		;; Zero out unused upper byteese
		LDA	#$00
		STA 	$D782
		STA	$D783
		STA	$D786
		STA	$D787
		;; XXX - Wait for multiplier to finish
		;; Get multplier result and add X offset
		LDX 	#$00
@ll2:		LDA	$D788, X
		STA	$0B, X
		STA	$0420, X
		INX
		CPX	#4
		BNE	@ll2
		;; Now add 2*(X position of start of copy) to get offset within row
		LDA	source_canvas_x1
		ASL
		CLC
		ADC	$0B
		STA	$0B
		STA	$0424
		PHP
		LDA	source_canvas_x1
		ASL
		ROL
		AND	#$01
		PLP
		ADC	$0C
		STA	$0C
		STA	$0425
		LDA	$0D
		ADC	#$00
		STA	$0D
		LDA	#$00
		STA	$0E
		;; $0B-$0E contains the amount to add to the source canvas pointers
		LDX	#$10
		LDY	#$0B
		jsr	add_32bit_value	; X=X+Y
		LDX	#$14
		LDY	#$0B
		jsr	add_32bit_value		
		;; Normalise source canvas positions
		LDA	source_canvas_y2
		SEC
		SBC	source_canvas_y1
		STA	source_canvas_y1
		LDA	source_canvas_x2
		SEC
		SBC	source_canvas_x1
		STA	source_canvas_x2

		LDX	#$00
@ll1b:		LDA	$10, X
		STA	$0400+40*1, X
		INX
		CPX	#$10
		BNE	@ll1b

		
		;; ... and similarly for the target canvas

		; target width*2 = row bytes		
		LDA	$09	
		ASL
		STA	$D780
		ROL
		AND	#$01
		STA	$D781
		;; start row
		LDA	target_canvas_y
		STA	$D784
		;; XXX - Wait for multiplier to finish
		;; Get multplier result and add X offset
		LDX 	#$00
@ll3:		LDA	$D788, X
		STA	$0B, X
		INX
		CPX	#4
		BNE	@ll3
		;; Now add 2*(X position of start of copy) to get offset within row
		LDA	target_canvas_x
		ASL
		CLC
		ADC	$0B
		STA	$0B
		PHP
		LDA	target_canvas_x
		ASL
		ROL
		AND	#$01
		PLP
		ADC	$0C
		STA	$0C
		LDA	$0D
		ADC	#$00
		STA	$0D
		LDA	#$00
		STA	$0E
		;; $0B-$0E contains the amount to add to the target canvas pointers
		LDX	#$18
		LDY	#$0B
		jsr	add_32bit_value	; X=X+Y
		LDX	#$1C
		LDY	#$0B
		jsr	add_32bit_value		
		;; Normalise target canvas positions
		;; Subtract target X offset from target width
		LDA	$09
		SEC
		SBC	target_canvas_x
		STA	$09
		;; Subtract target Y offset from target height
		LDA	$0A
		SEC
		SBC	target_canvas_y
		STA	$0A
		
@stampLineLoop:
		
		LDX	#$00
@ll1:		LDA	$10, X
		STA	$0400+40*5, X
		INX
		CPX	#$10
		BNE	@ll1
		
		;; All done, restore saved ZP
		jmp	zp_scratch_restore

@prepareCanvasPointers:
		;; Get pointers to screen and colour RAM for
		;; source and target canvases into $10-$17,
		;; and width and height into $07,$08
		
		;; Put target screen ram in $10-$13
		;; skip header, and save pointer

		PHA
		jsr	canvas_find
		PLA
		BNE	@targetNotCanvas0
		;; Canvas 0 has set addresses
		LDX	#$10
		jsr	get_canvas0_pointers
		lda	#80
		sta	$07
		LDA	#50
		sta	$08
		jmp 	@gotTargetPointers
@targetNotCanvas0:
		;;  Canvas dimensions 
		lda	canvas_width
		sta	$07		
		lda	canvas_height
		sta 	$08
		
		;; screen RAM rows are at header+64
		JSR	tileset_advance_by_64
		LDX	#$03
		LDY	#$10
		jsr	copy_32bit_pointer
		jsr	tileset_retreat_by_64

		;; colour RAM rows are at header + *(unsigned short*)&header[21]
		LDX	#$03
		LDY	#$14
		jsr	copy_32bit_pointer
		LDZ	#21
		LDA	$14
		CLC
		ADC	($03),Z
		STA	$14
		INZ
		LDA	$15
		CLC
		ADC	($03),Z
		STA	$15
		INZ
		LDA	$16
		CLC
		ADC	($03),Z
		STA	$16
@gotTargetPointers:
		LDZ	#$00
		RTS		

add_32bit_value:
		;; X=X+Y
		CLC
		LDA	$00, X
		ADC	$00, Y
		STA	$00, X
		INX
		INY
		LDA	$00, X
		ADC	$00, Y
		STA	$00, X
		INX
		INY
		LDA	$00, X
		ADC	$00, Y
		STA	$00, X
		INX
		INY
		LDA	$00, X
		ADC	$00, Y
		STA	$00, X
		RTS
		
get_canvas0_pointers:
		;; Canvas 0 screen RAM is at $000E000,
		;; colour RAM at $FF80800
		LDA	#<$E000
		STA	$00,X
		LDA	#>$E000
		STA	$01, X
		LDA	#$00
		STA	$02, X
		STA	$03, X
		LDA	#<$0800
		STA	$04, X
		LDa	#>$0800
		STA	$05, X
		LDA	#<$0FF8
		STA	$06, X
		LDA	#>$0FF8
		STA	$07, X
		RTS
		
copy_32bit_pointer:
		;; Copy 4 bytes from $00XX to $00YY
		LDA	$00,X
		STA	$00,Y
		INX
		INY
		LDA	$00,X
		STA	$00,Y
		INX
		INY
		LDA	$00,X
		STA	$00,Y
		INX
		INY
		LDA	$00,X
		STA	$00,Y
		RTS		
		
megabasic_perform_canvas_new:
megabasic_perform_canvas_delete:
megabasic_perform_canvas_clear:
megabasic_perform_canvas_settile:
		;; FALL THROUGH
megabasic_perform_undefined_function:
		LDX	#$1B
		JMP	$A437		

enable_viciv:
		LDA	#$47
		STA	$D02F
		LDA	#$53
		STA	$D02F

		RTS

update_viciv_registers:	

		;; Enable extended attributes / 8-bit colour register values
		LDA	#$20
		TSB	$D031
		
		;; Force 80 character virtual lines (80*2 for 16-bit char mode)
		LDA	#<80*2
		STA	$D058
		LDA	#>80
		STA	$D059
		;; Screen RAM start address ($0000A000)
		LDA	#$A0
		STA	$D061
		LDA	#$00
		STA	$D060
		STA	$D062
		STA	$D063
		;; Colour RAM start address ($0800)
		STA	$D064
		LDA	#$08
		STA	$D065
		;; Update $D054 bits
		LDA	$D054
		AND	#$EA
		ORA	d054_bits
		STA	$D054
		RTS
				
		
; -------------------------------------------------------------
; Tileset operations
; -------------------------------------------------------------

canvas_find:
		sta	search_canvas
		jsr 	tileset_point_to_start_of_area
		;; Are we looking for canvas 0?
		;; If yes, this is the special case. Always direct
		;; mapped at $E000, 80x50, and has no header structure
		lda	search_canvas
		CMP	#$00
		BNE	@canvasSearchLoop
		;; Set pointer to start of data
		LDA	#$00
		STA	$03
		STA	$05
		STA	$06
		LDA	#$E0
		STA	$04

		;; Set canvas size
		LDA	#80
		STA	canvas_width
		LDA	#50
		STA	canvas_height
		
		SEC
		RTS
@canvasSearchLoop:
		;; Find the next canvas (or first, skipping tileset header)
			jsr 	tileset_follow_pointer

		;; (We assume all following sections are valid, after having been installed.
		;; XXX - We sould check the magic string, just be to safe, anyway, though.)
		LDA	section_size+0
		ORA	section_size+1
		ORA	section_size+2
		BEQ	@endOfSectionList

		;; Found a section. Is the the one we want?
		LDZ	#15
		NOP
		NOP
		LDA	($03),Z
		LDZ	#0
		CMP	search_canvas
		BNE	@canvasSearchLoop
		BEQ	@foundCanvas
@endOfSectionList:		
		CLC
		RTS
@foundCanvas:
		;; Okay, we found it.
		;; Copy width and height out
		LDZ	#16
		NOP
		NOP
		LDA	($03),Z
		STA	canvas_width
		INZ
		NOP
		NOP
		LDA	($03),Z
		STA	canvas_height
		LDZ	#$00
		SEC
		RTS		
		
tileset_install:
		;; Sanity check the tile set that is in memory at 32-bit pointer
		;; in $03, and fix tile numbers in any canvases, so that they are
		;; correct for the tileset location.

		;; Check magic string
		LDZ 	#$00
		LDX	#$00
@magicCheckLoop:
		NOP
		NOP		
		LDA 	($03),Z
		beq	@magicOk
		CMP 	tileset_magic,X
		bne	@magicBad
		INZ
		INX
		CPX	#$10
		BNE	@magicCheckLoop
		BEQ	@magicOk
@magicBad:
		INC	$D020
		LDZ	#$00
		RTS		
@magicOk:
		;; Fix the first tile number.
		;; As we currently use a fixed location at $12000, and
		;; the header = 64 bytes + $300 of palette, the first tile
		;; will be at $12340 = $48D.
		LDZ #20
		lda #<($12000+$40+$300)
		NOP
		NOP
		STA ($03),Z
		INZ
		LDA #>($12000+$40+$300)
		NOP
		NOP
		STA ($03),Z
		LDZ	#$00

		;; Install the supplied palette.
		jsr tileset_install_palette

@sectionPrepareLoop:
		;; Then follow pointer to next section
		jsr 	tileset_follow_pointer
		LDA	section_size+0
		ORA	section_size+1
		ORA	section_size+2
		BEQ	@endOfSectionList

		;; There is another section to prepare
		jsr	tileset_install_section

		;; See if there are any more
		jmp	@sectionPrepareLoop
		
@endOfSectionList:

		RTS

tileset_install_section:
		;; At the moment the only sections that are allowed are
		;; screens (called CANVASes in MEGA BASIC)
		;; We thus must check for the magic string "MEGA65 SCREEN00",
		;; and can complain if it isn't found

		LDZ	#$00
		LDX	#$00
@magicCheckLoop:
		NOP
		NOP
		LDA	($03),Z
		beq	@emptySection
		CMP	canvas_magicstring,X
		bne	@badMagic
		INZ
		INX
		CPX	#15
		bne	@magicCheckLoop
		beq	@magicOk
@badMagic:
		;; Bad section - give a LOAD ERROR
		jmp	megabasic_perform_load_error
@emptySection:
		;; Empty section, so nothing to do
		;; (This relies on having an empty 64 byte block at end
		;; of the tileset file.)
		RTS
@magicOk:
		;; Now we have the CANVAS, we need to add the first tile number
		;; to all tile numbers in the screen RAM section
		;; so we need to look through *(unsigned short *)header[25] bytes
		;; at section + (header + 0x40) bytes, and add the first tile number
		;; (for now hardcoded at $12340/$40 = $048D) to them.
		LDZ	#25
		NOP
		NOP
		LDA	($03),Z
		STA	section_size+0
		INZ
		NOP
		NOP
		LDA	($03),Z
		STA	section_size+1
		LDZ	#$00
		jsr	tileset_stash_pointer		
		jsr	tileset_advance_by_64
@patchTileNumberLoop:
		;; It is nice to allow canvases to contain
		;; references to text characters when loaded. To do this
		;; we need to patch the values to be <$100, so that they
		;; aren't interpretted as full-colour character tiles.
		;; We do this by checking the bottom nybl of the hibh byte
		;; of the tile number. If zero, we don't patch it. If non-zero,
		;; we assume it is a tile number, and then patch it by $48D - $100
		;; (since the $100 offset was there already)

		;; Peek to see if we need to patch this tile
		INZ
		NOP
		NOP
		LDA	($03),Z
		DEZ
		AND	#$1F
		CMP	#$00
		bne	@doPatchTile
		INZ
		INZ
		jmp	@donePatchingTile
@doPatchTile:
		
		NOP
		NOP
		LDA	($03),Z
		CLC
		ADC	#<($048D-$100)
		NOP
		NOP
		STA	($03),Z
		INZ
		NOP
		NOP
		LDA	($03),Z
		ADC	#>($048D-$100)
		NOP
		NOP
		STA	($03),Z
		INZ
@donePatchingTile:
		;; IF Z has wrapped to 0, then inc $04
		CPZ	#$00
		bne	@pointerOk
		inc	$04
@pointerOk:
		
		;; Decrement count of remaining bytes by 2
		lda	section_size+0
		SEC
		SBC	#$02
		STA	section_size+0
		LDA	section_size+1
		SBC	#$00
		STA	section_size+1
		ORA	section_size+0
		BNE	@patchTileNumberLoop

		;; When done, rewind back to where we were
		jsr	tileset_restore_pointer
		
		RTS
		

canvas_magicstring:
		.byte "MEGA65 SCREEN00",0
		
tileset_read_section_size:	
		LDZ	#61
		NOP
		NOP
		LDA	($03),Z
		STA	section_size+0
		INZ
		NOP
		NOP
		LDA	($03),Z
		STA	section_size+1
		INZ
		NOP
		NOP
		LDA	($03),Z
		STA	section_size+2

		LDZ	#$00
		RTS

tileset_point_to_start_of_area:	
		LDA 	#$00
		STA 	$06
		LDA 	#$01
		STA 	$05

		;; Lower 16 bits we start with pointing at $2000
		LDA 	#$20
		STA 	$04
		LDA 	#$00
		STA 	$03
		RTS

tileset_stash_pointer:
		LDX	#$03
@l1:		LDA	$03,X
		STA	stashed_pointer,X
		DEX
		BPL	@l1
		RTS

tileset_restore_pointer:
		LDX	#$03
@l1:		LDA	stashed_pointer,X
		STA	$03,X
		DEX
		BPL	@l1
		RTS
		
tileset_follow_pointer:
		;; Follow the pointer in the section, by adding
		;; the section length to the current pointer
		jsr	tileset_read_section_size
		;; FALL-THROUGH to tileset_advance_by_section_size

tileset_advance_by_section_size:	
		;; Add length to current pointer
		;; (Offsets are 24 bit, so we don't bother touching the
		;; 4th byte of the pointer.)
		lda	section_size+0
		CLC
		ADC	$03
		STA	$03
		lda	section_size+1
		ADC	$04
		STA	$04
		lda	section_size+2
		ADC	$05
		STA	$05
		RTS

tileset_advance_by_64:
		;; Add length to current pointer
		;; (Offsets are 24 bit, so we don't bother touching the
		;; 4th byte of the pointer.)
		lda	#$40
		CLC
		ADC	$03
		STA	$03
		lda	#$00
		ADC	$04
		STA	$04
		lda	#$00
		ADC	$05
		STA	$05
		RTS
		
tileset_retreat_by_64:
		;; Deduct 64 from current pointer
		;; (Offsets are 24 bit, so we don't bother touching the
		;; 4th byte of the pointer.)
		lda	$03
		SEC
		SBC	#$40
		STA	$03
		lda	$04
		SBC	#$00
		STA	$04
		LDA	$05
		SBC	#$00
		STA	$05
		RTS
		

tileset_retreat_by_section_size:	
		;; Add length to current pointer
		;; (Offsets are 24 bit, so we don't bother touching the
		;; 4th byte of the pointer.)
		LDA	$03
		SEC
		SBC	section_size+0
		STA	$03
		LDA	$04
		SBC	section_size+1
		STA	$04
		LDA	$05
		SBC	section_size+2
		STA	$05
		RTS

tileset_install_palette:
		;; Install palette from current tileset
		jsr	enable_viciv
		
		;; Advance to red palette
		lda 	#$40
		sta 	section_size+0
		lda	#$00
		sta	section_size+1
		sta	section_size+2
		jsr	tileset_advance_by_section_size
		LDZ	#$00
		LDX	#$00
@redloop:
		NOP
		NOP
		LDA	($03),Z
		STA	$D100,X
		INZ
		INX
		bne 	@redloop
		lda	#$00
		sta	section_size+0
		lda	#$01
		sta	section_size+1
		jsr	tileset_advance_by_section_size
@greenloop:
		NOP
		NOP
		LDA	($03),Z
		STA	$D200,X
		INZ
		INX
		bne 	@greenloop
		jsr	tileset_advance_by_section_size
@blueloop:
		NOP
		NOP
		LDA	($03),Z
		STA	$D300,X
		INZ
		INX
		bne 	@blueloop

		;; Now step back to start of section.
		;; (We have stepped forward $40 for header, and over 2x $100 for palettes)
		lda	#<$240
		sta	section_size
		lda	#>$240
		sta	section_size+1
		jsr 	tileset_retreat_by_section_size

		LDZ	#$00
		RTS				
		
tileset_magic:
		.byte "MEGA65 TILESET00",0

raster_irq:
		;; MEGA BASIC raster IRQ
		;; This happens at the bottom of the screen,
		;; and copies $E000-$FFFF to $A000 for screen RAM,
		;; and also the colour RAM from $FF82800-$FF847FF to
		;; $FF80800, and then merges in any required changes
		;; from the BASIC screen (char data from $0400 and
		;; colour data from $FF80000).
		;; We need to know if the MEGA BASIC screen is in 40 or
		;; 80 column mode, so that we know how to arrange memory.
		;; (Later we will allow the BASIC screen to be 80x50 also,
		;; which will obviate that, but we aren't there just yet).

		;; Do the initial copies using DMA
		;; (Oh, I am so glad we have DMA, and that we have the
		;; options header to allow setting all the source and destination
		;; locations etc.)
		;; XXX - This DMA *MUST* happen at 50MHz, or there won't be enough
		;; raster time.  But we allow people to use SLOW and FAST commands
		;; to control things in BASIC.  This means SLOW and FAST must use
		;; the VIC-IV speed control register, not the POKE0,65 trick, since
		;; there is no way to READ that, and thus restore it after.
		
		;; Remember current speed setting
		LDA	$D054
		PHA
		;; Enable 50MHz fast mode
		LDA	#$40
		TSB	$D054
		TSB	$D031	

		;; Clear raster IRQ
		INC	$D019

		;; Copy CANVAS 0 stored copy to display copy
		lda 	#>canvas0copylist
		STA	$D701
		LDA	#<canvas0copylist
		STA	$D705
		;; Go through BASIC screen, and copy and non-space
		;; characters, and also overwrite any characters <$100

		jsr 	merge_basic_screen_to_display_canvas

		jsr	update_viciv_registers

		;; XXX $D06B - sprite 16 colour enables
		;; XXX $D06C-E - sprite pointer address
		
		;; Restore CPU speed and set $D054 video settings
		PLA
		AND	#$EA
		ORA	d054_bits		
		STA	$D054

		;; Chain to normal IRQ routine
		;; XXX - We should do this first, so that changing case with SHIFT-C=
		;; happens first, so that when it messes up the VIC-IV registers via touching
		;; hot reg $D016, we can fix it up without waiting for a whole frame.
		;; Else, we need two IRQ routines, the other at top of screen that all it does
		;; is fix the VIC-IV registers.
		JMP	$EA31

canvas0copylist:	
		;; Copy CANVAS 0 screen RAM from $E000 to $A000 for combining with BASIC scree
		.byte $0A,$00 	; F011A list follows		
		;; Normal F011A list
		.byte $04 ; fill + chained
		.word 80*50*2 ; size of copy 
		.word $E000 ; source address = fill value
		.byte $00   ; of bank $0
		.word $A000 ; destination address is $A000
		.byte $00   ; of bank $0
		.word $0000 ; modulo (unused)

		;; Copy colour RAM from $FF82800 down to $FF80800
		.byte $80,$FF  	; source is $FFxxxxx
		.byte $81,$FF  	; destination is $FFxxxxx
		.byte $0A,$00 	; F011A list follows
		;; Normal F011A list
		.byte $00 ; copy + end of chain
		.word 80*50*2 ; size of copy is 4000 bytes
		.word $2800 ; source address = fill value
		.byte $08   ; of bank $0
		.word $0800 ; destination address is $0800
		.byte $08   ; of bank $0
		.word $0000 ; modulo (unused)

merge_basic_screen_to_display_canvas:
		;; Merge BASIC screen onto display canvas.
		;; Because of the expansion of bytes this is a bit fiddly.
		;; Ideally we need to copy line by line, because the line steppings are different
		;; from source to destination

		;; Thus we need 4 pointers:
		;; 1. BASIC 2 screen RAM ($0B-$0C)
		;; 2. BASIC 2 colour RAM ($09-$0A)
		;; 3. MEGA BASIC display canvas screen RAM  ($07-$08)
		;; 4. MEGA BASIC display canvas colour RAM  ($03-$06)
		;; We need to thus first save $03-$0C to a scratch space
		jsr	zp_scratch_stash

		;; We also need to bank out the BASIC ROM
		LDA	$01
		AND	#$FE
		STA	$01

		;; 16-bit pointer to BASIC screen RAM
		LDA	#$00
		STA	$0B
		LDA	#$04
		STA	$0C
		;; 16-bit pointer to canvas screen RAM
		LDA	#$00
		STA	$07
		LDA	#$A0
		STA	$08
		;; 16-bit pointer to BASIC 2 colour RAM
		LDA	#$00
		STA	$09
		LDA	#$D8
		STA	$0A
		;; Set 32-bit pointer to canvas colour RAM
		LDA 	#$00
		STA	$03
		LDA	#$08
		STA	$04
		LDA	#$F8
		STA	$05
		LDA 	#$0F
		STA	$06

.if 1
		
		;;  X = line number
		LDX	#$00
@screenLineLoop:
		;; Y = BASIC 2 position on line
		LDY	#$00
		;; Z = Display canvas position on line ( = Y * 2)
		LDZ	#$00		
@screenCopyCheckLoop:
		;; Is BASIC 2 char other than space?
		;; If not space, then it should replace the tile
		LDA	($0B), Y
		CMP	#$20
		BEQ	@dontReplaceTile
@replaceTileWithChar:
		;; Replace screen RAM bytes
		;; low byte = char
		LDA	($0B), Y
		STA	($07), Z
		;; high byte = more char bits (must be zero), and some VIC-IV attributes, that
		;; are zero for bytes copied from BASIC 2 screeen
		LDA	#$00
		INZ
		STA	($07), Z
		DEZ
		;; Replace colour RAM bytes (trickier as not direct mapped)
		;; Extended attributes in first byte (zero when copied from BASIC 2 screen)
		LDA	#$00
		NOP
		NOP
		STA	($03),Z
		;; Colour goes in 2nd byte
		INZ
		LDA	($09), Y
		NOP
		NOP
		STA	($03),Z
		DEZ
@dontReplaceTile:
		INZ
		INZ
		INY
		;; At end of BASIC 2 line?
		CPY	#40
		BNE	@screenCopyCheckLoop
		;; Advance the various pointers
		;; canvas display colour RAM
		LDA	$03
		CLC
		ADC	#80*2
		STA	$03
		LDA	$04
		ADC	#$00
		STA	$04
		;; Display canvas screen RAM
		LDA	$07
		CLC
		ADC	#80*2
		STA	$07
		LDA	$08
		ADC	#0
		STA	$08
		;; BASIC 2 colour RAM
		LDA	$09
		CLC
		ADC	#40
		STA	$09
		LDA	$0A
		ADC	#0
		STA	$0A
		;; BASIC 2 screen RAM
		LDA	$0B
		CLC
		ADC	#40
		STA	$0B
		LDA	$0C
		ADC	#0
		STA	$0C
				
		INX
		CPX	#25
		BNE	@screenLineLoop

.endif
		
		;; Always end with Z=0, to avoid crazy behaviour from 6502 code
		LDZ	#$00
		
		jsr	zp_scratch_restore
		
		;; Put BASIC ROM back
		LDA	$01
		ORA	#$01
		STA	$01
		
		RTS

		;; We use $03-$22 in ZP as scratch space for some
		;; things.  To be compatible, we save it first, and
		;; restore it again after.
		
zp_scratch_stash:	
		LDX	#$00
@c:		LDA	$03, X
		STA	merge_scratch, X
		INX
		CPX	#$20
		BNE	@c
		RTS

zp_scratch_restore:
		;; Restore ZP bytes
		LDX	#$00
@c2:		LDA	merge_scratch, X
		STA	$03, X
		INX
		CPX	#$20
		BNE	@c2
		RTS
		
; -------------------------------------------------------------
; Variables and scratch space	
; -------------------------------------------------------------

d054_bits:
		;; $01 = sixteen bit character mode
		;; $04 = full colour for chars >$FF
		;; $10 = sprite H640
		.byte $05
		
		;; Flag to indicate which half of token list we are in.
token_hi_page_flag:
		.byte $00

		;; Where a colour is being put
colour_target:
		.byte $00

		;; 24-bit length of a tileset section
section_size:
		.byte 0,0,0
		;; Temporary storage for a 32-bit pointer
stashed_pointer:
		.byte 0,0,0,0

merge_scratch:
		.res $20,0


		;; For CANVAS stamping (copying)
source_canvas:	.byte 0
source_canvas_x1:	.byte 0
source_canvas_y1:	.byte 0
source_canvas_x2:	.byte 0
source_canvas_y2:	.byte 0
target_canvas:	.byte 0
target_canvas_x:	.byte 0
target_canvas_y:	.byte 0

search_canvas:		.byte 0
canvas_width:		.byte 0
canvas_height:		.byte 0
