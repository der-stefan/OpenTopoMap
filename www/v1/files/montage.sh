#!/bin/bash 

#Fill in the desired tile numbers here
X1=8688
X2=8700
Y1=5582
Y2=5600
Z=14

for x in `seq $X1 $X2`; do
    
    for y in `seq $Y1 $Y2`; do
    	
	
	if [ -e ${Z}_${y}_${x}.png ]
		then
    		echo "Keep ${Z}_${y}_${x}.png"
	else
		echo "Getting ${x},${y}"
        	curl -s https://a.tile.opentopomap.org/${Z}/${x}/${y}.png -o ${Z}_${y}_${x}.png &
		wait
	fi

    done

done

echo "Start montage"

montage -limit thread 8 -limit memory 30000MB -mode concatenate -tile "$((X2-X1+1))x" "${Z}_*.png" out_z${Z}_${X1}_${Y1}-${X2}_${Y2}.png
