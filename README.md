# nxadd

nxadd adds a Switch game you dumped from your own console to [NX Play](https://github.com/varyform/nx-native-wrapper), the Mac app that builds and plays games with [nxnative](https://github.com/seedds/nxnative). It puts the game's files in your games folder, on your Mac or on an external drive, and can start the build.

It does the file handling around a build:

- copies the game files and checks every copy byte for byte
- unpacks `.7z`, `.zip` and `.rar` downloads
- reads the game's title ID and tells you whether nxnative supports the game
- checks there is enough free space before copying
- sets up a disk image on exFAT and FAT32 drives (see [External drives](#external-drives))
- adds the games folder to NX Play
- offers to delete the download from your Mac once the copy on an external drive is checked

## Before you start

nxadd copies games without any of these, but building needs all of them. nxadd checks them each time it runs and tells you what is missing.

1. **A Mac with Apple silicon.**
2. **NX Play**, installed in Applications, with its setup finished: open NX Play, go to Settings › Setup and click **Install Missing**. This installs Xcode's Metal compiler, the Homebrew tools, Python and nxnative.
3. **Your keys**: `prod.keys` dumped from your own Switch (for example with Lockpick_RCM), saved as `~/.switch/prod.keys`.
4. **Optional:** `7z`, to unpack archives (`brew install p7zip`). nxadd offers to install it when it needs it.

## Install

```sh
git clone https://github.com/qu-bit1/nxadd.git
cd nxadd
./install.sh
```

This puts `nxadd` in `~/.local/bin`. If that folder isn't on your PATH, the installer prints the line to add to `~/.zshrc`.

## Use

Run `nxadd` and answer its questions. The first time, it asks where to keep your games:

```
$ nxadd

nxadd · add a Switch game for NX Play

● Before you start
  ✓ NX Play and its setup
  ✓ prod.keys (/Users/you/.switch/prod.keys)

● Setup: where should your games live?
  ? Where do you want to keep your games?
      1  On this Mac (~/Games)
      2  On an external drive
    › 2
  ? Which drive?
      1  Lexar (exFAT, 660.4 GB free)
    › 1
  · Lexar is formatted exFAT. A disk image on it keeps your games safer if the drive is
  · unplugged mid-write, and saves about 10 GB per game. It grows as you add games.
  ? Keep your games in a disk image on Lexar? (Y/n)
  ✓ Saved: games go in /Volumes/NXGames (inside Lexar/NXGames.sparsebundle)

● Games folder
  ✓ /Volumes/NXGames (inside Lexar/NXGames.sparsebundle)
```

Then, and on every later run, it asks for the game. Type the path to its file, folder or archive, or drag it into the Terminal window:

```
  ? Where is the game? Type the path to its file, folder or archive (or drag it into this window), then press Return
    › ~/Downloads/Metroid Prime Remastered

● Game files
  ✓ Metroid Prime Remastered.nsp (7.3 GB)
  ✓ Metroid Prime Remastered (010012101468C000) is supported by nxnative
  · what's known about it: ~/Library/Application Support/NX Play/nxnative/dm/games/010012101468C000/README.md
  ? Call it "Metroid Prime Remastered"? (Y/n)
  ✓ 7.3 GB to copy; 673.4 GB free (about 24.5 GB needed while it builds)

● Copy to /Volumes/NXGames/Metroid Prime Remastered
  ✓ Metroid Prime Remastered.nsp (copied and checked)

  ? The copy is checked. Delete the download from this Mac to free 7.3 GB? (y/N)

● NX Play
  ✓ NX Play already shows /Volumes/NXGames

  ? Build it now? A big game can take an hour; keep the Mac plugged in. (Y/n)
```

When it finishes, open NX Play and play the game.

A game folder holds one game: its base game, plus its update and DLC if you have them. nxnative's [games list](https://github.com/seedds/nxnative/blob/main/dm/games/README.md#games) shows which games run and which update each was tested on.

### Options

```
nxadd                                 asks for everything
nxadd [options] <name> <source>...    no questions: copies <source> into <games folder>/<name>
nxadd --setup                         choose again where your games are kept

--build              build after copying
--delete-download    delete the download from this Mac once the copy on an external drive is checked
--dry-run            check everything and say what would happen; copy and build nothing
--yes                take the default answer to every question
```

Your answers from the setup are kept in `~/.config/nxadd/config`.

## External drives

On an APFS drive, nxadd uses a folder called `NXGames`.

exFAT and FAT32 drives get an APFS disk image instead: `NXGames.sparsebundle` at the top of the drive, which opens as a drive called NXGames. It starts empty and grows as you add games. It has two advantages:

- If the drive is unplugged in the middle of a write, only the disk image can be damaged, not the rest of the drive.
- NX Play's Mac apps share data with the build instead of copying it, which saves about 10 GB per game.

FAT32 can't hold files over 4 GB, so on FAT32 the disk image is required. NTFS drives are read-only on a Mac and can't be used.

To play from the drive: plug it in, double-click `NXGames.sparsebundle`, then open NX Play. When you're done, eject NXGames, then the drive. nxadd opens the disk image by itself when it needs it.

Deleting a game inside the disk image doesn't make the image smaller on the drive. To get the space back, eject NXGames and run:

```sh
hdiutil compact /Volumes/<your drive>/NXGames.sparsebundle
```

## What nxadd won't do

- It never formats or erases a drive. The only thing it creates outside your games folder is the disk image file, and only after you say yes.
- It writes only inside the games folder you chose.
- It deletes a download only when you say so (the default answer is no), only from your Mac, and only after the copy on the external drive was checked byte for byte or unpacked with 7z's own checks.

## Troubleshooting

- **"the shader compile cache … is damaged"** during a build on the disk image: run the same command again. It happened once, on a first build with Spotlight indexing the image; nxadd now turns Spotlight off on the disk image.
- **"the drive with your games isn't connected"**: plug the drive in and run nxadd again.
- **A game isn't in nxnative's games list**: the build guesses its settings, and the game may not start.
- **Your dump's version isn't the one nxnative tested**: it still builds, without the fixes recorded for the tested version. Adding that update usually helps.
- **To start over**: `nxadd --setup`.

## Tests

```sh
tests/run.sh
```

The tests use throwaway disk images (an APFS, an exFAT and a FAT32 drive), a stand-in NX Play and fake game files. Your real drives, games and NX Play settings are not touched.

## Legal

nxadd only copies files you already have. Use it with games and keys you dumped from your own Switch. It doesn't download games or keys and never sends anything anywhere.

nxadd is not affiliated with Nintendo, nxnative or NX Play.

## License

MIT, see [LICENSE](LICENSE).
