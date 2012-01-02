#!/usr/bin/env perl

=head1 NAME

create_question_list.pl - search the pod files for the questions

=head1 DESCRIPTION

Used to create the list in perlfaq.pod

=cut

use strict;
use warnings;

use Path::Class;
use Data::Dumper;
use Template;
use HTML::TreeBuilder;
use Pod::Simple::XHTML;

# constants
my $SOURCE       = './lib';
my $HTML_CHARSET = 'UTF-8';

my $the_questions = get_questions();

my $out_handle = Path::Class::Dir->new($SOURCE)->file('perlfaq.pod')->openw();

my $tt = Template->new( { POST_CHOMP => 1, } );
$tt->process( 'perlfaq.tt', { the_questions => $the_questions }, $out_handle )
    || die $tt->error();

$out_handle->close();

sub get_questions {

    my $out;
    {
        my $source = Path::Class::Dir->new($SOURCE);
        my @files  = sort $source->children;

        foreach my $pod_file (@files) {
            next unless $pod_file->stringify =~ /.pod$/;
            next unless $pod_file->stringify =~ /\d/;

            # next unless $pod_file->stringify =~ /3/;

            my $parser = Pod::Simple::XHTML->new;
            $parser->html_header('');
            $parser->html_footer('');
            $parser->html_charset($HTML_CHARSET);
            my $html = '';
            $parser->output_string( \$html );
            $parser->parse_file( $pod_file->stringify );

            my $root
                = HTML::TreeBuilder->new_from_content($html);    # empty tree
            $root->elementify;

            my @doc  = $root->content_list();
            my @body = $doc[1]->content_list();

            my $html_nodes = scalar(@body);

            my %data;
            my @questions;

            for ( my $i = 0; $i <= $html_nodes; $i++ ) {
                my $h_node = $body[$i] || next;
                my $tag = $h_node->tag;
                next unless $tag =~ /^h/;
                my $text = fetch_text($h_node);

                if ( $tag eq 'h2' ) {

                    # All a bit hacky, but works - patches welcome
                    $text =~ s/</E<lt>/g;
                    $text =~ s/([^lt])>/$1E<gt>/g;
                    $text =~ s/CSTART/C</g;
                    $text =~ s/CEND/>/g;
                    push( @questions, $text );

                } else {
                    $data{$tag}->{$text} = fetch_text( $body[ $i + 1 ] );
                }
            }

            my $name = $data{'h1'}->{'NAME'};
            my $desc = $data{'h1'}->{'DESCRIPTION'};

            $name =~ s/(perlfaq.+) -/L<$1>:/;

            $out .= "=head2 $name\n\n";
            $out .= "$desc\n\n";
            $out .= "=over 4\n\n";

            foreach my $q (@questions) {
                $out .= "=item *\n\n";
                $out .= "$q\n\n";
            }

            $out .= "=back\n\n\n";
        }

    }
    return $out;
}

sub fetch_text {
    my $node = shift || return '';

    my $start = '';
    my $end   = '';
    if ( $node->tag eq 'code' ) {

        # All a bit hacky, but works - patches welcome
        $start = 'CSTART';
        $end   = 'CEND';
    }

    my @nodes = $node->content_list();

    # Wrap CSTART/CEND and recurse down if needed
    my $str
        = $start
        . ( join ' ', map { ref($_) ? fetch_text($_) : $_ } @nodes )
        . $end;
    $str =~ s/\s{2,}/ /g;    # Remove extra spaces
    $str =~ s/\s+$//;        # Remove trailing white spaces
    return $str;
}
