#TinyMCEView framework

A framework for Cappuccino that encapsulates the javascript HTML editor TinyMCE. It is right now a quick hack just to get it working but I hope it can evolve further on.

## Features

This Cappuccino control tries to implement as many of the TinyMCE features as possible. It is a CPView subclass and it tries to act as a well behaved Cappuccino control as far as it is possible. But since TinyMCE has an eventhandling of its own, some half nasty hacks have been made so the two event loops can reside side by side.

The setup, if default configuration does not fit, is now done in a method called editorConfigurationWithElement:. Subclass TinyMCEView and overide this method for a different configuration.

## Version

Right now the TinyMCE 4.0.19 is supplied in both min and full versions. I will try to upgrade to latest later. There will come a CHANGELOG too. Current version is 0.5 of the framework, have to start somewhere.

## License

Since TinyMCE is LGPL 2.1 I assume this code can have another license and therefore the MIT license is used for the code in the TinyMCEView class. So use this project as you like but please link to this project if you do. It would also be nice if you tell me if you use it just to get some feedback.

## Known bugs

There is right now an issue that makes the mouseclick in the TinyMCE menu pass through to the underlying Cappuccino views if a menu is outside the editor frame. This will be looked into. TinyMCE dialogs had this issue too before, but this is handled now in the TinyMCEView code.

## Todo

There is lots of room for improvments and fixes. It would be nice to have bindings working and also some theme improvments more like Aristo2. Configuration may also be easier to do with no subclassing. Please give feedback on how you are using the view.

Kerusan
