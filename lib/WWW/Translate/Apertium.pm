package WWW::Translate::Apertium;

use strict;
use warnings;
use Carp qw(carp);
use WWW::Mechanize;
use Encode;


our $VERSION = '0.02';


my %lang_pairs = (
                    'es-ca' => 'Spanish -> Catalan', # Default
                    'ca-es' => 'Catalan -> Spanish',
                    'es-gl' => 'Spanish -> Galician',
                    'gl-es' => 'Galician -> Spanish',
                    'es-pt' => 'Spanish -> Portuguese',
                    'pt-es' => 'Portuguese -> Spanish',
                    'es-br' => 'Spanish -> Brazilian Portuguese',
                    'oc-ca' => 'Aranese -> Catalan',
                    'ca-oc' => 'Catalan -> Aranese',
                    'fr-ca' => 'French -> Catalan',
                    'ca-fr' => 'Catalan -> French',
                    'en-ca' => 'English -> Catalan',
                    'ca-en' => 'Catalan -> English',
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
    
    $this{agent} = WWW::Mechanize->new();
    $this{agent}->env_proxy();
    $this{url} = 'http://xixona.dlsi.ua.es/prototype/'; 
    
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

    my $mech = $self->{agent};
    
    $mech->get($self->{url});
    unless ($mech->success) {
        carp $mech->response->status_line;
        return undef;
    }
    
    $mech->field("cuadrotexto", $string);
    
    
    if ($self->{output} eq 'marked_text') {
        $mech->tick('marcar', 1);
    }
    
    $mech->select("direccion", $self->{lang_pair});
    
    $mech->click();
    
    my $response = $mech->content();
    
    $response =~ s/\0//gs; # remove null characters
            
    my $translated;
    if (
        $response =~
            /Output:<\/label><div .+?\/>(.+?)\s*<\/fieldset>/s
        ) {
            $translated = $1;
    } else {
        carp "Didn't receive a translation from the Apertium server.\n" .
             "Please check the length of the source text.\n";
        return '';
    }
    
    # remove double spaces
    $translated =~ s/(?<=\S)\s{2}(?=\S)/ /g;
    
    if ($self->{output} eq 'marked_text') {
        # clean HTML tags of unknown words
        $translated =~ s/<span .+?><a href.+?>(\*.+?)<\/a><\/span>/$1/g;
        
        if ($self->{store_unknown}) {
            # store unknown words
            if ($translated =~ /(?:^|\W)\*/) {
            
                my $source_lang = substr($self->{lang_pair}, 0, 2);
                my $utf8 = decode('iso-8859-1', $translated);
                
                while ($utf8 =~ /(?:^|\W)\*(\w+?)\b/g) {
                    my $detected = encode('iso-8859-1', $1);
                    $self->{unknown}->{$source_lang}->{$detected}++;
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
        $self->{lang_pair} = $pair if exists $lang_pairs{$pair};
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
        if ($lang_code =~ /^(?:ca|en|es|fr|gl|oc|pt)$/) {
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


1;

__END__


=head1 NAME

WWW::Translate::Apertium - Open source machine translation


=head1 VERSION

Version 0.02 May 3, 2007


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
    my $es_unknown_href = $engine->get_unknown('oc');

=head1 DESCRIPTION

Apertium is an open source shallow-transfer machine translation engine designed
to translate between related languages, which provides approximate translations
between romance languages. It is being developed by the Department of Software
and Computing Systems at the University of Alicante.
The linguistic data is being developed by research teams from the University of
Alicante, the University of Vigo and the Pompeu Fabra University.
For more details, see L<http://apertium.sourceforge.net/>.

WWW::Translate::Apertium provides an object oriented interface to the Apertium
online machine translation engine.

The language pairs currently supported by Apertium are:

=over 4

=item * Catalan < > Spanish

=item * Galician < > Spanish

=item * Spanish < > Portuguese

=item * Spanish > Brazilian Portuguese

=item * Aranese < > Catalan

=item * Catalan < > French

=back

The Apertium 2.0 architecture includes improvements that support translation
between less related languages:

=over 4

=item * Catalan < > English (experimental)

=back


=head1 CONSTRUCTOR

=head2 new()

Creates and returns a new WWW::Translate::Apertium object.

    my $engine = WWW::Translate::Apertium->new();

WWW::Translate::Apertium recognizes the following parameters:

=over 4

=item * C<< lang_pair >>

The valid values of this parameter are:

=over 8

=item * C<< ca-es >>

Catalan into Spanish (default value).

=item * C<< es-ca >>

Spanish into Catalan.

=item * C<< es-gl >>

Spanish into Galician.

=item * C<< gl-es >>

Galician into Spanish.

=item * C<< es-pt >>

Spanish into Portuguese.

=item * C<< pt-es >>

Portuguese into Spanish.

=item * C<< es-br >>

Spanish into Brazilian Portuguese.

=item * C<< oc-ca >>

Aranese into Catalan.

=item * C<< ca-oc >>

Catalan into Aranese.

=item * C<< fr-ca >>

French into Catalan.

=item * C<< ca-fr >>

Catalan into French.

=item * C<< en-ca >>

English into Catalan.

=item * C<< ca-en >>

Catalan into English.

=back


=item * C<< output >>

The valid values of this parameter are:

=over 8

=item * C<< plain_text >>

Returns the translation as plain text (default value).

=item * C<< marked_text >>

Returns the translation with the unknown words marked with an asterisk.

=back

=item * C<< store_unknown >>

Off by default. If set to a true value, it configures the engine object to store
in a hash the unknown words and their frequencies during the session.
You will be able to access this hash later through the get_unknown method.
If you change the engine language pair in the same session, it will also
create a separate word list for the new source language.

B<IMPORTANT>: If you activate this setting, then you must also set the 
B<output> parameter to I<marked_text>. Otherwise, the get_unknown method will
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

Returns the translation of $string generated by Apertium.
$string must be a string of ANSI text. If the source text isn't encoded as
Latin-1, you must convert it to that encoding before sending it to the machine
translation engine. For this task you can use the Encode module or the PerlIO
layer, if you are reading the text from a file.

In case the server is down, it will show a warning and return C<undef>.


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

The valid values of $lang_code are (in alphabetical order):

=over 8

=item * C<< ca >>

Source language is Catalan.

=item * C<< en >>

Source language is English.

=item * C<< es >>

Source language is Spanish.

=item * C<< fr >>

Source language is French.

=item * C<< gl >>

Source language is Galician.

=item * C<< oc >>

Source language is Aranese.

=item * C<< pt >>

Source language is Portuguese.

=back

=head1 DEPENDENCIES

WWW::Mechanize 1.20 or higher.

=head1 SEE ALSO

WWW::Translate::interNOSTRUM

=head1 REFERENCES

Apertium project website:

L<http://apertium.sourceforge.net/>

=head1 ACKNOWLEDGEMENTS

Many thanks to Mikel Forcada Zubizarreta, coordinator of the Transducens
research team of the Department of Software and Computing Systems at the
University of Alicante, who kindly answered my questions during the development
of this module.


=head1 AUTHOR

Enrique Nell, E<lt>perl_nell@telefonica.netE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Enrique Nell.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut



