# 7DHUB HR Baseline Brand Source

**Owner-approved source**: `https://7dhub.co/`

**Recorded**: 2026-10-11

**Purpose**: Traceable design input for the shared 7DHUB HR store/default brand.

## Observed official assets

- Header wordmark: `https://7dhub.co/wp-content/uploads/2026/02/WhatsApp_Image_2026-01-14_at_3.08.37_PM-removebg-preview-1.svg`

  Observed SHA-256: `5d9e27748b29a7d4a4cbae19f3366cd9198aa1e8564556d40cfd9e3df6b01125`
- Light-on-dark wordmark used on the site: `https://7dhub.co/wp-content/uploads/2021/08/Group.svg`

  Observed SHA-256: `675f754040ffdf4343affd90b22a8b992c6a9f2688b0ddc073f55f9c89aa48ec`
- Current site icon source family: `https://7dhub.co/wp-content/uploads/2024/12/cropped-Group-1000006256-270x270.png`

  Observed SHA-256: `38873db04c114b14125a825bb0861ea01c1e0c1efee2067a7fcb35c77d0f2e26`

The implementation must download and review the source files, normalize them
into owned app assets, record SHA-256 checksums, and generate the required
Android, iOS, web, light, dark, compact, and accessible variants. The running
app must not hot-link these website files.

## Observed website palette

| Token | Website value | Intended baseline use |
|---|---:|---|
| Brand green | `#78AF2B` | Primary actions and active highlights |
| Logo green | `#79B12C` | Wordmark/icon master color |
| Graphite | `#3C4D57` | Wordmark, neutral text, and dark brand detail |
| White | `#FFFFFF` | Light surfaces and reversed wordmark |
| Supporting green | `#A3D75B` | Secondary accents after contrast validation |
| Pale green | `#D4FF99` | Subtle backgrounds after contrast validation |

The two close green values reflect separate website CSS/logo sources. Before
implementation, design tokens must choose a canonical primary and document any
intentional logo-only exception. Every foreground/background pairing must pass
the product's accessibility checks; observed marketing colors are inputs, not
automatic approval for UI text.

## Naming

- Store/default installed name: **7DHUB HR**
- Marketing brand source: **7D HUB**
- Signed-out mobile/web fallback: **7DHUB HR**
- Authenticated company name: the active company's approved display name

## Release approval

Native launcher icons, store artwork, and the final transformed logo set require
owner visual review before release. Dynamic company branding remains separate
from this bundled platform identity.
