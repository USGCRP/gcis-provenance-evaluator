# GCIS Provenance Evaluator
Creating a robust process for evaluating the GCIS project.

## Focus

Communication of the provenance provided for the primary publications in GCIS.  
Primary Publications: [nca3](https://data.globalchange.gov/report/nca3), [Impacts of Climate Change on Human Health](https://data.globalchange.gov/report/usgcrp-climate-human-health-assessment-2016), [Indicators](https://data.globalchange.gov/indicator?current=1), and others.  

## Secondary Objective
Informing decisions on where to direct data mangement work by identifying weak or broken provenance that can be improved

## Requires

### Perl

Perl v5.14 or higher  

### CPAN Modules

These modules are required, install via `cpanm`:  
```
Getopt::Long
Pod::Usage
YAML::XS
Data::Dumper
Clone::PP
Time::HiRes
Path::Class
JSON::XS
Mojo::UserAgent
```

### GCIS Repos

**GCIS Scripts**     : `https://github.com/USGCRP/gcis-scripts/`  
**GCIS Perl Client** : `https://github.com/USGCRP/gcis-pl-client/`

Clone these and add their `lib` directories to your local `PERL5LIB`

## Score Format

TODO

## Component Format

TODO

## Usage

  1. Establish Scores & Configuration
    1. Establish a scoring metric for each GCIS resource
      1. See [example](https://github.com/USGCRP/gcis-provenance-evaluator/blob/master/scores/internal_score.yaml), [format](#score-format)
    1. Establish a scoring metric for each GCIS connection
      1. See [example](https://github.com/USGCRP/gcis-provenance-evaluator/blob/master/scores/connection_score.yaml), [format](#score-format)
    1. Establish the components for each GCIS resource
      1. See [example](https://github.com/USGCRP/gcis-provenance-evaluator/blob/master/config/components.yaml), [format](#component-format)
  1. Generate the score tree
    1. Decide how many levels deep you want to analyse your resource.
    1. Select your GCIS instance to run against (or load the pertinent database dump into a temp instance).
    1. Run the command to generate the tree:
      `./generate_resource_scores.pl --resouce /report/nca3 --tree_file ./nca3_tree.yaml`
  1. Run analysis on the Score Tree
    1. TODO

