#!/usr/bin/perl
#
# CDImage.pm
# Routines for reading files from and writing sectors to Mode 1 (2352-byte sector) data tracks.
#
# Written by Derek Pascarella (ateam)

package CDImage;

use strict;
use Exporter 'import';

our @EXPORT = qw(read_file_raw write_file_raw find_track_file sector_data read_iso_file find_iso_file encode_sector);

my @edc_table;
my @ecc_f;
my @ecc_b;

for(my $i = 0; $i < 256; $i ++)
{
	my $edc = $i;

	for(1 .. 8)
	{
		$edc = ($edc >> 1) ^ (($edc & 1) ? 0xD8018001 : 0);
	}

	$edc_table[$i] = $edc;

	my $j = (($i << 1) ^ (($i & 0x80) ? 0x11D : 0)) & 0xFF;
	$ecc_f[$i] = $j;
	$ecc_b[$i ^ $j] = $i;
}

sub read_file_raw
{
	my $file = $_[0];

	open(my $fh, '<:raw', $file) or die "Could not open '$file': $!\n";
	local $/;
	my $data = <$fh>;
	close($fh);

	return $data;
}

sub write_file_raw
{
	my ($file, $data) = @_;

	open(my $fh, '>:raw', $file) or die "Could not write '$file': $!\n";
	print $fh $data;
	close($fh);
}

sub find_track_file
{
	my ($folder, $track) = @_;

	opendir(my $dh, $folder) or die "Could not open folder '$folder'.\n";
	my @files = grep { /\(Track $track\)\.bin$/i } readdir($dh);
	closedir($dh);

	die "No 'Track $track' BIN found in '$folder'.\n" if(scalar(@files) != 1);

	return "$folder/$files[0]";
}

sub sector_data
{
	my ($bin_ref, $lba, $count) = @_;
	$count = 1 if(!defined($count));

	my $data = "";

	for(my $i = 0; $i < $count; $i ++)
	{
		$data .= substr($$bin_ref, ($lba + $i) * 2352 + 16, 2048);
	}

	return $data;
}

sub find_iso_file
{
	my ($bin_ref, $name) = @_;

	my $pvd = sector_data($bin_ref, 16);
	my $root_lba = unpack("V", substr($pvd, 158, 4));
	my $root_size = unpack("V", substr($pvd, 166, 4));

	for(my $lba = $root_lba; $lba < $root_lba + int(($root_size + 2047) / 2048); $lba ++)
	{
		my $dir = sector_data($bin_ref, $lba);
		my $offset = 0;

		while($offset < 2048 && ord(substr($dir, $offset, 1)) != 0)
		{
			my $length = ord(substr($dir, $offset, 1));
			my $id = substr($dir, $offset + 33, ord(substr($dir, $offset + 32, 1)));
			$id =~ s/;.*$//;

			if(uc($id) eq uc($name))
			{
				return
				{
					dir_lba => $lba,
					dir_offset => $offset,
					lba => unpack("V", substr($dir, $offset + 2, 4)),
					size => unpack("V", substr($dir, $offset + 10, 4))
				};
			}

			$offset += $length;
		}
	}

	die "File '$name' not found in root directory.\n";
}

sub read_iso_file
{
	my ($bin_ref, $name) = @_;

	my $entry = find_iso_file($bin_ref, $name);

	return substr(sector_data($bin_ref, $entry->{lba}, int(($entry->{size} + 2047) / 2048)), 0, $entry->{size});
}

sub edc
{
	my $edc = 0;

	foreach my $byte (unpack("C*", $_[0]))
	{
		$edc = $edc_table[($edc ^ $byte) & 0xFF] ^ ($edc >> 8);
	}

	return $edc;
}

sub ecc_block
{
	my ($sector, $major_count, $minor_count, $major_mult, $minor_inc, $out) = @_;

	my $size = $major_count * $minor_count;

	for(my $major = 0; $major < $major_count; $major ++)
	{
		my $index = ($major >> 1) * $major_mult + ($major & 1);
		my $a = 0;
		my $b = 0;

		for(my $minor = 0; $minor < $minor_count; $minor ++)
		{
			my $temp = $sector->[12 + $index];
			$index += $minor_inc;
			$index -= $size if($index >= $size);
			$a ^= $temp;
			$b ^= $temp;
			$a = $ecc_f[$a];
		}

		$a = $ecc_b[$ecc_f[$a] ^ $b];
		$sector->[$out + $major] = $a;
		$sector->[$out + $major + $major_count] = $a ^ $b;
	}
}

sub bcd
{
	return (int($_[0] / 10) << 4) | ($_[0] % 10);
}

sub encode_sector
{
	my ($lba, $data) = @_;

	my $address = $lba + 150;
	my $header = pack("C12", 0, (0xFF) x 10, 0);
	$header .= pack("C4", bcd(int($address / 4500)), bcd(int($address / 75) % 60), bcd($address % 75), 1);

	my $sector = $header . $data;
	$sector .= pack("V", edc($sector)) . ("\0" x 8);

	my @bytes = unpack("C*", $sector . ("\0" x 276));

	ecc_block(\@bytes, 86, 24, 2, 86, 0x81C);
	ecc_block(\@bytes, 52, 43, 86, 88, 0x81C + 172);

	return pack("C*", @bytes);
}

1;
