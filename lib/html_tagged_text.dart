// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

/// Builds a [TextSpan] with the provided [text].
typedef TextSpanBuilder = TextSpan? Function(String text);

/// Builds an [InlineSpan] with the provided [text].
typedef InlineSpanBuilder = InlineSpan? Function(String text);

/// Called with the [href] of an anchor tag.
typedef LinkCallback = void Function(String href);

/// Builds a [TextSpan] with the provided [node].
typedef _HtmlTextSpanBuilder = InlineSpan Function(
  BuildContext context,
  XmlNode node,
);

/// Displays the provided [content] in a [RichText] after parsing and replacing
/// HTML tags using [tagToTextSpanBuilder].
///
/// This provides a convenient way to style localized text that is marked up
/// with semantic tags.
class TaggedText extends StatefulWidget {
  /// The tagged content to render.
  final String content;

  /// A map of [InlineSpanBuilder]s by lower-case HTML tag name. Tag names must be
  /// lower-case.
  ///
  /// This is used to determine how to render each tag that is found in
  /// [content].
  ///
  /// If a tag is missing, a warning will be printed and the text will be
  /// rendered in the default [style].
  final Map<String, InlineSpanBuilder> tagToTextSpanBuilder;

  /// Default style to use for all spans of text.
  final TextStyle? style;

  /// A text style to use for link text.
  ///
  /// When null, this will default to the given [style] with blue600 color.
  final TextStyle? linkStyle;

  /// Horizontal alignment of the spans of text.
  ///
  /// See [RichText.textAlign].
  final TextAlign textAlign;

  /// The directionality of the text.
  ///
  /// See [RichText.textDirection].
  final TextDirection? textDirection;

  /// The choice of whether the spans of text should break at soft line breaks
  ///
  /// See [RichText.softWrap].
  final bool softWrap;

  /// The choice of whether the spans of text should be selectable.
  ///
  /// See [SelectableText.rich].
  final bool selectableText;

  /// The manner in which to handle visual overflow of the spans of text.
  ///
  /// See [RichText.overflow].
  final TextOverflow overflow;

  /// The number of font pixels for each logical pixel.
  ///
  /// When null, this will default to [MediaQueryData.textScaleFactor] when
  /// available or 1.0.
  ///
  /// See [Text.textScaleFactor].
  final double? textScaleFactor;

  /// An optional maximum number of lines for the spans of text.
  ///
  /// If they exceed the given number of lines, they will be truncated
  /// according to [overflow].
  ///
  /// See [RichText.maxLines].
  final int? maxLines;

  /// A callback to fire when a user taps an anchor tag.
  ///
  /// Will only be fired when the tag is tapped if the href can be parsed from
  /// the anchor tag.
  final LinkCallback? onTapLink;

  /// The choice of whether anchor tags should be focusable.
  ///
  /// Defaults to [false].
  final bool focusableLinks;

  /// A map of default [_HtmlTextSpanBuilder]s by lower-case HTML tag name.
  final Map<String, _HtmlTextSpanBuilder> defaultTextSpanBuilders;

  /// Creates a new [TaggedText].
  ///
  /// For unspecified parameters, the defaults in [RichText] will be used.
  TaggedText({
    Key? key,
    required this.content,
    this.tagToTextSpanBuilder = const <String, InlineSpanBuilder>{},
    this.style,
    this.linkStyle,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.softWrap = true,
    this.selectableText = false,
    this.overflow = TextOverflow.clip,
    this.textScaleFactor,
    this.maxLines,
    this.onTapLink,
    this.focusableLinks = false,
  })  : assert(
          tagToTextSpanBuilder.keys.every((key) {
            return key == key.toLowerCase() && !_bannedHtmlTags.contains(key);
          }),
          'All keys must be lowercase. Actual HTML tags are not allowed to '
          'avoid confusion as this is not an HTML renderer. '
          'See README.md of this library.',
        ),
        defaultTextSpanBuilders = {..._defaultSpanBuilders},
        super(key: key) {
    if (onTapLink != null) {
      defaultTextSpanBuilders['a'] = (context, node) {
        final colorScheme = Theme.of(context).colorScheme;
        final href = node.getAttribute('href');
        return focusableLinks
            ? WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _FocusableLink(
                  text: node.text,
                  style: style,
                  linkStyle: linkStyle,
                  onTap: href != null ? () => onTapLink!(href) : null,
                ),
              )
            : TextSpan(
                text: node.text,
                style: linkStyle ?? TextStyle(color: colorScheme.primary),
                recognizer: href != null
                    ? (TapGestureRecognizer()..onTap = () => onTapLink!(href))
                    : null,
              );
      };
    }
  }

  @override
  State<StatefulWidget> createState() => _TaggedTextState();
}

/// [State] for [TaggedText].
class _TaggedTextState extends State<TaggedText> {
  XmlNode? _document;
  List<InlineSpan>? _textSpans;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _parseContent();
    _parseSpans();
  }

  @override
  void didUpdateWidget(TaggedText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.content != widget.content) {
      _parseContent();
      _parseSpans();
    } else if (!(const MapEquality()
        .equals(oldWidget.tagToTextSpanBuilder, widget.tagToTextSpanBuilder))) {
      _parseSpans();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_textSpans == null) return Container();

    return widget.selectableText
        ? SelectableText.rich(
            TextSpan(children: _textSpans, style: widget.style),
            textAlign: widget.textAlign,
            textDirection: widget.textDirection,
            textScaleFactor: widget.textScaleFactor ??
                MediaQuery.maybeOf(context)?.textScaleFactor ??
                1.0,
            maxLines: widget.maxLines,
          )
        : RichText(
            text: TextSpan(children: _textSpans, style: widget.style),
            textAlign: widget.textAlign,
            textDirection: widget.textDirection,
            softWrap: widget.softWrap,
            overflow: widget.overflow,
            textScaleFactor: widget.textScaleFactor ??
                MediaQuery.maybeOf(context)?.textScaleFactor ??
                1.0,
            maxLines: widget.maxLines,
          );
  }

  void _parseContent() {
    try {
      final document = XmlDocument.parse('<html>${widget.content}</html>');
      setState(() {
        _document = document.rootElement;
      });
    } on Exception catch (_) {
      assert(false);
      // Parse exceptions are not clearly documented.
      setState(() => _document = null);
    }
  }

  void _parseSpans() {
    setState(() {
      _textSpans = _document?.children
          .map((node) {
            if (node is XmlText) {
              return TextSpan(text: node.text);
            }

            if (node is! XmlElement) return null;

            assert(node.tags.isEmpty, 'Tags should not be placed within tags.');

            final tagName = node.localName.toLowerCase();
            final textSpanBuilder = widget.tagToTextSpanBuilder[tagName];
            final defaultTextSpanBuilder =
                widget.defaultTextSpanBuilders[tagName];

            assert(textSpanBuilder != null || defaultTextSpanBuilder != null);
            if (textSpanBuilder == null && defaultTextSpanBuilder == null) {
              return TextSpan(text: node.text);
            }

            return textSpanBuilder?.call(node.text) ??
                defaultTextSpanBuilder?.call(context, node);
          })
          .whereNotNull()
          .toList();
    });
  }
}

class _FocusableLink extends StatefulWidget {
  const _FocusableLink({
    Key? key,
    required this.text,
    this.style,
    this.linkStyle,
    this.onTap,
  }) : super(key: key);

  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final GestureTapCallback? onTap;

  @override
  State<StatefulWidget> createState() => _FocusableLinkState();
}

class _FocusableLinkState extends State<_FocusableLink> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      link: true,
      container: true,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Focus(
          onFocusChange: (focused) => setState(() => _focused = focused),
          onKey: (_, keyEvent) {
            if (keyEvent is RawKeyDownEvent &&
                keyEvent.logicalKey == LogicalKeyboardKey.enter) {
              // When focused, "enter" presses to trigger the "onTap" callback.
              widget.onTap?.call();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              decoration: _focused
                  ? BoxDecoration(
                      color: colors.primary.withOpacity(0.24),
                      borderRadius: BorderRadius.circular(2),
                    )
                  : null,
              child: Text(
                widget.text,
                style: widget.linkStyle ??
                    widget.style?.copyWith(color: colors.primary) ??
                    TextStyle(color: colors.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension _NameHelper on XmlElement {
  String get localName => name.local.toLowerCase();
  Iterable<XmlElement> get tags => children.whereType<XmlElement>();
}

final _defaultSpanBuilders = <String, _HtmlTextSpanBuilder>{
  'b': (_, node) => TextSpan(
        text: node.text,
        semanticsLabel: node.getAttribute('aria-label'),
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
  'strong': (_, node) => TextSpan(
        text: node.text,
        semanticsLabel: node.getAttribute('aria-label'),
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
  'u': (_, node) => TextSpan(
        text: node.text,
        semanticsLabel: node.getAttribute('aria-label'),
        style: TextStyle(decoration: TextDecoration.underline),
      ),
  'i': (_, node) => TextSpan(
        text: node.text,
        semanticsLabel: node.getAttribute('aria-label'),
        style: TextStyle(fontStyle: FontStyle.italic),
      ),
  'em': (_, node) => TextSpan(
        text: node.text,
        semanticsLabel: node.getAttribute('aria-label'),
        style: TextStyle(fontStyle: FontStyle.italic),
      ),
  'br': (_, node) => TextSpan(
        text: '\n',
        semanticsLabel: node.getAttribute('aria-label'),
      ),
  'span': (_, node) => TextSpan(
        text: node.text,
        semanticsLabel: node.getAttribute('aria-label'),
      ),
};

const _bannedHtmlTags = {
  'abbr',
  'acronym',
  'address',
  'applet',
  'area',
  'article',
  'aside',
  'audio',
  'base',
  'basefont',
  'bdi',
  'bdo',
  'bgsound',
  'big',
  'blink',
  'blockquote',
  'body',
  'button',
  'canvas',
  'caption',
  'center',
  'cite',
  'code',
  'col',
  'colgroup',
  'command',
  'content',
  'data',
  'datalist',
  'dd',
  'del',
  'details',
  'dfn',
  'dialog',
  'dir',
  'div',
  'dl',
  'dt',
  'element',
  'embed',
  'fieldset',
  'figcaption',
  'figure',
  'font',
  'footer',
  'form',
  'frame',
  'frameset',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'head',
  'header',
  'hgroup',
  'hr',
  'html',
  'iframe',
  'image',
  'img',
  'input',
  'ins',
  'isindex',
  'kbd',
  'keygen',
  'label',
  'legend',
  'li',
  'link',
  'listing',
  'main',
  'map',
  'mark',
  'marquee',
  'menu',
  'menuitem',
  'meta',
  'meter',
  'multicol',
  'nav',
  'nextid',
  'nobr',
  'noembed',
  'noframes',
  'noscript',
  'object',
  'ol',
  'optgroup',
  'option',
  'output',
  'p',
  'param',
  'picture',
  'plaintext',
  'pre',
  'progress',
  'q',
  'rb',
  'rp',
  'rt',
  'rtc',
  'ruby',
  's',
  'samp',
  'script',
  'section',
  'select',
  'shadow',
  'slot',
  'small',
  'source',
  'spacer',
  'strike',
  'style',
  'sub',
  'summary',
  'sup',
  'table',
  'tbody',
  'td',
  'template',
  'textarea',
  'tfoot',
  'th',
  'thead',
  'time',
  'title',
  'tr',
  'track',
  'tt',
  'ul',
  'var',
  'video',
  'wbr',
  'xmp'
};
