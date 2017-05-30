#!/bin/bash

# This is a full code, with adjustable settings for directories listed at the top.
# Ideally you only have to edit the locDir variable, but slight tweaks may be necessary.
# 
# Current ROIs with support are PPA, RSC, OPA (TOS), FFA and LO. (LOC coming soon!)
# 
# This script is designed to use ROIs derived from the GSS method, applied by Josh Julian
# and sent to BWLab for applications.
# This code involves all steps of preprocessing for localizer data, including motion correction,
# alignment of anatomical to functional data, the following alignment of the parcel data,
# masking the functional data, smoothing (FWHM at 0 2 4 6 8), and normalization. Following
# is regression, using the BWLab regression model. However this is interchangeable with your
# regression, so long as you include faces>objects, scenes>objects and objects>scrambledObjects.
# 
# Following regression, the script sets a thresholding value specified in the setup, and provided
# your subBricks are setup correctly, will spit out ROIs constrained by the parcels, and thresholded
# for viewing at 0.000 on the AFNI slider.
# 
# Andrew Serger
# The Ohio State University
# February 17th 2014


# I do recommend reading all the notes throughout the script before starting. Because
# running code blindly is never a good idea.
# I also recommend using the directories provided in the code and moving the few required
# files to where they should be. locDir and templateDir are the easiest to change
# without likely having a problem somewhere. See line 51.

pushd .

# SETUP and SETTINGS

# Set a for loop here across subjects. Just remember to type 'done' at the very bottom (before the popd)
subject=$1

# Main subject directory for localization
locDir=dirPathRemoved/

# Make Useful Directories 
# ref_data must contain your raw nii.gz data.
# analysis must contain your mprage

# set path for raw data and mprage should they need to be copied into the new directories

#rawData14=path/to/raw/data/
#anatData14=path/to/anatomical/data/

cd ${locDir}${subject}/

mkdir analysis
mkdir ref_data
mkdir reg_data
mkdir regressions
mkdir params
mkdir masks
mkdir Parcel_Alignment

#cp ${rawData14} /path/to/${locDir}${subject}/ref_data/
#cp ${anatData14}* /path/to/${locDir}${subject}/analysis/

# Location of template datasets. TemplateDir should contain the standard.nii.gz MNI brain,
# as well as the tlrc parcels, split unilaterially for each ROI.
templateDir=dirPathRemoved/fMRI/templates/
template=${templateDir}standard.nii.gz

# Registered Data ; lots of output files will end up in these directories while the script is
# processing.
regDataDir=${locDir}${subject}/reg_data/
analysisDir=${locDir}${subject}/analysis/
maskDir=${locDir}${subject}/masks/

# Location of original, unaltered localization runs, for motion correction; and nii.gz file
# for creating motion correction parameters. Also specify MC output directory
mcDir=${locDir}${subject}/ref_data/
gzFile=${subject}_loc_r02+orig.nii.gz
mcOutDir=${locDir}${subject}/reg_data/

# Location of MPRAGE
AnatDir=${analysisDir}

# Anatomical Dataset
mprage=${subject}_mprage_al+orig

# Regression output directory
regrDir=${locDir}${subject}/regressions/

# Directory with unaligned functional run(s)
EPIdir=${regDataDir}


# unAligned and aligned EPI prefix/suffix ; based on specified runs.
run1=01
run2=02
runs="${run1} ${run2}"
#run3 ; run4 ; etc. Will require slight alterations to the align_epi_anat function and regression.
unAlEPIprefix=${subject}_loc_r
unAlEPIsuffix=_vr+orig
alEPIprefix=${subject}_loc_r
alEPIsuffix=_vr_al+orig

# Parcel Alignment Directory
PAdir=${locDir}${subject}/Parcel_Alignment/

# Set Smoothing Levels ; second variable for normalization/regression purposes contains a 0.
smoothing="2 4 6 8"
normSmooth="0 2 4 6 8"

# Directory containing censor file, contrasts, and stimulus timing files for regression
regressionFiles=dirPathRemoved/scripts/

# Specify preferred smoothing level for further analyses (something to keep file names cleaned up and accurate
sm=sm4
# Regressed file to use on ROI extraction.
bucketFile=${regrDir}${subject}_loc_${sm}_bucket+orig


# Specify ROIs for alignment, analysis, and extraction. Due to a test-check towards the end of the script, PPA must be included in ROIs.
# If you're code savvy check the for loop at line 430 if you want to remove PPA, but generally I recommend using all of the ROIs currently here.
# This option is more so I can easily add more ROIs if the science community ever agrees on more.
# Also Note: pFs1 and 2 are the right hemisphere version of pFs, just separated. This means pFs is only left hemisphere.
ROIs="PPA RSC OPA LO FFA pFs pFs1 pFs2"
hemis="Left Right"

# Thresholding Setup
# AttBrick must be equal to ANY F-Stat subbrick of your smoothed data, that is not the 
# full F-Stat. I choose the subbrick that is the same as ScenesVsFaces out of habit.
# Speaking of;

# ScenesD must be the SubBrick number corresponding to the ScenesVsObjects_Coef
# ScenesT must be the SubBrick number corresponding to the ScenesVsObjects_Fstat
# facesD must be the SubBrick number corresponding to the FacesVsObjects_Coef
# facesT must be the SubBrick number corresponding to the FacesVsObjects_Fstat
# ObjD must be the SubBrick number corresponding to the ObjVsScrambled_Coef
# ObjT must be the SubBrick number corresponding to the ObjVsScrambled_Fstat

pval=0.05
AttBrick=26
scenesD=25
scenesT=26
facesD=27
facesT=28
objD=15
objT=16

### END SETUP


cd ${mcDir}

3dTstat -mean -prefix base_mean+orig ${gzFile}

for run in ${runs}; do
  3dvolreg \
    -zpad 4 \
    -prefix ${subject}_loc_r${run}_vr \
    -dfile ${subject}_loc_r${run}_vr.1D \
    -base base_mean+orig \
    -verbose \
    ${subject}_loc_r${run}+orig.nii.gz
done

mv *_vr*.BRIK *_vr*.HEAD ${mcOutDir}
cat ${subject}_loc_r*_vr.1D > ${subject}_loc_mc_params.1D
cp ${subject}_loc_mc_params.1D ${PAdir}
mv *_vr.1D ../params/


# Run Alignments
# 
# To quickly rerun alignments via this entire processing script:
# rm /analysis/*mask* *1D *vr*
# rm -r /Parcel_Alignment/
# rm reg_data/* ref_data/*mean*
# 
# Typically any alignment problems can be fixed with -big_move or -giant_move, I have not
# had the coding expertise to deteremine how to auto check alignments to evaluate if
# these options are necessary.

# Move files to Parcel_Alignment for processing
cd ${locDir}${subject}/

cd ${PAdir}
cp ${analysisDir}${subject}_loc_mc_params.1D .
cp ${AnatDir}${mprage}* .
cp ${template} .
cp -r ${EPIdir}* .

# Align functional data to anatomical data

align_epi_anat.py \
-anat ${mprage} \
-epi ${unAlEPIprefix}${run2}${unAlEPIsuffix} \
-epi2anat \
-epi_base mean \
-deoblique off \
-anat_has_skull no \
-volreg off \
-child_epi ${unAlEPIprefix}${run1}${unAlEPIsuffix}

for run in ${runs} ; do
cp ${alEPIprefix}${run}${alEPIsuffix}* ${regDataDir}
cp ${alEPIprefix}${run}${alEPIsuffix}* ${analysisDir}
done



# Enhancement of cortical matter (Gyri and Sulci clarity) for further processing [Specifically for SkullStrip accuracy]

3dUnifize \
-prefix ${subject}_mprage_uni \
-input ${mprage} 

# Skull Strip

3dSkullStrip \
-input ${subject}_mprage_uni+orig \
-prefix ${subject}_mprage_uniStrip \
-niter 400 \
-ld 40

# Initial Anatomical to TLRC Template

3dAllineate \
-prefix ${subject}_mprage_uniStripTLRC \
-base ${template} \
-source ${subject}_mprage_uniStrip+orig \
-twopass \
-cost lpa \
-1Dmatrix_save ${subject}_mprage_uniStripTLRC.aff12.1D \
-autoweight \
-fineblur 3 \
-cmass

# Refinement of previous alignment to template

3dQwarp \
-source ${subject}_mprage_uniStripTLRC+tlrc. \
-base ${template} \
-prefix ${subject}_mprage_uniStripTLRC_qWarp \
-duplo \
-useweight \
-blur 0 3 \
-iwarp


# Alignment of Parcels from TLRC back to ORIG space

cd ${PAdir}

cat_matvec ${subject}_mprage_uniStripTLRC.aff12.1D -I -ONELINE >> ${subject}_InverseAnatWarp.aff12.1D

for ROI in ${ROIs} ; do

cp ${templateDir}${ROI}_Parcel_Mask+tlrc.* .

for hemi in ${hemis} ; do

cp ${templateDir}${ROI}_Parcel_Mask_${hemi}+tlrc.* .

parcel=${ROI}_Parcel_Mask_${hemi}+tlrc.


3dNwarpApply \
-nwarp "${subject}_InverseAnatWarp.aff12.1D ${subject}_mprage_uniStripTLRC_qWarp_WARPINV+tlrc." \
-source ${parcel} \
-master ${alEPIprefix}${run2}${alEPIsuffix} \
-prefix ${ROI}_${hemi}_Parcel_nWarp_al

# Return Parcels to Binary Format.

3dcalc \
-a ${ROI}_${hemi}_Parcel_nWarp_al+orig \
-expr 'step(a-0.5)' \
-prefix ${ROI}_${hemi}_Parcel_nWarp_al_bin

done
done

cp *Parcel_nWarp* ${regrDir}


# Make Masks

cd ${regDataDir}
cp ${PAdir}${subject}_mprage_uniStrip+orig.* .

3dTstat -mean -prefix refEPImean ${alEPIprefix}${run2}${alEPIsuffix}

3dresample -master refEPImean+orig -prefix maskAnat -inset ${subject}_mprage_uniStrip+orig

3dcalc -a maskAnat+orig -expr 'step(a)' -prefix ${subject}_loc_mask

rm maskAnat+orig.*
rm refEPImean+orig.*

cp *mask* ${regrDir}
cp *mask* ${analysisDir}
cp *mask* ${maskDir}
cp *mask* ${PAdir}


# Smooth Data

cd ${regDataDir}

for fwhm in ${smoothing}; do

  for run in ${runs}; do

    3dmerge -1blur_fwhm ${fwhm} \
            -doall \
            -prefix ${subject}_loc_r${run}_vrsm${fwhm} \
            ${subject}_loc_r${run}_vr_al+orig
  done
done

echo Smooooooooooooooooooth as can be.

cp *vrsm* ${analysisDir}


# Normalize Data

echo Normalizing ${subject}

cd ${regDataDir}

for fwhm in ${normSmooth}; do

  for run in ${runs}; do
    if [ ${fwhm} -eq 0 ]; then
      prefix2=${subject}_loc_r${run}_vr_al
    else
      prefix2=${subject}_loc_r${run}_vrsm${fwhm}
    fi
    
    3dTstat -prefix ${prefix2}_mean ${prefix2}+orig

    3dcalc \
      -a ${prefix2}+orig \
      -b ${prefix2}_mean+orig \
      -expr "min(200,a/b*100)-100" \
      -prefix ${prefix2}_norm

    rm ${prefix2}_mean*

  done
done

# Regression

echo Set Up Regression

# Make Motion Correct parameters and Parcel Directory

cd ${locDir}${subject}/params
cat *vr* > ${subject}_loc_mc_params.1D
cp *loc_mc_params* ${regrDir}
cd ${regrDir}
cp ${analysisDir}${mprage}* ${regrDir}


# copy censor, contrasts, and stimulus timing files

cp ${regressionFiles}*1D ${regrDir}


echo Rapidly Regressing

for fwhm in ${normSmooth}; do
  if [ ${fwhm} -eq 0 ]; then
    suffix=_vr_al_norm+orig
  else
    suffix=_vrsm${fwhm}_norm+orig
  fi

  prefix=${regDataDir}${subject}_loc_r

    3dDeconvolve -input \
        ${prefix}${run1}${suffix} \
        ${prefix}${run2}${suffix} \
      -mask ${regrDataDir}${subject}_loc_mask+orig \
      -censor censor.1D \
      -polort 4 \
      -num_stimts 11 \
      -stim_times 1 faces.1D 'BLOCK(18,1)' -stim_label 1 faces \
      -stim_times 2 scenes.1D 'BLOCK(18,1)' -stim_label 2 scenes \
      -stim_times 3 objects.1D 'BLOCK(18,1)' -stim_label 3 objects \
      -stim_times 4 scrambled_objects.1D 'BLOCK(18,1)' -stim_label 4 scrambled_objects \
      -stim_times 5 fixations.1D 'BLOCK(12,1)' -stim_label 5 fixations \
      -stim_file 6 ${subject}_loc_mc_params.1D\[1\] -stim_label 6 mc_params1 -stim_base 6 \
      -stim_file 7 ${subject}_loc_mc_params.1D\[2\] -stim_label 7 mc_params2 -stim_base 7 \
      -stim_file 8 ${subject}_loc_mc_params.1D\[3\] -stim_label 8 mc_params3 -stim_base 8 \
      -stim_file 9 ${subject}_loc_mc_params.1D\[4\] -stim_label 9 mc_params4 -stim_base 9 \
      -stim_file 10 ${subject}_loc_mc_params.1D\[5\] -stim_label 10 mc_params5 -stim_base 10 \
      -stim_file 11 ${subject}_loc_mc_params.1D\[6\] -stim_label 11 mc_params6 -stim_base 11 \
      -num_glt 9 \
      -glt 1 ScenesVsObjectsAndFaces.1D -glt_label 1 ScenesVsObjectsAndFaces \
      -glt 1 FacesVsScenesAndObjects.1D -glt_label 2 FacesVsScenesAndObjects \
      -glt 1 ObjectsVsScrambledObjects.1D -glt_label 3 ObjectsVsScrambledObjects \
      -glt 1 ScenesVsEverything.1D -glt_label 4 ScenesVsEverything \
      -glt 1 FacesVsEverything.1D -glt_label 5 FacesVsEverything \
      -glt 1 ObjectsVsEverything.1D -glt_label 6 ObjectsVsEverything \
      -glt 1 ObjectsVsScenesAndFaces.1D -glt_label 7 ObjectsVsScenesAndFaces \
      -glt 1 ScenesVsObjects.1D -glt_label 8 ScenesVsObjects \
      -glt 1 FacesVsObjects.1D -glt_label 9 FacesVsObjects \
      -bucket ./${subject}_loc_sm${fwhm}_bucket \
      -errts ./${subject}_loc_sm${fwhm}_errts \
      -jobs 4 \
      -fout
      
done


# Threshold and Extraction

# Determine T value for thresholding bucket file


cd ${regrDir}


3dAttribute BRICK_STATAUX ${bucketFile}.HEAD[${AttBrick}] > info.txt

s=$(<info.txt)
set -- $s

ccalc -eval 'fift_p2t('${pval}','${4}','${5}')' > thresh.txt

thresh=$(<thresh.txt)

# Threshold bucket file by contrast type

for ROI in ${ROIs} ; do

if [ ${ROI} == PPA ] ; then

3dclust \
-noabs -isomerge -quiet -1dindex ${scenesD} -1tindex ${scenesT} -1noneg -2thresh -${thresh} ${thresh} \
-prefix ${subject}_ScenesThresh_loc_${sm} 0 0 ${bucketFile}

elif [ ${ROI} == RSC ] ; then
continue

elif [ ${ROI} == OPA ] ; then
continue

elif [ ${ROI} == FFA ] ; then

3dclust \
-noabs -isomerge -quiet -1dindex ${facesD} -1tindex ${facesT} -1noneg -2thresh -${thresh} ${thresh} \
-prefix ${subject}_FacesThresh_loc_${sm} 0 0 ${bucketFile}

elif [ ${ROI} == LO ] ; then

3dclust \
-noabs -isomerge -quiet -1dindex ${objD} -1tindex ${objT} -1noneg -2thresh -${thresh} ${thresh} \
-prefix ${subject}_ObjectsThresh_loc_${sm} 0 0 ${bucketFile}

elif [ ${ROI} == pFs ] ; then
continue

elif [ ${ROI} == pFs1 ] ; then
continue

else [ ${ROI} == pFs2 ]
continue

fi

done

# Extract ROI unilaterally by contrast type

for ROI in ${ROIs} ; do

for hemi in ${hemis} ; do

cp ${PAdir}*${ROI}_${hemi}*bin* ${regrDir}

#         PPA

if [ ${ROI} == PPA ] ; then

3dcalc \
-a ${subject}_ScenesThresh_loc_${sm}+orig. \
-b ${ROI}_${hemi}_Parcel_nWarp_al_bin+orig. \
-expr 'a*b' \
-prefix ${subject}_Extracted${ROI}_${hemi}

#         RSC

elif [ ${ROI} == RSC ] ; then

3dcalc \
-a ${subject}_ScenesThresh_loc_${sm}+orig. \
-b ${ROI}_${hemi}_Parcel_nWarp_al_bin+orig. \
-expr 'a*b' \
-prefix ${subject}_Extracted${ROI}_${hemi}

#         OPA

elif [ ${ROI} == OPA ] ; then

3dcalc \
-a ${subject}_ScenesThresh_loc_${sm}+orig. \
-b ${ROI}_${hemi}_Parcel_nWarp_al_bin+orig. \
-expr 'a*b' \
-prefix ${subject}_Extracted${ROI}_${hemi}

#         FFA

elif [ ${ROI} == FFA ] ; then

3dcalc \
-a ${subject}_FacesThresh_loc_${sm}+orig. \
-b ${ROI}_${hemi}_Parcel_nWarp_al_bin+orig. \
-expr 'a*b' \
-prefix ${subject}_Extracted${ROI}_${hemi}

#         LO

elif [ ${ROI} == LO ] ; then


3dcalc \
-a ${subject}_ObjectsThresh_loc_${sm}+orig. \
-b ${ROI}_${hemi}_Parcel_nWarp_al_bin+orig. \
-expr 'a*b' \
-prefix ${subject}_Extracted${ROI}_${hemi}

#        pFs

elif [ ${ROI} == pFs ] ; then

3dcalc \
-a ${subject}_ObjectsThresh_loc_${sm}+orig. \
-b ${ROI}_${hemi}_Parcel_nWarp_al_bin+orig. \
-expr 'a*b' \
-prefix ${subject}_Extracted${ROI}_${hemi}

elif [ ${ROI} == pFs1 ] ; then

3dcalc \
-a ${subject}_ObjectsThresh_loc_${sm}+orig. \
-b ${ROI}_${hemi}_Parcel_nWarp_al_bin+orig. \
-expr 'a*b' \
-prefix ${subject}_Extracted${ROI}_${hemi}

else [ ${ROI} == pFs2 ]

3dcalc \
-a ${subject}_ObjectsThresh_loc_${sm}+orig. \
-b ${ROI}_${hemi}_Parcel_nWarp_al_bin+orig. \
-expr 'a*b' \
-prefix ${subject}_Extracted${ROI}_${hemi}

fi

done

done

# Combine ROIs for viewing purposes

for ROI in ${ROIs} ; do

3dcalc \
-a ${subject}_Extracted${ROI}_Left+orig. \
-b ${subject}_Extracted${ROI}_Right+orig. \
-expr 'or(a,b)' \
-prefix ${subject}_Extracted${ROI}_Bilateral

done

popd
