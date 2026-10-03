#!/usr/bin/perl
#
# font_build.pl
# Builds the 8x16 English font from the Saturn glyphs plus the hand-drawn ones in "font/extra_glyphs.txt".
#
# Written by Derek Pascarella (ateam)

# Include necessary modules.
use strict;
use FindBin;
use lib $FindBin::Bin;
use CDImage;
use GD;

# Set input/output paths.
my $saturn_glyph_file = "assets/saturn/glyphs.bin";
my $label_file = "font/glyph_labels.txt";
my $extra_file = "font/extra_glyphs.txt";
my $output_folder = "build";

mkdir($output_folder);

my %glyphs;
my $saturn_glyphs = read_file_raw($saturn_glyph_file);

open(my $fh, '<', $label_file) or die "Could not open '$label_file'.\n";

while(my $line = <$fh>)
{
	$line =~ s/[\r\n]+$//;

	if($line =~ /^([0-9A-F]{2}) (.)$/)
	{
		$glyphs{$2} = [unpack("C*", substr($saturn_glyphs, hex($1) * 128, 128))];
	}
}

close($fh);

my $saturn_count = scalar(keys %glyphs);
my $character;
my @rows;

open($fh, '<', $extra_file) or die "Could not open '$extra_file'.\n";

while(my $line = <$fh>)
{
	$line =~ s/[\r\n]+$//;

	if($line =~ /^\[(.)\]$/)
	{
		$character = $1;
		@rows = ();
	}
	elsif($line =~ /^[.#]+$/ && defined($character))
	{
		push(@rows, $line);

		if(scalar(@rows) == 11)
		{
			$glyphs{$character} = draw_glyph(@rows);
			undef($character);
		}
	}
}

close($fh);

print "\nLoaded $saturn_count Saturn glyph(s) and " . (scalar(keys %glyphs) - $saturn_count) . " drawn glyph(s).\n";

my $font = "";

for(my $code = 0x20; $code < 0x80; $code ++)
{
	my $glyph = $glyphs{chr($code)} || [(0) x 128];

	for(my $y = 0; $y < 16; $y ++)
	{
		my $word = 0;

		for(my $x = 0; $x < 8; $x ++)
		{
			my $value = $glyph->[$y * 8 + $x];
			$word |= ($value == 0 ? 3 : $value) << ($x * 2);
		}

		$font .= pack("v", $word);
	}
}

write_file_raw("$output_folder/font_en.bin", $font);
save_preview("$output_folder/font_preview.png");

print "Wrote font_en.bin (" . length($font) . " bytes) and font_preview.png.\n\n";

sub draw_glyph
{
	my @rows = @_;

	my @stroke = (0) x 128;
	my @glyph = (0) x 128;

	for(my $y = 0; $y < 11; $y ++)
	{
		for(my $x = 0; $x < length($rows[$y]); $x ++)
		{
			$stroke[($y + 2) * 8 + $x] = 1 if(substr($rows[$y], $x, 1) eq "#");
		}
	}

	for(my $i = 0; $i < 128; $i ++)
	{
		my $x = $i % 8;
		my $y = int($i / 8);

		if($stroke[$i])
		{
			$glyph[$i] = 1;
		}
		elsif(($x > 0 && $stroke[$i - 1]) || ($y > 0 && $stroke[$i - 8]))
		{
			$glyph[$i] = 2;
		}
	}

	return \@glyph;
}

sub save_preview
{
	my $file = $_[0];

	my @characters = map { chr($_) } (0x20 .. 0x7F);
	my $image = GD::Image->new(32 * 8 * 3, 3 * 16 * 3);
	my @colors = map { $image->colorAllocate(@$_) } ([0, 0, 60], [255, 255, 220], [110, 70, 0]);

	for(my $i = 0; $i < scalar(@characters); $i ++)
	{
		my $glyph = $glyphs{$characters[$i]} || next;

		for(my $p = 0; $p < 128; $p ++)
		{
			my $x = (($i % 32) * 8 + ($p % 8)) * 3;
			my $y = (int($i / 32) * 16 + int($p / 8)) * 3;

			$image->filledRectangle($x, $y, $x + 2, $y + 2, $colors[$glyph->[$p]]);
		}
	}

	write_file_raw($file, $image->png);
}
