# condor_scripts
A few different scripts used to generate condor_submit and CMSSW configurations for submitting CMSSW jobs to condor clusters. 
Example usage:

```
perl condor_filelist.perl python/ConfFile_MyCmsConfif_cfg.py datafiles/ListOfFiles.txt {CMS run options} --prodSpace /local/cms/user/{username}/jobName --batch 10 --jobname JobName
```

You must run cmsenv (in your desired CMSSW distribution!) before calling condor_filelist.perl. condor_filelist will then group the files in your input file list into batches based on the batch size, and 
generate cfg files for each job in prodSpace/jobName/cfg. Upon submission to condor, batch_cmsRun (which expects to be moved to ~/bin/batch_cmsRun) will be called for each job to set up the environment and run cmssw.

There are three versions currently in this repository:

condor_filelist.perl:

This version is set up for running on the newer cluster, and uses the built-in file transferring utilities of condor to move the input files. In addition, each job generates a new executable 
named after the job name which calls batch_cmsRun from within a slc7 cmssw singularity container. 

condor_filelist_copyinputs.perl:

This version is for use with the 'current' cluster, where inputs must be manually copied to /export/scratch/ when running a job. condor_filelist_copyinputs has two additional inputs:

--user
and 
--originalDir

--user must be defined if the files you are copying from /local/ don't have your username in them (my default is rever025 but my files are under /revering/. batch_cmsRun needs to reverse-engineer what the filenames are, so I had to put this in).

--originalDir can be defined alternately to --user, and lets you explicitly tell condor_filelist where the base directory of the input files are when it copies them over. (i.e. I ran on some of big Mike's files, and needed to use --originalDir=/local/cms/user/krohn045/). 
condor_filelist will then re-create the filetrees which come after originalDir in /export/scratch/users/{username}/ and use originalDir to convert the relative paths in the cfg files to their original paths.

condor_filelist_lpc.perl:

This version is for running on the lpc, where there is not a shared filesystem accessible from the condor nodes. To get around this, condor_filelist makes a tar file of your cmssw folder and puts it on eos (Actually my eos space. Need to change the code to yours if you want to use it...). Each job then uses xrootd to download and extract this file before running.
