# DESIGN.md — Design System & UI Specification
## MetaStrip: Metadata Viewer & Remover
**Version:** 1.0.0  
**Design Language:** Industrial Minimalism  
**Last Updated:** 2026-08-07

---

## 1. Design Philosophy

### 1.1 Core Concept: "Industrial Minimalism"
MetaStrip dirancang dengan filosofi **Industrial Minimalism** — sebuah pendekatan desain yang mengambil inspirasi dari estetika pabrik dan utilitarian tool, dikombinasikan dengan kejelasan fungsional yang ekstrem.

**Pilar desain:**
- **Brutally Functional** — Setiap elemen UI memiliki tujuan. Tidak ada dekorasi tanpa fungsi.
- **High Contrast, Low Noise** — Informasi penting menonjol. Background menekan diri ke belakang.
- **Mechanical Precision** — Grid ketat, spacing konsisten, alignment pixel-perfect.
- **Tactical Accents** — Warna aksen digunakan sparingly untuk signaling, bukan estetika semata.

### 1.2 Visual Personality
- **Dark by default** — Latar belakang gelap mendominasi (seperti terminal, mesin industri)
- **Monospace & Geometric** — Font teknis yang mengesankan presisi dan keandalan
- **Subtle texture** — Noise texture ringan pada background untuk menghindari kesan flat yang steril
- **Angular, not rounded** — Border radius minimal, sudut tajam mendominasi
- **Rust + Steel palette** — Palet warna mengambil dari material industri: besi, karat, beton

---

## 2. Color System

### 2.1 Default Theme — "Dark Industrial"
```
Primary Background:    #0D0D0D  (near-black, charcoal)
Secondary Background:  #1A1A1A  (card surface)
Tertiary Background:   #242424  (elevated surface, input field)
Border/Divider:        #2E2E2E  (subtle separator)
Border Emphasis:       #404040  (active border, hover)

Text Primary:          #E8E0D0  (warm white, aged paper feel)
Text Secondary:        #9A9080  (muted, caption text)
Text Tertiary:         #5A5248  (very muted, placeholder)
Text Inverse:          #0D0D0D  (on accent button)

Accent Primary:        #C94B1A  (rust orange — CTA, active state, marked items)
Accent Secondary:      #E8A040  (amber — warning, secondary action)
Accent Success:        #4A8C5A  (muted green — success state)
Accent Danger:         #8C2A2A  (deep red — destructive action)
Accent Info:           #2A5A8C  (steel blue — informational)

Privacy Warning:       #C94B1A  (sama dengan accent primary — GPS, location data)
Overlay:               #0D0D0D CC (80% opacity black for modals)
```

### 2.2 Alternate Theme — "Steel Blue"
```
Primary Background:    #0A1628
Secondary Background:  #112038
Tertiary Background:   #1A2E4A
Border/Divider:        #243850
Text Primary:          #E0E8F0
Text Secondary:        #8090A8
Accent Primary:        #2E7DD1
Accent Secondary:      #5BB8E8
Accent Success:        #3A9C6A
Accent Danger:         #C03030
```

### 2.3 Alternate Theme — "Mercury" (Light Mode)
```
Primary Background:    #F0EFEC
Secondary Background:  #FFFFFF
Tertiary Background:   #E8E6E0
Border/Divider:        #C8C4BC
Text Primary:          #1A1816
Text Secondary:        #6A6560
Accent Primary:        #8C2E00
Accent Secondary:      #C4600A
Accent Success:        #2A6A3A
Accent Danger:         #8C1A1A
```

### 2.4 Alternate Theme — "Acid Green"
```
Primary Background:    #0F1A0F
Secondary Background:  #162416
Tertiary Background:   #1E2E1E
Border/Divider:        #243824
Text Primary:          #D0E8D0
Text Secondary:        #70A070
Accent Primary:        #39D353
Accent Secondary:      #A0D8A0
Accent Danger:         #D04040
```

### 2.5 Alternate Theme — "Neon Orange"
```
Primary Background:    #0D0800
Secondary Background:  #1A1200
Tertiary Background:   #261C00
Border/Divider:        #382800
Text Primary:          #F0E8D0
Text Secondary:        #A08040
Accent Primary:        #FF6B00
Accent Secondary:      #FFB040
Accent Danger:         #CC2020
```

### 2.6 Custom Theme
Implementasi saat ini menyediakan block color picker untuk seluruh 16 token warna scheme. Custom theme disimpan dengan key `custom`, diterapkan live, dan ikut dalam export/import settings.

---

## 3. Typography

### 3.1 Font Stack

| Role | Font | Weight | Size |
|------|------|--------|------|
| Display / App Name | `Bebas Neue` | 400 | 32–48sp |
| Heading H1 | `Space Mono` | 700 | 20sp |
| Heading H2 | `Space Mono` | 700 | 16sp |
| Heading H3 | `Space Mono` | 400 | 14sp |
| Body / Paragraph | `IBM Plex Mono` | 400 | 14sp |
| Body Emphasis | `IBM Plex Mono` | 600 | 14sp |
| Caption / Label | `IBM Plex Mono` | 400 | 12sp |
| Monospace Data | `IBM Plex Mono` | 400 | 12sp |
| Button Label | `Space Mono` | 700 | 13sp (uppercase) |
| Metadata Value | `IBM Plex Mono` | 400 | 13sp |
| Metadata Key | `IBM Plex Mono` | 400 | 12sp (muted color) |

**Import di `pubspec.yaml`:**
```yaml
fonts:
  - family: BebasNeue
    fonts:
      - asset: assets/fonts/BebasNeue-Regular.ttf
  - family: SpaceMono
    fonts:
      - asset: assets/fonts/SpaceMono-Regular.ttf
      - asset: assets/fonts/SpaceMono-Bold.ttf
        weight: 700
      - asset: assets/fonts/SpaceMono-Italic.ttf
        style: italic
  - family: IBMPlexMono
    fonts:
      - asset: assets/fonts/IBMPlexMono-Regular.ttf
      - asset: assets/fonts/IBMPlexMono-SemiBold.ttf
        weight: 600
      - asset: assets/fonts/IBMPlexMono-Italic.ttf
        style: italic
```

### 3.2 Type Scale
```
Display:    48sp / line-height 1.0 / letter-spacing -0.5
H1:         20sp / line-height 1.3 / letter-spacing 0.5 / UPPERCASE
H2:         16sp / line-height 1.3 / letter-spacing 0.5
H3:         14sp / line-height 1.4 / letter-spacing 0.3
Body:       14sp / line-height 1.6 / letter-spacing 0
Caption:    12sp / line-height 1.5 / letter-spacing 0.2
Overline:   10sp / line-height 1.4 / letter-spacing 1.5 / UPPERCASE
```

---

## 4. Spacing & Grid

### 4.1 Base Grid
- Base unit: **4dp**
- Grid spacing: multiples of 4 (4, 8, 12, 16, 20, 24, 32, 40, 48, 64)

### 4.2 Spacing Tokens
```dart
class AppSpacing {
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}
```

### 4.3 Layout Zones
- **Screen horizontal padding:** 16dp
- **Screen vertical padding top:** 16dp
- **Screen vertical padding bottom:** 24dp (+ safe area)
- **Card internal padding:** 16dp
- **List item padding:** 12dp vertical, 16dp horizontal
- **Section spacing:** 24dp between sections
- **Micro spacing (icon–label gap):** 8dp

---

## 5. Component Library

### 5.1 App Bar
```
Height: 56dp
Background: #0D0D0D (same as bg, no elevation)
Border-bottom: 1dp solid #2E2E2E
Title: Space Mono Bold 16sp, UPPERCASE, Text Primary color
Leading icon: 24dp
Trailing icons: 24dp, spacing 8dp between icons
```

Variant — dengan accent bar:
```
Thin accent bar (2dp height) di bottom app bar, warna Accent Primary
```

### 5.2 Bottom Navigation Bar
```
Height: 64dp + safe area
Background: #1A1A1A
Border-top: 1dp solid #2E2E2E
Icons: 24dp, unselected = Text Tertiary, selected = Accent Primary
Labels: IBM Plex Mono 10sp UPPERCASE, unselected = Text Tertiary, selected = Accent Primary
Active indicator: none (hanya warna yang berubah, no pill/background)
Items: 3 (VIEWER, REMOVER, SETTINGS)
```

### 5.3 Cards / List Items
```
Background: #1A1A1A
Border: 1dp solid #2E2E2E
Border-radius: 4dp (minimal rounding, industrial feel)
Padding: 16dp
Shadow: none (flat, no elevation)

Hover/Pressed state: background → #242424, border → #404040

Marked state:
  Border-left: 3dp solid Accent Primary (#C94B1A)
  Background: #1A0D08 (very subtle rust tint)
```

### 5.4 Buttons

#### Primary Button (CTA)
```
Background: Accent Primary (#C94B1A)
Text: #0D0D0D, Space Mono Bold 13sp UPPERCASE, letter-spacing 1.5
Height: 48dp
Border-radius: 2dp
Padding: 0 24dp
Pressed: background darken 15%
Disabled: background #2E2E2E, text Text Tertiary
```

#### Secondary Button (Outline)
```
Background: transparent
Border: 1dp solid #404040
Text: Text Primary, Space Mono Bold 13sp UPPERCASE
Height: 48dp
Border-radius: 2dp
Padding: 0 24dp
Pressed: background #242424
Hover: border → Accent Primary
```

#### Destructive Button
```
Background: transparent
Border: 1dp solid Accent Danger (#8C2A2A)
Text: Accent Danger, Space Mono Bold 13sp UPPERCASE
Height: 48dp
Border-radius: 2dp
Pressed: background #1A0808
```

#### Icon Button
```
Size: 40dp touch target
Icon: 20dp
Background: transparent
Pressed: background #242424, border-radius 4dp
```

#### Chip / Tag
```
Background: #242424
Border: 1dp solid #2E2E2E
Border-radius: 2dp
Padding: 4dp 10dp
Text: IBM Plex Mono 11sp
Height: 28dp
```

### 5.5 Input Fields
```
Background: #1A1A1A
Border: 1dp solid #2E2E2E
Border-radius: 2dp
Height: 48dp
Padding: 0 16dp
Font: IBM Plex Mono 14sp, Text Primary
Placeholder: Text Tertiary

Focus state:
  Border: 1dp solid Accent Primary
  Cursor: Accent Primary

Error state:
  Border: 1dp solid Accent Danger
  Helper text: Accent Danger, IBM Plex Mono 12sp
```

### 5.6 Toggle / Switch
```
Custom styled Switch:
  Track (off): #2E2E2E, border-radius 2dp (rectangular!)
  Track (on): Accent Primary dengan 40% opacity
  Thumb (off): #5A5248, border-radius 1dp
  Thumb (on): Accent Primary, border-radius 1dp
  Width: 44dp, Height: 24dp
```

### 5.7 Checkbox
```
Custom styled Checkbox:
  Unchecked: 20dp × 20dp, border 1.5dp solid #404040, border-radius 2dp, background transparent
  Checked: background Accent Primary, border Accent Primary, checkmark icon #0D0D0D
  Indeterminate: background #404040, dash icon Text Secondary
```

### 5.8 Progress Bar
```
Linear Progress:
  Track: #2E2E2E, height 3dp, border-radius 0 (flat)
  Fill: Accent Primary, animated left-to-right
  Accent bar fill effect: gradient from #C94B1A to #E8A040

Circular Progress (loading):
  Stroke width: 2dp
  Color: Accent Primary
  Size: 32dp
```

### 5.9 Dividers & Separators
```
Full-width divider: 1dp solid #2E2E2E
Section divider: 1dp solid #2E2E2E, dengan label kecil di tengah (IBM Plex Mono 10sp UPPERCASE, Text Tertiary)
Vertical divider: 1dp solid #2E2E2E
```

### 5.10 Badges & Tags
```
Extension badge:
  Background: #242424
  Border: 1dp solid #404040
  Text: IBM Plex Mono 10sp UPPERCASE, Text Secondary
  Padding: 2dp 6dp
  Border-radius: 2dp

Privacy warning badge (⚠️ GPS dll):
  Background: #1A0D00 (very dark rust)
  Border: 1dp solid Accent Primary
  Text: Accent Primary, IBM Plex Mono 10sp
  Icon: warning triangle Accent Primary

Marked badge:
  Background: Accent Primary
  Text: #0D0D0D, IBM Plex Mono 10sp UPPERCASE
  Padding: 2dp 8dp
  Border-radius: 2dp
  Label: "MARKED"

Status badge (processing):
  Animated border (CSS-like animated stroke)
  Colors sesuai status: warning, success, danger
```

### 5.11 Bottom Sheet
```
Background: #1A1A1A
Top notch: 4dp × 32dp, background #404040, border-radius 2dp, centered
Border-top-left-radius: 8dp
Border-top-right-radius: 8dp
Border-top: 1dp solid #2E2E2E
Max height: 90% screen height
```

### 5.12 Dialogs / Alerts
```
Background: #1A1A1A
Border: 1dp solid #2E2E2E
Border-radius: 4dp
Title: Space Mono Bold 16sp, Text Primary
Body: IBM Plex Mono 14sp, Text Secondary, line-height 1.6
Button row: right-aligned, spacing 8dp
Overlay: #0D0D0D at 80% opacity
```

### 5.13 Snackbar / Toast
```
Background: #E8E0D0 (inverted — light on dark screen)
Text: #0D0D0D, IBM Plex Mono 13sp
Action text: Accent Primary
Border-radius: 2dp
Position: bottom, 16dp from nav bar
Duration: 3000ms (informational), 5000ms (error with action)
Max lines: 2
```

### 5.14 Empty State
```
Illustration: SVG lineart gaya blueprint/industrial diagram (no color fill, hanya stroke)
Title: Space Mono Bold 16sp, Text Secondary
Subtitle: IBM Plex Mono 14sp, Text Tertiary
CTA Button: Primary Button
Vertical center alignment
```

---

## 6. Icons

### 6.1 Icon Style
- **Style:** Outlined, stroke weight 1.5dp, tidak ada fill
- **Size:** 24dp (default), 20dp (compact), 16dp (badge/chip)
- **Package:** `lucide_flutter` (open source, konsisten dengan estetika minimalis)
- **Fallback:** `flutter_bootstrap_icons` untuk ikon yang tidak ada di Lucide

### 6.2 Icon Mapping
| Action/Concept | Icon |
|---------------|------|
| Add files | `file_plus` |
| View/inspect | `search` |
| Remove metadata | `eraser` |
| Mark for removal | `bookmark` |
| Delete from list | `x` |
| Process/run | `play` |
| Settings | `sliders_horizontal` |
| Folder/output | `folder_open` |
| Copy to clipboard | `clipboard_copy` |
| Share | `share_2` |
| GPS/Location (warning) | `map_pin` |
| Image file | `image` |
| Video file | `video` |
| Audio file | `music` |
| Document file | `file_text` |
| Archive file | `file_archive` |
| Success | `check_circle` |
| Warning | `alert_triangle` |
| Error | `x_circle` |
| Info | `info` |
| Loading | `loader_2` (animated) |
| Hash/checksum | `fingerprint` |
| Timestamp | `clock` |
| Camera/device | `camera` |
| Author | `user` |
| Clear/reset | `rotate_ccw` |
| Close | `x` |
| Back | `chevron_left` |
| Expand | `chevron_down` |
| Collapse | `chevron_up` |
| Sort | `arrow_up_down` |
| Filter | `filter` |
| Select all | `check_square` |
| Batch | `layers` |

---

## 7. Animation & Motion

### 7.1 Principles
- **Purpose-driven:** Animasi hanya ada jika membantu orientasi atau feedback
- **Fast & snappy:** Duration 150–300ms (tidak ada yang > 400ms kecuali onboarding)
- **Easing:** `Curves.easeInOut` untuk transisi, `Curves.easeOut` untuk enter, `Curves.easeIn` untuk exit

### 7.2 Transition Specs
| Transition | Duration | Curve | Type |
|------------|----------|-------|------|
| Page push (main nav) | 250ms | easeInOut | Slide + fade |
| Bottom sheet open | 300ms | easeOut | Slide up |
| Bottom sheet close | 200ms | easeIn | Slide down |
| Dialog open | 200ms | easeOut | Scale + fade |
| Dialog close | 150ms | easeIn | Fade |
| List item appear | 200ms | easeOut | Slide + fade (staggered 30ms) |
| Accordion expand | 200ms | easeInOut | Height animation |
| Toast appear | 300ms | easeOut | Slide up |
| Toast dismiss | 200ms | easeIn | Slide down + fade |

### 7.3 Microinteractions
- **Button press:** Scale down ke 0.97, duration 100ms, Curves.easeIn
- **Checkbox check:** Checkmark draw animation, duration 200ms
- **Processing progress:** Indeterminate shimmer pada progress bar sebelum percentage diketahui
- **Mark toggle:** Border-left expand animation (width 0 → 3dp, duration 150ms)
- **File item remove:** Slide out ke kiri + fade, duration 200ms, ItemRemove animation

### 7.4 Onboarding Animations
- Slide transitions: horizontal slide, 350ms, easeInOut
- Illustration enter: fade + slight translateY (up 8dp), staggered, 400ms
- Progress dots: scale + color transition, 200ms
- CTA button: fade in terakhir setelah ilustrasi, delay 200ms

---

## 8. Screen Specifications

### 8.1 Onboarding — Slide 1 (Welcome)
```
Layout: full screen, vertical center
Background: Primary bg + subtle noise texture overlay
Top: logo/icon app (64dp), Bebas Neue 48sp "METASTRIP"
Center: IBM Plex Mono 16sp tagline "Strip the invisible. Own your files."
Bottom: progress dots + "GET STARTED" primary button
Skip link: top-right, Text Secondary, IBM Plex Mono 12sp
```

### 8.2 Onboarding — Slides 2–3 (Feature)
```
Layout: full screen
Top 40%: SVG illustration (blueprint/industrial style, accent color lines on dark bg)
Bottom 60%: 
  - Space Mono Bold 20sp UPPERCASE, feature name
  - IBM Plex Mono 14sp description (3-4 baris)
  - Progress dots
  - "NEXT" primary button
```

### 8.3 Onboarding — Slide 4 (Folder Setup)
```
Layout: full screen
Title: "SET OUTPUT FOLDER" Space Mono Bold 20sp
Subtitle: IBM Plex Mono 14sp, explanation
Center: 
  - Folder icon 64dp, Text Secondary
  - Current path (IBM Plex Mono 12sp, Text Secondary) atau "Not set"
  - "CHOOSE FOLDER" secondary button
Note: IBM Plex Mono 12sp Text Tertiary "Files will be saved here after processing"
Bottom: "CONTINUE" primary button (disabled jika folder belum dipilih)
```

### 8.4 Onboarding — Slide 5 (Permissions)
```
Layout: scrollable
Title: "APP PERMISSIONS" Space Mono Bold 20sp
Per permission item card:
  - Icon 24dp + Permission name Space Mono 14sp
  - IBM Plex Mono 12sp explanation
  - Status badge: GRANTED (green) | DENIED (red) | NOT YET (neutral)
  - "GRANT" button (secondary, per-item)
Bottom: "GRANT ALL" primary button + "SKIP (OPTIONAL)" link
        Note tentang mengapa permission penting
```

### 8.5 Viewer Screen
```
App Bar:
  Title: "VIEWER"
  Actions: [filter icon] [sort icon] [add files icon]

Body (file list):
  Per file card:
    Row 1: [thumbnail 48×48] [filename (bold)] [extension badge]
    Row 2:              [filesize] · [modified date]
    Row 3:              [tag: marked/unmarked] [actions: View · Mark · Remove]
    Left accent bar (3dp): visible if marked

  Empty state jika tidak ada file

Bottom action bar (fixed, visible jika ada file):
  Row 1: "X file(s)" Space Mono 12sp · [Select All checkbox]
  Row 2: [Mark Selected] [Remove from List] 
  Row 3: [SEND TO REMOVER →] primary button (full width)
```

### 8.6 Metadata Detail Screen
```
App Bar:
  Back button
  Title: filename (truncated, IBM Plex Mono 14sp)
  Actions: [share] [mark/unmark]

Body (scrollable):
  Header card:
    - Thumbnail full width (jika gambar, rasio asli)
    - Filename, size, path
    - Status badge: Marked/Unmarked
    - "MARK FOR REMOVAL" / "UNMARK" button

  Accordion sections (each):
    Section header:
      - Icon 16dp + section name Space Mono Bold 14sp UPPERCASE
      - Item count badge
      - Expand/collapse chevron

    Section body (expanded):
      Per field row:
        Key: IBM Plex Mono 12sp Text Secondary, left-aligned, 40% width
        Value: IBM Plex Mono 13sp Text Primary, right-aligned, 60% width
        ⚠️ icon jika privacy-sensitive
        Tap: copy value
        Long press: context menu (Copy Key, Copy Value, Copy Both)

  Sticky bottom:
    [MARK THIS FILE] primary button full-width
```

### 8.7 Remover Screen
```
App Bar:
  Title: "REMOVER"
  Actions: [add files icon]

Body:
  Section 1: Queue (file list to process)
    Per file card (compact):
     [thumbnail 40×40] [filename] [supported-cleanup status]
      [filesize] · [metadata count] · [remove from queue icon]

  Section 2: Processing Options
     Planned mode selector: chip group (Full Strip | Selective | Anonymize | Preserve Technical)
     Current status: unavailable; the current pipeline uses supported-cleanup behavior.

  Empty state jika queue kosong

Bottom:
  Summary: "X file(s) · Est. Y seconds"
  [PROCESS NOW] primary button full-width (disabled jika queue kosong)
```

### 8.8 Processing Screen (Modal full-screen)
```
Layout:
  Title: "PROCESSING" + file count, Space Mono Bold 20sp UPPERCASE
  
  Overall progress:
    Label: "X / Y files"
    Progress bar: full width, flat, 4dp height
    Percentage: IBM Plex Mono 24sp, right side

  Current file:
    Filename + extension badge
    File-specific progress bar (thinner, 2dp)
    Status: "Extracting..." | "Stripping..." | "Saving..."

  Log (expandable):
    Bottom panel, default collapsed
    Per line: timestamp + action + filename (monospace, 11sp)

  Cancel button: Destructive, centered below progress
```

### 8.9 Result Screen
```
Layout:
  Icon: check_circle (success) / x_circle (partial fail), 64dp
  Title: "DONE" / "PARTIAL SUCCESS", Space Mono Bold 32sp
  
  Stats grid (2×2):
    Processed: N
    Failed: M
    Metadata removed: X fields
    Data stripped: Y KB

  Failed files list (jika ada):
    Collapsible list, per item: filename + error reason

  Actions:
     [OPEN OUTPUT FOLDER] secondary button (planned where platform access is available)
     [SHARE FILES] secondary button (planned)
    [PROCESS ANOTHER] primary button
```

### 8.10 Settings Screen
Current MVP behavior (source of truth):
```
App Bar:
  Title: "SETTINGS"

Body (grouped sections):
  Section header: IBM Plex Mono 10sp UPPERCASE, Text Tertiary, with accent line

  APPEARANCE:
    - Color Theme → navigate ke theme picker screen

  OUTPUT:
    - Output Folder [path, tap to change]

  MAINTENANCE:
    - Clear App Cache [right: "X.X MB"] → dengan loading + success snackbar
    - Export settings → dialog untuk export/import JSON portabel
    - Reset all data → 2-step confirmation; kembali ke onboarding tanpa menghapus clean copies

  ABOUT:
    - App version, build
    - About MetaStrip
    - Open Source Licenses
```

Folder Structure, Naming Template, Keep Original, JPEG Quality, Max Concurrent Files, dan Auto-confirm ada pada model persistence, tetapi kontrolnya tidak diekspos di Settings screen dan belum dihubungkan ke processing. Export menghapus output path yang device-local; import mempertahankan output folder aktif.

### 8.11 Theme Picker Screen
```
App Bar:
  Back button
  Title: "COLOR THEME"

Body:
  Preview card (top):
    Live preview of selected theme applied ke mini-UI
    Shows: app bar, card, button, text, badge

  Preset list:
    - 7 radio rows: Dark Industrial, Steel Blue, Acid Green, Rust,
      Mercury, Neon Orange, Cobalt

  Custom section:
    "Custom Theme" row opens builder dialog
    16 scheme-token color rows use block color pickers
    [SAVE] persists and applies the custom scheme
```

---

## 9. Asset Requirements

### 9.1 App Icon
- **Design:** Stylized brackets `{ }` atau `< >` dengan accent bar yang menandai "stripping"
- **Style:** Flat, monochrome dengan accent color
- **Sizes:** Semua ukuran Android adaptive icon + iOS icon

### 9.2 Onboarding Illustrations (SVG)
3 ilustrasi SVG gaya blueprint/technical drawing:
1. **Viewer:** Kaca pembesar di atas file/dokumen dengan metadata terlihat memancar keluar
2. **Remover:** Eraser/penghapus menghapus data/teks dari file
3. **Folder:** Folder dengan panah masuk dan tanda checkmark

Style: stroke-only, no fill, warna aksen pada elemen utama, warna sekunder pada detail, background transparan.

### 9.3 Empty State Illustrations (SVG)
2 ilustrasi:
1. **Viewer empty:** File icon dengan tanda tanya
2. **Remover empty:** Queue icon kosong dengan panah masuk

### 9.4 Texture
- `bg_noise.png`: subtle noise texture, 200×200px, tiled, opacity 3–5%
- Digunakan sebagai overlay di atas background color untuk depth

---

## 10. Responsive Layout

### 10.1 Phone (< 600dp width) — Primary Target
- Single column layout
- Bottom navigation bar
- Cards full width
- Modal bottom sheets untuk secondary actions

### 10.2 Tablet (600–840dp width) — Supported
- Two-column layout untuk Viewer (list + detail side by side)
- Navigation rail (left side) menggantikan bottom nav
- Dialogs lebih narrow (max 480dp)

### 10.3 Breakpoints
```dart
class AppBreakpoints {
  static const double compact  = 600;  // phone
  static const double medium   = 840;  // tablet portrait
  static const double expanded = 1200; // tablet landscape / desktop
}
```

---

## 11. Theme Implementation (Flutter Code)

```dart
// lib/theme/app_theme.dart

ThemeData buildTheme(AppColorScheme colors) {
  return ThemeData(
    brightness: colors.brightness,
    scaffoldBackgroundColor: colors.backgroundPrimary,
    fontFamily: 'IBMPlexMono',
    
    colorScheme: ColorScheme(
      brightness: colors.brightness,
      primary: colors.accentPrimary,
      onPrimary: colors.backgroundPrimary,
      secondary: colors.accentSecondary,
      onSecondary: colors.backgroundPrimary,
      error: colors.accentDanger,
      onError: colors.textPrimary,
      surface: colors.backgroundSecondary,
      onSurface: colors.textPrimary,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: colors.backgroundPrimary,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      titleTextStyle: GoogleFonts.spaceMono(
        fontSize: 16, fontWeight: FontWeight.w700,
        color: colors.textPrimary, letterSpacing: 0.5,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: colors.border, height: 1),
      ),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colors.backgroundSecondary,
      selectedItemColor: colors.accentPrimary,
      unselectedItemColor: colors.textTertiary,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),

    cardTheme: CardTheme(
      color: colors.backgroundSecondary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: colors.border, width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.accentPrimary,
        foregroundColor: colors.backgroundPrimary,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        textStyle: GoogleFonts.spaceMono(
          fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: colors.borderEmphasis, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        textStyle: GoogleFonts.spaceMono(
          fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.backgroundSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: colors.accentPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    dividerTheme: DividerThemeData(
      color: colors.border,
      thickness: 1,
      space: 1,
    ),
  );
}
```
