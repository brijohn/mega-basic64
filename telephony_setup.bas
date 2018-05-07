LOOKUP_GOTO_LN_PATCH_ADDRESS rem "=== goto,X lookup of patch address"
for ja=2048 to 40959: if peek(ja-1)<>141 or peek(ja)<>44 then next
return

SETUP_PROGRAM rem "=== program flags and variables setup ==="
db=0: rem "flag db (debug): print debugging information"
sd=1: rem "flag send: send characters typed on keyboard to modem right away"
sc=1: rem "current screen to be displayed and user input to be taken"
sr=50: rem "screen refresh rate: number of loops between 2 screen updates"
su=0: rem "flag su (screen update): a change in the program requires a screen update"
us=0: rem "flag us (updated screen): is set to 1 when the screen if actually updated"
cid$="": rem "caller id (number)"
dr$="": rem "dr (dialling result): user friendly information about dialling state"
dia=0: rem "flag dia (dialling): the modem is currently dialling"
rssi=99: rem "rssi: received signal strength indicator"
ber=99: rem "ber: channel bit error rate"
btp=100.0: rem "remaining battery percentage [0:100]"
cnt=0: rem "loop counter"
nact$="": rem "network access technology (GSM, EDGE, HSPA, LTE...)"
ntype$="": rem "network type, to be displayed (2G, 3G, 4G...)"
nname$="": rem "network name to be displayed"

return

SETUP_PARSER rem "=== setup for modem parser ==="
dim mf$(20): rem "fields from colon-comma formatted messages"
dim ol$(20): rem "lines from modem that don't conform to any normal message format"
dim jt%(100): rem "jump table for message handling"
for i=0 to 99: jt%(i)=10000+100*i: next i
open 1,2,1
return

SETUP_MODEM rem "=== modem setup ==="
s$="ate0"+chr$(13): gosub WRITE_STRING_TO_MODEM: rem "no echo from modem"
return

SETUP_GUI rem "=== GUI-related setup ==="
u$="": nb$="": rem "user-input char and number initialization"
sl%=0: rem "Signal Level integer [0:5]"
ber$="?": rem "Bit Error Rate string to be displayed"
bl%=10: rem "Battery Level integer [0:10]"
tmr=1000: rem "timer for keystrokes"
hl%=0: rem "highlighted line (for example in contact pane)"
return

SETUP_PHONEBOOK rem "=== phonebook setup ==="
plngth%=200: rem "maximum number of contacts in the phonebook"
dim pindex%(plngth%): rem "index array"
dim pnumber$(plngth%): rem "phone number array"
dim ptype%(plngth%): rem "phone number type array [129, 145, 161]"
dim ptxt$(plngth%): rem "text array"
dim psim%(plngth%): rem "sim index array"
cmaxindex%=16: rem "dim of contact array"
clngth%=17: rem "max length that can be displayed in the contact pane"
dim cpane$(cmaxindex%): rem "contact pane array: names to be displayed in the contact pane"
dim cindex%(cmaxindex%): rem "contact pane <-> phonebook index mapping"
centry%=0: rem "number of entries in contact pane (<= cmaxindex%)"
cselected%=0: rem "selected contact index (in phonebook)"
cdisplay$="": rem "the text to be displayed on the contact screen"
gosub LOAD_PHONEBOOK
gosub PHONEBOOK_TO_CONTACT_PANE
gosub TRIM_CONTACT_PANE
return

DEFINE_FUNCTIONS rem "=== functions definition ==="
def fn m6(x) = x-(int(x/6)*6): rem "x modulo 6; x % 6"
def fn m1k(x) = x-(int(x/1000)*1000): rem "x modulo 1000; x % 1000"
mdv=1 : rem "modulo divisor"
def fn mod(x) = x-(int(x/mdv)*mdv): rem "x modulo mdv; x % mdv"
return
