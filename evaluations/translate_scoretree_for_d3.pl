#!/usr/bin/env perl

=head1 NAME

translate_scoretree_for_d3.pl -- produce a d3.js compatible score tree

=head1 DESCRIPTION

translate_scoretree_for_d3 -- Given the score tree generated by
generate_resource_scores and the components listing, produce a json output fit
for diagraming with d3.js

=head1 SYNOPSIS

./translate_scoretree_for_d3.pl [OPTIONS]

=head1 OPTIONS

=over

=item B<--tree_file>

The file to pull the yaml scoretree from

=item B<--d3_file>

The file to save the json scoretree to

=item B<--components>

File containing the component relationships. Default config/components.yaml

=item B<--verbose>

=back

=head1 EXAMPLES

Translate the nca3 report score

./translate_scoretree_for_d3.pl \
  --tree_file ./nca3_tree.yaml \
  --d3_file ./nca3_tree_d3.json

=cut


use Getopt::Long qw/GetOptions/;
use Pod::Usage qw/pod2usage/;

use Gcis::Exim qw();
use Gcis::Client;
use YAML::XS;
use JSON;
use Data::Dumper;
use FindBin qw( $RealBin );

use strict;
use v5.14;

my $COMPONENTS;
my $components_map = "../config/components.yaml";
GetOptions(
  'tree_file=s'         => \(my $tree_file),
  'd3_file=s'           => \(my $d3_file),
  'components=s'        => \$components_map,
  'verbose!'            => \(my $verbose),
  'help|?'              => sub { pod2usage(verbose => 2) },
) or die pod2usage(verbose => 1);

pod2usage(verbose => 1, message => "$0: tree_file option must be specified") unless $tree_file;
pod2usage(verbose => 1, message => "$0: d3_file option must be specified") unless $d3_file;

# Long running script - confirm our output file will work up front.
{
    if ( open(TEST, ">", $d3_file) ) {
        close TEST;
    } else {
        close Test;
        pod2usage(verbose => 1, message => "$0: d3_file $d3_file can't be opened for writing");
    }
}

&main;

sub main {

    my $greeting = <<END;
Evaluating Provenance
    input file             : $tree_file
    output file            : $d3_file
    components file        : $components_map

END
    say $greeting if $verbose;

    my $score_tree_initial = load_data();

    # Read the tree and produce the json.
    my $score_tree_final = process_subtree($score_tree_initial, 'publication');

    output_to_file( $score_tree_final );
    return;
}

=head1 FUNCTIONS

=cut

=head2 process_subtree

TODO

=cut

sub process_subtree {
    my $tree = shift;
    my $type = shift;

    my $result_tree = [];
    foreach my $key ( keys %$tree ) {
        # get name, type, and score
        my $node = {};
        $node->{name} = $key;
        $node->{type} = $type;
        $node->{score} = $tree->{$key}->{score};
        $node->{children} = get_children($tree->{$key});
        push @$result_tree, $node;
    }

    return $result_tree;
}


=head2 get_children

TODO

=cut

sub get_children {
    my $tree = shift;

    my $children = [];
    # Handle each component type subtree
    foreach my $component_type ( %{$tree->{components}} ) {
        my $childs = process_subtree($tree->{components}->{$component_type}, 'publication');
        push @$children, @$childs;
    }
    # Handle the contributor type subtree
    if ( exists $tree->{connections}->{contributors}
             && $tree->{connections}->{contributors} ) {
        my $childs = process_subtree($tree->{connections}->{contributors}, 'contributor');
        push @$children, @$childs;
    }
    # Handle the reference type subtree
    if ( exists $tree->{connections}->{references}
             && $tree->{connections}->{references} ) {
        my $childs = process_subtree($tree->{connections}->{references}, 'reference');
        push @$children, @$childs;
    }
    # Handle the person type subtree
    if ( exists $tree->{person}
             && $tree->{person}) {
        my $childs = process_subtree($tree->{person}, 'entity');
        push @$children, @$childs;
    }
    # Handle the organization type subtree
    if ( exists $tree->{organization}
             && $tree->{organization}) {
        my $childs = process_subtree($tree->{organization}, 'entity');
        push @$children, @$childs;
    }

    return $children;
}

### UTILITY FUNCTIONS

=head2 output_to_file

Print out the json score tree.

=cut

sub output_to_file {
    my $score_tree = shift;
    my $eval_json = to_json($score_tree);
    open( OUTPUT, ">", $d3_file ) or die $!;
    print OUTPUT $eval_json;
    close OUTPUT;
    say "Score tree written to $d3_file." if $verbose;
    return;
}

=head2 load_rubric_and_components

Load in the YAML rubrics, components.

=cut

sub load_data {

    $COMPONENTS = YAML::XS::LoadFile("$RealBin/$components_map")
        or die "Could not load Components file $RealBin/$components_map";

    my $score_tree_yaml = YAML::XS::LoadFile("$RealBin/$tree_file")
        or die "Could not load Components file $RealBin/$tree_file";

    return $score_tree_yaml;
}

1;

