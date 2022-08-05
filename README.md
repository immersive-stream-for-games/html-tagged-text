# html_tagged_text

Supports styling text using custom HTML tags. This is particularly useful for
styling text within a translated string.

NOTE: HTML is used only because it provides a convenient way to mark up text
that is supported by Translation Console. This widget provides very basic HTML
functionality by supplying default `TextSpan` generators for text in **bold**
(using both `b` and `strong` tags), *italics* (using both `i` and `em` tags) and
underline. See `HtmlWidget` if you want additional HTML support such as tables
or divs.

## Usage

The widget takes in a map of text span builders by tag name, and the string to
render.

For example:

```dart
String greeting(String name) => Intl.message(
      'Hello, my name is <name>$name</name>',
      name: 'greeting',
      args: [name],
      desc: '...',
    );

TaggedText(
  content: greeting('Bob'),
  spanBuilders: {
    'name': (text) => TextSpan(
        text: text,
        const TextStyle(color: Colors.red),
  },
  style: Theme.of(context).textTheme.body1,
);
```

Would result in a widget that looks like:

> Hello, my name is <font style="color:red">Bob</font>!

### Clickable spans

`TextSpan` accepts a `GestureRecognizer` in its constructor. You can use this to
link to screens in your string.

For example:

```dart
TaggedText(
  content: '<campaign-name>Search campaign 1</campaign-name> has 400 clicks.',
  spanBuilders: {
    'campaign-name': (text) => TextSpan(
        text: text,
        style: const TextStyle(decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()..onTap = () {
          // Go to campaign screen...
        })
  },
  style: Theme.of(context).textTheme.body1,
);
```
