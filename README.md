# Pu-Li-Ru-La

<img align="right" src="https://github.com/DerekPascarella/PuLiRuLa-EnglishPatchFMTowns/blob/main/cover.jpg?raw=true" width="156">English translation patch for the arcade beat 'em up "Pu-Li-Ru-La" on the FM Towns/FM Towns Marty.

In the storybook kingdom of Radish Land, every town keeps its clocks ticking with a magical Key of Time. That is, until a sinister villain swipes the keys one by one, freezing entire towns in their tracks. Armed with magic rods and plenty of pluck, young heroes Zac and Mel set out to take the keys back and get time flowing again.

Originally unleashed on arcades by Taito in 1991 and brought home to the FM Towns by VING in 1994, "Pu-Li-Ru-La" is one of the most delightfully bizarre games ever made. Bop an enemy and it turns back into a fleeing animal. Wander into crystal mountains, dream-warped towns, and scorched deserts. Face down foes that only get stranger with every stage. It's a psychedelic picture book come to life, and now it can finally be enjoyed in English on the FM Towns.

The latest version of this patch is [1.0](https://github.com/DerekPascarella/PuLiRuLa-EnglishPatchFMTowns/releases/download/1.0/Pu-Li-Ru-La.English.v1.0.zip).

## Table of Contents

1. [Patching Instructions](#patching-instructions)
2. [Credits](#credits)
3. [Release Changelog](#release-changelog)
4. [What's Changed](#whats-changed)
5. [About the Game](#about-the-game)
6. [How to Play](#how-to-play)

## Patching Instructions

This English translation patch release includes a custom patch-applying kit. It specifically targets the [Redump](https://redump.info/disc/16685) rip, and no other version of the original source disc image can be used.

To apply the patch, follow the steps below.

1. Extract the [latest release package ZIP](https://github.com/DerekPascarella/PuLiRuLa-EnglishPatchFMTowns/releases/download/1.0/Pu-Li-Ru-La.English.v1.0.zip) to any folder of your choosing.
2. Place the entire Redump disc image in the `redump_original` folder.
3. Launch the `apply_patch.bat` script and watch for status messages as it applies the patch.
4. Upon successful completion, patched disc images will reside in the following folders. These disc images are acceptable for burning to CD-R, using with an ODE, or using with an emulator.
   - `disc_image_patched_cue_bin` and `disc_image_patched_ccd_img_sub` (standard version)
   - `disc_image_patched_marty_exp_ram_cue_bin` and `disc_image_patched_marty_exp_ram_ccd_img_sub` (Marty expanded RAM version, see [What's Changed](#whats-changed))

## Credits

- **Hacking / Programming**
  - Derek Pascarella (ateam)
- **Translation**
  - DaVince21
  - Walnut
- **Playtesting**
  - Josh (hasnopants)
- **Special Thanks**
  - KoolFiller (for his work on the SEGA Saturn "Arcade Gears Vol. 1: Pu-Li-Ru-La" English translation patch, which both inspired and helped the FM Towns patch become a reality)

## Release Changelog

- Version 1.0 (2026-10-05)
  - Initial release.

## What's Changed

<img align="right" src="https://github.com/DerekPascarella/PuLiRuLa-EnglishPatchFMTowns/blob/main/screenshot1.png?raw=true" width="250">

- All story text has been translated into English, including the intro sequence and all in-game dialogue.
  - The script is based on [DaVince21's](https://docs.google.com/document/d/1FELj57dNtKLiWZ7nelXNtjIiWfKBS4pbEM6tsPDj-3c) complete retranslation of the game, not the error-riddled official translation from the arcade release. The text has been edited and, in some cases, re-translated by Walnut. A handful of DaVince21's lines have been trimmed slightly to fit within the FM Towns version's fixed-size text boxes and intro pages.
  - In the event it can be restored some day, unused dialogue left over from the arcade original, still present in the FM Towns version's data, has also been translated by Walnut.
  - Wherever the game's code allowed it, available text space has been expanded so that longer lines are shown in full across additional text boxes.
- The game's text engine has been modified so that every Japanese 16x16 character cell now draws two 8x16 English characters using the original English font from the arcade release, doubling the width of every line of text.
- The game's scripted dialogue sequences have been rebuilt to insert additional text boxes wherever a line runs long.
- The staff credits shown during the ending have been cleaned up (e.g., "EXECTIVE PRODUCER" and "Thank you for your playing!" are now "EXECUTIVE PRODUCER" and "Thank you for playing!", among others), and a new "ENGLISH TRANSLATION" section credits the team behind this patch.
- A new "INVINCIBLE" option has been added to the SET UP menu (off by default), allowing players to take hits without losing health.
- An optional Marty expanded RAM version is included, built with the same patch as the standalone [Pu-Li-Ru-La Expanded RAM Patch](https://github.com/DerekPascarella/PuLiRuLa-ExpandedRAMPatchFMTownsMarty). For FM Towns Marty owners with an aftermarket RAM add-on, it unlocks the game's extended mode, which is otherwise locked out on the Marty. Note that this extended mode runs very slowly when the console has 4 MB of total RAM, but runs smoothly when it has only 3 MB. The list below outlines the unlocked features.
  - The anti-infinite-combo enemy Sokushin Boots spawns when lingering on bosses or abusing juggles.
  - Three sound-effect samples absent from 2 MB mode are loaded and played.
  - The large parallax layer at the start of Stage 6 is fully present instead of being cut.
  - The rare screen-clearing magic attacks "Rapman" and "Mr. MIKATA" become available again.
  - The four mid-stage CD load pauses disappear, giving seamless play.

## About the Game

| | |
|---|---|
| **Original Title** | Pu-Li-Ru-La (プリルラ) |
| **Original Arcade Developer** | Taito |
| **FM Towns Developer and Publisher** | VING |
| **Release Date** | November 1994 |
| **Compatibility** | FM Towns, FM Towns Marty |

## How to Play

<img align="right" src="https://github.com/DerekPascarella/PuLiRuLa-EnglishPatchFMTowns/blob/main/screenshot2.png?raw=true" width="250">

- **CD-R**

  The English-patched version of this game can be burned to CD-R and played on FM Towns Marty or any FM Towns computer.

- **ODE (Optical Drive Emulator)**

  The English-patched version of this game (in CCD/IMG/SUB format) is compatible with both the [DocBrown](https://gdemu.wordpress.com/details/docbrown-details/) and [Wizard](https://gdemu.wordpress.com/details/wizard-details/) ODEs for the FM Towns Marty and the FM Towns, respectively.

- **Emulator**

  The English-patched version of this game is compatible with the [Tsugaru](https://github.com/captainys/TOWNSEMU) emulator, and likely [Unz](http://townsemu.world.coocan.jp/download.html) as well.
