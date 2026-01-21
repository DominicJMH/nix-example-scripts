#!/usr/bin/env bash

DATE=$(ddate +'the %e of %B%, %Y')

TITLE='
        A SIMPLE SCRIPT SHOWING HOW TO BUILD AND RUN
              SHELL SCRIPTS WITH NIX FLAKES
'

CAT='
  ,------,
 |   /\_/\
 |  =( o_o)=
 |    > ^ <
 |  /|     |\
 | | |_____| |
 | |_/_____\_|
  \_________/
'

RAINBOW='====||====||====||====||====||====||====||===='

clear
echo "$TITLE"
sleep 1

while true; do
  for OFFSET in $(seq 0 30); do
    clear
    echo "$TITLE"
    echo

    printf "%*s%s\n" "$OFFSET" "" "$CAT"
    printf "%*s%s\n" "$OFFSET" "" "$RAINBOW"
    echo
    echo "Today is $DATE."

    sleep 0.08
  done
done
