#!/usr/bin/perl
#
# disc_build.pl
# Builds the regular and Marty expanded RAM disc images by writing the patched files over the originals in Track 01.
#
# Written by Derek Pascarella (ateam)

# Include necessary modules.
use strict;
use FindBin;
use lib $FindBin::Bin;
use CDImage;
use File::Copy;

# Set input/output paths.
my $input_folder = "input/fmt_redump";
my $build_folder = "build";
my $marty_autoexec = "marty/AUTOEXEC.BAT";
my $output_folder = "output";

mkdir($output_folder);

my $track_file = find_track_file($input_folder, "01");
my $original = read_file_raw($track_file);
(my $track_name = $track_file) =~ s/^.*\///;

my %exp_files = (
	"PULIRULA.EXP" => read_file_raw("$build_folder/PULIRULA.EXP"),
	"PULIRUL2.EXP" => read_file_raw("$build_folder/PULIRUL2.EXP")
);

my %images = (
	"disc_image_patched" => { %exp_files },
	"disc_image_patched_marty_exp_ram" => { %exp_files, "AUTOEXEC.BAT" => read_file_raw($marty_autoexec) }
);

print "\n";

foreach my $folder (sort keys %images)
{
	my $target = "$output_folder/$folder";
	mkdir($target);

	opendir(my $dh, $input_folder);
	my @files = grep { /\.(bin|cue)$/i && $_ ne $track_name } readdir($dh);
	closedir($dh);

	foreach my $file (@files)
	{
		copy("$input_folder/$file", "$target/$file") or die "Could not copy '$file': $!\n";
	}

	my $bin = $original;

	foreach my $name (sort keys %{$images{$folder}})
	{
		my $data = $images{$folder}->{$name};
		my $entry = find_iso_file(\$bin, $name);

		die "Replacement for $name must be $entry->{size} bytes.\n" if(length($data) != $entry->{size});

		my $sectors = int((length($data) + 2047) / 2048);
		my $sector_data = sector_data(\$bin, $entry->{lba}, $sectors);
		substr($sector_data, 0, length($data)) = $data;

		for(my $i = 0; $i < $sectors; $i ++)
		{
			substr($bin, ($entry->{lba} + $i) * 2352, 2352) = encode_sector($entry->{lba} + $i, substr($sector_data, $i * 2048, 2048));
		}
	}

	write_file_raw("$target/$track_name", $bin);

	print "Built \"$target\".\n";
}

print "\n";
