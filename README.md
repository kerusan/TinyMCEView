#TinyMCEView framework

A framework for [Cappuccino](http://cappuccino-project.org) that encapsulates the javascript HTML editor [TinyMCE](http://www.tinymce.com). It is right now a quick hack just to get it working but I hope it can evolve further on. It is a HTML editor and should not be thought of as a replacement to either CPTextView or any other multiline textview even if it can be used as such. I have earlier used and still do use [WKTextField](https://github.com/wireload/WKTextView) for some things, but the TinyMCE editor is a more complete HTML editor than Google's Closure Lib editor and I needed the extra features TinyMCE bring and I did not have time to implement them myself in the Closure lib.

## Getting started

To get the framework just do:

    git clone https://github.com/kerusan/TinyMCEView.git

Now you have a local copy.

Then to build it you have to have a working Cappuccino installation. When you have that do:

    cd TinyMCEView
    jake install
    cd ..

This will install it into you $CAPP_BUILD dir:

To make a Test application with Xcode do:

    capp gen -t NIBApplication -l -F TinyMCEView Test
    cd Test
    mkdir Frameworks/Source
    cd Frameworks/Source
    ln -s ../../../TinyMCEView .
    cd ../..
    xcc .

Now you have a Xcode project with the framework added so it is easy to instantiate a TinyMCEView inside a window.

Since TinyMCE is an external javascript lib it has to be loaded from the index.html or index-debug.html files. So include these lines in index.html

    <script type="text/javascript"
    src="Frameworks/TinyMCEView/Resources/tinymce.min.js"
    charset="UTF-8">
    </script>

and this in the index-debug.html

    <script type="text/javascript"
    src="Frameworks/Debug/TinyMCEView/Resources/tinymce.full.js"
    charset="UTF-8">
    </script>

Now it is time for puting a TinyMCEView into the XIB file, and don't forget to add:

    @import <TinyMCEView/TinyMCEView.j>
    
in the begining of AppController.j

Test it with

    python -m "SimpleHTTPServer"
    
and the URL

    http://localhost:8000/index-debug.html
    


## Features

This Cappuccino control tries to implement as many of the TinyMCE features as possible. It is a CPView subclass and it tries to act as a well behaved Cappuccino control as far as it is possible. But since TinyMCE has an event handling of its own, some half nasty hacks have been made so the two event loops can reside side by side.

The editor will respond to view resizing and change size automatic.

The setup, if default configuration does not fit, is now done in a method called `editorConfigurationWithElement:`. Subclass TinyMCEView and override this method for a different configuration.

## Version

Current version of this framework is now 0.5 (I had to start somewhere). It is still a quick hack and may contain some strange things due to my testing to get to know TinyMCE. Right now the TinyMCE 4.0.19 is supplied in both min and full versions. I will try to upgrade to latest later. There will come a CHANGELOG too.

## License

Since TinyMCE is LGPL 2.1 I assume this code can have another license and therefore the MIT license is used for the code in the TinyMCEView class. So use this project as you like but please link to this project if you do. It would also be nice if you tell me if you use it just to get some feedback.

## Known bugs and caveats

There is right now an issue that makes the mouse click in the TinyMCE menu pass through to the underlying Cappuccino views if a menu is outside the editor frame. This will be looked into. TinyMCE dialogs had this issue too before, but this is handled now in the TinyMCEView code.

The editor is a bit sensitive to being displayed in different windows/views so if you switch out the view or close a window it is displayed in do a

    [myEditorView setHidden:YES];

before you do it and then

    [myEditorView setHidden:NO];

when you want to show it again.

## Demo

There is a Demo application [here](http://www.kerusan.org/Cappuccino/resources/TestMCE/Test/index-debug.html). And the demo project will be added to my projects here on GitHub.

## Todo

There is lots of room for improvements and fixes. It would be nice to have bindings working and also some theme improvements more like Aristo2. Configuration may also be easier to do with no subclassing. Please give feedback on how you are using the view.


Enjoy
Kerusan
