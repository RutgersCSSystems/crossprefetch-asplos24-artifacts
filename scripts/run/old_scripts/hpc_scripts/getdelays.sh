PROG=$1

ACCOUNTING="/users/shaleen/ssd/NVM/linux-stable/tools/accounting"


while :
do
	PID=$(pgrep $1)
	sleep 1
	if pgrep -x $1 >/dev/null
	then
		sudo $ACCOUNTING/getdelays -p $PID -d -i
	else
		break
	fi
done
