#!/usr/bin/perl
#
# exp_patch.pl
# Inserts the English script, font, and new code into both executables, then recompresses them.
#
# Written by Derek Pascarella (ateam)

# Include necessary modules.
use strict;
use FindBin;
use lib $FindBin::Bin;
use CDImage;
use ExpPack;

# Set input/output paths.
my $asset_folder = "assets/fmt";
my $build_folder = "build";

my $script_en = read_file_raw("$build_folder/script_en.bin");
my $continued = read_file_raw("$build_folder/script_en_continued.bin");
my $font_en = read_file_raw("$build_folder/font_en.bin");
my $credits_en = read_file_raw("$build_folder/credits_en.bin");

# Version line added to the title screen, between the menu and the copyright lines.
my $title_text = "ENGLISH V1.0";
my $title_y = 162;
my $title_attr = 0x8105;

die "Unexpected script size.\n" if(length($script_en) != (96 * 36 + 6 * 48) * 2);

# Continuation boxes are stored after the main script and get their own pseudo script addresses.
my @continued_units;

for(my $i = 0; $i < length($continued); $i += 74)
{
	push(@continued_units, unpack("v", substr($continued, $i, 2)));
	$script_en .= substr($continued, $i + 2, 72);
}

print "\n";

foreach my $name ("PULIRULA", "PULIRUL2")
{
	my $exp = read_file_raw("$asset_folder/$name.EXP");
	my $memory = read_file_raw("$asset_folder/$name.MEM");

	my ($font_base, $free) = patch_text(\$memory);
	my ($flag, $free_after) = patch_invincible(\$memory, $free, $font_base + 0xDE * 64);
	my $free_title = patch_scenes(\$memory, $font_base, $free_after, $font_base + 0xDE * 64);
	patch_credits(\$memory);
	patch_title(\$memory, $free_title, $font_base + 0xDE * 64, title_sprites($title_text, $title_y, $title_attr));

	write_file_raw("$build_folder/$name.EXP", build_exp($exp, $memory));

	printf("Patched %s.EXP (font at %05X, invincible flag at %05X).\n", $name, $font_base, $flag);
}

print "\n";

sub find_one
{
	my ($memory_ref, $pattern) = @_;

	my @matches;

	while($$memory_ref =~ /$pattern/gs)
	{
		push(@matches, [$-[0], $1, $2, $3]);
	}

	die "Signature matched " . scalar(@matches) . " time(s), expected once.\n" if(scalar(@matches) != 1);

	return @{$matches[0]};
}

sub call_rel
{
	my ($from, $to) = @_;

	return "\xE8" . pack("V", ($to - ($from + 5)) & 0xFFFFFFFF);
}

sub patch_text
{
	my $memory_ref = $_[0];

	my @sites;
	my $font_base;

	while($$memory_ref =~ /\x0F\xB6\x36\xC1\xE6\x06\x81\xC6(....)/gs)
	{
		push(@sites, $-[0]);
		$font_base = unpack("V", $1);
	}

	die "Could not find the text renderers.\n" if(scalar(@sites) != 3);

	my $script_base = $font_base - (96 * 36 + 6 * 48);
	my $text_address = $font_base;
	my $font_address = $text_address + length($script_en);
	my $cell_buffer = $font_address + length($font_en);
	my $code_address = $cell_buffer + 64;

	my $text_offset = ($text_address - 2 * $script_base) & 0xFFFFFFFF;

	my $code = "\x50\x53\x51\x57";                              # push eax/ebx/ecx/edi
	$code .= "\x8D\x04\x75" . pack("V", $text_offset);          # lea eax,[esi*2+text-script*2]
	$code .= "\x0F\xB6\x18";                                    # movzx ebx,byte [eax]
	$code .= "\x0F\xB6\x48\x01";                                # movzx ecx,byte [eax+1]
	$code .= "\xC1\xE3\x05";                                    # shl ebx,5
	$code .= "\xC1\xE1\x05";                                    # shl ecx,5
	$code .= "\x81\xC3" . pack("V", $font_address - 0x400);     # add ebx,font-0x400
	$code .= "\x81\xC1" . pack("V", $font_address - 0x400);     # add ecx,font-0x400
	$code .= "\xBF" . pack("V", $cell_buffer);                  # mov edi,cell
	$code .= "\xBE\x10\x00\x00\x00";                            # mov esi,16
	$code .= "\x0F\xB7\x01";                                    # movzx eax,word [ecx]
	$code .= "\xC1\xE0\x10";                                    # shl eax,16
	$code .= "\x66\x8B\x03";                                    # mov ax,[ebx]
	$code .= "\x89\x07";                                        # mov [edi],eax
	$code .= "\x83\xC7\x04";                                    # add edi,4
	$code .= "\x83\xC3\x02";                                    # add ebx,2
	$code .= "\x83\xC1\x02";                                    # add ecx,2
	$code .= "\x4E";                                            # dec esi
	$code .= "\x75\xE9";                                        # jnz row loop
	$code .= "\xBE" . pack("V", $cell_buffer);                  # mov esi,cell
	$code .= "\x5F\x59\x5B\x58\xC3";                            # pop edi/ecx/ebx/eax, ret

	die "Patch does not fit in the Japanese font area.\n" if($code_address + length($code) > $font_base + 0xDE * 64);

	substr($$memory_ref, $text_address, length($script_en)) = $script_en;
	substr($$memory_ref, $font_address, length($font_en)) = $font_en;
	substr($$memory_ref, $cell_buffer, 64) = "\0" x 64;
	substr($$memory_ref, $code_address, length($code)) = $code;

	foreach my $site (@sites)
	{
		substr($$memory_ref, $site, 12) = call_rel($site, $code_address) . ("\x90" x 7);
	}

	return ($font_base, ($code_address + length($code) + 15) & ~15);
}

sub find_value_list
{
	my ($memory_ref, $text, $y) = @_;

	my $list = pack("V", length($text));

	for(my $i = 0; $i < length($text); $i ++)
	{
		$list .= pack("v4", 144 + $i * 8, $y, 0x391 + ord(substr($text, $i, 1)) - ord("A"), 0x8108);
	}

	my ($offset) = find_one($memory_ref, quotemeta($list));

	return $offset;
}

sub patch_invincible
{
	my ($memory_ref, $free, $limit) = @_;

	my ($cursor_limit) = find_one($memory_ref, qr/\xB1\xBC\x8A\x25....\xF6\xC2\x01/);
	my ($exit_handler) = find_one($memory_ref, qr/\x80\xFC\xBC\x75.\xF6\xC2\xB0/);
	my ($debug_handler) = find_one($memory_ref, qr/\x80\xFC\xC8\x75.\xF6\xC2\x3C\x74.\x66\xF7\x15..../);
	my ($draw, $setup_list, $draw_call) = find_one($memory_ref, qr/\xBE(....)\xE8(....)\x32\xC0\xC3/);
	my ($damage) = find_one($memory_ref, qr/\x66\x0F\xBE\xC0\x66\x29\x83\x88\x00\x00\x00\x7E/);
	my (undef, $hp_1p, $hp_2p, $player_1p) = find_one($memory_ref, qr/\x66\x83\x3D(....)\x00\x7E.\x66\x83\x3D(....)\x00\x7E.\xBB(....)/);

	$setup_list = unpack("V", $setup_list);
	my $draw_list = ($draw + 10 + unpack("l", $draw_call)) & 0xFFFFFFFF;
	$player_1p = unpack("V", $player_1p);
	my $player_2p = unpack("V", $hp_2p) - 0x88;

	die "Unexpected SET UP menu layout.\n" if(unpack("V", substr($$memory_ref, $setup_list, 4)) != 82);

	# Move the unused ON/OFF lists up to the new row.
	my $on_list = find_value_list($memory_ref, "ON", 204);
	my $off_list = find_value_list($memory_ref, "OFF", 204);

	foreach my $list ($on_list, $off_list)
	{
		for(my $i = 0; $i < unpack("V", substr($$memory_ref, $list, 4)); $i ++)
		{
			substr($$memory_ref, $list + 4 + $i * 8 + 2, 2) = pack("v", 192);
		}
	}

	# EXIT moves down one row.
	my $moved = 0;

	for(my $i = 0; $i < 82; $i ++)
	{
		my $record = $setup_list + 4 + $i * 8;

		if(unpack("v", substr($$memory_ref, $record + 2, 2)) == 192)
		{
			substr($$memory_ref, $record + 2, 2) = pack("v", 204);
			$moved ++;
		}
	}

	die "Unexpected SET UP menu layout.\n" if($moved != 4);

	my $flag = $free;
	my $label = $flag + 4;
	my $text = "INVINCIBLE";

	substr($$memory_ref, $flag, 4) = "\0" x 4;
	substr($$memory_ref, $label, 4) = pack("V", length($text));

	for(my $i = 0; $i < length($text); $i ++)
	{
		substr($$memory_ref, $label + 4 + $i * 8, 8) = pack("v4", 40 + $i * 8, 192, 0x391 + ord(substr($text, $i, 1)) - ord("A"), 0x8108);
	}

	my $draw_hook = ($label + 4 + length($text) * 8 + 15) & ~15;

	my $code = "\x60";                                          # pushad
	$code .= "\xBE" . pack("V", $label);                        # mov esi,label
	$code .= call_rel($draw_hook + length($code), $draw_list);  # call draw_list
	$code .= "\xBE" . pack("V", $off_list);                     # mov esi,off_list
	$code .= "\x66\x83\x3D" . pack("V", $flag) . "\x00";        # cmp word [flag],0
	$code .= "\x74\x05";                                        # je +5
	$code .= "\xBE" . pack("V", $on_list);                      # mov esi,on_list
	$code .= call_rel($draw_hook + length($code), $draw_list);  # call draw_list
	$code .= "\x61";                                            # popad
	$code .= "\xBE" . pack("V", $setup_list);                   # mov esi,setup_list
	$code .= "\xC3";                                            # ret

	substr($$memory_ref, $draw_hook, length($code)) = $code;

	my $damage_hook = ($draw_hook + length($code) + 15) & ~15;

	$code = "\x66\x0F\xBE\xC0";                                 # movsx ax,al
	$code .= "\x66\x83\x3D" . pack("V", $flag) . "\x00";        # cmp word [flag],0
	$code .= "\x74\x13";                                        # je apply
	$code .= "\x81\xFB" . pack("V", $player_1p);                # cmp ebx,player_1p
	$code .= "\x74\x08";                                        # je zero
	$code .= "\x81\xFB" . pack("V", $player_2p);                # cmp ebx,player_2p
	$code .= "\x75\x03";                                        # jne apply
	$code .= "\x66\x31\xC0";                                    # zero: xor ax,ax
	$code .= "\x66\x29\x83\x88\x00\x00\x00";                    # apply: sub [ebx+0x88],ax
	$code .= "\xC3";                                            # ret

	die "Patch does not fit in the Japanese font area.\n" if($damage_hook + length($code) > $limit);

	substr($$memory_ref, $damage_hook, length($code)) = $code;

	substr($$memory_ref, $cursor_limit + 1, 1) = "\xC8";
	substr($$memory_ref, $exit_handler + 2, 1) = "\xC8";
	substr($$memory_ref, $debug_handler + 2, 1) = "\xBC";
	substr($$memory_ref, $debug_handler + 13, 4) = pack("V", $flag);
	substr($$memory_ref, $draw, 5) = call_rel($draw, $draw_hook);
	substr($$memory_ref, $damage, 11) = call_rel($damage, $damage_hook) . ("\x90" x 6);

	return ($flag, ($damage_hook + length($code) + 3) & ~3);
}

sub patch_scenes
{
	my ($memory_ref, $font_base, $free, $limit) = @_;

	return $free if(!@continued_units);

	my ($dispatch, $table) = find_one($memory_ref, qr/\xC1\xE6\x02\x2E\x8B\xB6(....)/);
	$table = unpack("V", $table);

	my $script_base = $font_base - (96 * 36 + 6 * 48);
	my %pseudo;

	for(my $i = 0; $i < scalar(@continued_units); $i ++)
	{
		push(@{$pseudo{$script_base + $continued_units[$i] * 36}}, $font_base + $i * 36);
	}

	my @scenes;
	my $first = unpack("V", substr($$memory_ref, $table, 4));

	for(my $address = $table; $address < $first; $address += 4)
	{
		push(@scenes, unpack("V", substr($$memory_ref, $address, 4)));
		$first = $scenes[-1] if($scenes[-1] < $first);
	}

	my %used;

	for(my $i = 0; $i < scalar(@scenes); $i ++)
	{
		my $list = "";
		my $position = $scenes[$i];

		while((my $value = unpack("V", substr($$memory_ref, $position, 4))) != 0xFFFFFFFF)
		{
			if($value == 0)
			{
				my ($zac, $mel, $color) = unpack("V3", substr($$memory_ref, $position + 4, 12));
				$list .= pack("V4", 0, $zac, $mel, $color);

				if($pseudo{$zac} || $pseudo{$mel})
				{
					die "Both lines of a boy/girl pair need the same number of boxes.\n" if(!$pseudo{$zac} || !$pseudo{$mel} || scalar(@{$pseudo{$zac}}) != scalar(@{$pseudo{$mel}}));

					for(my $j = 0; $j < scalar(@{$pseudo{$zac}}); $j ++)
					{
						$list .= pack("V4", 0, $pseudo{$zac}->[$j], $pseudo{$mel}->[$j], $color);
					}

					$used{$zac} = $used{$mel} = 1;
				}

				$position += 16;
			}
			else
			{
				my $color = unpack("V", substr($$memory_ref, $position + 4, 4));
				$list .= pack("V2", $value, $color);

				if($pseudo{$value})
				{
					$list .= pack("V2", $_, $color) foreach(@{$pseudo{$value}});
					$used{$value} = 1;
				}

				$position += 8;
			}
		}

		$list .= pack("V", 0xFFFFFFFF);

		die "Scene lists do not fit in the Japanese font area.\n" if($free + length($list) > $limit);

		substr($$memory_ref, $free, length($list)) = $list;
		substr($$memory_ref, $table + $i * 4, 4) = pack("V", $free);
		$free += length($list);
	}

	foreach my $address (keys %pseudo)
	{
		die "Entry " . (($address - $script_base) / 36) . " isn't shown through a scene list, so it can't have a continuation box.\n" if(!$used{$address});
	}

	return $free;
}

sub patch_credits
{
	my ($memory_ref) = @_;

	my ($last_row) = find_one($memory_ref, qr/\\VING  CORPORATION {14}\xFF\xFF/);
	my $table = $last_row + 32 - length($credits_en);

	die "Staff roll not found where expected.\n" if(substr($$memory_ref, $table + 14 * 32, 19) ne "^ Congratulations!!");

	substr($$memory_ref, $table, length($credits_en)) = $credits_en;
}

sub title_sprites
{
	my ($text, $y, $attr) = @_;

	my %glyphs = (".", 0x38A);
	my $x = 128 - length($text) * 4;
	my @sprites;

	foreach my $character (split(//, $text))
	{
		my $pattern = ($character =~ /[0-9A-Z]/) ? 0x350 + ord($character) : $glyphs{$character};

		die "Title text uses \"$character\", which has no sprite glyph.\n" if($character ne " " && !defined($pattern));

		push(@sprites, pack("v4", $x, $y, $pattern, $attr)) if($character ne " ");
		$x += 8;
	}

	return pack("V", scalar(@sprites)) . join("", @sprites);
}

sub patch_title
{
	my ($memory_ref, $free, $limit, $list) = @_;

	my ($copyright) = find_one($memory_ref, quotemeta(pack("V v4", 19, 0x50, 0xBA, 0x390, 0x8106)));
	my ($site, $draw) = find_one($memory_ref, qr/\xBE\Q${\pack("V", $copyright)}\E\xE8(....)/);
	$draw = $site + 10 + unpack("V", $draw);
	$draw -= 0x100000000 if($draw >= 0x100000000);

	my $stub = $free + length($list);
	my $code = "\xBE" . pack("V", $copyright);                 # mov esi,copyright list
	$code .= call_rel($stub + 5, $draw);                         # call draw_sprites
	$code .= "\xBE" . pack("V", $free);                          # mov esi,version list
	$code .= call_rel($stub + 15, $draw);                        # call draw_sprites
	$code .= "\xC3";                                             # ret

	die "Title screen patch does not fit in the Japanese font area.\n" if($stub + length($code) > $limit);

	substr($$memory_ref, $free, length($list)) = $list;
	substr($$memory_ref, $stub, length($code)) = $code;
	substr($$memory_ref, $site, 10) = call_rel($site, $stub) . ("\x90" x 5);
}

sub build_exp
{
	my ($exp, $memory) = @_;

	my $info = exp_info($exp);
	my $stream = encode_stream($memory);

	die "Compressed data is " . (length($stream) - $info->{eip}) . " byte(s) too large.\n" if(length($stream) > $info->{eip});

	my $image = $stream . ("\0" x ($info->{eip} - length($stream))) . substr($info->{image}, $info->{eip});

	# The stub only moves the stream itself up to the top of the segment, so it ends where the original data did.
	substr($image, $info->{eip} + 0x1F, 10) = "\xBE" . pack("V", length($stream) - 1) . "\xB9" . pack("V", length($stream));

	my $new_exp = substr($exp, 0, $info->{header_size}) . $image;

	# Make sure the unpack stub gives back the patched image.
	my ($result, $end) = unpack_in_place($new_exp);
	substr($result, $info->{stack} - 4, 4) = substr($memory, $info->{stack} - 4, 4);

	die "Recompressed EXP does not unpack correctly.\n" if($end != length($memory) || substr($result, 0, $end) ne $memory);

	return $new_exp;
}
