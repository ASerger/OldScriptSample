#!/bin/bash

# Use this on a funky fresh subject to run the unpacking of files and renaming to the FSL directory, which it will create if necessary.
# Presuming you're only using this on a new subject, subRun.sh should be your next file to run as it will take care of everything else.


sub=$1
dataDir="dirPathRemoved/"
timeVar="Baseline"
#chkF="${subDir}/data/PRE_MEAL_RUN_1.nii.gz"

# Make missing fsl directories

for s in ${sub} ; do
  for t in ${timeVar} ; do
  
  if [[ ! -d "${dataDir}/Reward_${t}_Data/RWDR${s}/fsl_RWDR${s}" ]];
  then
  mkdir ${dataDir}/Reward_${t}_Data/RWDR${s}/fsl_RWDR${s}
  fi
  
  done
done

# Populate FSL directories; run dicm2nii

for s in ${sub} ; do
  for t in ${timeVar} ; do
  
  subDir="${dataDir}/Reward_${t}_Data/RWDR${s}/fsl_RWDR${s}"
  
  if [[ -e ${subDir} ]] ; then
  
  cd ${subDir}
  
  mkdir premeal
  mkdir postmeal
  mkdir data
  mkdir behav
  mkdir group
    
  cd "dirPathRemoved/dicm2nii_matlab"
  
  echo "addpath('dirPathRemoved/dicm2nii_matlab')" > tmp.m
  echo "dicm2nii('${dataDir}/Reward_${t}_Data/RWDR${s}/raw_dicom','${subDir}/data');" >> tmp.m
  echo "quit;" >> tmp.m

matlab -nodesktop -nosplash -r "tmp"

  else

  echo "${subDir} Does Not Exist"

  fi
  
  done
done

###


# run fslreorient2std on all subject mprage files; ensuring this step is complete preliminarily across everyone.
# Checks orientation of files against header information to ensure files are in radiological convention
# Left=Right

time="Baseline"

for subject in ${sub} ; do
for t in ${time} ; do

expDir="dirPathRemoved/Reward_${t}_Data"
cd ${expDir}

dataDir="${expDir}/RWDR${subject}/fsl_RWDR${subject}/data"
cd ${dataDir}

fslreorient2std HI_RES_2D_s003.nii.gz HI_RES_2D_s003_std.nii.gz
fslreorient2std HI_RES_2D_s011.nii.gz HI_RES_2D_s011_std.nii.gz


## BET

bet HI_RES_2D_s003_std.nii.gz HI_RES_2D_s003_std_brain.nii.gz -f 0.5 -R
bet HI_RES_2D_s011_std.nii.gz HI_RES_2D_s011_std_brain.nii.gz -f 0.5 -R

done
done

