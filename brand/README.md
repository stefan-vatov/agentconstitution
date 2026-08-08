# Brand kit

The mark is the nib, derived from the constitution's own language: the vent
is *the point* (Fig. I's ring), the slit is *the bearing* (direction, never
details), and the slit splits the tip into two tines — two ways in, one pen
(P4, "Only a human holds the pen"). Canonical geometry lives in `mark.svg`;
every other asset is that path re-colored or framed.

Files:

- `mark.svg` — bare nib, `currentColor`, mask-carved (safe on any background)
- `tile.svg` — paper nib on the seal-red tile (same artwork as
  `public/favicon.svg`)
- `mark-seal-1024.png` / `mark-paper-1024.png` — transparent bare marks,
  seal red and paper (for dark surfaces)
- `tile-1024.png` — transparent-cornered tile
- `lockup.png` — transparent horizontal lockup (tile + wordmark)
- `board.html` → `brand-kit.png` — the 3 × 3 identity board; tokens are
  copied from `src/styles/global.css`, fonts are the site's vendored
  Newsreader subsets (`src/assets/fonts/`)

Site-served assets (`public/favicon.svg`, `og.png`, `apple-touch-icon.png`,
`icon-192.png`, `icon-512.png`) carry the same nib; the OG image's source is
`og.html` here — sibling of `board.html`.

To re-render the board (same command works for `og.html` at 1200 × 630 with
`--force-device-scale-factor=2`, then downscale to 1200 wide):

    cd brand
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
      --headless=new --disable-gpu --allow-file-access-from-files \
      --force-device-scale-factor=2 --window-size=1600,1200 \
      --screenshot=brand-kit.png "file://$PWD/board.html"

For transparent PNGs add `--default-background-color=00000000` and render at
`--force-device-scale-factor=1` (Chrome clamps small windows — render ≥ 512
and downscale with `sips -z`).

The board is presentation collateral, not a site asset — nothing in `src/`
or `public/` depends on files here.
