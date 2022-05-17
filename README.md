# MockSimpleComic
A testbed for using Apple's Vision framework with SimpleComic

This uses an NSImageView in a NSScrollView as a toy version of TSSTPageView. It has one page,
a compiled-in page from Django Zorro as sample data.

When run, it displays that page, scaled, in scrollbars. It initially covers most of the page
with a yellow tint.

It runs the Vision.framework OCR engine. Once that completes, you can use the mouse to select
text in place (look for the i-Beam cursor), and it tints just the places where it recognized text.

On the menubar, Select All, Copy, and Start Speaking work, as do items on the Services submenu.

Control-Click on selected text for a contextual menu. (Simple Comic uses right click for its
magnifying glass.)

Example of the start of the text it found with this sample page.

![sample](images/sample.png)

```
YES, WELL... SINCE YOU ARE
THE LAST TO ARRIVE, I'M AFRAID
OUR SERVANTS' QUARTERS
ARE FULL UP! YOUR MEN CAN
BUNK DOWN IN THE STABLES,
WHICH SEEMS -SNIFF& MOST
APPROPRIATE FOR THEIR
CURRENT FETTLE/ …
```
