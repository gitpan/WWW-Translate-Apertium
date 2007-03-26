#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 19;

use_ok( 'WWW::Translate::Apertium') or exit;

my $engine = WWW::Translate::Apertium->new();

isa_ok( $engine, 'WWW::Translate::Apertium' );

# Language pair tests
is( $engine->from_into(), 'ca-es',
   'Default language pair should be Catalan -> Spanish' );

$engine->from_into( 'es-ca' );
is( $engine->from_into(), 'es-ca',
    'Current language pair should be Spanish -> Catalan' );

$engine->from_into( 'gl-es' );
is( $engine->from_into(), 'gl-es',
    'Current language pair should be Galician -> Spanish' );

$engine->from_into( 'es-gl' );
is( $engine->from_into(), 'es-gl',
    'Current language pair should be Spanish -> Galician' );

$engine->from_into( 'es-pt' );
is( $engine->from_into(), 'es-pt',
    'Current language pair should be Spanish -> Portuguese' );

$engine->from_into( 'pt-es' );
is( $engine->from_into(), 'pt-es',
    'Current language pair should be Portuguese -> Spanish' );

$engine->from_into( 'es-br' );
is( $engine->from_into(), 'es-br',
    'Current language pair should be Spanish -> Brazilian Portuguese' );

$engine->from_into( 'oc-ca' );
is( $engine->from_into(), 'oc-ca',
    'Current language pair should be Aranese -> Catalan' );

$engine->from_into( 'ca-oc' );
is( $engine->from_into(), 'ca-oc',
    'Current language pair should be Catalan -> Aranese' );

$engine->from_into( 'fr-ca' );
is( $engine->from_into(), 'fr-ca',
    'Current language pair should be French -> Catalan' );

$engine->from_into( 'ca-fr' );
is( $engine->from_into(), 'ca-fr',
    'Current language pair should be Catalan -> French' );

$engine->from_into( 'en-ca' );
is( $engine->from_into(), 'en-ca',
    'Current language pair should be English -> Catalan' );

$engine->from_into( 'ca-en' );
is( $engine->from_into(), 'ca-en',
    'Current language pair should be Catalan -> English' );


# Output format tests
is( $engine->output_format, 'plain_text',
    'Default output format should be plain text' );

$engine->output_format('marked_text');
is( $engine->output_format, 'marked_text',
    'Current output format should be marked text' );

# Create object overriding defaults
my $engine2 = WWW::Translate::Apertium->new(
                                            lang_pair => 'pt-es',
                                            output => 'marked_text',
                                           );

is( $engine2->from_into(), 'pt-es',
    'Current language pair should be Portuguese -> Spanish' );
is( $engine2->output_format, 'marked_text',
    'Current output format should be marked text' );
