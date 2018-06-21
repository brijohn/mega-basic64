'=== read from modem ===
POLL_MODEM rem
if db>=6 then print "polling modem"
'reinitialize parser counter
cp=50
'read one char from cellular modem and parse received fields
PM_GET get#1,c$: if c$="" then return
cp=cp-1
'Special case for message prompt. Maybe we should do it another way (don't use the parser).
if ml$="" and c$=">" then ml$=c$: mf$=c$: goto HANDLE_MODEM_LINE
if c$=chr$(13) or c$=chr$(10) then goto HANDLE_MODEM_LINE
'quote mode: do not parse when between quotes
if c$=chr$(34) then qm=1-qm 'flip quote mode flag
'first field is separated with a column
if c$=":" and fc=0 and qm=0 then mf$(0)=mf$: fc=1: mf$=""
'other fields are separated with a comma; limit=20
if c$="," and fc>0 and fc<20 and qm=0 then mf$(fc)=mf$: fc=fc+1: mf$=""
if qm=0 and c$<>"," and c$<>":" then mf$=mf$+c$ 'when not in quote mode, do not add , or : to the current modem field
if qm=1 then mf$=mf$+c$ 'when in quote mode, add any char to the current modem field
ml$=ml$+c$

'if we didn't handle a non-empty modem line, we poll the modem again (limit: cp times)
if ml=0 and cp>0 goto PM_GET
return

'=== handle modem line ===
HANDLE_MODEM_LINE rem 'received complete line from modem
'--- Additional parsing ---
'add the last field to the field array
if mf$<>"" and fc<20 then mf$(fc)=mf$: fc=fc+1
'debug information
if ml$="" and db>=6 then print "empty line! (<CR> or <LF>)"
'if empty line, immediatly return
if ml$="" then return
'trim one space at the beginning of each field, if there is a whitespace
for i=0 to(fc-1)
if left$(mf$(i),1)=" " then mf$(i)=right$(mf$(i),len(mf$(i))-1)
next i
'--- Debug ---
if db>=4 then print "Received modem line: ";ml$ 's$=ml$: gosub PRINT_STRING_CRLF: print chr$(13);
if db>=5 then print "  modem field count: ";fc
if db>=5 then print "  modem fields: ";
if db>=5 then for i=0 to(fc-1): print chr$(123);mf$(i);chr$(125);: next i: print chr$(13);
'--- Message handling ---
mn=0
gosub GET_MESSAGE_TYPE: gosub JUMP_TO_HANDLER
ml=1 'a non-empty modem line has been handled
'--- Callback handling ---
'Check if we got an acceptable result code:
'  ok, error, +cme error, +cms error'
'  If so, then we will try and jump to a common callback
rc=0
if mn=40 or mn=44 or mn=49 or mn=50 then rc=1
if mn=60 then rc=2 'received message prompt ">"
if mn=58 then rc=3
'Check if we have a common callback registered
if rc=1 then mn=100: gosub JUMP_TO_HANDLER
if rc=2 then mn=99: gosub JUMP_TO_HANDLER
if rc=3 then mn=98: gosub JUMP_TO_HANDLER
'--- Reinit variables ---
ml$="": fc=0: mf$=""
qm=0 'reinit the quote mode, just to make sure the next line will start with quote mode off
'--- Debug ---
if db>=5 then print "" 'print empty line in debug
return


PRINT_STRING_CRLF rem
'Prints a string, replacing CR and LF by text <CR> and <LF>
'Arguments:
'  s$: the string to be printed
for i=1 to len(s$): b$=right$(left$(s$,i),1)
if b$<>"" and b$<>chr$(13) and b$<>chr$(10) then print b$;
if b$=chr$(13) then print chr$(13)+"<cr>";
if b$=chr$(10) then print "<lf>"+chr$(13);
next i
return

'=== Jump to handler ===
JUMP_TO_HANDLER rem
if db>=5 then print "  message is type";mn
'Check if jumptable is set for this message type, if so, call handler
ln=jt%(mn): if ln>0 then gosub GOTO_LN
return

'=== List of all messages ===
GET_MESSAGE_TYPE rem
'--- URC (Unsollicited Result Codes) ---
if mf$(0)="+CREG" then mn=1
if mf$(0)="+CGREG" then mn=3
if mf$(0)="+CTZV" then mn=5
if mf$(0)="+CTZE" then mn=6
if mf$(0)="+CMTI" then mn=7
if mf$(0)="+CMT" then mn=8
if mf$(0)="^HCMT" then mn=10
if mf$(0)="+CBM" then mn=11
if mf$(0)="+CDS" then mn=13
if mf$(0)="+CDSI" then mn=15
if mf$(0)="^HCDS" then mn=16
if mf$(0)="+COLP" then mn=17
if mf$(0)="+CLIP" then mn=18
if mf$(0)="+CRING" then mn=19
if mf$(0)="+CCWA" then mn=20
if mf$(0)="+CSSI" then mn=21
if mf$(0)="+CSSU" then mn=22
if mf$(0)="+CUSD" then mn=23
if mf$(0)="RDY" then mn=24
if mf$(0)="+CFUN" then mn=25
if mf$(0)="+CPIN" then mn=26
if mf$(0)="+QIND" then mn=27
if mf$(0)="POWERED DOWN" then mn=29
if mf$(0)="+CGEV" then mn=30
'--- Result Codes ---
if mf$(0)="OK" then mn=40
if mf$(0)="CONNECT" then mn=41
if mf$(0)="RING" then mn=42
if mf$(0)="NO CARRIER" then mn=43
if mf$(0)="ERROR" then mn=44
if mf$(0)="NO DIALTONE" then mn=46
if mf$(0)="BUSY" then mn=47
if mf$(0)="NO ANSWER" then mn=48
if mf$(0)="+CME ERROR" then mn=49
if mf$(0)="+CMS ERROR" then mn=50
'--- AT commands responses ---
if mf$(0)="+CLCC" then mn=51
if mf$(0)="+CSQ" then mn=52
if mf$(0)="+QNWINFO" then mn=53
if mf$(0)="+QSPN" then mn=54
if mf$(0)="+CPBS" then mn=55
if mf$(0)="+CPBR" then mn=56
if mf$(0)="+QLTS" then mn=57
if mf$(0)="+CMGR" then mn=58
if mf$(0)="+CPMS" then mn=59
if mf$(0)=chr$(62) then mn=60 '">"
if mf$(0)="+CMGS" then mn=61

return

'=== read one line from modem ===
RECEIVE_MODEM_LINE rem
'Receive one line from modem
'Format:
'  <cr><lf> or <lf>
'  line of text
'  <cr><lf>
'Returns:
'  r$: the line of text
r$="": c$="": last$="": crlf=0
RML_LOOP last$=c$: c$="": get#1,c$
if c$="" and last$="" goto RML_LOOP 'empty chars at the beginning of the response"
if c$="" and last$<>"" then return 'empty chars at the end of the response"
if c$<>"" then gosub RML_ADD_CHAR: gosub RML_CRLF
'We exit as soon as we encounter the second <CR><LF>
if crlf>=2 then return
goto RML_LOOP

RML_ADD_CHAR rem
'Adds the char to result (if not <CR> or <LF>)
if c$=chr$(13) or c$=chr$(10) then return
'if c$=chr$(13) then r$=r$+"<cr>": return
'if c$=chr$(10) then r$=r$+"<lf>": return
r$=r$+c$: return

RML_CRLF rem
'If the two last received chars are <CR><LF>, we increment the crlf flag
if c$=chr$(10) and last$=chr$(13) then crlf=crlf+1
if c$=chr$(10) and last$="" then crlf=crlf+1
return

'=== read chars from modem ===
RECEIVE_CHARS_FROM_MODEM rem
'Receive k characters from modem.
'Timeout after 5*k characters polled.
'It ignores the first <cr><lf> or <lf> encountered
'Note: the modem considers <cr><lf> to be a single char (in a SMS at least), but when polling the buffered UART it is most definitely 2 chars. When encountering further <cr><lf>, we decrement the char counter by one.
'Arguments:
'  k: the number of chars to get from modem
'Returns:
'  r$: the string of length k polled from modem
if k<1 then return
r$="": l=0: crlf=0: last$="":
for i=1 to 5*k 'timeout after 5*k chars polled
last$=c$: c$="": get#1,c$: if c$="" then goto RCFM_END 'loop immediatly if empty char
'Add character to string
if c$<>chr$(13) and c$<>chr$(10) then r$=r$+c$: l=l+1 'if not <cr> or <lf>, add it in any case
if c$=chr$(13) or c$=chr$(10) then if crlf>=1 then r$=r$+c$: l=l+1 'add <cr> or <lf> only after the first crlf was encountered
'Track <cr><lf>
gosub RML_CRLF
'Decrement l once when encountering additional <cr><lf>
if c$=chr$(10) and last$=chr$(13) and crlf>=2 then l=l-1
RCFM_END rem 'End
if l=k then return 'we reached k characters, return immediatly
next i
return

'=== purge modem buffer ===
PURGE_MODEM_BUFFER rem
'Purge the modem buffer, more specifically it purges the buffered UART.
'The size of the UART buffer is 2000 bytes (will be reduced in the future).
for i=1 to 2000: get#1,c$: next i
if db>=4 then print "Buffered UART purged"
c$="": return
