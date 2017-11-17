#!/bin/bash
set -x

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

DXLAPRS_HOME=/home/bbs/dxl/dxlAPRS
#W przypadku gdy:
# - chcemy z innych hostow wysylac przez sondeudp do tego sondemod
# - lub chcemy z innych hostow wysylac sondemod do tego udpgate4
# - lub chcemy skorzystac z sdrsharp z innej maszyny na ten sdr
# musimy podac nie loopback(127.0.0.1) a zewnetrzy adres
#IPADDR=$(hostname -I |cut -d' ' -f1)
IPADDR=127.0.0.1

#-------------------ustawienia globalne -----------------------
#wlasny znak
SIGN=SP2PTL
SIGN_SUF_GATE=10 #10 [APLWS2 via qAU, ...-10]
SIGN_SUF_SONDE=11 #11 ....-11>APLWS2,qAU,...-10:;M.... *HHMMSSh9999.99N/99999E (from ...-11) na aprs.fi
SIGN_SUF_SENDER=16
#haslo mozna wygenerowac przez pymultimonaprs/keygen.py <znak>
PASSWORD=18094
#w przypadku ruchomej powinny byc brane bezposrednio z gps-a i zapisywane w gate info
#szerokosc geograficzna bramki
LAT=5423.46
#dlugosc geograficzna bramki
LON=01822.91
#tekst bramki na aprs-ie
GATE_INFO='dxlAPRS www.radiosondy.info'

#------------------ustawienia wspolne ---------------------


DXL_SRC=${DXLAPRS_HOME}/src
DXL_BIN=${DXLAPRS_HOME}/bin
DXL_CONF=${DXLAPRS_HOME}/conf
DXL_LOG=${DXLAPRS_HOME}/log
DXL_TMP=${DXLAPRS_HOME}/tmp
LOGTMSTMP=$(date +"%Y_%m_%d_%H_%M_%S")


#utworzenie katalogow

mkdir -p ${DXL_BIN}
mkdir -p ${DXL_CONF}
mkdir -p ${DXL_LOG}
mkdir -p ${DXL_TMP}


#-------------------ustawienia rinnex ------------------
RINEXPYSCRIPT=/home/bbs/dxl/getrinex.py
RINEXFILE=/home/bbs/dxl/rinex
RINEXORDER=/home/bbs/dxl/getalmanach

#-------------------ustawienia dla rtl_tcp---------------
RTLPORT=1234
PPMERROR=25
GAIN=49.6
DEVICE=0
BLOCKSIZE=30

#dopuszczalne ustawienia do uzyskania przez polecenie rtl_test -t
#------------------ ustawienia dla gate APRS ----------------
GATELOCALUDPPORT=9001
GATELOCALAUXUDPPORT=4010
GATER="${IPADDR}:4011:${GATELOCALAUXUDPPORT}"
GATELOCALPORT=14580
GATESIGN="${SIGN}-${SIGN_SUF_GATE}"
GATELOGLVL=6
GATELOG=${DXL_LOG}/gate.log

UDPRFLOCAL="${IPADDR}:14581:${GATELOCALUDPPORT}"

#plik netbeacon.txt
NETBEACONFILE=${DXL_CONF}/netbeacon.txt
BEACONINFOFRM="!${LAT}N/${LON}E\`${GATE_INFO}"
echo "${BEACONINFOFRM}" >${NETBEACONFILE}

#interwal podawania pozycji bramki na aprs-ie
NTBCNIMIN=10

APRSISFILE=${DXL_CONF}/aprs-is.lst
cat >${APRSISFILE} <<EOF
radiosondy.info:14580
euro.aprs2.net:14580
sp.aprs2.net:14580
poland.aprs2.net:14580
radom.aprs2.net:14580
oe5hpm.hamspirit.at:14580
oe2xzr.ampr.at:14580
44.143.100.1:14580
EOF

# adres www - wpisz w przegladarce: localhost:8080
WWW=${DXLAPRS_HOME}/www/
WWWPORT=8080

# -----------------ustawienia sdrtst ---------------------
SQUELCHPOS=100 # closed squelch needs about 1% cpu of open squelch

SDRTSTCONF=${DXL_CONF}/sdrcfg.txt #channels config
cat >${SDRTSTCONF} <<EOF
p 5 ${PPMERROR}
# AutoGain=1(on) 0(off)
p 8 1

# max 2MHz odstepu miedzy skrajnymi f jak za duzo to komunikat: freq span > iq-sampelrate

#f f=MHz afc_range=0 squelch_%=0 lowpass_%=0 IF_width(szerokosc kanalu=16 KHz

# Lindenberg 2 RS41
#f 405.800 100 60 0

# Lindenberg 1 RS92
#f 405.100 100 60 0

# Greifswald RS92
#f 402.300 100 60 0
#f 404.700 100 60 0

# Łeba
f 403.000 100 60 0

EOF

FIFOFILEMULTICHANNEL=${DXL_TMP}/multichannel.fifo


# --------------ustawienia sondeudp ----------------------
MAXCHANNELS=0 #0-auto ${MAXACTIVERX} # ile na raz czytac strumieni wejsciowych
BUFLEN=128
#probkowanie audio
ADCRATE=16000
SONDESIGN="${SIGN}-${SIGN_SUF_SONDE}"
SONDEGATE="${IPADDR}:4000"

# --------------ustawienia sondemod ----------------------
ALMANACHGPSRINEX=${RINEXFILE}
DECODERPORT=4000
GATEADDRESS=${IPADDR}:${GATELOCALAUXUDPPORT}
SENDERSIGN="${SIGN}-${SIGN_SUF_SENDER}"
REQUESTNEWALMANACHMIN=30
LOWERALTITUDE=1200
LOWERALTINTERVALSEC=1
HIGHALTINTERVALSEC=5
SENDTYPE=2 #0- if weather data ready 1- if MHz known 2- send immediatly

OWNCOMMENTFILE=${DXL_CONF}/sondemod_comment.txt

cat >${OWNCOMMENTFILE} <<EOF
 www.radiosondy.info 
%u 
EOF
#%v - sondemod (c) v 0.7
#%u - uptime
#%s - sat gps count
#%r - tropomodel gps

#---------------------------------------------------------

RTL_CMD="rtl_tcp \
-a ${IPADDR} \
-p ${RTLPORT} \
-g ${GAIN} \
-P ${PPMERROR} \
-d ${DEVICE} \
-b ${BLOCKSIZE} \
2>&1 |tee ${DXL_LOG}/rtl_tcp_${LOGTMSTMP}.log \
"

GATE_CMD="${DXL_BIN}/udpgate4 \
-v \
-R ${GATER} \
-M ${UDPRFLOCAL} \
-s ${GATESIGN} \
-n ${NTBCNIMIN}:${NETBEACONFILE} \
-l 7:${GATELOG} \
-t ${GATELOCALPORT} \
-g radiosondy.info:14580 \
-g euro.aprs2.net:14580 \
-g sp.aprs2.net:14580 \
-g poland.aprs2.net:14580 \
-g radom.aprs2.net:14580 \
-g oe5hpm.hamspirit.at:14580 \
-g oe2xzr.ampr.at:14580 \
-g 44.143.100.1:14580 \
-p ${PASSWORD} \
-D ${WWW} \
-w ${WWWPORT} \
2>&1 |tee ${DXL_LOG}/udpgate4_${LOGTMSTMP}.log \
"


RTL_TCPTOAUDIO_CMD="${DXL_BIN}/sdrtst \
-c /home/bbs/dxl/frequency \
-t ${IPADDR}:${RTLPORT} \
-k \
-v \
-Z ${SQUELCHPOS} \
-s ${FIFOFILEMULTICHANNEL} \
2>&1 |tee ${DXL_LOG}/sdrtst_${LOGTMSTMP}.log \
"

SONDEFRAME_CMD="${DXL_BIN}/sondeudp \
-f ${ADCRATE} \
-l ${BUFLEN} \
-c ${MAXCHANNELS} \
-o ${FIFOFILEMULTICHANNEL} \
-I ${SONDESIGN} \
-v \
-u ${SONDEGATE} \
2>&1 |tee ${DXL_LOG}/sondeudp_${LOGTMSTMP}.log \
"

MULTISONDEDECODER_CMD="${DXL_BIN}/sondemod \
-v \
-x ${ALMANACHGPSRINEX} \
-r ${GATEADDRESS} \
-o ${DECODERPORT} \
-I ${SENDERSIGN} \
-R ${REQUESTNEWALMANACHMIN} \
-d \
-A ${LOWERALTITUDE} \
-B ${LOWERALTINTERVALSEC} \
-b ${HIGHALTINTERVALSEC} \
-p ${SENDTYPE} \
-t ${OWNCOMMENTFILE} \
2>&1 |tee ${DXL_LOG}/sondemod_${LOGTMSTMP}.log \
"

RINEX_CMD="/usr/bin/python ${RINEXPYSCRIPT} \
${RINEXFILE} ${RINEXORDER} \
2>&1 |tee ${DXL_LOG}/rinex_${LOGTMSTMP}.log \
"


echo 'kill-owanie starych procesow: udpgate4 sondemod sondeudp rtl_tcp sdrtst python'
killall -9 udpgate4 sondemod sondemodnew sondeudp rtl_tcp sdrtst python
pkill -9 -f 'SCREEN -S radiosondy'
screen -wipe


echo 'usuwanie starych logow'
find ${DXL_LOG}/ -type f -mtime +7 -print -exec rm -f {} \;
echo 'usuwanie plikow tmp'
rm -f ${DXL_TMP}/*


#skopiowanie programow
#echo 'kopiowanie programow'

cp ${DXL_SRC}/udpgate4 ${DXL_BIN}
cp ${DXL_SRC}/sdrtst ${DXL_BIN}
cp ${DXL_SRC}/sondeudp ${DXL_BIN}
cp ${DXL_SRC}/sondemod ${DXL_BIN}

#echo tworzenie fifo
mkfifo ${FIFOFILEMULTICHANNEL}


echo 'oczekiwanie 5 sek. na zamkniecie portow'
for w in $(seq 1 5);do printf '.' ;sleep 1;done
echo ''
echo 'startowanie screen-ow'

screen -S radiosondy -t main -A -d -m bash

#screen -S radiosondy -X screen -t rinex
#screen -S radiosondy -p rinex -X stuff $"${RINEX_CMD} \n"
#sleep 2

screen -S radiosondy -X screen -t udpgate4
screen -S radiosondy -p udpgate4 -X stuff $"${GATE_CMD} \n"
sleep 2

screen -S radiosondy -X screen -t rtl_tcp
screen -S radiosondy -p rtl_tcp -X stuff $"${RTL_CMD} \n"
sleep 2

screen -S radiosondy -X screen -t sdrtst
screen -S radiosondy -p sdrtst -X stuff $"${RTL_TCPTOAUDIO_CMD} \n"
sleep 2

screen -S radiosondy -X screen -t sondeudp
screen -S radiosondy -p sondeudp -X stuff $"${SONDEFRAME_CMD} \n"
sleep 2

screen -S radiosondy -X screen -t sondemod
screen -S radiosondy -p sondemod -X stuff $"${MULTISONDEDECODER_CMD} \n"
sleep 2

screen -rx radiosondy -p sondeudp

sleep 2
