#!/usr/bin/perl

use Getopt::Long;

#------------------------
#$prodSpace=$ENV{"HOME"}."/work";
$prodSpace="/uscms_data/d3/".$ENV{"USER"};
$batch=10;
$startPoint=0;
$nosubmit='';
$use_xrootd=''; # '' is false in perl


#$executable=$ENV{"HOME"}."/bin/batch_cmsRun";
$executable=$ENV{"HOME"}."/nobackup/run_Analyzer_condor.sh";
$rt=$ENV{"LOCALRT"};
$arch=$ENV{"SCRAM_ARCH"};

$jobBase="default";

print "$executable\n";

GetOptions(
    "batch=i" => \$batch,
    "start=i" => \$startPoint,
    "nosubmit" => \$nosubmit,
    "prodspace=s" => \$prodSpace,
    "jobname=s" => \$jobBase,
    "xrootd" => \$use_xrootd,
    "nice" => \$nice_user
);

print "$#ARGV\n";
$nargs = $#ARGV;

#if ($#ARGV!=3 && $#ARGV!=6) {
#    print "Usage: [BASE CONFIG] [NAME OF FILE CONTAINING LIST OF FILENAMES] [isMC=True/False] [runRandomTrack=True/False] [runLocally=True/False] [isSig=True/False] [hasDpho=True/False]\n\n";
#    print "    --batch (number of files per jobs) (default $batch)\n";
#    print "    --start (output file number for first job) (default $startPoint)\n";
#    print "    --jobname (name of the job) (default based on base config)\n";
#    print "    --prodSpace (production space) (default $prodSpace)\n";
#    print "    --nosubmit (don't actually submit, just make files)\n";
#    print "    --xrootd (use xrootd for file access)\n";
#    print "    --nice (set nice_user=true)\n";
#    exit(1);
#}

$basecfg=shift @ARGV;
$filelist=shift @ARGV;
$cmsRunArguments=shift @ARGV;
for(my $i = 0; $i <= $nargs-3; $i++)
{  
   $nextArg=shift @ARGV;
   $cmsRunArguments=$cmsRunArguments." ".$nextArg;    
}
print "cmsRun Arguments: $cmsRunArguments\n";

if ($jobBase eq "default") {
    my $stub3=$basecfg;
    $stub3=~s|.*/||g;
    $stub3=~s|_cfg.py||;
    $stub3=~s|[.]py||;
    $jobBase=$stub3;
}


if (length($rt)<2) {
    print "You must run \"cmsenv\" in the right release area\n";
    print "before running this script!\n";
    exit(1);
}

if ($use_xrootd) {
    # Try to find the user's proxy file
    open(VOMSY,"voms-proxy-info|");
    while (<VOMSY>) {
        if (/path\s+:\s+(\S+)/) {
            $voms_proxy=$1;
        }
    }
    close(VOMSY);
}
#------------------------

print "Setting up a job based on $basecfg into $jobBase using $filelist\n";
if ($nosubmit) {
    print "  Will not actually submit this job\n";
}

$cfg=$basecfg;

system("mkdir -p $prodSpace/$jobBase");
system("mkdir -p $prodSpace/logs");
system("cd $ENV{CMSSW_BASE}; cd ../; tar czf $ENV{CMSSW_VERSION}.tgz $ENV{CMSSW_VERSION}; xrdcp -f $ENV{CMSSW_VERSION}.tgz root://cmseos.fnal.gov//store/user/revering/$ENV{CMSSW_VERSION}.tgz; rm $ENV{CMSSW_VERSION}.tgz");
mkdir("$prodSpace/$jobBase/cfg");
mkdir("$prodSpace/$jobBase/log");

$linearn=0;

srand(); # make sure rand is ready to go
if ($nosubmit) {
    open(SUBMIT,">condor_submit.txt");
} else {
    open(SUBMIT,"|condor_submit");
}
print(SUBMIT "Executable = $executable\n");
print(SUBMIT "Arguments = \"$cmsRunArguments\"\n");
print(SUBMIT "Universe = vanilla\n");
print(SUBMIT "Transfer_Input_Files = Cert_314472-325175_13TeV_Legacy2018_Collisions18_JSON.txt\n");
print(SUBMIT "Should_Transfer_Files = YES\n");
print(SUBMIT "WhenToTransferOutput = ON_EXIT\n");
print(SUBMIT "Transfer_Output_Files = \"\"\n");
print(SUBMIT "x509userproxy = $ENV{X509_USER_PROXY}\n\n");
print(SUBMIT "request_memory = 2G\n");
print(SUBMIT "Requirements = (Arch==\"X86_64\")\n");

if ($nice_user) {
    print(SUBMIT "nice_user = True\n");
}

open(FLIST,$filelist);
while (<FLIST>) {
    chomp;
    push @flist,$_;
}
close(FLIST);

$i=0;
$ii=$startPoint-1;

while ($i<=$#flist) {
    $ii++;

    @jobf=();
    for ($j=0; $j<$batch && $i<=$#flist; $j++) {
        push @jobf,$flist[$i];
        $i++;
    }
    
    $jobCfg=specializeCfg($cfg,$ii,@jobf); 
    
    $stub=$jobBase.sprintf("_%03d",$ii);

    $log="$prodSpace/$jobBase/log/$stub.log";
    $elog="$prodSpace/$jobBase/log/$stub.err";
    $sleep=(($ii*2) % 60)+2;  # Never sleep more than a ~minute, but always sleep at least 2
    print(SUBMIT "Arguments = $ENV{CMSSW_VERSION} $jobBase $jobCfg $fname $cmsRunArguments\n");
    print(SUBMIT "Output = $prodSpace/$jobBase/log/$stub.out\n");
    print(SUBMIT "Error = $elog\n");
    print(SUBMIT "Log = $log\n");
    print(SUBMIT "Queue\n");
}

close(SUBMIT);

sub specializeCfg($$@) {
    my ($inp, $index, @files)=@_;

    $stub2=$jobBase;
    $stub2.=sprintf("_%03d",$index); 
    $mycfg="$prodSpace/$jobBase/cfg/".$stub2."_cfg.py"; 
    print "   $inp $index --> $stub2 ($mycfg) \n";
    open(INP,$inp);
    open(OUTP,">$mycfg");
    $sector=0;
    $had2=0;
    $had3=0;
    while(<INP>) {
        if (/TFileService/) { 
            $sector=2;
            $had2=1; 
        } 
        if (/PoolOutputModule/) {
            $sector=3;  
            $had3=1;
        } 
        if (/[.]Source/) {
            $sector=1;
        }
        if (/rivetAnalyzer[.]OutputFile/) {
            $sector=4;
        }
        if ($sector==2 && /^[^\#]*fileName\s*=/) {
            if ($had3==1) {
                $fname="$prodSpace/$jobBase/".$stub2."-hist.root";
            } else { 
                $fname=$stub2.".root";
            }
            unlink($fname);
            print OUTP "       fileName = cms.string(\"$fname\"),\n";
        } elsif ($sector==3 && /^[^\#]*fileName\s*=/) {
            if ($had2==1) {
                $fname="$prodSpace/$jobBase/".$stub2."-pool.root";
            } else {
                $fname=$stub2.".root";
            }
            unlink($fname);
            print OUTP "       fileName = cms.untracked.string(\"$fname\"),\n";
        } elsif ($sector==4 && /^[^\#]*rivetAnalyzer[.]OutputFile\s*=/) {
                $fname="$prodSpace/$jobBase/".$stub2.".yoda";
            unlink($fname); 
            print OUTP "process.rivetAnalyzer.OutputFile = cms.string(\"$fname\")\n";
        } elsif ($sector==1 && /^[^\#]*fileNames\s*=/) {
            print OUTP "    fileNames=cms.untracked.vstring(\n";
            for ($qq=0; $qq<=$#files; $qq++) {
                $storefile=$files[$qq];
                if ($storefile=~/store/) { 
                    if ($use_xrootd) {
                        $storefile=~s|.*/store|root://cmsxrootd.fnal.gov//store|;
                    } else {
                        $storefile=~s|.*/store|/store|;
                    } 
                } else { 
                    $storefile="file:".$storefile; 
                } 
                print OUTP "         '".$storefile."'";
                print OUTP "," if ($qq!=$#files);
                print OUTP "\n";
            }
            print OUTP "     )\n";
        } else { 
            print OUTP;
        }
        $depth++ if (/\{/ && $sector!=0);
        if (/\}/ && $sector!=0) {
            $depth--; 
            $sector=0 if ($depth==0);
        }
    }
    system("xrdcp -f $mycfg root://cmseos.fnal.gov//store/user/revering/$jobBase/cfg/${stub2}_cfg.py");

    $mycfg=$stub2."_cfg.py"; 

    close(OUTP);
    close(INP); 
    return $mycfg; 
}
