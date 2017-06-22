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

