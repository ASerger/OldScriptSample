#!/bin/bash

# Outputs the PRT file directly to the subject folder.

# Now moves the EV files too. Script name change incoming. - AS 1/12

#subs="1001 1002 1003 1004 1005 1006 1007 1008 1009 1010 1011 1012 1013 1014 1015 1016 1017 1018 1019 1020 1021 1022 1023 1024 1025 1026 1027 1028 1029 1030 1031 1032 1033 1035 1037 1038 1039 1040 1042"
subs=$1
time="Baseline" # EOT EOT12 EOT24"
presType="1a 1b 2a 2b 3a 3b 4a 4b"
cond="premeal postmeal"
EV="RestEV HighCalEV LowCalEV NonFoodEV"

# Do PRT files

for s in ${subs} ; do
for t in ${time} ; do
for c in ${cond} ; do
for pt in ${presType} ; do

behDir="dirPathRemoved/Behavioral_Data/RWDR${s}_${t}/"
tarDir="dirPathRemoved/Reward_${t}_Data/RWDR${s}/behav/"


if [ -f "${behDir}${s}${t}_${c}_${pt}.txt" ] ; then
  
    if [ -d "${tarDir}" ] ; then
  
      cp -u ${behDir}${s}${t}_${c}_${pt}.txt ${tarDir}${s}${t}_${c}_${pt}.prt
      rm ${tarDir}${s}${t}_${c}_${pt}_discards.prt
      
      else
      
      echo "${tarDir} Target DNE"
      
    fi
    
    else
    
    echo "${behDir} ${s}${t}_${c}_${pt} Source DNE"
    
fi
  
done
done
done
done


# Do EV Files

for s in ${subs} ; do
for t in ${time} ; do
for c in ${cond} ; do
for pt in ${presType} ; do
for ev in ${EV} ; do

behDir="dirPathRemoved/Behavioral_Data/RWDR${s}_${t}/"
tarDir="dirPathRemoved/Reward_${t}_Data/RWDR${s}/behav/"

if [ -f "${behDir}rwdr${s}${t}_${c}_${ev}_${pt}.txt" ] ; then

  if [ -d "${tarDir}" ] ; then
  
    cp -u ${behDir}rwdr${s}${t}_${c}_${ev}_${pt}.txt ${tarDir}rwdr${s}${t}_${c}_${ev}_${pt}.txt
    
    else echo "${tarDir} DNE"

  fi
  
  else echo "${behDir} ${s}${t}_${c}_${ev}_${pt} Source DNE"
  
fi

done
done
done
done
done
