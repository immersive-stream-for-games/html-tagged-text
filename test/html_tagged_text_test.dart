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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html_tagged_text/html_tagged_text.dart';
import 'package:mockito/mockito.dart';

const TextStyle greetingStyle = TextStyle(fontWeight: FontWeight.w100);
const TextStyle nameStyle = TextStyle(fontWeight: FontWeight.w200);
const TextStyle defaultStyle = TextStyle(fontWeight: FontWeight.w500);

void main() {
  group('$TaggedText', () {
    testWidgets('without tags', (tester) async {
      final content = 'Hello, Bob';
      final widget = TaggedText(
        content: content,
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, [TextSpan(text: content)]);
    });

    testWidgets('with tags', (tester) async {
      final widget = TaggedText(
        content: '<greeting>Hello</greeting>, my name is <name>George</name>!',
        tagToTextSpanBuilder: {
          'greeting': (text) => TextSpan(text: text, style: greetingStyle),
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, [
        TextSpan(text: 'Hello', style: greetingStyle),
        TextSpan(text: ', my name is '),
        TextSpan(text: 'George', style: nameStyle),
        TextSpan(text: '!'),
      ]);
    });

    testWidgets('with tags and selectable text', (tester) async {
      final widget = MediaQuery(
        data: MediaQueryData(),
        child: TaggedText(
          selectableText: true,
          content:
              '<greeting>Hello</greeting>, my name is <name>George</name>!',
          tagToTextSpanBuilder: {
            'greeting': (text) => TextSpan(text: text, style: greetingStyle),
            'name': (text) => TextSpan(text: text, style: nameStyle),
          },
        ),
      );

      await tester.pumpWidget(wrap(widget));

      final selectableText = findSelectableTextWidget(tester);
      final textSpan = getSelectableTextSpan(selectableText)!;
      expect(textSpan.text, isNull);
      expect(textSpan.children, [
        TextSpan(text: 'Hello', style: greetingStyle),
        TextSpan(text: ', my name is '),
        TextSpan(text: 'George', style: nameStyle),
        TextSpan(text: '!'),
      ]);
    });

    testWidgets('with InlineSpans', (tester) async {
      const redactedText = const Text('REDACTED');

      final widget = TaggedText(
        content: '<greeting>Hello</greeting>, my name is <name>George</name>!',
        tagToTextSpanBuilder: {
          'greeting': (text) => TextSpan(text: text, style: greetingStyle),
          'name': (text) => WidgetSpan(child: redactedText),
        },
      );

      await tester.pumpWidget(wrap(widget));

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsNWidgets(2));
      final richText = tester.firstWidget(richTextFinder) as RichText;

      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, [
        TextSpan(text: 'Hello', style: greetingStyle),
        TextSpan(text: ', my name is '),
        WidgetSpan(child: redactedText),
        TextSpan(text: '!'),
      ]);
    });

    testWidgets('content tags are case insensitive', (tester) async {
      final widget = TaggedText(
        content: '<GREEting>Hello</GREEting>, my name is <nAme>George</nAme>!',
        tagToTextSpanBuilder: {
          'greeting': (text) => TextSpan(text: text, style: greetingStyle),
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, [
        TextSpan(text: 'Hello', style: greetingStyle),
        TextSpan(text: ', my name is '),
        TextSpan(text: 'George', style: nameStyle),
        TextSpan(text: '!'),
      ]);
    });

    testWidgets('default tags are handled correctly', (tester) async {
      final widget = TaggedText(
        content:
            '<b>Hello</b>, <strong>my</strong> <em>name</em> <u>is</u><br/><i>George</i>!',
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, [
        TextSpan(text: 'Hello', style: TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: ', '),
        TextSpan(text: 'my', style: TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: ' '),
        TextSpan(text: 'name', style: TextStyle(fontStyle: FontStyle.italic)),
        TextSpan(text: ' '),
        TextSpan(
          text: 'is',
          style: TextStyle(decoration: TextDecoration.underline),
        ),
        TextSpan(text: '\n'),
        TextSpan(text: 'George', style: TextStyle(fontStyle: FontStyle.italic)),
        TextSpan(text: '!'),
      ]);
    });

    testWidgets('anchor tag is handled correctly', (tester) async {
      var linkUrl = '';
      final widget = TaggedText(
        content: '<a href="http://example.com">This is a link</a>',
        onTapLink: (url) => linkUrl = url,
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, hasLength(1));
      final childTextSpan = textSpan.children!.first as TextSpan;
      expect(childTextSpan.text, equals('This is a link'));
      expect(
        childTextSpan.style,
        equals(TextStyle(color: Colors.blue)),
      );
      expect(childTextSpan.recognizer, isNotNull);

      await tester.tapOnText(find.textRange.ofSubstring('This is a link'));
      expect(linkUrl, equals('http://example.com'));
    });

    testWidgets('linkStyle is applied to anchor tag correctly', (tester) async {
      final widget = TaggedText(
        content: '<a href="http://example.com">This is a link</a>',
        onTapLink: (url) {},
        linkStyle: TextStyle(color: Colors.red),
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      final childTextSpan = textSpan.children!.first as TextSpan;
      expect(childTextSpan.text, equals('This is a link'));
      expect(
        childTextSpan.style,
        equals(TextStyle(color: Colors.red)),
      );
    });

    testWidgets('anchor tags are focusable', (tester) async {
      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 1);
      await gesture.addPointer(location: const Offset(1, 1));
      addTearDown(gesture.removePointer);

      var linkUrl = '';
      final widget = TaggedText(
        content: '<a href="http://example.com">This is a link</a>',
        onTapLink: (url) => linkUrl = url,
        focusableLinks: true,
      );

      await tester.pumpWidget(wrap(widget));

      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );

      final richText = tester.firstWidget<RichText>(find.byType(RichText));
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, hasLength(1));

      // Check if the text is rendered.
      final widgetSpan = textSpan.children!.first as WidgetSpan;
      final textFinder = find.descendant(
        of: find.byWidget(widgetSpan.child),
        matching: find.text('This is a link'),
      );
      expect(textFinder, findsOneWidget);

      // Check if the callback is called when focused and "enter" is pressed.
      Focus.of(tester.element(textFinder)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(linkUrl, equals('http://example.com'));

      // Check if the callback is called by tapping on the text.
      linkUrl = '';
      await tester.tap(textFinder);
      expect(linkUrl, equals('http://example.com'));
    });

    testWidgets('asserts tags are not nested', (tester) async {
      final widget = TaggedText(
        content: '<greeting>Hello, my name is <name>George</name></greeting>!',
        tagToTextSpanBuilder: {
          'greeting': (text) => TextSpan(text: text, style: greetingStyle),
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );

      await tester.pumpWidget(wrap(widget));

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('asserts all tags in content are found', (tester) async {
      final widget = TaggedText(
        content:
            '<salutation>Hello</salutation>, my name is <name>George</name>!',
        tagToTextSpanBuilder: {
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );

      await tester.pumpWidget(wrap(widget));

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('rebuilds when content changes', (tester) async {
      final widget = TaggedText(
        content: 'Hello, Bob',
        tagToTextSpanBuilder: {
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );
      await tester.pumpWidget(wrap(widget));
      final newWidget = TaggedText(
        content: 'Hello, <name>Bob</name>',
        tagToTextSpanBuilder: {
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );

      await tester.pumpWidget(wrap(newWidget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, [
        TextSpan(text: 'Hello, '),
        TextSpan(text: 'Bob', style: nameStyle),
      ]);
    });

    testWidgets('rebuilds when tagToTextSpanBuilder changes', (tester) async {
      final widget = TaggedText(
        content: 'Hello, <name>Bob</name>',
        tagToTextSpanBuilder: {
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );
      await tester.pumpWidget(wrap(widget));
      final updatedStyle = const TextStyle(decoration: TextDecoration.overline);
      final newWidget = TaggedText(
        content: 'Hello, <name>Bob</name>',
        tagToTextSpanBuilder: {
          'name': (text) => TextSpan(text: text, style: updatedStyle),
        },
      );

      await tester.pumpWidget(wrap(newWidget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, [
        TextSpan(text: 'Hello, '),
        TextSpan(text: 'Bob', style: updatedStyle),
      ]);
    });

    testWidgets('does not rebuild when tagToTextSpanBuilder stays the same',
        (tester) async {
      // Set up.
      final mockTextSpanBuilder = MockTextSpanBuilder();
      final nameSpan = TextSpan(text: 'Bob', style: nameStyle);
      when(mockTextSpanBuilder.call(any)).thenReturn(nameSpan);

      final content = 'Hello, <name>Bob</name>';
      final tagToTextSpanBuilder = <String, TextSpanBuilder>{
        // TODO Eliminate this wrapper when the Dart 2 FE
        // supports mocking and tearoffs.
        'name': (x) => mockTextSpanBuilder(x),
      };
      final widget = TaggedText(
        content: content,
        tagToTextSpanBuilder: tagToTextSpanBuilder,
      );
      await tester.pumpWidget(wrap(widget));

      // Clone map to make sure that equality is checked by the contents of the
      // map.
      final newWidget = TaggedText(
        content: content,
        tagToTextSpanBuilder: Map.from(tagToTextSpanBuilder),
      );

      // Act.
      await tester.pumpWidget(wrap(newWidget));

      // Assert.
      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, [
        TextSpan(text: 'Hello, '),
        nameSpan,
      ]);
      verify(mockTextSpanBuilder.call(any)).called(1);
    });

    testWidgets('requires tag names to be lower case', (tester) async {
      expect(
        () => TaggedText(
          content: 'Hello, <name>Bob</name>',
          tagToTextSpanBuilder: {
            'nAme': (text) => TextSpan(text: text, style: nameStyle),
          },
        ),
        throwsA(anything),
      );
    });

    testWidgets('requires tag names to be lower case with selectable text',
        (tester) async {
      expect(
        () {
          TaggedText(
            selectableText: true,
            content: 'Hello, <name>Bob</name>',
            tagToTextSpanBuilder: {
              'nAme': (text) => TextSpan(text: text, style: nameStyle),
            },
          );
        },
        throwsA(anything),
      );
    });

    testWidgets('throws error when known HTML tags are used', (tester) async {
      expect(
        () {
          TaggedText(
            content: 'Hello, <link>Bob</link>',
            tagToTextSpanBuilder: {
              'link': (text) => TextSpan(text: text, style: nameStyle),
            },
          );
        },
        throwsA(anything),
      );
    });

    testWidgets(
        'throws error when known HTML tags are used with selectable text',
        (tester) async {
      expect(
        () {
          TaggedText(
            selectableText: true,
            content: 'Hello, <link>Bob</link>',
            tagToTextSpanBuilder: {
              'link': (text) => TextSpan(text: text, style: nameStyle),
            },
          );
        },
        throwsA(anything),
      );
    });

    testWidgets('ignores non-elements', (tester) async {
      final widget = TaggedText(
        content: 'Hello, <!-- comment is not an element and is ignored -->'
            '<name>Bob</name>',
        tagToTextSpanBuilder: {
          'name': (text) => TextSpan(text: text, style: nameStyle),
        },
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      final textSpan = getTextSpan(richText);
      expect(textSpan.text, isNull);
      expect(textSpan.children, [
        TextSpan(text: 'Hello, '),
        TextSpan(text: 'Bob', style: nameStyle),
      ]);
    });

    testWidgets('ignores non-elements with selectable text', (tester) async {
      final widget = MediaQuery(
        data: MediaQueryData(),
        child: TaggedText(
          selectableText: true,
          content: 'Hello, <!-- comment is not an element and is ignored -->'
              '<name>Bob</name>',
          tagToTextSpanBuilder: {
            'name': (text) => TextSpan(text: text, style: nameStyle),
          },
        ),
      );

      await tester.pumpWidget(wrap(widget));

      final selectableText = findSelectableTextWidget(tester);
      final textSpan = getSelectableTextSpan(selectableText)!;
      expect(textSpan.text, isNull);
      expect(textSpan.children, [
        TextSpan(text: 'Hello, '),
        TextSpan(text: 'Bob', style: nameStyle),
      ]);
    });

    testWidgets('renders correct input styles', (tester) async {
      final widget = TaggedText(
        content: '<greeting>Hello</greeting>',
        tagToTextSpanBuilder: {
          'greeting': (text) => TextSpan(text: text, style: greetingStyle),
        },
        style: defaultStyle,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        textScaleFactor: 1.5,
        maxLines: 2,
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      expect(richText.text.style, equals(defaultStyle));
      expect(richText.textAlign, equals(TextAlign.center));
      expect(richText.textDirection, equals(TextDirection.rtl));
      expect(richText.softWrap, isFalse);
      expect(richText.overflow, equals(TextOverflow.ellipsis));
      expect(richText.textScaleFactor, equals(1.5));
      expect(richText.maxLines, equals(2));
    });

    testWidgets(
        'uses 1.0 text scale factor when not specified and '
        'MediaQuery unavailable', (tester) async {
      final widget = TaggedText(
        content: '<greeting>Hello</greeting>',
        tagToTextSpanBuilder: {
          'greeting': (text) => TextSpan(text: text, style: greetingStyle),
        },
        // Text scale factor not specified!
      );

      await tester.pumpWidget(wrap(widget));

      final richText = findRichTextWidget(tester);
      expect(richText.textScaleFactor, equals(1.0));
    });

    testWidgets('uses MediaQuery text scale factor when available',
        (tester) async {
      final widget = TaggedText(
        content: '<greeting>Hello</greeting>',
        tagToTextSpanBuilder: {
          'greeting': (text) => TextSpan(text: text, style: greetingStyle),
        },
        // Text scale factor not specified!
      );
      final expectedTextScaleFactor = 123.4;

      await tester.pumpWidget(
        wrap(
          MediaQuery(
            data: MediaQueryData(textScaleFactor: expectedTextScaleFactor),
            child: widget,
          ),
        ),
      );

      final richText = findRichTextWidget(tester);
      expect(richText.textScaleFactor, equals(expectedTextScaleFactor));
    });

    testWidgets(
      'uses DefaultTextStyle when available',
      (tester) async {
        final widget = TaggedText(
          content: '<greeting>Hello</greeting>',
          tagToTextSpanBuilder: {
            'greeting': (text) => TextSpan(text: text, style: greetingStyle),
          },
          // Style not specified!
        );
        const expectedTextStyle = TextStyle(fontSize: 40);

        await tester.pumpWidget(
          wrap(
            DefaultTextStyle(
              style: expectedTextStyle,
              child: widget,
            ),
          ),
        );

        final richText = findRichTextWidget(tester);
        expect(richText.text.style, equals(expectedTextStyle));
      },
    );

    group('semantics', () {
      testWidgets('Default semantics', (tester) async {
        final widget = TaggedText(
          content: '<b>Hello</b>, <u>my name is</u><br/><i>George</i>!',
        );

        await tester.pumpWidget(wrap(widget));

        expect(
          find.bySemanticsLabel('Hello, my name is\nGeorge!'),
          findsOneWidget,
        );
      });

      testWidgets('Custom semantics', (tester) async {
        final widget = TaggedText(
          content: '<b>On Android devices,</b> <u>select Google</u> '
              '<span aria-label="and then">></span> <i>Parental controls</i>',
        );

        await tester.pumpWidget(wrap(widget));

        expect(
          find.bySemanticsLabel(
            'On Android devices, select Google and then Parental controls',
          ),
          findsOneWidget,
        );
      });
    });
  });
}

RichText findRichTextWidget(WidgetTester tester) {
  final richTextFinder = find.byType(RichText);
  expect(richTextFinder, findsOneWidget);
  return tester.widget(richTextFinder) as RichText;
}

TextSpan getTextSpan(RichText richText) {
  expect(richText.text, isA<TextSpan>());
  return richText.text as TextSpan;
}

SelectableText findSelectableTextWidget(WidgetTester tester) {
  final selectableTextFinder = find.byType(SelectableText);
  expect(selectableTextFinder, findsOneWidget);
  return tester.widget(selectableTextFinder) as SelectableText;
}

TextSpan? getSelectableTextSpan(SelectableText selectableText) {
  expect(selectableText.textSpan, isA<TextSpan>());
  return selectableText.textSpan;
}

Widget wrap(Widget widget) {
  return Theme(
    data: ThemeData(useMaterial3: false, primaryColor: Colors.blue),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: widget,
    ),
  );
}

class MockTextSpanBuilder extends Mock {
  TextSpan? call(String? text);
}
