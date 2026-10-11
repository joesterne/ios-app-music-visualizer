#!/usr/bin/env python3
"""Build the offline single-file preview from readable Web sources."""
from pathlib import Path
import base64
root=Path(__file__).resolve().parents[1]
app=(root/'Web/forest-walk.js').read_text() + '\n' + (root/'Web/app.js').read_text()
for token,name in [('__YOSEMITE_LANDSCAPE_DATA__','YosemiteLandscape'),('__YOSEMITE_CLOUD_DATA__','YosemiteCloud')]:
 asset=root/'Assets.xcassets'/f'{name}.imageset'/f'{name}.png'
 app=app.replace(token,'data:image/png;base64,'+base64.b64encode(asset.read_bytes()).decode('ascii'))
page=(root/'Web/index.html').read_text().replace('/*__STUDIO_CSS__*/',(root/'Web/studio.css').read_text()).replace('/*__APP_JS__*/',app)
(root/'Preview.html').write_text(page)
print('Built Preview.html from Web sources with offline artwork.')
