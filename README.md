# GCIS Provenance Evaluator
Creating a robust process for evaluating the GCIS project.

## Focus

Communication of the provenance provided for the primary publications in GCIS.  
Primary Publications: [nca3](https://data.globalchange.gov/report/nca3), [Impacts of Climate Change on Human Health](https://data.globalchange.gov/report/usgcrp-climate-human-health-assessment-2016), [Indicators](https://data.globalchange.gov/indicator?current=1), and others.  

## Secondary Objective
Informing decisions on where to direct data mangement work by identifying weak or broken provenance that can be improved

## Setup

### Perl

Perl v5.14 or higher  

```
apt-get -y update && apt-get -y install perlbrew
perlbrew init
echo "source ~/perl5/perlbrew/etc/bashrc" >>~/.bashrc
source ~/.bashrc
perlbrew install perl-5.20.0 # Takes about 25 minutes!
perlbrew install-cpanm
perlbrew install-patchperl
perlbrew switch perl-5.20.0
```

### CPAN Modules

These modules are required, install via `cpanm`:  

```
cpanm install Getopt::Long Pod::Usage YAML::XS Data::Dumper Clone::PP Time::HiRes Path::Class JSON::XS Mojo::UserAgent
```

If you run into any error that mentions a missing module, install it similarly with: `cpanm install Module::Name`.

### GCIS Repos Setup

Required repos:

**GCIS Scripts**     : `https://github.com/USGCRP/gcis-scripts/`  
**GCIS Perl Client** : `https://github.com/USGCRP/gcis-pl-client/`
**GCIS Provenance Evaluator** : `https://github.com/USGCRP/gcis-pl-client/`

Clone these and add their `lib` directories to your local `PERL5LIB`

Initial Setup:
```
mkdir ~/repos                    # only if you have no existing 'repos' directory
cd ~/repos
ls                               # check 'gcis-scripts' and 'gcis-pl-client' exist
git clone https://github.com/USGCRP/gcis-scripts/
git clone https://github.com/USGCRP/gcis-pl-client/
git clone https://github.com/USGCRP/gcis-provenance-evaluator/
ls                               # should see all three now
echo "export PERL5LIB=$PERL5LIB:~/repos/gcis-pl-client/lib:~/repos/gcis-scripts/lib/" >>~/.bashrc
. ~/.bashrc
```

Refresh the repos if it's been several months!
```
cd ~/repos/gcis-scripts
git pull
cd ~/repos/gcis-pl-client
git pull
cd ~/repos/gcis-provenance-evaluator
git pull
```

See the scripts documentation & examples:
```
cd ~/repos/gcis-provenance-evaluator
perldoc ./generate_resource_scores.pl
```

## Score Format

To Document

## Component Format

To Document

## Project Usage

  1. Establish Scores & Configuration
     1. Establish a scoring metric for each GCIS resource
        1. See [default example](https://github.com/USGCRP/gcis-provenance-evaluator/blob/master/scores/internal_score.yaml), [format](#score-format)
     1. Establish a scoring metric for each GCIS connection
        1. See [default example](https://github.com/USGCRP/gcis-provenance-evaluator/blob/master/scores/connection_score.yaml), [format](#score-format)
     1. Establish the components for each GCIS resource
        1. See [defaut example](https://github.com/USGCRP/gcis-provenance-evaluator/blob/master/config/components.yaml), [format](#component-format)
  1. Generate the score tree
     1. Decide how many levels deep you want to analyse your resource.
     1. Select your GCIS instance to run against (or load the pertinent database dump into a local instance) (default production).
     1. Run the command to generate the tree: See next section.  
       - Name the trees in an informative way and store them somewhere safe!
  1. Run analysis on the Score Tree
     1. TODO

## Generating Scores


**Note 1:** This script is _long running_ on larger chapters! To be safe, you should run it in a screen session on a long-living server to prevent interruptions. For our purposes at USGCRP, I suggest running this script on data-review. 

**Note 2:** This process is likely to generate a multitude of output trees we will want to keep track of. I strongly encourage a strict naming convention: "REPORT_CHAPTER_COMPONENT_SCORING_metrics.yaml".  
So, if you were to run this on the Executive Summary of the NCA3 with the default scores: "nca3_ch1_defaultscoring_metrics.yaml"  
Or to use your custom scoring file "super_strict_scores.yaml" on the CSSR Chapter Temperature Changes in the United States Figure 6.1: "cssr_ch6_fig1_superstrict_metrics.yaml" (and commit that scoring file!)


If you want to use the default scores and configuration, the process is pretty straightforward:

```
screen -DRS "metrics screen"         # creates or reconnects to the screen named "metrics screen"
cd ~/repos/gcis-provenance-evaluator
./generate_resource_scores.pl \
  --resouce /report/nca3/chapter/executive-summary \
  --tree_file ./nca3_ch1_defaultscoring_metrics.yaml```
