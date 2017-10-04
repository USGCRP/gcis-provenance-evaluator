#!/usr/bin/env perl

=head1 NAME



=head1 DESCRIPTION


=head1 SYNOPSIS


=head1 EXAMPLES

=cut

use utf8;
use v5.20;

use Data::Dumper;
use Try::Tiny;
use JSON::XS;

my $json_file = shift;

my $json;
{
    local $/; #Enable 'slurp' mode
    open my $fh, "<", "$json_file";
    $json = <$fh>;
    close $fh;
}
my $input = JSON::XS->new->decode($json);

my $max_count = {
    reference => 5,
    contributor => 8,
    publication => 20,
    entity => 4,
};

my (@nodes, @links);

sub parse_nodes_links {
    my $hash = shift;

    #say "Touching $hash->{name}";
    push @nodes, { "id" => $hash->{"name"}, "type" => $hash->{type}, "score" => $hash->{score} };
    my $children_names;
    if ( $hash->{children} ) {
        my $index = 0;
        my $type_count;
        foreach my $child ( @{ $hash->{children} } ) {
            next if $type_count->{$child->{type}} >= $max_count->{$child->{type}};
            my $child_name = parse_nodes_links( $child );
            push @$children_names, $child_name;
            $type_count->{$child->{type}}++;
        }
    }

    foreach my $child_name ( @$children_names ) {
        push @links, { "source" => $hash->{"name"}, "target" => $child_name };
    }

    return $hash->{name};
}

parse_nodes_links($input);

my $uniq_nodes;
my @nodes_uniq;
foreach my $entry ( @nodes ) {
    next if exists $uniq_nodes->{ $entry->{id} };
    push @nodes_uniq, $entry;
    $uniq_nodes->{$entry->{id}} = 1;
}
my $uniq_links;
my @links_uniq;
foreach my $entry ( @links ) {
    my $id = $entry->{target} . $entry->{source};
    next if exists $uniq_links->{ $id };
    push @links_uniq, $entry;
    $uniq_links->{$id} = 1;
}
my $output = { "nodes" => \@nodes_uniq, "links" => \@links_uniq };
my $out_json = JSON::XS->new->encode($output);

say $out_json;
