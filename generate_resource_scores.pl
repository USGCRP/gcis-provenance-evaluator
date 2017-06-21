#!/usr/bin/env perl


=head1 NAME

generate_resource_scores.pl -- generate the score tree for a resource

=head1 DESCRIPTION

generate_resource_scores -- Generate a score tree for a resource such as
a report, or chapters in a report.

This can be a long running script!

=head1 SYNOPSIS

./generate_resource_scores.pl [OPTIONS]

=head1 OPTIONS

=over

=item B<--url>

GCIS url, defaults to http://data.globalchange.gov

=item B<--resource>

GCIS resource, e.g. /report/nca3

=item B<--tree_file>

The file to save the output yaml

=item B<--connection_score>

File containing the Connection item scores. Default scores/connection_score.yaml

=item B<--internal_score>

File containing the Internal item scores. Default scores/internal_score.yaml

=item B<--components>

File containing the component relationships. Default config/components.yaml

=back

=head1 EXAMPLES

Score the nca3 report

./generate_resource_scores.pl --resouce /report/nca3  --tree_file ./nca3_tree.yaml

=cut


use Getopt::Long qw/GetOptions/;
use Pod::Usage qw/pod2usage/;

use Gcis::Client;
use Gcis::Exim;
use YAML::XS;
use Data::Dumper;
use FindBin qw( $RealBin );


use strict;
use v5.14;

# local $YAML::Indent = 2;

my $url = "https://data.globalchange.gov";
my $connection_score = "scores/connection_score.yaml";
my $internal_score = "scores/internal_score.yaml";
my $components_map = "config/components.yaml";
GetOptions(
  'url=s'               => \$url,
  'resource=s'          => \(my $resource_uri),
  'tree_file=s'         => \(my $tree_file),
  'connection_score=s'  => \$connection_score,
  'internal_score=s'    => \$internal_score,
  'components=s'        => \$components_map,
  'verbose!'            => \(my $verbose),
  'help|?'              => sub { pod2usage(verbose => 2) },
) or die pod2usage(verbose => 1);

pod2usage(verbose => 1, message => "$0: Resource option must be specified") unless $resource_uri;
pod2usage(verbose => 1, message => "$0: Tree_file option must be specified") unless $tree_file;

# Long running script - confirm our output file will work up front.
{
    if ( open(TEST, ">", $tree_file) ) {
        close TEST;
    } else {
        close Test;
        pod2usage(verbose => 1, message => "$0: Tree_file $tree_file can't be opened for writing");
    }
}

&main;

sub main {

    say " Evaluating Provenance";
    say "     url                    : $url";
    say "     resource               : $resource_uri";
    say "     output file            : $tree_file";
    say "     internal scores file   : $internal_score";
    say "     connection scores file : $connection_score";
    say "     components file        : $components_map";
    say "";

    my $score_tree;

    my ( $resource_rubric, $component_map ) = load_rubric();

    my $resource = $g->get("$resource_uri") or die " no resource";

    my $resource = $g->get("$resource_uri") or die " no resource";
    if (ref $resource eq 'ARRAY') {
        pod2usage(
            verbose => 1,
            message => "$0: Resource needs a root resource (/report/nca3, /report/nca3/chapter/water-resources) not a sub list (/report/nca3/chapter)."
        );
    }

    my $score_tree = { $resource_uri => score_resource( $g, $resource ) };

    output_to_file( $score_tree );

    say "Score Tree: " . Dumper $score_tree if $verbose;

    say "Score tree written to $tree_file.";
    return;
}

sub score_resource {
    my $g = shift;
    my $resource = shift;
    return {
           score => 4,
           connections => {
               references =>[
                   foo => {
                       score => 4,
                       child_publication => {
                           score => 2,
                       },
                   },
                   bar => {
                       score => 3,
                       child_publication => {
                           score => 2,
                       },
                   },
               ],
               contributors => [
                   5 => {
                       score => 4,
                       component => {
                           score => 2,
                       },
                   },
               ],
           },
           components => {
               figures => [
                   zap => {
                       score => 4,
                       component => {
                           score => 2,
                       },
                   },
               ],
           },
   }
}

sub output_to_file {
    my $score_tree = shift;
    # given a perl hash of a tree, output some yaml file!
    my $eval_yaml = YAML::XS::Dump($score_tree);

    open( OUTPUT, ">", $tree_file ) or die $!;
    print OUTPUT $eval_yaml;
    close OUTPUT;
    return;
}

sub load_rubric {
    my $internal_rubric = YAML::XS::LoadFile("$RealBin/$internal_score") or die "Could not load Internal Score file: $RealBin/$internal_score";
    my $connection_rubric = YAML::XS::LoadFile("$RealBin/$connection_score") or die "Could not load Connection Score file: $RealBin/$connection_score";
    my $component_map = YAML::XS::LoadFile("$RealBin/$components_map") or die "Could not load Components file $RealBin/$components_map";

    my %rubric = ( %$internal_rubric, %$connection_rubric );

    return ( \%rubric, $component_map );
}

1;

