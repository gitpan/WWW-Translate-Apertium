package WWW::Translate::Apertium;

use strict;
use warnings;
use Carp qw(carp);
use LWP::UserAgent;
use URI::Escape;
use Encode;


our $VERSION = '0.09';


my %lang_pairs = (
                    'es-ca'      => 'Spanish -> Catalan', # Default
                    'ca-es'      => 'Catalan -> Spanish',
                    'es-gl'      => 'Spanish -> Galician',
                    'gl-es'      => 'Galician -> Spanish',
                    'es-pt'      => 'Spanish -> Portuguese',
                    'pt-es'      => 'Portuguese -> Spanish',
                    'es-pt_BR'   => 'Spanish -> Brazilian Portuguese',
                    'oc-ca'      => 'Occitan -> Catalan',
                    'ca-oc'      => 'Catalan -> Occitan',
                    'oc_aran-ca' => 'Aranese -> Catalan',
                    'ca-oc_aran' => 'Catalan -> Aranese',
                    'en-ca'      => 'English -> Catalan',
                    'ca-en'      => 'Catalan -> English',
                    'fr-ca'      => 'French -> Catalan',
                    'ca-fr'      => 'Catalan -> French',
                    'fr-es'      => 'French -> Spanish',
                    'es-fr'      => 'Spanish -> French',
                    'ca-eo'      => 'Catalan -> Esperanto',
                    'es-eo'      => 'Spanish -> Esperanto',
                    'ro-es'      => 'Romanian -> Spanish',
                    'es-en'      => 'Spanish -> English',
                    'en-es'      => 'English -> Spanish',
                    'cy-en'      => 'Welsh -> English',
                    'eu-es'      => 'Basque -> Spanish',
                    'en-gl'      => 'English -> Galician',
                    'gl-en'      => 'Galician -> English',
                    
                 );

my %output =     (
                    plain_text => 'txtf',  # default
                    marked_text => 'txt',
                 );

my %defaults =   (
                    lang_pair => 'ca-es',
                    output => 'plain_text',
                    store_unknown => 0,
                 );


sub new {
    my $class = shift;
    
    # validate overrides
    my %overrides = @_;
    foreach (keys %overrides) {
        # check key; warn if illegal
        carp "Unknown parameter: $_\n" unless exists $defaults{$_};
        
        # check value; warn and delete if illegal
        if ($_ eq 'output' && !exists $output{$overrides{output}}) {
            carp _message($_, $overrides{$_});
            delete $overrides{$_};
        }
        if ($_ eq 'lang_pair' && !exists $lang_pairs{$overrides{lang_pair}}) {
            carp _message($_, $overrides{$_});
            delete $overrides{$_};
        }
    }
    
    # replace defaults with overrides
    my %args = (%defaults, %overrides);
    
    # remove invalid parameters
    my @fields = keys %defaults;
    my %this;
    @this{@fields} = @args{@fields};
    
    if ($this{store_unknown}) {
        $this{unknown} = ();
    }
    
    $this{agent} = LWP::UserAgent->new();
    $this{agent}->env_proxy();
    $this{url} = 'http://xixona.dlsi.ua.es/webservice/ws.php';
    
    return bless(\%this, $class);
}


sub translate {
    my $self = shift;
    
    my $string;
    if (@_ > 0) {
        $string = shift;
    } else {
        carp "Nothing to translate\n";
        return '';
    }
    
    return '' if ($string eq '');
    
    $string = _fix_source($string);
    $string = uri_escape($string);

    my $browser = $self->{agent};
    
    
    my $source_lang = substr($self->{lang_pair}, 0, 2);
    my $target_lang = substr($self->{lang_pair}, 3, 2);
    
    my $url = "$self->{url}?mode=$self->{lang_pair}&format=txt&text=$string";
    
    if ($self->{output} eq 'marked_text') {
        $url .= "&mark=1";
    } else {
        $url .= "&mark=0";
    }
    
    my $response = $browser->get($url);
    
    unless ($response->is_success) {
        carp $response->status_line;
        return undef;
    }
    
    
    if (!defined $response) {
        carp "Didn't receive a translation from the Apertium server.\n" .
             "Please check the length of the source text.\n";
        return '';
    }
    
    my $translated = _fix_translated($response->{'_content'});
    
    $translated = decode_utf8($translated);
    
    if ($self->{output} eq 'marked_text') {
        
        if ($self->{store_unknown}) {
            
            # store unknown words
            if ($translated =~ /(?:^|\W)\*/) {
                
                while ($translated =~ /(?:^|\W)\*(\w+?)\b/g) {
                    $self->{unknown}->{$source_lang}->{$1}++;
                }
            }
        }
    }
    
    return $translated;
}

sub from_into {
    my $self = shift;
    
    
    if (@_) {
        my $pair = shift;
        if (!exists $lang_pairs{$pair}) {
            carp _message('lang_pair', $self->{lang_pair});
            $self->{lang_pair} = $defaults{'lang_pair'};
        } else {
            $self->{lang_pair} = $pair if exists $lang_pairs{$pair};
        }
    } else {
        return $self->{lang_pair};
    }
}

sub output_format {
    my $self = shift;
    
    if (@_) {
        my $format = shift;
        $self->{output} = $format if exists $output{$format};
    } else {
        return $self->{output};
    }
}

sub get_unknown {
    my $self = shift;
    
    if (@_ && $self->{store_unknown}) {
        my $lang_code = shift;
        if ($lang_code =~ /^(?:ca|cy|en|es|eu|fr|gl|oc|oc_aran|pt|ro)$/) {
            return $self->{unknown}->{$lang_code};
        } else {
            carp "Invalid language code\n";
        }
    } else {
        carp "I'm not configured to store unknown words\n";
    }
}

sub get_pairs {
    my $self = shift;
    
    return %lang_pairs;
}

sub _message {
    my ($key, $value) = @_;
    
    my $string = "Invalid value for parameter $key, $value.\n" .
                 "Will use the default value instead.\n";
                 
    return $string;
}

sub _fix_source {
    my ($string) = @_;
    
    # fix geminated l; replace . by chr(183) = hex B7
    $string =~ s/l\.l/l\xB7l/g;
    
    return $string;
}

sub _fix_translated {
    my ($string) = @_;
    
    # remove double spaces
    $string =~ s/(?<=\S)\s{2}(?=\S)/ /g;
    
    return $string;
}


1;


1;

__END__


=head1 NAME

WWW::Translate::Apertium - Open source machine translation


=head1 VERSION

Version 0.09 December 14, 2008


=head1 SYNOPSIS

    use WWW::Translate::Apertium;
    
    my $engine = WWW::Translate::Apertium->new();
    
    my $translated_string = $engine->translate($string);
    
    # default language pair is Catalan -> Spanish
    # change to Spanish -> Galician:
    $engine->from_into('es-gl');
    
    # check current language pair:
    my $current_langpair = $engine->from_into();
    
    # get available language pairs:
    my %pairs = $engine->get_pairs();
    
    # default output format is 'plain_text'
    # change to 'marked_text':
    $engine->output_format('marked_text');
    
    # check current output format:
    my $current_format = $engine->output_format();
    
    # configure a new Apertium object to store unknown words:
    my $engine = WWW::Translate::Apertium->new(
                                                output => 'marked_text',
                                                store_unknown => 1,
                                              );
    
    # get unknown words for source language = Aranese
    my $es_unknown_href = $engine->get_unknown('oc_aran');

=head1 DESCRIPTION

Apertium is an open source shallow-transfer machine translation engine designed
to translate between related languages (and less related languages). It is being
developed by the Department of Software and Computing Systems at the University
of Alicante. The linguistic data is being developed by research teams from the
University of Alicante, the University of Vigo and the Pompeu Fabra University.
For more details, see L<http://www.apertium.org/>.

WWW::Translate::Apertium provides an object oriented interface to the Apertium
online machine translation web service, based on Apertium 3.0.

Currently, Apertium supports the following language pairs:

- Bidirectional

=over 4

=item * Spanish  < >  Catalan

=item * Spanish  < >  Galician

=item * Galician < >  Spanish

=item * Spanish  < >  Portuguese

=item * Occitan  < >  Catalan

=item * Aranese  < >  Catalan

=item * English  < >  Catalan

=item * French   < >  Catalan

=item * French   < >  Spanish

=item * Spanish  < >  English

=item * English  < >  Galician

=back


- Single Direction

=over 4

=item * Spanish   >   Brazilian Portuguese

=item * Catalan   >   Esperanto

=item * Spanish   >   Esperanto

=item * Romanian  >   Spanish

=item * Welsh     >   English

=item * Basque    >   Spanish

=back


B<NOTE>: The underlying translation retrieval method changed in version 0.06.
The current module is based on the Apertium web service, which serves the
translations faster than the previous web scraping approach.

Summary of changes since version 0.05 that may have an impact on legacy code:

- This module expects UTF-8 text and returns UTF-8 text. You can also send
text encoded in Latin-1, but the support for Latin-1 will be phased out soon.

- Some language codes have changed: The code for Brazilian Portuguese
is now B<pt_BR> and the code for Aranese is B<oc_aran> (used to be B<oc>, which
is now the language code for Occitan).



=head1 CONSTRUCTOR

=head2 new()

Creates and returns a new WWW::Translate::Apertium object.

    my $engine = WWW::Translate::Apertium->new();

WWW::Translate::Apertium recognizes the following parameters:

=over 4

=item * C<< lang_pair >>

The valid values of this parameter are:

=over 8

=item * C<< es-ca >> -- Spanish into Catalan

=item * C<< ca-es >> -- Catalan into Spanish

=item * C<< es-gl >> -- Spanish into Galician

=item * C<< gl-es >> -- Galician into Spanish

=item * C<< es-pt >> -- Spanish into Portuguese

=item * C<< pt-es >> -- Portuguese into Spanish

=item * C<< es-pt_BR >> -- Spanish into Brazilian Portuguese

=item * C<< oc-ca >> -- Occitan into Catalan

=item * C<< ca-oc >> -- Catalan into Occitan

=item * C<< oc_aran-ca >> -- Aranese into Catalan

=item * C<< ca-oc_aran >> -- Catalan into Aranese

=item * C<< en-ca >> -- English into Catalan

=item * C<< ca-en >> -- Catalan into English

=item * C<< fr-ca >> -- French into Catalan

=item * C<< ca-fr >> -- Catalan into French

=item * C<< fr-es >> -- French into Spanish

=item * C<< es-fr >> -- Spanish into French

=item * C<< ca-eo >> -- Catalan into Esperanto

=item * C<< es-eo >> -- Spanish into Esperanto

=item * C<< ro-es >> -- Romanian into Spanish

=item * C<< es-en >> -- Spanish into English

=item * C<< en-es >> -- English into Spanish

=item * C<< cy-en >> -- Welsh into English

=item * C<< eu-es >> -- Basque into Spanish

=item * C<< en-gl >> -- English into Galician

=item * C<< gl-en >> -- Galician into English

=back

These language pairs are stable versions. Other language pairs are currently
under development.

=item * C<< output >>

The valid values of this parameter are:

=over 8

=item * C<< plain_text >>

Returns the translation as plain text (default value).

=item * C<< marked_text >>

Returns the translation with the unknown words marked with an asterisk.

B<Warning>: This feature is always on in the current version of the Catalan < > French
language pair due to a bug in the stable package for these languages. It will be
fixed in the next release.

=back

=item * C<< store_unknown >>

Off by default. If set to a true value, it configures the engine object to store
in a hash the unknown words and their frequencies during the session.
You will be able to access this hash later through the B<get_unknown> method.
If you change the engine language pair in the same session, it will also
create a separate word list for the new source language.

B<IMPORTANT>: If you activate this setting, then you must also set the 
B<output> parameter to I<marked_text>. Otherwise, the B<get_unknown> method will
return an empty hash.

=back


The default parameter values can be overridden when creating a new
Apertium engine object:

    my %options = (
                    lang_pair => 'es-ca',
                    output => 'marked_text',
                    store_unknown => 1,
                  );

    my $engine = WWW::Translate::Apertium->new(%options);

=head1 METHODS

=head2 $engine->translate($string)

Returns the translation of $string generated by Apertium, encoded as UTF-8.
In case the server is down, the C<translate> method will show a warning and
return C<undef>.

The input $string must be an UTF-8 encoded string (for this task you can use
the Encode module or the PerlIO layer, if you are reading the text from a file).

If you are going to translate a string literal included in the code and then
display the result in the output window of the code editor, then you should add
the following statement to your code in order to avoid a "Wide character in
print" warning:

    binmode(STDOUT, ':utf8');


=head2 $engine->from_into($lang_pair)

Changes the engine language pair to $lang_pair.
When called with no argument, it returns the value of the current engine
language pair.

=head2 $engine->get_pairs()

Returns a hash containing the available language pairs.
The hash keys are the language codes, and the values are the corresponding
language names.

=head2 $engine->output_format($format)

Changes the engine output format to $format.
When called with no argument, it returns the value of the current engine
output format.

=head2 $engine->get_unknown($lang_code)

If the engine was configured to store unknown words, it returns a reference to
a hash containing the unknown words (keys) detected during the current machine
translation session for the specified source language, along with their
frequencies (values).

The valid values of $lang_code for the source language are (in alphabetical order):

=over 8

=item * C<< ca >>  --  Catalan

=item * C<< cy >>  --  Welsh

=item * C<< en >>  --  English

=item * C<< es >>  --  Spanish

=item * C<< eu >>  --  Basque

=item * C<< fr >>  --  French

=item * C<< gl >>  --  Galician

=item * C<< oc >>  --  Occitan

=item * C<< oc_aran >>  --  Aranese

=item * C<< pt >>  --  Portuguese

=item * C<< ro >>  --  Romanian

=back

=head1 DEPENDENCIES

LWP::UserAgent

URI::Escape

=head1 SEE ALSO

WWW::Translate::interNOSTRUM

=head1 REFERENCES

Apertium project website:

L<http://www.apertium.org/>

If you want to get I<the real thing>, you can download the Apertium code and
build it on your local machine. You will find detailed setup instructions in
the Apertium wiki:

L<http://wiki.apertium.org/wiki/Installation>

=head1 ACKNOWLEDGEMENTS

Many thanks to Mikel Forcada Zubizarreta, coordinator of the Transducens
research team of the Department of Software and Computing Systems at the
University of Alicante, who kindly answered my questions during the development
of this module, and to Xavier Noria and Jo�o Albuquerque for useful suggestions.
The author is also grateful to Francis Tyers, a member of the Apertium team,
who provided essential feedback for the latest versions of this module.


=head1 AUTHOR

Enrique Nell, E<lt>perl_nell@telefonica.netE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007-2008 by Enrique Nell, all rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut



