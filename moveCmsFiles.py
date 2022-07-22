#!/user/bin/env python

import argparse
import shutil
import os

parser = argparse.ArgumentParser(description="Move input files to /export/scratch")
parser.add_argument("configFile", help="cms config file")
parser.add_argument("originalDir", help="original base directory where input files are located")
parser.add_argument("--delete", dest="delete", action='store_true', default=False)

arg = parser.parse_args()

cfg = arg.configFile
cfgfile = open(cfg,"r")
lines = cfgfile.readlines()
blockFname=False
baseDir = cfg.split("_cfg")[0].split("/")[-1]

originalDir = arg.originalDir
if originalDir.endswith('/'):
   originalDir=originalDir[:-1]

if not arg.delete:
  for line in lines:
    if blockFname:
      if ")" in line:
        blockFname=False
      else:
        fname = line.split(":")[-1].split("'")[0]
        if originalDir != "none":
           originalfname = originalDir+fname.split(baseDir)[-1]
        else:
           originalfname = "/local/cms/user"+fname.split("users")[-1].split("/"+baseDir)[0]+fname.split(baseDir)[-1]
        basename=fname.split("/")[-1]
        if not os.path.isdir(fname.split(basename)[0]):
          os.makedirs(fname.split(basename)[0])
        shutil.copyfile(originalfname,fname)
    if "fileNames" in line and "#" not in line:
       blockFname = True
else:
  for line in lines:
    if blockFname:
      if ")" in line:
        blockFname=False
      else:
        fname = line.split(":")[-1].split("'")[0]
        dirname = fname.split(baseDir)[0]+baseDir
        shutil.rmtree(dirname)
        break
    if "fileNames" in line and "#" not in line:
       blockFname = True

