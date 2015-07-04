#!/bin/bash
# Author: Pushkar
# Date: 17th June 2014
# nagios script for mtr check
# email: pushkarmadan@yahoo.com
# About: Simple nagios script to check the packet loss at routing hops for the given ip.

read HEAD MTROUT <<< $(mtr -c 10 -r $1 |gawk '{gsub(/Loss/,"0.0") gsub(/\%/, "")}{if($1 ~ "Start*" ){{gsub(/\ /, "_")}print $0 }else if ( $3 > "0.0"){{gsub(/\.\|--/,"");print "issue at point " $1, "Where ip like " $2, "and loss =" $3 "%"} }}')

echo $HEAD|sed -e 's/_/\ /g'

if [ -z "$MTROUT" ]
then 
echo "No errors in mtr"
exit 0
else
echo $MTROUT
exit 4
fi
