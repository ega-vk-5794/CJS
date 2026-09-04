# Find an assignment that sits OUTSIDE its VALUE #( ) row.
#
# Depth-aware, because "ends with )" is not the test: a nested method call
# closes a paren too, so `iv_fb = 'x' )` looks like a closed row and every
# following assignment looks orphaned. Real rule:
#
#   INSERT ... FROM TABLE @( VALUE #(   -> table sits at depth 2, each row at 3
#   INSERT ... FROM @( VALUE #(         -> single row, assignments at depth 2
#
# so an assignment seen at the TABLE depth, on a line that does not itself
# open a row, is outside every row.

/^[[:space:]]*\*/ { next }

/^  INSERT / {
  ins  = 1
  d    = 0
  # single-row form has no TABLE between FROM and @(
  rowd = ($0 ~ /FROM TABLE @\(/) ? 3 : 2
}

ins {
  before = d

  # net paren movement on this line
  o = gsub(/\(/, "(")
  c = gsub(/\)/, ")")
  d = before + o - c

  if ($0 ~ /[a-z_][a-z_0-9]* = /) {
    opener = ($0 ~ /^[[:space:]]*\(/)
    # inside a row: before >= rowd. A row-opening line reports before = rowd-1.
    if (before < rowd - (opener ? 1 : 0))
      printf "%s:%d  OUTSIDE ROW (depth %d, rows at %d): %s\n", FILENAME, FNR, before, rowd, $0
  }

  if (d <= 0) ins = 0
}
