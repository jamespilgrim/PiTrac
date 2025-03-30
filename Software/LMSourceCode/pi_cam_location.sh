#!/bin/bash
for ((m = 0; m <= 5; ++m))
    do
        media-ctl -d "/dev/media$m" --print-dot | grep imx > discover_media.txt
        awk -F"imx296 " '{print $2}' < discover_media.txt | cut -d- -f1 > discover_device.txt
        echo -n -e "$m " > discover_result.txt
        cat discover_device.txt >> discover_result.txt
       if  grep imx discover_media.txt > /dev/null;  then  cat discover_result.txt > /home/mleary/Dev/PiTrac/Software/LMSourceCode/pi_cam_location.txt; break;  fi
            done
            rm -f discover_media.txt discover_device.txt discover_result.txt

