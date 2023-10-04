Command=$1
ssh -t clstore02.clemson.cloudlab.us $1 &
ssh -t clstore04.clemson.cloudlab.us $1 &
ssh -t clnode058.clemson.cloudlab.us $1 
