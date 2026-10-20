"""Subset the existing app fonts for the pre-Flutter loading screen.

Requires fontTools. Run again after changing web/index.html or web/offline.html copy.
"""

from html.parser import HTMLParser
from pathlib import Path
from shutil import copyfile

from fontTools import subset


class LoadingCopy(HTMLParser):
    def __init__(self):
        super().__init__()
        self.text = []
        self.capture = False

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        for name, value in attributes.items():
            if name == 'data-error' or name.startswith('data-stage-'):
                self.text.append(value)
        self.capture = attributes.get('class') in ('boot-title', 'boot-caption', 'boot-retry', 'offline-heading')

    def handle_data(self, data):
        if self.capture:
            self.text.append(data)

    def handle_endtag(self, tag):
        self.capture = False


root = Path(__file__).resolve().parent.parent
copy = LoadingCopy()
copy.feed((root / 'web/index.html').read_text(encoding='utf-8'))
copy.feed((root / 'web/offline.html').read_text(encoding='utf-8'))
destination = root / 'web/fonts'
destination.mkdir(exist_ok=True)
for weight in ('Regular', 'Bold'):
    font = subset.load_font(str(root / f'assets/fonts/Pretendard-{weight}.otf'), subset.Options())
    glyphs = subset.Subsetter()
    glyphs.populate(text=''.join(copy.text))
    glyphs.subset(font)
    subset.save_font(font, str(destination / f'Pretendard-Bootstrap-{weight}.otf'), subset.Options())
copyfile(root / 'assets/fonts/Pretendard-LICENSE.txt', destination / 'Pretendard-LICENSE.txt')
