#!/bin/bash


# set variables
TERM_WIDTH="$(tput cols)"
COLUMNS="$(printf '%*s\n' "${TERM_WIDTH}" '' | tr ' ' -)"


# set exchange data as functions
function exch_bittrex() {
  EXCHNAME="${EXCHNAME} Bittrex"
  CURR="${CURR} BTC"
  BUYEXCH="https://bittrex.com/api/v1.1/public/getticker?market=btc-ans"
  BUYJSON="Ask"
  SLLEXCH="https://bittrex.com/api/v1.1/public/getticker?market=btc-ans"
  SLLJSON="Bid"
}

# set functions
function awk_incrun() {
  awk -v var="${INCRUN}" '{print $var}'
}
function help_addr() {
  echo -e "\nA minimum of one AntShare wallet address is equired:\n" >&2
  echo -e " -a ADDRESS : get the balance of an AntShare wallet\n" >&2
}
function help_examples() {
  echo -e "\nExamples:\n" >&2
  echo -e " $(basename ${0}) -a AWGEETDuxNBy2vN9bMzszc4PTeJW8SRno3 # <-- Single AntShare wallet\n" >&2
  echo -e " $(basename ${0}) -a AWGEETDuxNBy2vN9bMzszc4PTeJW8SRno3 -a AVr8omQKrq3S49MoQrXLcPBwTDmneDuk69 # <-- Multiple AntShare wallets\n" >&2
  echo -e " $(basename ${0}) -a AWGEETDuxNBy2vN9bMzszc4PTeJW8SRno3 -d -v # <-- More information for single AntShare wallet\n" >&2

}
function help_intro() {
  echo -e "\n$(basename ${0}) is a script to convert ANS in an AntShare wallet into fiat currency according to the chosen exchange\n" >&2
}
function help_optional() {
  echo -e "\nFurther options:\n" >&2
  echo -e " -d : Show date when run\n" >&2
  echo -e " -v : Show exchange rate as well\n" >&2
}
function help_help() {
  echo -e "\nRun \"$(basename ${0}) -h\" to see all available options including available exchanges.\n" >&2
}
function value_format() {
  rev | sed "s/.\{3\}/&'/g" | rev | sed "s/^'//"
}
function zero_trail() {
  sed -e 's/[0]*$//g' -e 's/\.$//'
}


# set switches
while getopts ":a:dhv" opt; do
  case ${opt} in
    a)
      ANTSHARE="${ANTSHARE} $(echo ${OPTARG})"
      ;;
    d)
      DATE="$(date +%F\ %T)"
      ;;
    h)
      help_intro
      help_addr
      help_optional
      help_examples
      exit 0
      ;;
    v)
      VERBOSE="1"
      ;;
    \?)
      echo -e "\nInvalid option: \"-${OPTARG}\"\n" >&2
      echo -e "Run \"$(basename ${0}) -h\" for help.\n" >&2
      exit 1
      ;;
  esac
done


# remove whitespaces and remove double entries for wallets addresses
ANTSHARE="$(echo "${ANTSHARE}" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//' -e 's/\b\([a-z]\+\)[ ,\n]\1/\1/' | tr ' ' '\n' | sort -fu)"


# check if given wallet address
if [[ -z "${ANTSHARE}" ]]; then
  help_intro
  help_addr
  help_help
  exit 1
fi


# start output
echo


# if given, output current date
if ! [[ -z "${DATE}" ]]; then
  echo -e "${COLUMNS}\nDATE : ${DATE}"
fi


# start incremental run through all wallet addresses
exch_bittrex
for ANTSHAREWALLET in ${ANTSHARE}; do

  # check if wallet address is valid
  if ! echo "${ANTSHAREWALLET}" | grep -q '^[[:alnum:]]\{34\}$'; then
    echo -e "${COLUMNS}\"${ANTSHAREWALLET}\" is not a valid AntShare address!"

  else
    # get ANS balance
    ANSBAL="$(curl -s "http://antchain.org/api/v1/address/get_value/${ANTSHAREWALLET}" | python -mjson.tool 2> /dev/null | grep -A 1 "\"name\": \"AntShare\"," | grep "\"value\": " | head -1 | awk -F\: '{print $2}' | sed 's/[^0-9]//g')"

    # check that balance is not 0
    NORUN="0"
    if [[ "${ANSBAL}" -eq "0" ]]; then
      echo -e "${COLUMNS}Wallet \"${ANTSHAREWALLET}\" has no ANS!"
      NORUN="1"
    fi


    # if balance is ok, run through exchanges
    if [[ "${NORUN}" -ne "1" ]] ; then
      # format ANS values for output
      ANSFORM="$(echo ${ANSBAL} | value_format)"


      # output AntShare wallet address and amount
      echo -e "${COLUMNS}\nADDR : ${ANTSHAREWALLET}"
      echo "ANS  : ${ANSFORM}"


      # set variable for incremental runs
      INCRUN="0"

      # run once per given exchange
      for i in ${EXCHNAME}; do

        # increment run
        ((INCRUN++))
        INCCURR="$(echo ${CURR} | awk_incrun)"
        INCSLLEXCH="$(echo ${SLLEXCH} | awk_incrun)"
        INCSLLJSON="$(echo ${SLLJSON} | awk_incrun)"
        INCBUYEXCH="$(echo ${BUYEXCH} | awk_incrun)"
        INCBUYJSON="$(echo ${BUYJSON} | awk_incrun)"

        # print exchange
        echo -e "\nEXCH : ${i}"

        # get fiat buying rate
        SLLFIAT="$(curl -s "${INCSLLEXCH}" | python -mjson.tool | grep "\"${INCSLLJSON}\": " | awk -F\: '{print $2}' | sed 's/[^.0-9]//g' | zero_trail)"

        # calculate converted rate and format it nicely
        BTC="$(echo "scale=0; ${ANSBAL} * ${SLLFIAT} / 1" | bc | value_format)"
        BTCMINI="$(echo "scale=10; ${ANSBAL} * ${SLLFIAT} / 1" | bc | awk -F\. '{print $2}' | zero_trail)"
        TOTAL="${BTC}.${BTCMINI}"
        TOTAL="$(echo "${TOTAL}" | sed -e 's/\.0$//' -e 's/\.$//')"


        # create detailed output
        echo "${INCCURR}  : ${TOTAL}"


        # verbose output
        if ! [[ -z "${VERBOSE}" ]]; then
          if echo "${INCBUYEXCH}" | grep -qE "https?://"; then
            BUYFIAT="$(curl -s "${INCBUYEXCH}" | python -mjson.tool | grep "\"${INCBUYJSON}\": " | awk -F\: '{print $2}' | sed 's/[^.0-9]//g' | zero_trail)"
            echo "BUY  : ${BUYFIAT} ${INCCURR}/ANS"
          fi

          echo "SELL : ${SLLFIAT} ${INCCURR}/ANS"
        fi
      done
    fi
  fi
done


# exit script
echo -e "${COLUMNS}\n"
exit $?
