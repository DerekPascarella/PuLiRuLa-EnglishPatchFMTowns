#!/usr/bin/perl
#
# ExpPack.pm
# Compression routines for the self-extracting PULIRULA and PULIRUL2 executables.
#
# Written by Derek Pascarella (ateam)

package ExpPack;

use strict;
use Exporter 'import';

our @EXPORT = qw(exp_info decode_stream encode_stream unpack_in_place);

sub exp_info
{
	my $exp = $_[0];

	my ($last_page, $pages, $relocs, $header_size, $min_alloc) = unpack("v5", substr($exp, 2, 10));
	my $eip = unpack("V", substr($exp, 20, 4));
	my $image = substr($exp, $header_size * 16);

	substr($image, -0x10) =~ /\xBC(....)\x68(....)\xC3$/s or die "Unexpected unpack stub.\n";

	return
	{
		header_size => $header_size * 16,
		min_alloc => $min_alloc,
		eip => $eip,
		image => $image,
		stack => unpack("V", $1),
		entry => unpack("V", $2)
	};
}

sub decode_stream
{
	my $data = $_[0];

	my $output = "";
	my $position = 0;
	my $bit = 0;

	my $read = sub
	{
		my $value = 0;

		for(my $i = 0; $i < $_[0]; $i ++)
		{
			$value |= ((ord(substr($data, $position, 1)) >> $bit) & 1) << $i;

			if(++ $bit == 8)
			{
				$bit = 0;
				$position ++;
			}
		}

		return $value;
	};

	while(1)
	{
		if(!$read->(1))
		{
			$output .= chr($read->(8));

			next;
		}

		my $length;

		for my $count (2 .. 5)
		{
			if(!$read->(1))
			{
				$length = $count;

				last;
			}
		}

		if(!defined($length))
		{
			my $select = $read->(2);

			if($select == 0)
			{
				$length = 6;
			}
			elsif($select == 1)
			{
				$length = $read->(2) + 7;
			}
			elsif($select == 2)
			{
				$length = $read->(4) + 11;
			}
			else
			{
				$length = $read->(10);

				last if($length == 0);

				$length += 26;
			}
		}

		my $distance;

		if(!$read->(1))
		{
			$distance = $read->(8) + 1;
		}
		elsif(!$read->(1))
		{
			my $low = $read->(8);
			$distance = ((($read->(2) + 1) << 8) | $low) + 1;
		}
		else
		{
			my $low = $read->(8);
			$distance = ((($read->(4) + 5) << 8) | $low) + 1;
		}

		my $start = length($output) - $distance;

		if($distance >= $length)
		{
			$output .= substr($output, $start, $length);
		}
		else
		{
			for(my $i = 0; $i < $length; $i ++)
			{
				$output .= substr($output, $start + $i, 1);
			}
		}
	}

	return $output;
}

sub encode_stream
{
	my $data = $_[0];

	my $size = length($data);
	my @steps = (2, 3, 4, 5, 6, 7, 10, 11, 26, 27);
	my (%head, %last_pair, @previous, @candidates);

	for(my $i = 0; $i < $size; $i ++)
	{
		my $limit = $size - $i;
		$limit = 1049 if($limit > 1049);

		next if($limit < 2);

		my @found;
		my $best = 1;

		if($limit >= 3)
		{
			my $key = substr($data, $i, 3);
			my $j = exists($head{$key}) ? $head{$key} : -1;
			my $depth = 0;

			while($j >= 0 && $i - $j <= 5376 && $depth < 16)
			{
				my $diff = substr($data, $j, $limit) ^ substr($data, $i, $limit);
				$diff =~ /^\0*/;
				my $length = $+[0];

				if($length > $best)
				{
					$best = $length;
					push(@found, $i - $j, $length);

					last if($length == $limit);
				}

				$j = $previous[$j];
				$depth ++;
			}

			$previous[$i] = exists($head{$key}) ? $head{$key} : -1;
			$head{$key} = $i;
		}

		my $pair = substr($data, $i, 2);

		if($best < 3 && exists($last_pair{$pair}) && $i - $last_pair{$pair} <= 256)
		{
			push(@found, $i - $last_pair{$pair}, 2);
		}

		$last_pair{$pair} = $i;
		$candidates[$i] = pack("v*", @found) if(@found);
	}

	my @cost = (0) x ($size + 1);
	my @choice;

	for(my $i = $size - 1; $i >= 0; $i --)
	{
		my $best = 9 + $cost[$i + 1];
		my $pick;

		if(defined($candidates[$i]))
		{
			my @found = unpack("v*", $candidates[$i]);

			while(my ($distance, $length) = splice(@found, 0, 2))
			{
				my $distance_bits = ($distance <= 256) ? 10 : ($distance <= 1280 ? 13 : 15);

				foreach my $count (@steps, $length)
				{
					next if($count > $length);

					my $total = $distance_bits + length_bits($count) + $cost[$i + $count];

					if($total < $best)
					{
						$best = $total;
						$pick = [$distance, $count];
					}
				}
			}
		}

		$cost[$i] = $best;
		$choice[$i] = $pick;
	}

	my $bits = "";

	for(my $i = 0; $i < $size;)
	{
		if(!defined($choice[$i]))
		{
			$bits .= "0" . bit_string(ord(substr($data, $i, 1)), 8);
			$i ++;

			next;
		}

		my ($distance, $length) = @{$choice[$i]};

		$bits .= "1" . length_code($length) . distance_code($distance);
		$i += $length;
	}

	$bits .= "1" . "1111" . "11" . ("0" x 10);
	$bits .= "0" x ((8 - length($bits) % 8) % 8);

	return pack("b*", $bits);
}

sub bit_string
{
	my ($value, $count) = @_;

	return substr(unpack("b32", pack("V", $value)), 0, $count);
}

sub length_bits
{
	my $length = $_[0];

	return $length - 1 if($length <= 5);
	return 6 if($length == 6);
	return 8 if($length <= 10);
	return 10 if($length <= 26);
	return 16;
}

sub length_code
{
	my $length = $_[0];

	return ("1" x ($length - 2)) . "0" if($length <= 5);
	return "1111" . "00" if($length == 6);
	return "1111" . "10" . bit_string($length - 7, 2) if($length <= 10);
	return "1111" . "01" . bit_string($length - 11, 4) if($length <= 26);
	return "1111" . "11" . bit_string($length - 26, 10);
}

sub distance_code
{
	my $value = $_[0] - 1;

	return "0" . bit_string($value, 8) if($value < 256);
	return "10" . bit_string($value & 0xFF, 8) . bit_string(($value >> 8) - 1, 2) if($value < 1280);
	return "11" . bit_string($value & 0xFF, 8) . bit_string(($value >> 8) - 5, 4);
}

sub unpack_in_place
{
	my $exp = $_[0];

	my $info = exp_info($exp);
	my $image = $info->{image};
	my $eip = $info->{eip};
	my $top = length($image) + $info->{min_alloc} * 0x1000;

	substr($image, $eip, 0x30) =~ /\x8D\x7C\x24(.)\xBE(....)\xB9(....)/s or die "Unexpected unpack stub.\n";
	my $stub_copy_offset = unpack("c", $1);
	my $stub_end = unpack("V", $2);
	my $stub_size = unpack("V", $3);

	substr($image, $eip + 0x1F, 10) =~ /^\xBE(....)\xB9(....)$/s or die "Unexpected unpack stub.\n";
	my $data_end = unpack("V", $1);
	my $data_size = unpack("V", $2);

	my $memory = $image . ("\0" x ($top - length($image)));

	substr($memory, $top - 32, 32) = pack("V8", 0, 0, 0, $top, 0, 0, 0, 0);

	my $stub_dest = $top - 32 + $stub_copy_offset;
	substr($memory, $stub_dest - $stub_size + 1, $stub_size) = substr($memory, $stub_end - $stub_size + 1, $stub_size);

	my $data_dest = $stub_dest - $stub_size + 1;
	substr($memory, $data_dest - $data_size + 1, $data_size) = substr($memory, $data_end - $data_size + 1, $data_size);

	my $esi = $data_dest - $data_size + 1;
	my $edi = 0;
	my $cl = 0;

	while(1)
	{
		my $bits = unpack("V", substr($memory, $esi, 4)) >> $cl;

		if(!($bits & 1))
		{
			substr($memory, $edi ++, 1) = chr(($bits >> 1) & 0xFF);
			$cl ++;
			$esi += 1 + (($cl >> 3) & 1);
			$cl &= 7;

			die "Unpacked data overran the compressed data.\n" if($edi > $esi);

			next;
		}

		$bits >>= 1;

		my $length;

		for(my $count = 2; $count <= 5; $count ++)
		{
			my $bit = $bits & 1;
			$bits >>= 1;

			if(!$bit)
			{
				$length = $count;
				$cl += $count;

				last;
			}
		}

		if(!defined($length))
		{
			my $select = $bits & 3;
			my $value = $bits >> 2;

			if($select == 0)
			{
				$length = 6;
				$cl += 7;
			}
			elsif($select == 1)
			{
				$length = ($value & 3) + 7;
				$cl ++;
				$esi ++;
			}
			elsif($select == 2)
			{
				$length = ($value & 0xF) + 0xB;
				$cl += 3;
				$esi ++;
			}
			else
			{
				last if(($value & 0x3FF) == 0);

				$length = ($value & 0x3FF) + 0x1A;
				$cl ++;
				$esi += 2;
			}
		}

		$esi += ($cl >> 3) & 1;
		$cl &= ~8;

		$bits = unpack("V", substr($memory, $esi, 4)) >> $cl;

		my $distance;

		if(!($bits & 1))
		{
			$distance = (($bits >> 1) & 0xFF) + 1;
			$cl ++;
		}
		elsif(!($bits & 2))
		{
			$distance = (((($bits >> 10) & 3) + 1) << 8 | (($bits >> 2) & 0xFF)) + 1;
			$cl += 4;
		}
		else
		{
			$distance = ((((($bits >> 10) & 0xF) + 5) & 0xFF) << 8 | (($bits >> 2) & 0xFF)) + 1;
			$cl += 6;
		}

		if($distance >= $length)
		{
			substr($memory, $edi, $length) = substr($memory, $edi - $distance, $length);
		}
		else
		{
			for(my $i = 0; $i < $length; $i ++)
			{
				substr($memory, $edi + $i, 1) = substr($memory, $edi + $i - $distance, 1);
			}
		}

		$edi += $length;
		$esi += 1 + (($cl >> 3) & 1);
		$cl &= ~8;

		die "Unpacked data overran the compressed data.\n" if($edi > $esi);
	}

	substr($memory, $info->{stack} - 4, 4) = pack("V", $info->{entry});

	return ($memory, $edi);
}

1;
