package Object::Declare;

use 5.006;
use strict;
use warnings;

$Object::Declare::VERSION = '0.09';

use Sub::Override;

sub import {
    my $class       = shift;
    my %args        = ((@_ and ref($_[0])) ? (mapping => $_[0]) : @_) or return; 
    my $from        = caller;

    my $mapping     = $args{mapping} or return;
    my $declarator  = $args{declarator} || ['declare'];
    my $copula      = $args{copula}     || ['is', 'are'];

    # Both declarator and copula can contain more than one entries;
    # normalize into an arrayref if we only have on entry.
    $mapping    = [$mapping]    unless ref($mapping);
    $declarator = [$declarator] unless ref($declarator);
    $copula     = [$copula]     unless ref($copula);

    if (ref($mapping) eq 'ARRAY') {
        # rewrite "MyApp::Foo" into simply "foo"
        $mapping = {
            map {
                my $helper = $_;
                $helper =~ s/.*:://;
                (lc($helper) => $_);
            } @$mapping
        };
    }

    # Convert mapping targets into instantiation closures
    if (ref($mapping) eq 'HASH') {
        foreach my $key (keys %$mapping) {
            my $val = $mapping->{$key};
            next if ref($val); # already a callback, don't bother
            $mapping->{$key} = sub { scalar($val->new(@_)) };
        }
    }

    # Install declarator functions into caller's package, remembering
    # the mapping and copula set for this declarator.
    foreach my $sym (@$declarator) {
        no strict 'refs';

        *{"$from\::$sym"} = sub (&) {
            unshift @_, ($mapping, $copula);
            goto &_declare;
        };
    }

    # Establish prototypes (same as "use subs") so Sub::Override can work
    {
        no strict 'refs';
        *{"$from\::$_"}     = \&{"$from\::$_"} for keys %$mapping;
        *{"UNIVERSAL::$_"}  = \&{"UNIVERSAL::$_"} for @$copula;
        *{"$_\::AUTOLOAD"}  = \&{"$_\::AUTOLOAD"} for @$copula;
    }
}

sub _declare {
    my ($mapping, $copula, $code) = @_;
    my $from = caller;

    # Table of collected objects.
    my @objects;

    # Establish a lexical extent for overrided symbols; they will be
    # restored automagically upon scope exit.
    my $override = Sub::Override->new;
    my $replace = sub {
        no strict 'refs';
        no warnings 'redefine';
        my ($sym, $code) = @_;

        # Do the "use subs" predeclaration again before overriding, because
        # Sub::Override cannot handle empty symbol slots.  This is normally
        # redundant (&import already did that), but we do it here anyway to
        # guard against runtime deletion of symbol table entries.
        *$sym = \&$sym;

        # Now replace the symbol for real.
        $override->replace($sym => $code);
    };

    # In DSL (domain-specific language) mode; install AUTOLOAD to handle all
    # unrecognized calls for "foo is 1" (which gets translated to "is->foo(1)",
    # and UNIVERSAL to collect "is foo" (which gets translated to "foo->is".
    # The arguments are rolled into a Katamari structure for later analysis.
    foreach my $sym (@$copula) {
        $replace->("UNIVERSAL::$sym" => \&_universal);
        $replace->("$sym\::AUTOLOAD" => \&_autoload);
    }

    # Now install the collector symbols from class mappings 
    while (my ($sym, $build) = each %$mapping) {
        $replace->("$from\::$sym" => _make_object($build => \@objects));
    }

    # Let's play Katamari!
    &$code;

    # In scalar context, returns hashref; otherwise preserve ordering
    return(wantarray ? @objects : { @objects });
}

# Turn "is some_field" into "some_field is 1"
sub _universal {
    push @_, 1;
    bless(\@_, 'Object::Declare::Katamari');
}

# Handle "some_field is $some_value"
sub _autoload {
    shift;
    my $field = our $AUTOLOAD;
    $field =~ s/.*:://;
    unshift @_, $field;
    bless(\@_, 'Object::Declare::Katamari');
}

# Make a star from the Katamari!
sub _make_object {
    my ($build, $schema) = @_;

    return sub {
        my $name = shift;
        push @$schema, $name => $build->(map { $_->unroll } @_);
    };
}

package Object::Declare::Katamari;

# Unroll a Katamari structure into constructor arguments.
sub unroll {
    my @katamari = @{$_[0]} or return ();
    my $field = shift @katamari or return ();
    my @unrolled;

    unshift @unrolled, pop(@katamari)->unroll
        while ref($katamari[-1]) eq __PACKAGE__; 

    if (@katamari == 1) {
        # single value: "is foo"
        return($field => @katamari, @unrolled);
    }
    else {
        # Multiple values: "are qw( foo bar baz )"
        return($field => \@katamari, @unrolled);
    }
}

1;

__END__

=head1 NAME

Object::Declare - Declarative object constructor

=head1 SYNOPSIS

    use Object::Declare ['MyApp::Column', 'MyApp::Param'];

    my %objects = declare {

    param foo =>
        is immutable,
        valid_values are qw( more values );

    column bar =>
        field1 is 'value',
        field2 is 'some_other_value';

    };

    print $objects{foo}; # a MyApp::Param object
    print $objects{bar}; # a MyApp::Column object

=head1 DESCRIPTION

This module exports one function, C<declare>, for building named
objects with a declarative syntax, similar to how L<Jifty::DBI::Schema>
defines its columns.

In list context, C<declare> returns a list of name/object pairs in the
order of declaration (allowing duplicates), suitable for putting into a hash.
In scalar context, C<declare> returns a hash reference.

Using a flexible C<import> interface, one can change exported helper
functions names (I<declarator>), words to link labels and values together
(I<copula>), and the table of named classes to declare (I<mapping>):

    use Object::Declare
        declarator  => 'declare',       # is the default
        copula      => ['is', 'are'],   # this is the default
        mapping     => {
            column => 'MyApp::Column',  # class name to call ->new to
            param  => sub {             # arbitrary coderef also works
                bless(\@_, 'MyApp::Param');
            },
        };

After the declarator block finishes execution, all helper functions are
removed from the package.  Same-named functions (such as C<&is> and C<&are>)
that existed before the declarator's execution are restored correctly.

=head1 NOTES

If you export the declarator to another package via C<@EXPORT>, be sure 
to export all mapping keys as well.  For example, this will work for the
example above:

    our @EXPORT = qw( declare column param );

But this will not:

    our @EXPORT = qw( declare );

The copula are not turned into functions, so there is no need to export them.

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

=head1 COPYRIGHT (The "MIT" License)

Copyright 2006 by Audrey Tang <cpan@audreyt.org>.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is fur-
nished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FIT-
NESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE X
CONSORTIUM BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
