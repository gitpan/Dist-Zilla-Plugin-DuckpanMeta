package Dist::Zilla::Plugin::DuckpanMeta;
BEGIN {
  $Dist::Zilla::Plugin::DuckpanMeta::AUTHORITY = 'cpan:GETTY';
}
{
  $Dist::Zilla::Plugin::DuckpanMeta::VERSION = '0.002';
}
# ABSTRACT: DistZilla plugin for gathering DuckPAN related (so far only DDG related) meta information

use Moose;
use Moose::Autobox;
with 'Dist::Zilla::Role::FileGatherer';

use namespace::autoclean;

use Dist::Zilla::File::FromCode;
use JSON::MaybeXS;
use Class::Load ':all';
use Carp qw( croak );

### EVIL WORKAROUND
use File::Spec;
my $lib;
BEGIN { $lib = File::Spec->catdir( File::Spec->curdir(), 'lib' ); }
use lib "$lib";
#Carp::carp("[Bootstrap::lib] $lib added to \@INC");
##################################################################

sub gather_files {
	my ($self, $arg) = @_;

	my $zilla = $self->zilla;

	my $file = Dist::Zilla::File::FromCode->new({
		name => 'duckpan.json',
		code => sub {
			encode_json({
				@{$zilla->files->map(sub {
					my $file = $_;
					return unless (split('/',$file->name))[0] eq 'lib';
					my $class = $file->name;
					$class =~ s!^lib/!!g;
					my $file_without_lib = $class;
					$class =~ s!\.pm$!!g;
					$class =~ s!/!::!g;
					my %data;
					eval {
						try_load_class($class) unless is_class_loaded($class);
						if (!defined $INC{$file_without_lib}) {
							warn "Class ".$class." failed to load!";
						} elsif ($INC{$file_without_lib} ne $file->name) {
							warn "Class ".$class." already loaded from another location, can't parse it.";
						} else {
							if ($class->can('does')) {
								if ($class->does('DDG::HasAttribution')) {
									$data{ddg_meta} = $class->get_meta_information;
									my @attributions = @{$class->get_attributions};
									if (@attributions) {
										$data{ddg_meta}->{attributions} = \@attributions;
									}
								}
								if ($class->does('DDG::Block::Blockable')) {
									$data{ddg_block} = {
										triggers_block_type => $class->triggers_block_type,
										has_triggers => $class->has_triggers,
									};
								}
								if ($class->does('DDG::Meta::ShareDir')) {
									$data{module_share_dir} = $class->module_share_dir;
								}
							}
						}
					};
					warn "Error on parsing ".$class.": ".$@ if $@;
					return $class => {
						filename => $file->name,
						%data,
					} if (%data);
					return;
				})},
			});
		},
	});

	$self->add_file($file);
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=head1 NAME

Dist::Zilla::Plugin::DuckpanMeta - DistZilla plugin for gathering DuckPAN related (so far only DDG related) meta information

=head1 VERSION

version 0.002

=head1 SYNOPSIS

In dist.ini:

  [DuckpanMeta]

=head1 DESCRIPTION

=encoding utf8

=head1 SUPPORT

IRC

  Join #duckduckgo on irc.freenode.net. Highlight Getty for fast reaction :).

Repository

  http://github.com/duckduckgo/p5-dist-zilla-plugin-duckpanmeta
  Pull request and additional contributors are welcome

Issue Tracker

  http://github.com/duckduckgo/p5-dist-zilla-plugin-duckpanmeta/issues

=head1 AUTHOR

Torsten Raudssus <torsten@raudss.us>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
