#!/usr/bin/perl
#
# script_build.pl
# Converts "text/script_en.txt" into the binary English script inserted into the executables.
#
# Written by Derek Pascarella (ateam)

# Include necessary modules.
use strict;
use FindBin;
use lib $FindBin::Bin;
use CDImage;

# Set input/output paths.
my $input_file = "text/script_en.txt";
my $credits_file = "text/credits_en.txt";
my $font_file = "build/font_en.bin";
my $output_folder = "build";

mkdir($output_folder);

my %has_glyph;
my $font = read_file_raw($font_file);

for(my $code = 0x20; $code < 0x80; $code ++)
{
	$has_glyph{chr($code)} = 1 if($code == 0x20 || substr($font, ($code - 0x20) * 32, 32) ne pack("v", 0xFFFF) x 16);
}

open(my $fh, '<', $input_file) or die "Could not open '$input_file'.\n";
my @lines = map { s/[\r\n]+$//r } <$fh>;
close($fh);

my @entries;
my @continued;
my $errors = 0;

for(my $i = 0; $i < scalar(@lines); $i ++)
{
	next if($lines[$i] !~ /^#(\d+)/);

	my $number = $1;
	my $width = ($number < 96) ? 24 : 32;
	my $box = 0;

	while(1)
	{
		my $text = "";

		for(my $line = 1; $line <= 3; $line ++)
		{
			my $row = defined($lines[$i + $line]) ? $lines[$i + $line] : "";
			$row =~ s/\s+$//;

			if(length($row) > $width)
			{
				print "Entry $number, box " . ($box + 1) . ", line $line is " . length($row) . " characters (limit is $width).\n";
				$errors ++;
			}

			foreach my $character (split(//, $row))
			{
				if(!$has_glyph{$character})
				{
					print "Entry $number uses \"$character\", which has no glyph.\n";
					$errors ++;
				}
			}

			$text .= $row . (" " x ($width - length($row)));
		}

		if($box == 0)
		{
			$entries[$number] = $text;
		}
		else
		{
			push(@continued, pack("v", $number) . $text);
		}

		$i += 3;
		$box ++;

		last if(!defined($lines[$i + 1]) || $lines[$i + 1] ne "+");

		$i ++;

		if($number >= 96)
		{
			print "Entry $number is an intro page, which can't have a continuation box.\n";
			$errors ++;
		}
	}
}

for(my $number = 0; $number < 102; $number ++)
{
	if(!defined($entries[$number]))
	{
		print "Entry $number is missing.\n";
		$errors ++;
	}
}

open($fh, '<', $credits_file) or die "Could not open '$credits_file'.\n";
my @credit_lines = map { s/[\r\n]+$//r } <$fh>;
close($fh);

my $credits = "";

if(scalar(@credit_lines) != 142)
{
	print "Credits have " . scalar(@credit_lines) . " row(s), but the ending roll is exactly 142.\n";
	$errors ++;
}

for(my $i = 0; $i < scalar(@credit_lines); $i ++)
{
	my $row = $credit_lines[$i] =~ s/\s+$//r;

	if($row eq "")
	{
		$credits .= "\0" . (" " x 31);
	}
	elsif($row !~ /^[_^\\]/ || length($row) > 32 || substr($row, 1) !~ /^[A-Za-z1-9 !().-]*$/)
	{
		print "Credits row " . ($i + 1) . " needs a _, ^, or \\ color marker, at most 31 characters, and only A-Z, a-z, 1-9, space, and ! ( ) . -\n";
		$errors ++;
	}
	else
	{
		$credits .= $row . (" " x (32 - length($row)));
	}
}

die "\n$errors problem(s) found, script not built.\n" if($errors);

write_file_raw("$output_folder/script_en.bin", join("", @entries[0 .. 101]));
write_file_raw("$output_folder/script_en_continued.bin", join("", @continued));
write_file_raw("$output_folder/credits_en.bin", $credits);

print "\nBuilt script_en.bin from 102 entries, plus " . scalar(@continued) . " continuation box(es).\n";
print "Built credits_en.bin from 142 rows.\n\n";
