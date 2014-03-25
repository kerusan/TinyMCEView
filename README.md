#TinyMCEView framework

A framework for [Cappuccino](http://cappuccino-project.org) that encapsulates the javascript HTML editor TinyMCE. It is right now a quick hack just to get it working but I hope it can evolve further on. It is a HTML editor and should not be thought of as a replacement to either CPTextView or any other multiline textview even if it can be used as such. I have earlier used and still do use [WKTextField](https://github.com/wireload/WKTextView) for some things, but the TinyMCE editor is a more complete HTML editor than Google's Closure Lib editor. And I needed the extra features TinyMCE bring and did not have time to implement them myself in that lib.

## Features

This Cappuccino control tries to implement as many of the TinyMCE features as possible. It is a CPView subclass and it tries to act as a well behaved Cappuccino control as far as it is possible. But since TinyMCE has an eventhandling of its own, some half nasty hacks have been made so the two event loops can reside side by side.

The setup, if default configuration does not fit, is now done in a method called editorConfigurationWithElement:. Subclass TinyMCEView and overide this method for a different configuration.

## Version

Right now the TinyMCE 4.0.19 is supplied in both min and full versions. I will try to upgrade to latest later. There will come a CHANGELOG too. Current version is 0.5 of the framework, have to start somewhere.

## License

Since TinyMCE is LGPL 2.1 I assume this code can have another license and therefore the MIT license is used for the code in the TinyMCEView class. So use this project as you like but please link to this project if you do. It would also be nice if you tell me if you use it just to get some feedback.

## Known bugs

There is right now an issue that makes the mouseclick in the TinyMCE menu pass through to the underlying Cappuccino views if a menu is outside the editor frame. This will be looked into. TinyMCE dialogs had this issue too before, but this is handled now in the TinyMCEView code.

## Demo

There will be a Demo application soon. And the demo project will be added to my projects here on GitHub.

## Todo

There is lots of room for improvments and fixes. It would be nice to have bindings working and also some theme improvments more like Aristo2. Configuration may also be easier to do with no subclassing. Please give feedback on how you are using the view.


Enjoy
Kerusan
