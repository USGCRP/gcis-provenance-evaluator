#!/usr/bin/env perl

=head1 NAME

score_across_type.pl -- generate scores for resource groups

=head1 DESCRIPTION

score_across_type -- Traverse a score tree as generated by 
generate_resource_scores.pl and crete the mean, median, min,
max, and count for each type of object in the tree.

=head1 SYNOPSIS

./score_across_type.pl [OPTIONS]

=head1 OPTIONS

=over

=item B<--tree_file>

The file to save the output yaml

=back

=head1 EXAMPLES

./score_across_type.pl \
  --tree_file nca4_butterfly_depth1.yaml

=cut


use Getopt::Long qw/GetOptions/;
use Pod::Usage qw/pod2usage/;

use Gcis::Exim qw();
use Gcis::Client;
use YAML::XS;
use Data::Dumper;
use FindBin qw( $RealBin );
use List::Util qw< min max >;
use Statistics::Basic qw(:all);


use strict;
use v5.14;

# local $YAML::Indent = 2;

GetOptions(
  'tree_file=s'         => \(my $tree_file),
  'help|?'              => sub { pod2usage(verbose => 2) },
) or die pod2usage(verbose => 1);

pod2usage(verbose => 1, message => "$0: Tree_file option must be specified") unless $tree_file;

my $scores_by_thing;
my $score_output;

&main;

sub main {

    my $all_scores = load_score_tree($tree_file);

    collect_scores($all_scores);

    calculate_collective_scores();

    #say Dumper $scores_by_thing;
    say Dumper $score_output;
    return;
}

=head1 FUNCTIONS

=cut

=head2 load_score_tree

Load in the YAML score tree

=cut

sub load_score_tree {
    my $score_tree_file = shift;

    my $scores = YAML::XS::LoadFile("$RealBin/$score_tree_file")
        or die "Could not load Score file: $RealBin/$score_tree_file: $!";

    return $scores;
}

=head2 collect_scores

Walk through the tree and collect each component type scores.

=cut

sub collect_scores {
    my $scores_tree = shift;

    for my $key ( keys %$scores_tree ) {
        process_node(
            type   => 'main',
            node   => $scores_tree->{$key},
        );
    }
}

sub process_node {
    my (%args) = @_;
    my $type            = $args{type};
    my $tree            = $args{node};

    push @{$scores_by_thing->{$type}}, $tree->{score};

    for my $component_type ( keys %{ $tree->{components} } ) {
        foreach my $component ( keys %{ $tree->{components}->{$component_type} } ) {
            process_node(
                type   => $component_type,
                node   => $tree->{components}->{$component_type}->{$component},
            );
        }
    }

    for my $connection_type ( keys %{ $tree->{connections} } ) {
        foreach my $connection ( keys %{ $tree->{connections}->{$connection_type} } ) {
            process_node(
                type   => $connection_type,
                node   => $tree->{connections}->{$connection_type}->{$connection},
            );
        }
    }
}

=head2 calculate_collective_scores

=cut

sub calculate_collective_scores {
    foreach my $type (keys %$scores_by_thing) {
        $score_output->{$type}->{'mean'}   = mean($scores_by_thing->{$type})->query;
        $score_output->{$type}->{'median'} = median($scores_by_thing->{$type})->query;
        $score_output->{$type}->{'mode'}   = mode($scores_by_thing->{$type})->query;
        $score_output->{$type}->{'min'}    = min @{ $scores_by_thing->{$type} };
        $score_output->{$type}->{'max'}    = max @{$scores_by_thing->{$type}};
        $score_output->{$type}->{'count'}  = calculate_count_each($scores_by_thing->{$type});
    }
}

sub calculate_count_each {
    my $score_array = shift;

    my $count = {
        1 => 0,
        2 => 0,
        3 => 0,
        4 => 0,
        5 => 0,
    };

    foreach my $score ( @$score_array ) {
        $count->{$score}++
    }

    return $count;
}
