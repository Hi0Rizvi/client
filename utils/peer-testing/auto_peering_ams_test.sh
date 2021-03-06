#!/bin/sh/
# This code uses pinger to probe targets around the world: https://ant.isi.edu/software/verfploeter/pinger/index.html.
# A smaller hitlist with 0.3 million IPs is provided with this code.
# Please set the PEERING_DIR based on the installed location of PEERING.
# Please set the OUTPUT_DIR to place the 
# usage: sudo sh auto_peering_ams_test.sh PEERING_SOURCE_DIR OUTPUT_DIR PINGER_DIR

PREFIX=184.164.238.0/24
PEERING_DIR=$1
#PEERING_DIR=/home/asmrizvi/Documents/PhD/2nd_Project/PEERING/client/client/
SOURCE_IP=100.69.128.1
SOURCE_INTERFACE=tap5

YEAR=$(date +"%Y")
MONTH=$(date +"%m")
DAY=$(date +"%d")

DATE=$YEAR-$MONTH-$DAY
OUTPUT_DIR=$2
#OUTPUT_DIR=/home/asmrizvi/Documents/PhD/2nd_Project/PEERING/client/client/captures-new/Selective_Peers/
PINGER_DIR=$3
#PINGER_DIR=/home/asmrizvi/Documents/PhD/2nd_Project/Software/pinger-pinger.v0.4.1-alpha/target/release/


echo "BGP ANNOUNCEMENT"
cd $PEERING_DIR

./peering openvpn up amsterdam01
./peering bgp start amsterdam01

# input is the list of peering ids. I sorted that using CAIDA's AS rank list.
input="amsterdam_list.txt"
while IFS= read -r line
do
	echo "$line"
	./peering prefix announce -m amsterdam01 -c 47065,$line $PREFIX

	echo "BGP announcement done. Waiting for 15 mins...."
	sleep 900
	echo "Wait is done..."

	echo "Starting TCPdump process..."
	# I ran pinger with 184.164.238.33 destination.  
	tcpdump -i $SOURCE_INTERFACE icmp and dst 184.164.238.33 -w $OUTPUT_DIR/$DATE-AMS-$line.pcap &
	sleep 10
	# These are some rules so that pings from pinger go through amsterdam01 mux.
	sudo ip route add table 200 to default via $SOURCE_IP dev $SOURCE_INTERFACE
	sudo ip rule add from 184.164.238.0/24 table 200 priority 10

	cd $PINGER_DIR
	echo "Starting pinger..."
	xzcat ip_list_20190624_test.tar.xz | ./pinger -s 184.164.238.33 -r 5000 -i 14001
	echo "Pinger done..."
	sleep 60
	pkill -9 tcpdump

	cd $PEERING_DIR
	./peering prefix withdraw -m amsterdam01 -c 47065,$line $PREFIX
done < "$input"


