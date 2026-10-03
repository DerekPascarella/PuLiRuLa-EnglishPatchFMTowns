#!/usr/bin/perl
#
# saturn_extract.pl
# Extracts the English dialogue pages from the patched Saturn version and saves the unique font glyphs found on them.
#
# Written by Derek Pascarella (ateam)

# Include necessary modules.
use strict;
use FindBin;
use lib $FindBin::Bin;
use CDImage;
use GD;
use Digest::MD5 qw(md5_hex);

# Set input/output paths.
my $input_folder = "input/saturn_patched";
my $output_folder = "assets/saturn";

mkdir("assets");
mkdir($output_folder);
mkdir("$output_folder/pages");

my $track = find_track_file($input_folder, "01");
my $bin = read_file_raw($track);

print "\nReading \"$track\"...\n\n";

my %glyph_seen;
my @glyphs;
my $page_total = 0;

for(my $round = 1; $round <= 7; $round ++)
{
	my $cpt = read_iso_file(\$bin, "ROUND$round.CPT");
	write_file_raw("$output_folder/ROUND$round.CPT", $cpt);

	my $count = unpack("N", substr($cpt, 0, 4));
	my $page = 0;

	for(my $entry = 0; $entry < $count; $entry ++)
	{
		my ($width, $height) = unpack("C2", substr($cpt, $entry * 16 + 6, 2));
		my $offset = unpack("N", substr($cpt, $entry * 16 + 12, 4));

		next if($width != 192 || $height != 48);

		my @pixels = decode_sprite($cpt, $offset, $width * $height);

		save_page(\@pixels, sprintf("%s/pages/round%d_%02d.png", $output_folder, $round, $page));

		for(my $line = 0; $line < 3; $line ++)
		{
			for(my $column = 0; $column < 24; $column ++)
			{
				my $glyph = "";

				for(my $y = 0; $y < 16; $y ++)
				{
					$glyph .= pack("C8", @pixels[($line * 16 + $y) * 192 + $column * 8 .. ($line * 16 + $y) * 192 + $column * 8 + 7]);
				}

				if(!$glyph_seen{$glyph})
				{
					$glyph_seen{$glyph} = 1;
					push(@glyphs, $glyph);
				}
			}
		}

		$page ++;
	}

	print "ROUND$round.CPT: $page dialogue page(s).\n";
	$page_total += $page;
}

write_file_raw("$output_folder/glyphs.bin", join("", @glyphs));

if(md5_hex(join("", @glyphs)) ne "0a992f0799283e97888477e516f1583c")
{
	die "\nThe dialogue font doesn't match T-En v1.0, so \"font/glyph_labels.txt\" won't line up.\n\n";
}
save_glyph_sheet("$output_folder/glyphs.png");

print "\nSaved $page_total page(s) and " . scalar(@glyphs) . " unique glyph(s).\n\n";

sub decode_sprite
{
	my ($data, $position, $pixel_count) = @_;

	my $output = "";
	my $bit = 0;
	my $ring = 1;

	my $read_bits = sub
	{
		my $value = 0;

		for(1 .. $_[0])
		{
			$value = ($value << 1) | ((ord(substr($data, $position, 1)) >> (7 - $bit)) & 1);

			if(++ $bit == 8)
			{
				$bit = 0;
				$position ++;
			}
		}

		return $value;
	};

	while(length($output) < $pixel_count / 2)
	{
		if($read_bits->(1))
		{
			$output .= chr($read_bits->(8));
			$ring = ($ring + 1) & 0xFFF;
		}
		else
		{
			my $value = $read_bits->(16);
			my $offset = $value >> 4;
			my $length = ($value & 0xF) + 2;

			last if($offset == 0);

			my $distance = ($ring - $offset) & 0xFFF || 0x1000;
			my $start = length($output) - $distance;

			for(my $i = 0; $i < $length; $i ++)
			{
				$output .= ($start + $i >= 0) ? substr($output, $start + $i, 1) : "\0";
			}

			$ring = ($ring + $length) & 0xFFF;
		}
	}

	$output .= "\0" x ($pixel_count / 2 - length($output));

	return map { ($_ >> 4, $_ & 0xF) } unpack("C*", $output);
}

sub save_page
{
	my ($pixels, $file) = @_;

	my $image = GD::Image->new(192 * 2, 48 * 2);
	my @colors = map { $image->colorAllocate(@$_) } ([0, 0, 60], [255, 255, 220], [110, 70, 0]);

	for(my $i = 0; $i < 192 * 48; $i ++)
	{
		my $x = ($i % 192) * 2;
		my $y = int($i / 192) * 2;

		$image->filledRectangle($x, $y, $x + 1, $y + 1, $colors[$pixels->[$i] > 2 ? 0 : $pixels->[$i]]);
	}

	write_file_raw($file, $image->png);
}

sub save_glyph_sheet
{
	my $file = $_[0];

	my $image = GD::Image->new(16 * 30, int((scalar(@glyphs) + 15) / 16) * 60);
	my $background = $image->colorAllocate(40, 40, 40);
	my $label = $image->colorAllocate(0, 255, 0);
	my @colors = map { $image->colorAllocate(@$_) } ([0, 0, 60], [255, 255, 220], [110, 70, 0]);

	for(my $i = 0; $i < scalar(@glyphs); $i ++)
	{
		my $x0 = ($i % 16) * 30;
		my $y0 = int($i / 16) * 60;
		my @pixels = unpack("C*", $glyphs[$i]);

		$image->string(gdTinyFont, $x0 + 2, $y0 + 1, sprintf("%02X", $i), $label);

		for(my $p = 0; $p < 128; $p ++)
		{
			my $x = $x0 + 4 + ($p % 8) * 3;
			my $y = $y0 + 10 + int($p / 8) * 3;

			$image->filledRectangle($x, $y, $x + 2, $y + 2, $colors[$pixels[$p]]);
		}
	}

	write_file_raw($file, $image->png);
}
