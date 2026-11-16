"""Subset the app fonts for the web build.

Flutter web downloads every registered font before the first frame, and the
full Pretendard files are about 1.5MB each. The web build (scripts/vercel-build.sh)
copies these subsets over assets/fonts; native builds keep the full fonts.

Kept: KS X 1001 Hangul and symbols, Latin, common punctuation, and every
character written in lib/. Other characters fall back to the browser engine's
Noto fonts. Requires fontTools. Run again after changing fonts or adding app
copy with characters outside KS X 1001.
"""

from pathlib import Path

from fontTools import subset

root = Path(__file__).resolve().parent.parent


def ks_x_1001():
    rows = [*range(0xA1, 0xAD), *range(0xB0, 0xC9)]  # symbols, jamo, Hangul; no Hanja
    for lead in rows:
        for trail in range(0xA1, 0xFF):
            try:
                yield bytes([lead, trail]).decode('euc-kr')
            except UnicodeDecodeError:
                pass


ranges = [
    (0x0020, 0x007E), (0x00A0, 0x00FF), (0x2010, 0x205E), (0x2190, 0x21FF),
    (0x2460, 0x24FF), (0x3000, 0x303F), (0x3130, 0x318F), (0xFF01, 0xFF5E),
]
text = set(ks_x_1001())
text.update(chr(code) for start, end in ranges for code in range(start, end + 1))
for source in (root / 'lib').rglob('*.dart'):
    text.update(source.read_text(encoding='utf-8'))

destination = root / 'assets/fonts/web'
destination.mkdir(exist_ok=True)
options = subset.Options()
options.layout_features = ['*']
options.name_IDs = ['*']
for weight in ('Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black'):
    font = subset.load_font(str(root / f'assets/fonts/Pretendard-{weight}.otf'), options)
    glyphs = subset.Subsetter(options)
    glyphs.populate(text=''.join(sorted(text)))
    glyphs.subset(font)
    subset.save_font(font, str(destination / f'Pretendard-{weight}.otf'), options)
