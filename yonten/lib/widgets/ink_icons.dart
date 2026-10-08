import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/colors.dart';
import '../theme/text.dart';

/// Art missing from the image pack (spec §3), drawn in the same style:
/// a 2–2.5 px #2D3142 outline, flat fills, palette colors only.
///
/// Each glyph is named like the file the brief expects (e.g. `icon-book`,
/// `obj-apple`). When real art arrives, drop `assets/images/<fileName>.webp`
/// in and switch the call site to Image.asset.
enum InkGlyph {
  book('icon-book', _book),
  guidebook('icon-guide', _guidebook),
  magnifier('icon-magnifier', _magnifier),
  pecha('icon-pecha', _pecha),
  star('icon-star', _star),
  lock('icon-lock', _lock),
  speaker('icon-speaker', _speaker),
  close('icon-close', _close),
  switchCamera('icon-switch-camera', _switchCamera),
  check('icon-check', _check),
  apple('obj-apple', _apple),
  door('obj-door', _door),
  water('obj-water', _water),
  sun('obj-sun', _sun);

  const InkGlyph(this.fileName, this.svg);

  final String fileName;
  final String svg;
}

class InkIcon extends StatelessWidget {
  const InkIcon(this.glyph, {super.key, this.size = 32, this.semanticLabel});

  final InkGlyph glyph;
  final double size;

  /// Null means decorative (hidden from screen readers).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      glyph.svg,
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}

/// The "+10 XP" seal: a yellow circle with the text set in code (§3).
class XpSeal extends StatelessWidget {
  const XpSeal({super.key, this.text = '+10 XP', this.size = 64});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: YColors.yellow,
          shape: BoxShape.circle,
          border: Border.all(color: YColors.ink, width: 2.5),
        ),
        padding: EdgeInsets.all(size * 0.08),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: YColors.yellowDark, width: 2),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: YText.heading(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Shared SVG attributes. Small icons use a 32 viewBox, word pictures 96.
const _o = 'stroke="#2D3142" stroke-width="2.25" stroke-linejoin="round" '
    'stroke-linecap="round"';
const _oBig = 'stroke="#2D3142" stroke-width="2.5" stroke-linejoin="round" '
    'stroke-linecap="round"';

const _book = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <path d="M7 6.5A3.5 3.5 0 0 1 10.5 3H26v20H10.5A3.5 3.5 0 0 0 7 26.5z" fill="#2AB0EE" $_o/>
  <path d="M10.5 23H26v6H10.5A3 3 0 0 1 10.5 23z" fill="#FFFFFF" $_o/>
  <path d="M12 8h9M12 12h6" fill="none" $_o/>
</svg>''';

const _guidebook = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <path d="M16 8C12.5 5.5 7.5 5 3 6v19.5c4.5-1 9.5-.5 13 2z" fill="#FFFFFF" $_o/>
  <path d="M16 8c3.5-2.5 8.5-3 13-2v19.5c-4.5-1-9.5-.5-13 2z" fill="#C03221" $_o/>
  <path d="M7 11.5c2-.4 4-.3 6 .5M7 16c2-.4 4-.3 6 .5" fill="none" $_o/>
</svg>''';

const _magnifier = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <path d="M20 20l8 8" stroke="#2D3142" stroke-width="5" stroke-linecap="round"/>
  <path d="M20 20l8 8" stroke="#C03221" stroke-width="2" stroke-linecap="round"/>
  <circle cx="13" cy="13" r="9.5" fill="#DDF1FB" $_o/>
  <path d="M8.5 11.5a5 5 0 0 1 4-4" fill="none" stroke="#FFFFFF" stroke-width="2.5" stroke-linecap="round"/>
</svg>''';

const _pecha = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <rect x="2.5" y="10" width="27" height="13" rx="2" fill="#F9C80E" $_o/>
  <path d="M5.5 14h5M5.5 18h5M21.5 14h5M21.5 18h5" fill="none" stroke="#D1A507" stroke-width="2" stroke-linecap="round"/>
  <rect x="12.5" y="8.5" width="7" height="16" rx="1.5" fill="#C03221" $_o/>
</svg>''';

const _star = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <path d="M16.0 4.0 L19.5 12.1 L28.4 13.0 L21.7 18.9 L23.6 27.5 L16.0 23.0 L8.4 27.5 L10.3 18.9 L3.6 13.0 L12.5 12.1Z" fill="#F9C80E" $_o/>
</svg>''';

const _lock = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <path d="M10 14.5V10a6 6 0 0 1 12 0v4.5" fill="none" stroke="#2D3142" stroke-width="3" stroke-linecap="round"/>
  <rect x="6.5" y="14" width="19" height="14.5" rx="3.5" fill="#B8C3CC" $_o/>
  <circle cx="16" cy="20" r="2" fill="#2D3142"/>
  <path d="M16 21v3.5" stroke="#2D3142" stroke-width="2.25" stroke-linecap="round"/>
</svg>''';

const _speaker = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <path d="M4 12.5h5.5L17 6v20l-7.5-6.5H4z" fill="#FFFFFF" $_o/>
  <path d="M21 12a5.5 5.5 0 0 1 0 8M24.5 8.5a10.5 10.5 0 0 1 0 15" fill="none" $_o/>
</svg>''';

const _close = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <path d="M9 9l14 14M23 9L9 23" fill="none" stroke="#2D3142" stroke-width="3.5" stroke-linecap="round"/>
</svg>''';

const _switchCamera = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <path d="M11 9l2-3h6l2 3h4.5A3.5 3.5 0 0 1 29 12.5v11a3.5 3.5 0 0 1-3.5 3.5h-19A3.5 3.5 0 0 1 3 23.5v-11A3.5 3.5 0 0 1 6.5 9z" fill="#FFFFFF" $_o/>
  <path d="M10.5 17.5a5.5 5.5 0 0 1 9.5-3.5" fill="none" stroke="#1A8AC1" stroke-width="2.25" stroke-linecap="round"/>
  <path d="M20.5 11.5v3h-3" fill="none" stroke="#1A8AC1" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M21.5 18.5a5.5 5.5 0 0 1-9.5 3.5" fill="none" stroke="#1A8AC1" stroke-width="2.25" stroke-linecap="round"/>
  <path d="M11.5 24.5v-3h3" fill="none" stroke="#1A8AC1" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

const _check = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <path d="M7 16.5l6 6L25 10" fill="none" stroke="#2D3142" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M7 16.5l6 6L25 10" fill="none" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

const _apple = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">
  <path d="M48 31c-8-6-27-7-31 10-4 18 8 44 21 44 4 0 6-2 10-2s6 2 10 2c13 0 25-26 21-44-4-17-23-16-31-10z" fill="#C03221" $_oBig/>
  <path d="M48 31c0-7 2-13 6-17" fill="none" stroke="#2D3142" stroke-width="4" stroke-linecap="round"/>
  <path d="M53 22c5-8 14-10 21-8-2 8-12 13-21 8z" fill="#D1A507" $_oBig/>
  <path d="M27 46c0-6 4-11 9-12" fill="none" stroke="#F8DEDA" stroke-width="4.5" stroke-linecap="round"/>
</svg>''';

const _door = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">
  <path d="M16 88L23 24h50l7 64z" fill="#3D4357" $_oBig/>
  <rect x="12" y="10" width="72" height="9" rx="1.5" fill="#C03221" $_oBig/>
  <rect x="17" y="19" width="62" height="6" fill="#F9C80E" $_oBig/>
  <path d="M25 22h4M33 22h4M41 22h4M49 22h4M57 22h4M65 22h4" stroke="#C03221" stroke-width="2" stroke-linecap="round"/>
  <rect x="29" y="31" width="18.5" height="57" fill="#C03221" $_oBig/>
  <rect x="48.5" y="31" width="18.5" height="57" fill="#C03221" $_oBig/>
  <rect x="33" y="36" width="10.5" height="20" rx="1" fill="none" stroke="#9A2517" stroke-width="2"/>
  <rect x="52.5" y="36" width="10.5" height="20" rx="1" fill="none" stroke="#9A2517" stroke-width="2"/>
  <circle cx="43" cy="63" r="3.5" fill="#F9C80E" $_oBig/>
  <circle cx="53" cy="63" r="3.5" fill="#F9C80E" $_oBig/>
  <path d="M10 88h76" stroke="#2D3142" stroke-width="2.5" stroke-linecap="round"/>
</svg>''';

const _water = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">
  <path d="M48 9C38 28 21 44 21 61a27 27 0 0 0 54 0C75 44 58 28 48 9z" fill="#2AB0EE" $_oBig/>
  <path d="M33 59c0 8 4 14 10 16" fill="none" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round"/>
  <circle cx="35" cy="49" r="2.5" fill="#FFFFFF"/>
</svg>''';

const _sun = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96">
  <g fill="#F9C80E" $_oBig>
    <rect x="43" y="5" width="10" height="18" rx="5"/>
    <rect x="43" y="5" width="10" height="18" rx="5" transform="rotate(45 48 48)"/>
    <rect x="43" y="5" width="10" height="18" rx="5" transform="rotate(90 48 48)"/>
    <rect x="43" y="5" width="10" height="18" rx="5" transform="rotate(135 48 48)"/>
    <rect x="43" y="5" width="10" height="18" rx="5" transform="rotate(180 48 48)"/>
    <rect x="43" y="5" width="10" height="18" rx="5" transform="rotate(225 48 48)"/>
    <rect x="43" y="5" width="10" height="18" rx="5" transform="rotate(270 48 48)"/>
    <rect x="43" y="5" width="10" height="18" rx="5" transform="rotate(315 48 48)"/>
  </g>
  <circle cx="48" cy="48" r="21" fill="#F9C80E" $_oBig/>
  <circle cx="48" cy="48" r="14" fill="none" stroke="#D1A507" stroke-width="2.5"/>
</svg>''';
