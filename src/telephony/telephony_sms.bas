SMS_GET_FIRST_EMPTY_INDEX rem
'Get the first empty index of the SMS storage in RAM
'   if no empty index, return -1
k=-1
for i=0 to slngth%
if sidex%(i)=-1 then k=i: return
next i
return

EMPTY_SMS rem
' Delete all SMS from RAM
for i=1 to slngth%
sidex%(i)=-1: stxt$(i)="": snumber$(i)="": sd$(i)="": satus%(i)=-1
next i
sidex%=-1
gosub EMPTY_SMS_PANE
return

EMPTY_CONTACT_SMS rem
'Delete the indices of Contact SMS
for i=0 to 100
mpindex(i)=-1
next i
gosub EMPTY_SMS_CONTACT_PANE
mpindex%=-1: mxindex%=-1: mq=0
return

QUERY_ALL_SMS rem
'poke 0,64 'for debugging only, far too slow!
db=4: gosub SWITCH_TO_SCREEN_DEBUG
gosub EMPTY_SMS
sq=1: satus$="{yel}fetching SMS{elipsis}"
sx=1 'enable cache mechanism for further SMS
sidex%=-1 'begin at SIM index 0
gosub QAS_NEXT
return

QAS_NEXT rem
sidex%=sidex%+1 'index initialized at -1 --> begins at 0
if sidex%<sused% then goto QAS_QUERY 'we didn't query all SMS, so we query next one
jt%(98)=0: gosub QAS_ALL_SMS_LOADED: goto QAS_END 'we queried all SMS, so we go to ALL_SMS_LOADED
'--- Query next SMS ---
QAS_QUERY rem
if db>=4 then print "SMS";sidex%;"/";sused%-1;":"
jt%(98)= QAS_CALLBACK: k=sidex%: gosub SEND_AT+CMGR 'set callback and send message
QAS_END return

QAS_CALLBACK rem
' modem sent a response to at+cmgr=<i>
'NOTE: since we stopped to rely on Result Codes to call our callback, merror cannot longer be used.
if merror=0 then rem 'gosub SMS_TO_SMS_PANE '1 SMS was successfully retrieved. Updating the SMS pane is time consuming.
if merror=1 then merror=0: serror=serror+1 'error getting 1 SMS
gosub QAS_NEXT
return

QAS_ALL_SMS_LOADED rem
if db>=4 then print "All SMS queried!"
'NOTE: since we stopped to rely on Result Codes to call our callback, this serror number cannot be trusted
if serror>0 then sq=2: satus$="{red}some not fetched!" 'at least 1 error
if serror=0 then sq=2: satus$="{grn}successfully fetched" 'SMS queried and all received
serror=0
sx=0 'disable cache mechanism for further SMS
gosub SMS_TO_SMS_PANE 'update SMS pane

if db=4 then for ii=0 to sused%-1: print sidex%(ii);" ";snumber$(ii);" ";satus%(ii);" ";stxt$(ii); " "; sd$(ii): gosub WAIT_FOR_KEY_PRESS: next ii
if db=4 then gosub WAIT_FOR_KEY_PRESS: db=0: gosub SWITCH_TO_LAST_SCREEN
'poke 0,65
return

GET_STATUS_FROM_STRING rem
'Get SMS status integer from status string
'Arguments:
'  s$: the status string, with quotes
'Returns:
'  k: the status integer [0-4]
k=-1
for i=0 to 4:
if s$=sus$(i) then k=i: return
next i
return

GET_SMS_FROM_CONTACT rem
'Get the SMS from a particular contact
'Arguments:
'  r$: the number of the contact from whom we want the SMS
'Returns:
'  no return (fills the mpindex() array and query SMS missing from cache
'db=4: gosub SWITCH_TO_SCREEN_DEBUG
'poke 0,64 'for debugging only
if db>=4 then print "Get SMS from contact "+r$
'--- Get Contact's SMS indices ---
'We first get all the indices of the contact's SMS to fill pindex()
kk=1
for ii=sused%-1 to 0 step -1
if db>=4 then print "SMS";ii ';snumber$(ii);left$(stxt$(ii),5)
if sidex%(ii)>=0 then goto GSFC_COMPARE
if db>=4 then print " SMS";ii;"doesn't exist"
goto GSFC_NEXT 'SMS doesn't exist --> next
GSFC_COMPARE s$=snumber$(ii) 'get the number of current SMS
gosub COMPARE_PHONE_NUMBERS: if b=1 then goto GSFC_CONTACT 'SMS exists and its number is the same as selected contact
if db>=4 then print " Not the same number"
goto GSFC_NEXT 'SMS doesn't exist or its number is not the same --> next
GSFC_CONTACT mpindex(kk)=ii 'add the SMS index to the array of the current contact's SMS
if db>=4 then print " Same number, add SMS to mpindex!"
kk=kk+1 'increment the counter
GSFC_NEXT rem
if db>=4 then gosub WAIT_FOR_KEY_PRESS 'debug
next ii
'Once here, we've gone through all the SMS
mxindex%=kk-1 'kk counter is too high of 1 (incremented after filling an index)
if db>=4 then print "SMS indices of selected contact ("+r$+"):";: for i=1 to mxindex%: print mpindex(i);",";: next i: print chr$(13);
'--- Query not-cached Contact's SMS ---
'We now need to go through the Contact's SMS and query those not in cache
mq=1: matus$="{yel}fetching SMS{elipsis}"
sx=0 'disable cache mechanism for further SMS
mpindex%=0
gosub GSFC_STEP
return

GSFC_STEP rem
mpindex%=mpindex%+1 'increment mpindex% at the beginning of STEP --> start at mpindex%=0
if mpindex%>mxindex% then jt%(100)=0: gosub GSFC_ALL_SMS_LOADED: goto GSFC_END 'we handled all SMS
sidex%=mpindex(mpindex%)
if stxt$(sidex%)<>"" then goto GSFC_IN_CACHE
goto GSFC_QUERY 'the SMS is not in cache, we need to query it
'--- SMS already in cache ---
GSFC_IN_CACHE rem
if db>=4 then print "SMS";sidex%;": in-cache"
goto GSFC_STEP 'this SMS is already in cache, go to next step
'--- Query next SMS ---
GSFC_QUERY rem
if db>=4 then print "SMS";sidex%;": query"
jt%(100)= GSFC_CALLBACK: k=sidex%: gosub SEND_AT+CMGR 'set callback and send message
GSFC_END return

GSFC_CALLBACK rem
' modem sent a response to at+cmgr=<i>
if db>=4 then print "Contact SMS";mpindex%;"/";mxindex%;"..."
if merror=0 then gosub SMS_TO_SMS_CONTACT_PANE '1 SMS was successfully retrieved, update SMS Contact pane
if merror=1 then merror=0: serror=serror+1 'error getting 1 SMS
if db>=4 then gosub WAIT_FOR_KEY_PRESS 'debug
gosub GSFC_STEP 'go to next step
return

GSFC_ALL_SMS_LOADED rem
if db>=4 then print "All Contact SMS queried!"
if serror>0 then matus$="{red}"+str$(serror)+" errors!" 'at least 1 error
if serror=0 then matus$="{grn}success" 'SMS queried and all received
mq=2 'Current contact's SMS have been queried
serror=0
gosub SMS_TO_SMS_CONTACT_PANE 'update Contact SMS pane
sr%=cselected%
if db>=4 then gosub WAIT_FOR_KEY_PRESS
poke 0,65
'db=0: gosub SWITCH_TO_LAST_SCREEN
return



SMS_TO_SMS_PANE rem
'Fill the SMS pane with in-RAM SMS entries (from highest index to lowest)
'Only entries in cache (i.e. with their body in memory) are displayed
kk=0
for ii=sused%-1 to 0 step -1
if kk>smaxpane% then return 'don't fill more than smaxpane% (18) lines
if sidex%(ii)>=0 and stxt$(ii)<>"" then s$=snumber$(ii)+": "+stxt$(ii): l=38: gosub TRIM_STRING_SPACES: gosub RM_STRING_CRLF: spt$(kk)=s$: spi%(kk)=ii: kk=kk+1 'Remove <CR><LF> after having trimmed the string. It should speed up things a bit, since the RM_STRING_CRLF subroutine will go through 38 chars max instead of the whole string
next ii
return

EMPTY_SMS_PANE rem
'Empty the SMS pane
for ii=0 to smaxpane%-1
spt$(ii)="": spi%(ii)=-1
next ii
return

SMS_TO_SMS_CONTACT_PANE rem
'Fill the SMS Contact pane with in-RAM SMS entries, iterating on the array of SMS belonging to the current contact
kk=0
for ii=0 to mxindex% 'no more than mxindex% SMS for this contact
if kk>mmaxpane% then return 'don't fill more than mmaxpane% (12) lines
if mpindex(ii)>=0 then s$=stxt$(mpindex(ii)):l=34: gosub TRIM_STRING_SPACES: gosub RM_STRING_CRLF: mpt$(kk)=s$: mpi%(kk)=mpindex(ii): kk=kk+1
next ii
return

EMPTY_SMS_CONTACT_PANE rem
'Empty the Contact SMS pane
for ii=0 to mmaxpane%-1
mpt$(ii)="": mpi%(ii)=-1
next ii
return


SEND_SMS rem
'Send SMS
'Argument (text mode):
'  sm$: the message string
'  sn$: the phone number to send to
'  gf%: the SMS Message Format (0: PDU, 1: text)
'  mc: callback to call after message has been sent
if gf%=1 then goto S_AT+CMGS_TEXT 'text mode
if db>=4 then print "SMS PDU mode not implemented!": return
S_AT+CMGS_TEXT rem
'Message to send:
'  AT+CMGS=<da>[,<toda>]<CR>
'The modem will reply with:
'  >
jt%(99)= SEND_SMS_PROMPT_CALLBACK 'callback for the message prompt (">")
gosub SEND_AT+CMGS_1 'send the actual command
return

SEND_SMS_PROMPT_CALLBACK rem
'Received the message prompt (">")
'We can now enter the message, and end with:
'  <ctrl+z>  (ctrl-z is the SUB ASCII char, dec=26)
jt%(99)=0
if db>=4 then gosub WAIT_FOR_KEY_PRESS
jt%(100)= SEND_SMS_CALLBACK 'set the callback for result code
s$=sm$+chr$(26): gosub WRITE_STRING_TO_MODEM 'send the body of message + ctrl-z
return

SEND_SMS_CALLBACK rem
'Response to AT+CMGS received
jt%(100)=0
if db>=4 then gosub WAIT_FOR_KEY_PRESS
ln=mc: gosub GOTO_LN 'jump to Message sent callback
return
