package Mojolicious::Plugin::Data::Validate::WithYAML;

# ABSTRACT: validate form input with Data::Validate::WithYAML

use strict;
use warnings;

use parent 'Mojolicious::Plugin';

use Carp;
use Data::Validate::WithYAML;
use Mojo::File qw(path);

our $VERSION = 0.06;

sub register {
    my ($self, $app, $config) = @_;

    $config->{conf_path} = $app->home if !$config->{conf_path};
    $config->{no_steps}  = 1          if !defined $config->{no_steps};

    $app->helper( 'validate' => sub {
        my ($c, $file, $step) = @_;

        my $validator = _validator( $file, $config );
        my %params    = %{ $c->req->params->to_hash };
        my @args      = $step ? $step : ();
        my %errors    = $validator->validate( @args, %params );

        my $prefix = exists $config->{error_prefix} ?
            $config->{error_prefix} :
            'ERROR_';

        my %prefixed_errors = map{ ( "$prefix$_" => $errors{$_} ) } keys %errors;

        return %prefixed_errors;
    });

    $app->helper( 'fieldinfo' => sub {
        my ($c, $file, $field, $subinfo) = @_;

        my $validator = _validator( $file, $config );
        my $info      = $validator->fieldinfo( $field );

        return if !$info;

        return $info if !$subinfo;
        return $info->{$subinfo};
    });
}

sub _validator {
    my ($file, $config) = @_;

    if ( !$file ) {
        my @caller = caller(3);
        $file      = (split /::/, $caller[3])[-1];
    }

    my $path = path( $config->{conf_path},  $file . '.yml' )->to_string;

    croak "$path does not exist" if !-e $path;

    my $validator = Data::Validate::WithYAML->new(
        $path,
        %{$config},
    ) or croak $Data::Validate::WithYAML::errstr;

    return $validator;
}

1;

=head1 SYNOPSIS

In your C<startup> method:

  sub startup {
      my $self = shift;
  
      # more Mojolicious stuff
  
      $self->plugin(
          'Data::Validate::WithYAML',
          {
              error_prefix => 'ERROR_',        # optional
              conf_path    => '/opt/app/conf', # path to the dir where all the .ymls are (optional)
          }
      );
  }

In your controller:

  sub register {
      my $self = shift;

      # might be (age => 'You are too young', name => 'name is required')
      # or with error_prefix (ERROR_age => 'You are too young', ERROR_name => 'name is required')
      my %errors = $self->validate( 'registration' );
  
      if ( %errors ) {
         $self->stash( %errors );
         $self->render;
         return; 
      }
  
      # create new user
  }

Your registration.yml

  ---
  age:
    type: required
    message: You are too young
    min: 18
  name:
    type: required
    message: name is required
  password:
    type: required
    plugin: PasswordPolicy
  website:
    type: optional
    plugin: URL
  

=head1 HELPERS

=head2 validate

    my %errors = $controller->validate( $yaml_name );

Validates the parameters. Optional parameter is I<$yaml_name>. If I<$yaml_name> is ommitted, the subroutine name (e.g. "register") is used.

=cut

