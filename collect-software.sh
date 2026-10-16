#!/bin/sh
# Copy disk images the IMSAI drive can open, and paper tapes the reader can load.
set -eu

root=/src/z80pack
lib="$root/imsaisim/disks/library"
tapes="$root/imsaisim/tapes"
mkdir -p "$lib" "$tapes"

# These images are the right size, but none of the systems that boot on
# this IMSAI can read them. Altair UCSD Pascal I.5 uses a different volume
# layout than UCSD Pascal IV. The Mostek disks below use Mostek's own
# directory, not the IBM 8-inch directory used by CP/M and IMDOS.
skip_incompatible() {
  case $1 in
    altair-ucsd-i5-1.dsk|altair-ucsd-i5-2.dsk|altair-ucsd-i5-interp.dsk|\
    mostek-BASIC-GAMES.dsk|mostek-BASIC-INTERPRETER.dsk|mostek-CPM-LINK.dsk|\
    mostek-FLP-80DOS_ENATECHNIK.dsk|mostek-FLP-80DOS_MOSTK.dsk|\
    mostek-MOS-80.dsk|mostek-OLYMPIA-WERKE-SE11.dsk|mostek-WORD.dsk)
      return 0
      ;;
  esac
  return 1
}

copy_sized() {
  src=$1
  prefix=$2
  for f in "$src"/*; do
    [ -f "$f" ] || continue
    size=$(stat -c%s "$f")
    base=$(basename "$f")
    lower=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')
    case "$size" in
      256256)
        dest="${prefix}${base}"
        skip_incompatible "$dest" && continue
        cp --update=none "$f" "$lib/$dest"
        ;;
      4177920)
        stem=${lower%.dsk}
        cp --update=none "$f" "$lib/${prefix}${stem}.hdd"
        ;;
    esac
  done
}

copy_sized "$root/cpmsim/disks/library" "cpm-"
copy_sized "$root/altairsim/disks/library" "altair-"
copy_sized "$root/cromemcosim/disks/library" "cromemco-"
copy_sized "$root/mosteksim/disks/CPM" "mostek-"
copy_sized "$root/mosteksim/disks/FLP-80" "mostek-"
copy_sized "$root/mosteksim/disks/MOS-80" "mostek-"
copy_sized "$root/picosim/disks" "pico-"

cp -n "$root"/imsaisim/*.hex "$tapes/"
cp -n "$root"/imsaisim/roms/*.hex "$tapes/"
for f in "$root"/altairsim/*.hex "$root"/altairsim/roms/*.hex; do
  [ -f "$f" ] || continue
  cp -n "$f" "$tapes/altair-$(basename "$f")"
done
for f in "$root"/cromemcosim/*.hex "$root"/cromemcosim/roms/*.hex; do
  [ -f "$f" ] || continue
  cp -n "$f" "$tapes/cromemco-$(basename "$f")"
done

echo "library disks: $(find "$lib" -type f | wc -l)"
echo "paper tapes: $(find "$tapes" -type f | wc -l)"
