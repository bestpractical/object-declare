use strict;
use Test::More tests => 3, import => ['is_deeply'];
use ok 'Object::Declare' => 
    copula => {
        is  => '',
        are => 'plural_',
    },
    mapping => {
        column  => 'MyApp::Column',
        alt_col => sub { return { alt => 1, @_ } }
    };

sub MyApp::Column::new { shift; return { @_ } }

sub do_declare { declare {
    column x =>
        is rw,
        is happy,
        field1 is 'xxx',
        field2 are 'XXX', 'XXX',
        is field3;

    alt_col y =>
        !is happy,
        field1 is 'yyy',
        field2 is 'YYY';
} }

my @objects = do_declare;

is_deeply(\@objects => [
    x => {
            'field1' => 'xxx',
            'plural_field2' => ['XXX', 'XXX'],
            'field3' => 1,
            'rw' => 1,
            'happy' => 1,
            },
    y => {
            'field1' => 'yyy',
            'field2' => 'YYY',
            'alt'    => 1,
            happy    => '',
            },
], 'object declared correctly (list context)');

my $objects = do_declare;

is_deeply($objects => {
    x => {
            'field1' => 'xxx',
            'plural_field2' => ['XXX', 'XXX'],
            'field3' => 1,
            'rw' => 1,
            'happy' => 1,
            },
    y => {
            'field1' => 'yyy',
            'field2' => 'YYY',
            'alt'    => 1,
            happy    => '',
            },
}, 'object declared correctly (scalar context)');

