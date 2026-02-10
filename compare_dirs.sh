#!/usr/bin/env bash
set -euo pipefail

# Configuration
SRC="/path/to/primary-documents"      # authoritative source
DST="/path/to/backup-disk/documents"  # backup destination
OUT="comparison_$(date +%Y%m%d-%H%M%S).csv"

# Exclusions: hidden folders and common junk / temp files
RSYNC_EXCLUDES=(
  --exclude='/.*/'
  --exclude='.DS_Store'
  --exclude='*.tmp'
  --exclude='*.temp'
)

# Write CSV header
echo "relative_path,change_type,authoritative_side" > "$OUT"

# Export SRC and DST for awk access
export SRC DST

# Run rsync dry-run comparison and process output
rsync -ain --delete \
  "${RSYNC_EXCLUDES[@]}" \
  "${SRC}/" "${DST}/" |
awk '
BEGIN {
  total = 0
}

{
  # Full itemized string is first 11 chars
  item = substr($0, 1, 11)

  # Path starts after itemized string + space
  path = substr($0, 13)

  if (path == "") next

  # Classification logic
  if (item ~ /^>f\+{9}/) {
    type = "missing_in_dest"
  }
  else if (item ~ /^>f/ ) {
    type = "outdated_in_dest"
  }
  else {
    next
  }

  print path "," type ",src"
  total++
  count[type]++
}

END {
  print "# ------------------------------------------------------------"
  print "# SUMMARY"
  print "# ------------------------------------------------------------"
  print "# total_differences," total
  for (t in count)
    print "# " t "," count[t]

  print ""
  print "# ------------------------------------------------------------"
  print "# CONTEXT"
  print "# ------------------------------------------------------------"
  print "# source_path," ENVIRON["SRC"]
  print "# destination_path," ENVIRON["DST"]
}
' >> "$OUT"

echo "Comparison complete. Results saved to: $OUT"
