---
App Name: SysPie
version: 1.0.0
description: SysPie is a windows based system monitoring tool that presents real-time process, service, and hardware data in compact tables and charts. A diagonal gradient canvas (gold → teal → ice cube) anchors white elevated cards with 24px radius corners. Olympic Blue (#4285F4) carries every interactive element. The side menu is a fixed 150px ice-cube rail with pill-shaped navigation highlights. Typography is Segoe UI at compact sizes (10–14px). This is a tools-not-pictures design language where density is the feature.

colors:
  primary: "#4285F4"
  primary-on: "#FFFFFF"
  primary-container: "#BEE9F4"
  primary-on-container: "#4285F4"
  surface: "#FFFFFF"
  surface-elevated: "#FFFFFF"
  surface-container-highest: "#F3E7FE"
  canvas-gradient-top: "rgb(219, 203, 143)"
  canvas-gradient-mid: "rgba(43, 204, 196, 0.75)"
  canvas-gradient-bottom: "#BEE9F4"
  text-primary: "#000000"
  text-secondary: "#64748B"
  text-muted: "#94A3B8"
  status-green: "#22C55E"
  status-yellow: "#F59E0B"
  status-red: "#EF4444"
  status-blue: "#3B82F6"
  status-purple: "#8B5CF6"
  status-cyan: "#06B6D4"
  outline: "#CBD5E0"
  highlight: "#DEE1E6"
  category-column: "#FFD470"
  sidebar-bg: "#BEE9F4"
  header-text: "#4285F4"
  error: "#EF4444"

typography:
  font-family: "Segoe UI, system-ui"
  nav:
    fontSize: 14px
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: 0
  button:
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1.3
    letterSpacing: 0
  header:
    fontSize: 11px
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: 0
  cell:
    fontSize: 11px
    fontWeight: 500
    lineHeight: 1.3
    letterSpacing: 0
  cell-sub:
    fontSize: 10px
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: 0
  badge:
    fontSize: 10px
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: 0
  category-text:
    fontSize: 13px
    fontWeight: 700
    lineHeight: 1.3
    letterSpacing: 0
  context-menu:
    fontSize: 10px
    fontWeight: 400
    lineHeight: 1.4
    letterSpacing: 0
  chart-title:
    fontSize: 24px
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: 0
  chart-subtitle:
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: 0
  chart-hardware:
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: 0
  chart-legend:
    fontSize: 10px
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: 0
  chart-axis:
    fontSize: 10px
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: 0
  footer-label:
    fontSize: 11px
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: 0
  footer-value:
    fontSize: 12px
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: 0

rounded:
  none: 0px
  sm: 8px
  md: 12px
  lg: 24px
  pill: 9999px

spacing:
  xs: 1px
  sm: 4px
  md: 8px
  lg: 12px
  xl: 16px
  xxl: 20px
  section: 32px

components:
  side-menu:
    backgroundColor: "{colors.sidebar-bg}"
    textColor: "{colors.text-primary}"
    typography: "{typography.nav}"
    width: 150px
    border: "1px {colors.outline}"
    borderRadius: "{rounded.lg}"
    itemHighlight:
      backgroundColor: "{colors.primary}"
      textColor: "{colors.primary-on}"
      borderRadius: "{rounded.pill}"
  top-bar:
    backgroundColor: transparent
    textColor: "{colors.text-primary}"
    typography: "{typography.button}"
    height: 25px
  resource-bar:
    backgroundColor: transparent
    labelTypography: "{typography.button}"
    valueTypography: "{typography.cell-sub}"
    barHeight: 6px
    barWidth: 80px
    barBorderRadius: "{rounded.pill}"
  search-field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-primary}"
    typography: "{typography.button}"
    borderRadius: "{rounded.pill}"
    height: 25px
    width: 240px
    borderColor: "{colors.outline}"
  top-button:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.primary-on}"
    typography: "{typography.button}"
    borderRadius: "{rounded.pill}"
    height: 25px
  data-table:
    backgroundColor: "{colors.surface}"
    borderRadius: "{rounded.lg}"
    borderColor: "{colors.outline}"
    headerBackground: "{colors.primary-container}"
    headerHeight: 35px
    headerTypography: "{typography.header}"
    rowHeight: 35px
    rowTypography: "{typography.cell}"
    selectedRowBackground: "{colors.highlight}"
  category-header:
    backgroundColor: "{colors.category-column}"
    typography: "{typography.category-text}"
    height: 35px
  status-badge:
    borderRadius: "{rounded.pill}"
    typography: "{typography.badge}"
    greenDot: "{colors.status-green}"
    yellowDot: "{colors.status-yellow}"
    redDot: "{colors.status-red}"
  context-menu:
    backgroundColor: "{colors.surface}"
    borderRadius: "{rounded.lg}"
    typography: "{typography.context-menu}"
    width: 130px
    itemHeight: 30px
    iconSize: 17px
    shadow: "0 4px 12px rgba(0, 0, 0, 0.15)"
  chart-card:
    backgroundColor: "{colors.surface}"
    borderRadius: "{rounded.lg}"
    borderColor: "{colors.outline}"
    fixedHeight: 288px
  chart-tab:
    height: 35px
    activeColor: "{colors.primary}"
    inactiveColor: "{colors.text-muted}"
  elevation-banner:
    backgroundColor: "{colors.status-yellow} withAlpha(30)"
    textColor: "{colors.text-primary}"
    typography: "{typography.button}"
  custom-scrollbar:
    thickness: 14px
    hoverOpacity: 1.0
    fadeDuration: 250ms

---

## Overview

SysPie is a windows based **system monitoring tool** that presents real-time process, service, and hardware data in compact tables and charts. Every design decision serves the goal of **maximum information density with minimum visual noise**, this is a tools-not-pictures design language where density is the feature.

The layout is a fixed two-panel structure: a **150px icy blue side menu** on the left with pill-shaped navigation highlights, and a **white elevated card** filling the remaining viewport for the active screen content. A **diagonal gradient canvas** (gold → teal → icy blue, top-left to bottom-right) runs behind everything, providing subtle visual warmth without competing with the data.

**Key Characteristics:**
- Data-dense tables with 35px row heights and 10–11px cell typography information density is the primary design goal.
- Single accent color (`{colors.primary}` #4285F4) carries every interactive element: navigation highlights, button fills, chart lines, header text, and badge dots.
- Fixed 24px border radius on every elevated surface: cards, side menu, context menus, dialogs. The radius is uniform and generous, creating softness in an otherwise utilitarian interface.
- Diagonal gradient canvas (`{colors.canvas-gradient-top}` → `{colors.canvas-gradient-mid}` → `{colors.canvas-gradient-bottom}`) provides ambient warmth behind white data cards.
- Segoe UI at compact sizes (10–14px): the Windows system font at sizes that prioritize scanability over readability. No font is loaded from Google Fonts; the app feels native to the platform.
- Pill-shaped grammar for all interactive chrome: navigation highlights, buttons, search input, status badges, top-bar buttons. The pill radius (`{rounded.pill}`) is the universal "clickable" signal.
- Status colors are semantic: green = running/active, yellow = intermediate/warning, red = stopped/error. These map to badge dots, progress bar fills, and chart line colors.
- Context menus appear on right-click with fade+slide animation (150ms). Every table row and service row offers contextual actions.
- Cross-screen navigation: clicking "Go to Processes" from Details or Users highlights and scrolls to the target PID automatically.
- Optional elevation: the app detects admin privileges at startup and shows a yellow banner offering "Run as Admin" relaunch when access is denied.

## Colors

### Brand & Accent
- **Olympic Blue** (`{colors.primary}`, #4285F4): The single brand-level interactive color. All button fills, navigation highlights, chart axis labels, header text, and the side menu's active item use this blue. It is the universal "this is actionable" signal.
- **Primary On** (`{colors.primary-on}`, #FFFFFF): Text and icons on `{colors.primary}` backgrounds. Used on button labels, top-bar button icons, and active nav item text.
- **Primary Container** (`{colors.primary-container}`, #BEE9F4): The ice-cube blue used for the side menu background, data table header rows, and the gradient's terminal stop. It is the brand's "resting" surface, always visible but never demanding attention.
- **Primary On Container** (`{colors.primary-on-container}`, #4285F4): Text on `{colors.primary-container}` surfaces. Same hex as `{colors.primary}`, the container is light enough that the primary blue reads as text.

### Surface
- **White Surface** (`{colors.surface}`, #FFFFFF): The dominant data surface. All table cards, context menus, chart cards, and dialogs use pure white.
- **Elevated Surface** (`{colors.surface-elevated}`, #FFFFFF): Same as `{colors.surface}`, elevation is communicated through shadow, not color change.
- **Surface Container Highest** (`{colors.surface-container-highest}`, #F3E7FE): A faint lavender available for secondary selection states. Just different enough from white to read as "selected" without competing with the primary accent.

### Canvas Gradient
- **Gradient Top** (`{colors.canvas-gradient-top}`, rgb(219, 203, 143)): A warm gold/amber at the top-left corner. The starting point of the diagonal gradient.
- **Gradient Mid** (`{colors.canvas-gradient-mid}`, rgba(43, 204, 196, 0.75)): A translucent teal in the center. The gradient's midpoint, providing visual interest without opacity compete.
- **Gradient Bottom** (`{colors.canvas-gradient-bottom}`, #BEE9F4): The ice-cube blue at the bottom-right. Matches `{colors.primary-container}`, creating a seamless transition into the side menu.

### Text
- **Text Primary** (`{colors.text-primary}`, #000000): All primary text: table cell values, navigation labels, dialog content. Pure black for maximum contrast on white surfaces.
- **Text Secondary** (`{colors.text-secondary}`, #64748B): Secondary information: column sub-headers, muted labels, footer stat labels. A slate gray that recedes behind primary text.
- **Text Muted** (`{colors.text-muted}`, #94A3B8): The quietest text tier: search placeholders, disabled states, chart axis labels. Visible but unobtrusive.

### Status
- **Status Green** (`{colors.status-green}`, #22C55E): Running processes, active services, the CPU chart line, and progress bars under 40% load. The universal "healthy" signal.
- **Status Yellow** (`{colors.status-yellow}`, #F59E0B): Intermediate states, pending actions, kernel processes, disk write indicators, and the elevation warning banner. The "attention" signal.
- **Status Red** (`{colors.status-red}`, #EF4444): Stopped services, error states, terminate actions, and progress bars over 80% load. The "action required" signal.
- **Status Blue** (`{colors.status-blue}`, #3B82F6): User CPU chart line, network border color. A secondary data-series color distinct from the primary accent.
- **Status Purple** (`{colors.status-purple}`, #8B5CF6): GPU chart line, GPU border color. A tertiary data-series color for the GPU subsystem.
- **Status Cyan** (`{colors.status-cyan}`, #06B6D4): Memory available indicator, network receive line. A quaternary data-series color for memory and receive data.

### Hairlines & Borders
- **Outline** (`{colors.outline}`, #CBD5E0): The 1px border on data table cards, chart cards, and input fields. A light gray that defines edges without adding visual weight.
- **Highlight** (`{colors.highlight}`, #DEE1E6): The selected-row background in data tables. A barely-there gray that marks the active row without obscuring its content.

### Category & Misc
- **Category Column** (`{colors.category-column}`, #FFD470): The background tint on Apps/Background/Windows Processes group headers. A warm gold that visually separates table sections.

## Typography

### Font Family
- **Primary**: `Segoe UI, system-ui, -apple-system, sans-serif`: Windows' native system font, chosen for its ubiquity on the target platform and its excellent legibility at small sizes. No web fonts are loaded; the app feels native to Windows.

### Hierarchy

| Token | Size | Weight | Line Height | Use |
|---|---|---|---|---|
| `{typography.nav}` | 14px | 500 | 1.4 | Side menu navigation items |
| `{typography.button}` | 12px | 500 | 1.3 | Top bar buttons, search field, elevation banner |
| `{typography.header}` | 11px | 600 | 1.3 | Data table column headers |
| `{typography.cell}` | 11px | 500 | 1.3 | Data table cell text (primary values) |
| `{typography.cell-sub}` | 10px | 400 | 1.3 | Subtitle text (window titles, service names, sub-values) |
| `{typography.badge}` | 10px | 600 | 1.3 | Status badge text |
| `{typography.category-text}` | 13px | 700 | 1.3 | Category group header text (Apps, Background, Windows Processes) |
| `{typography.context-menu}` | 10px | 400 | 1.4 | Context menu item text |
| `{typography.chart-title}` | 24px | 700 | 1.2 | Chart tab title (e.g., "CPU") |
| `{typography.chart-subtitle}` | 12px | 400 | 1.3 | Chart subtitle (e.g., "% Utilization") |
| `{typography.chart-hardware}` | 14px | 400 | 1.3 | Hardware name below chart title |
| `{typography.chart-legend}` | 10px | 400 | 1.3 | Chart legend labels |
| `{typography.chart-axis}` | 10px | 400 | 1.3 | Chart Y-axis labels |
| `{typography.footer-label}` | 11px | 400 | 1.3 | Footer stat labels |
| `{typography.footer-value}` | 12px | 600 | 1.3 | Footer stat values |

### Principles

- **Compact by default.** The largest body text is 14px (navigation). Everything else is 10–12px. This is intentional; SysPie is a monitoring tool, and every pixel of vertical space saved means one more process row visible.
- **Weight 500 for data, 600 for structure.** Cell values use weight 500 (medium) for readability at small sizes. Column headers, badges, and footer values use weight 600 (semi-bold) to create structural hierarchy without adding size.
- **Weight 700 reserved for category headers and chart titles.** The only places bold appears are the Apps/Background/Windows Processes group headers (13px/700) and the chart tab title (24px/700). Everything else lives below 700.
- **Weight 400 for subtitles and muted content.** Window titles, service display names, chart axis labels, and context menu items use regular weight. They exist to be found, not to be read first.
- **Line-height is tight everywhere.** At 1.2–1.4, text lines sit close together. This is a density-first choice; generous leading would waste vertical space in a tool where seeing more rows matters more than reading comfort.
- **No italic, no underline, no letter-spacing.** The type system is deliberately plain. Emphasis comes from weight and color, not decoration.

## Layout

### Spacing System
- **Base unit:** 4px. All spacing values are multiples of 4px.
- **Tokens:** `{spacing.xs}` 1px · `{spacing.sm}` 4px · `{spacing.md}` 8px · `{spacing.lg}` 12px · `{spacing.xl}` 16px · `{spacing.xxl}` 20px · `{spacing.section}` 32px.
- **Table cell padding:** Horizontal padding inside cells uses `{spacing.md}` (8px) to `{spacing.lg}` (12px), keeping values tight against column edges.
- **Card padding:** Data table cards and chart cards have no internal padding; the table header row and content fill the card edge-to-edge.
- **Side menu padding:** Navigation items use `{spacing.lg}` (12px) horizontal padding within the 150px rail.

### Grid & Container
- **Side menu:** Fixed 150px width, full viewport height. Contains 5 navigation items stacked vertically with pill-shaped highlights.
- **Content area:** Fills remaining viewport width after the side menu. Content is a single white elevated card per screen.
- **Data tables:** Fixed column widths per screen (e.g., Processes: NAME 500px, CPU 70px, MEMORY 100px, DISK 90px, NETWORK 90px, GPU 70px, GPU ENGINE 120px, POWER USAGE 120px). Columns do not resize; horizontal scrolling is handled by custom scrollbars.
- **Chart layout:** Fixed 288px height. Tab bar at top (35px), title + hardware info below, line chart filling remaining space, footer stats grid at bottom.

### Whitespace Philosophy
SysPie's whitespace is **functional, not decorative**. Every pixel of empty space exists to separate data, not to create luxury. The gradient canvas provides ambient warmth, but the data surfaces themselves are edge-to-edge; white cards touch the content area borders with no margin. The 24px border radius on cards creates the only "breathing room" at corners. Inside tables, row height (35px) and cell padding (8–12px) are tuned for scanability: enough space to distinguish rows, not enough to waste vertical real estate.

## Elevation & Depth

| Level | Treatment | Use |
|---|---|---|
| Flat | No shadow, transparent background | Canvas gradient, scaffold background |
| Elevated card | `0 2px 8px rgba(0, 0, 0, 0.08)` shadow, white background, 24px radius | Data table cards, chart cards |
| Context menu | `0 4px 12px rgba(0, 0, 0, 0.15)` shadow, white background, 24px radius | Right-click context menus |
| Banner | No shadow, `{colors.status-yellow}` background | Elevation warning banner |

**Shadow philosophy.** SysPie uses **exactly two shadow levels**: a subtle 2px card shadow for data surfaces, and a slightly heavier 4px shadow for context menus that float above everything. No other elevation shadows exist. The gradient canvas is flat; the side menu is flat (its ice-cube color distinguishes it from the content area). Elevation is communicated through (a) shadow on cards and (b) the context menu's overlay position.

### Decorative Depth
- **Diagonal gradient canvas** provides ambient warmth behind the data surfaces. It is a CSS `LinearGradient` with three stops, applied to the full window background. The gradient is purely decorative; it adds visual interest without competing with data.
- **Pill-shaped highlights** on the side menu create a "raised" feel for the active navigation item through background color change (lavender pill on ice-cube blue), not through shadow.
- **Category column tint** (#FFD470, warm gold) creates visual separation between Apps/Background/Windows Processes sections without borders or shadows.

## Shapes

### Border Radius Scale

| Token | Value | Use |
|---|---|---|
| `{rounded.none}` | 0px | Table header rows (filling the card edge-to-edge) |
| `{rounded.sm}` | 8px | (Reserved for future use) |
| `{rounded.md}` | 12px | (Reserved for future use) |
| `{rounded.lg}` | 24px | Data table cards, chart cards, context menus, side menu, dialogs, the universal card radius |
| `{rounded.pill}` | 9999px | Navigation highlights, buttons, search field, status badges, top-bar buttons, the universal "interactive" radius |

### Radius Philosophy
SysPie uses exactly **two radii**: `{rounded.lg}` (24px) for containers and `{rounded.pill}` (9999px) for interactive elements. There is no middle ground. Containers are soft and rounded; interactive elements are fully pill-shaped. This binary grammar makes it instantly clear what is a surface (24px) versus what is a control (pill).

## Components

### Side Menu

**`side-menu`**: Fixed 150px wide rail on the left edge of every screen. Background `{colors.sidebar-bg}` (#BEE9F4, ice cube blue). 1px `{colors.outline}` border. Rounded `{rounded.lg}` (24px). Contains 5 navigation items stacked vertically: Processes, Details, Services, Charts, Users. Each item is `{typography.nav}` (14px / 500) with an outlined Material Icon. The active item gets a `{colors.primary}` (#4285F4, Olympic Blue) pill-shaped highlight (`{rounded.pill}`) with white (`{colors.primary-on}`) text and icon. The menu hides entirely when viewport width drops below 730px.

### Top Bar

**`top-bar`**: A thin horizontal strip above the content area. Left side: `{component.resource-bar}` showing CPU, GPU, and RAM usage. Right side: `{component.top-button}` row (View dropdown, Search field). Background is transparent, the gradient shows through. Height matches the resource bar (~25px).

### Resource Usage Bar

**`resource-bar`**: A horizontal row of three compact metrics: CPU, GPU, and RAM. Each metric has a label (`{typography.button}`, 12px), an 80px-wide progress bar (6px height, `{rounded.pill}`), and a percentage value (`{typography.cell-sub}`, 10px). Bar fill color is semantic: green (`{colors.status-green}`) under 40%, yellow (`{colors.status-yellow}`) at 40–80%, red (`{colors.status-red}`) over 80%. The bar background is `{colors.outline}` at low opacity.

### Search Field

**`search-field`**: Pill-shaped text input for global search. Background `{colors.surface}` (white), border 1px `{colors.outline}`, rounded `{rounded.pill}`, height 25px, width 240px. Typography `{typography.button}` (12px / 500). Leading icon: Material `Icons.search` at 14px in `{colors.text-muted}`. Hides when viewport width drops below 730px. Filters across process name, PID, username, exe path, window titles, and service names.

### Top Buttons

**`top-button`**: Pill-shaped action buttons in the top bar. Background `{colors.primary}` (#4285F4), text `{colors.primary-on}` (white), typography `{typography.button}` (12px / 500), rounded `{rounded.pill}`, height 25px. Each button needs ~120px width. Supports dropdown menus via `showMenu`. Hides when viewport width drops below 800px.

### Data Table

**`data-table`**: The core UI component. A white elevated card (`{rounded.lg}`, 24px radius, 1px `{colors.outline}` border) containing a fixed header row and scrollable body. Header background `{colors.primary-container}` (#BEE9F4), height 35px, text `{typography.header}` (11px / 600). Row height 35px, text `{typography.cell}` (11px / 500). Selected row gets `{colors.highlight}` (#DEE1E6) background. Rows are expandable (arrow icon toggles between `keyboard_arrow_right` and `keyboard_arrow_down`). Sub-rows (window titles, service hosts) use `{typography.cell-sub}` (10px / 400). Custom thin scrollbars (14px) appear on hover with 250ms fade.

### Category Header

**`category-header`**: A full-width row inside data tables that labels a process group (Apps, Background Processes, Windows Processes). Background `{colors.category-column}` (#FFD470, warm gold). Text `{typography.category-text}` (13px / 700) in `{colors.text-primary}`. Height 35px. No border, no shadow, the color tint alone creates section separation.

### Status Badge

**`status-badge`**: Pill-shaped badge with a colored dot and label. Rounded `{rounded.pill}`, typography `{typography.badge}` (10px / 600). Three states: green dot + "Running" (`{colors.status-green}`), yellow dot + intermediate state (`{colors.status-yellow}`), red dot + "Stopped" (`{colors.status-red}`). Used in the Status column of the Services table.

### Context Menu

**`context-menu`**: Overlay-based right-click menu with fade+slide animation (150ms). Background `{colors.surface}` (white), rounded `{rounded.lg}` (24px), shadow `0 4px 12px rgba(0, 0, 0, 0.15)`. Width 130px, item height 30px. Typography `{typography.context-menu}` (10px / 400). Each item has a 17px Material Icon on the left and text on the right, with 12px gap. Actions are context-dependent: processes get Terminate, Open File Location, Go to Details, Search Online, Properties. Services get Start, Stop, Restart. Users get Terminate All, Go to Users.

### Chart Card

**`chart-card`**: Elevated white card for performance charts. Background `{colors.surface}`, rounded `{rounded.lg}` (24px), 1px `{colors.outline}` border, fixed height 288px. Contains: `{component.chart-tab}` at top (35px), `{component.chart-header}` below (title + hardware info), `{component.chart-area}` filling remaining space (fl_chart LineChart with gradient fill), and `{component.chart-footer}` at bottom (two-column stats grid).

### Chart Tab Bar

**`chart-tab`**: Horizontal tab selector for CPU / Memory / Disk / Network / GPU. Height 35px. Active tab: text `{colors.primary}` (#4285F4) with bottom border. Inactive tabs: text `{colors.text-muted}` (#94A3B8). Typography `{typography.button}` (12px / 500).

### Elevation Banner

**`elevation-banner`**: Subtle yellow-tinted banner shown when the app lacks admin privileges. Background `{colors.status-yellow}` at 30% alpha, text `{colors.text-primary}`, typography `{typography.button}` (12px). Contains a lock icon, warning message, and "Run as Admin" button. Appears at the top of the content area when access is denied to certain processes or services. Dismissible via close button.

### Custom Scrollbar

**`custom-scrollbar`**: Thin (14px) draggable scrollbar that appears on hover over data tables. Uses 250ms fade-in animation. Transparent by default, visible when the mouse is over the scrollable area. Both horizontal and vertical variants exist.

### Details Screen

**`details-screen`**: Data table showing process details with the following fixed-width columns:

| Column | Width | Typography |
|--------|-------|------------|
| NAME | 300px | `{typography.cell}` |
| PID | 80px | `{typography.cell}` |
| STATUS | 105px | `{typography.cell}` |
| USERNAME | 125px | `{typography.cell}` |
| UAC VIRTUALIZATION | 100px | `{typography.cell}` |
| DISK PERMISSION | 100px | `{typography.cell}` |
| PARENT | 350px | `{typography.cell}` |

Context menu actions: Go to Processes, Go to Users. Cross-navigates to the Processes or Users screen with the target PID highlighted.

### Users Screen

**`users-screen`**: Data table listing real user accounts filtered from running processes. Uses the same column widths as the Processes screen (NAME 500px, CPU 70px, MEMORY 100px, DISK 90px, NETWORK 90px, GPU 70px, GPU ENGINE 120px, POWER USAGE 120px). Processes are grouped by username. Context menu actions: Terminate All, Go to Processes, Go to Details. Cross-navigates to the Processes or Details screen with the target PID highlighted.

## Do's and Don'ts

### Do
- Use `{colors.primary}` (#4285F4) for every interactive element: buttons, nav highlights, chart lines, header text, and nothing else. The single accent is non-negotiable.
- Keep table row heights at 35px and cell typography at 10–11px. This density is the core design intent.
- Use `{rounded.lg}` (24px) for all container surfaces and `{rounded.pill}` for all interactive elements. The binary radius grammar is the visual signature.
- Use status colors semantically: green = running/healthy, yellow = intermediate/warning, red = stopped/error. Never use these colors for decorative purposes.
- Show the gradient canvas behind all data surfaces. The gold → teal → ice cube diagonal gradient is the ambient warmth that keeps the tool from feeling sterile.
- Use `{typography.cell-sub}` (10px / 400) for secondary information within table rows: window titles, service display names, sub-values. It recedes behind `{typography.cell}` without disappearing.
- Display the elevation banner (`{colors.status-yellow}`) when the app lacks privileges. It is the only yellow surface in the app and immediately signals "action needed."
- Use `{colors.category-column}` (#FFD470) to tint process group headers. The warm tint creates section separation without borders.

### Don't
- Don't introduce a second accent color. Every interactive signal is `{colors.primary}` (#4285F4). Status colors are semantic, not decorative.
- Don't increase table row height above 35px or cell font size above 11px for "readability." The density is intentional; one more visible row is worth more than one more pixel of leading.
- Don't use `{rounded.sm}` (8px) or `{rounded.md}` (12px) on new components. The system uses only 24px for containers and pill for controls. Adding intermediate radii breaks the grammar.
- Don't add shadows to the side menu, category headers, or data table rows. Shadow is reserved for elevated cards (data tables, charts) and context menus only.
- Don't use italic, underline, or letter-spacing for emphasis. Emphasis comes from weight (500 → 600 → 700) and color (`{colors.text-primary}` → `{colors.text-secondary}` → `{colors.text-muted}`).
- Don't use status colors (green/yellow/red/blue/purple/cyan) for anything other than their semantic meaning. Green is running, red is stopped, yellow is warning; never use green for "cool" or red for "important."
- Don't make the side menu wider than 150px or its navigation text larger than 14px. The menu is a compact rail, not a full navigation panel.
- Don't add decorative gradients to cards, buttons, or text. The only gradient is the canvas background. Everything else is flat white or flat colored.

## Responsive Behavior

### Breakpoints

| Name | Width | Key Changes |
|---|---|---|
| Narrow | ≤ 730px | Side menu hides; search field hides; content fills full width |
| Medium | 731–800px | Side menu visible; search field hides; top buttons visible |
| Standard | 801px+ | Full layout: side menu + search + top buttons + content |

### Collapsing Strategy
- **Side menu**: Visible at ≥ 731px; hides entirely at ≤ 730px. When hidden, navigation is not accessible (the app is designed for desktop-width viewports).
- **Search field**: Visible at ≥ 731px; hides at ≤ 730px. The search functionality remains available via keyboard shortcut.
- **Top buttons**: Visible at ≥ 801px; hide at ≤ 800px. The dropdown menus they trigger are not available at narrow widths.
- **Data tables**: Columns use fixed widths and do not resize. Horizontal scrolling is handled by custom scrollbars when the content overflows.
- **Chart cards**: Fixed 288px height across all widths. The chart area scales horizontally; the footer stats grid reflows to fit.

### Minimum Window Size
- **600 × 600px**. Below this size, the content area becomes too narrow for the data tables to be useful. The app enforces this minimum via `window_manager`.

### Touch Targets
- Not applicable; SysPie is a desktop application. All interactive elements are designed for mouse/keyboard input, not touch.

## Iteration Guide

1. Focus on ONE component at a time. Reference its YAML key directly (`{component.data-table}`, `{component.side-menu}`).
2. Use `{token.refs}` everywhere; never inline hex values.
3. The two-radius system (`{rounded.lg}` for containers, `{rounded.pill}` for controls) is non-negotiable. Do not introduce intermediate radii.
4. Status colors are semantic only. Green = running, yellow = warning, red = error. Never use them decoratively.
5. Table density (35px rows, 10–11px text) is the core design intent. Do not increase for "readability."
6. The gradient canvas is the only decorative element. Everything else is functional.
7. When in doubt about emphasis: change weight (500 → 600 → 700) or color (primary → secondary → muted) before adding chrome.

## Known Gaps

- Form inputs (search field) have no documented error or validation states; only the neutral state is specified.
- The elevation banner's "Run as Admin" button does not have a hover/active state documented.
- The dropdown menu triggered by the top-bar "View" button is a standard Flutter `showMenu` overlay; its visual styling is not tokenized.
- Chart tooltip styling (the popup showing exact values on hover) uses fl_chart defaults and is not documented as a design token.
- The app's minimum window size (600×600) is enforced at runtime but not represented as a design token.
- Process icon rendering (17×17px, 6px border radius, base64-decoded from native DLL) is not documented as a component; it is a runtime data flow, not a static design element.
