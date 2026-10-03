#!/usr/bin/perl
#
# fmt_extract.pl
# Extracts and decompresses PULIRULA.EXP and PULIRUL2.EXP, then dumps the Japanese script and font.
#
# Written by Derek Pascarella (ateam)

# Include necessary modules.
use strict;
use FindBin;
use lib $FindBin::Bin;
use CDImage;
use ExpPack;
use GD;

# Set input/output paths.
my $input_folder = "input/fmt_redump";
my $output_folder = "assets/fmt";
my $glyph_table_file = "text/glyph_table.txt";

mkdir("assets");
mkdir($output_folder);

my $track = find_track_file($input_folder, "01");
my $bin = read_file_raw($track);

print "\nReading \"$track\"...\n\n";

foreach my $name ("PULIRULA", "PULIRUL2")
{
	my $exp = read_iso_file(\$bin, "$name.EXP");
	my $memory = decode_stream(exp_info($exp)->{image});

	write_file_raw("$output_folder/$name.EXP", $exp);
	write_file_raw("$output_folder/$name.MEM", $memory);

	printf("Unpacked %s.EXP (%d bytes) to %s.MEM (%d bytes).\n", $name, length($exp), $name, length($memory));
}

my @glyph_table = read_glyph_table($glyph_table_file);
my $memory = read_file_raw("$output_folder/PULIRULA.MEM");
my ($script_base, $font_base) = find_script($memory);

dump_script($memory, $script_base, "$output_folder/script_jp.txt");
dump_font($memory, $font_base, "$output_folder/font_jp.png");

print "\nWrote script_jp.txt and font_jp.png.\n\n";

sub find_script
{
	my $memory = $_[0];

	my @fonts;

	while($memory =~ /\x0F\xB6\x36\xC1\xE6\x06\x81\xC6(....)/gs)
	{
		push(@fonts, unpack("V", $1));
	}

	die "Could not find the text renderers.\n" if(scalar(@fonts) != 3 || $fonts[0] != $fonts[1] || $fonts[0] != $fonts[2]);

	return ($fonts[0] - (96 * 36 + 6 * 48), $fonts[0]);
}

sub read_glyph_table
{
	my $file = $_[0];

	my @table;

	open(my $fh, '<:encoding(UTF-8)', $file) or die "Could not open '$file'.\n";

	while(my $line = <$fh>)
	{
		$line =~ s/[\r\n]+$//;

		if($line =~ /^([0-9A-F]{2}) (.)$/)
		{
			$table[hex($1)] = $2;
		}
	}

	close($fh);

	return @table;
}

sub dump_script
{
	my ($memory, $base, $file) = @_;

	open(my $fh, '>:encoding(UTF-8)', $file) or die "Could not write '$file'.\n";

	for(my $unit = 0; $unit < 102; $unit ++)
	{
		my $width = ($unit < 96) ? 12 : 16;
		my $address = ($unit < 96) ? $base + $unit * 36 : $base + 96 * 36 + ($unit - 96) * 48;

		printf $fh "#%03d %05X\n", $unit, $address;

		for(my $line = 0; $line < 3; $line ++)
		{
			my $text = "";

			foreach my $glyph (unpack("C*", substr($memory, $address + $line * $width, $width)))
			{
				$text .= defined($glyph_table[$glyph]) ? $glyph_table[$glyph] : sprintf("[%02X]", $glyph);
			}

			print $fh "$text\n";
		}

		print $fh "\n";
	}

	close($fh);
}

sub dump_font
{
	my ($memory, $base, $file) = @_;

	my $count = scalar(@glyph_table);
	my $image = GD::Image->new(16 * 18 * 3, int(($count + 15) / 16) * 18 * 3);
	my @colors = map { $image->colorAllocate(@$_) } ([0, 0, 0], [255, 255, 220], [110, 70, 0], [20, 20, 60]);

	for(my $glyph = 0; $glyph < $count; $glyph ++)
	{
		my @bytes = unpack("C*", substr($memory, $base + $glyph * 64, 64));

		for(my $pixel = 0; $pixel < 256; $pixel ++)
		{
			my $value = ($bytes[$pixel >> 2] >> (($pixel & 3) * 2)) & 3;
			my $x = (($glyph % 16) * 18 + 1 + ($pixel % 16)) * 3;
			my $y = (int($glyph / 16) * 18 + 1 + int($pixel / 16)) * 3;

			$image->filledRectangle($x, $y, $x + 2, $y + 2, $colors[$value]);
		}
	}

	write_file_raw($file, $image->png);
}
