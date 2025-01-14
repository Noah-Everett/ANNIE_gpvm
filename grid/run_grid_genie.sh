#===========================GRID INIT========================#
export BASE_NODE_DIR=`pwd`
set -x
echo Start `date`
echo Site:${GLIDIEN_ResourceName}
echo "the worker node is " `hostname` "OS: " `uname -a`
echo "You are running as user `whoami`"
IFDH_OPTION=""
GROUP=$EXPERIMENT
if [ -z $GROUP ]; then
GROUP=`id -gn`
fi
SCRATCH_DIR=/pnfs/annie/scratch/users
if [ -z $X509_CERT_DIR ] && [ ! -d /etc/grid-security/certificates ]; then
    if [ -f /cvmfs/oasis.opensciencegrid.org/mis/osg-wn-client/current/el7-x86_64/setup.sh ]; then
    source /cvmfs/oasis.opensciencegrid.org/mis/osg-wn-client/current/el7-x86_64/setup.sh || echo "Failure to run OASIS software setup script!"
    else
    echo "X509_CERT_DIR is not set, and the /etc/grid-security/certificates directory is not present. No guarantees ifdh, etc. will work!"
    fi
fi
if [ -z "`which globus-url-copy`" ] || [ -z "`which uberftp`" ]; then
 if [ -f /cvmfs/oasis.opensciencegrid.org/mis/osg-wn-client/current/el7-x86_64/setup.sh ]; then
     source /cvmfs/oasis.opensciencegrid.org/mis/osg-wn-client/current/el7-x86_64/setup.sh || echo "Failure to run OASIS software setup script!"
 else
     echo "globus-url-copy or uberftp (or both) is not in PATH, and the oasis CVMFS software repo does not appear to be present. No guarantees ifdh, etc. will work!"
 fi
fi
# A few commands to lookk around to see what kind of environment we are in. Should match the requested container.
voms-proxy-info --all
lsb_release -a
cat /etc/redhat-release
ps -ef
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setup
setup ifdhc -z /cvmfs/fermilab.opensciencegrid.org/products/common/db || { echo "error setting up ifdhc!" ; sleep 300 ; exit 69; }
#======================================================================#



#===================SCRIPT VARIABLES=====================#
# Directories
export INPUT_TAR_DIR_LOCAL=${BASE_NODE_DIR}/tar
mkdir ${INPUT_TAR_DIR_LOCAL}
B=$INPUT_TAR_DIR_LOCAL/exp/annie/app/users/neverett/bin
C=$INPUT_TAR_DIR_LOCAL/exp/annie/app/users/neverett/config
G=$INPUT_TAR_DIR_LOCAL/exp/annie/app/users/neverett/geometry
#F=$INPUT_TAR_DIR_LOCAL/annie/data/flux/bnb
F=$INPUT_TAR_DIR_LOCAL/annie/data/flux/gsimple_bnb

for i in "$@"; do
  case $i in
    -r=*                   ) export RUNBASE="${i#*=}"     shift  ;;
    -n=*                   ) export NEVENTS="${i#*=}"     shift  ;;
    -e=*                   ) export NPOT="${i#*=}"        shift  ;;
    -g=*                   ) export GEOMETRY="${i#*=}"    shift  ;;
    -t=*                   ) export TOPVOL="${i#*=}"      shift  ;;
    -f=*                   ) export FLUXFILENUM="${i#*=}" shift  ;;
    -m=*                   ) export MAXPL="${i#*=}"       shift  ;;
    --message-thresholds=* ) export MESTHRE="${i#*=}"     shift  ;;
    -i=*                   ) export INDIR="${i#*=}"       shift  ;;
    -o=*                   ) export OUTDIR="${i#*=}"      shift  ;;
    #-*                     ) echo "unknown option $i";    exit 1 ;;
   esac
done

if [ -z "$FLUXFILENUM" ]; then
  export FLUXFILENUM="0000"
fi
#export FLUXFILE="beammc_annie_${FLUXFILENUM}.root"
#export FLUXFILE="bnb_annie_${FLUXFILENUM}.root"
export FLUXFILE="gsimple_beammc_annie_${FLUXFILENUM}.root"

if [ -z "$ZMIN" ]; then
  export ZMIN="-2000"
fi

if [ -z "$GEOMETRY" ]; then
  export GEOMETRY="annie_v02.gdml"
fi

if [-z "$MESTHRE" ]; then
  export MESTHRE=""
fi

if [ -z "$TOPVOL" ]; then
  export $TOPVOL="TARGON_LV"
fi

ifdh cp -D $IFDH_OPTION ${INDIR} ${INPUT_TAR_DIR_LOCAL}
echo "Unzip dir: ${INPUT_TAR_DIR_LOCAL}/$(basename "${INDIR}")"
cd ${INPUT_TAR_DIR_LOCAL}
echo $(basename "${INDIR}")
# gzip -dv $(basename "${INDIR}")
tar -zxvf $(basename "${INDIR}")
ls
cd -
echo "Unzip dir ls: `ls ${INPUT_TAR_DIR_LOCAL}/grid_genie`"

cp /cvmfs/larsoft.opensciencegrid.org/products/genie_xsec/v3_00_04_ub2/NULL/G1810a0211a-k250-e1000/data/gxspl-FNALbig.xml.gz .
gzip -d gxspl-FNALbig.xml.gz

if [ -z ${NEVENTS} ]; then
  export EXPOSURE="-e ${NPOT}"
  export EXPMSG="      Number of POT: ${NPOT}"
else
  export EXPOSURE="-n ${NEVENTS}"
  export EXPMSG="   Number of Events: ${NEVENTS}"
fi
export RUN=${RUNBASE}${PROCESS}
export SEED=${RUNBASE}${PROCESS}${CLUSTER}
export FLXPSET="ANNIE-tank"
export FLUX="${F}/${FLUXFILE},${FLXPSET}"
export GENIEXSEC=gxspl-FNALbig.xml
export UNITS="-L cm -D g_cm3"
export XYZHALL=( -393.70 -213.36   0.0  307.34 1021.08 487.68 )
export XYZBLDG=( -434.34 -259.08 -40.64 347.98 1066.80 528.32 )
#======================================================================#



#===========================GENIE SETUP=======================#
source ${B}/setup_genie3_00_06.sh #$CONDOR_DIR_INPUT/setup_genie3_00_06.sh
export GXMLPATH=${C}:${GXMLPATH} #$CONDOR_DIR_INPUT:${GXMLPATH}
#======================================================================#



#============================GET FILES==========================#
ifdh cp -D $IFDH_OPTION $INPUT_TAR_DIR_LOCAL/${GEOMETRY} .
ifdh cp -D $IFDH_OPTION $INPUT_TAR_DIR_LOCAL/${MAXPL} .
ifdh cp -D $IFDH_OPTION $INPUT_TAR_DIR_LOCAL/${MESTHRE} .
#===============================================================#



#==========================MAKE INFO LOG========================#
export OUTDIR=${OUTDIR}/${RUNBASE}_${CLUSTER}
ifdh mkdir_p ${OUTDIR}
cat <<EOF > settings_${RUN}.log
#===== SETTINGS =====#
            Program: /cvmfs/larsoft.opensciencegrid.org/products/genie/v3_00_06k/Linux64bit+3.10-2.17-e20-debug/bin/gevgen_fnal
                Run: ${RUN}
               Seed: ${SEED}
            Top Vol: ${TOPVOL}
               Flux: ${FLUX}
           Geometry: ${GEOMETRY}
              Units: ${UNITS}
     Cross Sections: ${GENIEXSEC}
${EXPMSG}
               Tune: G18_10a_02_11a
Maximum Path Length: ${MAXPL}
 Message Thresholds: ${MESTHRE}

#===== COMMAND =====#
/cvmfs/larsoft.opensciencegrid.org/products/genie/v3_00_06k/Linux64bit+3.10-2.17-e20-debug/bin/gevgen_fnal \
-r ${RUN} \
--seed ${SEED} \
-t ${TOPVOL} \
-f ${FLUX} \
-g $(basename ${GEOMETRY}) \
${UNITS} \
--cross-sections ${GENIEXSEC} \
--tune G18_10a_02_11a \
${EXPOSURE} \
-m $(basename ${MAXPL}) \
--message-thresholds $(basename ${MESTHRE})

#===== ls =====#
`ls`
EOF
ifdh cp -D $IFDH_OPTION settings_${RUN}.log ${OUTDIR}
#===============================================================#



#===============================RUN GENIE=============================#
/cvmfs/larsoft.opensciencegrid.org/products/genie/v3_00_06k/Linux64bit+3.10-2.17-e20-debug/bin/gevgen_fnal \
-r ${RUN} \
--seed ${SEED} \
-t ${TOPVOL} \
-f ${FLUX} \
-g $(basename ${GEOMETRY}) \
${UNITS} \
--cross-sections ${GENIEXSEC} \
--tune G18_10a_02_11a \
${EXPOSURE} \
-m $(basename ${MAXPL}) \
--message-thresholds $(basename ${MESTHRE}) 2>&1 | tee stdall_${RUN}.log
#-z $ZMIN \
#======================================================================#



#==============================COPY LOGS===============================#
#ifdh cp -D $IFDH_OPTION stdout_${RUN}.log ${OUTDIR}
#ifdh cp -D $IFDH_OPTION stderr_${RUN}.log ${OUTDIR}
ifdh cp -D $IFDH_OPTION stdall_${RUN}.log ${OUTDIR}
#======================================================================#



#=================================END GRID================================#
echo "Here is the your environment in this job: " > job_output_${CLUSTER}.${PROCESS}.log
env >> job_output_${CLUSTER}.${PROCESS}.log
echo "group = $GROUP"
# If GRID_USER is not set for some reason, try to get it from the proxy
if [ -z ${GRID_USER} ]; then
GRID_USER=`basename $X509_USER_PROXY | cut -d "_" -f 2`
fi
echo "GRID_USER = `echo $GRID_USER`"
export GLIDEIN_ToDie=`condor_config_val GLIDEIN_ToDie`
echo "GLIDEIN_ToDie = $GLIDEIN_ToDie"
# let's try an ldd on ifdh
ldd `which ifdh`
sleeptime=$RANDOM
if [ -z "${sleeptime}" ] ; then sleeptime=4 ; fi
sleeptime=$(( (($sleeptime % 10) + 1)*60 ))
sleep $sleeptime
umask 002
if [ -z "$SCRATCH_DIR" ]; then
    echo "Invalid scratch directory, not copying back."
    echo "I am going to dump the log file to the main job stdout in this case."
    cat job_output_${CLUSTER}.${PROCESS}.log
else
# Very useful for debugging problems with copies
export IFDH_DEBUG=1
export IFDH_CP_MAXRETRIES=2
export IFDH_GRIDFTP_EXTRA="-st 1000"
    # first do lfdh ls to check if directory exists. We put a zero on the end because we only want 
    # to check that the directory exists; we don't care what's in it (i.e recursion depth of 0).
    ifdh ls ${SCRATCH_DIR}/$GRID_USER 0
    # A non-zero exit value probably means it doesn't exist yet, or does not have group write permission, 
    # so send a useful message saying that is probably the issue
    if [ $? -ne 0 ] && [ -z "$IFDH_OPTION" ] ; then 
    echo "Unable to read ${SCRATCH_DIR}/$GRID_USER. Make sure that you have created this directory and given it group write permission (chmod g+w ${SCRATCH_DIR}/$GRID_USER)."
    exit 74
    else
        # directory already exists, so let's copy
#   ifdh cp -D $IFDH_OPTION job_output_${CLUSTER}.${PROCESS}.log ${SCRATCH_DIR}/${GRID_USER}/job_output
    ifdh cp -D $IFDH_OPTION *.root ${OUTDIR}
      if [ $? -ne 0 ]; then
          echo "Error $? when copying to dCache scratch area!"
          echo "If you created ${SCRATCH_DIR}/${GRID_USER} yourself,"
          echo "make sure that it has group write permission."
          echo "Also make sure that you are copying the correct file."
          exit 73
      fi
#    if [ ${RUNBASE} -eq 0 ]; then
#      ifdh cp -D $IFDH_OPTION gntp.${PROCESS}.ghep.root ${SCRATCH_DIR}/${GRID_USER}/genie_output/${RUNBASE}_${CLUSTER}
#      if [ $? -ne 0 ]; then
#          echo "Error $? when copying to dCache scratch area!"
#          echo "If you created ${SCRATCH_DIR}/${GRID_USER} yourself,"
#          echo "make sure that it has group write permission."
#          echo "Also make sure that you are copying the correct file."
#          exit 73
#      fi
#    else
#      ifdh cp -D $IFDH_OPTION gntp.${RUN}.ghep.root ${SCRATCH_DIR}/${GRID_USER}/genie_output/${RUNBASE}_${CLUSTER}
#      if [ $? -ne 0 ]; then
#        echo "Error $? when copying to dCache scratch area!"
#        echo "If you created ${SCRATCH_DIR}/${GRID_USER} yourself,"
#        echo "make sure that it has group write permission."
#        echo "Also make sure that you are copying the correct file."
#        exit 73
#      fi
#    fi
    fi
fi
echo "End `date`"
exit 0
#======================================================================#
