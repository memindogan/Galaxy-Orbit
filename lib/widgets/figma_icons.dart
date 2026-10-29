/// Icons extracted 1:1 from the Figma export and design specifications.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/theme_constants.dart';

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

class FigmaIcon extends StatelessWidget {
  final String _svg;
  final double size;

  const FigmaIcon._(this._svg, this.size);

  /// Settings gear (Figma: top-left chip).
  factory FigmaIcon.gear({double size = 18, Color color = kAccentColor}) =>
      FigmaIcon._(
        '<svg viewBox="36 60 18 18" xmlns="http://www.w3.org/2000/svg">'
        '<path fill="${_hex(color)}" d="$_gearPath"/></svg>',
        size,
      );

  /// Stardust sparkle / star (Figma: wallet pill).
  factory FigmaIcon.stardust({double size = 14, Color color = const Color(0xFFFFD166)}) =>
      FigmaIcon._(
        '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
        '<path fill="${_hex(color)}" d="M12 2l2.4 7.2h7.6l-6 4.8 2.3 7.2-6.3-4.6-6.3 4.6 2.3-7.2-6-4.8h7.6z"/></svg>',
        size,
      );

  /// Orbit glyph (Figma: Hangar / Celestial Market button).
  factory FigmaIcon.orbit({double size = 18, Color color = kAccentColor}) =>
      FigmaIcon._(
        '<svg viewBox="94 765 18 18" xmlns="http://www.w3.org/2000/svg">'
        '<path fill="none" stroke="${_hex(color)}" stroke-width="1.6" '
        'stroke-linecap="round" d="$_orbitPath"/></svg>',
        size,
      );

  /// Chevron right (Figma: Hangar button trailing arrow).
  factory FigmaIcon.chevron({double size = 14, Color color = kAccentColor}) =>
      FigmaIcon._(
        '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
        '<path fill="none" stroke="${_hex(color)}" stroke-width="2.2" '
        'stroke-linecap="round" stroke-linejoin="round" d="M9 18l6-6-6-6"/></svg>',
        size,
      );

  /// Back arrow (Figma: Hangar screen header back button).
  factory FigmaIcon.arrowBack({double size = 20, Color color = kTextColor}) =>
      FigmaIcon._(
        '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
        '<path fill="none" stroke="${_hex(color)}" stroke-width="2.2" '
        'stroke-linecap="round" stroke-linejoin="round" '
        'd="M19 12H5M12 19l-7-7 7-7"/></svg>',
        size,
      );

  /// Arrow right (Figma: Action button forward arrow).
  factory FigmaIcon.arrowRight({double size = 16, Color color = const Color(0xFF071722)}) =>
      FigmaIcon._(
        '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
        '<path fill="none" stroke="${_hex(color)}" stroke-width="2.5" '
        'stroke-linecap="round" stroke-linejoin="round" '
        'd="M5 12h14M12 5l7 7-7 7"/></svg>',
        size,
      );

  /// Lock icon (Figma: locked planet price tag).
  factory FigmaIcon.lock({double size = 14, Color color = kAccentColor}) =>
      FigmaIcon._(
        '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
        '<rect x="4" y="10" width="16" height="11" rx="2" fill="none" '
        'stroke="${_hex(color)}" stroke-width="2"/>'
        '<path fill="none" stroke="${_hex(color)}" stroke-width="2" '
        'd="M8 10V7a4 4 0 0 1 8 0v3"/></svg>',
        size,
      );

  /// Rocket / spaceship icon (Figma: Hangar button lead icon).
  factory FigmaIcon.rocket({double size = 18, Color color = kAccentColor}) =>
      FigmaIcon._(
        '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
        '<path fill="none" stroke="${_hex(color)}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" '
        'd="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09zM12 15l-3-3m0 0l2-4 7-4-4 7-4 2zm3-3l4 4m-8-8l-2 2"/></svg>',
        size,
      );

  /// Speaker volume icon (Figma: Settings Music Volume).
  factory FigmaIcon.speaker({double size = 18, Color color = kAccentColor}) =>
      FigmaIcon._(
        '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
        '<path fill="${_hex(color)}" d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>',
        size,
      );

  /// Soundwave / Equalizer icon (Figma: Settings SFX Volume).
  factory FigmaIcon.soundwave({double size = 18, Color color = kAccentColor}) =>
      FigmaIcon._(
        '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
        '<path fill="${_hex(color)}" d="M12 3a1 1 0 0 0-1 1v16a1 1 0 0 0 2 0V4a1 1 0 0 0-1-1zm-4 4a1 1 0 0 0-1 1v8a1 1 0 0 0 2 0V8a1 1 0 0 0-1-1zm8 0a1 1 0 0 0-1 1v8a1 1 0 0 0 2 0V8a1 1 0 0 0-1-1zm-12 4a1 1 0 0 0-1 1v0a1 1 0 0 0 2 0v0a1 1 0 0 0-1-1zm16 0a1 1 0 0 0-1 1v0a1 1 0 0 0 2 0v0a1 1 0 0 0-1-1z"/></svg>',
        size,
      );

  /// Vibrate / Haptic icon (Figma: Settings Haptic Feedback).
  factory FigmaIcon.vibrate({double size = 18, Color color = kAccentColor}) =>
      FigmaIcon._(
        '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
        '<path fill="${_hex(color)}" d="M16 19H8V5h8v14zm0-16H8a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2zM2 9v6h2V9H2zm20 0v6h-2V9h2zM0 11v2h1v-2H0zm23 0v2h1v-2h-1z"/></svg>',
        size,
      );

  /// Checkmark icon (Figma: Equipped badge).
  factory FigmaIcon.check({double size = 12, Color color = kAccentColor}) =>
      FigmaIcon._(
        '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
        '<path fill="none" stroke="${_hex(color)}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" '
        'd="M20 6L9 17l-5-5"/></svg>',
        size,
      );

  /// Close icon (Figma: Settings close button).
  factory FigmaIcon.close({double size = 16, Color color = kTextColor}) =>
      FigmaIcon._(
        '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
        '<path fill="none" stroke="${_hex(color)}" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" '
        'd="M18 6L6 18M6 6l12 12"/></svg>',
        size,
      );

  /// Trophy icon (Figma: Orbit Lost high score emblem).
  factory FigmaIcon.trophy({double size = 14, Color color = const Color(0xFFAA93FF)}) =>
      FigmaIcon._(
        '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
        '<path fill="${_hex(color)}" d="M19 4h-2V3a1 1 0 0 0-1-1H8a1 1 0 0 0-1 1v1H5a2 2 0 0 0-2 2v2a5 5 0 0 0 4.13 4.93A6 6 0 0 0 11 15.9V19H8a1 1 0 0 0 0 2h8a1 1 0 0 0 0-2h-3v-3.1a6 6 0 0 0 3.87-1.97A5 5 0 0 0 21 8V6a2 2 0 0 0-2-2zM5 8V6h2v4.73A3 3 0 0 1 5 8zm14 0a3 3 0 0 1-2 2.73V6h2v2z"/></svg>',
        size,
      );

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(_svg, width: size, height: size);
  }
}

const String _gearPath =
    'M50.0184 69.0004C50.0184 68.5587 50.1253 68.1236 50.329 67.7318C50.5314 67.3425 50.8241 67.0074 51.1825 66.7543C51.4146 66.588 51.5773 66.3409 51.6376 66.0619C51.6979 65.7827 51.6515 65.4908 51.5087 65.2435C51.3658 64.9964 51.136 64.8112 50.8641 64.724C50.5923 64.6369 50.2979 64.6538 50.038 64.7718C49.6394 64.9561 49.2023 65.042 48.7636 65.0228C48.3223 65.0035 47.8922 64.8783 47.5096 64.6576C47.127 64.4368 46.8029 64.1267 46.5653 63.7543C46.3278 63.3819 46.1833 62.9579 46.1444 62.5179V62.517C46.116 62.2345 45.9835 61.9727 45.7733 61.7816C45.5616 61.5891 45.286 61.4818 44.9999 61.4818C44.7138 61.4818 44.4381 61.5891 44.2264 61.7816C44.0149 61.9741 43.8825 62.2381 43.8553 62.5228C43.8534 62.5432 43.849 62.5635 43.8456 62.5834C43.7987 62.9998 43.6591 63.4005 43.4335 63.7543C43.1959 64.1267 42.8718 64.4368 42.4891 64.6576C42.1066 64.8783 41.6765 65.0035 41.2352 65.0228C40.7941 65.0421 40.3543 64.9553 39.954 64.7689V64.7679C39.696 64.6535 39.4045 64.6386 39.1356 64.725C38.864 64.8123 38.6338 64.9974 38.4911 65.2445C38.3484 65.4915 38.3031 65.783 38.3632 66.0619C38.4233 66.3408 38.5854 66.5879 38.8173 66.7543C39.1755 67.0073 39.4684 67.3426 39.6708 67.7318C39.8744 68.1236 39.9803 68.5588 39.9803 69.0004C39.9803 69.4419 39.8744 69.8771 39.6708 70.2689C39.4682 70.6586 39.1741 70.9933 38.8153 71.2465L38.8163 71.2474C38.5844 71.4137 38.4225 71.6599 38.3622 71.9388C38.3019 72.218 38.3473 72.5099 38.4901 72.7572C38.6329 73.0044 38.8628 73.1895 39.1346 73.2767C39.3725 73.353 39.6279 73.35 39.8622 73.2689L39.9618 73.2289C40.3601 73.0446 40.7967 72.958 41.2352 72.9769C41.6766 72.9961 42.1074 73.1215 42.4901 73.3422C42.8728 73.5629 43.1968 73.8731 43.4345 74.2455C43.6712 74.6166 43.8149 75.0395 43.8544 75.4779H43.8553C43.8825 75.7626 44.0149 76.0267 44.2264 76.2191C44.4381 76.4116 44.7138 76.5189 44.9999 76.5189C45.286 76.5189 45.5616 76.4116 45.7733 76.2191C45.985 76.0266 46.1183 75.7627 46.1454 75.4779C46.1849 75.0397 46.3287 74.6174 46.5653 74.2465C46.8029 73.874 47.127 73.5639 47.5096 73.3431C47.8922 73.1224 48.3223 72.9972 48.7636 72.9779C49.202 72.9587 49.6386 73.0448 50.037 73.2289C50.2969 73.3469 50.5923 73.3639 50.8641 73.2767C51.136 73.1895 51.3658 73.0044 51.5087 72.7572C51.6515 72.5099 51.6979 72.218 51.6376 71.9388C51.5773 71.6598 51.4146 71.4137 51.1825 71.2474V71.2465C50.8241 70.9934 50.5314 70.6582 50.329 70.2689C50.1253 69.8771 50.0184 69.442 50.0184 69.0004ZM46.6991 69.0004C46.6989 68.0618 45.9384 67.3014 44.9999 67.3011C44.0611 67.3011 43.2999 68.0616 43.2997 69.0004C43.2997 69.9392 44.061 70.7006 44.9999 70.7006C45.9385 70.7003 46.6991 69.9391 46.6991 69.0004ZM48.2997 69.0004C48.2997 70.8227 46.8222 72.3009 44.9999 72.3011C43.1773 72.3011 41.6991 70.8229 41.6991 69.0004C41.6993 67.178 43.1774 65.7006 44.9999 65.7006C46.8221 65.7008 48.2995 67.1781 48.2997 69.0004ZM51.619 69.0004C51.619 69.185 51.6637 69.3668 51.7489 69.5306C51.8341 69.6945 51.9571 69.8357 52.1083 69.9418L52.1151 69.9466C52.67 70.3443 53.057 70.9346 53.2011 71.6019C53.3451 72.2693 53.236 72.9668 52.8944 73.558C52.5528 74.149 52.0034 74.5916 51.3534 74.8002C50.7032 75.0087 49.9986 74.9681 49.3768 74.6859L49.369 74.683C49.2017 74.6051 49.0183 74.5685 48.8339 74.5765C48.6494 74.5846 48.4694 74.6367 48.3095 74.7289C48.1494 74.8212 48.0133 74.9511 47.9139 75.1068C47.8148 75.2624 47.7545 75.4396 47.7382 75.6234V75.6293C47.6734 76.3104 47.3567 76.9433 46.8505 77.4037C46.3442 77.864 45.6841 78.1185 44.9999 78.1185C44.3159 78.1185 43.6564 77.8638 43.1503 77.4037C42.6441 76.9433 42.3274 76.3104 42.2626 75.6293L42.2616 75.6234C42.2453 75.4394 42.1852 75.2616 42.0858 75.1058C41.9865 74.9503 41.8511 74.8211 41.6913 74.7289C41.5312 74.6365 41.3505 74.5836 41.1659 74.5756C40.9815 74.5676 40.7981 74.605 40.6307 74.683L40.6229 74.6859C40.0011 74.9682 39.2966 75.0087 38.6464 74.8002C37.9961 74.5916 37.446 74.1492 37.1044 73.558C36.7628 72.9668 36.6537 72.2693 36.7977 71.6019C36.9419 70.9345 37.3296 70.3443 37.8846 69.9466L37.8905 69.9418L37.9989 69.8558C38.1014 69.7638 38.187 69.6535 38.2509 69.5306C38.336 69.3668 38.3807 69.1849 38.3807 69.0004C38.3807 68.8158 38.336 68.6339 38.2509 68.4701C38.1657 68.3062 38.0417 68.165 37.8905 68.059L37.8837 68.0541C37.3295 67.6563 36.9425 67.0666 36.7987 66.3998C36.6549 65.7327 36.7651 65.0356 37.1063 64.4447C37.4476 63.8539 37.9959 63.4104 38.6454 63.2015C39.2139 63.0187 39.8245 63.0267 40.3846 63.2201L40.621 63.3148L40.6288 63.3177C40.7962 63.3958 40.9804 63.4323 41.1649 63.4242C41.3494 63.4161 41.5293 63.3641 41.6893 63.2718C41.8494 63.1795 41.9845 63.0497 42.0839 62.8939C42.1832 62.7382 42.2443 62.5612 42.2606 62.3773C42.2636 62.3435 42.2683 62.31 42.2753 62.2777C42.3591 61.6326 42.6675 61.0371 43.1503 60.598C43.6565 60.1377 44.3157 59.8822 44.9999 59.8822C45.6842 59.8822 46.3442 60.1376 46.8505 60.598C47.2932 61.0008 47.5912 61.535 47.702 62.1185L47.7382 62.3715V62.3773C47.7545 62.5611 47.8148 62.7383 47.9139 62.8939C48.0133 63.0497 48.1494 63.1795 48.3095 63.2718C48.4694 63.364 48.6494 63.4161 48.8339 63.4242C49.0183 63.4322 49.2017 63.3957 49.369 63.3177L49.3768 63.3148C49.9986 63.0326 50.7032 62.992 51.3534 63.2006C52.0034 63.4091 52.5528 63.8517 52.8944 64.4427C53.236 65.0341 53.3452 65.7323 53.2011 66.3998C53.0569 67.0669 52.6699 67.6565 52.1151 68.0541L52.1083 68.059C51.9571 68.165 51.8341 68.3062 51.7489 68.4701C51.6637 68.6339 51.619 68.8157 51.619 69.0004Z';

const String _orbitPath =
    'M109.255 769.863C110.064 771.086 110.497 772.52 110.5 773.986C110.503 775.453 110.076 776.888 109.272 778.114C108.468 779.34 107.322 780.304 105.976 780.886C104.63 781.468 103.143 781.642 101.699 781.388M96.7439 778.137C95.9348 776.914 95.5021 775.48 95.4994 774.013C95.4967 772.546 95.9241 771.111 96.7287 769.885C97.5333 768.659 98.6798 767.695 100.026 767.114C101.373 766.532 102.86 766.359 104.305 766.614M105.249 774C105.249 775.243 104.242 776.25 102.999 776.25C101.757 776.25 100.749 775.243 100.749 774C100.749 772.757 101.757 771.75 102.999 771.75C104.242 771.75 105.249 772.757 105.249 774ZM109.749 768.75C109.749 769.579 109.078 770.25 108.249 770.25C107.421 770.25 106.749 769.579 106.749 768.75C106.749 767.922 107.421 767.25 108.249 767.25C109.078 767.25 109.749 767.922 109.749 768.75ZM99.2494 779.25C99.2494 780.079 98.5778 780.75 97.7494 780.75C96.921 780.75 96.2494 780.079 96.2494 779.25C96.2494 778.422 96.921 777.75 97.7494 777.75C98.5778 777.75 99.2494 778.422 99.2494 779.25Z';
