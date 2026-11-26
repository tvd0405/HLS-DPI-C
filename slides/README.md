# DPI-C ↔ ap_fixed — tutorial slides

A 20-slide, self-contained HTML deck explaining how fixed-point values cross the
SystemVerilog / C DPI boundary. No network access, fonts, or JavaScript libraries
are fetched — `index.html` is the whole deck.

## Open it

```bash
firefox slides/index.html          # or: xdg-open slides/index.html
```

Keys: **← →** (or space) navigate · **Home / End** jump · **F** fullscreen ·
**P** print. Clicking the left third / right two-thirds of a slide also moves.

Deep links work: `index.html#slide-9` opens the `from_bits()` slide.

## Export to PDF

Print from the browser (`P`, or Ctrl+P), then:

- Destination: **Save as PDF**
- Layout: **Landscape**
- Margins: **None**
- **Background graphics: on** (otherwise the code panels and colours drop out)

Each `<section class="slide">` is one 1280×720 page (`@page` is set in the CSS).

## Outline

| # | Slide | Substance |
|---|-------|-----------|
| 1 | Title | Same bits, two binary points |
| 2 | There is no fixed-point DPI type | DPI type-mapping table; `ap_fixed` is absent |
| 3 | Two worlds | What SV knows vs what the C++ type knows; the contract |
| 4 | ap_fixed in one slide | W, I, F = W−I; `data_t` / `out_t` ranges and LSBs |
| 5 | HLS flattens ap_fixed | FIFO pragmas → 11/21-bit ports in `dut.v` |
| 6 | One element = one raw word | Four transport rules; 32-bit word layouts |
| 7 | Who converts what | The 8 conversion points, with file:line |
| 8 | The round trip is the identity | Why a raw-word scoreboard is trustworthy |
| 9 | `from_bits()` | C → `ap_fixed`: `x.V = ap_private<W,true>(...)`, `uint32_t` cast |
| 10 | `raw_bits()` | `ap_fixed` → C: `get_VAL()` + mask |
| 11 | Sign-extend and compare | `sign_extend()`, normalize both sides to 21 bits |
| 12 | Slice in, sign-extend out | `[10:0]` and `$signed(c_din)` in `Tb_hls.sv` |
| 13 | Powers of two | 0.5 × 0.25 → raw `0x200` × `0x100` = `0x20000` |
| 14 | Round once, then stay exact | 0.7 × 0.3, AP_RND, AP_SAT at 1.0 |
| 15 | The `double` alternative | Exact for W ≤ 53, but not a wire |
| 16 | Wider than 32 bits | `longint` / `svBitVecVal*`, 32-bit chunk layout |
| 17 | Signature rules that bite | Open arrays, function vs task, `context`, generated header |
| 18 | Build and run | `make simc && make libdpi_hls && make simrun`; `TEST PASSED` |
| 19 | Eight ways to get this wrong | Compile-clean failure modes |
| 20 | Summary and recipe | Carrier-picking table + three takeaways |

Everything shown is drawn from this repository. Slide 16 marks the wide-vector
paths as guidance because the current test only exercises W ≤ 32.

## Editing

- One slide = one `<section class="slide">`; the order in the file is the order
  in the deck. Page numbers, footer marks and the progress bar are generated.
- The 32-cell bit strips on slide 6 are filled from
  `<div class="bits" data-raw="11" data-tone="a">`; change `data-raw` to the
  type width and `data-tone` to `a` or `c` for the colour.
- Colours, spacing and the code theme live in the `:root` variables at the top.
- Keep the deck self-contained: no CDN links, no web fonts. Anything added here
  must load from the file itself.

## Source of the examples

- `hls/define.h` — `data_t = ap_fixed<W+1,1,AP_RND,AP_SAT>`,
  `out_t = ap_fixed<2W+1,1,AP_RND,AP_SAT>`, `W = 10`, `N = 1024`
- `src/cpp/dpi_hls_model.cpp` — `raw_bits()`, `sign_extend()`, `from_bits()`,
  stimulus and scoreboard
- `src/v/Tb_hls.sv` — imports, part-select, `$signed(c_din)`
- `wdir/hls/impl/verilog/dut.v` — generated 11-bit / 21-bit ports
- `Makefile` — `-dpiimpheader`, `-dpi_void_task`, shared-library build
- `sim_64/sim_run.log` — `TEST PASSED (1024 vectors)`, Xcelium 26.03-s004
